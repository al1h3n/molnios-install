#!/usr/bin/env bash
# MM    MM              dd           bb                         lll  1  hh      333333
# MMM  MMM   aa aa      dd   eee     bb      yy   yy      aa aa lll 111 hh         3333 nn nnn
# MM MM MM  aa aaa  dddddd ee   e    bbbbbb  yy   yy     aa aaa lll  11 hhhhhh    3333  nnn  nn
# MM    MM aa  aaa dd   dd eeeee     bb   bb  yyyyyy    aa  aaa lll  11 hh   hh     333 nn   nn
# MM    MM  aaa aa  dddddd  eeeee    bbbbbb       yy     aaa aa lll 111 hh   hh 333333  nn   nn
#                                             yyyyy
# molnios.sh v2 - installs MolniOS declaratively with nix on NixOS, macOS,
# Arch, Debian and Alpine (and their derivatives).
#
# How it works:
#   1. Detect the OS (os.sh) and install nix if needed (nix.sh).
#   2. Clone molnixos (the flake) and molnios-shared (the dotfiles) (repos.sh).
#   3. Make sure molnixos has hosts/<this hostname>/ (host.sh).
#   4. Install what nix cannot do well here with the distro package manager,
#      then switch the nix configurations (apply.sh).
#   With --preset native, step 4 uses plain package lists and symlinks
#   instead of nix (fallback.sh).
#
# The old v1 installer is in deprecated/v1/.
set -euo pipefail

SELF=$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")
SCRIPT_DIR=$(cd "$(dirname "$SELF")" && pwd)
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/os.sh
. "$SCRIPT_DIR/lib/os.sh"
# shellcheck source=lib/nix.sh
. "$SCRIPT_DIR/lib/nix.sh"
# shellcheck source=lib/repos.sh
. "$SCRIPT_DIR/lib/repos.sh"
# shellcheck source=lib/host.sh
. "$SCRIPT_DIR/lib/host.sh"
# shellcheck source=lib/apply.sh
. "$SCRIPT_DIR/lib/apply.sh"
# shellcheck source=lib/fallback.sh
. "$SCRIPT_DIR/lib/fallback.sh"

usage() {
  cat <<EOF
${BOLD}Usage:${RESET} $(basename "$0") [options]

${BOLD}Presets${RESET} (what to do when nix cannot install something well):
  -p, --preset nix       nixpkgs wherever it works, distro packages only where
                         it cannot (PAM, drivers, login shells...). Default.
  -p, --preset hybrid    also take GUI apps from the distro package manager.
  -p, --preset native    no nix at all: distro packages + plain symlinks.
  -nn, --no-nix          same as --preset native (v1 flag).

${BOLD}Options:${RESET}
  -H, --host NAME        host folder in molnixos/hosts (default: hostname)
  -u, --update           pull the repos and apply again
  -fu, --flake-update    update flake.lock (all inputs) before applying
  -dp, --download-photos static wallpapers (~711 MiB)
  -dv, --download-videos video wallpapers (~2.1 GiB)
  -cg, --collect-garbage delete old nix generations afterwards
  -re, --reboot          reboot when done
  -y, -np, --yes         never ask, answer yes
  -n, --dry-run          only print what would be done
      --nix-installer rust|classic   how to install nix (default: rust)
  -h, --help             this help

${BOLD}Environment:${RESET}
  MOLNI_GIT_BASE   mirror, e.g. https://gitlab.com/al1h3n (default: GitHub)
  MOLNI_FLAKE      where molnixos is cloned
  MOLNI_SHARED     where molnios-shared is cloned

${BOLD}Example:${RESET} $(basename "$0") --preset hybrid -dp
EOF
}

PRESET="" HOST="" UPDATE=0 FLAKE_UPDATE=0 PHOTOS=0 VIDEOS=0 GC=0 REBOOT=0
ASSUME_YES=0 DRY_RUN=0 NIX_INSTALLER=rust

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      -p | --preset) PRESET=${2:-}; shift ;;
      -nn | --no-nix) PRESET=native ;;
      -H | --host) HOST=${2:-}; shift ;;
      -u | --update) UPDATE=1 ;;
      -fu | --flake-update) FLAKE_UPDATE=1 ;;
      -dp | --download-photos) PHOTOS=1 ;;
      -dv | --download-videos) VIDEOS=1 ;;
      -cg | --collect-garbage) GC=1 ;;
      -re | --reboot) REBOOT=1 ;;
      -y | -np | --yes | --no-prompt) ASSUME_YES=1 ;;
      -n | --dry-run) DRY_RUN=1 ;;
      --nix-installer) NIX_INSTALLER=${2:-}; shift ;;
      -h | --help | -\?) usage; exit 0 ;;
      *) usage >&2; die "unknown option: $1" ;;
    esac
    shift
  done
  case "$PRESET" in "" | nix | hybrid | native) ;; *) die "--preset must be nix, hybrid or native" ;; esac
  case "$NIX_INSTALLER" in rust | classic) ;; *) die "--nix-installer must be rust or classic" ;; esac
}

# git and curl before anything else (the official nix installer needs both).
prerequisites() {
  local os=$1 missing=()
  exists git || missing+=(git)
  exists curl || missing+=(curl)
  [ ${#missing[@]} -eq 0 ] && return 0
  info "installing prerequisites: ${missing[*]}"
  case "$os" in
    debian) missing+=(ca-certificates xz-utils) ;;
    darwin) die "install the Xcode command line tools first: xcode-select --install" ;;
    nixos) die "git/curl missing on NixOS: nix-shell -p git curl --run '$0'" ;;
  esac
  pkg_refresh "$os"
  pkg_install "$os" "${missing[@]}"
}

# On NixOS the flake and dotfiles live in /etc/nixos (v1 layout), owned by you.
ensure_dir_owned() {
  local dir=$1
  [ -d "$dir" ] && [ -w "$dir" ] && return 0
  [ -w "$(dirname "$dir")" ] && return 0
  as_root mkdir -p "$dir"
  as_root chown "$(id -u):$(id -g)" "$dir"
}

# Set the preset in a host file (new hosts, or when --preset is given).
set_preset() {
  local file="$1/hosts/$2/default.nix" preset=$3
  if grep -q '^  preset = ' "$file"; then
    run_cmd sed -i.bak "s|^  preset = \"[a-z]*\";|  preset = \"$preset\";|" "$file"
  else # templates like MolniPC have no preset line: add one after `os = ...;`
    run_cmd sed -i.bak "s|^\(  os = .*;\)$|\1\n  preset = \"$preset\";|" "$file"
  fi
  run_cmd rm -f "$file.bak"
}

main() {
  parse_args "$@"
  [ "$(id -u)" != 0 ] || die "run molnios.sh as your normal user - it uses sudo only where needed"

  local os system user lshared flake shared media
  os=$(detect_os)
  system=$(detect_system)
  user=$(id -un)
  HOST=${HOST:-$(hostname -s 2>/dev/null || hostname)}
  lshared="$HOME/.local/share/molnios"
  if [ "$os" = nixos ]; then
    flake=${MOLNI_FLAKE:-/etc/nixos/molnixos}
    shared=${MOLNI_SHARED:-/etc/nixos/shared}
  else
    flake=${MOLNI_FLAKE:-$lshared/molnixos}
    shared=${MOLNI_SHARED:-$lshared/shared}
  fi
  media="$lshared/molnios-media/wallpapers"

  printf '\e[38;5;213mMolniOS installer v2 by\e[0m \e[38;5;171mal1h3n\e[0m\n'
  info "os=$os system=$system user=$user host=$HOST preset=${PRESET:-from host file}"
  [ "$DRY_RUN" = 1 ] && warn "dry run: nothing will be changed"

  prerequisites "$os"

  # ── No nix at all ────────────────────────────────────────────────────────
  if [ "$PRESET" = native ]; then
    [ "$os" = nixos ] && die "--preset native makes no sense on NixOS"
    repo_sync molnixos "$flake"
    repo_sync molnios-shared "$shared"
    [ "$PHOTOS" = 0 ] || media_sync "$media" molnios-media-static
    [ "$VIDEOS" = 0 ] || media_sync "$media" molnios-media-dynamic
    confirm "Install the $(host_template "$os") package lists and symlinks without nix?" || exit 0
    fallback_apply "$flake" "$(host_template "$os")" "$os" "$shared"
    login_shell
    ok "done (native preset). Run again with --preset nix any time to switch to nix."
    exit 0
  fi

  # ── With nix ─────────────────────────────────────────────────────────────
  nix_install "$os"
  ensure_dir_owned "$flake"
  ensure_dir_owned "$shared"
  repo_sync molnixos "$flake"
  repo_sync molnios-shared "$shared"
  [ "$PHOTOS" = 0 ] || media_sync "$media" molnios-media-static
  [ "$VIDEOS" = 0 ] || media_sync "$media" molnios-media-dynamic

  local new=0
  [ -f "$flake/hosts/$HOST/default.nix" ] || new=1
  if [ "$UPDATE" = 1 ] && [ "$new" = 1 ]; then
    die "--update: no hosts/$HOST yet - run without --update first"
  fi
  host_ensure "$flake" "$HOST" "$os" "$system" "$user"
  if [ -n "$PRESET" ]; then
    set_preset "$flake" "$HOST" "$PRESET"
    run_cmd git -C "$flake" add "hosts/$HOST"
  fi

  if [ "$FLAKE_UPDATE" = 1 ]; then
    info "updating flake inputs"
    run_cmd nixf flake update --flake "$flake"
  else
    # Adds inputs that are missing from flake.lock; changes nothing else.
    run_cmd nixf flake lock "$flake"
  fi

  # A dry run does not really create a new host, so read its template instead.
  local info_host=$HOST
  [ "$DRY_RUN" = 1 ] && [ "$new" = 1 ] && info_host=$(host_template "$os")

  if [ "$DRY_RUN" != 1 ] || [ "$new" = 0 ]; then
    info "what goes where on $HOST:"
    # shellcheck disable=SC2016 # a nix expression, not shell
    host_value "$flake" "$info_host" 'h: builtins.concatStringsSep "\n" (
      [ "  preset:  ${h.preset}" ]
      ++ builtins.attrValues (builtins.mapAttrs (k: v: "  native ${k}: ${toString (if builtins.isList v then v else builtins.attrNames v)}") h.native)
      ++ map (s: "  skipped: ${s}") h.skipped)'
    echo
  fi
  [ "$new" = 0 ] || confirm "hosts/$HOST is new - review $flake/hosts/$HOST/default.nix now if you like. Continue?" || exit 0

  native_sync "$flake" "$info_host" "$os"
  apply_nix "$flake" "$HOST" "$os" "$user"
  [ "$os" = nixos ] || [ "$os" = darwin ] || login_shell

  if [ "$GC" = 1 ]; then
    info "collecting garbage"
    run_cmd nix-collect-garbage -d
  fi
  if [ "$DRY_RUN" = 1 ]; then
    ok "dry run finished - nothing was changed."
    return 0
  fi
  ok "MolniOS is installed on $HOST ($os)."
  echo "   Edit dotfiles in $shared - changes apply immediately (symlinks)."
  echo "   Edit $flake/hosts/$HOST/default.nix, then run: molnios.sh --update"
  [ "$REBOOT" = 0 ] || as_root reboot
}

main "$@"
