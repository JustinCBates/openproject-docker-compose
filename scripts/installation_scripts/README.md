# Installation scripts

This directory contains the interactive installer, the deployment orchestrator,
and a set of installation utilities. The content below describes the files
actually present in this folder.

Files in this directory

- `interactive_config.sh` - Interactive configuration script. Guides a user
	through collecting configuration values (hostname, HTTPS choice, tag, domain,
	subdomain, environment type, OS family, storage selection, and proxy options)
	and writes them to `interactive_config.cfg` in this directory.

- `interactive_config.cfg` - (Generated) configuration file created by
	`interactive_config.sh`. It stores OPENPROJECT_* environment variables that are
	used by utility scripts and deployment.

- `deploy.sh` - Deployment orchestrator. Reads values from
	`interactive_config.cfg` and runs the installation utilities and stack build
	steps. (Run only after verifying `interactive_config.cfg`.)

- `installation_utilities/` - A collection of modular utility scripts used by
	the deployer. OS-specific installers live under this directory.

- `common/` - Shared helper scripts (see `common/README.md`). These are
	sourced by the interactive script and utilities to provide UI helpers and
	other shared functionality.

Quick usage

1. Run the interactive configuration to create or update the configuration:

```bash
./interactive_config.sh
```

2. Inspect the generated `interactive_config.cfg` and then run the deploy step:

```bash
# check the file first
cat interactive_config.cfg

# run deployment
./deploy.sh
```

Notes

- The interactive script writes `interactive_config.cfg` into this directory.
- OS-specific scripts and utilities live under `installation_utilities/` and
	should be invoked by `deploy.sh` or called directly when needed.
- Keep UI and helper code in the `common/` folder so all scripts use the same
	helpers and formatting.