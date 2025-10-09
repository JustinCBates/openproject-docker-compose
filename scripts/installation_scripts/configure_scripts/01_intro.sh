#!/bin/bash
# Interactive intro + preview merged

run_intro() {
    interactive_body=$(cat <<'EOF'
Follow a guided prompt sequence to gather deployment settings.
Press {RESET}<Enter>{BRONZE}{DIM} to accept any default shown.
Changes are saved to {RESET}interactive_config.cfg{BRONZE}{DIM}.
EOF
)
    supersection "Interactive Configuration:" "$interactive_body"

    # The preview is shown by run_preview() prior to prompting; keep run_intro
    # focused on the interactive intro content only.
}
