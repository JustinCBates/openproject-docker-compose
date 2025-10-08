# Red Hat Family Utilities

This directory contains OS-specific utility scripts for Red Hat-based distributions:
- RHEL (Red Hat Enterprise Linux)
- CentOS / Rocky Linux / AlmaLinux
- Fedora

## Package Manager
Uses `dnf` (modern) or `yum` (legacy) for package management.

## Service Manager
Uses `systemctl` for service management.

## Common Paths
- Config files: `/etc/`
- Logs: `/var/log/`
- Services: `/usr/lib/systemd/system/`

Scripts in this directory

- `install_docker.redhat.sh` - OS-specific Docker installation script
- `configure_docker.redhat.sh` - Docker configuration helper
- `build_stack.redhat.sh` - Helper to assemble the stack for RedHat-family systems