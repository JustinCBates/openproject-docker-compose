# Arch Family Utilities

This directory contains OS-specific utility scripts for Arch-based distributions:
- Arch Linux
- Manjaro
- EndeavourOS
- Artix Linux

## Package Manager
Uses `pacman` for package management and `yay`/`paru` for AUR packages.

## Service Manager
Uses `systemctl` for service management.

## Common Paths
- Config files: `/etc/`
- Logs: `/var/log/`
- Services: `/usr/lib/systemd/system/`

Scripts in this directory

- `install_docker.arch.sh` - OS-specific Docker installation script
- `configure_docker.arch.sh` - Docker configuration helper
- `build_stack.arch.sh` - Helper to assemble the stack for Arch-family systems