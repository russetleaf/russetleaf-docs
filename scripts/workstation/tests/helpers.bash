# shellcheck shell=bash
#
# helpers.bash
#
# Shared setup for the workstation script tests (bats). Each test runs the scripts
# with an isolated PATH: a temporary directory holding only the utilities the
# scripts need, plus stub commands. Nothing real can be installed or changed, and
# a mistake fails the test (command not found) instead of touching the machine.

SCRIPTS_DIR="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
SETUP="${SCRIPTS_DIR}/setup-ubuntu.sh"
CHECK="${SCRIPTS_DIR}/check-tools.sh"
COMMON="${SCRIPTS_DIR}/lib/common.sh"

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

########################################
# Write a fake os-release file
# Globals:
#   BATS_TEST_TMPDIR (read)
#   RL_OS_RELEASE (set and exported)
# Arguments:
#   $1 (required): ID, e.g. ubuntu
#   $2 (required): VERSION_ID, e.g. 24.04
########################################
function fake_os_release() {
  RL_OS_RELEASE="${BATS_TEST_TMPDIR}/os-release"
  printf 'ID=%s\nVERSION_ID="%s"\nVERSION_CODENAME=test\nPRETTY_NAME="%s %s"\n' \
    "$1" "$2" "$1" "$2" >"${RL_OS_RELEASE}"
  export RL_OS_RELEASE
}
