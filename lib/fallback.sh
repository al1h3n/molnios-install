# fallback.sh - the "native" preset: MolniOS without nix.
#
# For machines where nix is not wanted or not possible. Everything comes from
# plain text files that `nix run .#export-fallback` wrote into
# molnixos/fallback/<host>/ on a machine that does have nix:
#   native-<pacman|aur|apt|apk|brew|cask>.txt   packages, one per line
#   services-<systemd|openrc>.txt               services to enable
#   links.tsv                                   "<target in $HOME><TAB><source in molnios-shared>"
#   templates.tsv                               "<target><TAB><template>" (@HOME@ ... filled in)
# So the package lists and symlinks are the very same data the nix presets
# use - just applied with the distro package manager and `ln -s`.

# fallback_apply <flake dir> <template host> <os> <shared dir>
fallback_apply() {
  local flake=$1 template=$2 os=$3 shared=$4
  local dir="$flake/fallback/$template"
  [ -d "$dir" ] || die "no $dir - run 'nix run .#export-fallback' in molnixos on a machine with nix"

  local pm units=()
  case "$os" in
    arch) pm=pacman ;;
    debian) pm=apt ;;
    alpine) pm=apk ;;
    darwin) pm=brew ;;
  esac
  read_into NATIVE_PKGS < <(lines "$dir/native-$pm.txt")
  read_into NATIVE_AUR < <(lines "$dir/native-aur.txt")

  if [ "$os" = darwin ]; then
    exists brew || die "the no-nix preset on macOS needs Homebrew (https://brew.sh)"
    [ ${#NATIVE_PKGS[@]} -eq 0 ] || run_cmd brew install "${NATIVE_PKGS[@]}" || true
    local casks=()
    read_into casks < <(lines "$dir/native-cask.txt")
    [ ${#casks[@]} -eq 0 ] || run_cmd brew install --cask "${casks[@]}" || true
  else
    native_install "$os"
    case "$os" in
      alpine) read_into units < <(lines "$dir/services-openrc.txt") ;;
      *) read_into units < <(lines "$dir/services-systemd.txt") ;;
    esac
    [ ${#units[@]} -eq 0 ] || service_enable "$os" "${units[@]}"
  fi

  links_apply "$dir/links.tsv" "$shared"
  templates_apply "$dir/templates.tsv" "$shared"
  if [ -s "$dir/skipped.txt" ]; then
    warn "these apps need nix on $os and were skipped:"
    sed 's/^/       /' "$dir/skipped.txt" >&2
  fi
}

# fill <path> <shared dir> - @HOME@/@SHARED@ -> real paths; relative = in $HOME / in shared.
_fill_target() { local t=${1//@SHARED@/$2}; t=${t//@HOME@/$HOME}; case "$t" in /*) echo "$t" ;; *) echo "$HOME/$t" ;; esac; }
_fill_source() { local s=${1//@SHARED@/$2}; s=${s//@HOME@/$HOME}; case "$s" in /*) echo "$s" ;; *) echo "$2/$s" ;; esac; }

# A value safe inside sed's s|...|VALUE| (escapes | & and backslash).
esc() { printf '%s' "$1" | sed 's/[|&\\]/\\&/g'; }

# templates_apply <templates.tsv> <shared dir> - render @HOME@-style
# placeholders, same names as molnixos's molni.templates.
templates_apply() {
  local tsv=$1 shared=$2 target src
  [ -f "$tsv" ] || return 0
  while IFS=$'\t' read -r target src || [ -n "$target" ]; do
    [ -n "$target" ] || continue
    target=$(_fill_target "$target" "$shared")
    src=$(_fill_source "$src" "$shared")
    [ -f "$src" ] || { warn "template missing, skipped: $src"; continue; }
    if [ "${DRY_RUN:-0}" = 1 ]; then
      printf '%s[dry-run]%s render %s -> %s\n' "$YELLOW" "$RESET" "$src" "$target"
      continue
    fi
    mkdir -p "$(dirname "$target")"
    [ -L "$target" ] && rm -f "$target"
    sed -e "s|@HOME@|$(esc "$HOME")|g" -e "s|@USER@|$(esc "$(id -un)")|g" \
      -e "s|@LSHARED@|$(esc "$HOME/.local/share/molnios")|g" -e "s|@SHARED@|$(esc "$shared")|g" \
      -e "s|@MEDIA@|$(esc "$HOME/.local/share/molnios/molnios-media/wallpapers")|g" "$src" >"$target"
  done <"$tsv"
}

# links_apply <links.tsv> <shared dir> - plain symlinks, with backups.
# A real file in the way is moved to <file>.backup (never deleted); an old
# symlink is simply replaced.
links_apply() {
  local tsv=$1 shared=$2 target src
  while IFS=$'\t' read -r target src || [ -n "$target" ]; do
    [ -n "$target" ] || continue
    src=$(_fill_source "$src" "$shared")
    target=$(_fill_target "$target" "$shared")
    if [ ! -e "$src" ]; then
      warn "link source missing, skipped: $src"
      continue
    fi
    run_cmd mkdir -p "$(dirname "$target")"
    if [ -e "$target" ] && [ ! -L "$target" ]; then
      run_cmd mv "$target" "$target.backup"
    fi
    run_cmd ln -sfn "$src" "$target"
  done <"$tsv"
  ok "symlinks from $(basename "$(dirname "$tsv")")/links.tsv applied"
}

# links_remove <links.tsv> - undo links_apply (only links that point into shared).
links_remove() {
  local tsv=$1 shared=$2 target
  while IFS=$'\t' read -r target _; do
    [ -n "$target" ] || continue
    target="$HOME/$target"
    if [ -L "$target" ] && [[ "$(readlink "$target")" == "$shared"/* ]]; then
      run_cmd rm "$target"
      if [ -e "$target.backup" ]; then run_cmd mv "$target.backup" "$target"; fi
    fi
  done <"$tsv"
  return 0
}
