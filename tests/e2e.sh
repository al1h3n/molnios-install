#!/usr/bin/env bash
# e2e.sh - REALLY installs MolniOS for a throwaway user on THIS machine.
#
# Only for CI and disposable containers (Debian/Ubuntu or Arch). It creates a
# user, installs packages with the distro package manager, runs the installer
# as that user (Home Manager switch included), then checks the result and
# runs it a second time (an update must be a no-op that still succeeds).
#
#   sudo tests/e2e.sh <molnixos checkout> <molnios-shared checkout>
#
# MOLNI_GITIFY=1 rewrites the flake.lock copy to fetch GitHub inputs with git
# (for sandboxes that block GitHub tarball downloads).
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
src_flake=$(cd "${1:?molnixos checkout}" && pwd)
src_shared=$(cd "${2:?molnios-shared checkout}" && pwd)
[ "$(id -u)" = 0 ] || { echo "run as root (creates a test user)" >&2; exit 1; }

user=molni-e2e
home=/home/$user
lshared=$home/.local/share/molnios
host=e2e
pass=0 fail=0
check() { # <description> <command...>
  local what=$1; shift
  if "$@"; then echo "PASS  $what"; pass=$((pass + 1)); else echo "FAIL  $what"; fail=$((fail + 1)); fi
}

# ── 1. A fresh user with passwordless sudo ─────────────────────────────────
id "$user" >/dev/null 2>&1 || useradd -m -s /bin/bash "$user"
echo "$user ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/molni-e2e

# Containers have no systemd to start the nix daemon; non-root users need it.
if [ ! -S /nix/var/nix/daemon-socket/socket ]; then
  /nix/var/nix/profiles/default/bin/nix-daemon >/tmp/nix-daemon.log 2>&1 &
  for _ in $(seq 50); do [ -S /nix/var/nix/daemon-socket/socket ] && break; sleep 0.1; done
fi

# ── 2. The repos, as the installer would clone them (but from local copies) ─
rm -rf "$lshared"
install -d -o "$user" "$lshared"
copy_repo() { # <from> <to>
  mkdir -p "$2"
  git -C "$1" ls-files -z --cached --others --exclude-standard | (cd "$1" && xargs -0 cp --parents -t "$2")
  git -C "$2" init -q
  git -C "$2" add -A
}
copy_repo "$src_flake" "$lshared/molnixos"
copy_repo "$src_shared" "$lshared/shared"

# A small host: a real switch, but minutes instead of an hour of downloads.
mkdir -p "$lshared/molnixos/hosts/$host"
cat >"$lshared/molnixos/hosts/$host/default.nix" <<EOF
# e2e - created by tests/e2e.sh
{
  os = "debian";
  system = "x86_64-linux";
  user = "$user";
  stateVersion = "26.05";
  preset = "nix";
  # (no yazi: its RAR-enabled 7-zip is unfree, so not in the binary cache and
  # compiles from source - slow, and its source host may be blocked in CI.)
  apps = [ "cli" "nix-tools" "fish" "zsh" "shells" "fonts" "config-cleanup" ];
}
EOF
grep -q 'ID=arch' /etc/os-release && sed -i 's/os = "debian"/os = "arch"/' "$lshared/molnixos/hosts/$host/default.nix"

if [ "${MOLNI_GITIFY:-0}" = 1 ]; then
  (
    cd "$lshared/molnixos"
    nix flake lock \
      --override-input nix-darwin "git+https://github.com/nix-darwin/nix-darwin?shallow=1" \
      --override-input nix-homebrew "git+https://github.com/zhaofengli/nix-homebrew?shallow=1" \
      --override-input system-manager "git+https://github.com/numtide/system-manager?shallow=1" \
      --override-input molnios-shared "git+https://github.com/al1h3n/molnios-shared?shallow=1"
    "$src_flake/tests/lib/gitify-lock.sh" flake.lock
  )
fi
git -C "$lshared/molnixos" add -A
chown -R "$user:" "$home"

# ── 3. Run the installer as the user ───────────────────────────────────────
as_user() { sudo -u "$user" -H env MOLNI_FLAKE="$lshared/molnixos" MOLNI_SHARED="$lshared/shared" "$@"; }
start=$(date +%s)
# </dev/null: a prompt that slipped through must fail the test, not hang it.
as_user bash "$here/molnios.sh" --yes -H "$host" </dev/null
first=$(($(date +%s) - start))

# ── 4. Check the result ────────────────────────────────────────────────────
cfg=$home/.config
check "fish came from the distro (native), not nix" test -x /usr/bin/fish
check "zsh came from the distro (native)" test -x /usr/bin/zsh
check "Home Manager generation exists" test -e "$home/.local/state/home-manager/gcroots/current-home"
check "HM wrote fish config that sources the shared one" grep -q "$lshared/shared/config/fish/config.fish" "$cfg/fish/config.fish"
check "molni.links: ~/.config/shells -> live shared folder" \
  test "$(readlink -f "$cfg/shells")" = "$lshared/shared/config/shells"
check "compat link ~/.local/share/molnios/scripts" \
  test "$(readlink -f "$lshared/scripts")" = "$lshared/shared/scripts"
check "registry pkgs installed (eza, nh from nix)" \
  test -x "$home/.nix-profile/bin/eza" -a -x "$home/.nix-profile/bin/nh"
check "host.json summary written" grep -q '"os":"debian"\|"os":"arch"' "$cfg/molnios/host.json"
check "fish/zsh are listed as native in host.json" grep -q '"fish":"native"' "$cfg/molnios/host.json"
check "login shell is the distro's fish" test "$(getent passwd "$user" | cut -d: -f7)" = /usr/bin/fish

# ── 5. Second run = update: must succeed and change nothing important ──────
start=$(date +%s)
check "second run (--update) succeeds" as_user bash "$here/molnios.sh" --yes --update -H "$host" </dev/null
second=$(($(date +%s) - start))

echo
echo "first install: ${first}s, update: ${second}s"
echo "$pass passed, $fail failed"
[ "$fail" = 0 ]
