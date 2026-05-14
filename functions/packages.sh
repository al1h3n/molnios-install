# Legacy.
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