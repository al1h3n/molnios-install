NIX_INSTALLED="${NIX_INSTALLED:-false}"
NO_NIX="${NO_NIX:-false}"
ONLY_HOME="${ONLY_HOME:-false}"
COLLECT_GARBAGE="${COLLECT_GARBAGE:-false}"
UPDATE="${UPDATE:-false}"
REMOVE="${REMOVE:-false}"
DEBUG="${DEBUG:-false}"
FRESH_INSTALL="${FRESH_INSTALL:-false}"
DOWNLOAD_VIDEO_WALLPAPERS="${DOWNLOAD_VIDEO_WALLPAPERS:-false}"
DOWNLOAD_PHOTO_WALLPAPERS="${DOWNLOAD_PHOTO_WALLPAPERS:-false}"
PROMPT="${PROMPT:-true}"
BACKUPS="${BACKUPS:-false}"
REBOOT="${REBOOT:-false}"

OS="not supported"
SHARED_PATH="not existing"
CURRENT_DIR=$(pwd)
USER="${SUDO_USER:-$USER}"

if [ $(uname) = "Darwin" ];then
    USER_HOME=$(dscl . -read /Users/$USER NFSHomeDirectory | awk '{print $2}')
else
    USER_HOME=$(getent passwd $USER | cut -d: -f6)
fi

HOME_CONFIG=$USER_HOME/.config
ENV_FILE=/etc/environment

SHARED_REPO="gitlab.com/al1h3n/molnios-shared"
SHARED_MEDIA_STATIC_REPO="gitlab.com/al1h3n/molnios-media-static"
SHARED_MEDIA_DYNAMIC_REPO="codeberg.org/al1h3n/molnios-media-dynamic"
SHARED_CONFIG=$SHARED_PATH/config

cursor_name="clay_white"