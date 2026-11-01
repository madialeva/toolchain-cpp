#!/usr/bin/env bash
# The gcc-mingw component: a GCC cross compiler that runs on Linux and builds 64-bit
# Windows executables (x86_64-w64-mingw32), in $SOFTWARE_DIR/gcc-$GCC_VERSION-mingw
# (docs/toolchain.md, "gcc-mingw"):
#   - binutils $BINUTILS_VERSION   assembler, linker and the other binary tools
#   - mingw-w64 $MINGW_VERSION     Windows and C runtime headers, the C runtime (CRT)
#                                  and winpthreads
#   - GCC $GCC_VERSION, C and C++  the release of the native compiler, built with it
#
# The target is fixed: Windows 10 or later (the minimum of Qt 6.12) with the Universal
# C Runtime (UCRT), SEH exceptions, POSIX threads on winpthreads and GCC's native
# Windows TLS for thread_local. Only the static runtime is built (libgcc, libstdc++,
# winpthreads): whatever the compiler builds carries it inside, with no extra flags,
# and needs only DLLs of the system (KERNEL32.dll and the UCRT's).
#
# The prefix is also the sysroot: mingw-w64 goes to x86_64-w64-mingw32/{include,lib},
# next to libstdc++, and a relative link `mingw` points there, where GCC looks for the
# system headers and libraries. The compilers find everything relative to themselves,
# so the directory can be moved.
#
# Every download is checked against its signature before anything is built or removed:
# GCC and binutils with the GNU keyring, and mingw-w64 with the key of its release
# manager, fetched once from keyserver.ubuntu.com by the fingerprint fixed below.
#
# The installation ends checking the compiler: it builds a C++26 test program with
# threads, thread_local, exceptions and shared_ptr, fails if the program imports any
# DLL that is not of the system or uses the emulated TLS, and runs it with Wine if
# there is one, in a Wine prefix of its own (~/.wine is not touched) and without a
# display.
#
#   components/gcc-mingw.sh                       install, then check
#   components/gcc-mingw.sh --check               only check the installed compiler
#   components/gcc-mingw.sh --check <executable>  only check the DLLs and the TLS of
#                                                 <executable>
#
# System requirements: those of the gcc component, and about 9 GB of free disk for the
# build trees, removed at the end. It takes about a quarter of an hour with 12 cores;
# the compiler takes 0.5 GB.
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(dirname "$0")/../lib/common.sh"

TARGET=x86_64-w64-mingw32
PREFIX="$SOFTWARE_DIR/gcc-$GCC_VERSION-mingw"
# The key that signs the mingw-w64 releases (Jonathan Yong)
MINGW_KEY=CAF5641F74F7DFBA88AE205693BDB53CD4EBC740

NAME=gcc-mingw
VERSION="$GCC_VERSION"
PREFIXES=("$PREFIX")
USAGE="[--status | --check [<executable>]]"

# check_executable <executable>: fails, naming them, if <executable> imports a DLL that
# is not of the system, the Windows kernel's or the UCRT's (objdump -p), or carries
# symbols of the emulated TLS (nm: an executable without symbols shows none)
check_executable() {
    local exe="$1" problems=() dlls dll symbol
    dlls="$(LC_ALL=C "$PREFIX/bin/$TARGET-objdump" -p "$exe" | sed -n 's/^[[:space:]]*DLL Name: //p')"
    while read -r dll; do
        case "${dll,,}" in
            "" | kernel32.dll | ucrtbase.dll | api-ms-win-crt-*.dll) ;;
            *) problems+=("imports $dll") ;;
        esac
    done <<<"$dlls"
    while read -r symbol; do
        problems+=("uses the emulated TLS: $symbol")
    done < <(LC_ALL=C "$PREFIX/bin/$TARGET-nm" "$exe" 2>/dev/null | awk '$NF ~ /^__emutls/ {print $NF}')

    if ((${#problems[@]})); then
        echo "error: $exe does not pass the check:" >&2
        printf '  %s\n' "${problems[@]}" >&2
        return 1
    fi
    say "$exe imports only these DLLs of the system:"
    sed 's/^/     /' <<<"$dlls"
}

# The test program and what it prints: threads that count in a thread_local variable
# and catch an exception, a shared_ptr copied into each, and a C++26 feature
EXPECTED="threads=4 thread_local=4000 exceptions=4 shared_ptr=1 c++26=26"
write_test_program() {
    cat <<'EOF'
#include <atomic>
#include <cstdio>
#include <format>
#include <memory>
#include <stdexcept>
#include <thread>
#include <vector>

namespace {

thread_local int counter = 0;

// Pack indexing, new in C++26
template <typename... Ts>
constexpr auto first(Ts... values) {
    return values...[0];
}

}  // namespace

int main() {
    constexpr int threads = 4, rounds = 1000;
    std::atomic<int> total = 0, caught = 0;
    auto shared = std::make_shared<int>(26);
    {
        std::vector<std::jthread> workers;
        for (int i = 0; i < threads; ++i) {
            workers.emplace_back([&total, &caught, shared] {
                for (int round = 0; round < rounds; ++round) {
                    ++counter;
                }
                total += counter;
                try {
                    throw std::runtime_error("thrown in a thread");
                } catch (const std::runtime_error &) {
                    ++caught;
                }
            });
        }
    }
    // Not std::println: on Windows it needs libstdc++exp.a (-lstdc++exp)
    std::fputs(std::format("threads={} thread_local={} exceptions={} shared_ptr={} c++26={}\n",
                           threads, total.load(), caught.load(), shared.use_count(),
                           first(*shared, 0))
                   .c_str(),
               stdout);
    return total == threads * rounds && caught == threads && shared.use_count() == 1 ? 0 : 1;
}
EOF
}

# The check's directory: the test program, and the Wine prefix and its log
check_dir=""
cleanup_check() {
    if [[ -d "$check_dir/wine" ]]; then
        WINEPREFIX="$check_dir/wine" wineserver -k 2>/dev/null || true
        WINEPREFIX="$check_dir/wine" wineserver -w 2>/dev/null || true
    fi
    rm -rf "$check_dir"
}

# check_compiler: builds the test program with no extra flags, checks it, and runs it
# with Wine if it is in the PATH
check_compiler() {
    local output status=0
    check_dir="$(mktemp -d)"
    trap cleanup_check EXIT
    cd "$check_dir"
    write_test_program >test.cpp
    "$PREFIX/bin/$TARGET-g++" -std=c++26 -O2 -o test.exe test.cpp
    check_executable test.exe

    if ! command -v wine >/dev/null; then
        echo ">> warning: no wine in the PATH: test.exe was not run" >&2
        return
    fi
    # A prefix of its own, no display so that no window opens, no offer to install
    # Mono or Gecko, and a time limit should the program hang
    output="$(env -u DISPLAY -u WAYLAND_DISPLAY -u WINEARCH WINEPREFIX="$check_dir/wine" \
        WINEDEBUG=-all WINEDLLOVERRIDES="mscoree,mshtml=" timeout 120 wine test.exe \
        2>wine.log)" || status=$?
    output="${output//$'\r'/}"
    if ((status != 0)) || [[ "$output" != "$EXPECTED" ]]; then
        echo "error: test.exe failed under $(wine --version) (exit status $status), printing:" >&2
        sed 's/^/  /' <<<"$output" >&2
        echo "instead of:" >&2
        echo "  $EXPECTED" >&2
        tail -n 20 wine.log >&2
        exit 1
    fi
    say "test.exe under $(wine --version): $output"
    say "the cross compiler in $PREFIX works"
}

install() {
    local gcc_tarball binutils_tarball mingw_tarball mingw_keyring work mingw_src build_cc tarball
    require gcc

    # The sources, checked before anything is built or removed
    gcc_tarball="$SRC/gcc-$GCC_VERSION.tar.xz"
    binutils_tarball="$SRC/binutils-$BINUTILS_VERSION.tar.xz"
    mingw_tarball="$SRC/mingw-w64-v$MINGW_VERSION.tar.bz2"
    mingw_keyring="$SRC/mingw-w64-keyring.gpg"
    download_signed "https://ftpmirror.gnu.org/gcc/gcc-$GCC_VERSION/gcc-$GCC_VERSION.tar.xz" "$gcc_tarball"
    download_signed "https://ftpmirror.gnu.org/binutils/binutils-$BINUTILS_VERSION.tar.xz" "$binutils_tarball"
    download_signed "https://downloads.sourceforge.net/project/mingw-w64/mingw-w64/mingw-w64-release/mingw-w64-v$MINGW_VERSION.tar.bz2" \
        "$mingw_tarball"
    gnu_keyring
    fetch_key "$MINGW_KEY" "$mingw_keyring"
    check_signature "$GNU_KEYRING" "$gcc_tarball"
    check_signature "$GNU_KEYRING" "$binutils_tarball"
    check_signature "$mingw_keyring" "$mingw_tarball" "$MINGW_KEY"

    # The compilers and flags of the environment are not meant for Windows, and the
    # configure scripts of mingw-w64 would take them
    unset CC CXX CPP CFLAGS CXXFLAGS CPPFLAGS LDFLAGS

    # The source and build trees, apart from those of the gcc component. GMP, MPFR, MPC
    # and ISL are built in the GCC source tree, as in the native compiler
    work="$SRC/gcc-$GCC_VERSION-mingw-build"
    rm -rf "$work"
    mkdir -p "$work"
    cd "$work"
    for tarball in "$gcc_tarball" "$binutils_tarball" "$mingw_tarball"; do
        tar -xf "$tarball"
    done
    (cd "gcc-$GCC_VERSION" && ./contrib/download_prerequisites)
    mingw_src="$work/mingw-w64-v$MINGW_VERSION"

    # Every download is checked: only now does an install that did not finish go away
    rm -rf "$PREFIX"
    # The cross tools are found by name (x86_64-w64-mingw32-gcc, ...), and the system may
    # have others of an older release
    export PATH="$PREFIX/bin:$PATH"
    build_cc=(CC="$GCC_DIR/bin/gcc" CXX="$GCC_DIR/bin/g++")

    # 1. binutils
    mkdir build-binutils
    (
        cd build-binutils
        "../binutils-$BINUTILS_VERSION/configure" --prefix="$PREFIX" --target="$TARGET" \
            --with-sysroot="$PREFIX" "${build_cc[@]}"
        make -j"$(nproc)"
        make install-strip
    )

    # 2. The mingw-w64 headers, with the UCRT and Windows 10 as defaults, and the link to
    # them where GCC looks for the system headers and libraries (<sysroot>/mingw)
    mkdir build-headers
    (
        cd build-headers
        "$mingw_src/mingw-w64-headers/configure" --prefix="$PREFIX/$TARGET" --host="$TARGET" \
            --with-default-msvcrt=ucrt --with-default-win32-winnt=0x0A00
        make install
    )
    ln -s "$TARGET" "$PREFIX/mingw"

    # 3. The compiler alone (all-gcc), to build the C runtime with it. POSIX threads,
    # native TLS and the static runtime only; libstdc++'s steady_clock and sleeps on the
    # clock_gettime and nanosleep of winpthreads, instead of the wall clock
    mkdir build-gcc
    (
        cd build-gcc
        "../gcc-$GCC_VERSION/configure" --prefix="$PREFIX" --target="$TARGET" \
            --with-sysroot="$PREFIX" --enable-languages=c,c++ --disable-multilib \
            --enable-threads=posix --enable-tls --disable-shared --enable-libstdcxx-time=yes \
            "${build_cc[@]}"
        make -j"$(nproc)" all-gcc
        make install-gcc
    )

    # 4. The C runtime, 64-bit only, with the UCRT as libmsvcrt.a
    mkdir build-crt
    (
        cd build-crt
        "$mingw_src/mingw-w64-crt/configure" --prefix="$PREFIX/$TARGET" --host="$TARGET" \
            --enable-lib64 --disable-lib32 --with-default-msvcrt=ucrt
        make -j"$(nproc)"
        make install
    )

    # 5. winpthreads, static only: its configure links no program, so it does not need
    # libgcc yet
    mkdir build-winpthreads
    (
        cd build-winpthreads
        "$mingw_src/mingw-w64-libraries/winpthreads/configure" --prefix="$PREFIX/$TARGET" \
            --host="$TARGET" --disable-shared --enable-static
        make -j"$(nproc)"
        make install
    )

    # 6. The rest of GCC: libgcc, libstdc++ and the other runtime libraries
    (
        cd build-gcc
        make -j"$(nproc)"
        make install-strip
    )

    # The tarballs stay for a later rebuild; the source and build trees take several GB
    cd "$SRC"
    rm -rf "$work"
}

after_install() { check_compiler; }

case "${1:-}" in
    --check)
        is_installed || die "the gcc-mingw component is not installed in $SOFTWARE_DIR: run ./install.sh gcc-mingw"
        case $# in
            1) check_compiler ;;
            2) check_executable "$2" ;;
            *) component_usage ;;
        esac
        exit
        ;;
esac
component_main "$@"
