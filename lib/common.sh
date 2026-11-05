# common.sh - small helpers every other file uses.
# Sourced by molnios.sh; never run on its own.

# Colours only when printing to a terminal.
# shellcheck disable=SC2034 # BOLD etc. are used by molnios.sh
if [ -t 1 ]; then
  RED=$'\e[31m' GREEN=$'\e[32m' YELLOW=$'\e[33m' BLUE=$'\e[34m' BOLD=$'\e[1m' RESET=$'\e[0m'
else
  RED='' GREEN='' YELLOW='' BLUE='' BOLD='' RESET=''
fi

info() { printf '%s==>%s %s\n' "$BLUE" "$RESET" "$*"; }
ok() { printf '%s ok%s %s\n' "$GREEN" "$RESET" "$*"; }
warn() { printf '%swarn%s %s\n' "$YELLOW" "$RESET" "$*" >&2; }
die() { printf '%serror%s %s\n' "$RED" "$RESET" "$*" >&2; exit 1; }

exists() { command -v "$1" >/dev/null 2>&1; }

# run_cmd CMD... - runs a command, or only prints it with --dry-run.
# Every command that changes the system goes through run_cmd or as_root, so a dry
# run shows exactly what a real run would do.
run_cmd() {
  if [ "${DRY_RUN:-0}" = 1 ]; then
    printf '%s[dry-run]%s %s\n' "$YELLOW" "$RESET" "$*"
    return 0
  fi
  "$@"
}

# as_root CMD... - the same, with sudo/doas when we are not root already.
# The installer itself runs as the normal user (nix and Home Manager must),
# and only escalates for package managers and system activation.
as_root() {
  if [ "$(id -u)" = 0 ]; then
    run_cmd "$@"
  elif exists sudo; then
    run_cmd sudo "$@"
  elif exists doas; then
    run_cmd doas "$@"
  else
    die "need root for: $* (install sudo or doas)"
  fi
}

# confirm "question" - yes/no prompt; --yes answers yes to everything.
confirm() {
  [ "${ASSUME_YES:-0}" = 1 ] && return 0
  if exists gum; then
    gum confirm "$1"
    return
  fi
  local reply
  read -r -p "$1 [y/N] " reply
  case "$reply" in [Yy]*) return 0 ;; *) return 1 ;; esac
}

# nix with flakes on, even before /etc/nix/nix.conf says so.
nixf() { nix --extra-experimental-features 'nix-command flakes' "$@"; }

# Lines of a file, without blank lines or # comments.
lines() { [ -f "$1" ] && grep -v -e '^[[:space:]]*$' -e '^[[:space:]]*#' "$1" || true; }

# read_into <array name> - read stdin lines into an array, skipping blanks.
# (`mapfile` needs bash 4; macOS still ships bash 3.2.) The eval only ever
# sees the array name, which is a literal in our own code - the values are
# referenced as "$_l", never pasted into the eval string.
read_into() {
  local _l
  eval "$1=()"
  # `|| [ -n "$_l" ]`: keep the last line even without a trailing newline
  # (`nix eval --raw` prints none - without this, the last package was lost).
  while IFS= read -r _l || [ -n "$_l" ]; do
    [ -n "$_l" ] && eval "$1+=(\"\$_l\")"
  done
  return 0
}
