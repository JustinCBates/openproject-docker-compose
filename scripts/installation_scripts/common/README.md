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

Helpers added recently
----------------------

The following helpers were moved into `common_ui.sh` to centralize prompts
and validation logic used by the interactive installer:

- `prompt_with_default(prompt, default, varname)`
  - Prompts the user and stores the result in the caller variable named by
    `varname`.

- `validate_yn(prompt, default)` and `validate_tf(prompt, default)`
  - Prompt for yes/no and true/false answers respectively. Return status 0
    for affirmative, 1 for negative.

Test runner
-----------

`test_prompt_helpers.sh` is a non-interactive unit-style test script that
verifies basic behavior of the prompt helpers. It is intended to be fast and
deterministic by mocking input via file descriptors when possible.

Full function reference
-----------------------

This section lists the primary functions available across the files in this
directory. All functions are intended to be sourced by installer scripts so
they run in the caller's shell environment.

From `common.sh` (core helpers):

- detect_compose_cmd()
  - Detects whether `docker-compose` or the `docker compose` plugin is
    available. Prints the command string on success or returns non-zero on
    failure.

- get_compose_services(<project_root>)
  - Lists services declared by compose in the specified project root. Prints
    one service name per line.

- service_has_local_dockerfile(<service>)
  - Returns 0 if the service directory contains a `Dockerfile`.

- service_has_compose_build(<project_root> <service>)
  - Returns 0 if the compose configuration for the service includes a
    `build:` block.

- decide_service_action(<project_root> <service>)
  - Prints `build|reason` or `pull|reason` indicating whether the service
    should be built locally or pulled from a registry.

Color + UI primitives in `common.sh`:

- warn(msg)
  - Prints a red WARNING prefixed message.
- caution(msg)
  - Prints a yellow caution message.
- note(msg)
  - Prints a bronze note.
- section(title)
  - Prints a bronze section header with an underline.
- format_default(value)
  - Returns a colorized (green) representation of a default value when colors
    are enabled.

From `common_ui.sh` (high-level UI helpers):

- subsection(title)
  - Prints a single-line bronze subsection header.

- prompt_with_default(prompt, default, varname)
  - Prompt the user, show a colored default when appropriate, and assign the
    result to `varname` in the caller via `eval`.

- validate_yn(prompt, default)
  - Prompt for a yes/no answer. Returns 0 on yes, 1 on no. When `default` is
    provided it will be used if the user presses Enter.

- validate_tf(prompt, default)
  - Prompt for true/false answers, same contract as `validate_yn`.

- numbered_list(default, ...items)
  - Print a numbered list of items. `default` is a numeric index that will be
    highlighted.

- numbered_list_prompt(default_arg, out_var, out_idx_var?, ...items)
  - Present a numbered list and prompt the user. `default_arg` may be a
    numeric index or a token (the short token at the start of each item). The
    function maps a token to an index automatically. `out_var` receives the
    token string of the selected item. If `out_idx_var` is provided it will be
    set to the numeric index (1-based).

From `common_os.sh` (OS detection):

- detect_os_family()
  - Detects common Linux distribution families using `/etc/os-release` and
    other release files; prints one of: `debian`, `redhat`, `suse`, `arch`,
    `slackware`, or `unknown`.

Test helper
-----------

The `test_prompt_helpers.sh` script runs a few quick assertions to ensure the
prompt helpers behave correctly in non-interactive environments. It is safe
to run locally and in CI. It lives in this folder and is executable.

Source and usage example
------------------------

From any installer script under `scripts/installation_scripts/` or its
subdirectories, source the helpers like this:

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/../common/common_ui.sh" ]; then
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/../common/common_ui.sh"
fi
```

Then call the helpers directly, for example:

```bash
prompt_with_default "Domain name" "$current_domain" domain_name
if validate_tf "Redirect HTTP to HTTPS?" "true"; then
  PROXY_HTTPS_REDIRECT=true
else
  PROXY_HTTPS_REDIRECT=false
fi
```

If you add or change helpers, update this README and the unit test so later
refactors have quick coverage.
