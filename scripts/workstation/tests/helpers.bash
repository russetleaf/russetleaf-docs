# shellcheck shell=bash
# shellcheck source-path=SCRIPTDIR
#
# helpers.bash
#
# Helpers for the workstation script tests: the scripts under test, and a fake
# os-release file. The generic helpers (isolated PATH, stubs) come from
# scripts/lib/bats-helpers.bash.
#
# This program is licensed under the terms of the GNU General Public License v3.0.

# shellcheck source=../../lib/bats-helpers.bash
source "${BATS_TEST_DIRNAME}/../../lib/bats-helpers.bash"

SCRIPTS_DIR="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
# Used by the .bats files that load this file
# shellcheck disable=SC2034
SETUP="${SCRIPTS_DIR}/setup-ubuntu.sh"
# shellcheck disable=SC2034
CHECK="${SCRIPTS_DIR}/check-tools.sh"

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
