#!/usr/bin/env bash
# Installs components of the toolchain by name, with the components they need
# (docs/toolchain.md):
#
#   ./install.sh <component>...            install them and what they need
#   ./install.sh --dry-run <component>...  only show what would be installed
#   ./install.sh --list                    every component, its version and its status
#
# Everything goes to $SOFTWARE_DIR, by default software/ in this repository. A
# component can also be installed alone with its own script, components/<name>.sh,
# which fails if a component it needs is missing.
set -euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

# The components, in the order they are installed
COMPONENTS=(gcc gcc-mingw qt qt-wasm qt-static libpq-static libpqxx cpp-httplib protobuf
    protobuf-wasm buf)
# The components each one needs
declare -A NEEDS=(
    [gcc-mingw]=gcc [qt-wasm]=qt [qt-static]=gcc [libpq-static]=gcc [libpqxx]=gcc
    [cpp-httplib]=gcc [protobuf]=gcc [protobuf-wasm]=qt-wasm
)
# The version each one installs
declare -A VERSIONS=(
    [gcc]=$GCC_VERSION [gcc-mingw]=$GCC_VERSION [qt]=$QT_VERSION [qt-wasm]=$QT_VERSION
    [qt-static]=$QT_VERSION [libpq-static]=$POSTGRESQL_VERSION [libpqxx]=$LIBPQXX_VERSION
    [cpp-httplib]=$HTTPLIB_VERSION [protobuf]=$PROTOBUF_VERSION
    [protobuf-wasm]=$PROTOBUF_VERSION [buf]=$BUF_VERSION
)

usage() {
    echo "usage: $0 [--dry-run] <component>... | --list" >&2
    echo "components: ${COMPONENTS[*]}" >&2
    exit 2
}

# is_component_installed <component>: what its script answers
is_component_installed() {
    local script="$TOOLCHAIN_ROOT/components/$1.sh"
    [[ -x "$script" ]] && "$script" --status
}

# want <component>: adds <component> and, recursively, the components it needs
declare -A wanted=()
want() {
    local component="$1" need
    [[ -n "${wanted[$component]:-}" ]] && return
    wanted[$component]=1
    for need in ${NEEDS[$component]:-}; do
        want "$need"
    done
}

dry_run=0
case "${1:-}" in
    --list)
        [[ $# -eq 1 ]] || usage
        for component in "${COMPONENTS[@]}"; do
            status="not installed"
            is_component_installed "$component" && status=installed
            printf '%-14s %-8s %s\n' "$component" "${VERSIONS[$component]}" "$status"
        done
        exit 0
        ;;
    --dry-run) dry_run=1; shift ;;
    "" | -*) usage ;;
esac
[[ $# -gt 0 ]] || usage

for component; do
    [[ -n "${VERSIONS[$component]:-}" ]] ||
        die "unknown component '$component'; the components are: ${COMPONENTS[*]}"
done
for component; do
    want "$component"
done

plan=()
for component in "${COMPONENTS[@]}"; do
    [[ -n "${wanted[$component]:-}" ]] || continue
    if is_component_installed "$component"; then
        say "$component ${VERSIONS[$component]} already installed"
    else
        plan+=("$component")
    fi
done

if ((${#plan[@]} == 0)); then
    exit 0
fi
if ((dry_run)); then
    say "would install, in this order: ${plan[*]}"
    exit 0
fi
say "installing, in this order: ${plan[*]}"
for component in "${plan[@]}"; do
    script="$TOOLCHAIN_ROOT/components/$component.sh"
    [[ -x "$script" ]] || die "no script for the $component component: $script"
    "$script"
done
