#!/usr/bin/env bash
#
# Smoke-test install.sh in a clean Ubuntu container.
#
# Usage:
#   tests/ubuntu.sh
#   STARSHIP_VERSION=1.26.0 tests/ubuntu.sh
#   ATUIN_VERSION=18.24.0 tests/ubuntu.sh
#   ZOXIDE_VERSION=0.10.0 tests/ubuntu.sh
#   FZF_VERSION=0.75.0 tests/ubuntu.sh
#   LSD_VERSION=1.2.0 tests/ubuntu.sh
#   ZELLIJ_VERSION=0.46.0 tests/ubuntu.sh
#   FISH_VERSION=4.9.3 tests/ubuntu.sh
#   IMAGE=ubuntu:22.04 tests/ubuntu.sh

set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
IMAGE=${IMAGE:-ubuntu:24.04}
STARSHIP_VERSION=${STARSHIP_VERSION:-latest}
ATUIN_VERSION=${ATUIN_VERSION:-latest}
ZOXIDE_VERSION=${ZOXIDE_VERSION:-latest}
FZF_VERSION=${FZF_VERSION:-latest}
LSD_VERSION=${LSD_VERSION:-latest}
ZELLIJ_VERSION=${ZELLIJ_VERSION:-latest}
FISH_VERSION=${FISH_VERSION:-latest}

echo "Testing $IMAGE (fish $FISH_VERSION, starship $STARSHIP_VERSION, atuin $ATUIN_VERSION, zoxide $ZOXIDE_VERSION, fzf $FZF_VERSION, zellij $ZELLIJ_VERSION)"

docker run --rm -i \
    -e "STARSHIP_VERSION=$STARSHIP_VERSION" \
    -e "ATUIN_VERSION=$ATUIN_VERSION" \
    -e "ZOXIDE_VERSION=$ZOXIDE_VERSION" \
    -e "FZF_VERSION=$FZF_VERSION" \
    -e "LSD_VERSION=$LSD_VERSION" \
    -e "ZELLIJ_VERSION=$ZELLIJ_VERSION" \
    -e "FISH_VERSION=$FISH_VERSION" \
    -v "$ROOT:/src:ro" \
    "$IMAGE" \
    bash -s <<'EOS'
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive TERM=xterm-256color

apt-get update -qq
apt-get install -y -qq sudo curl ca-certificates

useradd -m -s /bin/bash tester
echo 'tester ALL=(ALL) NOPASSWD:ALL' >/etc/sudoers.d/tester
chmod 440 /etc/sudoers.d/tester

install_cmd="sudo env FISH_VERSION=$FISH_VERSION STARSHIP_VERSION=$STARSHIP_VERSION ATUIN_VERSION=$ATUIN_VERSION ZOXIDE_VERSION=$ZOXIDE_VERSION FZF_VERSION=$FZF_VERSION LSD_VERSION=$LSD_VERSION ZELLIJ_VERSION=$ZELLIJ_VERSION bash /src/install.sh --no-proxy"

echo "=== fresh install (sudo, local configs) ==="
su - tester -c "$install_cmd"

echo "=== checks ==="
test "$(getent passwd tester | awk -F: '{print $7}')" = "/usr/local/bin/fish"
test -x /home/tester/.local/bin/starship
test -x /home/tester/.local/bin/atuin
test -x /home/tester/.local/bin/zoxide
test -x /home/tester/.local/bin/fzf
test -x /home/tester/.local/bin/lsd
test -x /home/tester/.local/bin/zellij
if [[ "$FZF_VERSION" != "latest" ]]; then
    test "$(/home/tester/.local/bin/fzf --version | awk '{print $1}')" = "${FZF_VERSION#v}"
fi
if [[ "$LSD_VERSION" != "latest" ]]; then
    test "$(/home/tester/.local/bin/lsd --version | awk '{print $2}')" = "${LSD_VERSION#v}"
fi
if [[ "$ZELLIJ_VERSION" != "latest" ]]; then
    test "$(/home/tester/.local/bin/zellij --version | awk '{print $2}')" = "${ZELLIJ_VERSION#v}"
fi
test -f /home/tester/.local/share/fonts/JetBrainsMonoNerdFontMono/JetBrainsMonoNerdFontMono-Regular.ttf
test -f /home/tester/.local/share/fonts/JetBrainsMonoNerdFontMono/JetBrainsMonoNerdFontMono-BoldItalic.ttf
test "$(stat -c %U /home/tester/.local/share/fonts/JetBrainsMonoNerdFontMono)" = "tester"
test -f /home/tester/.config/fish/conf.d/00-shell-setup.fish
test -f /home/tester/.config/starship.toml
test -f /home/tester/.config/atuin/config.toml
test -f /home/tester/.config/zellij/config.kdl
test -f /home/tester/.config/zellij/themes/nord-gap.kdl
grep -q 'pane_frame_style "full"' /home/tester/.config/zellij/config.kdl
grep -q 'frame_unselected' /home/tester/.config/zellij/themes/nord-gap.kdl
su - tester -c 'zellij setup --check' | grep -q 'CONFIG FILE: Well defined'
grep -q 'murkl/starship-theme-arch-os' /home/tester/.config/starship.toml
test "$(stat -c %U /home/tester/.local)" = "tester"
test "$(stat -c %U /home/tester/.config/fish)" = "tester"
test "$(stat -c %U /home/tester/.config/atuin)" = "tester"
test "$(stat -c %U /home/tester/.config/zellij)" = "tester"
su - tester -c 'fish -i -c "echo INTERACTIVE_OK"' | grep -q INTERACTIVE_OK
su - tester -c 'fish -i -c "abbr --show"' | grep -q 'lsd -lah'
su - tester -c 'fish -i -c "abbr --show"' | grep -q 'lsd -A'
su - tester -c 'fish -i -c "abbr --show"' | grep -q ' cd z$'
su - tester -c 'fish -i -c "abbr --show"' | grep -q ' ls lsd$'
su - tester -c 'fish -c "starship init fish | source; echo STARSHIP_INIT_OK"' \
    | grep -q STARSHIP_INIT_OK
su - tester -c 'fish -c "atuin init fish | source; echo ATUIN_INIT_OK"' \
    | grep -q ATUIN_INIT_OK
su - tester -c 'fish -c "zoxide init fish | source; echo ZOXIDE_INIT_OK"' \
    | grep -q ZOXIDE_INIT_OK

# zellij autostart: only in a real terminal, opt-out via ZELLIJ_AUTO_START=0.
grep -q 'exec zellij' /home/tester/.config/fish/conf.d/00-shell-setup.fish
mkdir -p /tmp/fakebin
printf '#!/bin/sh\necho ZELLIJ_AUTOSTART_OK\n' >/tmp/fakebin/zellij
chmod 755 /tmp/fakebin/zellij
su - tester -c 'PATH=/tmp/fakebin:/home/tester/.local/bin:$PATH fish -i -c "echo NO_TTY_OK"' \
    | grep -q NO_TTY_OK
if command -v script >/dev/null 2>&1; then
    cat >/tmp/zellij-autostart.sh <<'EOF'
#!/bin/bash
export PATH=/tmp/fakebin:$HOME/.local/bin:$PATH
script -qec 'fish -i -c "echo SHELL_ALIVE"' /dev/null </dev/null
EOF
    chmod 755 /tmp/zellij-autostart.sh
    su - tester -c /tmp/zellij-autostart.sh | grep -q ZELLIJ_AUTOSTART_OK

    cat >/tmp/zellij-optout.sh <<'EOF'
#!/bin/bash
export PATH=/tmp/fakebin:$HOME/.local/bin:$PATH
export ZELLIJ_AUTO_START=0
script -qec 'fish -i -c "echo SHELL_ALIVE"' /dev/null </dev/null
EOF
    chmod 755 /tmp/zellij-optout.sh
    su - tester -c /tmp/zellij-optout.sh | grep -q SHELL_ALIVE
else
    echo "warning: script not found; skipping zellij autostart PTY test" >&2
fi
echo "checks passed"

echo "=== idempotent re-run (local configs) ==="
su - tester -c "sudo env FISH_VERSION=$FISH_VERSION STARSHIP_VERSION=$STARSHIP_VERSION ATUIN_VERSION=$ATUIN_VERSION ZOXIDE_VERSION=$ZOXIDE_VERSION FZF_VERSION=$FZF_VERSION LSD_VERSION=$LSD_VERSION ZELLIJ_VERSION=$ZELLIJ_VERSION bash /src/install.sh --no-proxy" \
    | tee /tmp/rerun.log
grep -q 'already up to date' /tmp/rerun.log
grep -q 'starship is up to date' /tmp/rerun.log
grep -q 'fish is up to date' /tmp/rerun.log
grep -q 'atuin is up to date' /tmp/rerun.log
grep -q 'zoxide is up to date' /tmp/rerun.log
grep -q 'fzf is up to date' /tmp/rerun.log
grep -q 'lsd is up to date' /tmp/rerun.log
grep -q 'zellij is up to date' /tmp/rerun.log
grep -q 'already up to date: /home/tester/.config/zellij/config.kdl' /tmp/rerun.log
grep -q 'fonts are up to date' /tmp/rerun.log
grep -q 'login shell is already fish' /tmp/rerun.log
echo "idempotency passed"

echo "=== check and update ==="
su - tester -c "$install_cmd --check" | tee /tmp/check.log
grep -q 'all tools are up to date' /tmp/check.log
su - tester -c "$install_cmd --update" | tee /tmp/update.log
grep -q 'fzf is up to date' /tmp/update.log
grep -q 'lsd is up to date' /tmp/update.log
grep -q 'zellij is up to date' /tmp/update.log
grep -q 'Update complete' /tmp/update.log
echo "check/update passed"

echo "=== proxy settings from .env ==="
cat >/tmp/proxy.env <<'EOF'
PROXY=192.0.2.10:8080
HTTPS_PROXY=http://user:placeholder@192.0.2.10:8080
NO_PROXY=localhost,127.0.0.1
PATH=/should/not/be/imported
EOF
chmod 644 /tmp/proxy.env
su - tester -c 'bash /src/install.sh --dry-run --no-chsh --env-file /tmp/proxy.env' \
    >/tmp/proxy-plan.log
grep -q 'proxy        : http://\*\*\*@192.0.2.10:8080' /tmp/proxy-plan.log
grep -q 'no proxy for : localhost,127.0.0.1' /tmp/proxy-plan.log
grep -q 'fish         : already installed' /tmp/proxy-plan.log
if grep -q 'user:placeholder' /tmp/proxy-plan.log; then
    echo "proxy credentials leaked into output" >&2
    exit 1
fi

mkdir -p /tmp/envdir
printf 'PROXY=192.0.2.10:8080\n' >/tmp/envdir/.env
chmod 644 /tmp/envdir/.env
su - tester -c 'cd /tmp/envdir && bash /src/install.sh --dry-run --no-chsh' \
    >/tmp/envdir-plan.log
grep -q 'proxy        : http://192.0.2.10:8080' /tmp/envdir-plan.log
su - tester -c 'cd /tmp/envdir && bash /src/install.sh --dry-run --no-chsh --no-proxy' \
    >/tmp/envdir-noproxy.log
grep -q 'proxy        : none' /tmp/envdir-noproxy.log
echo "proxy settings passed"

echo "=== dry run ==="
su - tester -c 'bash /src/install.sh --dry-run --no-chsh --no-proxy' | grep -q 'Installation plan'
su - tester -c 'bash /src/install.sh --dry-run --no-chsh --no-proxy --no-atuin' \
    >/tmp/noatuin.log
grep -q 'atuin        : skipped' /tmp/noatuin.log
if grep -q 'atuin/config.toml' /tmp/noatuin.log; then
    echo "atuin config should be skipped with --no-atuin" >&2
    exit 1
fi
su - tester -c 'bash /src/install.sh --dry-run --no-chsh --no-proxy --no-zoxide' \
    >/tmp/nozoxide.log
grep -q 'zoxide       : skipped' /tmp/nozoxide.log
su - tester -c 'bash /src/install.sh --dry-run --no-chsh --no-proxy --no-lsd' \
    >/tmp/nolsd.log
grep -q 'lsd          : skipped' /tmp/nolsd.log
su - tester -c 'bash /src/install.sh --dry-run --no-chsh --no-proxy --no-zellij' \
    >/tmp/nozellij.log
grep -q 'zellij       : skipped' /tmp/nozellij.log
if grep -q 'zellij/config.kdl' /tmp/nozellij.log; then
    echo "zellij config should be skipped with --no-zellij" >&2
    exit 1
fi
su - tester -c 'bash /src/install.sh --dry-run --no-chsh --no-proxy --no-font' \
    >/tmp/nofont.log
grep -q 'font         : skipped' /tmp/nofont.log
echo "dry run passed"

echo "ALL TESTS PASSED"
EOS
