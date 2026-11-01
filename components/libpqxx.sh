#!/usr/bin/env bash
# The libpqxx component: libpqxx $LIBPQXX_VERSION, the C++ client of PostgreSQL, in
# $SOFTWARE_DIR/libpqxx-$LIBPQXX_VERSION (docs/toolchain.md, "Libraries"): static and
# PIC, since it is also linked into Qt executables, built with the native GCC in C++26.
#
# System requirements: CMake 3.25+, Ninja, git and the development files of libpq
# (libpq5-devel / libpq-devel).
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(dirname "$0")/../lib/common.sh"

PREFIX="$SOFTWARE_DIR/libpqxx-$LIBPQXX_VERSION"
NAME=libpqxx
VERSION="$LIBPQXX_VERSION"
PREFIXES=("$PREFIX")

install() {
    local src="$SRC/libpqxx-$LIBPQXX_VERSION"
    use_native_gcc
    git_tag https://github.com/jtv/libpqxx.git "$LIBPQXX_VERSION" "libpqxx-$LIBPQXX_VERSION"
    rm -rf "$PREFIX"
    cmake_native "$src" "$src/build" "$PREFIX" \
        -DBUILD_SHARED_LIBS=OFF -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
        -DBUILD_TEST=OFF -DBUILD_EXAMPLES=OFF -DBUILD_DOC=OFF
}

component_main "$@"
