#!/usr/bin/env bash
# The qt-static component: Qt $QT_VERSION, static, for Linux, in
# $SOFTWARE_DIR/Qt/$QT_VERSION-static, built with the native GCC from Qt's sources
# (docs/toolchain.md, "qt-static"). It is the kit of the projects' self-contained
# executables.
#
# One kit for every project, with the union of what they use: qtbase with Qt SQL and
# Qt's own SQLite, qtshadertools, qtsvg, qtdeclarative, qtwebsockets and the Linguist
# tools of qttools. A kit that lacks a module of the list is removed and built again
# whole: modules built against another configuration of qtbase must not be mixed.
#
# Every Qt feature that would otherwise depend on the -devel packages installed is
# fixed here, so that the result does not change with them: X11 (xcb) only, Qt's own
# copies of the libraries that not every desktop has (SQLite among them), and the
# system's of those that every desktop has (zlib, freetype with fontconfig, OpenGL,
# X11). OpenSSL and D-Bus are loaded at run time. The Qt tools that run during a build
# (moc, qmlcachegen, lrelease, ...) get a run path to the native GCC's libstdc++.
#
# Every tarball is checked against the SHA-256 published by download.qt.io before
# anything is built or removed; the tarballs and sources stay in $SOFTWARE_DIR/src.
#
# System requirements: CMake 3.25+, Ninja, curl, xz, and the development packages of
# OpenSSL, libxcb and xcb-util (-wm, -image, -keysyms, -renderutil, -cursor),
# libxkbcommon and libxkbcommon-x11, fontconfig, freetype, Mesa (GL and EGL), X11 and
# zlib. It takes about half an hour with 12 cores, and close to 40 GB of free disk at
# its peak for the build trees, removed after each module.
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(dirname "$0")/../lib/common.sh"

QT_PREFIX="$SOFTWARE_DIR/Qt/$QT_VERSION-static"
NAME=qt-static
VERSION="$QT_VERSION"
PREFIXES=("$QT_PREFIX")

# The modules, in build order (qtsvg before qtdeclarative, an optional dependency of
# it), and the files that mark each one as installed in the kit
QT_MODULES=(qtbase qtshadertools qtsvg qtdeclarative qtwebsockets qttools)
declare -A QT_MARKERS=(
    [qtbase]="lib/cmake/Qt6Core lib/cmake/Qt6Sql plugins/sqldrivers/libqsqlite.a"
    [qtshadertools]="lib/cmake/Qt6ShaderTools"
    [qtsvg]="lib/cmake/Qt6Svg"
    [qtdeclarative]="lib/cmake/Qt6Quick"
    [qtwebsockets]="lib/cmake/Qt6WebSockets"
    [qttools]="lib/cmake/Qt6LinguistTools"
)

# qtbase: static, release, and every system-dependent feature fixed
QTBASE_OPTIONS=(
    -static -release -nomake examples -nomake tests
    # X11 only, with its GLX and EGL integrations; no Wayland nor embedded backends
    -qpa xcb -default-qpa xcb -xcb -xcb-xlib -xkbcommon -bundled-xcb-xinput
    -no-feature-xcb-sm -no-feature-wayland -no-eglfs -no-linuxfb -no-kms -no-gbm
    -no-feature-vnc -no-feature-vkkhrdisplay -no-feature-vulkan
    -no-libudev -no-libinput -no-mtdev -no-tslib -no-evdev
    -opengl desktop -egl
    # Qt's own copies of what not every desktop has, or has in another version
    -qt-pcre -qt-harfbuzz -qt-libpng -qt-libjpeg -qt-doubleconversion
    -no-feature-system-libb2 -no-feature-system-textmarkdownreader
    # The system's of what every desktop has. fontconfig loads the system's
    # freetype, so a copy of Qt's own would leave two in the process
    -system-zlib -system-freetype -fontconfig
    # Loaded at run time: libssl for wss:// and libdbus-1 (accessibility, portals).
    # -dbus-runtime does not reach CMake in 6.12.0, hence the feature itself
    -openssl-runtime -no-feature-dbus-linked
    # Qt SQL with the SQLite driver only, on Qt's own copy of SQLite; every other
    # driver off, or it would follow the -devel installed
    -feature-sql -sql-sqlite -qt-sqlite
    -no-sql-db2 -no-sql-ibase -no-sql-mimer -no-sql-mysql -no-sql-oci -no-sql-odbc
    -no-sql-psql
    # Used by no project: ICU (Qt has its own CLDR data), GLib (Qt's own event loop),
    # Widgets (and with it the GTK theme), printing (and with it CUPS), session
    # management, and the network extras that would link more libraries
    -no-icu -no-glib -no-widgets -no-feature-printsupport
    -no-feature-sessionmanager -no-feature-gssapi -no-feature-brotli
    -no-feature-zstd -no-libproxy -no-journald
)
# qttools: the Linguist tools only (lupdate, lrelease). Its graphical applications
# need Widgets, and qdoc needs libclang
QTTOOLS_OPTIONS=(
    -no-feature-assistant -no-feature-designer -no-feature-distancefieldgenerator
    -no-feature-kmap2qmap -no-feature-pixeltool -no-feature-qdbus -no-feature-qdoc
    -no-feature-clang -no-feature-qev -no-feature-qtdiag -no-feature-qtplugininfo
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
    use_native_gcc
    cmake_args=(-DCMAKE_C_COMPILER="$GCC_DIR/bin/gcc" -DCMAKE_CXX_COMPILER="$GCC_DIR/bin/g++"
        -DCMAKE_EXE_LINKER_FLAGS="-Wl,-rpath,$LIBSTDCXX_DIR")

    if [[ -d "$QT_PREFIX" ]]; then
        say "the static Qt kit in $QT_PREFIX is incomplete: it is built again whole"
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
        build="$qt_src/build-$module"
        rm -rf "$build"
        mkdir -p "$build"
        (
            cd "$build"
            case "$module" in
                qtbase) "$src/configure" -prefix "$QT_PREFIX" "${QTBASE_OPTIONS[@]}" -- "${cmake_args[@]}" ;;
                qttools) "$QT_PREFIX/bin/qt-configure-module" "$src" "${QTTOOLS_OPTIONS[@]}" -- "${cmake_args[@]}" ;;
                *) "$QT_PREFIX/bin/qt-configure-module" "$src" -- "${cmake_args[@]}" ;;
            esac
            cmake --build . --parallel "$(nproc)"
            cmake --install .
        )
        rm -rf "$build"
        say "$module $QT_VERSION installed in $QT_PREFIX"
    done
}

component_main "$@"
