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
# Everything fetches the LATEST version by default (flake inputs, repos);
# `--update` also upgrades every distro package. `--locked` keeps flake.lock.
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
${BOLD}Usage:${RESET} $(basename "$0") [options]      (after install also just: molnios [options])

${BOLD}Presets${RESET} (what to do when nix cannot install something well):
  -p, --preset nix       nixpkgs wherever it works, distro packages only where
                         it cannot (PAM, drivers, login shells...). Default.
  -p, --preset hybrid    also take GUI apps from the distro package manager.
  -p, --preset native    no nix at all: distro packages + plain symlinks.
  -nn, --no-nix          same as --preset native (v1 flag).

${BOLD}Options:${RESET}
  -u, --update           update EVERYTHING to the latest version: this
                         installer, molnixos, your dotfiles, wallpapers, all
                         flake inputs (nixpkgs, Home Manager...) and every
                         distro package (pacman+AUR / apt / apk / Homebrew),
                         then apply
      --locked           keep flake.lock as it is (default: latest inputs)
  -H, --host NAME        host folder in molnixos/hosts (default: hostname)
  -fb, --flake-branch B      use branch B of molnixos
  -sb, --shared-branch B     use branch B of your dotfiles repo
  -ib, --installer-branch B  use branch B of this installer
                         (test a branch without merging it to main; later
                         runs stay on B until you pass another, e.g. -fb main)
  -dp, --download-photos static wallpapers (~711 MiB)
  -dv, --download-videos video wallpapers (~2.1 GiB)
  -cg, --collect-garbage delete old nix generations afterwards
  -re, --reboot          reboot when done
  -y, -np, --yes         never ask, answer yes
  -n, --dry-run          only print what would be done
      --nix-installer rust|classic   how to install nix (default: rust)
  -h, --help             this help

${BOLD}Who and what:${RESET} molnixos/users/<login>.nix (created for you on the first run)
picks your profiles (gaming, dev, media...), apps and dotfiles repo;
molnixos/hosts/<host>/ describes the machine. See molnixos/docs/PLAN.md.

${BOLD}Environment:${RESET}
  MOLNI_GIT_HOST   git host for all repos, e.g. https://gitlab.com (default: GitHub)
  MOLNI_FLAKE      where molnixos is cloned
  MOLNI_SHARED     where your dotfiles are cloned (default: from your user file)

${BOLD}Examples:${RESET} $(basename "$0") --preset hybrid -dp      $(basename "$0") --update
          $(basename "$0") -u -fb feat/improvement -sb feat/improvement
EOF
}

PRESET="" HOST="" UPDATE=0 FLAKE_UPDATE=1 PHOTOS=0 VIDEOS=0 GC=0 REBOOT=0
ASSUME_YES=0 DRY_RUN=0 NIX_INSTALLER=rust FLAKE_BRANCH="" SHARED_BRANCH="" INSTALLER_BRANCH=""

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      -p | --preset) PRESET=${2:-}; shift ;;
      -nn | --no-nix) PRESET=native ;;
      -H | --host) HOST=${2:-}; shift ;;
      -fb | --flake-branch) FLAKE_BRANCH=${2:?$1 needs a branch}; shift ;;
      -sb | --shared-branch) SHARED_BRANCH=${2:?$1 needs a branch}; shift ;;
      -ib | --installer-branch) INSTALLER_BRANCH=${2:?$1 needs a branch}; shift ;;
      -u | --update) UPDATE=1 ;;
      --locked) FLAKE_UPDATE=0 ;;
      -fu | --flake-update) FLAKE_UPDATE=1 ;; # v1 flag; latest is the default now
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

# --update / --installer-branch: pull this installer (or move it to the
# branch) first, and restart it if it changed, so the rest runs the new code.
self_update() {
  [ "${MOLNI_SELF_UPDATED:-0}" = 1 ] && return 0
  git -C "$SCRIPT_DIR" rev-parse --git-dir >/dev/null 2>&1 || return 0
  local before after
  before=$(git -C "$SCRIPT_DIR" rev-parse HEAD)
  if [ -n "$INSTALLER_BRANCH" ]; then
    repo_sync molnios-install "$SCRIPT_DIR" "$INSTALLER_BRANCH"
  else
    git -C "$SCRIPT_DIR" pull --ff-only -q 2>/dev/null || { warn "installer: could not fast-forward, using this version"; return 0; }
  fi
  after=$(git -C "$SCRIPT_DIR" rev-parse HEAD)
  if [ "$before" != "$after" ]; then
    info "installer updated, restarting it"
    MOLNI_SELF_UPDATED=1 exec bash "$SCRIPT_DIR/molnios.sh" "$@"
  fi
}

# media_if <flag> <media path> <repo> - wallpapers when asked, or when they
# were downloaded before (so --update keeps them current).
media_if() {
  if [ "$1" = 1 ] || [ -d "$(dirname "$2")/repos/$3" ]; then
    media_sync "$2" "$3"
  fi
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

main() {
  parse_args "$@"
  [ "$(id -u)" != 0 ] || die "run molnios.sh as your normal user - it uses sudo only where needed"
  { [ "$UPDATE" = 0 ] && [ -z "$INSTALLER_BRANCH" ]; } || [ "$DRY_RUN" = 1 ] || self_update "$@"

  local os system user lshared flake shared media installer
  os=$(detect_os)
  system=$(detect_system)
  user=$(id -un)
  HOST=${HOST:-$(hostname -s 2>/dev/null || hostname)}
  lshared="$HOME/.local/share/molnios"
  if [ "$os" = nixos ]; then
    flake=${MOLNI_FLAKE:-/etc/nixos/molnixos}
  else
    flake=${MOLNI_FLAKE:-$lshared/molnixos}
  fi
  media="$lshared/molnios-media/wallpapers"

  printf '\e[38;5;213mMolniOS installer v2\e[0m\n'
  info "os=$os system=$system user=$user host=$HOST preset=${PRESET:-from host/user file}"
  [ "$DRY_RUN" = 1 ] && warn "dry run: nothing will be changed"

  prerequisites "$os"

  # ── No nix at all ────────────────────────────────────────────────────────
  if [ "$PRESET" = native ]; then
    [ "$os" = nixos ] && die "--preset native makes no sense on NixOS"
    shared=${MOLNI_SHARED:-$lshared/shared}
    repo_sync molnixos "$flake" "$FLAKE_BRANCH"
    repo_sync molnios-shared "$shared" "$SHARED_BRANCH"
    media_if "$PHOTOS" "$media" molnios-media-static
    media_if "$VIDEOS" "$media" molnios-media-dynamic
    [ "$UPDATE" = 0 ] || system_upgrade "$os"
    confirm "Install the $(host_template "$os") package lists and symlinks without nix?" || exit 0
    fallback_apply "$flake" "$(host_template "$os")" "$os" "$shared"
    login_shell
    ok "done (native preset). Run again with --preset nix any time to switch to nix."
    exit 0
  fi

  # ── With nix ─────────────────────────────────────────────────────────────
  nix_install "$os"

  # 1. The flake, and this machine + this person in it.
  ensure_dir_owned "$flake"
  repo_sync molnixos "$flake" "$FLAKE_BRANCH"
  local new=0
  [ -f "$flake/hosts/$HOST/default.nix" ] || new=1
  [ "$UPDATE" = 0 ] || [ "$new" = 0 ] || die "--update: no hosts/$HOST yet - run without --update first"
  user_ensure "$flake" "$user"
  host_ensure "$flake" "$HOST" "$os" "$system" "$user"
  if [ -n "$PRESET" ]; then
    host_set "$flake/hosts/$HOST/default.nix" preset "\"$PRESET\""
    run_cmd git -C "$flake" add "hosts/$HOST"
  fi

  # 2. Latest versions of every flake input (nixpkgs, Home Manager, ...).
  if [ "$FLAKE_UPDATE" = 1 ]; then
    info "updating flake inputs to their latest versions"
    run_cmd nixf flake update --flake "$flake"
  else
    run_cmd nixf flake lock "$flake" # only adds missing inputs
  fi

  # A dry run does not really create a new host, so read its template instead.
  local info_host=$HOST
  [ "$DRY_RUN" = 1 ] && [ "$new" = 1 ] && info_host=$(host_template "$os")

  # 3. Your dotfiles (repo and folder come from your user file / profiles),
  #    this installer (for the `molnios` command) and wallpapers.
  local dot_repo
  dot_repo=$(user_value "$flake" "$info_host" "$user" dotfiles.repo al1h3n/molnios-shared)
  shared=${MOLNI_SHARED:-$(user_value "$flake" "$info_host" "$user" dotfiles.path "$lshared/shared")}
  installer=$(host_value "$flake" "$info_host" 'h: h.installerPath' 2>/dev/null || echo "$lshared/molnios-install")
  ensure_dir_owned "$shared"
  repo_sync "$dot_repo" "$shared" "$SHARED_BRANCH"
  if [ "$(cd "$SCRIPT_DIR" && pwd -P)" != "$(cd "$installer" 2>/dev/null && pwd -P)" ]; then
    repo_sync molnios-install "$installer" "$INSTALLER_BRANCH"
  fi
  media_if "$PHOTOS" "$media" molnios-media-static
  media_if "$VIDEOS" "$media" molnios-media-dynamic

  if [ "$DRY_RUN" != 1 ] || [ "$new" = 0 ]; then
    info "what goes where on $HOST:"
    # shellcheck disable=SC2016 # a nix expression, not shell
    host_value "$flake" "$info_host" 'h: builtins.concatStringsSep "\n" (
      [ "  users:   ${toString h.users}" "  preset:  ${h.preset}" ]
      ++ builtins.attrValues (builtins.mapAttrs (k: v: "  native ${k}: ${toString v}") h.native)
      ++ map (s: "  skipped: ${s}") h.skipped)'
    echo
  fi
  [ "$new" = 0 ] || confirm "New files in $flake: hosts/$HOST and users/$user.nix - review them now if you like. Continue?" || exit 0

  # 4. Distro packages: everything upgraded on --update, then what nix cannot do.
  if [ "$UPDATE" = 1 ]; then
    info "upgrading all distro packages"
    system_upgrade "$os"
  fi
  native_sync "$flake" "$info_host" "$os"

  # 5. Switch to the new configuration.
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
  ok "MolniOS is up to date on $HOST ($os)."
  echo "   Dotfiles: $shared (live: edits apply immediately)."
  echo "   Your apps/profiles: $flake/users/$user.nix   Machine: $flake/hosts/$HOST/"
  echo "   Update everything later with: molnios --update"
  [ "$REBOOT" = 0 ] || as_root reboot
}

main "$@"
