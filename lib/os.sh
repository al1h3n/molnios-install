# os.sh - which OS is this, and how do we install packages on it?
#
# detect_os prints one of: nixos darwin arch debian alpine
# (the same names hosts/<name>/default.nix uses for `os`), or fails.
# Derivatives are mapped by ID_LIKE: Manjaro/EndeavourOS/Artix -> arch,
# Ubuntu/Mint/Pop -> debian.

# MOLNI_OS_RELEASE lets tests point at a fake /etc/os-release.
detect_os() {
  if [ "$(uname -s)" = Darwin ]; then
    echo darwin
    return
  fi
  local file=${MOLNI_OS_RELEASE:-/etc/os-release}
  [ -r "$file" ] || die "cannot read $file - unsupported OS"

  local id like
  # os-release is shell syntax (KEY=value); a subshell keeps its vars out of ours.
  # shellcheck source=/dev/null
  id=$(. "$file" && echo "${ID:-}")
  # shellcheck source=/dev/null
  like=$(. "$file" && echo "${ID_LIKE:-}")

  local word
  for word in $id $like; do
    case "$word" in
      nixos) echo nixos; return ;;
      arch | artix | manjaro | endeavouros | cachyos) echo arch; return ;;
      debian | ubuntu) echo debian; return ;;
      alpine) echo alpine; return ;;
    esac
  done
  die "unsupported OS '$id' (ID_LIKE='$like'). Supported: NixOS, macOS, Arch, Debian, Alpine and their derivatives."
}

# nix "system" string for this machine, e.g. x86_64-linux, aarch64-darwin.
detect_system() {
  local arch kernel
  arch=$(uname -m)
  kernel=$(uname -s)
  case "$arch" in
    x86_64 | amd64) arch=x86_64 ;;
    aarch64 | arm64) arch=aarch64 ;;
    *) die "unsupported CPU '$arch' (need x86_64 or aarch64)" ;;
  esac
  case "$kernel" in
    Linux) echo "$arch-linux" ;;
    Darwin) echo "$arch-darwin" ;;
    *) die "unsupported kernel '$kernel'" ;;
  esac
}

# pkg_install <os> <pkg>... - install with the distro package manager.
# One big transaction first (fast); if that fails because one name is wrong,
# retry one by one so the others still get installed, and report the bad ones.
pkg_install() {
  local os=$1
  shift
  [ $# -gt 0 ] || return 0
  if _pkg_install_batch "$os" "$@"; then
    return 0
  fi
  warn "batch install failed, retrying packages one by one"
  local p failed=()
  for p in "$@"; do
    _pkg_install_batch "$os" "$p" || failed+=("$p")
  done
  if [ ${#failed[@]} -gt 0 ]; then
    warn "could not install: ${failed[*]}"
    warn "check the names in molnixos/modules/home/registry.nix (tests/verify-native.sh)"
    return 1
  fi
}

_pkg_install_batch() {
  local os=$1
  shift
  case "$os" in
    # -Syu, never -Sy alone: installing on top of a refreshed but not upgraded
    # system is a partial upgrade, which Arch does not support.
    arch) as_root pacman -Syu --needed --noconfirm "$@" ;;
    # confdef/confold: keep config files that already exist instead of asking.
    # The nix installer adds a "# Nix" block to /etc/zsh/zshrc, so a later
    # `apt-get install zsh` otherwise stops at an interactive conffile prompt.
    debian) as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold "$@" ;;
    alpine) as_root apk add --no-cache "$@" ;;
    darwin) run_cmd brew install "$@" ;;
    *) die "pkg_install: no package manager for '$os'" ;;
  esac
}

# Refresh the package index once before installing. (Arch: pacman -Syu in
# _pkg_install_batch does it, a lone -Sy would invite a partial upgrade.)
pkg_refresh() {
  case "$1" in
    debian) as_root apt-get update ;;
    alpine) as_root apk update ;;
    *) : ;;
  esac
}

# system_upgrade <os> - upgrade EVERY distro package to the latest version
# (molnios.sh --update). nix packages are updated by `nix flake update`.
system_upgrade() {
  case "$1" in
    arch)
      as_root pacman -Syu --noconfirm
      local helper
      for helper in paru yay; do
        if exists "$helper"; then run_cmd "$helper" -Sua --noconfirm; break; fi
      done
      ;;
    debian)
      as_root apt-get update
      as_root env DEBIAN_FRONTEND=noninteractive apt-get upgrade -y \
        -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold
      ;;
    alpine) as_root apk update && as_root apk upgrade ;;
    darwin) : ;; # Homebrew: nix-darwin upgrades it on switch (onActivation.upgrade)
    nixos) : ;;  # everything is nix
  esac
}

# AUR packages need a helper (paru or yay) running as the normal user.
aur_install() {
  [ $# -gt 0 ] || return 0
  local helper
  for helper in paru yay; do
    if exists "$helper"; then
      run_cmd "$helper" -Syu --needed --noconfirm "$@"
      return
    fi
  done
  warn "AUR packages skipped (no paru/yay): $*"
  warn "install one, e.g.: git clone https://aur.archlinux.org/paru-bin.git && cd paru-bin && makepkg -si"
  return 1
}

# service_enable <os> <unit>... - enable + start native services.
service_enable() {
  local os=$1 unit
  shift
  for unit in "$@"; do
    case "$os" in
      arch | debian) as_root systemctl enable --now "$unit" ;;
      alpine) as_root rc-update add "$unit" default && as_root rc-service "$unit" start ;;
    esac || warn "could not enable service $unit"
  done
}
