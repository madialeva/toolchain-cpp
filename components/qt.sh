#!/usr/bin/env bash
# The qt component: the official Qt $QT_VERSION desktop kit for Linux x86_64
# (linux_gcc_64), installed with aqtinstall, in $SOFTWARE_DIR/Qt/$QT_VERSION/gcc_64
# (docs/toolchain.md, "qt and qt-wasm"). It is the kit of the projects' native
# builds, and the host (QT_HOST_PATH) of the WebAssembly kit.
#
# Beyond aqt's default modules it has the union of what the projects need (lib/aqt.sh).
# A kit that lacks one of them is installed again.
#
# System requirements: python3 with the venv module.
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(dirname "$0")/../lib/common.sh"
# shellcheck source=../lib/aqt.sh
source "$TOOLCHAIN_ROOT/lib/aqt.sh"

KIT="$QT_DIR/$QT_VERSION/gcc_64"
NAME=qt
VERSION="$QT_VERSION"
PREFIXES=("$KIT")
is_installed() { installed "$KIT" && has_modules "$KIT"; }

install() {
    rm -rf "$KIT"
    aqt_install linux desktop linux_gcc_64
}

component_main "$@"
