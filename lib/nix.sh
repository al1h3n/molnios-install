# nix.sh - get a working, flake-enabled nix on any supported OS.
#
#   NixOS   - already there.
#   Alpine  - `apk add nix` (Alpine's package ships an OpenRC nix-daemon
#             service; the official installers expect systemd or launchd).
#   others  - the official Rust installer from the NixOS project
#             (github.com/NixOS/nix-installer, beta since Nix 2.34). It
#             installs upstream Nix with flakes enabled and can uninstall
#             cleanly with `/nix/nix-installer uninstall`.
#             --nix-installer classic uses the older nixos.org/nix/install script.

NIX_INSTALLER_URL=${NIX_INSTALLER_URL:-https://artifacts.nixos.org/nix-installer}

# Make a nix installed earlier in this same run visible to this shell.
nix_load_profile() {
  local f
  for f in /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh \
    "$HOME/.nix-profile/etc/profile.d/nix.sh"; do
    # shellcheck disable=SC1090
    [ -r "$f" ] && . "$f" && return 0
  done
  return 0
}

nix_install() {
  local os=$1
  nix_load_profile
  if exists nix; then
    ok "nix is installed ($(nix --version))"
    return 0
  fi
  [ "$os" = nixos ] && die "NixOS without nix? Something is very wrong."

  info "installing nix"
  case "$os" in
    alpine)
      as_root apk add --no-cache nix
      as_root addgroup "$USER" nix || true # the daemon socket is group-restricted
      as_root rc-update add nix-daemon default
      as_root rc-service nix-daemon start
      nix_enable_flakes
      # A new group only applies to new logins, so this shell may not reach
      # the daemon socket yet.
      if [ "${DRY_RUN:-0}" != 1 ] && ! nixf store info >/dev/null 2>&1; then
        die "nix is installed. Log out and back in (for the 'nix' group), then run molnios.sh again."
      fi
      ;;
    *)
      if [ "${NIX_INSTALLER:-rust}" = classic ]; then
        run_cmd sh -c "curl --proto '=https' --tlsv1.2 -fsSL https://nixos.org/nix/install | sh -s -- --daemon --yes"
        nix_enable_flakes
      else
        # --no-confirm: the user already confirmed by running molnios.sh.
        run_cmd sh -c "curl --proto '=https' --tlsv1.2 -sSfL '$NIX_INSTALLER_URL' | sh -s -- install --no-confirm"
      fi
      ;;
  esac
  nix_load_profile
  [ "${DRY_RUN:-0}" = 1 ] || exists nix || die "nix was installed, but is not on PATH yet. Open a new terminal and run molnios.sh again."
}

# The Rust installer enables flakes itself; apk and the classic script do not.
# Idempotent: only appends when the line is missing.
nix_enable_flakes() {
  local conf=/etc/nix/nix.conf
  if ! grep -qs '^experimental-features.*flakes' "$conf"; then
    as_root sh -c "mkdir -p /etc/nix && echo 'experimental-features = nix-command flakes' >> $conf"
  fi
}
