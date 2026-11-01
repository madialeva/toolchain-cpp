#!/usr/bin/env bash
# The qt-wasm component: the toolchain of the projects' web clients (docs/toolchain.md,
# "qt and qt-wasm"):
#   - the official Qt $QT_VERSION wasm_singlethread kit, installed with aqtinstall, in
#     $SOFTWARE_DIR/Qt/$QT_VERSION/wasm_singlethread, with the same modules as the
#     desktop kit, which is its host (the qt component);
#   - emsdk $EMSDK_VERSION in $SOFTWARE_DIR/emsdk: the Emscripten release that Qt
#     version requires (QT_EMCC_RECOMMENDED_VERSION in the kit), checked against
#     versions.sh;
#   - Python 3.12 through uv, in uv's standard location: Emscripten needs >= 3.10, and
#     EL9 ships 3.9. EMSDK_PYTHON must point to it (~/.local/bin/python3.12), also
#     after sourcing emsdk_env.sh, which clears it.
#
# System requirements: python3 with the venv module, git and uv.
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(dirname "$0")/../lib/common.sh"
# shellcheck source=../lib/aqt.sh
source "$TOOLCHAIN_ROOT/lib/aqt.sh"

KIT="$QT_DIR/$QT_VERSION/wasm_singlethread"
EMSDK_DIR="$SOFTWARE_DIR/emsdk"
NAME=qt-wasm
VERSION="$QT_VERSION"
PREFIXES=("$KIT" "$EMSDK_DIR")
is_installed() { installed "$KIT" "$EMSDK_DIR" && has_modules "$KIT"; }

install() {
    local recommended
    require qt

    if ! { installed "$KIT" && has_modules "$KIT"; }; then
        rm -rf "$KIT"
        aqt_install all_os wasm wasm_singlethread
    fi
    recommended="$(sed -n 's/.*set(QT_EMCC_RECOMMENDED_VERSION "\([0-9.]*\)").*/\1/p' \
        "$KIT/lib/cmake/Qt6/QtPublicWasmToolchainHelpers.cmake")"
    [[ "$recommended" == "$EMSDK_VERSION" ]] ||
        die "the Qt $QT_VERSION kit recommends emsdk ${recommended:-(none found)}, but versions.sh has $EMSDK_VERSION"

    uv python install 3.12
    export EMSDK_PYTHON="$HOME/.local/bin/python3.12"
    rm -rf "$EMSDK_DIR"
    git clone -q https://github.com/emscripten-core/emsdk.git "$EMSDK_DIR"
    "$EMSDK_DIR/emsdk" install "$EMSDK_VERSION"
    "$EMSDK_DIR/emsdk" activate "$EMSDK_VERSION"
}

component_main "$@"
