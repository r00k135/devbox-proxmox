#!/usr/bin/env bash
###############################################################################
# This script is intended to be run from a new devbox after it has been
# provisioned, the script should run as root so it doesn't run into permissions
# issues
###############################################################################

set -e

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
    curl
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
curl -fsSL https://aka.ms/copilot-cli/install.sh -o install-copilot.sh
sh install-copilot.sh
# check the script installed copilot correctly
if ! command -v copilot &> /dev/null; then
    echo "Copilot CLI installation failed"
    exit 1
fi
