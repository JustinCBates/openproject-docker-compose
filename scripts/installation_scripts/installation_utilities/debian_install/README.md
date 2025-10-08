# Debian Family Utilities

This directory contains OS-specific utility scripts for Debian-based distributions:
- Debian
- Ubuntu  
- Linux Mint
- Raspbian

## Package Manager
Uses `apt` for package management.

## Service Manager
Uses `systemctl` for service management.

## Common Paths
- Config files: `/etc/`
- Logs: `/var/log/`
- Services: `/lib/systemd/system/`

Scripts in this directory

- `install_docker.debian.sh` - OS-specific Docker installation script
- `configure_docker.debian.sh` - Docker configuration helper
- `build_stack.debian.sh` - Helper to assemble the stack for Debian-family systems