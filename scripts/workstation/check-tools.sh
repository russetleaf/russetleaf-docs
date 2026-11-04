#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
set -Eeuo pipefail

# check-tools.sh
#
# Reports the version of every RussetLeaf workstation tool, and fails if a required
# one is missing. The per-repo tools come from each repo's .mise.toml, so run it from
# inside a project repo (after `mise install`) to check them; before the repos exist,
# use --system to check only what setup-ubuntu.sh installs.
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
  readonly VERSION_TIMEOUT=15 # Seconds to wait for a tool's version command
  readonly VERSION_PATTERN='[0-9]+\.[0-9]+(\.[0-9]+)?'

  # Exit codes
  readonly ERR_MISSING=1 # A required tool is missing
  readonly ERR_USAGE=64  # Invalid option

  # Global variables
  no_color="false"
  verbose="false"
  system_only="false"
  missing=0
}

########################################
# Parse script parameters
# Globals:
#   no_color, verbose, system_only (set)
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
      -s | --system)
        system_only="true"
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
Usage: ${SCRIPT_NAME} [-h|--help] [-n|--no-color] [-s|--system] [-v|--verbose]

Reports the version of every RussetLeaf workstation tool, and fails if a required
one is missing. Run it inside a project repo to check that repo's pinned tools too.

Available options:
  -h|--help        Display help
  -n|--no-color    Turn off text colors (also off when NO_COLOR is set, or the
                   output is not a terminal)
  -s|--system      Check only the tools setup-ubuntu.sh installs
  -v|--verbose     Trace every command

Exit codes:
  0    Every required tool is installed
  1    At least one required tool is missing
  64   Invalid option
EOF
}

########################################
# Print a section heading
# Arguments:
#   $1 (required): Heading text
# Outputs:
#   Writes the heading to stdout
########################################
function section() {
  printf '\n%s%s%s\n' "${C_BLUE}" "$1" "${C_RESET}"
}

########################################
# Print one result line
# Arguments:
#   $1 (required): Tool name
#   $2 (required): Version or status
#   $3 (optional): Color for the status
# Outputs:
#   Writes the result to stdout
########################################
function print_result() {
  local name="$1" status="$2" color="${3:-}"

  printf '  %-26s %s%s%s\n' "${name}" "${color}" "${status}" "${C_RESET}"
}

########################################
# Check that a tool is on the PATH, and show its version
# Globals:
#   VERSION_PATTERN, VERSION_TIMEOUT (read)
#   missing (incremented)
# Arguments:
#   $1 (required): Command to look up on the PATH
#   $2 (required): "required" or "optional"
#   $@ (required): The version command, after the first two arguments
# Outputs:
#   Writes the result to stdout; the version shown is the first "x.y" or "x.y.z" in
#   the version command's output
########################################
function check_tool() {
  local name="$1" need="$2" output version
  shift 2

  if ! command -v "${name}" >/dev/null 2>&1; then
    if [[ "${need}" == "optional" ]]; then
      print_result "${name}" "not installed (optional)" "${C_YELLOW}"
    else
      print_result "${name}" "MISSING" "${C_RED}"
      missing=$((missing + 1))
    fi
    return 0
  fi

  output="$(timeout "${VERSION_TIMEOUT}" "$@" 2>&1 || true)"
  version="$(grep -oE "${VERSION_PATTERN}" <<<"${output}" | head -n 1 || true)"
  print_result "${name}" "${version:-installed (version not shown)}"
}

########################################
# Check the packages installed with apt
# Arguments:
#   None
########################################
function check_base_packages() {
  section "Base packages (apt)"
  check_tool git required git --version
  check_tool curl required curl --version
  check_tool wget required wget --version
  check_tool unzip required unzip -v
  check_tool jq required jq --version
  check_tool gpg required gpg --version
  check_tool python3 required python3 --version
  check_tool shellcheck required shellcheck --version
  check_tool shfmt required shfmt --version
  check_tool bats required bats --version
  check_tool direnv required direnv version
  check_tool wg required wg --version
}

########################################
# Check Docker Engine, its plugins, and whether the daemon answers
# Globals:
#   missing (incremented)
# Arguments:
#   None
########################################
function check_docker() {
  local plugin version

  section "Docker"
  check_tool docker required docker --version
  if ! command -v docker >/dev/null 2>&1; then
    return 0
  fi

  for plugin in compose buildx; do
    if docker "${plugin}" version >/dev/null 2>&1; then
      version="$(docker "${plugin}" version 2>&1 | grep -oE "${VERSION_PATTERN}" | head -n 1 || true)"
      print_result "docker ${plugin}" "${version:-installed}"
    else
      print_result "docker ${plugin}" "MISSING" "${C_RED}"
      missing=$((missing + 1))
    fi
  done

  if ! docker info >/dev/null 2>&1; then
    log_warn "'docker info' failed; if setup-ubuntu.sh just ran, log out and back in (docker group)"
  fi
}

########################################
# Check mise, uv and the Python tools
# Arguments:
#   None
########################################
function check_python_tools() {
  section "mise and the Python tools (uv)"
  check_tool mise required mise --version
  check_tool uv required uv --version
  check_tool pre-commit required pre-commit --version
  check_tool checkov required checkov --version
  check_tool semgrep required semgrep --version
  check_tool ruff required ruff --version
  check_tool pip-audit required pip-audit --version
  check_tool prowler required prowler --version
  check_tool zizmor required zizmor --version
  check_tool localstack optional localstack --version
}

########################################
# Check the tools pinned in the current repo's .mise.toml
# Arguments:
#   None
########################################
function check_repo_tools() {
  section "Per-repo tools (from the current repo's .mise.toml)"
  if [[ ! -f .mise.toml && ! -f mise.toml ]]; then
    log_warn "no .mise.toml here; run this inside a project repo, or use --system"
  fi
  check_tool terraform required terraform version
  check_tool tflint required tflint --version
  check_tool terraform-docs required terraform-docs --version
  check_tool infracost required infracost --version
  check_tool talosctl required talosctl version --client
  check_tool kubectl required kubectl version --client
  check_tool helm required helm version --short
  check_tool kustomize required kustomize version
  check_tool kind required kind version
  check_tool argocd required argocd version --client --short
  check_tool kubeconform required kubeconform -v
  check_tool ct required ct version
  check_tool k6 required k6 version
  check_tool cilium required cilium version --client
  check_tool hubble required hubble version
  check_tool kyverno required kyverno version
  check_tool cosign required cosign version
  check_tool syft required syft version
  check_tool trivy required trivy --version
  check_tool rekor-cli required rekor-cli version
  check_tool hadolint required hadolint --version
  check_tool container-structure-test required container-structure-test version
  check_tool kubescape required kubescape version
  check_tool gh required gh --version
  check_tool aws required aws --version
  check_tool promtool required promtool --version
  check_tool k9s optional k9s version --short
  check_tool stern optional stern --version
  check_tool kubectx optional kubectx --version
}

########################################
# Print the summary and exit with the result
# Globals:
#   ERR_MISSING, missing (read)
# Arguments:
#   None
# Outputs:
#   Writes the summary to stdout
########################################
function report() {
  printf '\n'
  if [[ "${missing}" -gt 0 ]]; then
    log_error "${missing} required tool(s) missing"
    exit "${ERR_MISSING}"
  fi
  log_ok "All required tools are installed."
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

  check_base_packages
  check_docker
  check_python_tools
  if [[ "${system_only}" != "true" ]]; then
    check_repo_tools
  fi
  report
}

########################################
# Invoke main function
########################################
main "$@"
