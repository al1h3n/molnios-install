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

# Currently script suppports following OS:
# Arch, Artix, Alpine, Debian, nixOS, macOS.

# To do in future: nix for all OS, check symlinking.

# 1. Variables definition.

# 1.1. Colors (gruvbox theme).
# bright_green  #b8bb26
GREEN="\033[38;2;184;187;38m"
# neutral_green #98971a
FINISH="\033[38;2;152;151;26m"
# bright_yellow #fabd2f
YELLOW="\033[38;2;250;189;47m"
# bright_red #fb4934
RED="\033[38;2;251;73;52m"
# bright_aqua #8ec07c
BLUE="\033[38;2;142;192;124m"
# light1 #ebdbb2
WHITE="\033[38;2;235;219;178m"
# dark0 #282828
BG="\033[48;2;40;40;40m"
RESET="\033[0m"

# 1.2. Actions. By default post-install with auto OS definition.

# Nix related.
NIX_INSTALLED=false # Detection of nix.
NO_NIX=false # Script disable of nix.
ONLY_HOME=false
COLLECT_GARBAGE=false

UPDATE=false # Update your system and existing configurations. [u]
REMOVE=false # Delete all existing MolniOS files.

DEBUG=false
FRESH_INSTALL=false
DOWNLOAD_VIDEO_WALLPAPERS=false
DOWNLOAD_PHOTO_WALLPAPERS=false
PROMPT=true
NO_BACKUPS=false

OS="not supported"
SHARED_PATH="not existing"

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

Other options:
  -H, --help, -?, --?     Show this help message.

Notes:
  - Flags with no arguments act as toggles.
  - Unknown options will trigger an error and display this usage.
EOF
}

while [[ $# -gt 0 ]];do
  case $1 in
    -d|--debug) DEBUG=true;; # Force fresh install.
    -f|--force) FRESH_INSTALL=true;; # Force fresh install.
    -dv|--download-videos) DOWNLOAD_VIDEO_WALLPAPERS=true;; # Add media-dynamic repo (~2.1GiB!).
    -dp|--download-photos) DOWNLOAD_PHOTO_WALLPAPERS=true;; # Add media-static repo (~711MiB!).
    -np|--no-prompt) PROMPT=false;; # Show prompt to adjust configurations.
    -h|--home) ONLY_HOME=true;; # Run only "home-manager switch".
    -nn|--no-nix) NO_NIX=true;; # Disable nix even if it exists. On nixOS, aborts installation.
    -nb|--no-backups) NO_BACKUPS=true;; # Disables symlink backups.
    -u|--update) UPDATE=true;;
    -r|--remove) REMOVE=true;;
    -cg|--collect-garbage) COLLECT_GARBAGE=true;;
    -H|--help|-?|--?) usage;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
  shift
done

# 1.3. Local paths.
# x_PATH - path for shared files such as configurations, scripts etc.
# x_MEDIA_PATH - path for shared wallpapers (takes a lot of space).

exists(){ command -v $1&>/dev/null; }

CURRENT_DIR=$(pwd)
USER="${SUDO_USER:-$USER}"

if [ $(uname) = "Darwin" ];then
    USER_HOME=$(dscl . -read /Users/$USER NFSHomeDirectory | awk '{print $2}')
else
    USER_HOME=$(getent passwd $USER | cut -d: -f6)
fi

HOME_CONFIG=$USER_HOME/.config

ENV_FILE=/etc/environment

if exists nixos-rebuild;then
    OS="nix"
    SHARED_PATH=/etc/nixos/shared
    SHARED_NIX_PATH=/etc/nixos/molnixos
    SHARED_MEDIA_PATH=$USER_HOME/.local/share/molnios/molnios-media/wallpapers
    SHARED_REPO_NIX="gitlab.com/al1h3n/molnixos"
elif exists pacman || exists apt || exists apk;then
    if exists pacman;then
        OS="arch"
    elif exists apt;then
        OS="debian"
    elif exists apk;then
        OS="alpine"
    fi
    SHARED_PATH=/usr/local/bin/molnios
    SHARED_MEDIA_PATH=$SHARED_PATH/molnios-media/wallpapers
elif [ $(uname) = "Darwin" ];then
    OS="mac"
    SHARED_PATH=$USER_HOME/maconlyos/shared
    SHARED_MAC_PATH=$USER_HOME/maconlyos
    SHARED_MEDIA_PATH=$SHARED_PATH/molnios-media
    SHARED_REPO_MAC="gitlab.com/al1h3n/maconlyos"
else
    echo -e "${RED}Error: your OS is unsupported.${RESET}"
    exit 1
fi

if exists nix;then
    NIX_INSTALLED=true;
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
    exec sudo bash $0 $@
fi

# 2.2. Input functions.
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

# 2.3. Web functions.
repo(){ # $1 - link, $2 - path.
    if [ -d "$2/.git" ];then
        git -C "$2" fetch --quiet
        LOCAL=$(git -C "$2" rev-parse HEAD)
        REMOTE=$(git -C "$2" rev-parse "@{u}" 2>/dev/null)
        if [ -z "$REMOTE" ]; then
            echo -e "${YELLOW}$2: no upstream tracked, pulling anyway..${RESET}"
            git -C "$2" pull --rebase --autostash
        elif [ "$LOCAL" = "$REMOTE" ]; then
            echo -e "${GREEN}$2: already up to date, skipping.${RESET}"
        else
            echo -e "${BLUE}$2: changes found, updating..${RESET}"
            git -C "$2" pull --rebase --autostash
        fi
    elif [ -d "$2" ];then
        echo -e "${YELLOW}$2 exists but is not a git repo, removing and recloning..${RESET}"
        rm -rf "$2"
        git clone "https://$1.git" "$2"
    elif [ "$1" = "s" ];then
        local tmpdir=$(mktemp -d)
        git clone --depth=1 --filter=blob:none --sparse "https://$2.git" "$tmpdir"
        git -C "$tmpdir" sparse-checkout set "$4"
        mkdir -p "$3"
        cp -a "$tmpdir/$4/." "$3/"
        rm -rf "$tmpdir"
    else
        git clone "https://$1.git" "$2"
    fi
}

media(){
    if $DOWNLOAD_PHOTO_WALLPAPERS;then
        repo $SHARED_MEDIA_STATIC_REPO $SHARED_MEDIA_PATH
    fi
    if $DOWNLOAD_VIDEO_WALLPAPERS;then
        repo $SHARED_MEDIA_DYNAMIC_REPO $SHARED_MEDIA_PATH
    fi
}

file(){ # Individual file downloader.
    curl -L -o $2 "https://$1"
}

# 2.7. Imperative functions.

s(){ su - $USER -c "$*"; } # Launch as user.

autolaunch(){
    systemctl daemon-reload
    systemctl enable --now $1.service
    systemctl start $1
}

dislaunch(){
    systemctl stop $1
    systemctl disable --now $1
}

# For Alpine specifically (enabling SSH)
autolaunch_openrc(){
    rc-update add $1 default
    rc-service $1 start
}

dislaunch_openrc(){
    rc-service $1 stop
    rc-update del $1 default
}

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

p(){ # pacman downloader.
    pacman -Sy --needed --noconfirm --overwrite='/usr/lib/libgcc*' --overwrite='/usr/lib/libstdc*' --overwrite='/usr/share/locale/*/libstdc*' --overwrite='/usr/share/licenses/gcc-libs/*' "$@"
}

pa(){
    # paru has some errors - 29.03.2026
    if exists yay;then
        s yay -Sy --needed --noconfirm "$@"
    elif exists paru;then
        s paru -Sy --needed --noconfirm "$@"
    fi
}

ap(){
    apk add --no-cache $1
}

de(){
    apt install -y $1
}

nix_install(){
    if [[ $OS != "nix" && $NO_NIX != true ]];then
        sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install) --daemon
    else
        echo -e "nix wasn't installed: you either have nixOS or disabled nix in arguments."
    fi
}

packages_p(){
    prompt "installing packages via pacman (YOU MUST INSTALL YAY/PARU TOO)"
    pacman -Syu --noconfirm

    sed -i '/^#\[multilib\]/,/^#Include = \/etc\/pacman.d\/mirrorlist/{s/^#//}' /etc/pacman.conf
    echo Main packages + fonts + important programs.
    p base-devel openssh git fastfetch countryfetch ttf-jetbrains-mono-nerd mpv btop font-manager neovim
    echo GUI applications.
    p firefox obs-studio thunar gvfs ffmpegthumbnailer obsidian cpu-x songrec anki
    echo Developing.
    p python-pipx breeze virt-manager
    echo RGB + accessories.
    p openrgb piper gamemode
    echo Configurations.
    p zsh zsh-autosuggestions zsh-syntax-highlighting eza yazi fzf zoxide tealdeer zenity bat
    chsh -s $(which zsh) $USER
    echo OCR
    p tesseract tesseract-data-eng tesseract-data-rus tesseract-data-chi_sim slurp wl-clipboard
    echo Backend + hyprland utilities.
    p brightnessctl blueman wtype
    echo Hyprland.
    p hyprland hyprlock rofi rofi-emoji rofi-calc swww cava
    echo Screenshots.
    p wl-clip-persist grim slurp
    echo Clipboard.
    p cliphist
    echo Permissions.
    p hyprpolkitagent # polkit-gnome
    echo Tray.
    p waybar swaync # quickshell, dunst
    echo Man.
    p tldr
    tldr --update

    # local type="paru-bin"
    # p pacman rust
    # repo aur.archlinux.org/$type /tmp/$type
    # chown -R $USER: /tmp/$type
    # su - $USER -c "cd /tmp/$type && makepkg -s --needed --noconfirm"
    # pacman -U --noconfirm /tmp/$type/$type-*.pkg.tar.zst
    # rm -rf /tmp/$type
    # cd $CURRENT_DIR

    echo -e "${RED}Use hyprland uwsm if you have systemd.${RESET}"

    echo '''To install AUR manager type this (change yay to paru if you want):
    sudo pacman -S --needed git base-devel
    git clone https://aur.archlinux.org/yay-bin.git
    cd yay
    makepkg -si
    '''

    echo "Run these commands and then hit enter:"
    echo '''[yay/paru] -Sy --needed temurin-bin-21 temurin-bin-25
    yt-x 64gram-desktop-bin vesktop notion-app-electron waypaper
    mpvpaper-git mpvpaper-stop-git apple-fonts
    zsh-theme-powerlevel10k-git zsh-autocomplete-git
    hyprshell vscodium-bin pay-respects-bin spicetify-cli spicetify-marketplace-bin
    zinit qbittorrent-enhanced we10x-icon-theme-git mactahoe-icon-theme-git
    '''
    echo "spicetify&&spicetify config custom_apps marketplace&&spicetify backup apply"
    read
    # openoffice-bin

    echo "JRE 8 for 1.16.5 and older, 21 for 1.17-1.21.11, 25 for 26.x+. Install JRE instead of JDK (wastes less space). Adoptium is better in any case."
    echo "JRE 8 recommended, cause 21 and 25 is already installed."
    pacman -Sy steam prismlauncher # jre8-openjdk
    xdg-settings set default-web-browser firefox.desktop

    # MPV theme.
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/tomasklaen/uosc/HEAD/installers/unix.sh)"

    # ZSH shift select
    s "git clone https://github.com/jirutka/zsh-shift-select.git $USER_HOME/.local/share/zsh/plugins/zsh-shift-select"
    echo -e "${GREEN}Packages were installed.${RESET}"
}

packages_apt(){
    prompt "installing packages via apt"

    apt update && apt upgrade -y

    echo Main packages + important programs.
    de build-essential openssh-server git curl wget fastfetch \
        fonts-jetbrains-mono mpv btop neovim

    echo GUI applications.
    de firefox-esr thunar gvfs ffmpegthumbnailer

    echo Configurations.
    de zsh zsh-autosuggestions zsh-syntax-highlighting fzf eza zoxide yazi

    echo Backend utilities.
    de brightnessctl blueman wtype dbus-x11

    echo Wayland + compositor.
    de hyprland xwayland wayland-protocols rofi-wayland swww

    echo Screenshots + clipboard.
    de grim slurp wl-clipboard cliphist

    echo Tray + notifications.
    de waybar

    echo OCR.
    de tesseract-ocr tesseract-ocr-eng tesseract-ocr-rus tesseract-ocr-chi-sim

    echo Developing.
    de python3 pipx

    echo Man.
    de tldr
    tldr --update

    # MPV theme.
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/tomasklaen/uosc/HEAD/installers/unix.sh)"

    # ZSH shift select
    repo github.com/jirutka/zsh-shift-select $USER_HOME/.local/share/zsh/plugins/zsh-shift-select

    systemctl enable --now ssh
    xdg-settings set default-web-browser firefox-esr.desktop

    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh # cargo installation
    repo github.com/Linus789/wl-clip-persist /tmp/wl-clip-persist&&cd /tmp/wl-clip-persist&&cargo build --release&&cp target/release/wl-clip-persist /usr/local/bin&&rm -rf /tmp/wl-clip-persist&&cd $CURRENT_DIR

    echo -e "${GREEN}Packages were installed.${RESET}"
}

packages_b(){
    prompt "installing packages via homebrew"

    # Install brew if missing.
    if ! exists brew; then
        echo -e "${YELLOW}Homebrew not found, installing..${RESET}"
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi

    brew install git curl

    echo Installing nix-darwin if missing.
    if ! exists darwin-rebuild && [[ $NO_NIX != "true" ]]; then
        nix run nix-darwin -- switch --flake $SHARED_MAC_PATH#main
    fi

    echo -e "${GREEN}Packages were installed.${RESET}"
}

drivers_pacman(){
    echo -e "${BLUE}Detecting hardware...${RESET}"

    # Detect virtualization first.
    if exists vboxservice || lspci 2>/dev/null | grep -qi "VirtualBox"; then
        echo -e "${GREEN}VirtualBox detected.${RESET}"
        p virtualbox-guest-utils virtualbox-guest-modules-artix
        return 0
    fi

    if exists vmware-checkvm || lspci 2>/dev/null | grep -qi "VMware"; then
        echo -e "${GREEN}VMware detected.${RESET}"
        p open-vm-tools xf86-video-vmware
        autolaunch vmtoolsd
        return 0
    fi

    # Detect GPU via lspci.
    local gpu=$(lspci 2>/dev/null | grep -iE "VGA|3D|Display")
    echo -e "GPU detected: ${BLUE}$gpu${RESET}"

    if echo "$gpu" | grep -qi "nvidia"; then
        echo -e "${GREEN}NVIDIA GPU detected.${RESET}"
        prompt "installing NVIDIA drivers"
        p nvidia nvidia-utils nvidia-settings lib32-nvidia-utils
        # For older GPUs uncomment one of these instead:
        # p nvidia-470xx-dkms nvidia-470xx-utils  # GTX 900 and older
        # p nvidia-390xx-dkms nvidia-390xx-utils  # Even older
        p cuda # Optional: CUDA support

    elif echo "$gpu" | grep -qi "amd\|radeon\|advanced micro"; then
        echo -e "${GREEN}AMD GPU detected.${RESET}"
        prompt "installing AMD drivers"
        p mesa lib32-mesa xf86-video-amdgpu vulkan-radeon lib32-vulkan-radeon
        p libva-mesa-driver lib32-libva-mesa-driver mesa-vdpau lib32-mesa-vdpau
        # Optional: ROCm for compute workloads
        # p rocm-opencl-runtime

    elif echo "$gpu" | grep -qi "intel arc\|intel.*xe"; then
        echo -e "${GREEN}Intel Arc GPU detected.${RESET}"
        prompt "installing Intel Arc drivers"
        p mesa lib32-mesa vulkan-intel lib32-vulkan-intel
        p intel-media-driver intel-compute-runtime level-zero-loader
        # Arc may need newer kernel - check if zen is new enough
        echo -e "${YELLOW}Note: Intel Arc works best on kernel 6.2+. Verify your kernel version.${RESET}"

    elif echo "$gpu" | grep -qi "intel"; then
        echo -e "${GREEN}Intel iGPU detected.${RESET}"
        prompt "installing Intel iGPU drivers"
        p mesa lib32-mesa vulkan-intel lib32-vulkan-intel
        p intel-media-driver libva-intel-driver # intel-media-driver for Gen8+, libva-intel-driver for older

    else
        echo -e "${YELLOW}GPU not recognized: $gpu${RESET}"
        echo -e "${YELLOW}Installing generic mesa drivers as fallback.${RESET}"
        p mesa lib32-mesa xf86-video-vesa
    fi

    # Check for hybrid GPU (e.g. laptop with Intel iGPU + Nvidia dGPU).
    local gpu_count=$(lspci 2>/dev/null | grep -icE "VGA|3D|Display")
    if [ "$gpu_count" -gt 1 ]; then
        echo -e "${YELLOW}Hybrid GPU setup detected ($gpu_count GPUs). Installing optimus manager.${RESET}"
        pa optimus-manager optimus-manager-qt
        autolaunch optimus-manager
    fi

    echo -e "${GREEN}Drivers were installed.${RESET}"
}

packages_apk(){
    echo "Coming soon."
}

cursor_name="clay_white"
cursor(){
    mkdir -p $USER_HOME/.local/share/icons/$cursor_name
    cp -r $SHARED_PATH/cursors/$cursor_name $USER_HOME/.local/share/icons
    echo -e "${GREEN}Cursor was installed.${RESET}"
}

cursor_remove(){
    rm -rf $USER_HOME/.local/share/icons/molnios/$cursor_name
    rm -rf /usr/share/icons/molnios
    echo -e "${GREEN}Cursor was removed.${RESET}"
}

font_install(){ # JetBrains Mono Nerd Font
    prompt "changing default font"
    mkdir -p /etc/fonts/conf.d
    cat > /etc/fonts/local.conf <<EOF
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <alias>
    <family>sans-serif</family>
    <prefer><family>JetBrainsMono Nerd Font</family></prefer>
  </alias>
  <alias>
    <family>serif</family>
    <prefer><family>JetBrainsMono Nerd Font</family></prefer>
  </alias>
  <alias>
    <family>monospace</family>
    <prefer><family>JetBrainsMono Nerd Font</family></prefer>
  </alias>
</fontconfig>
EOF
    fc-cache -fv
    echo -e "${GREEN}Default font set to JetBrains Mono Nerd Font.${RESET}"
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
    if [ ! $OS = "nix" ];then
        mkdir -p /usr/local/bin
        cp $SHARED_PATH/scripts/path.sh /usr/local/bin/path.sh
        cp $(readlink -f $0) /usr/local/bin/molnios.sh
        chmod a+x $SHARED_PATH/scripts/path.sh
        chmod a+x /usr/local/bin/molnios.sh
    fi
    mkdir -p $USER_HOME/.local/share/molnios
    ln -sfn $SHARED_PATH/scripts $USER_HOME/.local/share/molnios/scripts
    ln -sfn $SHARED_PATH/config $USER_HOME/.local/share/molnios/config
    ln -sfn $SHARED_PATH/images $USER_HOME/.local/share/molnios/images
    ln -sfn $SHARED_PATH/sfx $USER_HOME/.local/share/molnios/sfx
    chown -hR $USER: $USER_HOME/.local/share/molnios
    echo -e "${GREEN}Everything was successfully symlinked.${RESET}"
}

symlinks_remove(){
    rm -rf $USER_HOME/.local/share/molnios/molnios-media
    rm -rf $USER_HOME/.local/share/molnios/scripts
    rm -rf $USER_HOME/.local/share/molnios/config
    rm -rf $USER_HOME/.local/share/molnios/images
    rm -rf $USER_HOME/.local/share/molnios/sfx # Because of video repo
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
        rm -rf $USER_HOME/Screenshots
        echo -e "${GREEN}Existing symlinks were cleaned.${RESET}"
}

dots_backup(){
    if [ $NO_BACKUPS = true ];then
        echo -e "Backups were disabled."
    else
        dots_clean
        backup /etc/hosts
        backup $HOME_CONFIG/fastfetch/config.jsonc
        backup $HOME_CONFIG/feh/buttons
        backup $HOME_CONFIG/hypr/hyprland.conf
        backup $HOME_CONFIG/kitty/kitty.conf
        backup $HOME_CONFIG/kitty/kittystyle
        backup /etc/ly/config.ini
        backup $HOME_CONFIG/waypaper/config.ini
        backup $HOME_CONFIG/qBittorrent/qBittorrent.conf
    fi
    ln -sfn $SHARED_CONFIG/config/hosts /etc/hosts

    mkdir -p $HOME_CONFIG/fastfetch
    ln -sfn $SHARED_CONFIG/fastfetch.jsonc $HOME_CONFIG/fastfetch/config.jsonc

    mkdir -p $HOME_CONFIG/feh
    ln -sfn $SHARED_CONFIG/feh.conf $HOME_CONFIG/feh/buttons

    mkdir -p $HOME_CONFIG/hypr
    ln -sfn $SHARED_CONFIG/hyprland-monolithic/hypr.conf $HOME_CONFIG/hypr/hyprland.conf # TODO: change path to lua config when 0.55 will be released.
    ln -sfn $SHARED_CONFIG/hyprland-monolithic/custom $HOME_CONFIG/hypr/custom

    mkdir -p $HOME_CONFIG/kitty
    ln -sfn $SHARED_CONFIG/kitty.conf $HOME_CONFIG/kitty/kitty.conf
    ln -sfn $SHARED_CONFIG/kitty-style.conf $HOME_CONFIG/kitty/kitty-style.conf

    mkdir -p /etc/ly
    ln -sfn $SHARED_CONFIG/ly.ini /etc/ly/config.ini

    mkdir -p $HOME_CONFIG/waypaper

    cp $SHARED_CONFIG/waypaper.ini $HOME_CONFIG/waypaper/config.ini
    sed -i "s|$USER_HOME/.local/share/molnios/molnios-media/wallpapers|$SHARED_MEDIA_PATH|g" \
        $HOME_CONFIG/waypaper/config.ini

    mkdir -p $HOME_CONFIG/qBittorrent/themes
    ln -sfn $SHARED_CONFIG/qbittorrent $HOME_CONFIG/qBittorrent/qBittorrent.conf
    mkdir -p $HOME_CONFIG/qBittorrent/themes
    for theme in $SHARED_CONFIG/qbit-themes/*.qbtheme; do
        ln -sfn $theme $HOME_CONFIG/qBittorrent/themes/$(basename $theme)
    done
}

# 2.6. Main functions.
update(){
    repo $SHARED_REPO $SHARED_PATH
    if [ ! $OS = "mac" ];then
        symlinks
    fi
    if [[ $OS != "nix" && $NO_NIX != true ]];then
        nix flake update
        home-manager switch --impure --flake $SHARED_NIX_PATH#main
    fi
    if [ $OS = "nix" ];then
        repo $SHARED_REPO_NIX $SHARED_NIX_PATH #! Check if hardware-configuration.nix kills repo function.
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
        repo $SHARED_REPO_MAC $SHARED_MAC_PATH
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
        rm -rf /etc/nixos/*
        nixos-generate-config
    else
        rm -rf ./molnios*
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
    if [ $OS = "nix" ];then
        if ! exists git;then
            nix-shell -p git --run "git clone https://$SHARED_REPO.git $SHARED_PATH"
        else
            repo $SHARED_REPO $SHARED_PATH
        fi
        mkdir -p $SHARED_MEDIA_PATH
        repo $SHARED_REPO_NIX $SHARED_NIX_PATH
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
        repo $SHARED_REPO $SHARED_PATH
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
        repo $SHARED_REPO $SHARED_PATH
        media
        repo $SHARED_REPO_MAC $SHARED_MAC_PATH

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

if [[ $NO_NIX != true && $NIX_INSTALLED && $COLLECT_GARBAGE ]];then
    nix-collect-garbage -d
fi

echo -e "${FINISH}==========================================${RESET}"
echo -e "${FINISH}      PRE-INSTALLATION COMPLETE!           ${RESET}"
echo -e "${FINISH}==========================================${RESET}"
echo -e "               ...now configure what you need..."

exit 0