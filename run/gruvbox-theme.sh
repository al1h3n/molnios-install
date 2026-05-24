# Colors (gruvbox theme).

# Fallback to 256-color approximations
GREEN=$'\033[38;5;142m'
FINISH=$'\033[38;5;100m'
YELLOW=$'\033[38;5;214m'
RED=$'\033[38;5;167m'
BLUE=$'\033[38;5;108m'
WHITE=$'\033[38;5;223m'
BG=$'\033[48;5;235m'
RESET=$'\033[0m'

if [[ $COLORTERM =~ ^(truecolor|24bit)$ ]];then
    # bright_green  #b8bb26
    GREEN=$'\033[38;2;184;187;38m'
    # neutral_green #98971a
    FINISH=$'\033[38;2;152;151;26m'
    # bright_yellow #fabd2f
    YELLOW=$'\033[38;2;250;189;47m'
    # bright_red #fb4934
    RED=$'\033[38;2;251;73;52m'
    # bright_aqua #8ec07c
    BLUE=$'\033[38;2;142;192;124m'
    # light1 #ebdbb2
    WHITE=$'\033[38;2;235;219;178m'
    # dark0 #282828
    BG=$'\033[48;2;40;40;40m'
fi