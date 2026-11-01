#!/usr/bin/env bash
# The gcc component: GCC from the GNU sources, the native compiler of the projects (C
# and C++, C++26 with reflection), in $SOFTWARE_DIR/gcc-$GCC_VERSION
# (docs/toolchain.md, "gcc").
#
# It uses the configure options of the official gcc Docker image the projects' CI runs
# in (gcc:<version>-trixie), so that the local compiler and the CI's are the same:
# --disable-multilib and the default full bootstrap. Only C and C++ are built; the
# image also builds Fortran and Go, which change nothing for C++.
#
# The assembler and the linker are fixed to the `as` and `ld` found in the PATH
# (--with-as, --with-ld): GCC checks their features when it is configured, and it must
# not pick others later if the PATH changes (on EL9 with gcc-toolset-14 enabled,
# binutils 2.41 instead of the system's 2.35). If those binutils are removed, build
# this GCC again.
#
# A prefix that is a symbolic link to a GCC of the same version counts as installed:
# the official image's, in the CI of the projects.
#
# System requirements: a C++ compiler to build it (the system's g++), make, m4, bzip2,
# xz, curl, gpgv, and about 11 GB of free disk for the build trees, removed at the end.
# The full bootstrap takes about an hour with 12 cores.
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(dirname "$0")/../lib/common.sh"

NAME=gcc
VERSION="$GCC_VERSION"
PREFIXES=("$GCC_DIR")
is_installed() { gcc_installed; }

install() {
    local as_path ld_path tarball src build
    as_path="$(command -v as)" || die "no assembler (as, binutils) in the PATH"
    ld_path="$(command -v ld)" || die "no linker (ld, binutils) in the PATH"

    # The release and its signature, checked against the GNU keyring
    tarball="$SRC/gcc-$GCC_VERSION.tar.xz"
    download_signed "https://ftpmirror.gnu.org/gcc/gcc-$GCC_VERSION/gcc-$GCC_VERSION.tar.xz" "$tarball"
    gnu_keyring
    check_signature "$GNU_KEYRING" "$tarball"

    # GMP, MPFR, MPC and ISL are built in the source tree: no -devel packages needed
    src="$SRC/gcc-$GCC_VERSION"
    build="$SRC/gcc-$GCC_VERSION-build"
    rm -rf "$src" "$build" "$GCC_DIR"
    tar -xf "$tarball" -C "$SRC"
    (cd "$src" && ./contrib/download_prerequisites)

    mkdir -p "$build"
    (
        cd "$build"
        "$src/configure" --prefix="$GCC_DIR" --disable-multilib --enable-languages=c,c++ \
            --with-as="$as_path" --with-ld="$ld_path"
        make -j"$(nproc)"
        make install-strip
    )

    # The tarball stays for a later rebuild; the source and build trees take several GB
    rm -rf "$src" "$build"
}

component_main "$@"
