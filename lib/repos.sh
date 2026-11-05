# repos.sh - clone or update the MolniOS repositories.
#
# v1 deleted .git after cloning and tracked a ".repo_commit" file to detect
# updates. v2 keeps .git (shallow): updating is a plain `git pull`, and the
# molnixos flake *needs* git (flakes only see tracked files).
#
# Mirrors: MOLNI_GIT_HOST=https://gitlab.com (or https://codeberg.org).

MOLNI_GIT_HOST=${MOLNI_GIT_HOST:-https://github.com}
MOLNI_GIT_BASE=${MOLNI_GIT_BASE:-$MOLNI_GIT_HOST/al1h3n}

# repo_url <name | owner/repo | URL>
#   molnixos          -> $MOLNI_GIT_BASE/molnixos   (a MolniOS repo)
#   someone/dotfiles  -> $MOLNI_GIT_HOST/someone/dotfiles
#   https://...       -> as is
repo_url() {
  case "$1" in
    *://* | git@*) echo "$1" ;;
    */*) echo "$MOLNI_GIT_HOST/$1" ;;
    *) echo "$MOLNI_GIT_BASE/$1" ;;
  esac
}

# repo_sync <repo> <dir> - clone if missing, fast-forward if present.
# Local edits are never thrown away: if the pull cannot fast-forward, it stops
# with a message instead.
repo_sync() {
  local name=$1 dir=$2 url
  url=$(repo_url "$1")
  if [ -d "$dir/.git" ]; then
    info "updating $name"
    run_cmd git -C "$dir" pull --ff-only ||
      warn "$name: could not fast-forward (local changes?). Left as is: $dir"
  elif [ -e "$dir" ] && [ -n "$(ls -A "$dir" 2>/dev/null)" ]; then
    die "$dir exists and is not a git checkout. Move it away first."
  else
    info "cloning $name -> $dir"
    run_cmd mkdir -p "$(dirname "$dir")"
    run_cmd git clone --depth 1 "$url" "$dir"
  fi
}

# Wallpapers. v1 cloned BOTH media repos into the same folder, so the second
# clone was skipped (or, with -f, deleted the first). Each repo now gets its own
# folder, and its top-level folders are linked into the wallpaper path:
#   molnios-media/repos/molnios-media-static/static  ->  wallpapers/static
#   molnios-media/repos/molnios-media-dynamic/video  ->  wallpapers/video
media_sync() { # <media path> <repo>...
  local media=$1 repo src
  shift
  local root
  root="$(dirname "$media")/repos"
  for repo in "$@"; do
    repo_sync "$repo" "$root/$repo"
    for src in "$root/$repo"/*/; do
      [ -d "$src" ] || continue
      run_cmd mkdir -p "$media"
      run_cmd ln -sfn "${src%/}" "$media/$(basename "$src")"
    done
  done
}
