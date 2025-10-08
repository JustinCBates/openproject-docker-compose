# SUSE Family Utilities

This directory contains OS-specific utility scripts for SUSE-based distributions:
- openSUSE Leap
- openSUSE Tumbleweed  
- SLES (SUSE Linux Enterprise Server)

## Package Manager
Uses `zypper` for package management.

## Service Manager
Uses `systemctl` for service management.

## Common Paths
- Config files: `/etc/`
- Logs: `/var/log/`
- Services: `/usr/lib/systemd/system/`

Scripts in this directory

- `install_docker.suse.sh` - OS-specific Docker installation script
- `configure_docker.suse.sh` - Docker configuration helper
- `build_stack.suse.sh` - Helper to assemble the stack for SUSE-family systems