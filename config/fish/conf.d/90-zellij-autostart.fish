# Managed by bag2000/shell — https://github.com/bag2000/shell
# This file is sourced automatically by fish on every start.
# Re-run install.sh to update it. Disable with install.sh --no-zellij-autostart.

# Open every new terminal inside zellij. Nested sessions (ZELLIJ is set) and
# non-terminal shells are skipped; set ZELLIJ_AUTO_START=0 to keep a plain
# shell for the current terminal.
if status is-interactive
    if type -q zellij; and not set -q ZELLIJ; and isatty stdin; and isatty stdout
        if not contains -- "$ZELLIJ_AUTO_START" 0 false; and test "$TERM" != dumb
            exec zellij
        end
    end
end
