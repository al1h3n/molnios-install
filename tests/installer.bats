#!/usr/bin/env bats
# Tests for molnios.sh's library functions. No root, no network, no nix:
#   nix run nixpkgs#bats -- tests/
# (tests/e2e.sh is the slow end-to-end test that really installs.)

setup() {
  ROOT="$BATS_TEST_DIRNAME/.."
  # shellcheck source=../lib/common.sh
  for f in common os nix repos host apply fallback; do . "$ROOT/lib/$f.sh"; done
  TMP=$(mktemp -d)
  export HOME="$TMP/home"
  mkdir -p "$HOME"
}

teardown() { rm -rf "$TMP"; }

osrelease() { printf '%s\n' "$@" >"$TMP/os-release"; export MOLNI_OS_RELEASE="$TMP/os-release"; }

# ── detect_os ────────────────────────────────────────────────────────────
@test "detect_os: Arch and derivatives" {
  osrelease 'ID=arch'
  [ "$(detect_os)" = arch ]
  osrelease 'ID=manjaro' 'ID_LIKE=arch'
  [ "$(detect_os)" = arch ]
  osrelease 'ID=endeavouros' 'ID_LIKE="arch"'
  [ "$(detect_os)" = arch ]
}

@test "detect_os: Debian and Ubuntu family" {
  osrelease 'ID=debian'
  [ "$(detect_os)" = debian ]
  osrelease 'ID=linuxmint' 'ID_LIKE="ubuntu debian"'
  [ "$(detect_os)" = debian ]
}

@test "detect_os: Alpine and NixOS" {
  osrelease 'ID=alpine'
  [ "$(detect_os)" = alpine ]
  osrelease 'ID=nixos'
  [ "$(detect_os)" = nixos ]
}

@test "detect_os: unsupported distro fails with a message" {
  osrelease 'ID=fedora' 'ID_LIKE="rhel centos"'
  run detect_os
  [ "$status" -ne 0 ]
  [[ "$output" == *"unsupported OS 'fedora'"* ]]
}

@test "detect_system: maps uname to nix systems" {
  uname() { case "$1" in -m) echo arm64 ;; -s) echo Darwin ;; esac; }
  [ "$(detect_system)" = aarch64-darwin ]
  uname() { case "$1" in -m) echo x86_64 ;; -s) echo Linux ;; esac; }
  [ "$(detect_system)" = x86_64-linux ]
  uname() { case "$1" in -m) echo riscv64 ;; -s) echo Linux ;; esac; }
  run detect_system
  [ "$status" -ne 0 ]
}

# ── helpers ──────────────────────────────────────────────────────────────
@test "read_into: keeps spaces, drops blank lines, bash-3.2 safe" {
  read_into arr < <(printf 'a b\n\nc\n')
  [ "${#arr[@]}" -eq 2 ]
  [ "${arr[0]}" = "a b" ]
  [ "${arr[1]}" = c ]
}

@test "read_into: keeps the last line without a trailing newline" {
  # Regression: `nix eval --raw` output has no final newline, and the last
  # native package (zsh) was silently dropped. Found by tests/e2e.sh.
  read_into arr < <(printf 'fish\nzsh')
  [ "${#arr[@]}" -eq 2 ]
  [ "${arr[1]}" = zsh ]
}

@test "read_into: empty input gives an empty array" {
  read_into arr < <(true)
  [ "${#arr[@]}" -eq 0 ]
}

@test "lines: skips comments and blanks, missing file is empty" {
  printf '# c\nfish\n\n  # x\nzsh\n' >"$TMP/l"
  [ "$(lines "$TMP/l" | tr '\n' ' ')" = "fish zsh " ]
  [ -z "$(lines "$TMP/missing")" ]
}

@test "run_cmd: --dry-run prints instead of running" {
  DRY_RUN=1 run run_cmd touch "$TMP/should-not-exist"
  [ ! -e "$TMP/should-not-exist" ]
  [[ "$output" == *"touch $TMP/should-not-exist"* ]]
}

@test "host_template: one template per OS" {
  [ "$(host_template nixos)" = MolniPC ]
  [ "$(host_template darwin)" = ManiacPC ]
  [ "$(host_template arch)" = example-arch ]
  [ "$(host_template alpine)" = example-alpine ]
}

# ── host_ensure ──────────────────────────────────────────────────────────
@test "host_ensure: copies the template, fills system and users" {
  flake="$TMP/flake"
  mkdir -p "$flake/hosts/example-arch"
  cat >"$flake/hosts/example-arch/default.nix" <<'EOF'
# example-arch - template for an Arch Linux machine.
{
  os = "arch";
  system = "x86_64-linux";
  preset = "nix";
}
EOF
  git -C "$flake" init -q
  host_ensure "$flake" mybox arch aarch64-linux alice
  f="$flake/hosts/mybox/default.nix"
  grep -q '^  users = \[ "alice" \];' "$f"
  grep -q '^  system = "aarch64-linux";' "$f"
  head -1 "$f" | grep -q '^# mybox - created by molnios.sh from hosts/example-arch.'
  [ ! -e "$f.bak" ] && [ ! -e "$f.tmp" ]
  git -C "$flake" diff --cached --name-only | grep -q '^hosts/mybox/default.nix$'
  # The template itself is untouched.
  ! grep -q users "$flake/hosts/example-arch/default.nix"
}

@test "host_set: replaces an existing key, inserts a missing one after os" {
  printf '{\n  os = "arch";\n  preset = "nix";\n  system = "x";\n}\n' >"$TMP/h.nix"
  host_set "$TMP/h.nix" preset '"hybrid"'
  host_set "$TMP/h.nix" users '[ "bob" ]'
  [ "$(sed -n 2,4p "$TMP/h.nix" | tr -d ' ')" = "$(printf 'os="arch";\nusers=["bob"];\npreset="hybrid";')" ]
  [ "$(grep -c preset "$TMP/h.nix")" = 1 ]
}

@test "user_ensure: users/<login>.nix from the template, only once" {
  flake="$TMP/flake"
  mkdir -p "$flake/users"
  echo '{ profiles = [ "base" ]; }' >"$flake/users/_template.nix"
  git -C "$flake" init -q
  user_ensure "$flake" carol
  grep -q base "$flake/users/carol.nix"
  echo '{ mine = true; }' >"$flake/users/carol.nix"
  user_ensure "$flake" carol
  grep -q mine "$flake/users/carol.nix" # an existing user file is never replaced
}

@test "repo_url: MolniOS names, owner/repo and full URLs" {
  [ "$(repo_url molnixos)" = "https://github.com/al1h3n/molnixos" ]
  [ "$(repo_url bob/dots)" = "https://github.com/bob/dots" ]
  [ "$(repo_url https://example.org/x.git)" = "https://example.org/x.git" ]
  MOLNI_GIT_HOST=https://gitlab.com MOLNI_GIT_BASE=https://gitlab.com/al1h3n
  [ "$(repo_url molnixos)" = "https://gitlab.com/al1h3n/molnixos" ]
  [ "$(repo_url bob/dots)" = "https://gitlab.com/bob/dots" ]
}

@test "arch never does a partial upgrade (-Sy without -u)" {
  DRY_RUN=1 run pkg_install arch fish
  [[ "$output" == *"pacman -Syu --needed --noconfirm fish"* ]]
  DRY_RUN=1 run pkg_refresh arch
  [[ "$output" != *"pacman -Sy "* ]]
}

@test "system_upgrade: upgrades every distro package" {
  DRY_RUN=1 run system_upgrade arch
  [[ "$output" == *"pacman -Syu --noconfirm"* ]]
  DRY_RUN=1 run system_upgrade debian
  [[ "$output" == *"apt-get update"* && "$output" == *"apt-get upgrade -y"* && "$output" == *"force-confold"* ]]
  DRY_RUN=1 run system_upgrade alpine
  [[ "$output" == *"apk upgrade"* ]]
}

@test "host_ensure: an existing host is left alone" {
  flake="$TMP/flake"
  mkdir -p "$flake/hosts/mybox"
  echo '{ user = "kept"; }' >"$flake/hosts/mybox/default.nix"
  host_ensure "$flake" mybox arch x86_64-linux alice
  grep -q kept "$flake/hosts/mybox/default.nix"
}

# ── links (the no-nix preset) ────────────────────────────────────────────
@test "links_apply: links, backs up real files, replaces old links" {
  shared="$TMP/shared"
  mkdir -p "$shared/config/kitty" "$shared/config/fish" "$HOME/.config/fish" "$HOME/.config/kitty"
  echo conf >"$shared/config/kitty/kitty.conf"
  echo fish >"$shared/config/fish/config.fish"
  echo mine >"$HOME/.config/fish/config.fish"         # real file -> backup
  ln -s /nowhere "$HOME/.config/kitty/kitty.conf"      # old link -> replaced
  printf '.config/kitty/kitty.conf\tconfig/kitty/kitty.conf\n.config/fish/config.fish\tconfig/fish/config.fish\n.config/x\tconfig/missing\n' >"$TMP/links.tsv"

  run links_apply "$TMP/links.tsv" "$shared"
  [ "$status" -eq 0 ]
  [ "$(readlink "$HOME/.config/kitty/kitty.conf")" = "$shared/config/kitty/kitty.conf" ]
  [ "$(readlink "$HOME/.config/fish/config.fish")" = "$shared/config/fish/config.fish" ]
  [ "$(cat "$HOME/.config/fish/config.fish.backup")" = mine ]
  [ ! -e "$HOME/.config/x" ]
  [[ "$output" == *"link source missing"* ]]
}

@test "links_remove: removes only our links and restores backups" {
  shared="$TMP/shared"
  mkdir -p "$shared/config" "$HOME/.config"
  echo a >"$shared/config/a"
  echo mine >"$HOME/.config/a"
  ln -s /elsewhere "$HOME/.config/b"
  printf '.config/a\tconfig/a\n.config/b\tconfig/b\n' >"$TMP/links.tsv"
  links_apply "$TMP/links.tsv" "$shared" >/dev/null 2>&1
  links_remove "$TMP/links.tsv" "$shared"
  [ "$(cat "$HOME/.config/a")" = mine ]           # backup restored
  [ "$(readlink "$HOME/.config/b")" = /elsewhere ] # not ours: untouched
}

@test "templates_apply: placeholders become this user's paths" {
  shared="$TMP/shared"
  mkdir -p "$shared/config"
  printf 'theme=@HOME@/.config/t.qbtheme\nuser=@USER@ dots=@SHARED@\n' >"$shared/config/q.ini.in"
  ln -s /old "$HOME/q.conf" # a link from before it was a template
  printf 'q.conf\tconfig/q.ini.in\n@SHARED@/out.css\tconfig/q.ini.in\n' >"$TMP/templates.tsv"
  templates_apply "$TMP/templates.tsv" "$shared"
  [ ! -L "$HOME/q.conf" ]
  grep -qx "theme=$HOME/.config/t.qbtheme" "$HOME/q.conf"
  grep -qx "user=$(id -un) dots=$shared" "$HOME/q.conf"
  [ -f "$shared/out.css" ]
}

@test "links_apply: @HOME@ and @SHARED@ in exported lists" {
  shared="$TMP/shared"
  mkdir -p "$shared/config"
  echo x >"$shared/config/a"
  printf '@HOME@/.config/a\t@SHARED@/config/a\n' >"$TMP/links.tsv"
  links_apply "$TMP/links.tsv" "$shared" >/dev/null
  [ "$(readlink "$HOME/.config/a")" = "$shared/config/a" ]
}

# ── media ────────────────────────────────────────────────────────────────
@test "media_sync: each repo in its own folder, top-level dirs linked" {
  # Fake remote repos, so no network is needed.
  for r in molnios-media-static molnios-media-dynamic; do
    mkdir -p "$TMP/remote/$r"
    git -C "$TMP/remote/$r" init -q
  done
  mkdir -p "$TMP/remote/molnios-media-static/static" "$TMP/remote/molnios-media-dynamic/video"
  touch "$TMP/remote/molnios-media-static/static/a.png" "$TMP/remote/molnios-media-dynamic/video/b.mp4"
  for r in molnios-media-static molnios-media-dynamic; do
    git -C "$TMP/remote/$r" add -A
    git -C "$TMP/remote/$r" -c user.email=t@t -c user.name=t commit -qm init
  done
  MOLNI_GIT_BASE="file://$TMP/remote"
  media="$TMP/m/wallpapers"
  media_sync "$media" molnios-media-static molnios-media-dynamic >/dev/null
  [ -e "$media/static/a.png" ]
  [ -e "$media/video/b.mp4" ] # v1 bug: the second repo never arrived
}

# ── argument parsing (whole script) ──────────────────────────────────────
@test "molnios.sh: rejects unknown options and bad presets" {
  run bash "$ROOT/molnios.sh" --bogus
  [ "$status" -ne 0 ]
  run bash "$ROOT/molnios.sh" --preset maybe
  [ "$status" -ne 0 ]
  [[ "$output" == *"--preset must be nix, hybrid or native"* ]]
}

@test "molnios.sh: --help works" {
  run bash "$ROOT/molnios.sh" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"--preset native"* ]]
  [[ "$output" == *"--locked"* ]]
}
