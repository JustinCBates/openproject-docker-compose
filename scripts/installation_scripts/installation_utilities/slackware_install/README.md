# Slackware Family Utilities

This directory contains OS-specific utility scripts for Slackware-based distributions:
- Slackware Linux

## Package Manager
Uses `slackpkg` for package management or manual package installation.

## Service Manager
Uses traditional SysV init scripts in `/etc/rc.d/`.

## Common Paths
- Config files: `/etc/`
- Logs: `/var/log/`
- Init scripts: `/etc/rc.d/`
- Services: `/etc/rc.d/rc.*`

Scripts in this directory

- `install_docker.slackware.sh` - OS-specific Docker installation script
- `configure_docker.slackware.sh` - Docker configuration helper
- `build_stack.slackware.sh` - Helper to assemble the stack for Slackware-family systems