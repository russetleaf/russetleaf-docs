#!/usr/bin/env bats
# Stub bodies are single-quoted on purpose: they run later, inside the stub
# shellcheck disable=SC2016
#
# setup-ubuntu.bats
#
# Tests for setup-ubuntu.sh's options and its checks before changing anything. They
# use an isolated PATH without sudo or apt, so a failing test cannot install
# anything. The installation itself is tested by fresh-ubuntu-test.sh, in CI.
#
# This program is licensed under the terms of the GNU General Public License v3.0.

load helpers

@test "--help shows the options and exit codes, and exits 0" {
  run "${SETUP}" --help
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Usage: setup-ubuntu.sh"* ]]
  [[ "${output}" == *"--with-localstack"* ]]
  [[ "${output}" == *"64   Invalid option"* ]]
  [[ "${output}" == *"78   The Docker snap or a conflicting package is installed"* ]]
}

@test "an unknown option exits 64" {
  run "${SETUP}" --bogus
  [ "${status}" -eq 64 ]
  [[ "${output}" == *"invalid option: --bogus"* ]]
}

@test "running as root exits 77 before changing anything" {
  sudo -n true 2>/dev/null || skip "needs passwordless sudo (as in CI)"
  run sudo -n "${SETUP}"
  [ "${status}" -eq 77 ]
  [[ "${output}" == *"not root"* ]]
}

@test "a system other than Ubuntu 24.04 exits 69" {
  [ "${EUID}" -ne 0 ] || skip "run the tests as a normal user"
  make_isolated_bin
  fake_os_release debian 12
  run_isolated "${SETUP}"
  [ "${status}" -eq 69 ]
  [[ "${output}" == *"for Ubuntu 24.04 (found debian 12)"* ]]
}

@test "another Ubuntu version exits 69" {
  [ "${EUID}" -ne 0 ] || skip "run the tests as a normal user"
  make_isolated_bin
  fake_os_release ubuntu 22.04
  run_isolated "${SETUP}"
  [ "${status}" -eq 69 ]
}

@test "the Docker snap exits 78 and says how to remove it" {
  [ "${EUID}" -ne 0 ] || skip "run the tests as a normal user"
  make_isolated_bin
  fake_os_release ubuntu 24.04
  stub_script snap '[[ "$1 $2" == "list docker" ]]'
  run_isolated "${SETUP}"
  [ "${status}" -eq 78 ]
  [[ "${output}" == *"sudo snap remove docker"* ]]
}

@test "a package that conflicts with Docker exits 78 and names it" {
  [ "${EUID}" -ne 0 ] || skip "run the tests as a normal user"
  make_isolated_bin
  fake_os_release ubuntu 24.04
  # dpkg-query reports only runc as installed
  stub_script dpkg-query '[[ "${@: -1}" == "runc" ]] && printf "install ok installed"; exit 0'
  run_isolated "${SETUP}"
  [ "${status}" -eq 78 ]
  [[ "${output}" == *"sudo apt-get remove runc"* ]]
}
