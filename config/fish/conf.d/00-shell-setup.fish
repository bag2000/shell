# Managed by bag2000/shell — https://github.com/bag2000/shell
# This file is sourced automatically by fish on every start.
# Re-run install.sh to update it.

# User-local binaries (starship, cargo, uv, pipx, ...).
if not contains -- $HOME/.local/bin $PATH
    set -gx PATH $HOME/.local/bin $PATH
end

if status is-interactive
    # Starship prompt.
    if type -q starship
        starship init fish | source
    end

    # Atuin shell history (Ctrl-R and up-arrow search).
    if type -q atuin
        atuin init fish | source
    end

    # zoxide (smarter cd): z <dir>, zi for interactive selection.
    if type -q zoxide
        zoxide init fish | source
        abbr --add --global cd z
    end

    # lsd as a drop-in ls replacement.
    if type -q lsd
        abbr --add --global ls lsd
        abbr --add --global ll 'lsd -lah'
        abbr --add --global la 'lsd -A'
    else
        abbr --add --global ll 'ls -lah'
        abbr --add --global la 'ls -A'
    end

    # No greeting.
    set -g fish_greeting

    # Small quality-of-life abbreviations.
    abbr --add --global g git
    abbr --add --global gs 'git status'
    abbr --add --global gd 'git diff'
    abbr --add --global gl 'git log --oneline --graph --decorate -20'

    # Open every new terminal inside zellij. Nested sessions (ZELLIJ is set) and
    # non-terminal shells are skipped; set ZELLIJ_AUTO_START=0 to keep a plain
    # shell.
    if type -q zellij; and not set -q ZELLIJ; and isatty stdin; and isatty stdout
        if not contains -- "$ZELLIJ_AUTO_START" 0 false; and test "$TERM" != dumb
            exec zellij
        end
    end
end
