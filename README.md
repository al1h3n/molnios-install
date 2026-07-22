# ⚡ MolniOS Project

#### More than regular dotfiles, less than independent ecosystem.
![Project](https://img.shields.io/badge/Type-Dotfiles-blue?style=for-the-badge&logo=archlinux)

![License](https://img.shields.io/badge/License-Proprietary-red?style=for-the-badge)

![Status](https://img.shields.io/badge/Status-Active-success?style=for-the-badge)

[![Downloads](https://img.shields.io/badge/dynamic/json?url=https://codeberg.org/api/v1/repos/al1h3n/install/releases&query=$[0].assets[0].download_count&label=Downloads&suffix=%20Total&color=green)](https://codeberg.org/al1h3n/install/releases)

[![Latest Release](https://img.shields.io/badge/dynamic/json?color=blue&label=release&query=%24.tag_name&url=https%3A%2F%2Fcodeberg.org%2Fal1h3n%2Fmolniux%2Freleases%2Flatest%2Fdownload%3Fformat%3Djson)](https://codeberg.org/al1h3n/molnios-shared/releases/latest)

[![Donate](https://img.shields.io/badge/Support-Buy%20Me%20A%20Coffee-ff5f5f.svg?style=for-the-badge&logo=ko-fi)](https://ko-fi.com/al1h3n)
***
**MolniOS** is my personal, highly customized dotfiles configuration for Hyprland, Niri, GNOME and Plasma.

This project represents a complete overhaul of the Wayland experience, designed for aesthetics, speed, and workflow efficiency. It is the result of countless hours of tweaking, styling, and scripting to achieve a perfect harmony between form and function between variety of distros.
> **Look, but don't touch.**
>
> This repository is publicly viewable for educational purposes and inspection, but the code and assets contained herein are **proprietary**.
> See the [License](https://codeberg.org/al1h3n/molnios-shared/raw/branch/main/LICENSE) section below.
>
> If you want to use this codebase in own commercial product, contact us.



## 📸 Gallery
<p align="center">
<img src="https://codeberg.org/al1h3n/molnios-objects/raw/branch/main/Gruvbox%20example.png" alt="Desktop Preview (with gruvbox theme)" width="45%" />
<video width="45%" controls>
  <source src="https://codeberg.org/al1h3n/molnios-objects/raw/branch/main/Preview%20of%20MolniOS%202026-07-22.mp4" type="video/mp4">
  Your browser does not support the video tag.
</video>
<img src="https://codeberg.org/al1h3n/molnios-objects/raw/branch/main/Rofi%20Preview%202026-07-22.png" alt="Rofi preview" width="45%" />

</p>

## ✅ Installation

Just type any of these commands:

```
git clone --depth=1 --filter=blob:none https://github.com/al1h3n/molnios-install
git clone --depth=1 --filter=blob:none https://gitlab.com/al1h3n/molnios-install
git clone --depth=1 --filter=blob:none https://codeberg.org/al1h3n/molnios-install
```

<!-- > ## PLEASE, DON'T USE THIS WITHOUT -f FLAG WHEN INSTALLING (or it won't properly work, known bug) -->
## 🛠️ The Tech Stack

| Category       | Application(s)                                                                                                                                                                                  | Description                                                                                                                                                                                                                                                                                            |
| -------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Window Manager | [Hyprland](https://hypr.land), [Niri](https://niri-wm.github.io/niri/index.html), [Plasma](https://kde.org/plasma-desktop), [GNOME](https://gnome.org)                                          | The core of the experience. Keybinds for [Hyprland](https://codeberg.org/al1h3n/molnios-shared/src/branch/main/documentation/hyprland-advanced.md), [Niri](https://codeberg.org/al1h3n/molnios-shared/src/branch/main/documentation/niri.md)                                                           |
| Terminal       | [Zellij](https://zellij.dev) (as multiplexer), [Kitty](https://sw.kovidgoyal.net/kitty) and [WezTerm](https://wezterm.org/index.html)                                                           | Blazing fast GPU-accelerated terminal. Shortcuts for [Kitty](https://codeberg.org/al1h3n/molnios-shared/src/branch/main/documentation/kitty.md), [WezTerm](https://codeberg.org/al1h3n/molnios-shared/src/branch/main/documentation/wezterm.md)<br>WezTerm is used in Niri, whereas Kitty in Hyprland. |
| Shell          | Zsh and [Fish](https://fishshell.com)                                                                                                                                                           | Currently, fish is under precedence, but you can change a few lines of configurations to utilize Zsh.                                                                                                                                                                                                  |
| Launcher       | [Rofi](https://github.com/davatorium/rofi), [Noctalia](https://noctalia.dev)                                                                                                                    | App launcher and power menu.                                                                                                                                                                                                                                                                           |
| Bar            | [Waybar](https://github.com/Alexays/Waybar), [Noctalia](https://noctalia.dev)                                                                                                                   | Noctalia is in precedence due to its configuration degree.                                                                                                                                                                                                                                             |
| Lock Screen    | [Hyprlock](https://wiki.hyprland.org/Hypr-Ecosystem/hyprlock/), [Noctalia](https://noctalia.dev)                                                                                                | Secure and aesthetic screen locking.                                                                                                                                                                                                                                                                   |
| TUI            | [ly](https://codeberg.org/fairyglade/ly)                                                                                                                                                        | Lightweight ncurses-like display manager. [Keybinds](https://codeberg.org/al1h3n/molnios-shared/src/branch/main/documentation/ly.md)                                                                                                                                                                   |
| Notifications  | [Dunst](https://dunst-project.org), [SwayNC](https://github.com/ErikReider/SwayNotificationCenter)                                                                                              | Minimalist notification daemon.                                                                                                                                                                                                                                                                        |
| Wallpaper      | [Waypaper](https://github.com/anufrievroman/waypaper), [Noctalia](https://noctalia.dev)]                                                                                                        | Uses `awww` + `mpvpaper` for static and live wallpapers.                                                                                                                                                                                                                                               |
| File Manager   | [Thunar](https://gitlab.xfce.org/xfce/thunar)                                                                                                                                                   | Lightweight and fast.                                                                                                                                                                                                                                                                                  |
| Clipboard      | [cliphist](https://github.com/sentriz/cliphist)                                                                                                                                                 | History manager for the clipboard.                                                                                                                                                                                                                                                                     |
| Auth           | polkit-gnome, [hyprpolkitagent](https://wiki.hypr.land/Hypr-Ecosystem/hyprpolkitagent)                                                                                                          | Authentication agent.                                                                                                                                                                                                                                                                                  |
| Connectivity   | nm-applet / [blueman](https://github.com/blueman-project/blueman), [Noctalia](https://noctalia.dev), [impala](https://github.com/pythops/impala), [bluetui](https://github.com/pythops/bluetui) | Network and Bluetooth management.                                                                                                                                                                                                                                                                      |
| Media          | [MPV](https://mpv.io), [Spotify](https://open.spotify.com) ([spicetify](https://spicetify.app/docs/getting-started) / [spicetify-nix](https://github.com/the-argus/spicetify-nix)).             | Video and Music consumption.                                                                                                                                                                                                                                                                           |
| Editors        | [Neovim](https://neovim.io) ([lazyvim](https://lazyvim.org/)), [VSCodium](https://vscodium.com)                                                                                                 | For serious coding. [VSCodium](https://vscodium.com) is VSCode without telemetry.                                                                                                                                                                                                                      |
| Productivity   | [Notion](https://notion.so) (Electron, not on nixOS), [Obsidian](https://obsidian.md), [Logseq](https://logseq.com)                                                                             | Notes and organization.                                                                                                                                                                                                                                                                                |
| Browser        | [Librewolf](https://librewolf.net), Firefox                                                                                                                                                     | Better than Firefox in terms of privacy. Tweaked manually to be secured and faster.                                                                                                                                                                                                                    |

## 🧠 Custom Scripting
One of the standout features of **Molniux** is the backend logic.

* **Screenshot Manager:** A custom implementation using `grim` + `tee` to handle captures and processing instantly.
* **Recordings:** Another one script which automatically handles recording via [wf-recorder](https://github.com/ammen99/wf-recorder) or [OBS](https://obsproject.com)
* **External scripts:** Made to be compatible for this project, we created a lot of additions for uniqueness
	* [sweeper](https://github.com/Alihan1ai9595/sweeper) (system cleaner)
	* [Disk Mounter](https://codeberg.org/al1h3n/molnios-shared/src/branch/main/scripts/disk-mounter.sh) (made to make proccess of mounting devices easier)
	* [Reloadus](https://codeberg.org/al1h3n/molnios-shared/src/branch/main/scripts/reloadus.sh) (reloads entire configurations to avoid rebooting)
	* [Git Cooker](https://codeberg.org/al1h3n/molnios-shared/src/branch/main/scripts/gooker.sh) (all-in-one tool for git projects)
	* MolniOS [menu](https://codeberg.org/al1h3n/molnios-shared/src/branch/main/scripts/menu/molnios-menu.sh) (a gem for your administration)
	* And tons of QOL features as well!

* **Automation:** Several scripts in this repository were written over **days of straight work** to handle specific edge cases, window rules, and system behavior that standard configurations simply don't offer.



## ☕ Support My Work
Creating **Molniux** took a significant amount of time and sleepless nights. If you enjoy looking at my code or find the architecture inspiring, consider buying me a coffee!
<a href="https://ko-fi.com/al1h3n">
<img src="https://img.shields.io/badge/Support-Buy%20Me%20A%20Coffee-yellow.svg?style=for-the-badge&logo=ko-fi" alt="Buy me some noodles!" />
</a>

## ⚠️ License & Disclaimer
**© Copyright [2026] al1h3n. All Rights Reserved.**

This repository is **Source-Available**, meaning you can view the code to see how it works, but it is **NOT Open Source** in the traditional sense (it is not MIT, GPL, etc.).
### Terms of Use:

1. **No Copying:** You may **not** copy, reproduce, distribute, or modify any part of this configuration or the scripts contained within without my explicit, written permission (the only exception - personal use).
2. **No Commercial Use:** You may not use this configuration for any commercial purpose.
3. **Educational Use:** You are free to read the code to understand the logic.
### Disclaimer:
> All configurations, scripts, and visual styles found in this repository are the result of my own personal work. **Any resemblance to other configurations, dotfiles, or rices is pure random and completely coincidental.**
***