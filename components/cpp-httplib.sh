#!/usr/bin/env bash
# The cpp-httplib component: cpp-httplib $HTTPLIB_VERSION, an embedded HTTP server
# (header-only), in $SOFTWARE_DIR/cpp-httplib-$HTTPLIB_VERSION (docs/toolchain.md,
# "Libraries"). With zlib compression. TLS is terminated by a reverse proxy; Brotli
# and zstd stay off, so that the result does not depend on which optional libraries
# happen to be installed.
#
# System requirements: CMake 3.25+, Ninja, git and the development files of zlib.
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(dirname "$0")/../lib/common.sh"

PREFIX="$SOFTWARE_DIR/cpp-httplib-$HTTPLIB_VERSION"
NAME=cpp-httplib
VERSION="$HTTPLIB_VERSION"
PREFIXES=("$PREFIX")

install() {
    local src="$SRC/cpp-httplib-$HTTPLIB_VERSION"
    use_native_gcc
    git_tag https://github.com/yhirose/cpp-httplib.git "v$HTTPLIB_VERSION" "cpp-httplib-$HTTPLIB_VERSION"
    rm -rf "$PREFIX"
    cmake_native "$src" "$src/build" "$PREFIX" \
        -DHTTPLIB_COMPILE=OFF -DHTTPLIB_REQUIRE_ZLIB=ON \
        -DHTTPLIB_USE_OPENSSL_IF_AVAILABLE=OFF \
        -DHTTPLIB_USE_BROTLI_IF_AVAILABLE=OFF -DHTTPLIB_USE_ZSTD_IF_AVAILABLE=OFF
}

component_main "$@"
