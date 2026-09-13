# Colors.

# Fallback to 256-color approximations
GREEN=$'\e[0;32m'
FINISH=$'\e[1;32m'
YELLOW=$'\e[0;33m'
RED=$'\e[0;31m'
BLUE=$'\e[0;34m'
WHITE=$'\e[0;37m'
BG=$'\e[0;30m'
RESET=$'\e[0m'

# repo.sh uses these; they were never defined anywhere, so 12 call sites printed
# nothing and would abort under set -u.
_BLD=$'\e[1m'
_YLW=$YELLOW
_CYN=$'\e[0;36m'
_RST=$RESET