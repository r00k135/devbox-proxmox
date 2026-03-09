#!/usr/bin/env bash
###############################################################################
# This script is intended to be run from the proxmox host to provision a new 
# devbox container, the script should be run as root
###############################################################################

set -e

# check if the script is being run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root"
    exit 1
fi

# create a new container with the specified name and template
BASE_CONTAINER_NAME="devbox"
TEMPLATE="local:vztmpl/ubuntu-24.04-standard_24.04-2_amd64.tar.zst"
NETWORK_BRIDGE="vmbr0"
START_CONTAINER_ID=200
CORES=2
MEMORY=2048
SWAP=512
ROOTFS_SIZE=16
# append the current timestamp in a human-readable format to the container name to ensure uniqueness
TIMESTAMP=$(date +%Y%m%d%H%M%S)
# Convert the timestamp to hex and take the last 5 characters to ensure the container name is unique
TIMESTAMP_HEX=$(printf '%x' "$TIMESTAMP" | tail -c 5)
CONTAINER_NAME="${BASE_CONTAINER_NAME}-${TIMESTAMP_HEX}"
# check if a container with the same name already exists, if it does, exit with an error
if pct list | grep -q "$CONTAINER_NAME"; then
    echo "A container with the name $CONTAINER_NAME already exists, please choose a different name"
    exit 1
fi

# Find the next available numeric container ID, starting at 200.
CONTAINER_ID="$START_CONTAINER_ID"
while pct status "$CONTAINER_ID" > /dev/null 2>&1; do
    CONTAINER_ID=$((CONTAINER_ID + 1))
done

pct create "$CONTAINER_ID" "$TEMPLATE" \
    --hostname "$CONTAINER_NAME" \
    --net0 name=eth0,bridge=$NETWORK_BRIDGE,ip=dhcp \
    --cores $CORES --memory $MEMORY --swap $SWAP --rootfs local-lvm:$ROOTFS_SIZE --unprivileged 0
if [ $? -ne 0 ]; then
    echo "Failed to create container $CONTAINER_NAME"
    exit 1
fi

# update the container config and add following lines to the config
CONFIG_FILE="/etc/pve/lxc/${CONTAINER_ID}.conf"
{
    echo "lxc.apparmor.profile: unconfined"
    echo "lxc.cap.drop:"
    echo "lxc.cgroup2.devices.allow: c 10:229 rwm"
    echo "lxc.mount.entry: /dev/fuse dev/fuse none bind,create=file"
    echo "lxc.cgroup2.devices.allow: c 10:200 rwm"
    echo "lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file"
} >> "$CONFIG_FILE"
if [ $? -ne 0 ]; then
    echo "Failed to update container config for $CONTAINER_NAME"
    exit 1
fi

# start the container
pct start "$CONTAINER_ID"
if [ $? -ne 0 ]; then
    echo "Failed to start container $CONTAINER_NAME"
    exit 1
fi

# wait for the container to start and retrieve its IP address
echo "Waiting for container $CONTAINER_NAME to start..."
sleep 5

CONTAINERS_IP=$(pct exec "$CONTAINER_ID" -- sh -lc "hostname -I | awk '{print \$1}'")
if [ -z "$CONTAINERS_IP" ]; then
    echo "Failed to retrieve IP address for container $CONTAINER_NAME"
    exit 1
fi

# check the container name with .lan on the end is available via DNS linked to DHCP leases from nameserver 192.168.0.1
CONTAINER_DNS_NAME_VALID=$(nslookup "$CONTAINER_NAME.lan" 192.168.0.1 2>&1 | grep -q "Address:")
if ! $CONTAINER_DNS_NAME_VALID; then
    echo "Failed to resolve $CONTAINER_NAME.lan via DNS, please check your DHCP leases and nameserver configuration"
    exit 1
else
    echo "Container $CONTAINER_NAME is available via DNS as $CONTAINER_NAME.lan"
fi

# output summary information about the new container
echo ""
echo "--------------------------------------------------------------"
echo "Container $CONTAINER_NAME created and started successfully!"
echo "Container ID: $CONTAINER_ID"
echo "Hostname: $CONTAINER_NAME"
echo "Network: $NETWORK_BRIDGE (DHCP)"
echo "Cores: $CORES"
echo "Memory: $MEMORY MB"
echo "Swap: $SWAP MB"
echo "Root filesystem: local-lvm:$ROOTFS_SIZE GB"
echo "Containers DHCP IP address: $CONTAINERS_IP"
if $CONTAINER_DNS_NAME_VALID; then
    echo "Container DNS name: $CONTAINER_NAME.lan"
else
    echo "Container DNS name: Not available via DNS, please check your DHCP leases and nameserver configuration"
fi
echo ""
echo "To access the container, use: pct enter $CONTAINER_ID"
