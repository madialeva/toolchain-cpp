#!/usr/bin/env bash
# The buf component: buf $BUF_VERSION, the lint and breaking-change checks of Protobuf
# contracts, a single binary in $SOFTWARE_DIR/buf-$BUF_VERSION/bin (docs/toolchain.md,
# "Libraries"), checked against the checksums of its release.
#
# System requirements: curl.
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(dirname "$0")/../lib/common.sh"

PREFIX="$SOFTWARE_DIR/buf-$BUF_VERSION"
NAME=buf
VERSION="$BUF_VERSION"
PREFIXES=("$PREFIX")

install() {
    local url="https://github.com/bufbuild/buf/releases/download/v$BUF_VERSION"
    local binary="$SRC/buf-$BUF_VERSION-Linux-x86_64" expected actual
    download "$url/buf-Linux-x86_64" "$binary"
    expected="$(curl -fsSL "$url/sha256.txt" | awk '$2 == "buf-Linux-x86_64" {print $1}')" ||
        die "cannot download $url/sha256.txt"
    actual="$(sha256sum "$binary" | cut -d' ' -f1)"
    [[ -n "$expected" && "$expected" == "$actual" ]] ||
        die "checksum mismatch for $binary: remove it and run this again"
    rm -rf "$PREFIX"
    mkdir -p "$PREFIX/bin"
    cp "$binary" "$PREFIX/bin/buf"
    chmod +x "$PREFIX/bin/buf"
}

component_main "$@"
