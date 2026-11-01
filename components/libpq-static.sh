#!/usr/bin/env bash
# The libpq-static component: libpq of PostgreSQL $POSTGRESQL_VERSION, static, in
# $SOFTWARE_DIR/libpq-$POSTGRESQL_VERSION-static, built with the native GCC
# (docs/toolchain.md, "libpq-static"). It is the libpq of the projects' self-contained
# executables.
#
# The client part of PostgreSQL only (headers, libpq, the common and port libraries
# libpq.a needs, and pg_config), as in its documentation's client-only installation.
# The shared libpq is removed afterwards, so that FindPostgreSQL can only find
# libpq.a. With OpenSSL; GSSAPI and LDAP are off by default; ICU, readline and zlib are
# only used by the server and the tools. The tarball is checked against the SHA-256
# published by ftp.postgresql.org.
#
# System requirements: make, bzip2, curl and the development packages of OpenSSL.
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(dirname "$0")/../lib/common.sh"

LIBPQ_PREFIX="$SOFTWARE_DIR/libpq-$POSTGRESQL_VERSION-static"
NAME=libpq-static
VERSION="$POSTGRESQL_VERSION"
PREFIXES=("$LIBPQ_PREFIX")

install() {
    local url tarball src build dir
    require gcc

    url="https://ftp.postgresql.org/pub/source/v$POSTGRESQL_VERSION/postgresql-$POSTGRESQL_VERSION.tar.bz2"
    tarball="$SRC/postgresql-$POSTGRESQL_VERSION.tar.bz2"
    download "$url" "$tarball"
    check_sha256 "$url" "$tarball"
    src="$SRC/postgresql-$POSTGRESQL_VERSION"
    [[ -d "$src" ]] || tar -xf "$tarball" -C "$SRC"

    build="$SRC/postgresql-$POSTGRESQL_VERSION-build"
    rm -rf "$build" "$LIBPQ_PREFIX"
    mkdir -p "$build"
    (
        cd "$build"
        "$src/configure" --prefix="$LIBPQ_PREFIX" CC="$GCC_DIR/bin/gcc" \
            --with-ssl=openssl --without-icu --without-readline --without-zlib
        for dir in src/include src/common src/port src/interfaces/libpq src/bin/pg_config; do
            make -C "$dir" -j"$(nproc)" install
        done
    )
    rm -rf "$build"
    rm -f "$LIBPQ_PREFIX"/lib/libpq.so*
}

component_main "$@"
