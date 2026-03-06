# devbox-proxmox
My repository for preparing devboxes on proxmox with a number of tools such as:
- vscode remote server: https://code.visualstudio.com/docs/remote/vscode-server
- docker: https://docs.docker.com/engine/install/ubuntu/#install-using-the-convenience-script
- copilot cli: https://github.com/features/copilot/cli

Also system configuration such as:
- proxmox launch command
- apparmour fix for ubuntu lxc templates
- ssh config such allowing tunneling
- sudo setup to run docker commands as unprivilaged user

## Provion Proxmox Container
```
wget -q https://github.com/r00k135/devbox-proxmox/raw/refs/heads/main/proxmox-provision.sh -O proxmox-provision.sh
chmod +x ./proxmox-provision.sh
./proxmox-provision.sh
```

## Devbox customisation
```
wget -q https://github.com/r00k135/devbox-proxmox/raw/refs/heads/main/devbox-config.sh -O devbox-config.sh
bash ./devbox-config.sh
```