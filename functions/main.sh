usage() {
cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  -d, --debug             Enable debug mode.
  -f, --force             Force fresh installation.
  -dv, --download-videos  Download video wallpapers (~2.1GiB).
  -dp, --download-photos  Download photo wallpapers (~711MiB).
  -np, --no-prompt        Disable prompt for configuration adjustments.
  -h, --home              Run only "home-manager switch".
  -nn, --no-nix           Disable Nix even if it exists; abort on NixOS.
  -cg, --collect-garbage  Runs command "nix-collect-garbage -d" (only when nix is enabled and installed).
  -nb, --no-backups       Disable symlink backups.
  -u, --update            Update existing installation.
  -r, --remove            Remove existing installation.
  -re, --reboot           Reboot after installation.

Other options:
  -H, --help, -?, --?     Show this help message.

Notes:
  - Flags with no arguments act as toggles.
  - Unknown options will trigger an error and display this usage.
EOF
}

prompt(){
    if [ $PROMPT == true ];then
        read -p "Do you want to proceed with $1? (y/n) " yn
        case $yn in
            [Yy]* ) echo -e "${BLUE}Proceeding..${RESET}";;
            * ) echo -e "${GREEN}Getting out..${RESET}"; exit;;
        esac
        return 0
    else
        echo "Procced with $1 -> skipped.."
    fi
}

file(){ # Individual file downloader.
    curl -L -o $2 https://$1
}

s(){ su - $USER -c "$*"; } # Launch as user.

backup(){
    for target in "$@";do
        if [ -L $target ];then
            echo "Skipping symlink: $target"
        elif [ -f $target ];then
            cp "$target" "${target}.bak.$(date +%Y%m%d%H%M%S)"
            echo "Backed up file: $target"
        elif [ -d $target ];then
            cp -r $target "${target}.bak.$(date +%Y%m%d%H%M%S)"
            echo "Backed up folder: $target"
        else
            echo -e "${RED}Nothing to back up — not found: $target${RESET}"
        fi
    done
}

restore(){
    for target in $@;do
        local latest_backup=$(ls -td "${target}.bak."* 2>/dev/null | head -1)
        if [ -z $latest_backup ];then
            echo -e "${RED}No backup found for $target!${RESET}"
        elif [ -f $latest_backup ];then
            cp $latest_backup $target
            echo -e "${GREEN}Restored file: $target from $latest_backup${RESET}"
        elif [ -d $latest_backup ];then
            cp -r $latest_backup $target
            echo -e "${GREEN}Restored folder: $target from $latest_backup${RESET}"
        else
            echo -e "${RED}Backup exists but is unrecognised type: $latest_backup${RESET}"
        fi
    done
}

env_add(){ # Adds variable to /etc/environment
    if ! grep -q "^$1=" $ENV_FILE; then
        echo "$1" | sudo tee -a "$ENV_FILE" > /dev/null
        echo -e "${GREEN}$1 added to $ENV_FILE.${RESET}"
    else
        echo "$1 already exists in $ENV_FILE, skipping addition."
    fi
}