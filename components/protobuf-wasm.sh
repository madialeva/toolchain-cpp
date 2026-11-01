#!/usr/bin/env bash
# The protobuf-wasm component: the same protobuf $PROTOBUF_VERSION and abseil, for
# WebAssembly, in $SOFTWARE_DIR/protobuf-$PROTOBUF_VERSION-wasm (docs/toolchain.md,
# "Libraries"). Built with the emsdk of the qt-wasm component, for Qt's
# wasm_singlethread kit: no threads and Emscripten's default exception handling, as
# the kit, and C++26. The same version as the native protobuf, which the generated
# code requires; without protoc, since the native one generates the code.
#
# System requirements: CMake 3.25+, Ninja and git.
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(dirname "$0")/../lib/common.sh"

PREFIX="$SOFTWARE_DIR/protobuf-$PROTOBUF_VERSION-wasm"
EMSDK_DIR="$SOFTWARE_DIR/emsdk"
NAME=protobuf-wasm
VERSION="$PROTOBUF_VERSION"
PREFIXES=("$PREFIX")

install() {
    local src="$SRC/protobuf-$PROTOBUF_VERSION"
    require qt-wasm
    git_tag https://github.com/protocolbuffers/protobuf.git "v$PROTOBUF_VERSION" "protobuf-$PROTOBUF_VERSION" \
        --recurse-submodules --shallow-submodules
    rm -rf "$PREFIX" "$src/build-wasm"
    (
        # Emscripten needs Python >= 3.10; emsdk_env.sh clears EMSDK_PYTHON
        export EMSDK_PYTHON="$HOME/.local/bin/python3.12"
        # shellcheck disable=SC1091
        source "$EMSDK_DIR/emsdk_env.sh" >/dev/null 2>&1
        export EMSDK_PYTHON="$HOME/.local/bin/python3.12"
        emcmake cmake -S "$src" -B "$src/build-wasm" -G Ninja \
            -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PREFIX" \
            -DCMAKE_CXX_STANDARD=26 -DBUILD_SHARED_LIBS=OFF \
            -Dprotobuf_BUILD_TESTS=OFF -Dprotobuf_BUILD_PROTOC_BINARIES=OFF -Dprotobuf_BUILD_LIBUPB=OFF \
            -Dprotobuf_INSTALL=ON -Dprotobuf_ABSL_PROVIDER=module -DABSL_ENABLE_INSTALL=ON \
            -DABSL_PROPAGATE_CXX_STD=ON
        cmake --build "$src/build-wasm" -j"$(nproc)"
        cmake --install "$src/build-wasm"
    )
    rm -rf "$src/build-wasm"
}

component_main "$@"
