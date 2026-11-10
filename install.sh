#!/usr/bin/env bash
#
# Install fish, starship, atuin, zoxide, lsd and a Nerd Font with a ready-to-use
# configuration.
#
# Usage:
#   git clone https://github.com/bag2000/shell.git
#   cd shell
#   cp .env.example .env   # optional: proxy settings
#   bash install.sh
#
# Run as a normal user. sudo is used only for package installation and chsh.
# See --help for all options.

set -Eeuo pipefail

SCRIPT_VERSION="1.5.0"
STARSHIP_VERSION="${STARSHIP_VERSION:-latest}"
ATUIN_VERSION="${ATUIN_VERSION:-latest}"
ZOXIDE_VERSION="${ZOXIDE_VERSION:-latest}"
LSD_VERSION="${LSD_VERSION:-latest}"
FISH_VERSION="${FISH_VERSION:-latest}"

# Options.
NO_CHSH=0
NO_CONFIG=0
NO_STARSHIP=0
NO_ATUIN=0
NO_ZOXIDE=0
NO_LSD=0
NO_FONT=0
FORCE=0
DRY_RUN=0
CHECK=0
UPDATE=0
CONFIG_DIR=""
FONT_DIR=""

# JetBrainsMono Nerd Font is vendored in the repository under fonts/.
FONT_BASE="JetBrainsMonoNerdFontMono"
FONT_STYLES=(
    Thin ThinItalic
    ExtraLight ExtraLightItalic
    Light LightItalic
    Regular Italic
    Medium MediumItalic
    SemiBold SemiBoldItalic
    Bold BoldItalic
    ExtraBold ExtraBoldItalic
)
CLI_PROXY=""
CLI_ENV_FILE=""
DISABLE_PROXY=0

# Proxy state, filled by setup_proxy().
HTTP_PROXY="${HTTP_PROXY:-}"
HTTPS_PROXY="${HTTPS_PROXY:-}"
ALL_PROXY="${ALL_PROXY:-}"
NO_PROXY="${NO_PROXY:-}"
EFFECTIVE_PROXY=""
PKG_PROXY_ENV=()
APT_PROXY_OPTS=()
DNF_PROXY_OPTS=()

# Filled in by detection.
TARGET_USER=""
TARGET_HOME=""
TARGET_GROUP=""
CONFIG_HOME=""
DATA_HOME=""
FISH_BIN=""
DISTRO_ID=""
DISTRO_LIKE=""
PM=""
SUDO=()
TMP_DIRS=()

if [[ -t 1 ]]; then
    BOLD=$'\033[1m'
    BLUE=$'\033[34m'
    GREEN=$'\033[32m'
    YELLOW=$'\033[33m'
    RED=$'\033[31m'
    RESET=$'\033[0m'
else
    BOLD=""
    BLUE=""
    GREEN=""
    YELLOW=""
    RED=""
    RESET=""
fi

info() { printf '%s==>%s %s\n' "$BLUE$BOLD" "$RESET" "$*"; }
ok()   { printf '%s  ✓%s %s\n' "$GREEN" "$RESET" "$*"; }
warn() { printf '%swarning:%s %s\n' "$YELLOW" "$RESET" "$*" >&2; }
die()  { printf '%serror:%s %s\n' "$RED" "$RESET" "$*" >&2; exit 1; }

cleanup() {
    local dir
    for dir in "${TMP_DIRS[@]+"${TMP_DIRS[@]}"}"; do
        [[ -d "$dir" ]] && rm -rf "$dir"
    done
}

on_error() {
    local line=$1 code=$2
    set +e
    printf '%serror:%s command failed with exit code %s (line %s)\n' \
        "$RED" "$RESET" "$code" "$line" >&2
}

trap cleanup EXIT
trap 'on_error "$LINENO" "$?"' ERR

usage() {
    cat <<EOF
${BOLD}fish + starship + atuin + zoxide + lsd + font installer${RESET} v${SCRIPT_VERSION}

Usage:
  git clone https://github.com/bag2000/shell.git
  cd shell
  cp .env.example .env     # optional: proxy settings
  bash install.sh [options]

Options:
  --no-chsh              Do not change the login shell to fish.
  --no-config            Do not install fish/starship/atuin configuration files.
  --no-starship          Do not install starship.
  --no-atuin             Do not install atuin.
  --no-zoxide            Do not install zoxide.
  --no-lsd               Do not install lsd.
  --no-font              Do not install JetBrainsMono Nerd Font.
  --force                Reinstall starship, atuin, zoxide, lsd and fonts even if present.
  --dry-run              Detect the system and print the plan, change nothing.
  --check                Show installed and latest versions, change nothing.
                         Exit: 0 up to date, 1 updates available, 2 check failed.
  --update               Update already installed tools only; do not install
                         missing components, configs, or change the login shell.
  --config-dir DIR       Use configs from DIR (must contain fish/, starship.toml, atuin.toml).
  --font-dir DIR         Install the font to DIR.
  --starship-version V   Install a specific starship version (default: latest).
  --atuin-version V      Install a specific atuin version (default: latest).
  --zoxide-version V     Install a specific zoxide version (default: latest).
  --lsd-version V        Install a specific lsd version (default: latest).
  --fish-version V       Install a specific fish version (default: latest).
  --proxy URL            Use this HTTP(S)/SOCKS proxy for all downloads.
  --no-proxy             Ignore proxy settings from the environment and .env.
  --env-file FILE        Load proxy settings from FILE (default: ./.env,
                         then the .env next to install.sh).
  -h, --help             Show this help.
  --version              Show script version.

Environment:
  STARSHIP_VERSION   Same as --starship-version.
  ATUIN_VERSION      Same as --atuin-version.
  ZOXIDE_VERSION     Same as --zoxide-version.
  LSD_VERSION        Same as --lsd-version.
  FISH_VERSION       Same as --fish-version.
  ENV_FILE           Path to an env file with proxy settings.

Supported .env keys:
  PROXY, HTTP_PROXY, HTTPS_PROXY, ALL_PROXY, NO_PROXY
  (and their lowercase forms). Only these keys are imported.

Configs are installed to:
  \$XDG_CONFIG_HOME/fish/conf.d/00-shell-setup.fish
  \$XDG_CONFIG_HOME/starship.toml
  \$XDG_CONFIG_HOME/atuin/config.toml (unless --no-atuin)

Fonts are installed to:
  \$XDG_DATA_HOME/fonts/JetBrainsMonoNerdFontMono
  (default: ~/.local/share/fonts/JetBrainsMonoNerdFontMono)

Existing files are backed up with a .bak.TIMESTAMP suffix.
EOF
}

parse_args() {
    while (($#)); do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            --version)
                printf '%s\n' "$SCRIPT_VERSION"
                exit 0
                ;;
            --no-chsh) NO_CHSH=1 ;;
            --no-config) NO_CONFIG=1 ;;
            --no-starship) NO_STARSHIP=1 ;;
            --no-atuin) NO_ATUIN=1 ;;
            --no-zoxide) NO_ZOXIDE=1 ;;
            --no-lsd) NO_LSD=1 ;;
            --no-font) NO_FONT=1 ;;
            --force) FORCE=1 ;;
            --dry-run) DRY_RUN=1 ;;
            --check) CHECK=1 ;;
            --update) UPDATE=1 ;;
            --proxy)
                [[ $# -ge 2 ]] || die "--proxy requires a URL"
                CLI_PROXY=$2
                DISABLE_PROXY=0
                shift
                ;;
            --no-proxy)
                DISABLE_PROXY=1
                CLI_PROXY=""
                ;;
            --env-file)
                [[ $# -ge 2 ]] || die "--env-file requires a path"
                CLI_ENV_FILE=$2
                shift
                ;;
            --config-dir)
                [[ $# -ge 2 ]] || die "--config-dir requires a directory"
                CONFIG_DIR=$2
                shift
                ;;
            --font-dir)
                [[ $# -ge 2 ]] || die "--font-dir requires a directory"
                FONT_DIR=$2
                shift
                ;;
            --starship-version)
                [[ $# -ge 2 ]] || die "--starship-version requires a version"
                STARSHIP_VERSION=$2
                shift
                ;;
            --atuin-version)
                [[ $# -ge 2 ]] || die "--atuin-version requires a version"
                ATUIN_VERSION=$2
                shift
                ;;
            --zoxide-version)
                [[ $# -ge 2 ]] || die "--zoxide-version requires a version"
                ZOXIDE_VERSION=$2
                shift
                ;;
            --lsd-version)
                [[ $# -ge 2 ]] || die "--lsd-version requires a version"
                LSD_VERSION=$2
                shift
                ;;
            --fish-version)
                [[ $# -ge 2 ]] || die "--fish-version requires a version"
                FISH_VERSION=$2
                shift
                ;;
            --)
                shift
                break
                ;;
            *)
                die "unknown option: $1 (try --help)"
                ;;
        esac
        shift
    done

    if ((CHECK && UPDATE)); then
        die "--check and --update cannot be used together"
    fi
}

resolve_env_file() {
    if [[ -n "$CLI_ENV_FILE" ]]; then
        [[ -f "$CLI_ENV_FILE" ]] || die "env file not found: $CLI_ENV_FILE"
        printf '%s' "$CLI_ENV_FILE"
        return 0
    fi

    if [[ -n "${ENV_FILE:-}" ]]; then
        [[ -f "$ENV_FILE" ]] || die "env file not found: $ENV_FILE"
        printf '%s' "$ENV_FILE"
        return 0
    fi

    if [[ -f "$PWD/.env" ]]; then
        printf '%s' "$PWD/.env"
        return 0
    fi

    local script_path="${BASH_SOURCE[0]:-}" script_dir
    if [[ -n "$script_path" && -f "$script_path" ]]; then
        script_dir=$(cd -- "$(dirname -- "$script_path")" && pwd)
        if [[ -f "$script_dir/.env" ]]; then
            printf '%s' "$script_dir/.env"
            return 0
        fi
    fi

    return 1
}

load_env_file() {
    local file=$1
    local line key value

    [[ -f "$file" ]] || die "env file not found: $file"
    info "Loading proxy settings from $file"

    while IFS= read -r line || [[ -n "$line" ]]; do
        line=${line%$'\r'}
        line=${line#"${line%%[![:space:]]*}"}
        [[ "$line" =~ ^[[:space:]]*(#|$) ]] && continue

        # Accept both "KEY=value" and "export KEY=value".
        if [[ "$line" == export[[:space:]]* ]]; then
            line=${line#export}
            line=${line#"${line%%[![:space:]]*}"}
        fi

        [[ "$line" == *=* ]] || continue

        key=${line%%=*}
        value=${line#*=}
        key=${key#"${key%%[![:space:]]*}"}
        key=${key%"${key##*[![:space:]]}"}

        case "$key" in
            PROXY|HTTP_PROXY|HTTPS_PROXY|ALL_PROXY|NO_PROXY|http_proxy|https_proxy|all_proxy|no_proxy)
                ;;
            *)
                # Never import unrelated variables (PATH, HOME, ...).
                continue
                ;;
        esac

        if [[ "$value" == \"*\" && "$value" == *\" ]] \
            || [[ "$value" == \'*\' && "$value" == *\' ]]; then
            value=${value:1:${#value}-2}
        else
            value=${value#"${value%%[![:space:]]*}"}
            value=${value%"${value##*[![:space:]]}"}
        fi

        export "$key=$value"
    done < "$file"
}

normalize_proxy() {
    local value=$1
    [[ -z "$value" ]] && return 0
    if [[ "$value" != *"://"* ]]; then
        value="http://$value"
    fi
    printf '%s' "$value"
}

redact_proxy() {
    local value=$1
    if [[ "$value" =~ ^([A-Za-z][A-Za-z0-9+.-]*://)[^/@]+@(.+)$ ]]; then
        printf '%s***@%s' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
    else
        printf '%s' "$value"
    fi
}

setup_proxy() {
    if ((DISABLE_PROXY)); then
        unset HTTP_PROXY HTTPS_PROXY ALL_PROXY NO_PROXY \
            http_proxy https_proxy all_proxy no_proxy PROXY
        EFFECTIVE_PROXY=""
        PKG_PROXY_ENV=()
        APT_PROXY_OPTS=()
        DNF_PROXY_OPTS=()
        return 0
    fi

    local fallback=${PROXY:-}

    if [[ -n "$CLI_PROXY" ]]; then
        HTTP_PROXY=$CLI_PROXY
        HTTPS_PROXY=$CLI_PROXY
        ALL_PROXY=$CLI_PROXY
    else
        HTTP_PROXY=${HTTP_PROXY:-${http_proxy:-$fallback}}
        HTTPS_PROXY=${HTTPS_PROXY:-${https_proxy:-$fallback}}
        ALL_PROXY=${ALL_PROXY:-${all_proxy:-$fallback}}
    fi

    # Most setups use the same proxy for HTTP and HTTPS.
    if [[ -n "$HTTP_PROXY" && -z "$HTTPS_PROXY" ]]; then
        HTTPS_PROXY=$HTTP_PROXY
    elif [[ -n "$HTTPS_PROXY" && -z "$HTTP_PROXY" ]]; then
        HTTP_PROXY=$HTTPS_PROXY
    fi

    HTTP_PROXY=$(normalize_proxy "$HTTP_PROXY")
    HTTPS_PROXY=$(normalize_proxy "$HTTPS_PROXY")
    ALL_PROXY=$(normalize_proxy "$ALL_PROXY")

    if [[ -z "$ALL_PROXY" ]]; then
        ALL_PROXY=${HTTPS_PROXY:-$HTTP_PROXY}
    fi

    if [[ -z "$HTTP_PROXY" && -z "$HTTPS_PROXY" && -z "$ALL_PROXY" ]]; then
        return 0
    fi

    export HTTP_PROXY HTTPS_PROXY ALL_PROXY
    export http_proxy=$HTTP_PROXY https_proxy=$HTTPS_PROXY all_proxy=$ALL_PROXY

    NO_PROXY=${NO_PROXY:-${no_proxy:-}}
    if [[ -n "$NO_PROXY" ]]; then
        export NO_PROXY
        export no_proxy=$NO_PROXY
    fi

    EFFECTIVE_PROXY=${HTTPS_PROXY:-${HTTP_PROXY:-$ALL_PROXY}}

    PKG_PROXY_ENV=()
    [[ -n "$HTTP_PROXY" ]] && PKG_PROXY_ENV+=("HTTP_PROXY=$HTTP_PROXY" "http_proxy=$HTTP_PROXY")
    [[ -n "$HTTPS_PROXY" ]] && PKG_PROXY_ENV+=("HTTPS_PROXY=$HTTPS_PROXY" "https_proxy=$HTTPS_PROXY")
    [[ -n "$ALL_PROXY" ]] && PKG_PROXY_ENV+=("ALL_PROXY=$ALL_PROXY" "all_proxy=$ALL_PROXY")
    if [[ -n "$NO_PROXY" ]]; then
        PKG_PROXY_ENV+=("NO_PROXY=$NO_PROXY" "no_proxy=$NO_PROXY")
    fi

    APT_PROXY_OPTS=()
    if [[ "$HTTP_PROXY" == http://* || "$HTTP_PROXY" == https://* ]]; then
        APT_PROXY_OPTS+=(-o "Acquire::http::Proxy=$HTTP_PROXY")
    fi
    if [[ "$HTTPS_PROXY" == http://* || "$HTTPS_PROXY" == https://* ]]; then
        APT_PROXY_OPTS+=(-o "Acquire::https::Proxy=$HTTPS_PROXY")
    fi

    DNF_PROXY_OPTS=()
    local dnf_proxy=${HTTPS_PROXY:-$HTTP_PROXY}
    if [[ "$dnf_proxy" == http://* || "$dnf_proxy" == https://* ]]; then
        DNF_PROXY_OPTS=(--setopt="proxy=$dnf_proxy")
    fi

    info "Using proxy: $(redact_proxy "$EFFECTIVE_PROXY")"
}

check_platform() {
    [[ "$(uname -s)" == "Linux" ]] || die "only Linux is supported right now (got: $(uname -s))"
}

detect_target_user() {
    if ((EUID == 0)); then
        if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
            TARGET_USER=$SUDO_USER
        else
            TARGET_USER="root"
        fi
    else
        TARGET_USER=$(id -un)
    fi

    TARGET_HOME=$(getent passwd "$TARGET_USER" 2>/dev/null | awk -F: '{print $6}')
    TARGET_GROUP=$(id -gn "$TARGET_USER")
    [[ -n "$TARGET_HOME" && -d "$TARGET_HOME" ]] \
        || die "could not determine home directory for user '$TARGET_USER'"

    CONFIG_HOME="${XDG_CONFIG_HOME:-$TARGET_HOME/.config}"
    DATA_HOME="${XDG_DATA_HOME:-$TARGET_HOME/.local/share}"
}

detect_distro() {
    if [[ -r /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        DISTRO_ID=${ID:-unknown}
        DISTRO_LIKE=${ID_LIKE:-}
    else
        die "cannot detect the distribution: /etc/os-release is missing"
    fi

    local ids=" $DISTRO_ID $DISTRO_LIKE "
    case "$ids" in
        *" ubuntu "*|*" debian "*|*" linuxmint "*|*" pop "*)
            PM="apt"
            ;;
        *" fedora "*|*" rhel "*)
            PM="dnf"
            ;;
        *" arch "*)
            PM="pacman"
            ;;
        *)
            die "unsupported distribution: ${PRETTY_NAME:-$DISTRO_ID}. Supported: Debian/Ubuntu, Fedora/RHEL, Arch."
            ;;
    esac

    command -v "$PM" >/dev/null 2>&1 \
        || die "package manager '$PM' was not found; is this really a ${DISTRO_ID} system?"
}

detect_sudo() {
    if ((EUID != 0)); then
        command -v sudo >/dev/null 2>&1 \
            || die "sudo is required to install packages as a non-root user"
        SUDO=(sudo)
    fi
}

run_root() {
    "${SUDO[@]}" "$@"
}

install_packages() {
    case "$PM" in
        apt)
            run_root env "${PKG_PROXY_ENV[@]}" DEBIAN_FRONTEND=noninteractive \
                apt-get "${APT_PROXY_OPTS[@]}" install -y -qq --no-install-recommends "$@"
            ;;
        dnf)
            run_root env "${PKG_PROXY_ENV[@]}" \
                dnf "${DNF_PROXY_OPTS[@]}" install -y "$@"
            ;;
        pacman)
            run_root env "${PKG_PROXY_ENV[@]}" \
                pacman -S --needed --noconfirm "$@"
            ;;
        *)
            die "internal error: unknown package manager '$PM'"
            ;;
    esac
}

refresh_package_index() {
    case "$PM" in
        apt)
            info "Updating apt package index"
            run_root env "${PKG_PROXY_ENV[@]}" DEBIAN_FRONTEND=noninteractive \
                apt-get "${APT_PROXY_OPTS[@]}" update -qq
            ;;
        dnf)
            info "Refreshing dnf metadata"
            run_root env "${PKG_PROXY_ENV[@]}" \
                dnf "${DNF_PROXY_OPTS[@]}" makecache >/dev/null
            ;;
        pacman)
            # Avoid a partial upgrade; a fresh Arch install already has a sync db.
            :
            ;;
    esac
}

install_prereqs() {
    local xz_pkg
    case "$PM" in
        apt) xz_pkg="xz-utils" ;;
        *) xz_pkg="xz" ;;
    esac

    info "Installing prerequisites (curl, CA certificates, tar, gzip, xz)"
    refresh_package_index
    install_packages ca-certificates curl tar gzip "$xz_pkg"
    command -v curl >/dev/null 2>&1 || die "curl was installed but is not in PATH"
    command -v xz >/dev/null 2>&1 || die "xz was installed but is not in PATH"
}

detect_fish_target() {
    local arch
    arch=$(uname -m | tr '[:upper:]' '[:lower:]')

    case "$arch" in
        amd64) arch="x86_64" ;;
        arm64) arch="aarch64" ;;
    esac

    if command -v getconf >/dev/null 2>&1 \
        && [[ "$(getconf LONG_BIT)" == "32" ]]; then
        return 1
    fi

    case "$arch" in
        x86_64|aarch64) printf '%s' "$arch" ;;
        *) return 1 ;;
    esac
}

resolve_fish_version() {
    if [[ -n "$FISH_VERSION" && "$FISH_VERSION" != "latest" ]]; then
        printf '%s\n' "${FISH_VERSION#v}"
        return 0
    fi
    resolve_latest_version "fish-shell/fish-shell"
}

install_fish_binary() {
    local version=$1 target=$2
    local tmp extract downloaded=0 candidate
    local asset="fish-${version}-linux-${target}.tar.xz"

    tmp=$(mktemp -d "${TMPDIR:-/tmp}/shell-fish.XXXXXX")
    TMP_DIRS+=("$tmp")
    extract="$tmp/extract"
    mkdir -p "$extract"

    info "Installing fish ${version} from GitHub (${target})"
    if download_release_asset "fish-shell/fish-shell" "$version" \
        "$asset" "$tmp/fish.tar.xz" 3 ""; then
        downloaded=1
    elif [[ "$FISH_VERSION" == "latest" ]]; then
        warn "could not download fish ${version}; trying recent releases"
        while IFS= read -r candidate; do
            [[ -z "$candidate" || "$candidate" == "$version" ]] && continue
            info "Trying fish ${candidate}"
            if download_release_asset "fish-shell/fish-shell" "$candidate" \
                "fish-${candidate}-linux-${target}.tar.xz" "$tmp/fish.tar.xz" 1 ""; then
                version=$candidate
                downloaded=1
                break
            fi
        done < <(list_recent_versions "fish-shell/fish-shell")
    fi

    if ((!downloaded)); then
        warn "failed to download fish ${version} for ${target}"
        return 1
    fi

    tar -xJf "$tmp/fish.tar.xz" -C "$extract"
    local extracted="$extract/fish"
    if [[ ! -f "$extracted" ]]; then
        extracted=$(find "$extract" -maxdepth 2 -type f -name fish | head -n1) || true
    fi
    [[ -n "$extracted" && -f "$extracted" ]] || {
        warn "the fish archive did not contain a binary"
        return 1
    }

    # Prefer a system-wide install; fall back to the user's ~/.local/bin.
    if run_root install -d -m 0755 /usr/local/bin 2>/dev/null \
        && run_root install -m 0755 "$extracted" /usr/local/bin/fish 2>/dev/null; then
        FISH_BIN="/usr/local/bin/fish"
    else
        make_dir "$TARGET_HOME/.local/bin"
        install -m 0755 "$extracted" "$TARGET_HOME/.local/bin/fish"
        if ((EUID == 0)) && [[ "$TARGET_USER" != "root" ]]; then
            chown "$TARGET_USER:$TARGET_GROUP" "$TARGET_HOME/.local/bin/fish"
        fi
        FISH_BIN="$TARGET_HOME/.local/bin/fish"
    fi

    "$FISH_BIN" --version >/dev/null 2>&1 || {
        warn "installed fish binary does not run: $FISH_BIN"
        return 1
    }
    return 0
}

install_fish() {
    local existing="" current="" desired="" target=""

    if [[ -x "/usr/local/bin/fish" ]]; then
        existing="/usr/local/bin/fish"
    elif command -v fish >/dev/null 2>&1; then
        existing=$(command -v fish)
    fi
    if [[ -n "$existing" ]]; then
        current=$("$existing" --version 2>/dev/null | awk '{print $3}' | head -n1)
    fi

    if target=$(detect_fish_target); then
        if ! desired=$(resolve_fish_version); then
            if [[ -n "$existing" ]]; then
                warn "could not check the latest fish version; keeping $existing"
                FISH_BIN=$existing
                ok "fish: $FISH_BIN ($("$FISH_BIN" --version))"
                return 0
            fi
            warn "could not check the latest fish version; falling back to the package manager"
            desired=""
        fi
    else
        warn "no standalone fish binary for $(uname -m); using the package manager"
        desired=""
    fi

    if [[ -n "$desired" && -n "$existing" ]] && ((!FORCE)); then
        if [[ "${desired#v}" == "$current" ]]; then
            FISH_BIN=$existing
            ok "fish is up to date: $existing ($current)"
            return 0
        fi
        info "Updating fish ${current:-unknown} -> ${desired}"
    fi

    if [[ -n "$desired" ]]; then
        if install_fish_binary "$desired" "$target"; then
            ok "fish: $FISH_BIN ($("$FISH_BIN" --version))"
            return 0
        fi
        if [[ -n "$existing" ]]; then
            warn "could not update fish from GitHub; keeping $existing"
            FISH_BIN=$existing
            ok "fish: $FISH_BIN ($("$FISH_BIN" --version))"
            return 0
        fi
        warn "GitHub install failed; falling back to the package manager"
    fi

    info "Installing fish from the package manager"
    install_packages fish
    FISH_BIN=$(command -v fish || true)
    [[ -n "$FISH_BIN" ]] || die "fish was installed but is not in PATH"
    ok "fish: $FISH_BIN ($("$FISH_BIN" --version))"
}

detect_starship_target() {
    local arch platform target
    arch=$(uname -m | tr '[:upper:]' '[:lower:]')

    case "$arch" in
        amd64) arch="x86_64" ;;
        arm64) arch="aarch64" ;;
        armv*) arch="arm" ;;
        i386|i486|i586|i686) arch="i686" ;;
        riscv64) arch="riscv64gc" ;;
    esac

    # Some systems report a 64-bit kernel while running 32-bit userland.
    if command -v getconf >/dev/null 2>&1; then
        if [[ "$arch" == "x86_64" && "$(getconf LONG_BIT)" == "32" ]]; then
            arch="i686"
        elif [[ "$arch" == "aarch64" && "$(getconf LONG_BIT)" == "32" ]]; then
            arch="arm"
        fi
    fi

    case "$arch" in
        x86_64|i686|aarch64|arm|riscv64gc) ;;
        *) die "unsupported CPU architecture for starship: $arch" ;;
    esac

    platform="unknown-linux-musl"
    target="${arch}-${platform}"
    if [[ "$target" == "arm-unknown-linux-musl" ]]; then
        target="arm-unknown-linux-musleabihf"
    fi
    printf '%s' "$target"
}

resolve_latest_version() {
    local repo=$1
    local version json

    if json=$(curl -fsSL --retry 2 --connect-timeout 10 --max-time 25 \
        "https://api.github.com/repos/${repo}/releases/latest" 2>/dev/null); then
        version=$(printf '%s' "$json" \
            | sed -n 's/.*"tag_name": *"v\{0,1\}\([^"]*\)".*/\1/p' \
            | head -n1)
        if [[ -n "$version" ]]; then
            printf '%s\n' "$version"
            return 0
        fi
    fi

    # GitHub API may be rate-limited; the release redirect still works.
    version=$(curl -fsSI --retry 2 --connect-timeout 10 --max-time 25 \
        "https://github.com/${repo}/releases/latest" 2>/dev/null \
        | awk 'tolower($1) == "location:" {print $2}' \
        | tr -d '\r' \
        | sed -E 's#.*/tag/v?##' \
        | head -n1)
    [[ -n "$version" ]] || return 1
    printf '%s\n' "$version"
}

resolve_starship_version() {
    if [[ -n "$STARSHIP_VERSION" && "$STARSHIP_VERSION" != "latest" ]]; then
        printf '%s\n' "${STARSHIP_VERSION#v}"
        return 0
    fi
    resolve_latest_version "starship/starship"
}

download_release_asset() {
    local repo=$1 version=$2 asset=$3 dest=$4 retries=${5:-2}
    local tag_prefix=${6-v}
    local url="https://github.com/${repo}/releases/download/${tag_prefix}${version}/${asset}"
    curl -fsSL --retry "$retries" --retry-delay 2 --connect-timeout 15 \
        --speed-time 30 --speed-limit 1024 -o "$dest" "$url"
}

list_recent_versions() {
    local repo=$1 count=${2:-8}
    curl -fsSL --retry 1 --connect-timeout 10 --max-time 25 \
        "https://api.github.com/repos/${repo}/releases?per_page=$((count * 2))" 2>/dev/null \
        | sed -n 's/.*"tag_name": *"v\{0,1\}\([^"]*\)".*/\1/p' \
        | { grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' || true; } \
        | head -n "$count"
}

install_starship() {
    if ((NO_STARSHIP)); then
        info "Skipping starship (--no-starship)"
        return 0
    fi

    local bin="$TARGET_HOME/.local/bin/starship"
    local existing="" current=""
    if [[ -x "$bin" ]]; then
        existing=$bin
    elif command -v starship >/dev/null 2>&1; then
        existing=$(command -v starship)
    fi

    local version
    if ! version=$(resolve_starship_version); then
        if [[ -n "$existing" ]]; then
            current=$("$existing" --version 2>/dev/null | awk '{print $2}' | head -n1)
            warn "could not check the latest starship version; keeping $existing ($current)"
            return 0
        fi
        die "could not determine the latest starship version; set STARSHIP_VERSION=x.y.z"
    fi

    if [[ -n "$existing" ]] && ((!FORCE)); then
        current=$("$existing" --version 2>/dev/null | awk '{print $2}' | head -n1)
        if [[ "${version#v}" == "$current" ]]; then
            ok "starship is up to date: $existing ($current)"
            return 0
        fi
        info "Updating starship ${current:-unknown} -> ${version}"
    fi

    local target tmp
    target=$(detect_starship_target)

    info "Installing starship ${version} (${target})"
    tmp=$(mktemp -d "${TMPDIR:-/tmp}/shell-starship.XXXXXX")
    TMP_DIRS+=("$tmp")

    local downloaded=0
    local candidate
    if download_release_asset "starship/starship" "$version" \
        "starship-${target}.tar.gz" "$tmp/starship.tar.gz" 3; then
        downloaded=1
    elif [[ "$STARSHIP_VERSION" == "latest" ]]; then
        warn "could not download starship ${version}; trying recent releases"
        while IFS= read -r candidate; do
            [[ -z "$candidate" || "$candidate" == "$version" ]] && continue
            info "Trying starship ${candidate}"
            if download_release_asset "starship/starship" "$candidate" \
                "starship-${target}.tar.gz" "$tmp/starship.tar.gz" 1; then
                version=$candidate
                downloaded=1
                break
            fi
        done < <(list_recent_versions "starship/starship")
    fi

    if ((!downloaded)); then
        die "failed to download starship for ${target}; set STARSHIP_VERSION=<version> or check the proxy"
    fi

    tar -xzf "$tmp/starship.tar.gz" -C "$tmp"
    [[ -f "$tmp/starship" ]] || die "the starship archive did not contain a binary"

    make_dir "$(dirname "$bin")"
    install -m 0755 "$tmp/starship" "$bin"
    if ((EUID == 0)) && [[ "$TARGET_USER" != "root" ]]; then
        chown "$TARGET_USER:$TARGET_GROUP" "$bin"
    fi

    "$bin" --version
    ok "starship installed: $bin"
}

detect_atuin_target() {
    local arch
    arch=$(uname -m | tr '[:upper:]' '[:lower:]')

    case "$arch" in
        amd64) arch="x86_64" ;;
        arm64) arch="aarch64" ;;
    esac

    if command -v getconf >/dev/null 2>&1 \
        && [[ "$(getconf LONG_BIT)" == "32" ]]; then
        return 1
    fi

    case "$arch" in
        x86_64|aarch64) ;;
        *) return 1 ;;
    esac

    printf '%s' "${arch}-unknown-linux-musl"
}

resolve_atuin_version() {
    if [[ -n "$ATUIN_VERSION" && "$ATUIN_VERSION" != "latest" ]]; then
        printf '%s\n' "${ATUIN_VERSION#v}"
        return 0
    fi
    resolve_latest_version "atuinsh/atuin"
}

install_atuin() {
    if ((NO_ATUIN)); then
        info "Skipping atuin (--no-atuin)"
        return 0
    fi

    local bin="$TARGET_HOME/.local/bin/atuin"
    local existing="" current=""
    if [[ -x "$bin" ]]; then
        existing=$bin
    elif command -v atuin >/dev/null 2>&1; then
        existing=$(command -v atuin)
    fi

    local target version
    if ! target=$(detect_atuin_target); then
        warn "atuin has no prebuilt binary for $(uname -m); skipping"
        NO_ATUIN=1
        return 0
    fi

    if ! version=$(resolve_atuin_version); then
        if [[ -n "$existing" ]]; then
            current=$("$existing" --version 2>/dev/null | awk '{print $2}' | head -n1)
            warn "could not check the latest atuin version; keeping $existing ($current)"
            return 0
        fi
        die "could not determine the latest atuin version; set ATUIN_VERSION=x.y.z"
    fi

    if [[ -n "$existing" ]] && ((!FORCE)); then
        current=$("$existing" --version 2>/dev/null | awk '{print $2}' | head -n1)
        if [[ "${version#v}" == "$current" ]]; then
            ok "atuin is up to date: $existing ($current)"
            return 0
        fi
        info "Updating atuin ${current:-unknown} -> ${version}"
    fi

    local tmp
    info "Installing atuin ${version} (${target})"
    tmp=$(mktemp -d "${TMPDIR:-/tmp}/shell-atuin.XXXXXX")
    TMP_DIRS+=("$tmp")

    local downloaded=0
    local candidate
    if download_release_asset "atuinsh/atuin" "$version" \
        "atuin-${target}.tar.gz" "$tmp/atuin.tar.gz" 3; then
        downloaded=1
    elif [[ "$ATUIN_VERSION" == "latest" ]]; then
        warn "could not download atuin ${version}; trying recent releases"
        while IFS= read -r candidate; do
            [[ -z "$candidate" || "$candidate" == "$version" ]] && continue
            info "Trying atuin ${candidate}"
            if download_release_asset "atuinsh/atuin" "$candidate" \
                "atuin-${target}.tar.gz" "$tmp/atuin.tar.gz" 1; then
                version=$candidate
                downloaded=1
                break
            fi
        done < <(list_recent_versions "atuinsh/atuin")
    fi

    if ((!downloaded)); then
        die "failed to download atuin for ${target}; set ATUIN_VERSION=<version> or check the proxy"
    fi

    tar -xzf "$tmp/atuin.tar.gz" -C "$tmp"
    local extracted="$tmp/atuin-${target}/atuin"
    if [[ ! -f "$extracted" ]]; then
        extracted=$(find "$tmp" -maxdepth 3 -type f -name atuin | head -n1) || true
    fi
    [[ -n "$extracted" && -f "$extracted" ]] \
        || die "the atuin archive did not contain a binary"

    make_dir "$(dirname "$bin")"
    install -m 0755 "$extracted" "$bin"
    if ((EUID == 0)) && [[ "$TARGET_USER" != "root" ]]; then
        chown "$TARGET_USER:$TARGET_GROUP" "$bin"
    fi

    "$bin" --version
    ok "atuin installed: $bin"
}

detect_zoxide_target() {
    local arch
    arch=$(uname -m | tr '[:upper:]' '[:lower:]')

    case "$arch" in
        amd64) arch="x86_64" ;;
        arm64) arch="aarch64" ;;
        armv7*) arch="armv7" ;;
        armv6*) arch="arm" ;;
        i?86) arch="i686" ;;
        riscv64) arch="riscv64gc" ;;
    esac

    if command -v getconf >/dev/null 2>&1; then
        if [[ "$arch" == "x86_64" && "$(getconf LONG_BIT)" == "32" ]]; then
            arch="i686"
        elif [[ "$arch" == "aarch64" && "$(getconf LONG_BIT)" == "32" ]]; then
            arch="arm"
        fi
    fi

    case "$arch" in
        x86_64|aarch64|i686|riscv64gc) printf '%s-unknown-linux-musl' "$arch" ;;
        armv7) printf '%s' "armv7-unknown-linux-musleabihf" ;;
        arm) printf '%s' "arm-unknown-linux-musleabihf" ;;
        *) return 1 ;;
    esac
}

resolve_zoxide_version() {
    if [[ -n "$ZOXIDE_VERSION" && "$ZOXIDE_VERSION" != "latest" ]]; then
        printf '%s\n' "${ZOXIDE_VERSION#v}"
        return 0
    fi
    resolve_latest_version "ajeetdsouza/zoxide"
}

install_zoxide() {
    if ((NO_ZOXIDE)); then
        info "Skipping zoxide (--no-zoxide)"
        return 0
    fi

    local bin="$TARGET_HOME/.local/bin/zoxide"
    local existing="" current=""
    if [[ -x "$bin" ]]; then
        existing=$bin
    elif command -v zoxide >/dev/null 2>&1; then
        existing=$(command -v zoxide)
    fi

    local target version
    if ! target=$(detect_zoxide_target); then
        warn "zoxide has no prebuilt binary for $(uname -m); skipping"
        NO_ZOXIDE=1
        return 0
    fi

    if ! version=$(resolve_zoxide_version); then
        if [[ -n "$existing" ]]; then
            current=$("$existing" --version 2>/dev/null | awk '{print $2}' | head -n1)
            warn "could not check the latest zoxide version; keeping $existing ($current)"
            return 0
        fi
        die "could not determine the latest zoxide version; set ZOXIDE_VERSION=x.y.z"
    fi

    if [[ -n "$existing" ]] && ((!FORCE)); then
        current=$("$existing" --version 2>/dev/null | awk '{print $2}' | head -n1)
        if [[ "${version#v}" == "$current" ]]; then
            ok "zoxide is up to date: $existing ($current)"
            return 0
        fi
        info "Updating zoxide ${current:-unknown} -> ${version}"
    fi

    local tmp
    info "Installing zoxide ${version} (${target})"
    tmp=$(mktemp -d "${TMPDIR:-/tmp}/shell-zoxide.XXXXXX")
    TMP_DIRS+=("$tmp")

    local downloaded=0
    local candidate
    if download_release_asset "ajeetdsouza/zoxide" "$version" \
        "zoxide-${version}-${target}.tar.gz" "$tmp/zoxide.tar.gz" 3; then
        downloaded=1
    elif [[ "$ZOXIDE_VERSION" == "latest" ]]; then
        warn "could not download zoxide ${version}; trying recent releases"
        while IFS= read -r candidate; do
            [[ -z "$candidate" || "$candidate" == "$version" ]] && continue
            info "Trying zoxide ${candidate}"
            if download_release_asset "ajeetdsouza/zoxide" "$candidate" \
                "zoxide-${candidate}-${target}.tar.gz" "$tmp/zoxide.tar.gz" 1; then
                version=$candidate
                downloaded=1
                break
            fi
        done < <(list_recent_versions "ajeetdsouza/zoxide")
    fi

    if ((!downloaded)); then
        die "failed to download zoxide for ${target}; set ZOXIDE_VERSION=<version> or check the proxy"
    fi

    tar -xzf "$tmp/zoxide.tar.gz" -C "$tmp"
    local extracted="$tmp/zoxide"
    if [[ ! -f "$extracted" ]]; then
        extracted=$(find "$tmp" -maxdepth 3 -type f -name zoxide | head -n1) || true
    fi
    [[ -n "$extracted" && -f "$extracted" ]] \
        || die "the zoxide archive did not contain a binary"

    make_dir "$(dirname "$bin")"
    install -m 0755 "$extracted" "$bin"
    if ((EUID == 0)) && [[ "$TARGET_USER" != "root" ]]; then
        chown "$TARGET_USER:$TARGET_GROUP" "$bin"
    fi

    "$bin" --version
    ok "zoxide installed: $bin"
}

detect_lsd_target() {
    local arch
    arch=$(uname -m | tr '[:upper:]' '[:lower:]')

    case "$arch" in
        amd64) arch="x86_64" ;;
        arm64) arch="aarch64" ;;
        armv7*|armv6*) arch="arm" ;;
        i?86) arch="i686" ;;
    esac

    if command -v getconf >/dev/null 2>&1; then
        if [[ "$arch" == "x86_64" && "$(getconf LONG_BIT)" == "32" ]]; then
            arch="i686"
        elif [[ "$arch" == "aarch64" && "$(getconf LONG_BIT)" == "32" ]]; then
            arch="arm"
        fi
    fi

    case "$arch" in
        x86_64|aarch64|i686) printf '%s-unknown-linux-musl' "$arch" ;;
        arm) printf '%s' "arm-unknown-linux-gnueabihf" ;;
        *) return 1 ;;
    esac
}

resolve_lsd_version() {
    if [[ -n "$LSD_VERSION" && "$LSD_VERSION" != "latest" ]]; then
        printf '%s\n' "${LSD_VERSION#v}"
        return 0
    fi
    resolve_latest_version "lsd-rs/lsd"
}

install_lsd() {
    if ((NO_LSD)); then
        info "Skipping lsd (--no-lsd)"
        return 0
    fi

    local bin="$TARGET_HOME/.local/bin/lsd"
    local existing="" current=""
    if [[ -x "$bin" ]]; then
        existing=$bin
    elif command -v lsd >/dev/null 2>&1; then
        existing=$(command -v lsd)
    fi

    local target version
    if ! target=$(detect_lsd_target); then
        warn "lsd has no prebuilt binary for $(uname -m); skipping"
        NO_LSD=1
        return 0
    fi

    if ! version=$(resolve_lsd_version); then
        if [[ -n "$existing" ]]; then
            current=$("$existing" --version 2>/dev/null | awk '{print $2}' | head -n1)
            warn "could not check the latest lsd version; keeping $existing ($current)"
            return 0
        fi
        die "could not determine the latest lsd version; set LSD_VERSION=x.y.z"
    fi

    if [[ -n "$existing" ]] && ((!FORCE)); then
        current=$("$existing" --version 2>/dev/null | awk '{print $2}' | head -n1)
        if [[ "${version#v}" == "$current" ]]; then
            ok "lsd is up to date: $existing ($current)"
            return 0
        fi
        info "Updating lsd ${current:-unknown} -> ${version}"
    fi

    local tmp
    info "Installing lsd ${version} (${target})"
    tmp=$(mktemp -d "${TMPDIR:-/tmp}/shell-lsd.XXXXXX")
    TMP_DIRS+=("$tmp")

    local downloaded=0
    local candidate
    if download_release_asset "lsd-rs/lsd" "$version" \
        "lsd-v${version}-${target}.tar.gz" "$tmp/lsd.tar.gz" 3; then
        downloaded=1
    elif [[ "$LSD_VERSION" == "latest" ]]; then
        warn "could not download lsd ${version}; trying recent releases"
        while IFS= read -r candidate; do
            [[ -z "$candidate" || "$candidate" == "$version" ]] && continue
            info "Trying lsd ${candidate}"
            if download_release_asset "lsd-rs/lsd" "$candidate" \
                "lsd-v${candidate}-${target}.tar.gz" "$tmp/lsd.tar.gz" 1; then
                version=$candidate
                downloaded=1
                break
            fi
        done < <(list_recent_versions "lsd-rs/lsd")
    fi

    if ((!downloaded)); then
        die "failed to download lsd for ${target}; set LSD_VERSION=<version> or check the proxy"
    fi

    tar -xzf "$tmp/lsd.tar.gz" -C "$tmp"
    local extracted="$tmp/lsd-v${version}-${target}/lsd"
    if [[ ! -f "$extracted" ]]; then
        extracted=$(find "$tmp" -maxdepth 3 -type f -name lsd | head -n1) || true
    fi
    [[ -n "$extracted" && -f "$extracted" ]] \
        || die "the lsd archive did not contain a binary"

    make_dir "$(dirname "$bin")"
    install -m 0755 "$extracted" "$bin"
    if ((EUID == 0)) && [[ "$TARGET_USER" != "root" ]]; then
        chown "$TARGET_USER:$TARGET_GROUP" "$bin"
    fi

    "$bin" --version
    ok "lsd installed: $bin"
}

tool_enabled() {
    case "$1" in
        starship) [[ $NO_STARSHIP -eq 0 ]] ;;
        atuin) [[ $NO_ATUIN -eq 0 ]] ;;
        zoxide) [[ $NO_ZOXIDE -eq 0 ]] ;;
        lsd) [[ $NO_LSD -eq 0 ]] ;;
        *) return 0 ;;
    esac
}

tool_bin() {
    local name=$1
    if [[ "$name" == "fish" ]]; then
        if [[ -x "/usr/local/bin/fish" ]]; then
            printf '%s' "/usr/local/bin/fish"
        elif [[ -x "$TARGET_HOME/.local/bin/fish" ]]; then
            printf '%s' "$TARGET_HOME/.local/bin/fish"
        elif command -v fish >/dev/null 2>&1; then
            command -v fish
        else
            return 1
        fi
    elif [[ -x "$TARGET_HOME/.local/bin/$name" ]]; then
        printf '%s' "$TARGET_HOME/.local/bin/$name"
    elif command -v "$name" >/dev/null 2>&1; then
        command -v "$name"
    else
        return 1
    fi
}

tool_current_version() {
    local name=$1 bin version
    bin=$(tool_bin "$name") || return 1
    if [[ "$name" == "fish" ]]; then
        version=$("$bin" --version 2>/dev/null | awk '{print $3}' | head -n1)
    else
        version=$("$bin" --version 2>/dev/null | awk '{print $2}' | head -n1)
    fi
    [[ -n "$version" ]] || return 1
    printf '%s' "$version"
}

resolve_tool_version() {
    case "$1" in
        fish) resolve_fish_version ;;
        starship) resolve_starship_version ;;
        atuin) resolve_atuin_version ;;
        zoxide) resolve_zoxide_version ;;
        lsd) resolve_lsd_version ;;
        *) return 1 ;;
    esac
}

make_dir() {
    local dir=$1

    if ((EUID == 0)) && [[ "$TARGET_USER" != "root" ]]; then
        # Remember which directories do not exist yet, create them, then give
        # only those directories to the target user. This also covers a custom
        # XDG_CONFIG_HOME outside of the home directory.
        local missing=()
        local current=$dir
        while [[ ! -d "$current" ]]; do
            missing+=("$current")
            current=$(dirname "$current")
        done

        install -d -m 0755 -o "$TARGET_USER" -g "$TARGET_GROUP" "$dir"

        local created
        for created in "${missing[@]+"${missing[@]}"}"; do
            chown "$TARGET_USER:$TARGET_GROUP" "$created"
        done
        chown "$TARGET_USER:$TARGET_GROUP" "$dir"
    else
        mkdir -p "$dir"
    fi
}

place_file() {
    local src=$1 dest=$2
    [[ -f "$src" ]] || die "config file not found: $src"

    make_dir "$(dirname "$dest")"

    if [[ -f "$dest" ]] && cmp -s "$src" "$dest"; then
        ok "already up to date: $dest"
        return 0
    fi

    if [[ -e "$dest" ]]; then
        local backup
        backup="${dest}.bak.$(date +%Y%m%d-%H%M%S)"
        cp -a "$dest" "$backup"
        info "Backup: $backup"
    fi

    install -m 0644 "$src" "$dest"
    if ((EUID == 0)) && [[ "$TARGET_USER" != "root" ]]; then
        chown "$TARGET_USER:$TARGET_GROUP" "$dest"
    fi
    ok "installed: $dest"
}

resolve_configs() {
    ATUIN_CONF_SRC=""
    local base

    if [[ -n "$CONFIG_DIR" ]]; then
        base=$CONFIG_DIR
    else
        local script_path="${BASH_SOURCE[0]:-}"
        [[ -n "$script_path" && -f "$script_path" ]] \
            || die "run install.sh from the cloned repository (or pass --config-dir)"
        base=$(cd -- "$(dirname -- "$script_path")" && pwd)/config
    fi

    [[ -f "$base/starship.toml" && -f "$base/fish/conf.d/00-shell-setup.fish" ]] \
        || die "configs not found in $base (run install.sh from the repository)"
    FISH_CONF_SRC="$base/fish/conf.d/00-shell-setup.fish"
    STARSHIP_CONF_SRC="$base/starship.toml"
    if ((!NO_ATUIN)); then
        [[ -f "$base/atuin.toml" ]] \
            || die "atuin config not found in $base (or pass --no-atuin)"
        ATUIN_CONF_SRC="$base/atuin.toml"
    fi
}

install_configs() {
    if ((NO_CONFIG)); then
        info "Skipping configuration files (--no-config)"
        return 0
    fi

    resolve_configs
    place_file "$FISH_CONF_SRC" "$CONFIG_HOME/fish/conf.d/00-shell-setup.fish"
    place_file "$STARSHIP_CONF_SRC" "$CONFIG_HOME/starship.toml"
    if ((!NO_ATUIN)); then
        place_file "$ATUIN_CONF_SRC" "$CONFIG_HOME/atuin/config.toml"
    fi
}

resolve_fonts() {
    local script_path="${BASH_SOURCE[0]:-}"
    [[ -n "$script_path" && -f "$script_path" ]] \
        || die "run install.sh from the cloned repository (fonts are stored next to it)"
    FONT_SRC_DIR=$(cd -- "$(dirname -- "$script_path")" && pwd)/fonts/$FONT_BASE
    [[ -d "$FONT_SRC_DIR" ]] \
        || die "fonts not found in $FONT_SRC_DIR (run install.sh from the repository)"
}

fonts_installed() {
    local dir=$1 style
    for style in "${FONT_STYLES[@]}"; do
        [[ -f "$dir/$FONT_BASE-$style.ttf" ]] || return 1
    done
}

install_fonts() {
    if ((NO_FONT)); then
        info "Skipping fonts (--no-font)"
        return 0
    fi

    local dir=${FONT_DIR:-$DATA_HOME/fonts/$FONT_BASE}
    local style file

    if fonts_installed "$dir" && ((!FORCE)); then
        ok "fonts are up to date: $dir"
        return 0
    fi

    resolve_fonts
    for style in "${FONT_STYLES[@]}"; do
        file="$FONT_BASE-$style.ttf"
        [[ -f "$FONT_SRC_DIR/$file" ]] \
            || die "font file not found: $FONT_SRC_DIR/$file"
    done

    info "Installing JetBrainsMono Nerd Font Mono to $dir"
    make_dir "$dir"
    for style in "${FONT_STYLES[@]}"; do
        file="$FONT_BASE-$style.ttf"
        install -m 0644 "$FONT_SRC_DIR/$file" "$dir/$file"
        if ((EUID == 0)) && [[ "$TARGET_USER" != "root" ]]; then
            chown "$TARGET_USER:$TARGET_GROUP" "$dir/$file"
        fi
    done

    if command -v fc-cache >/dev/null 2>&1; then
        fc-cache -f "$dir" >/dev/null 2>&1 \
            || warn "fc-cache failed for $dir; log out and back in to refresh fonts"
        if ((EUID == 0)) && [[ "$TARGET_USER" != "root" ]]; then
            chown -R "$TARGET_USER:$TARGET_GROUP" "$dir"
        fi
    else
        warn "fc-cache not found; install fontconfig or log out and back in"
    fi

    ok "fonts installed: $dir (${#FONT_STYLES[@]} files)"
}

setup_shell() {
    if ! grep -qxF "$FISH_BIN" /etc/shells 2>/dev/null; then
        info "Registering $FISH_BIN in /etc/shells"
        if ! printf '%s\n' "$FISH_BIN" | run_root tee -a /etc/shells >/dev/null; then
            warn "could not update /etc/shells; continuing"
        fi
    fi

    if ((NO_CHSH)); then
        warn "not changing the login shell (--no-chsh). Later: chsh -s $FISH_BIN"
        return 0
    fi

    if [[ "$TARGET_USER" == "root" ]]; then
        warn "target user is root; leaving root's login shell unchanged"
        return 0
    fi

    local current
    current=$(getent passwd "$TARGET_USER" | awk -F: '{print $7}')
    if [[ "$current" == "$FISH_BIN" ]]; then
        ok "login shell is already fish"
        return 0
    fi

    command -v chsh >/dev/null 2>&1 \
        || { warn "chsh not found; later: chsh -s $FISH_BIN"; return 0; }

    info "Changing the login shell for $TARGET_USER to $FISH_BIN"
    if ((EUID == 0)); then
        if chsh -s "$FISH_BIN" "$TARGET_USER"; then
            ok "login shell updated"
        else
            warn "could not change the login shell; later: chsh -s $FISH_BIN"
        fi
    else
        if chsh -s "$FISH_BIN"; then
            ok "login shell updated"
        else
            warn "could not change the login shell; later: chsh -s $FISH_BIN"
        fi
    fi
}

print_plan() {
    local fish_state starship_state atuin_state zoxide_state lsd_state font_state font_dir config_state proxy_state
    if [[ -x "/usr/local/bin/fish" ]]; then
        FISH_BIN="/usr/local/bin/fish"
    else
        FISH_BIN=$(command -v fish 2>/dev/null || true)
    fi
    if [[ -n "$FISH_BIN" ]]; then
        fish_state="already installed ($FISH_BIN, $("$FISH_BIN" --version 2>/dev/null | head -n1))"
    elif detect_fish_target >/dev/null 2>&1; then
        fish_state="will install from GitHub to /usr/local/bin/fish"
    else
        fish_state="will install from packages ($(uname -m) has no standalone binary)"
    fi
    if ((NO_STARSHIP)); then
        starship_state="skipped"
    elif command -v starship >/dev/null 2>&1 || [[ -x "$TARGET_HOME/.local/bin/starship" ]]; then
        starship_state="already installed"
    else
        starship_state="will install to $TARGET_HOME/.local/bin/starship"
    fi
    if ((NO_ATUIN)); then
        atuin_state="skipped"
    elif command -v atuin >/dev/null 2>&1 || [[ -x "$TARGET_HOME/.local/bin/atuin" ]]; then
        atuin_state="already installed"
    elif detect_atuin_target >/dev/null 2>&1; then
        atuin_state="will install to $TARGET_HOME/.local/bin/atuin"
    else
        atuin_state="no binary for $(uname -m); will skip"
    fi
    if ((NO_ZOXIDE)); then
        zoxide_state="skipped"
    elif command -v zoxide >/dev/null 2>&1 || [[ -x "$TARGET_HOME/.local/bin/zoxide" ]]; then
        zoxide_state="already installed"
    elif detect_zoxide_target >/dev/null 2>&1; then
        zoxide_state="will install to $TARGET_HOME/.local/bin/zoxide"
    else
        zoxide_state="no binary for $(uname -m); will skip"
    fi
    if ((NO_LSD)); then
        lsd_state="skipped"
    elif command -v lsd >/dev/null 2>&1 || [[ -x "$TARGET_HOME/.local/bin/lsd" ]]; then
        lsd_state="already installed"
    elif detect_lsd_target >/dev/null 2>&1; then
        lsd_state="will install to $TARGET_HOME/.local/bin/lsd"
    else
        lsd_state="no binary for $(uname -m); will skip"
    fi
    font_dir=${FONT_DIR:-$DATA_HOME/fonts/$FONT_BASE}
    if ((NO_FONT)); then
        font_state="skipped"
    elif fonts_installed "$font_dir"; then
        font_state="already installed ($font_dir)"
    else
        font_state="will install to $font_dir"
    fi
    if ((NO_CONFIG)); then
        config_state="skipped"
    elif ((NO_ATUIN)) || [[ "$atuin_state" == no\ binary* ]]; then
        config_state="$CONFIG_HOME/{fish/conf.d/00-shell-setup.fish,starship.toml}"
    else
        config_state="$CONFIG_HOME/{fish/conf.d/00-shell-setup.fish,starship.toml,atuin/config.toml}"
    fi
    if [[ -n "$EFFECTIVE_PROXY" ]]; then
        proxy_state=$(redact_proxy "$EFFECTIVE_PROXY")
    else
        proxy_state="none"
    fi

    cat <<EOF

${BOLD}Installation plan${RESET}
  distribution : ${PRETTY_NAME:-$DISTRO_ID}
  package mgr  : $PM
  target user  : $TARGET_USER ($TARGET_HOME)
  fish         : $fish_state
  starship     : $starship_state
  atuin        : $atuin_state
  zoxide       : $zoxide_state
  lsd          : $lsd_state
  font         : $font_state
  configs      : $config_state
  proxy        : $proxy_state
  no proxy for : ${NO_PROXY:-none}
  login shell  : $([[ $NO_CHSH == 1 || $TARGET_USER == root ]] && echo "unchanged" || echo "will switch to fish")

Run without --dry-run to apply.
EOF
}

print_summary() {
    printf '\n'
    ok "Installation complete"
    printf '  fish      : %s (%s)\n' "$FISH_BIN" "$("$FISH_BIN" --version)"
    if ((NO_STARSHIP)); then
        printf '  starship  : skipped\n'
    elif [[ -x "$TARGET_HOME/.local/bin/starship" ]]; then
        printf '  starship  : %s\n' "$TARGET_HOME/.local/bin/starship"
    elif command -v starship >/dev/null 2>&1; then
        printf '  starship  : %s\n' "$(command -v starship)"
    else
        printf '  starship  : not installed\n'
    fi
    if ((NO_ATUIN)); then
        printf '  atuin     : skipped\n'
    elif [[ -x "$TARGET_HOME/.local/bin/atuin" ]]; then
        printf '  atuin     : %s\n' "$TARGET_HOME/.local/bin/atuin"
    elif command -v atuin >/dev/null 2>&1; then
        printf '  atuin     : %s\n' "$(command -v atuin)"
    else
        printf '  atuin     : not installed\n'
    fi
    if ((NO_ZOXIDE)); then
        printf '  zoxide    : skipped\n'
    elif [[ -x "$TARGET_HOME/.local/bin/zoxide" ]]; then
        printf '  zoxide    : %s\n' "$TARGET_HOME/.local/bin/zoxide"
    elif command -v zoxide >/dev/null 2>&1; then
        printf '  zoxide    : %s\n' "$(command -v zoxide)"
    else
        printf '  zoxide    : not installed\n'
    fi
    if ((NO_LSD)); then
        printf '  lsd       : skipped\n'
    elif [[ -x "$TARGET_HOME/.local/bin/lsd" ]]; then
        printf '  lsd       : %s\n' "$TARGET_HOME/.local/bin/lsd"
    elif command -v lsd >/dev/null 2>&1; then
        printf '  lsd       : %s\n' "$(command -v lsd)"
    else
        printf '  lsd       : not installed\n'
    fi
    if ((NO_FONT)); then
        printf '  font      : skipped\n'
    else
        printf '  font      : %s\n' "${FONT_DIR:-$DATA_HOME/fonts/$FONT_BASE}"
    fi
    if ((NO_CONFIG)); then
        printf '  configs   : skipped\n'
    else
        printf '  configs   : %s\n' "$CONFIG_HOME"
    fi
    if [[ -n "$EFFECTIVE_PROXY" ]]; then
        printf '  proxy     : %s\n' "$(redact_proxy "$EFFECTIVE_PROXY")"
    fi
    printf '\nNext steps:\n'
    printf '  1. Start a new terminal (or run: exec fish).\n'
    if ((NO_FONT)); then
        printf '  2. Prompt icons need a Nerd Font (skipped with --no-font):\n'
        printf '     install it from fonts/%s in this repository\n' "$FONT_BASE"
    else
        printf '  2. Select "JetBrainsMono Nerd Font Mono" in your terminal settings\n'
        printf '     so the prompt icons render correctly.\n'
    fi
    local step=3
    if ((!NO_ATUIN)); then
        printf '  %s. Atuin sync is off by default; enable it with: atuin register\n' "$step"
        step=$((step + 1))
    fi
    if ((NO_CHSH)) || [[ "$TARGET_USER" == "root" ]]; then
        printf '  %s. Optional: chsh -s %s\n' "$step" "$FISH_BIN"
    fi
    printf '\n'
}

check_versions() {
    local name current latest status
    local outdated=0 failed=0

    printf '\n%sVersion check%s\n' "$BOLD" "$RESET"
    printf '  %-10s %-14s %-14s %s\n' "tool" "installed" "latest" "status"

    for name in fish starship atuin zoxide lsd; do
        tool_enabled "$name" || continue

        if ! latest=$(resolve_tool_version "$name"); then
            current=$(tool_current_version "$name" || true)
            [[ -n "$current" ]] || current="-"
            printf '  %-10s %-14s %-14s %s\n' \
                "$name" "$current" "?" "check failed"
            failed=1
            continue
        fi
        latest=${latest#v}

        if current=$(tool_current_version "$name"); then
            if [[ "$current" == "$latest" ]]; then
                status="up to date"
            else
                status="update available"
                outdated=1
            fi
        else
            current="-"
            status="not installed"
            outdated=1
        fi

        printf '  %-10s %-14s %-14s %s\n' "$name" "$current" "$latest" "$status"
    done

    printf '\n'
    if ((failed)); then
        warn "could not check some versions (GitHub unavailable?)"
        return 2
    fi
    if ((outdated)); then
        info "updates available; run: bash install.sh --update"
        return 1
    fi
    ok "all tools are up to date"
    return 0
}

ensure_update_prereqs() {
    local cmd missing=()
    for cmd in curl tar gzip xz; do
        command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
    done
    if ((${#missing[@]})); then
        die "missing prerequisites: ${missing[*]}; run install.sh first"
    fi
}

update_tools() {
    local name
    for name in fish starship atuin zoxide lsd; do
        if ! tool_enabled "$name"; then
            info "Skipping $name"
            continue
        fi
        if ! tool_bin "$name" >/dev/null 2>&1; then
            ok "$name is not installed; skipping (run install.sh to install it)"
            continue
        fi
        case "$name" in
            fish)
                if ! detect_fish_target >/dev/null 2>&1; then
                    warn "no standalone fish binary for $(uname -m); use the package manager"
                    continue
                fi
                install_fish
                ;;
            starship) install_starship ;;
            atuin) install_atuin ;;
            zoxide) install_zoxide ;;
            lsd) install_lsd ;;
        esac
    done
}

print_update_summary() {
    local name current
    printf '\n'
    ok "Update complete"
    for name in fish starship atuin zoxide lsd; do
        tool_enabled "$name" || continue
        if current=$(tool_current_version "$name"); then
            printf '  %-10s %s\n' "$name" "$current"
        else
            printf '  %-10s %s\n' "$name" "not installed"
        fi
    done
    printf '\n'
}

main() {
    parse_args "$@"
    check_platform

    local env_file
    if ((!DISABLE_PROXY)); then
        if env_file=$(resolve_env_file); then
            load_env_file "$env_file"
        fi
    fi
    setup_proxy

    detect_target_user

    if ((CHECK)); then
        local check_status=0
        check_versions || check_status=$?
        exit "$check_status"
    fi

    detect_distro

    if ((DRY_RUN)); then
        print_plan
        exit 0
    fi

    if ((UPDATE)); then
        detect_sudo
        ensure_update_prereqs
        update_tools
        print_update_summary
        exit 0
    fi

    detect_sudo
    install_prereqs
    install_fish
    install_starship
    install_atuin
    install_zoxide
    install_lsd
    install_fonts
    install_configs
    setup_shell
    print_summary
}

main "$@"
