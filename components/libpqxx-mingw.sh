#!/usr/bin/env bash
# The libpqxx-mingw component: libpqxx $LIBPQXX_VERSION, static, for 64-bit Windows,
# against the libpq-mingw component, in $SOFTWARE_DIR/libpqxx-$LIBPQXX_VERSION-mingw,
# cross-built with the gcc-mingw component in C++26 (docs/toolchain.md, "Components for
# Windows").
#
# System requirements: CMake 3.25+, Ninja and git.
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(dirname "$0")/../lib/common.sh"

PREFIX="$SOFTWARE_DIR/libpqxx-$LIBPQXX_VERSION-mingw"
LIBPQ_PREFIX="$SOFTWARE_DIR/libpq-$POSTGRESQL_VERSION-mingw"
NAME=libpqxx-mingw
VERSION="$LIBPQXX_VERSION"
PREFIXES=("$PREFIX")

install() {
    local src="$SRC/libpqxx-$LIBPQXX_VERSION"
    require libpq-mingw
    git_tag https://github.com/jtv/libpqxx.git "$LIBPQXX_VERSION" "libpqxx-$LIBPQXX_VERSION"
    rm -rf "$PREFIX"
    cmake_mingw "$src" "$src/build-mingw" "$PREFIX" -DCMAKE_FIND_ROOT_PATH="$LIBPQ_PREFIX" \
        -DBUILD_SHARED_LIBS=OFF -DBUILD_TEST=OFF -DBUILD_EXAMPLES=OFF -DBUILD_DOC=OFF
}

component_main "$@"
