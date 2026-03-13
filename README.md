# ⚡ MolniOS Project
**More than regular dotfiles, less than independent ecosystem.**

![Hyprland](https://img.shields.io/badge/Type-Dotfiles-blue?style=for-the-badge&logo=archlinux)
![License](https://img.shields.io/badge/License-Proprietary-red?style=for-the-badge)
![Status](https://img.shields.io/badge/Status-Active-success?style=for-the-badge)
[![Downloads](https://img.shields.io/badge/dynamic/json?url=https://codeberg.org/api/v1/repos/al1h3n/install/releases&query=$[0].assets[0].download_count&label=Downloads&suffix=%20Total&color=green)](https://codeberg.org/al1h3n/install/releases)
[![Latest Release](https://img.shields.io/badge/dynamic/json?color=blue&label=release&query=%24.tag_name&url=https%3A%2F%2Fcodeberg.org%2Fal1h3n%2Fmolniux%2Freleases%2Flatest%2Fdownload%3Fformat%3Djson)](https://codeberg.org/al1h3n/molnios-shared/releases/latest)
<a href="https://ko-fi.com/al1h3n">
  <img src="https://img.shields.io/badge/Support-Buy%20Me%20A%20Coffee-ff5f5f.svg?style=for-the-badge&logo=ko-fi" alt="Buy me some noodles!" />
</a>

**MolniOS** is my personal, highly customized dotfiles configuration for **Hyprland**. 

This project represents a complete overhaul of the Wayland experience, designed for aesthetics, speed, and workflow efficiency. It is the result of countless hours of tweaking, styling, and scripting to achieve a perfect harmony between form and function.

> **Look, but don't touch.**
> This repository is publicly viewable for educational purposes and inspection, but the code and assets contained herein are **proprietary**. See the [License](https://codeberg.org/al1h3n/molnios-shared/raw/branch/main/LICENSE) section below.

## 📸 Preview

<!-- Upload screenshots to your repo (e.g., inside a screenshots/ folder) and link them here -->
<p align="center">
  <img src="./screenshots/desktop.png" alt="Desktop Preview" width="45%" />
  <img src="./screenshots/menu.png" alt="Rofi Preview" width="45%" />
</p>

## ✅ Installation
Just type any of these commands:
```
git clone https://github.com/al1h3n/molnios-install
git clone https://gitlab.com/al1h3n/molnios-install
git clone https://codeberg.org/al1h3n/molnios-install
```
> ## PLEASE, DON'T USE THIS WITHOUT -f FLAG WHEN INSTALLING (or it won't properly work, known bug)


## 🛠️ The Tech Stack

| Category | Application | Description |
| :--- | :--- | :--- |
| **Window Manager** | [Hyprland](https://hyprland.org/) | The core of the experience. [Keybinds](https://codeberg.org/al1h3n/molnios-shared/src/branch/main/documentation/hyprland.md) |
| **Shell & Term** | Zsh + [Kitty](https://sw.kovidgoyal.net/kitty/) | Blazing fast GPU-accelerated terminal. [Shortcuts](https://codeberg.org/al1h3n/molnios-shared/src/branch/main/documentation/zsh.md) |
| **Launcher** | [Rofi](https://github.com/davatorium/rofi) | App launcher and power menu. |
| **Bar** | [Waybar](https://github.com/Alexays/Waybar) | Highly configured status bar. |
| **Lock Screen** | [Hyprlock](https://wiki.hyprland.org/Hypr-Ecosystem/hyprlock/) | Secure and aesthetic screen locking. |
| **TUI** | [ly](https://codeberg.org/fairyglade/ly) | Lightweight ncurses-like display manager. [Keybinds](https://codeberg.org/al1h3n/molnios-shared/src/branch/main/documentation/ly.md) |
| **Notifications** | [Dunst](https://dunst-project.org/) / [swaync](https://github.com/ErikReider/SwayNotificationCenter)| Minimalist notification daemon. |
| **Wallpaper** | [Waypaper](https://github.com/anufrievroman/waypaper) | Using `swww` + `mpvpaper` for static and live wallpapers. |
| **File Manager** | Thunar | Lightweight and fast. |
| **Clipboard** | Cliphist | History manager for the clipboard. |
| **Auth** | Polkit-Gnome | Authentication agent. |
| **Connectivity** | nm-applet / blueman | Network and Bluetooth management. |
| **Media** | [MPV](https://mpv.io) / [Spotify](https://spotify.com) | Video and Music consumption. |
| **Editors** | Neovim / VSCodium | For serious coding. |
| **Productivity** | [Notion (Electron)](https://notion.so), [Obsidian](https://obsidian.md) | Notes and organization. |
| **Browser** | Firefox | Web browsing. |

## 🧠 Custom Scripting

One of the standout features of **Molniux** is the backend logic.

*   **Screenshot Manager:** A custom implementation using `grim` + `tee` to handle captures and processing instantly.
*   **Recordings:** Another one script which automatically handles recording via [wf-recorder](https://github.com/ammen99/wf-recorder) or [OBS](https://obsproject.com)
*   **External scripts:** Made to be compatible for this project, we created a lot of additions for uniqueness - [sweeper](https://github.com/Alihan1ai9595/sweeper) (system cleaner), Disk Mounter [DM] (made to make proccess of mounting devices easier), Reloadus (reloads entire configurations to avoid rebooting), PathSH (use to shorten paths to your config files), and tons of QOL features.
*   **Automation:** Several scripts in this repository were written over **days of straight work** to handle specific edge cases, window rules, and system behavior that standard configurations simply don't offer.

## ☕ Support My Work

Creating **Molniux** took a significant amount of time and sleepless nights. If you enjoy looking at my code or find the architecture inspiring, consider buying me a coffee!

<a href="https://ko-fi.com/al1h3n">
  <img src="https://img.shields.io/badge/Support-Buy%20Me%20A%20Coffee-yellow.svg?style=for-the-badge&logo=ko-fi" alt="Buy me some noodles!" />
</a>

<!-- Or use Ko-fi / PayPal links here -->

## ⚠️ License & Disclaimer

**© Copyright [2026] al1h3n. All Rights Reserved.**

This repository is **Source-Available**, meaning you can view the code to see how it works, but it is **NOT Open Source** in the traditional sense (it is not MIT, GPL, etc.).

### Terms of Use:
1.  **No Copying:** You may **not** copy, reproduce, distribute, or modify any part of this configuration or the scripts contained within without my explicit, written permission (the only exception - personal use).
2.  **No Commercial Use:** You may not use this configuration for any commercial purpose.
3.  **Educational Use:** You are free to read the code to understand the logic.

### Disclaimer:
> All configurations, scripts, and visual styles found in this repository are the result of my own personal work. **Any resemblance to other configurations, dotfiles, or rices is pure random and completely coincidental.**

***
