media(){
    if $DOWNLOAD_PHOTO_WALLPAPERS;then
        _repo $SHARED_MEDIA_STATIC_REPO $SHARED_MEDIA_PATH
    fi
    if $DOWNLOAD_VIDEO_WALLPAPERS;then
        _repo $SHARED_MEDIA_DYNAMIC_REPO $SHARED_MEDIA_PATH
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
    # if [ ! $OS = "nixos" ];then
        mkdir -p /usr/local/bin
        # ln -sfn $SHARED_PATH/scripts/debug/path.sh /usr/local/bin/path.sh
        # chmod a+x $SHARED_PATH/scripts/debug/path.sh
        cp $(readlink -f $0) /usr/local/bin/molnios.sh
        chmod a+x /usr/local/bin/molnios.sh
        ln -sfn $SHARED_PATH/scripts/gooker.sh /usr/local/bin/gooker.sh
        chmod a+x $SHARED_PATH/scripts/gooker.sh
    # fi
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
    rm -rf /usr/local/bin/gooker.sh
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
    restore $HOME_CONFIG/niri/config.kdl
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
        # rm -rf $USER_HOME/Screenshots
        rm -f $HOME_CONFIG/niri/config.kdl
        echo -e "${GREEN}Existing symlinks were cleaned.${RESET}"
}

dots_backup(){
    if [ $BACKUPS != true ];then
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
        backup $HOME_CONFIG/niri/config.kdl
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

    mkdir -p $HOME_CONFIG/niri
    ln -sfn $SHARED_CONFIG/niri/niri.kdl $HOME_CONFIG/niri/config.kdl
}