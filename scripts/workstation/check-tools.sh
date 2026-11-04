#!/usr/bin/env bash
# Report the version of every RussetLeaf workstation tool, and exit 1 if a required
# one is missing.
#
# The per-repo tools come from each repo's .mise.toml, so run this from inside a
# project repo (after `mise install`) to check them. Before the repos exist, use
# --system to check only what setup-ubuntu.sh installs.
#
# Usage: scripts/workstation/check-tools.sh [--system]
# See "Local workstation setup" in docs/phase-1-russetleaf-dev/plan.md.

set -uo pipefail

system_only=false
missing=0

case ${1:-} in
  --system) system_only=true ;;
  -h | --help)
    sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
  "") ;;
  *)
    echo "unknown option: $1 (see --help)" >&2
    exit 2
    ;;
esac

section() { printf '\n%s\n' "$1"; }

# check NAME [optional] -- VERSION-COMMAND...
# NAME is the command looked up on the PATH. The version shown is the first
# "x.y" or "x.y.z" in the command's output.
check() {
  local name=$1 optional=false out version
  shift
  if [[ $1 == optional ]]; then
    optional=true
    shift
  fi
  [[ $1 == -- ]] && shift
  if ! command -v "$name" >/dev/null 2>&1; then
    if [[ $optional == true ]]; then
      printf '  %-26s not installed (optional)\n' "$name"
    else
      printf '  %-26s MISSING\n' "$name"
      missing=$((missing + 1))
    fi
    return
  fi
  out=$(timeout 15 "$@" 2>&1)
  version=$(grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' <<<"$out" | head -n1)
  printf '  %-26s %s\n' "$name" "${version:-installed (version not shown)}"
}

section "Base packages (apt)"
check git -- git --version
check curl -- curl --version
check wget -- wget --version
check unzip -- unzip -v
check jq -- jq --version
check gpg -- gpg --version
check python3 -- python3 --version
check shellcheck -- shellcheck --version
check direnv -- direnv version
check wg -- wg --version

section "Docker"
check docker -- docker --version
if command -v docker >/dev/null 2>&1; then
  for plugin in compose buildx; do
    if docker "$plugin" version >/dev/null 2>&1; then
      printf '  %-26s %s\n' "docker $plugin" "$(docker "$plugin" version 2>&1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1)"
    else
      printf '  %-26s MISSING\n' "docker $plugin"
      missing=$((missing + 1))
    fi
  done
  if ! docker info >/dev/null 2>&1; then
    echo "  note: 'docker info' failed; if the setup script just ran, log out and back in (docker group)"
  fi
fi

section "mise and the Python tools (uv)"
check mise -- mise --version
check uv -- uv --version
check pre-commit -- pre-commit --version
check checkov -- checkov --version
check semgrep -- semgrep --version
check ruff -- ruff --version
check pip-audit -- pip-audit --version
check prowler -- prowler --version
check zizmor -- zizmor --version
check localstack optional -- localstack --version

if [[ $system_only == false ]]; then
  section "Per-repo tools (from the current repo's .mise.toml)"
  [[ -f .mise.toml || -f mise.toml ]] ||
    echo "  note: no .mise.toml here; run this inside a project repo, or use --system"
  check terraform -- terraform version
  check tflint -- tflint --version
  check terraform-docs -- terraform-docs --version
  check infracost -- infracost --version
  check talosctl -- talosctl version --client
  check kubectl -- kubectl version --client
  check helm -- helm version --short
  check kustomize -- kustomize version
  check kind -- kind version
  check argocd -- argocd version --client --short
  check kubeconform -- kubeconform -v
  check ct -- ct version
  check k6 -- k6 version
  check cilium -- cilium version --client
  check hubble -- hubble version
  check kyverno -- kyverno version
  check cosign -- cosign version
  check syft -- syft version
  check trivy -- trivy --version
  check rekor-cli -- rekor-cli version
  check hadolint -- hadolint --version
  check container-structure-test -- container-structure-test version
  check kubescape -- kubescape version
  check gh -- gh --version
  check aws -- aws --version
  check promtool -- promtool --version
  check k9s optional -- k9s version --short
  check stern optional -- stern --version
  check kubectx optional -- kubectx --version
fi

echo
if ((missing > 0)); then
  echo "$missing required tool(s) missing."
  exit 1
fi
echo "All required tools are installed."
