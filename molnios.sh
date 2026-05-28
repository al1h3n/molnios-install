#!/usr/bin/env bash
# MM    MM              dd           bb                         lll  1  hh      333333
# MMM  MMM   aa aa      dd   eee     bb      yy   yy      aa aa lll 111 hh         3333 nn nnn
# MM MM MM  aa aaa  dddddd ee   e    bbbbbb  yy   yy     aa aaa lll  11 hhhhhh    3333  nnn  nn
# MM    MM aa  aaa dd   dd eeeee     bb   bb  yyyyyy    aa  aaa lll  11 hh   hh     333 nn   nn
# MM    MM  aaa aa  dddddd  eeeee    bbbbbb       yy     aaa aa lll 111 hh   hh 333333  nn   nn
#                                             yyyyy
# Support - al1h3n(tg,ds) | Donate me - paypal.me/al1h3n
# MolniOS Downloader v1 - Pre-installations for dotfiles.
# Part of the MolniOS project.

# ! CHANGE APPROACH TO NIX

# How it works?
# 1. Script checks which OS you have.
# 2. Script applies required flags.
# 3. Makes requied actions (backing directories/files or updates existing git repos if needed)
# ==============================================================================

# To make gruvbox theme work use this command: sudo -E bash molnios.sh
# Custom theme syntax only works in bash.

# Currently script suppports following OS:
# Arch, Artix, Alpine, Debian, nixOS, macOS.

# To do in future: nix for all OS, check symlinking.

case "$0" in
  */*) SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd) ;;
  *)   SCRIPT_DIR=$(pwd) ;;
esac
. "$SCRIPT_DIR/functions/variables.sh"
. "$SCRIPT_DIR/functions/autostart.sh"
. "$SCRIPT_DIR/functions/file.sh"
. "$SCRIPT_DIR/functions/repo.sh"
. "$SCRIPT_DIR/functions/main.sh"
. "$SCRIPT_DIR/functions/molnios-custom.sh"
. "$SCRIPT_DIR/functions/nix.sh"

. "$SCRIPT_DIR/run/gruvbox-theme.sh"

ORIG_ARGS=("$@")
while [[ $# -gt 0 ]];do
  case $1 in
    -d|--debug) DEBUG=true;; # Force fresh install.
    -f|--force) FRESH_INSTALL=true;; # Force fresh install.
    -dv|--download-videos) DOWNLOAD_VIDEO_WALLPAPERS=true;; # Add media-dynamic repo (~2.1GiB!).
    -dp|--download-photos) DOWNLOAD_PHOTO_WALLPAPERS=true;; # Add media-static repo (~711MiB!).
    -np|--no-prompt) PROMPT=false;; # Show prompt to adjust configurations.
    -h|--home) ONLY_HOME=true;; # Run only "home-manager switch".
    -nn|--no-nix) NO_NIX=true;; # Disable nix even if it exists. On nixOS, aborts installation.
    -ni|--nix-install) NIX_INSTALL=true;; # Enable installation of nix (not nixOS).
    -nb|--no-backups) NO_BACKUPS=true;; # Disables symlink backups.
    -u|--update) UPDATE=true;;
    -r|--remove) REMOVE=true;;
    -cg|--collect-garbage) COLLECT_GARBAGE=true;;
    -re|--reboot) REBOOT=true;;
    -H|--help|-?|--?) usage;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
  shift
done

# 1.3. Local paths.
# x_PATH - path for shared files such as configurations, scripts etc.
# x_MEDIA_PATH - path for shared wallpapers (takes a lot of space).

if exists nixos-rebuild;then
    OS="nixos"
    SHARED_PATH=/etc/nixos/shared
    SHARED_NIX_PATH=/etc/nixos/molnixos
    SHARED_MEDIA_PATH=$USER_HOME/.local/share/molnios/molnios-media/wallpapers
    SHARED_REPO_NIX="gitlab.com/al1h3n/molnixos"
elif [ $(uname) = "Darwin" ];then
    OS="mac"
    SHARED_PATH=$USER_HOME/maconlyos/shared
    SHARED_MAC_PATH=$USER_HOME/maconlyos
    SHARED_MEDIA_PATH=$SHARED_PATH/molnios-media
    SHARED_REPO_MAC="gitlab.com/al1h3n/maconlyos"
elif exists pacman || exists apt || exists apk;then
    # if [[ exists pacman && !exists yay ]];then
    #     AUR_INSTALL=true
    # fi
    SHARED_PATH=/usr/local/bin/molnios
    SHARED_MEDIA_PATH=$SHARED_PATH/molnios-media/wallpapers
else
    echo -e "${RED}Error: your OS is unsupported. Try install nix first.${RESET}"
    exit 1
fi

if exists nix;then
    NIX_INSTALLED=true;
    # if [ $OS != "nixos" ];then
    #     nix_install_channel nixos.org/channels/nixpkgs-unstable unstable
    # fi
fi

if ! exists nix;then
    if [ $NIX_INSTALL != "false" ];then
        nix_install
    fi
fi

# Checking for root.
if [ $EUID -ne 0 ];then
    echo -e "${YELLOW}Elevation needed. Restarting with sudo..${RESET}"
    exec sudo bash $0 "${ORIG_ARGS[@]}"
fi

_repo(){
    if [ $FRESH_INSTALL != "true" ];then
        repo "$@"
    else
        repo --force "$@"
    fi
}

# Main functions.
update(){
    _repo $SHARED_REPO $SHARED_PATH
    if [ ! $OS = "mac" ];then
        symlinks
    fi
    if [[ $OS != "nix" && $NO_NIX != true ]];then
        nix flake update
        home-manager switch --impure --flake $SHARED_NIX_PATH#main
    fi
    if [ $OS = "nix" ];then
        _repo $SHARED_REPO_NIX $SHARED_NIX_PATH #! Check if hardware-configuration.nix kills repo function.
        nix-channel --update
        nixos-rebuild switch --impure --upgrade-all --flake $SHARED_NIX_PATH#main
    elif [ $OS = "arch" ];then
        if exists yay;then
            s yay --noconfirm
        elif exists paru;then
            s paru --noconfirm
        fi
        tldr --update
    elif [ $OS = "mac" ];then
        _repo $SHARED_REPO_MAC $SHARED_MAC_PATH
        nix flake update --flake $SHARED_MAC_PATH
        darwin-rebuild switch --impure --flake $SHARED_MAC_PATH#main
        brew upgrade
    else
        exit 1
    fi
    exit 0
}

remove(){
    if [ $OS = "nix" ];then
        prompt "removing files - CAN BREAK YOUR SYSTEM"
        rm -rf $SHARED_PATH
        rm -rf $SHARED_NIX_PATH
    elif [ $OS = "mac" ];then
        prompt "removing MaconlyOS files"
        rm -rf $SHARED_PATH
        rm -rf $SHARED_MAC_PATH
    else
        prompt "removing files"
        dislaunch sweeper
        rm -rf $SHARED_PATH
    fi
    exit 0
}

if $DEBUG;then
    echo MD: Debug mode enabled.
    echo -e "File name - $0. Repositores: shared dotfiles repo - $SHARED_REPO,\nshared wallpaper repo (video) - $SHARED_MEDIA_DYNAMIC_REPO,\nshared static wallpaper repo - $SHARED_MEDIA_STATIC_REPO."
    echo -e "Current OS: $OS"
    echo -e "Testing (you should see colorful text): ${FINISH}this is a green text${RESET}, ${RED}whereas this is a red one.${RESET}."
    echo -e "Current user: $USER, directory - ${CURRENT_DIR}, shared path - $SHARED_PATH."
    if ping -q -c 1 -W 1 8.8.8.8 >/dev/null;then
        echo -e "Internet: ${GREEN}working${RESET}."
    else
        echo -e "Internet: ${RED}not working${RESET}."
    fi
    if exists git;then
        echo -e "Git: ${FINISH}existing.${RESET}"
    else
        echo -e "${RED}Git: NOT EXISTING!${RESET}"
    fi
    echo MD: End of debug.
fi

if $FRESH_INSTALL;then
    if [ $OS = "nix" ];then
        if [ $NO_BACKUPS != true ];then
            backup /etc/nixos
        fi
        rm -f /etc/nixos/*configuration.nix
        nixos-generate-config
    # else
        # rm -rf ./molnios*
    fi
fi

if $UPDATE;then
    update
fi

if $REMOVE;then
    remove
fi

install(){
    git config --global http.followRedirects true
    if [ $OS = "nixos" ];then
        _repo $SHARED_REPO $SHARED_PATH
        mkdir -p $SHARED_MEDIA_PATH
        _repo $SHARED_REPO_NIX $SHARED_NIX_PATH
        media
        symlinks

        mkdir -p $USER_HOME/.local/state/nix/profiles
        mkdir -p /nix/var/nix/profiles/per-user/al1h3n
        chown -R $USER:users $USER_HOME/.local
        chown -R $USER:users /nix/var/nix/profiles/per-user/al1h3n

        mkdir -p /$USER_HOME/.config/dconf
        mkdir -p $USER_HOME/Screenshots
        chown -R $USER:users $USER_HOME
        chmod 700 $USER_HOME

        cp -r /etc/nixos/hardware-configuration.nix $SHARED_NIX_PATH
        git -C $SHARED_NIX_PATH add -f hardware-configuration.nix
        git -C $SHARED_NIX_PATH -c user.email="molnios@local" -c user.name="MolniOS" commit -m "add hardware-configuration.nix"
        git -C $SHARED_NIX_PATH update-index --assume-unchanged hardware-configuration.nix
        git -C $SHARED_NIX_PATH update-index --assume-unchanged configuration.nix

        rm ~/.config/gtk-3.0/settings.ini
        rm ~/.config/gtk-4.0/settings.ini
        rm ~/.config/gtk-3.0/settings.ini.backup
        rm ~/.config/gtk-4.0/settings.ini.backup

        cd $SHARED_PATH&&git add .
        if [ $PROMPT = true ];then
            echo -ne "${YELLOW}Adjust your modules configuration now and then hit enter.${RESET} "&&read
        fi

        nixos-rebuild switch --impure --upgrade-all --flake $SHARED_NIX_PATH#main
        # ! Dirty git tree - isn't a problem. It happens if you don't commit changes.

        BREEZE_COLORS=$(nix eval --raw nixpkgs#kdePackages.breeze)/share/color-schemes/BreezeDark.colors
        mkdir -p ~/.config/qt6ct ~/.config/qt5ct
        rm ~/.config/qt6ct/qt6ct.conf
        rm ~/.config/qt5ct/qt5ct.conf

        cat > ~/.config/qt6ct/qt6ct.conf << EOF
[Appearance]
icon_theme=MacTahoe
style=Breeze-Dark
color_scheme_path=$BREEZE_COLORS
custom_palette=true
EOF

        cat > ~/.config/qt5ct/qt5ct.conf << EOF
[Appearance]
icon_theme=MacTahoe
style=Breeze-Dark
color_scheme_path=$BREEZE_COLORS
custom_palette=true
EOF
    nix-store --optimise
    return 0
    elif [ $OS = "arch" ];then
        rm -rf /tmp/paru*
        backup $ENV_FILE
        packages_p
    elif [ $OS = "debian" ];then
        packages_apt
    elif [ $OS = "alpine" ];then
        packages_apk
    fi
    if [ $OS != "mac" ];then
        _repo $SHARED_REPO $SHARED_PATH
        media
        symlinks
        dots_backup
        # icons_install
        font_install
        cursor

        env_add "SHARED_PATH=$SHARED_PATH"
        env_add "SHARED_MEDIA_PATH=$SHARED_MEDIA_PATH"
        env_add "L_PATH=~/.local/share/molnios"
        file "raw.githubusercontent.com/al1h3n/sweeper/refs/heads/main/sweeper.sh" "/usr/local/bin/sweeper/sweeper.sh"
        file "raw.githubusercontent.com/al1h3n/sweeper/refs/heads/main/sweeper.service" "/etc/systemd/system/sweeper.service"
        autolaunch sweeper&&rm /etc/systemd/system/sweeper.service&&cd $CURRENT_DIR&&echo -e "${GREEN}Sweeper was added to autolaunch!${RESET}"
        timedatectl set-local-rtc 1
    else
        packages_b
        _repo $SHARED_REPO $SHARED_PATH
        media
        _repo $SHARED_REPO_MAC $SHARED_MAC_PATH

        read -p "Adjust your configuration now and then hit enter."
        darwin-rebuild switch --impure --flake $SHARED_MAC_PATH#main
    fi
}

# 3. Actual start.
echo -e "\033[38;5;213mMolniOS Downloader by\033[0m \033[38;5;171mal1h3n${RESET}"
echo You must have git pre-installed before launching the script.
echo -e "${GREEN}=========================================="
echo -e "    STARTING SYSTEM PRE-INSTALLATION..      "
echo -e "==========================================${RESET}"
echo -e "Pay attention that every OS needs to be configured ${RED}after${RESET} the installation (with drivers)!"

# 3.1. Default action.
install

if [[ $NO_NIX != true && $NIX_INSTALLED != false && $COLLECT_GARBAGE != false ]];then
    nix-collect-garbage -d
fi

echo -e "${FINISH}==========================================${RESET}"
echo -e "${FINISH}      PRE-INSTALLATION COMPLETE!           ${RESET}"
echo -e "${FINISH}==========================================${RESET}"
echo -e "               ...now configure what you need..."

if [ $REBOOT != false ];then
    reboot
fi

exit 0