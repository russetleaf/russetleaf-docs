#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
set -Eeuo pipefail

# fresh-ubuntu-test.sh
#
# Tests setup-ubuntu.sh end to end on a fresh Ubuntu 24.04: runs it as a normal user
# with sudo, runs it a second time and checks that nothing changed, then runs
# check-tools.sh --system. Run as root inside a throwaway container, as CI does:
#
#   docker run --rm --privileged -v "$PWD:/repo:ro" ubuntu:24.04 \
#     /repo/scripts/workstation/tests/fresh-ubuntu-test.sh
#
# (--privileged lets the setup script set kind's file-watch limits.)
#
# This program is licensed under the terms of the GNU General Public License v3.0.

########################################
# Initialize constants, exit codes and global variables
# Arguments:
#   None
########################################
function init_script() {
  # Constants
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  readonly SCRIPT_DIR
  readonly WORKSTATION_DIR="${SCRIPT_DIR%/*}"
  readonly TEST_USER="tester"
  readonly TEST_HOME="/home/${TEST_USER}"
  readonly SNAPSHOT_DIR="/tmp/setup-snapshots"
  readonly SCRIPT_NAME="${0##*/}"

  # Exit codes
  readonly ERR_TEST_FAILED=1    # The setup script failed a check
  readonly ERR_NOT_CONTAINER=77 # Not running as root in a container
  readonly ERR_USAGE=64         # Invalid option

  # Global variables
  no_color="false"
  verbose="false"
}

########################################
# Parse script parameters
# Globals:
#   no_color, verbose (set)
# Arguments:
#   $@ (optional): Options passed to the script
########################################
function parse_params() {
  local param

  while [[ $# -gt 0 ]]; do
    param="$1"
    shift
    case "${param}" in
      -h | --help)
        usage
        exit 0
        ;;
      -n | --no-color)
        no_color="true"
        ;;
      -v | --verbose)
        verbose="true"
        ;;
      *)
        die "${ERR_USAGE}" "invalid option: ${param} (see ${SCRIPT_NAME} --help)"
        ;;
    esac
  done
}

########################################
# Usage
# Arguments:
#   None
# Outputs:
#   Writes usage instructions to stdout
########################################
function usage() {
  cat <<EOF
Usage: ${SCRIPT_NAME} [-h|--help] [-n|--no-color] [-v|--verbose]

Tests setup-ubuntu.sh end to end on a fresh Ubuntu 24.04. Run it only as root inside
a throwaway container (see the header of this file for the docker command).

Available options:
  -h|--help       Display help
  -n|--no-color   Turn off text colors
  -v|--verbose    Trace every command

Exit codes:
  0    The setup script passed every check
  1    The setup script failed a check
  64   Invalid option
  77   Not running as root in a container
  Any other non-zero code is that of the command that failed.
EOF
}

########################################
# Refuse to run anywhere but as root in a container: the test creates a user and
# installs packages
# Globals:
#   ERR_NOT_CONTAINER (read)
# Arguments:
#   None
########################################
function check_container() {
  if [[ "${EUID}" -ne 0 || ! -f /.dockerenv ]]; then
    die "${ERR_NOT_CONTAINER}" "run this only as root inside a throwaway container (see its header)"
  fi
}

########################################
# Create the test user, with passwordless sudo like a workstation's admin user
# Globals:
#   TEST_USER (read)
# Arguments:
#   None
########################################
function prepare_container() {
  log_step "Preparing the container"
  DEBIAN_FRONTEND=noninteractive apt-get update
  # cups-daemon is on every Ubuntu Desktop, and the setup script changes its settings
  DEBIAN_FRONTEND=noninteractive apt-get install -y sudo cups-daemon
  # In the sudo group (the normal Ubuntu admin rule, which asks for a password) and
  # with a NOPASSWD rule: the two together are what made `sudo -v` fail on a real
  # workstation, so the test keeps both
  useradd --create-home --shell /bin/bash --groups sudo "${TEST_USER}"
  printf '%s ALL=(ALL) NOPASSWD:ALL\n' "${TEST_USER}" >"/etc/sudoers.d/${TEST_USER}"
  chmod 0440 "/etc/sudoers.d/${TEST_USER}"
}

########################################
# Run a command as the test user, in their home directory
# Globals:
#   TEST_USER (read)
# Arguments:
#   $@ (required): Command and its arguments
########################################
function as_user() {
  # GITHUB_TOKEN (set in CI) lets mise download tools without hitting rate limits
  sudo -u "${TEST_USER}" -H --preserve-env=GITHUB_TOKEN "$@"
}

########################################
# Record everything the setup script changes, to compare two runs
# Globals:
#   SNAPSHOT_DIR, TEST_HOME, TEST_USER (read)
# Arguments:
#   $1 (required): Snapshot name
# Outputs:
#   Writes the snapshot to a file in SNAPSHOT_DIR
########################################
function snapshot() {
  local name="$1"

  mkdir -p "${SNAPSHOT_DIR}"
  {
    echo "## files"
    sha256sum "${TEST_HOME}/.bashrc" "${TEST_HOME}/.profile" /etc/sysctl.d/99-kind.conf \
      /etc/cups/cupsd.conf /etc/apt/sources.list.d/* /etc/apt/keyrings/* \
      /etc/dconf/profile/user /etc/dconf/db/local.d/00-russetleaf-screen-lock \
      /etc/dconf/db/local.d/locks/00-russetleaf-screen-lock 2>&1 || true
    echo "## firewall"
    ufw status verbose 2>&1 || true
    echo "## groups"
    id -nG "${TEST_USER}"
    echo "## packages"
    dpkg-query -W -f='${Package} ${Version}\n'
    echo "## mise global tools"
    cat "${TEST_HOME}/.config/mise/config.toml" 2>&1 || true
    echo "## uv tools"
    as_user mise exec -- uv tool list 2>&1 || true
  } >"${SNAPSHOT_DIR}/${name}.txt"
}

########################################
# Run the setup script as the test user
# Globals:
#   WORKSTATION_DIR (read)
# Arguments:
#   $1 (required): Which run this is, for the heading
########################################
function run_setup() {
  log_step "setup-ubuntu.sh, $1 run"
  as_user "${WORKSTATION_DIR}/setup-ubuntu.sh"
}

########################################
# Check that each line the setup script adds to ~/.bashrc is there exactly once
# Globals:
#   ERR_TEST_FAILED, TEST_HOME (read)
# Arguments:
#   None
########################################
function check_bashrc() {
  local hook count

  log_step "Shell hooks in ~/.bashrc"
  # shellcheck disable=SC2016  # the hooks are matched as literal text
  for hook in 'eval "$(mise activate bash)"' 'eval "$(direnv hook bash)"' \
    '[[ ":${PATH}:" == *":${HOME}/.local/bin:"* ]] || export PATH="${HOME}/.local/bin:${PATH}"'; do
    count="$(grep -cxF -- "${hook}" "${TEST_HOME}/.bashrc" || true)"
    if [[ "${count}" -ne 1 ]]; then
      die "${ERR_TEST_FAILED}" "expected '${hook}' once in ~/.bashrc, found it ${count} times"
    fi
  done
  log_ok "Each hook appears once."
}

########################################
# Check that CUPS keeps no copies of printed documents, set exactly once
# Globals:
#   ERR_TEST_FAILED (read)
# Arguments:
#   None
########################################
function check_print_spool() {
  local count

  log_step "CUPS print spool"
  count="$(grep -cE '^[[:space:]]*PreserveJobFiles[[:space:]]' /etc/cups/cupsd.conf || true)"
  if [[ "${count}" -ne 1 ]] || ! grep -qx 'PreserveJobFiles No' /etc/cups/cupsd.conf; then
    die "${ERR_TEST_FAILED}" "expected one 'PreserveJobFiles No' line in cupsd.conf, found ${count} PreserveJobFiles lines"
  fi
  log_ok "PreserveJobFiles No is set once."
}

########################################
# Check that each repository key is the one its publisher publishes (or, for
# Docker, the one pinned in setup-ubuntu.sh)
# Globals:
#   ERR_TEST_FAILED (read)
# Arguments:
#   None
########################################
function check_repo_keys() {
  local entry key expected found

  log_step "Repository keys"
  for entry in claude-code.asc:31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE \
    docker.asc:9DC858229FC7DD38854AE2D88D81803C0EBFCD88 \
    mise-archive-keyring.gpg:24853EC9F655CE80B48E6C3A8B81C9D17413A06D; do
    key="/etc/apt/keyrings/${entry%%:*}"
    expected="${entry##*:}"
    found="$(gpg --show-keys --with-colons "${key}" |
      awk -F: '$1 == "pub" { want = 1; next } $1 == "fpr" && want { print $10; want = 0 }')"
    if [[ "${found}" != "${expected}" ]]; then
      die "${ERR_TEST_FAILED}" "expected ${key} to hold the key ${expected}, found: ${found:-none}"
    fi
  done
  log_ok "Each repository key has its expected fingerprint."
}

########################################
# Check that the firewall is on and blocks incoming connections
# Globals:
#   ERR_TEST_FAILED (read)
# Arguments:
#   None
########################################
function check_firewall() {
  local status

  log_step "Firewall"
  status="$(ufw status verbose)"
  if ! grep -qx 'Status: active' <<<"${status}" || ! grep -q '^Default: deny (incoming), allow (outgoing)' <<<"${status}"; then
    die "${ERR_TEST_FAILED}" "expected ufw active, denying incoming and allowing outgoing; found: ${status}"
  fi
  log_ok "ufw is active and blocks incoming connections."
}

########################################
# Check that the screen-lock policy is in the system dconf database and locked
# Globals:
#   ERR_TEST_FAILED (read)
# Arguments:
#   None
########################################
function check_screen_lock() {
  local key

  log_step "Screen lock"
  if ! grep -qx 'system-db:local' /etc/dconf/profile/user || [[ ! -f /etc/dconf/db/local ]]; then
    die "${ERR_TEST_FAILED}" "expected the user profile to read the compiled system database /etc/dconf/db/local"
  fi
  for key in /org/gnome/desktop/session/idle-delay /org/gnome/desktop/screensaver/lock-enabled \
    /org/gnome/desktop/screensaver/lock-delay; do
    if ! grep -qxF "${key}" /etc/dconf/db/local.d/locks/00-russetleaf-screen-lock; then
      die "${ERR_TEST_FAILED}" "expected ${key} to be locked"
    fi
  done
  log_ok "The screen-lock settings are set for every user and locked."
}

########################################
# Check that the second run changed nothing
# Globals:
#   ERR_TEST_FAILED, SNAPSHOT_DIR (read)
# Arguments:
#   None
# Outputs:
#   Writes any differences to stdout
########################################
function check_idempotent() {
  log_step "Comparing the two runs"
  if ! diff -u "${SNAPSHOT_DIR}/first.txt" "${SNAPSHOT_DIR}/second.txt"; then
    die "${ERR_TEST_FAILED}" "the second run changed the system (differences above)"
  fi
  log_ok "The second run changed nothing."
}

########################################
# Run check-tools.sh --system as the test user, with mise's global tools and
# ~/.local/bin on the PATH, as in a new terminal
# Globals:
#   WORKSTATION_DIR (read)
# Arguments:
#   None
########################################
function run_check_tools() {
  log_step "check-tools.sh --system"
  # shellcheck disable=SC2016  # expanded by the test user's shell
  as_user bash -c 'export PATH="${HOME}/.local/bin:${PATH}"; mise exec -- "$0" --system' \
    "${WORKSTATION_DIR}/check-tools.sh"
}

########################################
# Main function
# Arguments:
#   $@ (optional): Options passed to the script
########################################
function main() {
  init_script
  # shellcheck source=../../lib/common.sh
  source "${WORKSTATION_DIR}/../lib/common.sh"
  install_traps
  parse_params "$@"
  init_colors "${no_color}"
  if [[ "${verbose}" == "true" ]]; then
    enable_trace
  fi

  check_container
  prepare_container
  run_setup first
  snapshot first
  run_setup second
  snapshot second
  check_bashrc
  check_print_spool
  check_repo_keys
  check_firewall
  check_screen_lock
  check_idempotent
  run_check_tools
  log_step "Result"
  log_ok "setup-ubuntu.sh works on a fresh Ubuntu 24.04, and a second run changes nothing."
}

########################################
# Invoke main function
########################################
main "$@"
