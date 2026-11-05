# host.sh - make sure molnixos has a hosts/<hostname>/ for this machine.
#
# A new machine gets a copy of hosts/example-<os>/ (or MolniPC for NixOS) with
# `system` and `users = [ "<you>" ];` filled in. A new person gets
# users/<login>.nix from users/_template.nix - the file NAME is the login, so
# no user name is written anywhere else. Flakes only see files git tracks, so
# new files are `git add`-ed (not committed: review and commit them yourself).

# host_template <os> - which host folder a new machine starts from.
host_template() {
  case "$1" in
    nixos) echo MolniPC ;;
    darwin) echo ManiacPC ;;
    *) echo "example-$1" ;;
  esac
}

# host_set <file> <key> <nix value> - set `  key = value;` in a host file,
# or add it after the `os = ...;` line when the file has no such key.
host_set() {
  local file=$1 key=$2 value=$3
  if [ "${DRY_RUN:-0}" = 1 ]; then
    printf '%s[dry-run]%s set %s = %s; in %s\n' "$YELLOW" "$RESET" "$key" "$value" "$file"
    return 0
  fi
  # awk, not sed: macOS sed cannot insert a line with \n.
  if grep -q "^  $key = " "$file"; then
    awk -v k="$key" -v v="$value" '$0 ~ "^  " k " = " { print "  " k " = " v ";"; next } { print }' "$file" >"$file.tmp"
  else
    awk -v k="$key" -v v="$value" '{ print } /^  os = .*;/ && !done { print "  " k " = " v ";"; done = 1 }' "$file" >"$file.tmp"
  fi
  mv "$file.tmp" "$file"
}

# user_ensure <flake dir> <login> - users/<login>.nix, from the template.
user_ensure() {
  local flake=$1 user=$2
  if [ -f "$flake/users/$user.nix" ]; then
    ok "using existing users/$user.nix"
    return 0
  fi
  [ -f "$flake/users/_template.nix" ] || die "no users/_template.nix in $flake"
  info "creating users/$user.nix (your apps, profiles and dotfiles)"
  run_cmd cp "$flake/users/_template.nix" "$flake/users/$user.nix"
  run_cmd git -C "$flake" add "users/$user.nix"
}

# host_ensure <flake dir> <host> <os> <system> <user>
host_ensure() {
  local flake=$1 host=$2 os=$3 system=$4 user=$5
  local dir="$flake/hosts/$host"
  if [ -f "$dir/default.nix" ]; then
    ok "using existing hosts/$host"
    return 0
  fi

  local template
  template=$(host_template "$os")
  [ -d "$flake/hosts/$template" ] || die "no template hosts/$template in $flake"
  info "creating hosts/$host from hosts/$template"
  run_cmd cp -r "$flake/hosts/$template" "$dir"
  # Plain `key = "value";` lines, so sed is enough (and easy to review).
  run_cmd sed -i.bak \
    -e "s|^\(  system = \)\"[^\"]*\";|\1\"$system\";|" \
    -e "1s|^# [^ ]* - .*|# $host - created by molnios.sh from hosts/$template.|" \
    "$dir/default.nix"
  run_cmd rm -f "$dir/default.nix.bak" "$dir/hardware-configuration.nix"
  # Only you on this machine (without the line: every user in users/).
  host_set "$dir/default.nix" users "[ \"$user\" ]"

  if [ "$os" = nixos ]; then
    # The one file that must come from this exact machine.
    info "generating hardware-configuration.nix"
    if [ "${DRY_RUN:-0}" = 1 ]; then
      run_cmd nixos-generate-config --show-hardware-config
    else
      nixos-generate-config --show-hardware-config >"$dir/hardware-configuration.nix"
    fi
  fi
  run_cmd git -C "$flake" add "hosts/$host"
  ok "hosts/$host created - review it, it is yours to edit"
}

# host_value <flake> <host> <expr over the host info> - read data from the flake.
# Example: host_value "$FLAKE" "$HOST" 'h: builtins.concatStringsSep "\n" (h.native.pacman or [])'
# No jq needed: nix prints the lines itself.
host_value() {
  nixf eval --raw "$1#lib.hosts.\"$2\"" --apply "$3"
}

# user_value <flake> <host> <login> <field> <default> - a per-user value
# (e.g. dotfiles.repo), or the default when the user is not on that host yet.
user_value() {
  host_value "$1" "$2" "h: toString ((h.perUser.\"$3\" or { }).$4 or \"$5\")" 2>/dev/null || printf '%s' "$5"
}

# host_list <flake> <host> <attr> <key> - one list from the host info, one per line.
host_list() {
  host_value "$1" "$2" "h: builtins.concatStringsSep \"\\n\" ((h.$3 or {}).$4 or [])"
}
