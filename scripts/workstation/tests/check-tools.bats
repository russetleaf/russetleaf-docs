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
  git curl wget unzip jq gpg paperkey ykman python3 shellcheck shfmt bats direnv wg
  mise bw opengrep uv pre-commit checkov ruff pip-audit prowler zizmor
)
REPO_TOOLS=(
  tofu tflint terraform-docs infracost talosctl kubectl helm kustomize kind argocd
  kubeconform ct k6 cilium hubble kyverno cosign syft trivy rekor-cli hadolint
  container-structure-test kubescape gh aws promtool
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

@test "uv installed by mise but not on the PATH is found through mise" {
  stub_system_tools
  mkdir -p "${BATS_TEST_TMPDIR}/mise-uv"
  mv "${BIN}/uv" "${BATS_TEST_TMPDIR}/mise-uv/uv"
  stub_script mise "case \"\$1\" in
  which) echo '${BATS_TEST_TMPDIR}/mise-uv/uv' ;;
  *) echo 'mise 2026.11.1' ;;
esac"
  run_isolated "${CHECK}" --system
  [ "${status}" -eq 0 ]
  [[ "${output}" =~ uv\ +1\.2\.3 ]]
}

@test "the Bitwarden CLI installed by mise but not on the PATH is found through mise" {
  stub_system_tools
  mkdir -p "${BATS_TEST_TMPDIR}/mise-bw"
  mv "${BIN}/bw" "${BATS_TEST_TMPDIR}/mise-bw/bw"
  stub_script mise "case \"\$1 \$2\" in
  'which bw') echo '${BATS_TEST_TMPDIR}/mise-bw/bw' ;;
  'which '*) exit 1 ;;
  *) echo 'mise 2026.11.1' ;;
esac"
  run_isolated "${CHECK}" --system
  [ "${status}" -eq 0 ]
  [[ "${output}" =~ bw\ +1\.2\.3 ]]
}

@test "uv missing from both the PATH and mise is reported" {
  stub_system_tools
  rm "${BIN}/uv"
  stub_script mise 'case "$1" in
  which) exit 1 ;;
  *) echo "mise 2026.11.1" ;;
esac'
  run_isolated "${CHECK}" --system
  [ "${status}" -eq 1 ]
  [[ "${output}" =~ uv\ +MISSING ]]
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
  local tool

  stub_system_tools
  for tool in "${REPO_TOOLS[@]}"; do
    stub "${tool}"
  done
  run_isolated "${CHECK}"
  [ "${status}" -eq 0 ]
  [[ "${output}" =~ k9s\ +not\ installed\ \(optional\) ]]
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
  [[ "${output}" =~ tofu\ +MISSING ]]
}

@test "output that is not a terminal has no color codes" {
  stub_system_tools
  rm "${BIN}/jq"
  run_isolated "${CHECK}" --system
  [[ "${output}" != *$'\e'* ]]
}
