BLACK="\e[0;30m"
RED="\e[0;31m"
GREEN="\e[0;32m"
YELLOW="\e[0;33m"
BLUE="\e[0;34m"
PURPLE="\e[0;35m"
CYAN="\e[0;36m"
WHITE="\e[0;37m"
ORANGE="\e[38;5;214m"
ENDCOLOR="\e[0m"

echo_in_green() {
    echo -e "${GREEN}$1${ENDCOLOR}"
}
echo_in_orange() {
    echo -e "${ORANGE}$1${ENDCOLOR}"
}
echo_in_red() {
    echo -e "${RED}$1${ENDCOLOR}"
}
echo_in_purple() {
    echo -e "${PURPLE}$1${ENDCOLOR}"
}

echo_in_yellow() {
    echo -e "${YELLOW}$1${ENDCOLOR}"
}

echo_in_blue() {
    echo -e "${BLUE}$1${ENDCOLOR}"
}
