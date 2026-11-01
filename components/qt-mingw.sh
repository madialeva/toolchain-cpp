#!/usr/bin/env bash
# The qt-mingw component: Qt $QT_VERSION, static, for 64-bit Windows, in
# $SOFTWARE_DIR/Qt/$QT_VERSION-mingw, cross-built with the gcc-mingw component from
# Qt's sources, with the desktop kit (the qt component) as its host
# (docs/toolchain.md, "qt-mingw"). It is the kit of the projects' self-contained
# Windows executables.
#
# One kit for every project, with the union of what they use: qtbase with Qt SQL and
# Qt's own SQLite, qtshadertools, qtsvg, qtdeclarative and qtwebsockets. The Linguist
# tools come from the host kit. A kit that lacks a module of the list is removed and
# built again whole: modules built against another configuration of qtbase must not be
# mixed.
#
# Windows has no libraries of its system for Qt's third-party code, so the kit carries
# Qt's own copies of all of them; TLS is Windows' own (Schannel), without OpenSSL. The
# configuration follows qt-static where it applies to Windows. Every tarball is checked
# against the SHA-256 published by download.qt.io before anything is built or removed;
# they are the ones of qt-static, in $SOFTWARE_DIR/src/qt-$QT_VERSION.
#
# System requirements: CMake 3.25+, Ninja, curl and xz. It takes about half an hour
# with 12 cores, and tens of GB of free disk at its peak for the build trees, removed
# after each module.
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(dirname "$0")/../lib/common.sh"

QT_PREFIX="$SOFTWARE_DIR/Qt/$QT_VERSION-mingw"
QT_HOST="$SOFTWARE_DIR/Qt/$QT_VERSION/gcc_64"
MINGW_TOOLCHAIN="$SOFTWARE_DIR/gcc-$GCC_VERSION-mingw/toolchain.cmake"
NAME=qt-mingw
VERSION="$QT_VERSION"
PREFIXES=("$QT_PREFIX")

# The modules, in build order (qtsvg before qtdeclarative, an optional dependency of
# it), and the files that mark each one as installed in the kit
QT_MODULES=(qtbase qtshadertools qtsvg qtdeclarative qtwebsockets)
declare -A QT_MARKERS=(
    [qtbase]="lib/cmake/Qt6Core lib/cmake/Qt6Sql plugins/sqldrivers/libqsqlite.a plugins/platforms/libqwindows.a plugins/tls/libqschannelbackend.a"
    [qtshadertools]="lib/cmake/Qt6ShaderTools"
    [qtsvg]="lib/cmake/Qt6Svg"
    [qtdeclarative]="lib/cmake/Qt6Quick"
    [qtwebsockets]="lib/cmake/Qt6WebSockets"
)

# qtbase: static, release, for Windows with the cross compiler, and every feature that
# would otherwise depend on what is installed fixed
QTBASE_OPTIONS=(
    -static -release -nomake examples -nomake tests
    -qt-host-path "$QT_HOST"
    # Qt's own copies of every third-party library: Windows has none for it
    -qt-zlib -qt-pcre -qt-harfbuzz -qt-libpng -qt-libjpeg -qt-freetype -qt-doubleconversion
    -no-feature-system-libb2 -no-feature-system-textmarkdownreader
    # TLS through Windows' Schannel, without OpenSSL
    -schannel -no-openssl
    # Qt SQL with the SQLite driver only, on Qt's own copy of SQLite
    -feature-sql -sql-sqlite -qt-sqlite
    -no-sql-db2 -no-sql-ibase -no-sql-mimer -no-sql-mysql -no-sql-oci -no-sql-odbc
    -no-sql-psql
    # Desktop OpenGL (opengl32.dll) besides Direct3D; no Vulkan (its headers would follow
    # what is installed)
    -opengl desktop -no-feature-vulkan
    # Used by no project, as in qt-static: ICU, D-Bus, GLib, Widgets, printing and the
    # network extras that would link more libraries
    -no-icu -no-dbus -no-glib -no-widgets -no-feature-printsupport
    -no-feature-gssapi -no-feature-brotli -no-feature-zstd -no-libproxy
)

is_installed() {
    local module marker
    installed "$QT_PREFIX" || return 1
    for module in "${QT_MODULES[@]}"; do
        for marker in ${QT_MARKERS[$module]}; do
            [[ -e "$QT_PREFIX/$marker" ]] || return 1
        done
    done
}

install() {
    local qt_src qt_url module tarball src build cmake_args
    require gcc-mingw
    require qt
    # For qtbase: the cross compiler's toolchain file, and the mkspec name for qmake
    cmake_args=(-DCMAKE_TOOLCHAIN_FILE="$MINGW_TOOLCHAIN" -DQT_QMAKE_TARGET_MKSPEC=win32-g++)

    if [[ -d "$QT_PREFIX" ]]; then
        say "the Qt kit for Windows in $QT_PREFIX is incomplete: it is built again whole"
    fi

    # Every source is checked before the kit is removed and any module is built
    qt_src="$SRC/qt-$QT_VERSION"
    qt_url="https://download.qt.io/official_releases/qt/${QT_VERSION%.*}/$QT_VERSION/submodules"
    for module in "${QT_MODULES[@]}"; do
        tarball="$module-everywhere-src-$QT_VERSION.tar.xz"
        download "$qt_url/$tarball" "$qt_src/$tarball"
        check_sha256 "$qt_url/$tarball" "$qt_src/$tarball"
        [[ -d "$qt_src/$module-everywhere-src-$QT_VERSION" ]] || tar -xf "$qt_src/$tarball" -C "$qt_src"
    done

    rm -rf "$QT_PREFIX"
    for module in "${QT_MODULES[@]}"; do
        src="$qt_src/$module-everywhere-src-$QT_VERSION"
        build="$qt_src/build-$module-mingw"
        rm -rf "$build"
        mkdir -p "$build"
        (
            cd "$build"
            case "$module" in
                qtbase) "$src/configure" -prefix "$QT_PREFIX" "${QTBASE_OPTIONS[@]}" -- "${cmake_args[@]}" ;;
                # The kit's qt.toolchain.cmake chain-loads the cross compiler's; passing
                # that one here would hide the kit from find_package
                *) "$QT_PREFIX/bin/qt-configure-module" "$src" ;;
            esac
            cmake --build . --parallel "$(nproc)"
            cmake --install .
        )
        rm -rf "$build"
        say "$module $QT_VERSION installed in $QT_PREFIX"
    done
}

component_main "$@"
