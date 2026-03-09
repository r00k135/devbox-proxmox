#!/usr/bin/env bash
###############################################################################
# This script is intended to be run from a new devbox after it has been
# provisioned, the script should run as root so it doesn't run into permissions
# issues
###############################################################################

set -e

# If invoked with sh/dash, restart with bash so bash-only syntax works.
if [ -z "${BASH_VERSION:-}" ]; then
    exec /usr/bin/env bash "$0" "$@"
fi

# check if the script is being run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root"
    exit 1
fi

# set environment variables for non-interactive apt installs
export DEBIAN_FRONTEND=noninteractive

# update the os
if ! apt update -y; then
    echo "Failed to update package lists"
    exit 1
fi
if ! apt upgrade -y; then
    echo "Failed to upgrade packages"
    exit 1
fi

# install packages, including packages for docker, copilot cli and vscode serverdependencies
PACKAGES=(
    git
    vim
    build-essential
    sudo
    nodejs
    npm
    gpg
    software-properties-common
    tcpdump
    lsof
    dnsutils
    net-tools
    wget
    curl
    screen
)
if ! apt install -y "${PACKAGES[@]}"; then
    echo "Failed to install packages"
    exit 1
fi

# create a devbox user and add it to the sudo group
useradd -m -s /bin/bash devbox
if ! id -u devbox &> /dev/null; then
    echo "Failed to create devbox user"
    exit 1
fi
usermod -aG sudo devbox
# allow the devbox user to run sudo commands without a password
echo "devbox ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
# set the devbox user's password to "devbox" (you should change this after the first login)
echo "devbox:devbox" | chpasswd
# add a hushlogin file to the devbox user's home directory to disable the message of the day
touch /home/devbox/.hushlogin
chown devbox:devbox /home/devbox/.hushlogin

# install docker using the convenience script
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
# check the script installed docker correctly
if ! command -v docker &> /dev/null; then
    echo "Docker installation failed"
    exit 1
fi
rm get-docker.sh

# add devbox user to the docker group
usermod -aG docker devbox

# install copilot cli
curl -fsSL https://gh.io/copilot-install | bash
# check the script installed copilot correctly
if [ "$?" -ne 0 ]; then
    echo "Copilot CLI installation failed"
    exit 1
fi

# Create a copilot function for the devbox user.
cat <<'EOF' >> /home/devbox/.bashrc
cli() {
    local continue_flag=""
    local args=()

    for arg in "$@"; do
        case "$arg" in
            --continue)
                continue_flag="--continue"
                ;;
            *)
                args+=("$arg")
                ;;
        esac
    done

    copilot \
        --allow-tool "write" \
        --allow-tool "shell" \
        --deny-tool "shell(git:*)" \
        --allow-all-paths \
        --allow-all-urls \
        "${args[@]}" \
        $continue_flag
}
EOF
chown devbox:devbox /home/devbox/.bashrc

# print out the ip address of the container for reference
CONTAINERS_IP=$(hostname -I | awk '{print $1}')
echo "Devbox IP address: $CONTAINERS_IP"

# update the message displayed on the console before login to include the IP address (dynamically) of the container
echo -e "The IP address of this Devbox is: \\4 \n" >> /etc/issue


# reboot the container to ensure all changes take effect
echo "Rebooting the container to apply changes..."
reboot
