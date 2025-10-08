# Common helpers for OpenProject installer

This folder contains shared helper scripts used by the interactive installer
and OS-specific installation utilities.

Files
- `common.sh` - Core non-UI helpers (compose detection, service helpers) and
  common UI primitives (color detection and basic helpers like `warn`,
  `note`, `section`, and `format_default`). Source this file from any script
  that needs these capabilities.
- `common_ui.sh` - Convenience UI helpers that build on `common.sh` and
  provide additional formatting helpers like `subsection` and `numbered_list`.

Usage

From any script under `scripts/installation_scripts` or
`scripts/installation_scripts/installation_utilities`, source the UI helpers
like this (using `SCRIPT_DIR` computed via `BASH_SOURCE`):

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/../common/common_ui.sh" ]; then
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/../common/common_ui.sh"
fi
```

Notes
- Avoid duplicating color/UI logic in multiple files. Keep helpers in
  `common.sh` and `common_ui.sh` to ensure consistent output across the
  installer and utilities.
