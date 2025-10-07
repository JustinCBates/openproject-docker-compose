# Scripts Directory

This directory contains various script categories for the OpenProject Docker Compose deployment.

## Directory Structure

```
scripts/
└── installation_scripts/    # Installation and deployment scripts
```

## Script Categories

### Installation Scripts (`installation_scripts/`)
Contains all scripts related to installing, configuring, and deploying OpenProject and its dependencies.

- **Main deployment scripts**
- **Utility scripts for system configuration**
- **OS-specific installation scripts**
- **Docker installation and setup**

## Usage

Navigate to the appropriate subdirectory for the type of scripts you need:

```bash
# For installation and deployment
cd installation_scripts/

# Run interactive deployment
./interactive_config.sh

# Run deployment orchestrator
./deploy.sh
```

## Future Script Categories

This directory structure allows for easy expansion with additional script categories:

- `monitoring_scripts/` - System monitoring and alerting
- `backup_scripts/` - Backup and recovery operations
- `maintenance_scripts/` - System maintenance and updates
- `security_scripts/` - Security hardening and auditing
- `utility_scripts/` - General utility and helper scripts

## Contributing

When adding new scripts:

1. **Choose appropriate category** - Use existing subdirectories or create new ones
2. **Follow naming conventions** - Use descriptive names with `.sh` extension
3. **Set executable permissions** - `chmod +x script_name.sh`
4. **Include documentation** - Add README files for new categories
5. **Test thoroughly** - Ensure scripts work across target environments

## Script Standards

All scripts should follow these standards:

- **Shebang line**: `#!/bin/bash`
- **Error handling**: `set -e` for critical scripts
- **Documentation**: Clear comments and usage instructions
- **Configuration**: Use `.interactive_config.cfg` for shared settings
- **Logging**: Provide clear progress and error messages
- **Cross-platform**: Support multiple OS families where applicable