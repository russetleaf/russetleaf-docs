# shellcheck shell=bash
#
# bats-helpers.bash
#
# Shared helpers for the bats tests of every script. Tests run a script with an
# isolated PATH: a temporary directory holding only basic utilities plus stub
# commands. Nothing real can be installed or changed, and a mistake fails the test
# (command not found) instead of touching the machine.
#
# Load it from a test file with:
#   source "${BATS_TEST_DIRNAME}/<path to scripts/lib>/bats-helpers.bash"
#
# This program is licensed under the terms of the GNU General Public License v3.0.

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Used by the test files that load this file
# shellcheck disable=SC2034
COMMON="${LIB_DIR}/common.sh"

########################################
# Create an isolated bin directory with the basic utilities. Only the script under
# test runs with it as its PATH (see run_isolated); the test itself keeps its PATH.
# Globals:
#   BATS_TEST_TMPDIR (read)
#   BIN (set)
# Arguments:
#   None
########################################
function make_isolated_bin() {
  local util

  BIN="${BATS_TEST_TMPDIR}/bin"
  mkdir -p "${BIN}"
  for util in bash env cat grep head timeout dirname id sleep; do
    ln -s "$(command -v "${util}")" "${BIN}/${util}"
  done
}

########################################
# Run a script with only the isolated bin directory on its PATH (bats "run")
# Globals:
#   BIN (read)
# Arguments:
#   $1 (required): Script to run
#   $@ (optional): Its options, after the script
########################################
function run_isolated() {
  run env PATH="${BIN}" "${BIN}/bash" "$@"
}

########################################
# Add a stub command that prints a fixed line and exits 0
# Globals:
#   BIN (read)
# Arguments:
#   $1 (required): Command name
#   $2 (optional): Line to print (default: "<name> version 1.2.3")
########################################
function stub() {
  local name="$1" output="${2:-$1 version 1.2.3}"

  {
    printf '#!/usr/bin/env bash\n'
    printf 'echo %q\n' "${output}"
  } >"${BIN}/${name}"
  chmod +x "${BIN}/${name}"
}

########################################
# Add a stub command with its own body
# Globals:
#   BIN (read)
# Arguments:
#   $1 (required): Command name
#   $2 (required): Bash code for the stub's body
########################################
function stub_script() {
  local name="$1" body="$2"

  printf '#!/usr/bin/env bash\n%s\n' "${body}" >"${BIN}/${name}"
  chmod +x "${BIN}/${name}"
}
