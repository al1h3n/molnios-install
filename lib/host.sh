# host.sh - make sure molnixos has a hosts/<hostname>/ for this machine.
#
# A new machine gets a copy of hosts/example-<os>/ (or MolniPC for NixOS) with
# `user` and `system` filled in. Flakes only see files git tracks, so the new
# folder is `git add`-ed (not committed: you can still review and commit it).

# host_template <os> - which host folder a new machine starts from.
host_template() {
  case "$1" in
    nixos) echo MolniPC ;;
    darwin) echo ManiacPC ;;
    *) echo "example-$1" ;;
  esac
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
    -e "s|^\(  user = \)\"[^\"]*\";|\1\"$user\";|" \
    -e "s|^\(  system = \)\"[^\"]*\";|\1\"$system\";|" \
    -e "1s|^# [^ ]* - .*|# $host - created by molnios.sh from hosts/$template.|" \
    "$dir/default.nix"
  run_cmd rm -f "$dir/default.nix.bak" "$dir/hardware-configuration.nix"

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

# host_list <flake> <host> <attr> <key> - one list from the host info, one per line.
host_list() {
  host_value "$1" "$2" "h: builtins.concatStringsSep \"\\n\" ((h.$3 or {}).$4 or [])"
}
