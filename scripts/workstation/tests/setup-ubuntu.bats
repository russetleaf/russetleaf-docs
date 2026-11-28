#!/usr/bin/env bats
# Stub bodies are single-quoted on purpose: they run later, inside the stub
# shellcheck disable=SC2016
#
# setup-ubuntu.bats
#
# Tests for setup-ubuntu.sh's options, its checks before changing anything, the
# repository key checks, the firewall, the screen lock and the Bitwarden desktop
# step. They use an isolated PATH in which sudo, apt-get, snap and
# the other commands that change the machine are stubs, so a failing test cannot
# install anything. The installation itself is tested by fresh-ubuntu-test.sh, in
# CI, except for the snap, which a container cannot install.
#
# This program is licensed under the terms of the GNU General Public License v3.0.

load helpers

########################################
# Stub every command a full run uses, for an Ubuntu 24.04 machine with snapd. The
# sudo stub only records its arguments, in ${BATS_TEST_TMPDIR}/sudo.log, and keeps
# what each `sudo tee <file>` would write under ${BATS_TEST_TMPDIR}/tee/<file>.
# Globals:
#   BATS_TEST_TMPDIR, BIN (read)
#   HOME, RL_DCONF_DIR (set and exported, so ~/.bashrc and the dconf profile are
#   test files)
# Arguments:
#   None
########################################
function stub_full_run() {
  local util

  make_isolated_bin
  fake_os_release ubuntu 24.04
  for util in awk touch mkdir; do
    ln -s "$(command -v "${util}")" "${BIN}/${util}"
  done
  stub_script sudo "printf '%s\\n' \"\$*\" >>'${BATS_TEST_TMPDIR}/sudo.log'
if [[ \"\$1\" == tee ]]; then
  [[ \"\$2\" == -a ]] && shift
  mkdir -p \"${BATS_TEST_TMPDIR}/tee\$(dirname \"\$2\")\"
  cat >>\"${BATS_TEST_TMPDIR}/tee\$2\"
fi
exit 0"
  stub_script dpkg-query 'exit 1'
  stub dpkg amd64
  stub_script curl 'exit 0'
  # Each repository's key check reads the primary key's fingerprint from gpg's
  # output; BAD_KEY names a repository whose key has another fingerprint
  stub_script gpg 'if [[ "$1" == "--show-keys" ]]; then
  case "${@: -1}" in
    *claude-code*) fpr=31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE ;;
    *docker*) fpr=9DC858229FC7DD38854AE2D88D81803C0EBFCD88 ;;
    *mise*) fpr=24853EC9F655CE80B48E6C3A8B81C9D17413A06D ;;
  esac
  [[ -n "${BAD_KEY:-}" && "${@: -1}" == *"${BAD_KEY}"* ]] && fpr=0000000000000000000000000000000000000000
  printf "pub:u:4096:1:0:0::::::scESC:\nfpr:::::::::%s:\nsub:u:4096:1:0:0::::::e:\nfpr:::::::::1111111111111111111111111111111111111111:\n" "${fpr}"
fi
exit 0'
  stub_script mise 'exit 0'
  stub_script systemctl 'exit 0'
  # snap: the Docker snap is not installed; Bitwarden is when BW_SNAP is set
  stub_script snap '[[ "$1 $2" == "list bitwarden" && -n "${BW_SNAP:-}" ]]'
  export HOME="${BATS_TEST_TMPDIR}"
  export RL_DCONF_DIR="${BATS_TEST_TMPDIR}/dconf"
}

@test "a full run checks every repository key and succeeds" {
  [ "${EUID}" -ne 0 ] || skip "run the tests as a normal user"
  stub_full_run
  run_isolated "${SETUP}"
  [ "${status}" -eq 0 ]
  grep -q 'tee /etc/apt/sources.list.d/docker.list' "${BATS_TEST_TMPDIR}/sudo.log"
  grep -q 'tee /etc/apt/sources.list.d/mise.list' "${BATS_TEST_TMPDIR}/sudo.log"
  grep -q 'tee /etc/apt/sources.list.d/claude-code.list' "${BATS_TEST_TMPDIR}/sudo.log"
}

@test "a repository key with another fingerprint exits 65 and is removed with its source list" {
  [ "${EUID}" -ne 0 ] || skip "run the tests as a normal user"
  stub_full_run
  BAD_KEY=docker run_isolated "${SETUP}"
  [ "${status}" -eq 65 ]
  [[ "${output}" == *"the docker repository key does not have the expected fingerprint 9DC858229FC7DD38854AE2D88D81803C0EBFCD88"* ]]
  grep -qx 'rm -f /etc/apt/keyrings/docker.asc /etc/apt/sources.list.d/docker.list' "${BATS_TEST_TMPDIR}/sudo.log"
  # The source list is never written, and nothing is installed from the repository
  run grep -q 'tee /etc/apt/sources.list.d/docker.list' "${BATS_TEST_TMPDIR}/sudo.log"
  [ "${status}" -ne 0 ]
  run grep -q 'docker-ce' "${BATS_TEST_TMPDIR}/sudo.log"
  [ "${status}" -ne 0 ]
}

@test "the firewall blocks incoming connections and is turned on" {
  [ "${EUID}" -ne 0 ] || skip "run the tests as a normal user"
  stub_full_run
  run_isolated "${SETUP}"
  [ "${status}" -eq 0 ]
  grep -qx 'ufw default deny incoming' "${BATS_TEST_TMPDIR}/sudo.log"
  grep -qx 'ufw default allow outgoing' "${BATS_TEST_TMPDIR}/sudo.log"
  grep -qx 'ufw --force enable' "${BATS_TEST_TMPDIR}/sudo.log"
}

@test "the screen lock is set for every user and locked" {
  [ "${EUID}" -ne 0 ] || skip "run the tests as a normal user"
  stub_full_run
  run_isolated "${SETUP}"
  [ "${status}" -eq 0 ]
  local tee="${BATS_TEST_TMPDIR}/tee${RL_DCONF_DIR}"
  [ "$(cat "${tee}/profile/user")" == $'user-db:user\nsystem-db:local' ]
  grep -qx 'idle-delay=uint32 600' "${tee}/db/local.d/00-russetleaf-screen-lock"
  grep -qx 'lock-enabled=true' "${tee}/db/local.d/00-russetleaf-screen-lock"
  grep -qx 'lock-delay=uint32 0' "${tee}/db/local.d/00-russetleaf-screen-lock"
  [ "$(cat "${tee}/db/local.d/locks/00-russetleaf-screen-lock")" == $'/org/gnome/desktop/session/idle-delay\n/org/gnome/desktop/screensaver/lock-enabled\n/org/gnome/desktop/screensaver/lock-delay' ]
  grep -qx 'dconf update' "${BATS_TEST_TMPDIR}/sudo.log"
}

@test "an existing dconf user profile gets the system database added, once" {
  [ "${EUID}" -ne 0 ] || skip "run the tests as a normal user"
  stub_full_run
  mkdir -p "${RL_DCONF_DIR}/profile"
  printf 'user-db:user\n' >"${RL_DCONF_DIR}/profile/user"
  run_isolated "${SETUP}"
  [ "${status}" -eq 0 ]
  grep -qx "tee -a ${RL_DCONF_DIR}/profile/user" "${BATS_TEST_TMPDIR}/sudo.log"
  [ "$(cat "${BATS_TEST_TMPDIR}/tee${RL_DCONF_DIR}/profile/user")" == 'system-db:local' ]
  # A profile that already reads the system database is left alone
  printf 'system-db:local\n' >>"${RL_DCONF_DIR}/profile/user"
  rm "${BATS_TEST_TMPDIR}/sudo.log"
  run_isolated "${SETUP}"
  [ "${status}" -eq 0 ]
  run grep -q "profile/user" "${BATS_TEST_TMPDIR}/sudo.log"
  [ "${status}" -ne 0 ]
}

@test "the Bitwarden desktop app is installed from the snap store and connected" {
  [ "${EUID}" -ne 0 ] || skip "run the tests as a normal user"
  stub_full_run
  run_isolated "${SETUP}"
  [ "${status}" -eq 0 ]
  grep -qx 'snap install bitwarden' "${BATS_TEST_TMPDIR}/sudo.log"
  grep -qx 'snap connect bitwarden:password-manager-service' "${BATS_TEST_TMPDIR}/sudo.log"
}

@test "an installed Bitwarden snap is not installed again, but is still connected" {
  [ "${EUID}" -ne 0 ] || skip "run the tests as a normal user"
  stub_full_run
  BW_SNAP=1 run_isolated "${SETUP}"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Already installed (the snap updates itself)"* ]]
  run grep -q 'snap install' "${BATS_TEST_TMPDIR}/sudo.log"
  [ "${status}" -ne 0 ]
  grep -qx 'snap connect bitwarden:password-manager-service' "${BATS_TEST_TMPDIR}/sudo.log"
}

@test "without a running snapd the Bitwarden desktop app is skipped" {
  [ "${EUID}" -ne 0 ] || skip "run the tests as a normal user"
  stub_full_run
  stub_script systemctl '[[ "$*" != *snapd.socket* ]]'
  run_isolated "${SETUP}"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"snapd is not running: skipped"* ]]
  run grep -q 'snap ' "${BATS_TEST_TMPDIR}/sudo.log"
  [ "${status}" -ne 0 ]
}

@test "--help shows the options and exit codes, and exits 0" {
  run "${SETUP}" --help
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Usage: setup-ubuntu.sh"* ]]
  [[ "${output}" == *"--no-color"* ]]
  [[ "${output}" != *"localstack"* ]]
  [[ "${output}" == *"64   Invalid option"* ]]
  [[ "${output}" == *"65   A repository key does not have its expected fingerprint"* ]]
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
