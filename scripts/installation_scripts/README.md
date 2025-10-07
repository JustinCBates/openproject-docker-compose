# Installation Scripts

This directory contains all scripts related to installing, configuring, and deploying OpenProject and its dependencies.

## Main Scripts

### `deploy_interactive.sh` 
Interactive configuration and deployment script that guides users through the entire setup process.

**Features:**
- OpenProject configuration (hostname, HTTPS, version)
- Git user configuration
- Domain and subdomain setup
- Environment type selection (localdev/remotedev/remotetest/production)
- OS family detection and selection
- Configuration persistence in `.deploy_interactive.cfg`

**Usage:**
```bash
./deploy_interactive.sh
```

### `deploy.sh`
Deployment orchestrator that executes utility scripts in logical order based on saved configuration.

**Features:**
- Validates configuration file
- Executes utility scripts sequentially
- Provides deployment summary
- Environment-specific warnings and guidance

**Usage:**
```bash
./deploy.sh
```

## Utilities Directory

The `utilities/` directory contains modular utility scripts that handle specific configuration tasks:

### Cross-Platform Utilities
- **`git_user.sh`** - Configures git username and email from saved settings
- **`install_docker.sh`** - Docker installation dispatcher (calls OS-specific scripts)

### OS-Specific Utilities
Each OS family has its own subdirectory with specialized scripts:

- **`debian/`** - Debian, Ubuntu, Linux Mint, Raspbian
- **`redhat/`** - RHEL, CentOS, Fedora, Rocky Linux, AlmaLinux
- **`suse/`** - openSUSE Leap/Tumbleweed, SLES
- **`arch/`** - Arch Linux, Manjaro, EndeavourOS
- **`slackware/`** - Slackware Linux

Each OS directory contains:
- `install_docker.sh` - OS-specific Docker installation
- `README.md` - OS-specific documentation

## Configuration File

### `.deploy_interactive.cfg`
Stores all user configuration choices for use by utility scripts:

```bash
OPENPROJECT_HOST_NAME=example.com
OPENPROJECT_HTTPS=true
OPENPROJECT_TAG=16-slim
GIT_USERNAME=john.doe
GIT_EMAIL=john.doe@example.com
DOMAIN_NAME=example.com
SUBDOMAIN=openproject
ENVIRONMENT_TYPE=production
OS_FAMILY=debian
```

## Workflow

1. **Interactive Configuration** - Run `deploy_interactive.sh` to collect user preferences
2. **Automatic Deployment** - Run `deploy.sh` to execute deployment using saved configuration
3. **Individual Utilities** - Run specific utility scripts as needed

## Supported Environments

- **localdev** - Local development environment
- **remotedev** - Remote development server
- **remotetest** - Remote testing/staging server
- **production** - Production server

## Supported OS Families

- **debian** - Uses `apt` package manager, `systemctl` service management
- **redhat** - Uses `dnf`/`yum` package manager, `systemctl` service management
- **suse** - Uses `zypper` package manager, `systemctl` service management
- **arch** - Uses `pacman` package manager, `systemctl` service management
- **slackware** - Uses `slackpkg` package manager, SysV init scripts

## Requirements

- **Root/sudo access** - Many scripts require elevated privileges
- **Internet connection** - For downloading packages and Docker images
- **Git** - For repository management and configuration
- **Curl** - For downloading dependencies

## Usage Examples

### Complete Deployment
```bash
# Interactive setup and deployment
./deploy_interactive.sh

# Or run deployment separately after configuration
./deploy.sh
```

### Individual Components
```bash
# Configure git user only
./utilities/git_user.sh

# Install Docker only
./utilities/install_docker.sh

# OS-specific Docker installation
./utilities/debian/install_docker.sh
```

### Re-configuration
```bash
# Reconfigure settings
./deploy_interactive.sh

# Deploy with new settings
./deploy.sh
```

## Troubleshooting

### Configuration Issues
- Ensure `.deploy_interactive.cfg` exists and contains required variables
- Run `deploy_interactive.sh` to recreate configuration

### Permission Issues
- Run scripts with `sudo` when required
- Check script executable permissions: `chmod +x script_name.sh`

### OS Detection Issues
- Manually specify OS family in configuration
- Check `/etc/os-release` for distribution information

### Docker Issues
- Verify internet connectivity for downloads
- Check firewall settings
- Ensure sufficient disk space
- Review OS-specific documentation in utility subdirectories

## Security Considerations

- **Production deployments** receive additional security warnings
- **Configuration files** may contain sensitive information
- **Environment-specific** security recommendations provided
- **Firewall configuration** handled by OS-specific scripts
- **User group management** for Docker access