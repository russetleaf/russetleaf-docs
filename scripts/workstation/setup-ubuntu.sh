#!/usr/bin/env bash
# Set up an Ubuntu 24.04 workstation for RussetLeaf.
#
# Installs the base packages, Docker Engine (from Docker's repository, not the snap),
# kind's file-watch limits, mise and direnv with their shell hooks, and the Python
# tools installed with uv. Safe to run again: each step checks or overwrites its own
# files instead of appending duplicates.
#
# The per-repo CLI tools (terraform, kubectl, talosctl, ...) are not installed here:
# run `mise install` inside each repo, which installs the versions pinned in its
# .mise.toml (the same versions CI uses).
#
# Usage: scripts/workstation/setup-ubuntu.sh [--with-localstack]
# See "Local workstation setup" in docs/phase-1-russetleaf-dev/plan.md.

set -euo pipefail

APT_PACKAGES=(
  git curl wget unzip jq ca-certificates gnupg
  python3 python3-venv shellcheck direnv wireguard-tools
)
DOCKER_PACKAGES=(
  docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
)
# Packages that conflict with Docker Engine (Docker's own list for Ubuntu).
DOCKER_CONFLICTS=(
  docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc
)
UV_TOOLS=(pre-commit checkov semgrep ruff pip-audit prowler zizmor)

with_localstack=false

log() { printf '\n==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

# Add a line to a file only if it is not already there.
append_once() {
  local line=$1 file=$2
  touch "$file"
  grep -qxF -- "$line" "$file" || printf '%s\n' "$line" >>"$file"
}

parse_args() {
  while (($#)); do
    case $1 in
      --with-localstack) with_localstack=true ;;
      -h | --help)
        sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
        exit 0
        ;;
      *) die "unknown option: $1 (see --help)" ;;
    esac
    shift
  done
}

preflight() {
  [[ $EUID -ne 0 ]] || die "run as your normal user, not root (the script uses sudo where needed)"
  # shellcheck source=/dev/null
  . /etc/os-release
  [[ ${ID:-} == ubuntu && ${VERSION_ID:-} == 24.04 ]] ||
    die "this script is for Ubuntu 24.04 (found ${PRETTY_NAME:-unknown})"
  if command -v snap >/dev/null && snap list docker >/dev/null 2>&1; then
    die "the Docker snap is installed; remove it first with: sudo snap remove docker"
  fi
  local conflicts=() pkg
  for pkg in "${DOCKER_CONFLICTS[@]}"; do
    if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q 'install ok installed'; then
      conflicts+=("$pkg")
    fi
  done
  ((${#conflicts[@]} == 0)) ||
    die "packages that conflict with Docker Engine are installed; remove them first with: sudo apt-get remove ${conflicts[*]}"
  sudo -v
}

install_base_packages() {
  log "Base packages"
  sudo apt-get update
  sudo apt-get install -y "${APT_PACKAGES[@]}"
}

# Add a signed apt repository: its key goes in /etc/apt/keyrings, its source list in
# /etc/apt/sources.list.d. Both files are overwritten, so a rerun cannot duplicate them.
add_apt_repo() {
  local name=$1 key_url=$2 key_file=$3 line=$4
  sudo install -m 0755 -d /etc/apt/keyrings
  if [[ $key_file == *.gpg ]]; then
    curl -fsSL "$key_url" | gpg --dearmor | sudo tee "$key_file" >/dev/null
  else
    sudo curl -fsSL "$key_url" -o "$key_file"
  fi
  sudo chmod a+r "$key_file"
  printf '%s\n' "$line" | sudo tee "/etc/apt/sources.list.d/$name.list" >/dev/null
}

install_docker() {
  log "Docker Engine (from Docker's repository)"
  local arch
  arch=$(dpkg --print-architecture)
  # VERSION_CODENAME comes from /etc/os-release, read in preflight.
  add_apt_repo docker https://download.docker.com/linux/ubuntu/gpg /etc/apt/keyrings/docker.asc \
    "deb [arch=$arch signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $VERSION_CODENAME stable"
  sudo apt-get update
  sudo apt-get install -y "${DOCKER_PACKAGES[@]}"
  if ! id -nG "$USER" | grep -qw docker; then
    sudo usermod -aG docker "$USER"
    needs_relogin=true
  fi
}

set_kind_limits() {
  log "File-watch limits for kind"
  printf '%s\n' 'fs.inotify.max_user_watches=524288' 'fs.inotify.max_user_instances=512' |
    sudo tee /etc/sysctl.d/99-kind.conf >/dev/null
  sudo sysctl --system >/dev/null
}

install_mise() {
  log "mise (from its signed apt repository) and the shell hooks"
  local arch
  arch=$(dpkg --print-architecture)
  add_apt_repo mise https://mise.jdx.dev/gpg-key.pub /etc/apt/keyrings/mise-archive-keyring.gpg \
    "deb [signed-by=/etc/apt/keyrings/mise-archive-keyring.gpg arch=$arch] https://mise.jdx.dev/deb stable main"
  sudo apt-get update
  sudo apt-get install -y mise
  # Single quotes on purpose: these lines run later, in each new shell.
  # shellcheck disable=SC2016
  append_once 'eval "$(mise activate bash)"' "$HOME/.bashrc"
  # shellcheck disable=SC2016
  append_once 'eval "$(direnv hook bash)"' "$HOME/.bashrc"
}

install_python_tools() {
  log "uv and the Python tools"
  # uv itself is installed globally with mise; each repo can still pin its own version.
  mise use --global uv@latest
  local tools=("${UV_TOOLS[@]}") tool
  if [[ $with_localstack == true ]]; then
    tools+=(localstack)
  fi
  for tool in "${tools[@]}"; do
    if mise exec -- uv tool list 2>/dev/null | grep -q "^$tool "; then
      echo "$tool: already installed"
    else
      mise exec -- uv tool install "$tool"
    fi
  done
  mise exec -- uv tool update-shell >/dev/null
}

main() {
  parse_args "$@"
  needs_relogin=false
  preflight
  install_base_packages
  install_docker
  set_kind_limits
  install_mise
  install_python_tools

  log "Done"
  cat <<EOF
Next:
  1. $([[ $needs_relogin == true ]] && echo "Log out and back in, so the docker group applies." || echo "Open a new terminal (or run: source ~/.bashrc).")
  2. In each repo, run: mise install
  3. Check everything with: scripts/workstation/check-tools.sh
EOF
}

main "$@"
