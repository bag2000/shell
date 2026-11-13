# Managed by bag2000/shell — https://github.com/bag2000/shell
# This file is sourced automatically by fish on every start.
# Re-run install.sh to update it.

# Bare `zellij` always attaches to the "main" session, creating it if needed.
# Subcommands and options are passed through unchanged.
if status is-interactive
    function zellij --wraps=zellij --description 'zellij (attach to the main session)'
        if test (count $argv) -eq 0
            if set -q ZELLIJ
                command zellij
            else
                command zellij attach --create main
            end
        else
            command zellij $argv
        end
    end
end
