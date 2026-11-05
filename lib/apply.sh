# apply.sh - install native packages, then switch the nix configurations.
#
# Order matters on other distros: native packages first (e.g. Hyprland from
# pacman must exist before Home Manager writes a session that starts it), then
# system-manager (root: /etc/nix/nix.conf, services), then Home Manager (user).

# native_sync <flake> <host> <os> - packages + services whose source is "native".
native_sync() {
  local flake=$1 host=$2 os=$3
  [ "$os" = nixos ] && return 0
  [ "$os" = darwin ] && return 0 # nix-darwin's homebrew module does it declaratively

  local pm
  case "$os" in
    arch) pm=pacman ;;
    debian) pm=apt ;;
    alpine) pm=apk ;;
  esac

  read_into NATIVE_PKGS < <(host_list "$flake" "$host" native "$pm")
  read_into NATIVE_AUR < <(host_list "$flake" "$host" native aur)
  native_install "$os"

  local units=()
  case "$os" in
    alpine) read_into units < <(host_list "$flake" "$host" services openrc) ;;
    *) read_into units < <(host_list "$flake" "$host" services systemd) ;;
  esac
  [ ${#units[@]} -eq 0 ] || service_enable "$os" "${units[@]}"
}

# native_install <os> - installs the globals NATIVE_PKGS (repo packages) and
# NATIVE_AUR (Arch only). Shared by the nix presets and the no-nix preset.
NATIVE_PKGS=()
NATIVE_AUR=()
native_install() {
  local os=$1
  if [ ${#NATIVE_PKGS[@]} -eq 0 ] && [ ${#NATIVE_AUR[@]} -eq 0 ]; then
    ok "no native packages needed"
    return 0
  fi
  info "native packages ($os): ${NATIVE_PKGS[*]:-} ${NATIVE_AUR[*]:-}"

  if [ "$os" = arch ] && printf '%s\n' "${NATIVE_PKGS[@]:-}" | grep -qx -e steam -e 'lib32-.*'; then
    arch_enable_multilib
  fi
  pkg_refresh "$os"
  [ ${#NATIVE_PKGS[@]} -eq 0 ] || pkg_install "$os" "${NATIVE_PKGS[@]}" || true
  [ ${#NATIVE_AUR[@]} -eq 0 ] || aur_install "${NATIVE_AUR[@]}" || true
}

# Steam and lib32-* live in [multilib], which Arch ships commented out.
arch_enable_multilib() {
  grep -q '^\[multilib\]' /etc/pacman.conf && return 0
  info "enabling [multilib] in /etc/pacman.conf"
  as_root sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
}

# apply_nix <flake> <host> <os> <user> - build and activate everything.
apply_nix() {
  local flake=$1 host=$2 os=$3 user=$4
  case "$os" in
    nixos)
      info "nixos-rebuild switch (#$host)"
      as_root nixos-rebuild switch --flake "$flake#$host"
      ;;
    darwin)
      info "darwin-rebuild switch (#$host)"
      # First run: darwin-rebuild does not exist yet, so run it from the flake's
      # own pinned nix-darwin input. Activation needs root since nix-darwin 25.05.
      # Absolute paths: sudo resets PATH on macOS and would not find nix.
      if exists darwin-rebuild; then
        as_root "$(command -v darwin-rebuild)" switch --flake "$flake#$host"
      else
        as_root "$(command -v nix)" --extra-experimental-features 'nix-command flakes' \
          run_cmd "$flake#darwin-rebuild" -- switch --flake "$flake#$host"
      fi
      ;;
    arch | debian | alpine)
      # system-manager talks to systemd; skip it where systemd is not PID 1
      # (containers, WSL1) instead of failing halfway.
      if [ "$os" != alpine ] && [ ! -d /run/systemd/system ]; then
        warn "systemd is not running - skipping system-manager (nix.conf, sweeper timer)"
      elif [ "$os" != alpine ]; then
        info "system-manager switch (#$host)"
        # --sudo: builds as you, activates /etc and systemd units as root.
        run_cmd nixf run "$flake#system-manager" -- switch --flake "$flake#$host" --sudo
      fi
      info "home-manager switch (#$user@$host)"
      # -b backup: an existing file in the way is renamed, never overwritten.
      run_cmd nixf run "$flake#home-manager" -- switch --flake "$flake#$user@$host" -b backup
      gpu_setup "$flake" "$host" "$user"
      ;;
  esac
}

# Home Manager's non-NixOS GPU module needs a one-time root step that links
# the nix GPU drivers to /run/opengl-driver. Re-running it is harmless.
gpu_setup() {
  local flake=$1 host=$2 user=$3 pkg
  if [ "${DRY_RUN:-0}" = 1 ]; then
    run_cmd non-nixos-gpu-setup "(from homeConfigurations.\"$user@$host\")"
    return 0
  fi
  pkg=$(nixf build --no-link --print-out-paths \
    "$flake#homeConfigurations.\"$user@$host\".config.targets.genericLinux.gpu.setupPackage" 2>/dev/null) || return 0
  [ -x "$pkg/bin/non-nixos-gpu-setup" ] || return 0
  info "linking nix GPU drivers (non-nixos-gpu-setup)"
  as_root "$pkg/bin/non-nixos-gpu-setup" || warn "GPU setup failed - nix GUI apps may not start"
}

# Offer the configured login shell: the DISTRO's fish/zsh (registry: native).
# `command -v` is not enough - Home Manager's nix copy comes first in PATH,
# and a login shell must never live in ~/.nix-profile.
login_shell() {
  local want dir path current
  current=$(getent passwd "$(id -un)" 2>/dev/null | cut -d: -f7) || current=${SHELL:-}
  for want in fish zsh; do
    for dir in /usr/bin /bin /opt/homebrew/bin /usr/local/bin; do
      [ -x "$dir/$want" ] || continue
      path="$dir/$want"
      [ "$current" = "$path" ] && return 0
      if confirm "Use $path as your login shell?"; then
        grep -qx "$path" /etc/shells || as_root sh -c "echo '$path' >> /etc/shells"
        # As root: a user's own chsh asks for the password.
        as_root chsh -s "$path" "$(id -un)"
      fi
      return 0
    done
  done
}
