#!/usr/bin/env bash
# The protobuf component: protobuf $PROTOBUF_VERSION, its C++ library and protoc, with
# abseil (a submodule, installed next to it), in $SOFTWARE_DIR/protobuf-$PROTOBUF_VERSION
# (docs/toolchain.md, "Libraries"): static and PIC, built with the native GCC in C++26,
# so that abseil and the projects agree on the std types abseil aliases (string_view,
# optional, ...). protoc gets a run path to that GCC's libstdc++.
#
# System requirements: CMake 3.25+, Ninja and git.
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(dirname "$0")/../lib/common.sh"

PREFIX="$SOFTWARE_DIR/protobuf-$PROTOBUF_VERSION"
NAME=protobuf
VERSION="$PROTOBUF_VERSION"
PREFIXES=("$PREFIX")

install() {
    local src="$SRC/protobuf-$PROTOBUF_VERSION"
    use_native_gcc
    git_tag https://github.com/protocolbuffers/protobuf.git "v$PROTOBUF_VERSION" "protobuf-$PROTOBUF_VERSION" \
        --recurse-submodules --shallow-submodules
    rm -rf "$PREFIX"
    cmake_native "$src" "$src/build" "$PREFIX" \
        -DBUILD_SHARED_LIBS=OFF -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
        -Dprotobuf_BUILD_TESTS=OFF -Dprotobuf_BUILD_LIBUPB=OFF -Dprotobuf_INSTALL=ON \
        -Dprotobuf_ABSL_PROVIDER=module -DABSL_ENABLE_INSTALL=ON -DABSL_PROPAGATE_CXX_STD=ON
}

component_main "$@"
