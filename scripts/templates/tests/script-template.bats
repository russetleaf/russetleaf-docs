#!/usr/bin/env bats
# shellcheck source-path=SCRIPTDIR
#
# script-template.bats
#
# Tests for script-template.sh, and the starting point for every script's tests:
# copy it next to the new script's other tests and rename it to match the script.
# Every script needs at least these: --help, an unknown option, and its own
# behavior. Use run_isolated (scripts/lib/bats-helpers.bash) with stub commands for
# anything that would install or change something.
#
# This program is licensed under the terms of the GNU General Public License v3.0.

# shellcheck source=SCRIPTDIR/../../lib/bats-helpers.bash
source "${BATS_TEST_DIRNAME}/../../lib/bats-helpers.bash"

SCRIPT="${BATS_TEST_DIRNAME}/../script-template.sh"

@test "--help shows the options and exit codes, and exits 0" {
  run "${SCRIPT}" --help
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Usage: script-template.sh"* ]]
  [[ "${output}" == *"Exit codes:"* ]]
}

@test "an unknown option exits 64" {
  run "${SCRIPT}" --bogus
  [ "${status}" -eq 64 ]
  [[ "${output}" == *"invalid option: --bogus"* ]]
}

@test "an option missing its value exits 64" {
  run "${SCRIPT}" --name
  [ "${status}" -eq 64 ]
  [[ "${output}" == *"--name needs a value"* ]]
}

@test "it greets the world by default" {
  run "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Hello, world."* ]]
}

@test "--name changes who is greeted" {
  run "${SCRIPT}" --name operator
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Hello, operator."* ]]
}

@test "it runs with only basic utilities on the PATH" {
  make_isolated_bin
  run_isolated "${SCRIPT}" --name isolated
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Hello, isolated."* ]]
}
