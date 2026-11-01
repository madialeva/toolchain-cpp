#!/usr/bin/env bash
# The libpq-mingw component: libpq of PostgreSQL $POSTGRESQL_VERSION, static, for 64-bit
# Windows, with the TLS of the openssl-mingw component, in
# $SOFTWARE_DIR/libpq-$POSTGRESQL_VERSION-mingw, cross-built with the gcc-mingw
# component (docs/toolchain.md, "Components for Windows").
#
# The client part of PostgreSQL, as libpq-static: the headers, libpq and the common and
# port libraries libpq needs. On mingw PostgreSQL only installs libpq.dll and its import
# library, named libpq.a; the static libpq.a is made here from libpq's objects, and the
# DLL and the import library go away, and libpq's own pthread functions are renamed so
# that they do not clash with winpthreads. The tarball is the one of libpq-static,
# checked against the SHA-256 published by ftp.postgresql.org.
#
# System requirements: make, bzip2 and curl.
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(dirname "$0")/../lib/common.sh"

PREFIX="$SOFTWARE_DIR/libpq-$POSTGRESQL_VERSION-mingw"
OPENSSL_PREFIX="$SOFTWARE_DIR/openssl-$OPENSSL_VERSION-mingw"
NAME=libpq-mingw
VERSION="$POSTGRESQL_VERSION"
PREFIXES=("$PREFIX")
# The functions of libpq's pthread-win32.c, renamed in the static libpq
LIBPQ_PTHREAD_SYMBOLS=(pthread_self pthread_setspecific pthread_getspecific pthread_mutex_init
    pthread_mutex_lock pthread_mutex_unlock)

install() {
    local url tarball src build dir tool objects object symbol
    require openssl-mingw

    url="https://ftp.postgresql.org/pub/source/v$POSTGRESQL_VERSION/postgresql-$POSTGRESQL_VERSION.tar.bz2"
    tarball="$SRC/postgresql-$POSTGRESQL_VERSION.tar.bz2"
    download "$url" "$tarball"
    check_sha256 "$url" "$tarball"
    src="$SRC/postgresql-$POSTGRESQL_VERSION"
    [[ -d "$src" ]] || tar -xf "$tarball" -C "$SRC"

    build="$SRC/postgresql-$POSTGRESQL_VERSION-build-mingw"
    rm -rf "$build" "$PREFIX"
    mkdir -p "$build"
    (
        cd "$build"
        # The cross tools by their path, also those configure looks for by name (windres)
        export PATH="$MINGW_DIR/bin:$PATH"
        tool="$MINGW_DIR/bin/x86_64-w64-mingw32"
        # A static libcrypto needs these Windows libraries when configure links with it
        "$src/configure" --host=x86_64-w64-mingw32 --prefix="$PREFIX" \
            CC="$tool-gcc" AR="$tool-ar" RANLIB="$tool-ranlib" \
            CPPFLAGS="-I$OPENSSL_PREFIX/include" LDFLAGS="-L$OPENSSL_PREFIX/lib" \
            LIBS="-lws2_32 -lgdi32 -lcrypt32" \
            --with-ssl=openssl --without-icu --without-readline --without-zlib
        for dir in src/include src/common src/port src/interfaces/libpq; do
            make -C "$dir" -j"$(nproc)" install
        done

        # The static libpq, from the objects PostgreSQL's makefile puts in libpq.a: all
        # but the shared library's own (*_shlib.o) and the DLL's version resource
        # (win32ver.o), which would clash with the executable's
        objects=()
        for object in src/interfaces/libpq/*.o; do
            [[ "$object" == *_shlib.o || "$object" == */win32ver.o ]] || objects+=("$object")
        done
        ((${#objects[@]} > 10)) || die "no objects of libpq in $build/src/interfaces/libpq"

        # libpq carries its own pthread functions for Windows (pthread-win32.c), with a
        # pthread_mutex_t of its own: in a static library they clash with those of
        # winpthreads, which every C++ program links. Renamed with a pq_ prefix in all of
        # libpq's objects, libpq keeps calling its own
        for symbol in "${LIBPQ_PTHREAD_SYMBOLS[@]}"; do
            echo "$symbol pq_$symbol"
        done >pthread-symbols
        for object in "${objects[@]}"; do
            "$tool-objcopy" --redefine-syms=pthread-symbols "$object"
        done

        rm -f "$PREFIX"/lib/libpq.a "$PREFIX"/lib/libpq.dll* "$PREFIX"/bin/libpq.dll
        "$tool-ar" rcs "$PREFIX/lib/libpq.a" "${objects[@]}"
        if "$tool-nm" "$PREFIX/lib/libpq.a" | grep -E ' [A-Za-z] pthread_'; then
            die "libpq.a still has the pthread symbols above"
        fi

        # exec.c defines _dowildcard for PostgreSQL's own programs: in an archive, mingw's
        # crt2.o pulls it in for that symbol, and with it code that needs the backend's
        # palloc. libpq uses neither exec.c nor restricted_token.c, its only user
        "$tool-ar" d "$PREFIX/lib/libpgcommon_shlib.a" exec_shlib.o restricted_token_shlib.o
    )
    rm -rf "$build"
}

component_main "$@"
