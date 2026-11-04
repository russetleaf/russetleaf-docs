#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
set -Eeuo pipefail

# setup-ubuntu.sh
#
# Sets up an Ubuntu 24.04 workstation for RussetLeaf: the base packages, Docker
# Engine (from Docker's repository, not the snap), kind's file-watch limits, mise
# and direnv with their shell hooks, and the Python tools installed with uv. Safe to
# run again: each step checks or overwrites its own files instead of appending.
#
# The per-repo CLI tools (terraform, kubectl, talosctl, ...) are installed later by
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
    git curl wget unzip jq ca-certificates gnupg
    python3 python3-venv shellcheck direnv wireguard-tools
  )
  readonly DOCKER_PACKAGES=(
    docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  )
  # Packages that conflict with Docker Engine (Docker's own list for Ubuntu)
  readonly DOCKER_CONFLICTS=(
    docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc
  )
  readonly UV_TOOLS=(pre-commit checkov semgrep ruff pip-audit prowler zizmor)
  readonly KEYRING_DIR="/etc/apt/keyrings"
  readonly SOURCES_DIR="/etc/apt/sources.list.d"
  readonly BASHRC="${HOME}/.bashrc"

  # Exit codes (any other non-zero code is that of a failed command)
  readonly ERR_USAGE=64          # Invalid option
  readonly ERR_UNSUPPORTED=69    # Not Ubuntu 24.04
  readonly ERR_ROOT=77           # Run as root
  readonly ERR_CONFLICT=78       # Docker snap or conflicting packages installed

  # Global variables
  no_color="false"
  verbose="false"
  with_localstack="false"
  needs_relogin="false"
  current_user="$(id -un)"
}

########################################
# Parse script parameters
# Globals:
#   no_color, verbose, with_localstack (set)
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
      -l | --with-localstack)
        with_localstack="true"
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
Usage: ${SCRIPT_NAME} [-h|--help] [-l|--with-localstack] [-n|--no-color] [-v|--verbose]

Sets up an Ubuntu 24.04 workstation for RussetLeaf: base packages, Docker Engine,
kind's file-watch limits, mise and direnv, and the Python tools (with uv).
Run it as a normal user; it uses sudo where needed. Safe to run again.

Available options:
  -h|--help              Display help
  -l|--with-localstack   Also install the LocalStack CLI
  -n|--no-color          Turn off text colors (also off when NO_COLOR is set,
                         or the output is not a terminal)
  -v|--verbose           Trace every command

Exit codes:
  0    Success
  64   Invalid option
  69   Not Ubuntu 24.04
  77   Run as root
  78   The Docker snap or a conflicting package is installed
  Any other non-zero code is that of the command that failed.
EOF
}

########################################
# Check the machine before changing anything
# Globals:
#   DOCKER_CONFLICTS, ERR_* (read)
# Arguments:
#   None
########################################
function preflight() {
  local conflicts=() pkg

  if [[ "${EUID}" -eq 0 ]]; then
    die "${ERR_ROOT}" "run as your normal user, not root (the script uses sudo where needed)"
  fi

  # shellcheck source=/dev/null
  . /etc/os-release
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

  # Ask for the sudo password once, at the start
  sudo -v
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
# Add a signed apt repository. The key and the source list are overwritten, so a
# rerun cannot duplicate them.
# Globals:
#   KEYRING_DIR, SOURCES_DIR (read)
# Arguments:
#   $1 (required): Name of the source list (without .list)
#   $2 (required): URL of the signing key
#   $3 (required): Key file; a .gpg name is converted from ASCII armor
#   $4 (required): The deb line
########################################
function add_apt_repo() {
  local name="$1" key_url="$2" key_file="$3" deb_line="$4"

  sudo install -m 0755 -d "${KEYRING_DIR}"
  if [[ "${key_file}" == *.gpg ]]; then
    curl -fsSL "${key_url}" | gpg --dearmor | sudo tee "${key_file}" >/dev/null
  else
    sudo curl -fsSL "${key_url}" -o "${key_file}"
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
# Install Docker Engine from Docker's repository, and add the user to the docker
# group
# Globals:
#   DOCKER_PACKAGES, KEYRING_DIR, VERSION_CODENAME, current_user (read)
#   needs_relogin (set)
# Arguments:
#   None
########################################
function install_docker() {
  local arch

  log_step "Docker Engine (from Docker's repository)"
  arch="$(dpkg --print-architecture)"
  # VERSION_CODENAME comes from /etc/os-release, read in preflight
  add_apt_repo docker https://download.docker.com/linux/ubuntu/gpg "${KEYRING_DIR}/docker.asc" \
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
# Install mise from its signed apt repository, and add the mise and direnv hooks to
# ~/.bashrc
# Globals:
#   BASHRC, KEYRING_DIR (read)
# Arguments:
#   None
########################################
function install_mise() {
  local arch

  log_step "mise (from its signed apt repository) and the shell hooks"
  arch="$(dpkg --print-architecture)"
  add_apt_repo mise https://mise.jdx.dev/gpg-key.pub "${KEYRING_DIR}/mise-archive-keyring.gpg" \
    "deb [signed-by=${KEYRING_DIR}/mise-archive-keyring.gpg arch=${arch}] https://mise.jdx.dev/deb stable main"
  apt_get update
  apt_get install -y mise

  # Single quotes on purpose: these lines run later, in each new shell
  # shellcheck disable=SC2016
  append_once 'eval "$(mise activate bash)"' "${BASHRC}"
  # shellcheck disable=SC2016
  append_once 'eval "$(direnv hook bash)"' "${BASHRC}"
}

########################################
# Install uv globally with mise, then the Python tools with uv
# Globals:
#   UV_TOOLS, with_localstack (read)
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
  if [[ "${with_localstack}" == "true" ]]; then
    tools+=(localstack)
  fi

  installed="$(mise exec -- uv tool list 2>/dev/null || true)"
  for tool in "${tools[@]}"; do
    if grep -q "^${tool} " <<<"${installed}"; then
      printf '%s: already installed\n' "${tool}"
    else
      mise exec -- uv tool install "${tool}"
    fi
  done
  mise exec -- uv tool update-shell >/dev/null
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
  local first_step="Open a new terminal (or run: source ~/.bashrc)."

  if [[ "${needs_relogin}" == "true" ]]; then
    first_step="Log out and back in, so the docker group applies."
  fi
  log_step "Done"
  log_ok "The workstation is set up."
  cat <<EOF
Next:
  1. ${first_step}
  2. In each repo, run: mise install
  3. Check everything with: scripts/workstation/check-tools.sh
EOF
}

########################################
# Main function
# Arguments:
#   $@ (optional): Options passed to the script
########################################
function main() {
  init_script
  # shellcheck source=lib/common.sh
  source "${SCRIPT_DIR}/lib/common.sh"
  install_traps
  parse_params "$@"
  init_colors "${no_color}"
  if [[ "${verbose}" == "true" ]]; then
    enable_trace
  fi

  preflight
  install_base_packages
  install_docker
  set_kind_limits
  install_mise
  install_python_tools
  print_next_steps
}

########################################
# Invoke main function
########################################
main "$@"
