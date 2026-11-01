#!/usr/bin/env bash
# The protobuf-mingw component: the same protobuf $PROTOBUF_VERSION and abseil as the
# protobuf component, static, for 64-bit Windows, in
# $SOFTWARE_DIR/protobuf-$PROTOBUF_VERSION-mingw, cross-built with the gcc-mingw
# component in C++26 (docs/toolchain.md, "Components for Windows"). Without protoc: the
# native one generates the code, and both must be the same version.
#
# System requirements: CMake 3.25+, Ninja and git.
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(dirname "$0")/../lib/common.sh"

PREFIX="$SOFTWARE_DIR/protobuf-$PROTOBUF_VERSION-mingw"
NAME=protobuf-mingw
VERSION="$PROTOBUF_VERSION"
PREFIXES=("$PREFIX")

install() {
    local src="$SRC/protobuf-$PROTOBUF_VERSION"
    require gcc-mingw
    git_tag https://github.com/protocolbuffers/protobuf.git "v$PROTOBUF_VERSION" "protobuf-$PROTOBUF_VERSION" \
        --recurse-submodules --shallow-submodules
    rm -rf "$PREFIX"
    cmake_mingw "$src" "$src/build-mingw" "$PREFIX" \
        -DBUILD_SHARED_LIBS=OFF -Dprotobuf_BUILD_TESTS=OFF -Dprotobuf_BUILD_PROTOC_BINARIES=OFF \
        -Dprotobuf_BUILD_LIBUPB=OFF -Dprotobuf_INSTALL=ON \
        -Dprotobuf_ABSL_PROVIDER=module -DABSL_ENABLE_INSTALL=ON -DABSL_PROPAGATE_CXX_STD=ON
}

component_main "$@"
