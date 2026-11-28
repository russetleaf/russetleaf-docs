#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
set -Eeuo pipefail

# setup-ubuntu.sh
#
# Sets up an Ubuntu 24.04 workstation for RussetLeaf: the base packages, the
# firewall (ufw, blocking incoming connections), a screen lock users cannot turn
# off, Docker Engine (from Docker's repository, not the snap, with its key's
# fingerprint checked), kind's file-watch limits, no copies of printed documents
# kept by CUPS, Claude Code (from Anthropic's
# repository), mise and direnv with their shell hooks, the Bitwarden CLI and
# desktop app, the GitHub CLI and Opengrep, and the Python tools installed with uv. Safe to run again: each step checks or overwrites its own files instead of appending. A
# rerun also upgrades the packages it installs, if newer versions exist.
#
# The per-repo CLI tools (tofu, kubectl, talosctl, ...) are installed later by
# `mise install` in each repo, from the versions pinned in its .mise.toml.
#
# See "Local workstation setup" in docs/phase-1-russetleaf-dev/plan.md.
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
  readonly SCRIPT_NAME="${0##*/}"
  readonly APT_PACKAGES=(
    git curl wget unzip jq ca-certificates gnupg scdaemon pcscd paperkey exfatprogs yubikey-manager
    libpam-u2f pamu2fcfg
    python3 python3-venv shellcheck shfmt bats direnv wireguard-tools procps vim
    ufw dconf-cli
  )
  readonly DOCKER_PACKAGES=(
    docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  )
  # Packages that conflict with Docker Engine (Docker's own list for Ubuntu)
  readonly DOCKER_CONFLICTS=(
    docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc
  )
  readonly UV_TOOLS=(pre-commit checkov ruff pip-audit prowler zizmor)
  # The same Vale version as the docs CI workflow (.github/workflows/docs.yml)
  readonly VALE_VERSION="3.25.1"
  # Opengrep 2.0.0 renamed its Linux release files (opengrep_manylinux_x86 became
  # opengrep_linux_x86) and mise's aqua registry still expects the old names, so
  # "latest" fails to install; pinned to the last 1.x release until the registry
  # catches up (improvement I1-9)
  readonly OPENGREP_VERSION="1.33.1"
  # The primary-key fingerprints of the apt repositories' signing keys. A
  # downloaded key with any other fingerprint is removed, and the script stops.
  # Anthropic's, as published in its setup documentation (code.claude.com/docs/en/setup)
  readonly CLAUDE_CODE_KEY_FPR="31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE"
  # mise's release key, as published in its installation documentation
  # (mise.jdx.dev/installing-mise.html); its apt repository is signed with the same key
  readonly MISE_KEY_FPR="24853EC9F655CE80B48E6C3A8B81C9D17413A06D"
  # Docker's, pinned from the key served over HTTPS at download.docker.com (the key
  # Docker has signed its repositories with since 2017; its install page no longer
  # prints the fingerprint). A mismatch means a rotated or replaced key: confirm the
  # new key with Docker before changing this value.
  readonly DOCKER_KEY_FPR="9DC858229FC7DD38854AE2D88D81803C0EBFCD88"
  # The tests point this at a test folder, to check the screen-lock profile
  readonly DCONF_DIR="${RL_DCONF_DIR:-/etc/dconf}"
  # The screen locks after this many seconds without activity (CIS: at most 900)
  readonly IDLE_DELAY=600
  readonly KEYRING_DIR="/etc/apt/keyrings"
  readonly SOURCES_DIR="/etc/apt/sources.list.d"
  readonly BASHRC="${HOME}/.bashrc"
  readonly CUPSD_CONF="/etc/cups/cupsd.conf"
  # The tests point this at a fake file, to check the Ubuntu 24.04 requirement
  readonly OS_RELEASE="${RL_OS_RELEASE:-/etc/os-release}"

  # Exit codes (any other non-zero code is that of a failed command)
  readonly ERR_USAGE=64       # Invalid option
  readonly ERR_BAD_KEY=65     # A downloaded repository key has the wrong fingerprint
  readonly ERR_UNSUPPORTED=69 # Not Ubuntu 24.04
  readonly ERR_ROOT=77        # Run as root
  readonly ERR_CONFLICT=78    # Docker snap or conflicting packages installed

  # Global variables
  no_color="false"
  verbose="false"
  needs_relogin="false"
  current_user="$(id -un)"
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

Sets up an Ubuntu 24.04 workstation for RussetLeaf: base packages, the firewall
(ufw), a locked screen-lock policy, Docker Engine, kind's file-watch limits, no copies of printed documents kept by CUPS, mise and
direnv, the Bitwarden CLI (bw) and desktop app (snap), the GitHub CLI (gh) and
Opengrep, and the Python tools (with uv).
Run it as a normal user; it uses sudo where needed. Safe to run again.

Available options:
  -h|--help              Display help
  -n|--no-color          Turn off text colors (also off when NO_COLOR is set,
                         or the output is not a terminal)
  -v|--verbose           Trace every command

Exit codes:
  0    Success
  64   Invalid option
  65   A repository key does not have its expected fingerprint
  69   Not Ubuntu 24.04
  77   Run as root
  78   The Docker snap or a conflicting package is installed
  Any other non-zero code is that of the command that failed.
EOF
}

########################################
# Check the machine before changing anything
# Globals:
#   DOCKER_CONFLICTS, OS_RELEASE, ERR_* (read)
# Arguments:
#   None
########################################
function preflight() {
  local conflicts=() pkg

  if [[ "${EUID}" -eq 0 ]]; then
    die "${ERR_ROOT}" "run as your normal user, not root (the script uses sudo where needed)"
  fi

  # shellcheck source=/dev/null
  . "${OS_RELEASE}"
  if [[ "${ID:-}" != "ubuntu" || "${VERSION_ID:-}" != "24.04" ]]; then
    die "${ERR_UNSUPPORTED}" "this script is for Ubuntu 24.04 (found ${PRETTY_NAME:-an unknown system})"
  fi

  if command -v snap >/dev/null && snap list docker >/dev/null 2>&1; then
    die "${ERR_CONFLICT}" "the Docker snap is installed; remove it first with: sudo snap remove docker"
  fi

  for pkg in "${DOCKER_CONFLICTS[@]}"; do
    if dpkg-query -W -f='${Status}' "${pkg}" 2>/dev/null | grep -q 'install ok installed'; then
      conflicts+=("${pkg}")
    fi
  done
  if [[ ${#conflicts[@]} -gt 0 ]]; then
    die "${ERR_CONFLICT}" "packages that conflict with Docker Engine are installed; remove them first with: sudo apt-get remove ${conflicts[*]}"
  fi

  # Ask for the sudo password once, at the start. Not `sudo -v`: by default it asks
  # for a password unless every sudoers rule for the user is NOPASSWD, even when a
  # NOPASSWD rule would let the commands themselves run without one.
  sudo true
}

########################################
# Run apt-get without interactive prompts
# Arguments:
#   $@ (required): apt-get arguments
########################################
function apt_get() {
  sudo DEBIAN_FRONTEND=noninteractive apt-get "$@"
}

########################################
# Add a line to a file, unless the file already has it
# Arguments:
#   $1 (required): Line to add
#   $2 (required): File
########################################
function append_once() {
  local line="$1" file="$2"

  touch "${file}"
  if ! grep -qxF -- "${line}" "${file}"; then
    printf '%s\n' "${line}" >>"${file}"
  fi
}

########################################
# Add a signed apt repository, after checking that the downloaded key's primary-key
# fingerprint is the expected one. The key and the source list are overwritten, so
# a rerun cannot duplicate them; a key with another fingerprint is removed with its
# source list, and the script stops.
# Globals:
#   ERR_BAD_KEY, KEYRING_DIR, SOURCES_DIR (read)
# Arguments:
#   $1 (required): Name of the source list (without .list)
#   $2 (required): URL of the signing key
#   $3 (required): Key file; a .gpg name is converted from ASCII armor
#   $4 (required): The key's expected primary-key fingerprint
#   $5 (required): The deb line
########################################
function add_apt_repo() {
  local name="$1" key_url="$2" key_file="$3" expected="$4" deb_line="$5" found

  sudo install -m 0755 -d "${KEYRING_DIR}"
  if [[ "${key_file}" == *.gpg ]]; then
    curl -fsSL "${key_url}" | gpg --dearmor | sudo tee "${key_file}" >/dev/null
  else
    sudo curl -fsSL "${key_url}" -o "${key_file}"
  fi
  # The fingerprint of each primary key (the fpr record after a pub record), not
  # of its subkeys
  found="$(gpg --show-keys --with-colons "${key_file}" |
    awk -F: '$1 == "pub" { want = 1; next } $1 == "fpr" && want { print $10; want = 0 }')"
  if [[ "${found}" != "${expected}" ]]; then
    sudo rm -f "${key_file}" "${SOURCES_DIR}/${name}.list"
    die "${ERR_BAD_KEY}" "the ${name} repository key does not have the expected fingerprint ${expected} (found: ${found:-none}); removed it"
  fi
  sudo chmod a+r "${key_file}"
  printf '%s\n' "${deb_line}" | sudo tee "${SOURCES_DIR}/${name}.list" >/dev/null
}

########################################
# Install the base packages
# Globals:
#   APT_PACKAGES (read)
# Arguments:
#   None
########################################
function install_base_packages() {
  log_step "Base packages"
  apt_get update
  apt_get install -y "${APT_PACKAGES[@]}"
}

########################################
# Turn on the firewall: incoming connections blocked, outgoing allowed (the CIS
# Benchmarks expect a host firewall that denies by default). Replies to the
# workstation's own connections, the WireGuard tunnel's included, still arrive.
# Ports that Docker publishes bypass ufw, so containers publish to 127.0.0.1 only
# (see the plan's workstation configuration).
# Arguments:
#   None
########################################
function set_firewall() {
  log_step "Firewall (ufw): incoming connections blocked"
  sudo ufw default deny incoming
  sudo ufw default allow outgoing
  # --force: enable without asking whether to keep SSH connections open
  sudo ufw --force enable
}

########################################
# Lock the screen after IDLE_DELAY seconds without activity, set for every user in
# the system dconf database and locked there, so a user's own settings cannot turn
# it off or lengthen it (the CIS Benchmarks' GDM screen-lock checks). The files are
# overwritten, so a rerun changes nothing.
# Globals:
#   DCONF_DIR, IDLE_DELAY (read)
# Arguments:
#   None
########################################
function set_screen_lock() {
  local profile="${DCONF_DIR}/profile/user" db_dir="${DCONF_DIR}/db/local.d"

  log_step "Screen lock: after $((IDLE_DELAY / 60)) minutes, and users cannot turn it off"
  sudo install -m 0755 -d "${DCONF_DIR}/profile" "${db_dir}/locks"
  # The user profile reads the user's own settings, then the system database, which
  # holds the locked keys. Ubuntu ships no user profile; an existing one gets the
  # system database added at its end.
  if [[ ! -f "${profile}" ]]; then
    printf '%s\n' 'user-db:user' 'system-db:local' | sudo tee "${profile}" >/dev/null
  elif ! grep -qx 'system-db:local' "${profile}"; then
    printf '%s\n' 'system-db:local' | sudo tee -a "${profile}" >/dev/null
  fi
  printf '%s\n' '# RussetLeaf: lock the screen when the workstation is left (setup-ubuntu.sh)' \
    '[org/gnome/desktop/session]' "idle-delay=uint32 ${IDLE_DELAY}" '' \
    '[org/gnome/desktop/screensaver]' 'lock-enabled=true' 'lock-delay=uint32 0' |
    sudo tee "${db_dir}/00-russetleaf-screen-lock" >/dev/null
  printf '%s\n' '/org/gnome/desktop/session/idle-delay' \
    '/org/gnome/desktop/screensaver/lock-enabled' '/org/gnome/desktop/screensaver/lock-delay' |
    sudo tee "${db_dir}/locks/00-russetleaf-screen-lock" >/dev/null
  sudo dconf update
}

########################################
# Install Docker Engine from Docker's repository, and add the user to the docker
# group
# Globals:
#   DOCKER_KEY_FPR, DOCKER_PACKAGES, KEYRING_DIR, VERSION_CODENAME, current_user (read)
#   needs_relogin (set)
# Arguments:
#   None
########################################
function install_docker() {
  local arch

  log_step "Docker Engine (from Docker's repository)"
  arch="$(dpkg --print-architecture)"
  # VERSION_CODENAME comes from the os-release file, read in preflight
  add_apt_repo docker https://download.docker.com/linux/ubuntu/gpg "${KEYRING_DIR}/docker.asc" "${DOCKER_KEY_FPR}" \
    "deb [arch=${arch} signed-by=${KEYRING_DIR}/docker.asc] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable"
  apt_get update
  apt_get install -y "${DOCKER_PACKAGES[@]}"

  if ! id -nG "${current_user}" | grep -qw docker; then
    sudo usermod -aG docker "${current_user}"
    needs_relogin="true"
  fi
}

########################################
# Raise the file-watch limits kind needs (otherwise pods fail with "too many open
# files")
# Arguments:
#   None
########################################
function set_kind_limits() {
  log_step "File-watch limits for kind"
  printf '%s\n' 'fs.inotify.max_user_watches=524288' 'fs.inotify.max_user_instances=512' |
    sudo tee /etc/sysctl.d/99-kind.conf >/dev/null
  sudo sysctl --system >/dev/null
}

########################################
# Keep no copy of a printed document in the CUPS spool once it has printed. By
# default CUPS keeps each one on disk for a day, and the break-glass kit is
# printed from memory so that it never reaches the disk. Nothing to do where CUPS
# is not installed.
# Globals:
#   CUPSD_CONF (read)
# Arguments:
#   None
########################################
function set_print_spool() {
  log_step "Printing: no copies kept after a document prints"
  if [[ ! -f "${CUPSD_CONF}" ]]; then
    printf 'CUPS is not installed: nothing to change\n'
    return 0
  fi
  if grep -qx 'PreserveJobFiles No' "${CUPSD_CONF}"; then
    printf 'Already set\n'
    return 0
  fi
  sudo sed -i -e '/^[[:space:]]*PreserveJobFiles[[:space:]]/d' -e '/^# RussetLeaf: no copies of printed documents/d' "${CUPSD_CONF}"
  printf '%s\n' '# RussetLeaf: no copies of printed documents (setup-ubuntu.sh)' 'PreserveJobFiles No' |
    sudo tee -a "${CUPSD_CONF}" >/dev/null
  # A container (the CI test) has no running service to restart
  if systemctl is-active --quiet cups 2>/dev/null; then
    sudo systemctl restart cups
  fi
}

########################################
# Install Claude Code from Anthropic's signed apt repository (the stable channel),
# after checking that the downloaded key has the published fingerprint. Updates
# arrive with the system's other package updates.
# Globals:
#   CLAUDE_CODE_KEY_FPR, KEYRING_DIR (read)
# Arguments:
#   None
########################################
function install_claude_code() {
  local key_file="${KEYRING_DIR}/claude-code.asc"

  log_step "Claude Code (from Anthropic's signed apt repository)"
  add_apt_repo claude-code https://downloads.claude.ai/keys/claude-code.asc "${key_file}" "${CLAUDE_CODE_KEY_FPR}" \
    "deb [signed-by=${key_file}] https://downloads.claude.ai/claude-code/apt/stable stable main"
  apt_get update
  apt_get install -y claude-code
}

########################################
# Install mise from its signed apt repository, and add the mise and direnv hooks,
# and ~/.local/bin on the PATH, to ~/.bashrc
# Globals:
#   BASHRC, KEYRING_DIR, MISE_KEY_FPR (read)
# Arguments:
#   None
########################################
function install_mise() {
  local arch

  log_step "mise (from its signed apt repository) and the shell hooks"
  arch="$(dpkg --print-architecture)"
  add_apt_repo mise https://mise.jdx.dev/gpg-key.pub "${KEYRING_DIR}/mise-archive-keyring.gpg" "${MISE_KEY_FPR}" \
    "deb [signed-by=${KEYRING_DIR}/mise-archive-keyring.gpg arch=${arch}] https://mise.jdx.dev/deb stable main"
  apt_get update
  apt_get install -y mise

  # Single quotes on purpose: these lines run later, in each new shell
  # shellcheck disable=SC2016
  append_once 'eval "$(mise activate bash)"' "${BASHRC}"
  # shellcheck disable=SC2016
  append_once 'eval "$(direnv hook bash)"' "${BASHRC}"
  # uv installs the Python tools into ~/.local/bin
  # shellcheck disable=SC2016
  append_once '[[ ":${PATH}:" == *":${HOME}/.local/bin:"* ]] || export PATH="${HOME}/.local/bin:${PATH}"' "${BASHRC}"
}

########################################
# Install the Bitwarden CLI (bw) globally with mise, which verifies the release's
# checksum
# Arguments:
#   None
########################################
function install_bitwarden_cli() {
  log_step "The Bitwarden CLI (bw)"
  mise use --global bitwarden@latest
}

########################################
# Install the Bitwarden desktop app, the official snap published by Bitwarden, and
# connect it to the desktop's secret service, as Bitwarden's documentation asks on
# every Linux distribution. Snaps update themselves, so a rerun only checks it.
# Nothing to do where snapd is not running (a container, such as the CI test).
# Arguments:
#   None
########################################
function install_bitwarden_desktop() {
  log_step "The Bitwarden desktop app (snap)"
  if ! command -v snap >/dev/null || ! systemctl is-active --quiet snapd.socket 2>/dev/null; then
    printf 'snapd is not running: skipped (install it later with: sudo snap install bitwarden)\n'
    return 0
  fi
  if snap list bitwarden >/dev/null 2>&1; then
    printf 'Already installed (the snap updates itself)\n'
  else
    sudo snap install bitwarden
  fi
  sudo snap connect bitwarden:password-manager-service
}

########################################
# Install the GitHub CLI (gh) globally with mise, which verifies the release's
# checksum. It is needed before any repo exists (to sign in, and to create the
# organization's repos); each repo can still pin its own version in its .mise.toml.
# Arguments:
#   None
########################################
function install_github_cli() {
  log_step "The GitHub CLI (gh)"
  mise use --global gh@latest
}

########################################
# Install Opengrep (static analysis, the open-source fork of Semgrep) globally with
# mise, which verifies the release's checksum
# Globals:
#   OPENGREP_VERSION (read)
# Arguments:
#   None
########################################
function install_opengrep() {
  log_step "Opengrep ${OPENGREP_VERSION}"
  mise use --global "opengrep@${OPENGREP_VERSION}"
}

########################################
# Install Vale (the prose linter of the documentation style guide) globally with
# mise, which verifies the release's checksum, at the version CI uses
# Globals:
#   VALE_VERSION (read)
# Arguments:
#   None
########################################
function install_vale() {
  log_step "Vale ${VALE_VERSION}"
  mise use --global "vale@${VALE_VERSION}"
}

########################################
# Install uv globally with mise, then the Python tools with uv
# Globals:
#   UV_TOOLS (read)
# Arguments:
#   None
# Outputs:
#   Writes each tool's status to stdout
########################################
function install_python_tools() {
  local tools=("${UV_TOOLS[@]}") tool installed

  log_step "uv and the Python tools"
  # Each repo can still pin its own uv version in its .mise.toml
  mise use --global uv@latest

  installed="$(mise exec -- uv tool list 2>/dev/null || true)"
  for tool in "${tools[@]}"; do
    if grep -q "^${tool} " <<<"${installed}"; then
      printf '%s: already installed\n' "${tool}"
    else
      mise exec -- uv tool install "${tool}"
    fi
  done
}

########################################
# Print the next steps
# Globals:
#   needs_relogin (read)
# Arguments:
#   None
# Outputs:
#   Writes the next steps to stdout
########################################
function print_next_steps() {
  local first_step="Log out and back in, so the screen-lock policy applies."

  if [[ "${needs_relogin}" == "true" ]]; then
    first_step="Log out and back in, so the docker group and the screen-lock policy apply."
  fi
  log_step "Done"
  log_ok "The workstation is set up."
  cat <<EOF
Next:
  1. ${first_step}
  2. Check what this script installed with: scripts/workstation/check-tools.sh --system
  3. Later, in each code repo (from step 1.1), run "mise install" to get the tools
     its .mise.toml pins, then check them too with: scripts/workstation/check-tools.sh
EOF
}

########################################
# Main function
# Arguments:
#   $@ (optional): Options passed to the script
########################################
function main() {
  init_script
  # shellcheck source=../lib/common.sh
  source "${SCRIPT_DIR}/../lib/common.sh"
  install_traps
  parse_params "$@"
  init_colors "${no_color}"
  if [[ "${verbose}" == "true" ]]; then
    enable_trace
  fi

  preflight
  install_base_packages
  set_firewall
  set_screen_lock
  install_docker
  set_kind_limits
  set_print_spool
  install_claude_code
  install_mise
  install_bitwarden_cli
  install_bitwarden_desktop
  install_github_cli
  install_opengrep
  install_vale
  install_python_tools
  print_next_steps
}

########################################
# Invoke main function
########################################
main "$@"
