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

# repo_sync <repo> <dir> [branch] - clone if missing, fast-forward if present.
# Local edits are never thrown away: if the pull cannot fast-forward, it stops
# with a message instead. With a branch, the clone is moved to that branch
# first (and stays on it: later runs pull that branch).
repo_sync() {
  local name=$1 dir=$2 branch=${3:-} url
  url=$(repo_url "$1")
  if [ -d "$dir/.git" ]; then
    if [ -n "$branch" ] && [ "$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null)" != "$branch" ]; then
      repo_switch "$name" "$dir" "$branch"
      return
    fi
    info "updating $name"
    run_cmd git -C "$dir" pull --ff-only ||
      warn "$name: could not fast-forward (local changes?). Left as is: $dir"
  elif [ -e "$dir" ] && [ -n "$(ls -A "$dir" 2>/dev/null)" ]; then
    die "$dir exists and is not a git checkout. Move it away first."
  else
    info "cloning $name${branch:+ ($branch)} -> $dir"
    run_cmd mkdir -p "$(dirname "$dir")"
    run_cmd git clone --depth 1 ${branch:+--branch "$branch"} "$url" "$dir" ||
      die "$name: could not clone${branch:+ branch $branch} from $url"
  fi
}

# repo_switch <name> <dir> <branch> - put an existing (shallow) clone on
# another branch of origin. Uncommitted edits move along (new hosts/ files
# too); if they conflict with the branch, git refuses and nothing changes.
repo_switch() {
  local name=$1 dir=$2 branch=$3
  info "switching $name to branch $branch"
  # Shallow clones fetch only their first branch; teach origin this one too.
  git -C "$dir" config --get-all remote.origin.fetch |
    grep -qxF -e '+refs/heads/*:refs/remotes/origin/*' -e "+refs/heads/$branch:refs/remotes/origin/$branch" ||
    run_cmd git -C "$dir" remote set-branches --add origin "$branch"
  run_cmd git -C "$dir" fetch --depth 1 origin "$branch" ||
    die "$name: no branch '$branch' on $(git -C "$dir" remote get-url origin)"
  if git -C "$dir" show-ref --verify --quiet "refs/heads/$branch"; then
    # Been on it before: keep its local commits, just fast-forward.
    run_cmd git -C "$dir" checkout "$branch" ||
      die "$name: local changes in $dir conflict with $branch - commit or stash them first"
    run_cmd git -C "$dir" merge --ff-only "origin/$branch" ||
      warn "$name: $branch could not fast-forward (local commits?). Left as is: $dir"
  else
    run_cmd git -C "$dir" checkout -b "$branch" --track "origin/$branch" ||
      die "$name: local changes in $dir conflict with $branch - commit or stash them first"
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
