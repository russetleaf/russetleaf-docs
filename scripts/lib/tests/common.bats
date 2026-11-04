#!/usr/bin/env bats
# shellcheck source-path=SCRIPTDIR
#
# common.bats
#
# Tests for lib/common.sh: messages, colors, and error and signal handling.
#
# This program is licensed under the terms of the GNU General Public License v3.0.

# shellcheck source=SCRIPTDIR/../bats-helpers.bash
source "${BATS_TEST_DIRNAME}/../bats-helpers.bash"

@test "messages are printed as text, never as a format string" {
  run bash -c "source '${COMMON}'; log_warn 'Disk 100% full'"
  [ "${status}" -eq 0 ]
  [ "${output}" = "warning: Disk 100% full" ]
}

@test "die prints the error and exits with the given code" {
  run bash -c "source '${COMMON}'; die 42 'something broke'; echo 'not reached'"
  [ "${status}" -eq 42 ]
  [ "${output}" = "error: something broke" ]
}

@test "a failed command is reported with its line, and stops the script" {
  run bash -c "set -Eeuo pipefail
source '${COMMON}'
install_traps
ls /nonexistent-path >/dev/null 2>&1
echo 'not reached'"
  [ "${status}" -eq 2 ]
  [[ "${output}" == *"line 4: 'ls /nonexistent-path"*"failed with exit code 2"* ]]
  [[ "${output}" != *"not reached"* ]]
}

@test "SIGTERM stops the script with exit code 143" {
  run bash -c "set -Eeuo pipefail
source '${COMMON}'
install_traps
(sleep 1; kill -TERM \$\$) &
sleep 3
echo 'not reached'"
  [ "${status}" -eq 143 ]
  [[ "${output}" == *"stopped by SIGTERM"* ]]
  [[ "${output}" != *"not reached"* ]]
}

@test "SIGINT stops the script with exit code 130" {
  run bash -c "set -Eeuo pipefail
source '${COMMON}'
install_traps
(sleep 1; kill -INT \$\$) &
sleep 3
echo 'not reached'"
  [ "${status}" -eq 130 ]
  [[ "${output}" == *"stopped by SIGINT"* ]]
  [[ "${output}" != *"not reached"* ]]
}

@test "colors are on in a terminal" {
  command -v script >/dev/null || skip "script (util-linux) is not installed"
  run script -qec "bash -c 'source ${COMMON}; init_colors false; printf %q \"\${C_RED}\"'" /dev/null </dev/null
  [[ "${output}" == *'\E[0;31m'* ]]
}

@test "colors are off with NO_COLOR, even in a terminal" {
  command -v script >/dev/null || skip "script (util-linux) is not installed"
  run script -qec "env NO_COLOR=1 bash -c 'source ${COMMON}; init_colors false; printf \"[%s]\" \"\${C_RED}\"'" /dev/null </dev/null
  [[ "${output}" == *"[]"* ]]
}

@test "colors are off with --no-color, even in a terminal" {
  command -v script >/dev/null || skip "script (util-linux) is not installed"
  run script -qec "bash -c 'source ${COMMON}; init_colors true; printf \"[%s]\" \"\${C_RED}\"'" /dev/null </dev/null
  [[ "${output}" == *"[]"* ]]
}

@test "colors are off when the output is not a terminal" {
  run bash -c "source '${COMMON}'; init_colors false; printf '[%s]' \"\${C_RED}\""
  [ "${output}" = "[]" ]
}
