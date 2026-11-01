#!/usr/bin/env bash
# The openssl-mingw component: OpenSSL $OPENSSL_VERSION, of its LTS branch, static, for
# 64-bit Windows, in $SOFTWARE_DIR/openssl-$OPENSSL_VERSION-mingw, cross-built with the
# gcc-mingw component (docs/toolchain.md, "Components for Windows"). It is the TLS of
# libpq-mingw; Qt for Windows uses Windows' own (Schannel).
#
# The tarball is checked against its signature, made by a subkey of OpenSSL's signing
# key, fetched once from keyserver.ubuntu.com by the fingerprint fixed below, which
# gpgv's VALIDSIG must name.
#
# System requirements: make and perl.
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(dirname "$0")/../lib/common.sh"

PREFIX="$SOFTWARE_DIR/openssl-$OPENSSL_VERSION-mingw"
# OpenSSL's signing key (openssl-library.org/source)
OPENSSL_KEY=B146647E45A7B33947AB226B2A2C87D161692D40
NAME=openssl-mingw
VERSION="$OPENSSL_VERSION"
PREFIXES=("$PREFIX")

install() {
    local url tarball keyring src build
    require gcc-mingw

    url="https://github.com/openssl/openssl/releases/download/openssl-$OPENSSL_VERSION/openssl-$OPENSSL_VERSION.tar.gz"
    tarball="$SRC/openssl-$OPENSSL_VERSION.tar.gz"
    keyring="$SRC/openssl-keyring.gpg"
    download_signed "$url" "$tarball" .asc
    fetch_key "$OPENSSL_KEY" "$keyring"
    check_signature "$keyring" "$tarball" "$OPENSSL_KEY" .asc
    src="$SRC/openssl-$OPENSSL_VERSION"
    [[ -d "$src" ]] || tar -xf "$tarball" -C "$SRC"

    build="$SRC/openssl-$OPENSSL_VERSION-build-mingw"
    rm -rf "$build" "$PREFIX"
    mkdir -p "$build"
    (
        cd "$build"
        # no-module: the providers (legacy) inside libcrypto, not as DLLs
        "$src/Configure" mingw64 no-shared no-module no-tests no-docs \
            --cross-compile-prefix="$MINGW_DIR/bin/x86_64-w64-mingw32-" \
            --prefix="$PREFIX" --libdir=lib
        make -j"$(nproc)"
        make install_sw
    )
    rm -rf "$build"
}

component_main "$@"
