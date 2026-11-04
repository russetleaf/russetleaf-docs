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

  # Exit codes
  readonly ERR_TEST_FAILED=1     # The setup script failed a check
  readonly ERR_NOT_CONTAINER=77  # Not running as root in a container
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
  DEBIAN_FRONTEND=noninteractive apt-get install -y sudo
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
      /etc/apt/sources.list.d/* /etc/apt/keyrings/* 2>&1 || true
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
#   None
########################################
function main() {
  init_script
  # shellcheck source=../lib/common.sh
  source "${WORKSTATION_DIR}/lib/common.sh"
  install_traps
  init_colors "false"

  check_container
  prepare_container
  run_setup first
  snapshot first
  run_setup second
  snapshot second
  check_bashrc
  check_idempotent
  run_check_tools
  log_step "Result"
  log_ok "setup-ubuntu.sh works on a fresh Ubuntu 24.04, and a second run changes nothing."
}

########################################
# Invoke main function
########################################
main "$@"
