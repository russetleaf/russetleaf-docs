#!/usr/bin/env bats
# Stub bodies are single-quoted on purpose: they run later, inside the stub
# shellcheck disable=SC2016
#
# check-tools.bats
#
# Tests for check-tools.sh, using stub commands on an isolated PATH, so the results
# do not depend on what is installed on the machine running the tests.
#
# This program is licensed under the terms of the GNU General Public License v3.0.

load helpers

SYSTEM_TOOLS=(
  git curl wget unzip jq gpg python3 shellcheck shfmt bats direnv wg
  mise uv pre-commit checkov semgrep ruff pip-audit prowler zizmor
)

########################################
# Stub every tool that --system checks, with a working Docker
# Arguments:
#   None
########################################
function stub_system_tools() {
  local tool

  for tool in "${SYSTEM_TOOLS[@]}"; do
    stub "${tool}"
  done
  stub_script docker 'case "$1" in
  --version) echo "Docker version 27.3.1, build ce12230" ;;
  compose | buildx) echo "$1 v2.29.7" ;;
  info) exit 0 ;;
esac'
}

setup() {
  make_isolated_bin
}

@test "--help shows the options and exit codes, and exits 0" {
  run_isolated "${CHECK}" --help
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"--system"* ]]
  [[ "${output}" == *"1    At least one required tool is missing"* ]]
}

@test "an unknown option exits 64" {
  run_isolated "${CHECK}" --bogus
  [ "${status}" -eq 64 ]
  [[ "${output}" == *"invalid option: --bogus"* ]]
}

@test "with every tool installed, it exits 0" {
  stub_system_tools
  run_isolated "${CHECK}" --system
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"All required tools are installed."* ]]
}

@test "the version shown is the first version number in the tool's output" {
  stub_system_tools
  stub git "git version 2.43.0"
  stub curl "curl 8.5.0 (x86_64-pc-linux-gnu) libcurl/8.5.0 OpenSSL/3.0.13"
  run_isolated "${CHECK}" --system
  [[ "${output}" =~ git\ +2\.43\.0 ]]
  [[ "${output}" =~ curl\ +8\.5\.0$'\n' ]]
}

@test "a missing required tool is reported, and it exits 1" {
  stub_system_tools
  rm "${BIN}/jq"
  run_isolated "${CHECK}" --system
  [ "${status}" -eq 1 ]
  [[ "${output}" =~ jq\ +MISSING ]]
  [[ "${output}" == *"1 required tool(s) missing"* ]]
}

@test "a missing Docker plugin counts as missing" {
  stub_system_tools
  stub_script docker 'case "$1" in
  --version) echo "Docker version 27.3.1" ;;
  compose) echo "compose v2.29.7" ;;
  *) exit 1 ;;
esac'
  run_isolated "${CHECK}" --system
  [ "${status}" -eq 1 ]
  [[ "${output}" =~ docker\ buildx\ +MISSING ]]
}

@test "a missing optional tool is not counted" {
  stub_system_tools
  run_isolated "${CHECK}" --system
  [ "${status}" -eq 0 ]
  [[ "${output}" =~ localstack\ +not\ installed\ \(optional\) ]]
}

@test "an unreachable Docker daemon is a warning, not a failure" {
  stub_system_tools
  stub_script docker 'case "$1" in
  --version) echo "Docker version 27.3.1" ;;
  compose | buildx) echo "$1 v2.29.7" ;;
  info) exit 1 ;;
esac'
  run_isolated "${CHECK}" --system
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"warning: 'docker info' failed"* ]]
}

@test "without --system, it checks the per-repo tools too" {
  stub_system_tools
  run_isolated "${CHECK}"
  [ "${status}" -eq 1 ]
  [[ "${output}" == *"Per-repo tools"* ]]
  [[ "${output}" =~ terraform\ +MISSING ]]
}

@test "output that is not a terminal has no color codes" {
  stub_system_tools
  rm "${BIN}/jq"
  run_isolated "${CHECK}" --system
  [[ "${output}" != *$'\e'* ]]
}
