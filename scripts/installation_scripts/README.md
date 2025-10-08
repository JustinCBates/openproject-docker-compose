# Installation scripts

This directory contains the interactive installer, the deployment orchestrator,
and a set of installation utilities. The content below describes the files
actually present in this folder.

Files in this directory

- `interactive_config.sh` - Interactive configuration script. Guides a user

- `interactive_config.sh` - Interactive configuration script.
		- Purpose: Guides a user through collecting deployment configuration values
			(OpenProject repo tag, hostname, HTTPS enablement, proxy redirect choice,
			domain/subdomain, environment type, OS family, DB storage and admin
			password, Git user/email, and other settings). It persists choices to
			`interactive_config.cfg` in this directory for use by the deployment
			orchestrator and utility scripts.
		- Important flags:
				- `--no-deploy`  — When provided, the script will save configuration but
					will not run the full `deploy.sh` at the end. Useful for automated
					UI tests and demos.
				- `-h`/`--help`  — Show brief usage information.
		- Developer notes:
				- The script uses shared UI helpers from `common/` which provide
					`section()`, `subsection()`, `supersection()`, color helpers, and
					prompt helpers. Sections and subsections are used to group related
					configuration prompts; `supersection()` is a visually stronger
					heading used for the top-level Interactive Configuration container.
				- Output coloring is automatic when stdout is a TTY and the terminal
					reports color support. You can force color by exporting
					`INSTALLER_FORCE_COLOR=1` into the environment before running the
					script (useful for capturing colorized transcripts).
		- Non-interactive / test-friendly usage:
				- Capture a safe, reproducible transcript by running the script with
					`--no-deploy` under a pty recorder (the repository includes
					`scripts/installation_scripts/tests/generate_interactive_transcript.sh`
					to automate this). The generated transcript file preserves ANSI
					escapes and can be replayed to a terminal using the provided
					`play_interactive_transcript.sh` helper (also located under
					`scripts/installation_scripts/tests/`).
				- For automated tests you can pipe default answers into the script or
					use the `--no-deploy` flag to avoid performing a full deployment.

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