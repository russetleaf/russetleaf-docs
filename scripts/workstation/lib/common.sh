# shellcheck shell=bash
#
# common.sh
#
# Shared functions for the RussetLeaf workstation scripts: colored messages, error
# and signal handling, and verbose tracing. Sourced by the scripts, not run.
#
# This program is licensed under the terms of the GNU General Public License v3.0.

# Colors start off, so messages work before init_colors runs (for example, a usage
# error found while parsing options).
C_RED=""
C_GREEN=""
C_YELLOW=""
C_BLUE=""
C_RESET=""

########################################
# Turn on colors, unless turned off with an option or NO_COLOR, or the output is not
# a terminal (so logs and pipes never get escape codes).
# Globals:
#   NO_COLOR (read; see https://no-color.org)
#   C_RED, C_GREEN, C_YELLOW, C_BLUE, C_RESET (set)
# Arguments:
#   $1 (required): "true" if colors were turned off with --no-color
########################################
function init_colors() {
  local no_color="$1"

  if [[ "${no_color}" != "true" && -z "${NO_COLOR:-}" && -t 1 && -t 2 ]]; then
    C_RED=$'\e[0;31m'
    C_GREEN=$'\e[0;32m'
    C_YELLOW=$'\e[0;33m'
    C_BLUE=$'\e[0;34m'
    C_RESET=$'\e[0m'
  fi
}

########################################
# Print the heading of a step.
# Arguments:
#   $@ (required): Heading text
# Outputs:
#   Writes the heading to stdout
########################################
function log_step() {
  printf '\n%s==>%s %s\n' "${C_BLUE}" "${C_RESET}" "$*"
}

########################################
# Print a success message.
# Arguments:
#   $@ (required): Message text
# Outputs:
#   Writes the message to stdout
########################################
function log_ok() {
  printf '%s%s%s\n' "${C_GREEN}" "$*" "${C_RESET}"
}

########################################
# Print a warning.
# Arguments:
#   $@ (required): Message text
# Outputs:
#   Writes the warning to stderr
########################################
function log_warn() {
  printf '%swarning:%s %s\n' "${C_YELLOW}" "${C_RESET}" "$*" >&2
}

########################################
# Print an error.
# Arguments:
#   $@ (required): Message text
# Outputs:
#   Writes the error to stderr
########################################
function log_error() {
  printf '%serror:%s %s\n' "${C_RED}" "${C_RESET}" "$*" >&2
}

########################################
# Print an error and exit.
# Arguments:
#   $1 (required): Exit code
#   $@ (required): Message text, after the exit code
# Outputs:
#   Writes the error to stderr
########################################
function die() {
  local code="$1"
  shift
  log_error "$*"
  exit "${code}"
}

########################################
# Report a failed command and exit with its code. Called by the ERR trap.
# Arguments:
#   $1 (required): Exit code of the failed command
#   $2 (required): Line number
#   $3 (required): The failed command
# Outputs:
#   Writes the error to stderr
########################################
function on_error() {
  local code="$1" line="$2" command="$3"

  trap - ERR
  log_error "line ${line}: '${command}' failed with exit code ${code}"
  exit "${code}"
}

########################################
# Stop on a signal, instead of running the rest of the script. Called by the INT and
# TERM traps.
# Arguments:
#   $1 (required): Signal name
#   $2 (required): Exit code (128 plus the signal number)
# Outputs:
#   Writes the error to stderr
########################################
function on_signal() {
  local signal="$1" code="$2"

  trap - ERR INT TERM
  log_error "stopped by SIG${signal}"
  exit "${code}"
}

########################################
# Install the ERR, INT and TERM traps.
# Arguments:
#   None
########################################
function install_traps() {
  trap 'on_error "$?" "${LINENO}" "${BASH_COMMAND}"' ERR
  trap 'on_signal INT 130' INT
  trap 'on_signal TERM 143' TERM
}

########################################
# Trace every command, with the script name and line number.
# Globals:
#   PS4 (set)
# Arguments:
#   None
########################################
function enable_trace() {
  # Single quotes on purpose: bash expands PS4 at each traced line.
  # shellcheck disable=SC2016
  PS4='+ ${BASH_SOURCE[0]##*/}:${LINENO}: '
  set -x
}
