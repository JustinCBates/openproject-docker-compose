# Common helpers for the installer

This folder contains shared helper scripts used by the interactive installer
and the installation utilities.

Files present

- `common.sh` - Core helpers used across scripts (compose/docker helpers,
  color detection, and small UI building blocks such as `warn`, `note`,
  `section`, and `format_default`).

- `common_ui.sh` - Higher-level UI helpers built on `common.sh` (for example
  `subsection`, `numbered_list`, and `numbered_list_prompt`).

How to source

From a script in `scripts/installation_scripts` or one of the utility
subdirectories, compute the script directory and source the UI helpers like
this:

```bash
# where this script lives
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# source the shared UI helpers
if [ -f "$SCRIPT_DIR/../common/common_ui.sh" ]; then
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/../common/common_ui.sh"
fi
```

Guidelines

- Keep UI and color logic in this folder so all installer scripts display
  consistent output.
- Avoid copying these helpers into other directories; update the central
  files here and then source them.
