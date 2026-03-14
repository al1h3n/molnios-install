# MM    MM              dd           bb                         lll  1  hh      333333
# MMM  MMM   aa aa      dd   eee     bb      yy   yy      aa aa lll 111 hh         3333 nn nnn
# MM MM MM  aa aaa  dddddd ee   e    bbbbbb  yy   yy     aa aaa lll  11 hhhhhh    3333  nnn  nn
# MM    MM aa  aaa dd   dd eeeee     bb   bb  yyyyyy    aa  aaa lll  11 hh   hh     333 nn   nn
# MM    MM  aaa aa  dddddd  eeeee    bbbbbb       yy     aaa aa lll 111 hh   hh 333333  nn   nn
#                                             yyyyy
# Support - al1h3n(tg,ds) | Donate me - paypal.me/al1h3n
# MolniOS Downloader v1 - Pre-installations for dotfiles.
# MolniuxOS (Arch), MolnixOS (nixOS), ArmiuxOS (Artix) included.
# Part of the MolniOS project.

# How it works?
# 1. Script checks which OS you have.
# 2. Script applies required flags.
# 3. Makes requied actions (backing directories/files or updates existing git repos if needed)
# ==============================================================================

# 1. Variables definition.

# 1.1. Colors.
GREEN="\e[32m"
FINISH="\033[38;5;46m" # Special green finish value.
YELLOW="\e[33m"
RED="\e[31m"
BLUE="\x1B[36m"
RESET="\e[0m"

# 1.2. Actions. By default post-install with auto OS definition.
DEBUG=false # More outputs. [d]
FRESH_INSTALL=false # Delete and download all repos again [f].
PRE_INSTALL=false # Pre-install actions. [p]
UPDATE=false # Update your system and existing configurations. [u]
REMOVE=false # Delete all existing MolniOS files. [r]

OS="not supported"
SHARED_PATH="not existing"

# 1.3. Local paths.
# x_PATH - path for shared files such as configurations, scripts etc.
# x_MEDIA_PATH - path for shared wallpapers (takes a lot of space).

exists(){
	command -v $1&>/dev/null
}

CURRENT_DIR=$(pwd)
USER="${SUDO_USER:-$USER}"
USER_HOME=$(getent passwd "$USER" | cut -d: -f6)
HOME_CONFIG=$USER_HOME/.config

ENV_FILE=/etc/environment

if exists nix-shell;then
    OS="nix"
    SHARED_PATH=/etc/nixos/shared
    SHARED_NIX_PATH=/etc/nixos/molnixos
    SHARED_MEDIA_PATH=$USER_HOME/.local/share/molnios/molnios-media
    SHARED_REPO_NIX="gitlab.com/al1h3n/molnixos"
elif exists pacman;then
    OS="arch"
    SHARED_PATH=/usr/local/bin/molnios
    SHARED_MEDIA_PATH=$SHARED_PATH/molnios/molnios-media
elif exists apk;then
    OS="artix"
    SHARED_PATH=/usr/local/bin/molnios
    SHARED_MEDIA_PATH=$SHARED_PATH/molnios/molnios-media
else
    echo -e "${RED}Error: your OS is unsupported.${RESET}"
    exit 1
fi

# 1.4. Web paths.
SHARED_REPO="gitlab.com/al1h3n/molnios-shared"
SHARED_MEDIA_STATIC_REPO="gitlab.com/al1h3n/molnios-media-static"
SHARED_MEDIA_DYNAMIC_REPO="codeberg.org/al1h3n/molnios-media-dynamic"
SHARED_CONFIG=$SHARED_PATH/config

# 2. Preparations and function handling.

# 2.1. Checking for root.
if [ $EUID -ne 0 ];then
    echo -e "${YELLOW}Elevation needed. Restarting with sudo..${RESET}"
    exec sudo sh $0 $@
fi

# 2.2. Arguments handling.
while getopts "dfpur" opt; do
    case $opt in
        d) DEBUG=true ;;
        f) FRESH_INSTALL=true ;;
        p) PRE_INSTALL=true ;;
        u) UPDATE=true ;;
        r) REMOVE=true ;;
        \?) echo -e "${RED}Invalid option: -$OPTARG${RESET}" >&2; usage ;;
    esac
done

# 2.3. Input functions.
prompt(){
    read -p "Do you want to proceed with $1? (y/n) " yn
    case $yn in
        [Yy]* ) echo -e "${BLUE}Proceeding..${RESET}";;
        * ) echo -e "${GREEN}Getting out..${RESET}"; exit;;
    esac
    return 0
}

# 2.4. Web functions.
repo(){ # $1 - link, $2 - path.
    if [ -d "$2/.git" ];then
        # FIX 1: Use rebase and autostash to handle local commits and unstaged files
        git -C "$2" pull --rebase --autostash
    elif [ -d "$2" ];then
        echo -e "${YELLOW}$2 exists but is not a git repo, removing and recloning..${RESET}"
        rm -rf "$2"
        git clone "https://$1.git" "$2"
    elif [ "$1" = "s" ];then # Individual folder downloader.
        # FIX 2: Use shallow sparse-checkout instead of unsupported git archive
        # $1 - attribute, $2 - link, $3 - path, $4 - folder from repo.
        local tmpdir=$(mktemp -d)
        
        # Clone efficiently without downloading file contents yet
        git clone --depth=1 --filter=blob:none --sparse "https://$2.git" "$tmpdir"
        
        # Tell Git to only fetch the specific folder
        git -C "$tmpdir" sparse-checkout set "$4"
        
        # Move the folder contents to the destination and clean up
        mkdir -p "$3"
        cp -a "$tmpdir/$4/." "$3/"
        rm -rf "$tmpdir"
    else
        git clone "https://$1.git" "$2"
    fi
}

file(){ # Individual file downloader.
    curl -L -o $2 "https://$1"
}

# 2.7. Imperative functions.
autolaunch(){
    systemctl daemon-reload
    systemctl enable --now $1.service
    systemctl start $1
}

dislaunch(){
    systemctl stop $1
    systemctl disable --now $1
}

backup(){
    for target in $@;do
        if [ -L $target ];then
            echo "Skipping symlink: $target"
        elif [ -f $target ];then
            cp $target "${target}.bak.$(date +%Y%m%d%H%M%S)"
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

p(){ # Arch + Artix universal downloader.
    pacman -Sy --needed --noconfirm $1
}

packages_p(){
    prompt "installing packages via pacman"

    sed -i '/^#\[multilib\]/,/^#Include = \/etc\/pacman.d\/mirrorlist/{s/^#//}' /etc/pacman.conf
    echo Main packages + fonts + important programs.
    p base-devel openssh git fastfetch ttf-jetbrains-mono-nerd mpv btop font-manager neovim
    echo GUI applications.
    p firefox qbittorrent obs-studio thunar gvfs obsidian cpu-x songrec
    echo Developing.
    p python-pipx breeze virt-manager
    echo RGB + accessories.
    p openrgb piper
    echo Configurations.
    p zsh zsh-autosuggestions zsh-syntax-highlighting eza yazi fzf

    echo Backend + hyprland utilities.
    p brightnessctl blueman wtype
    echo Hyprland.
    p hyprland hyprlock rofi rofi-emoji rofi-calc swww
    echo Screenshots.
    p wl-clip-persist grim
    echo Clipboard.
    p cliphist
    echo Permissions.
    p hyprpolkitagent
    echo Tray.
    p waybar swaync # quickshell, dunst

    echo Installing paru.
    local type="paru-bin"
    repo aur.archlinux.org/$type&&cd $type&&makepkg -si&&cd ..&&rm -rf $type&&cd $CURRENT_DIR

    echo Use hyprland uwsm if you have systemd.
    paru -Sy --needed --noconfirm temurin-bin-8 temurin-bin-21 temurin-bin-25
    paru -Sy --needed --noconfirm yt-x 64gram-desktop-bin vesktop notion-app-electron waypaper mpvpaper-git mpvpaper-stop-git apple-fonts zsh-theme-powerlevel10k-git zsh-autocomplete-git hyprshell vscodium-bin
    # openoffice-bin

    echo JRE 8 for 1.16.5 and older, 21 for 1.17-1.21.11, 25 for 26.x+. Install JRE instead of JDK. Adoptium is better in any case.
    pacman -Sy steam prismlauncher # jre21-openjdk
    xdg-settings set default-web-browser firefox.desktop

    # MPV theme.
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/tomasklaen/uosc/HEAD/installers/unix.sh)"

    # ZSH shift select
    repo github.com/jirutka/zsh-shift-select $USER_HOME/.local/share/zsh/plugins/zsh-shift-select
    echo -e "${GREEN}Packages were installed.${RESET}"
}

cursor(){
    local cursor_name="clay_white"
    mkdir -p $USER_HOME/.local/share/icons/molnios/$cursor_name
    cp -r $SHARED_PATH/cursors/* $USER_HOME/.local/share/icons/molnios
    echo -e "${GREEN}Cursor was installed.${RESET}"
}

cursor_remove(){
    rm -rf $USER_HOME/.local/share/icons/molnios
    rm -rf /usr/share/icons/molnios
    echo -e "${GREEN}Cursor was removed.${RESET}"
}

icons_install(){
    prompt "installing icon themes"
    
    # We10X
    local tmpdir=$(mktemp -d)
    git clone --depth=1 https://github.com/yeyushengfan258/We10X-icon-theme.git $tmpdir/we10x
    sh $tmpdir/we10x/install.sh -d /usr/share/icons -t black
    
    # MacTahoe
    git clone --depth=1 https://github.com/vinceliuice/MacTahoe-icon-theme.git $tmpdir/mactahoe
    sh $tmpdir/mactahoe/install.sh -d /usr/share/icons -t default
    
    rm -rf $tmpdir

    # Set default icon theme for Qt
    mkdir -p /etc/xdg/qt5ct /etc/xdg/qt6ct
    for f in /etc/xdg/qt5ct/qt5ct.conf /etc/xdg/qt6ct/qt6ct.conf;do
        cat > $f <<EOF
[Appearance]
icon_theme=MacTahoe
style=Breeze
color_scheme_path=/usr/share/color-schemes/BreezeDark.colors
EOF
    done
    echo -e "${GREEN}Icons were installed.${RESET}"
}

icons_uninstall(){
    rm -rf /usr/share/icons/We10X-black-dark
    rm -rf /usr/share/icons/MacTahoe
    rm -rf /etc/xdg/qt5ct/qt5ct.conf
    rm -rf /etc/xdg/qt6ct/qt6ct.conf
    echo -e "${GREEN}Icons were removed.${RESET}"
}

symlinks(){
    mkdir -p /usr/local/bin
    cp $SHARED_PATH/scripts/path.sh /usr/local/bin/path.sh
    cp $(readlink -f $0) /usr/local/bin/molnios.sh
    chmod a+x $SHARED_PATH/scripts/path.sh
    chmod a+x /usr/local/bin/molnios.sh

    mkdir -p $USER_HOME/.local/share/molnios
    ln -sfn $SHARED_MEDIA_PATH $USER_HOME/.local/share/molnios/molnios-media/wallpapers
    ln -sfn $SHARED_PATH/scripts $USER_HOME/.local/share/molnios/scripts
    ln -sfn $SHARED_PATH/config $USER_HOME/.local/share/molnios/config
    ln -sfn $SHARED_PATH/images $USER_HOME/.local/share/molnios/images
    ln -sfn $SHARED_PATH/sfx $USER_HOME/.local/share/molnios/sfx
    chown -hR $USER: $USER_HOME/.local/share/molnios

    echo -e "${GREEN}Shared repo, path.sh and molnios.sh were symlinked to /usr/local/bin${RESET}"
}

symlinks_remove(){
    rm -rf $USER_HOME/.local/share/molnios/molnios-media
    rm -rf $USER_HOME/.local/share/molnios/scripts
    rm -rf $USER_HOME/.local/share/molnios/config
    rm -rf $USER_HOME/.local/share/molnios/images
    rm -rf $USER_HOME/.local/share/molnios/sfx
    rm -rf /usr/local/bin/path.sh
    rm -rf /usr/local/bin/molnios.sh
}

dots_restore(){
    restore /etc/hosts
    restore $HOME_CONFIG/fastfetch/config.jsonc
    restore $HOME_CONFIG/feh/buttons
    restore $HOME_CONFIG/hypr/hyprland.conf
    restore $HOME_CONFIG/kitty/kitty.conf
    restore $HOME_CONFIG/kitty/kittystyle
    restore $HOME_CONFIG/waypaper/config.ini
    restore /etc/ly/config.ini
    restore $HOME_CONFIG/qBittorrent/qBittorrent.conf
    symlinks_remove
}

dots_clean(){
    rm -f /etc/hosts
    restore /etc/hosts
    rm -f $HOME_CONFIG/fastfetch/config.jsonc
    restore $HOME_CONFIG/fastfetch/config.jsonc
    rm -f $HOME_CONFIG/feh/buttons
    restore $HOME_CONFIG/feh/buttons
    rm -f $HOME_CONFIG/hypr/hyprland.conf
    restore $HOME_CONFIG/hypr/hyprland.conf
    rm -f $HOME_CONFIG/kitty/kitty.conf
    restore $HOME_CONFIG/kitty/kitty.conf
    rm -f $HOME_CONFIG/kitty/kittystyle
    restore $HOME_CONFIG/kitty/kittystyle
    rm -f $HOME_CONFIG/waybar/config
    restore $HOME_CONFIG/waybar/config
    rm -f $HOME_CONFIG/waypaper/config.ini
    restore $HOME_CONFIG/waypaper/config.ini
    rm -f /etc/ly/config.ini
    restore /etc/ly/config.ini
    rm -f $HOME_CONFIG/qBittorrent/qBittorrent.conf
    restore $HOME_CONFIG/qBittorrent/qBittorrent.conf
    rm -rf $USER_HOME/.local/share/molnios
    echo -e "${GREEN}Existing symlinks were cleaned.${RESET}"
}

dots_backup(){
    dots_clean
    
    backup /etc/hosts
    ln -sfn $SHARED_CONFIG/config/hosts /etc/hosts

    backup $HOME_CONFIG/fastfetch/config.jsonc
    ln -sfn $SHARED_CONFIG/fastfetch.jsonc $HOME_CONFIG/fastfetch/config.jsonc

    backup $HOME_CONFIG/feh/buttons
    ln -sfn $SHARED_CONFIG/feh $HOME_CONFIG/feh/buttons

    backup $HOME_CONFIG/hypr/hyprland.conf
    ln -sfn $SHARED_CONFIG/hyprconfig $HOME_CONFIG/hypr/hyprland.conf
    ln -sfn $SHARED_CONFIG/custom $HOME_CONFIG/hypr/custom

    backup $HOME_CONFIG/kitty/kitty.conf
    ln -sfn $SHARED_CONFIG/kitty $HOME_CONFIG/kitty/kitty.conf
    backup $HOME_CONFIG/kitty/kittystyle
    ln -sfn $SHARED_CONFIG/kittystyle $HOME_CONFIG/kitty/kittystyle

    backup /etc/ly/config.ini
    ln -sfn $SHARED_CONFIG/ly /etc/ly/config.ini

    mkdir -p $HOME_CONFIG/waypaper
    backup $HOME_CONFIG/waypaper/config.ini
    cp $SHARED_CONFIG/waypaper $HOME_CONFIG/waypaper/config.ini
    sed -i "s|$USER_HOME/.local/share/molnios/molnios-media/wallpapers|$SHARED_MEDIA_PATH/wallpapers|g" \
        $HOME_CONFIG/waypaper/config.ini

    backup $HOME_CONFIG/qBittorrent/qBittorrent.conf
    ln -sfn $SHARED_CONFIG/qbittorrent $HOME_CONFIG/qBittorrent/qBittorrent.conf
    mkdir -p $HOME_CONFIG/qBittorrent/themes
    for theme in $SHARED_CONFIG/qbit-themes/*.qbtheme; do
        ln -sfn $theme $HOME_CONFIG/qBittorrent/themes/$(basename $theme)
    done

    local kitty_conf=$HOME_CONFIG/kitty/kitty.conf
    local line='include ${L_PATH}/config/kitty'
    if ! grep -qF "$line" $kitty_conf; then
        echo "include ${L_PATH}/config/kitty" >> $kitty_conf
    else
        echo "Kitty include already exists, skipping."
    fi  
}

# 2.6. Main functions.
update(){
    repo $SHARED_REPO $SHARED_PATH
    symlinks
    if [ $OS = "nix" ];then
        repo $SHARED_REPO_NIX $SHARED_NIX_PATH #! Check if hardware-configuration.nix kills repo function.
        nix-channel --update
        nixos-rebuild switch --impure --upgrade
    elif [ $OS = "arch" ] || [ $OS = "artix" ];then
        paru --noconfirm
    else
        exit 1
    fi
    exit 0
}

remove(){
    rm -rf /.config/waybar/*
    if [ $OS = "nix" ];then
        prompt "removing files - CAN BREAK YOUR SYSTEM"
        rm -rf $SHARED_PATH/*
        rm -rf $SHARED_NIX_PATH/*
    elif [ $OS = "arch" ] || [ $OS = "artix" ];then
        prompt "removing files"
        dislaunch sweeper
        rm -rf $SHARED_PATH
    else
        exit 1
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
        echo -e Fx"Internet: ${RED}not working${RESET}."
    fi
    if exists git;then
        echo -e "Git: ${FINISH}existing.${RESET}"
    else
        echo -e "${RED}Git: NOT EXISTING!${RESET}"
    fi
    echo MD: End of debug.
fi

if $FRESH_INSTALL;then
    if [ $OS="nix" ];then
        rm -rf /etc/nixos/*
        nixos-generate-config
    fi
fi

if $PRE_INSTALL;then
    rm -rf /.config/waybar/*
    if [ $OS="nix" ];then
        nixos-generate-config -root /mnt
        nixos-install
    fi
    exit 0
fi

if $UPDATE;then
    update
fi

if $REMOVE;then
    remove
fi

install(){
    symlinks_remove
    if [ $OS = "nix" ];then
        repo $SHARED_REPO $SHARED_PATH
        mkdir -p $SHARED_MEDIA_PATH/wallpapers
        repo $SHARED_MEDIA_STATIC_REPO $SHARED_MEDIA_PATH
        #/molnios-media-static&&mv $SHARED_MEDIA_PATH/molnios-media-static/* $SHARED_MEDIA_PATH/wallpapers&&rm -rf $SHARED_MEDIA_PATH/molnios-media-static
        #repo $SHARED_MEDIA_DYNAMIC_REPO $SHARED_MEDIA_PATH/molnios-media-dynamic&&mv $SHARED_MEDIA_PATH/molnios-media-dynamic/* $SHARED_MEDIA_PATH/wallpapers&&rm -rf $SHARED_MEDIA_PATH/molnios-media-dynamic
        
        repo $SHARED_REPO_NIX $SHARED_NIX_PATH
        symlinks

        repo github.com/sejjy/mechabar $SHARED_CONFIG/mechabar
        mkdir -p $USER_HOME/.config/waybar
        cp -r $SHARED_CONFIG/mechabar/* $USER_HOME/.config/waybar

        cp -r /etc/nixos/hardware-configuration.nix $SHARED_NIX_PATH
        git -C $SHARED_NIX_PATH add -f hardware-configuration.nix
        git -C $SHARED_NIX_PATH -c user.email="molnios@local" -c user.name="MolniOS" commit -m "add hardware-configuration.nix"
        git -C $SHARED_NIX_PATH update-index --assume-unchanged hardware-configuration.nix
        git -C $SHARED_NIX_PATH update-index --assume-unchanged configuration.nix

        cd $SHARED_PATH&&git add .
        read -p "Adjust your modules configuration now and then hit enter."
        nixos-rebuild switch --impure --upgrade --flake $SHARED_NIX_PATH#main
        # ! Dirty git tree - isn't a problem. It happens when you didn't commit changes.

        # nix --extra-experimental-features 'nix-command flakes' flake update --flake $SHARED_NIX_PATH
        # git -C $SHARED_NIX_PATH add flake.lock
        # git -C $SHARED_NIX_PATH -c user.email="molnios@local" -c user.name="MolniOS" commit -m "update flake.lock"
        # git -C $SHARED_NIX_PATH update-index --assume-unchanged flake.lock
    elif [ $OS = "arch" ] || [ $OS = "artix" ];then
        backup $ENV_FILE
        packages_p
        repo $SHARED_REPO $SHARED_PATH
        repo $SHARED_MEDIA_STATIC_REPO $SHARED_MEDIA_PATH
        #/molnios-media-static&&mv $SHARED_MEDIA_PATH/molnios-media-static/* $SHARED_MEDIA_PATH/wallpapers&&rm -rf $SHARED_MEDIA_PATH/molnios-media-static
        #repo $SHARED_MEDIA_DYNAMIC_REPO $SHARED_MEDIA_PATH/molnios-media-dynamic&&mv $SHARED_MEDIA_PATH/molnios-media-dynamic/* $SHARED_MEDIA_PATH/wallpapers&&rm -rf $SHARED_MEDIA_PATH/molnios-media-dynamic
        symlinks
        dots_backup
        icons_install
        cursor
        
        repo github.com/sejjy/mechabar $SHARED_CONFIG/mechabar
        mkdir -p $USER_HOME/.config/waybar
        cp -r $SHARED_CONFIG/mechabar/* $USER_HOME/.config/waybar

        env_add "SHARED_PATH=$SHARED_PATH"
        env_add "SHARED_MEDIA_PATH=$SHARED_MEDIA_PATH/wallpapers"
        env_add "L_PATH=~/.local/share/molnios"
        file "raw.githubusercontent.com/Alihan1ai9595/sweeper/unobfusticated/sweeper.sh" "/usr/local/bin/sweeper/sweeper.sh"
        file "raw.githubusercontent.com/Alihan1ai9595/sweeper/main/sweeper.service" "/etc/systemd/system/sweeper.service"
        autolaunch sweeper&&rm /etc/systemd/system/sweeper.service&&cd $CURRENT_DIR&&echo -e "${GREEN}Sweeper was added to autolaunch!${RESET}"
        timedatectl set-local-rtc 1
    else
        exit 1
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

echo -e "${FINISH}==========================================${RESET}"
echo -e "${FINISH}      PRE-INSTALLATION COMPLETE!           ${RESET}"
echo -e "${FINISH}==========================================${RESET}"
echo -e "               ...now configure what you need..."