#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
set -Eeuo pipefail

# script-template.sh
#
# The starting point for every RussetLeaf bash script. Copy it to
# scripts/<area>/<name>.sh, copy tests/script-template.bats to
# scripts/<area>/tests/<name>.bats, then replace this description, the options, the
# exit codes and the step functions. It runs as it is (it prints a greeting), and
# passes every check, so a new script starts out compliant.
#
# See docs/standards/bash.md for the standard this follows.
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

  # Exit codes (any other non-zero code is that of a failed command)
  readonly ERR_USAGE=64 # Invalid option or missing argument

  # Global variables
  no_color="false"
  verbose="false"
  name="world"
}

########################################
# Parse script parameters
# Globals:
#   no_color, verbose, name (set)
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
      --name)
        # An option that takes an argument
        if [[ $# -eq 0 || -z "$1" ]]; then
          die "${ERR_USAGE}" "--name needs a value (see ${SCRIPT_NAME} --help)"
        fi
        name="$1"
        shift
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
Usage: ${SCRIPT_NAME} [-h|--help] [--name NAME] [-n|--no-color] [-v|--verbose]

Prints a greeting. (Replace this with what the script does.)

Available options:
  -h|--help       Display help
  --name NAME     Who to greet (default: world)
  -n|--no-color   Turn off text colors (also off when NO_COLOR is set, or the
                  output is not a terminal)
  -v|--verbose    Trace every command

Exit codes:
  0    Success
  64   Invalid option or missing argument
  Any other non-zero code is that of the command that failed.
EOF
}

########################################
# Print the greeting (an example step: replace it with the script's own steps)
# Globals:
#   name (read)
# Arguments:
#   None
# Outputs:
#   Writes the greeting to stdout
########################################
function print_greeting() {
  log_step "Greeting"
  log_ok "Hello, ${name}."
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

  print_greeting
}

########################################
# Invoke main function
########################################
main "$@"
