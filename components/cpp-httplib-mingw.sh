#!/usr/bin/env bash
# The cpp-httplib-mingw component: cpp-httplib $HTTPLIB_VERSION, header-only, for 64-bit
# Windows, in $SOFTWARE_DIR/cpp-httplib-$HTTPLIB_VERSION-mingw, configured with the
# gcc-mingw component (docs/toolchain.md, "Components for Windows"). Without zlib, TLS,
# Brotli or zstd: on Windows the projects embed the backend, which opens no port.
#
# System requirements: CMake 3.25+, Ninja and git.
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(dirname "$0")/../lib/common.sh"

PREFIX="$SOFTWARE_DIR/cpp-httplib-$HTTPLIB_VERSION-mingw"
NAME=cpp-httplib-mingw
VERSION="$HTTPLIB_VERSION"
PREFIXES=("$PREFIX")

install() {
    local src="$SRC/cpp-httplib-$HTTPLIB_VERSION"
    require gcc-mingw
    git_tag https://github.com/yhirose/cpp-httplib.git "v$HTTPLIB_VERSION" "cpp-httplib-$HTTPLIB_VERSION"
    rm -rf "$PREFIX"
    cmake_mingw "$src" "$src/build-mingw" "$PREFIX" \
        -DHTTPLIB_COMPILE=OFF -DHTTPLIB_REQUIRE_ZLIB=OFF -DHTTPLIB_USE_ZLIB_IF_AVAILABLE=OFF \
        -DHTTPLIB_USE_OPENSSL_IF_AVAILABLE=OFF \
        -DHTTPLIB_USE_BROTLI_IF_AVAILABLE=OFF -DHTTPLIB_USE_ZSTD_IF_AVAILABLE=OFF
}

component_main "$@"
