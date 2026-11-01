# toolchain-cpp: technical reference

The toolchain of the maintainer's C++ projects on GCC 16.2, built without root.
This document describes the conventions every component follows and, for each
one, what it installs, with which options and why. The components and how to
install them are in the [README](../README.md).

## 1. Conventions

### 1.1 The installation directory

Everything goes to `SOFTWARE_DIR`, by default `software/` in this repository,
which git ignores:

- `software/src/`: the downloads (tarballs, signatures, keyrings, git clones)
  and the source trees kept for later rebuilds;
- one prefix per component, named after its version: `gcc-16.2.0`,
  `Qt/6.12.0/gcc_64`, `Qt/6.12.0-static`, `protobuf-36.2`, ...

The prefixes are the contract with the projects, whose presets and scripts name
them; they are the same as in the `~/software` the projects used before this
repository, so a project moves by changing the base of its paths. The only thing
installed outside `SOFTWARE_DIR` is the Python that uv manages (for `qt-wasm`),
in uv's standard location.

What is built carries absolute paths (run paths to the native GCC's `libstdc++`,
libtool's `.la` files, ...), so the repository is not moved after building, and
`git clean -xdf` must not be run in it.

### 1.2 Components and `install.sh`

Each component is a script in `components/`. `install.sh` holds the table of
the components, in installation order, with what each one needs and its version:

- `./install.sh <component>...` installs them and, first, the components they
  need that are missing;
- `--dry-run` shows that plan without doing anything;
- `--list` shows every component, its version and whether it is installed;
- an unknown name fails before anything is installed.

A component script can run alone: it fails, naming the component, if one it
needs is missing. With `--status` it only answers, with its exit status,
whether it is installed. It defines `NAME`, `VERSION`, `PREFIXES` and
`install`, and ends with `component_main` (`lib/common.sh`).

### 1.3 The stamp

A component writes a stamp, `.toolchain-cpp-installed`, in each of its prefixes
as the last step of its installation:

- a stamped prefix is installed, and never touched again;
- a prefix without the stamp comes from an installation that did not finish: the
  component removes it, after checking its downloads, and installs it from the
  start;
- the Qt kits also check their module list, and are installed again when a
  module is missing;
- `gcc` takes a prefix that is a symbolic link to a GCC of its version as
  installed, without a stamp: the official GCC image's, in the CI of the
  projects.

### 1.4 Checked downloads

Every download is checked before anything is built or removed (`lib/common.sh`):

| How | Used for |
|---|---|
| Signature, against the GNU keyring (`gnu-keyring.gpg`, downloaded once from ftp.gnu.org) | GCC, binutils |
| Signature, against a key pinned by its fingerprint: fetched once from keyserver.ubuntu.com, and gpgv's `VALIDSIG` must name that primary key, so a good signature of another key fails | mingw-w64 (`.sig`), OpenSSL (`.asc`, made by a subkey of OpenSSL's signing key) |
| The SHA-256 its server publishes (`<url>.sha256`) | Qt's tarballs, PostgreSQL |
| The checksums of the release | buf |
| A shallow clone of the version's tag from the official repository | libpqxx, cpp-httplib, protobuf (also their `-mingw` builds) |

A download that does not match fails, naming the file to remove.

### 1.5 The native compiler

The components that build C or C++ use the native GCC (`gcc`), and what they
install with an executable gets a run path to its `libstdc++` (newer than the
system's), so that it runs without `LD_LIBRARY_PATH`. The C++ libraries are
built in C++26, the projects' standard: abseil aliases `std` types depending on
the standard, and must agree with the projects.

## 2. Components

### 2.1 gcc

GCC 16.2.0 for C and C++, the native compiler of the projects, in
`software/gcc-16.2.0`. It is built from the GNU sources, checked against the GNU
keyring, with GMP, MPFR, MPC and ISL built in its source tree (no `-devel`
packages), and configured as the official `gcc:16.2.0-trixie` image the projects'
CI runs in: `--disable-multilib`, the default full bootstrap, C and C++ only. The
local compiler and the CI's are therefore the same release with the same defaults
(upstream GCC enables neither PIE nor the stack protector by default, unlike
distribution packages).

- **Its binutils are fixed.** It takes the `as` and `ld` found in the PATH when it
  is configured (`--with-as`, `--with-ld`), so that a later change of PATH does not
  give it other binutils: on EL9 with gcc-toolset-14 enabled, binutils 2.41
  instead of the system's 2.35. If those binutils are removed, build it again.
- **Its `libstdc++` is newer than the system's** (`GLIBCXX_3.4.29` on EL9): what is
  built with it needs a run path to its directory, as the components do (§1.5),
  and so do the projects' executables.
- **A symbolic link counts as installed.** In the projects' CI, `gcc-16.2.0` is a
  link to the GCC of the official image, and the component does not build anything
  (§1.3).
- **Requirements and cost:** a C++ compiler to build it (the system's `g++`), make,
  m4, bzip2, xz, curl and gpgv. The full bootstrap takes about an hour with 12
  cores (55 minutes on the development machine), with 11 GB of disk at its peak
  for the build trees, removed at the end; the compiler takes 0.3 GB, and its
  tarball 0.1 GB.

### 2.2 gcc-mingw

A GCC 16.2.0 cross compiler for C and C++ that runs on Linux and builds 64-bit
Windows executables (`x86_64-w64-mingw32`), in `software/gcc-16.2.0-mingw`: the
native compiler's release, built with it from the same tarball, with binutils 2.47
and mingw-w64 14.0.0 (the Windows and C runtime headers, the C runtime and
winpthreads). No prebuilt toolchain fits: the MinGW-w64 ones with GCC run on
Windows, llvm-mingw is Clang, and EL9's (`mingw64-gcc` in CodeReady Builder) is
GCC 14. GCC and binutils are checked against the GNU keyring, and mingw-w64 against
the key of its release manager, pinned by its fingerprint (§1.4).

- **The target:**
  - Windows 10 or later, the minimum of Qt 6.12, with the Universal C Runtime
    (`--with-default-msvcrt=ucrt`, `--with-default-win32-winnt=0x0A00`);
  - SEH exceptions;
  - POSIX threads on winpthreads (`--enable-threads=posix`), as in Qt's MinGW,
    MSYS2 and Fedora;
  - GCC 16's native Windows TLS for `thread_local` (`--enable-tls`, which needs
    binutils 2.44 or later) instead of the emulated one;
  - libstdc++'s `steady_clock` and sleeps on the `clock_gettime` and `nanosleep`
    of winpthreads (`--enable-libstdcxx-time=yes`: by default, on mingw,
    `steady_clock` is the wall clock).
- **Static runtime only** (`--disable-shared`, and winpthreads static). What the
  compiler builds carries libgcc, libstdc++ and winpthreads inside, without
  `-static`, and needs only system DLLs: `KERNEL32.dll` and the UCRT's. The price
  is that no two DLLs can share one runtime, so it cannot build a shared Qt for
  Windows; that would take the compiler again with `--enable-shared`.
- **The prefix is also the sysroot** (`--with-sysroot`). mingw-w64 goes to
  `x86_64-w64-mingw32/{include,lib}`, next to libstdc++, and a relative link
  `mingw` points to it, because GCC looks for the system headers and libraries in
  `<sysroot>/mingw/include` and `<sysroot>/mingw/lib`. With the sysroot inside the
  prefix, GCC and ld find it relative to themselves, so the prefix can be moved.
- **The build** has no bootstrap, as no cross compiler does, and runs in a work
  directory of its own in `software/src`, removed at the end:
  1. binutils;
  2. the mingw-w64 headers;
  3. GCC alone (`make all-gcc`);
  4. with it, the C runtime and winpthreads, static because libgcc does not exist
     yet;
  5. the rest of GCC.

  Meanwhile its `bin` goes first in the PATH, since the configure scripts of
  mingw-w64 find the cross tools by name and EL9 has others in `/usr/bin`. The
  compiler's programs (`cc1plus`, `lto1`, ...) link libstdc++ statically, so they
  need no run path. It takes about a quarter of an hour with 12 cores (13 minutes
  on the development machine), with 9 GB of disk at its peak; the compiler takes
  0.5 GB, and the tarballs of binutils and mingw-w64 40 MB more.
- **The check**, at the end of the installation and on demand with
  `components/gcc-mingw.sh --check`:
  - it builds with no extra flags, with `-O2` and with `-O0`, a C++26 test program
    the script carries: four `std::jthread`s that count in a `thread_local`
    variable and catch an exception, copies and moves of `std::logic_error`,
    `std::runtime_error` and `std::range_error` (inlined only when optimized, hence
    the second build), a `shared_ptr` copied into each thread, and pack indexing;
  - it fails, naming them, if the program imports any DLL other than
    `KERNEL32.dll`, `ucrtbase.dll` and the UCRT's `api-ms-win-crt-*.dll` (the
    cross `objdump -p`), or carries symbols of the emulated TLS (`__emutls*`, with
    `nm`);
  - with Wine in the PATH, it runs both builds and compares its output and exit
    status with the expected ones: in a temporary Wine prefix, removed with its
    `wineserver` afterwards, so `~/.wine` is never created or touched; without
    `DISPLAY` or `WAYLAND_DISPLAY`, so no window opens; with Mono and Gecko
    disabled (`WINEDLLOVERRIDES`); and within two minutes. Without Wine it warns
    and skips the run.

  `--check <executable>` applies the DLL and TLS checks to any executable (the
  TLS one needs its symbols).
- **The CMake toolchain file**, `software/gcc-16.2.0-mingw/toolchain.cmake`, builds
  for 64-bit Windows with this compiler: `-DCMAKE_TOOLCHAIN_FILE=` with its path,
  and the prefixes of the `-mingw` components a build needs in
  `CMAKE_FIND_ROOT_PATH` (and `CMAKE_PREFIX_PATH`). It names the compiler and its
  binutils relative to itself, so it moves with the prefix, and it only searches
  for libraries, headers and packages in those roots and the compiler's sysroot,
  never in the Linux system (`CMAKE_FIND_ROOT_PATH_MODE_*` `ONLY`, programs
  `NEVER`). A cross-built Qt kit chain-loads it by its absolute path. It is part
  of the installation: a compiler that lacks it gets it without building
  anything.
- **A patch of libstdc++'s headers** for C++26 exceptions,
  `patches/gcc-16.2.0-mingw-stdexcept.patch`. In C++26
  (`__cpp_lib_constexpr_exceptions`), GCC 16's headers define inline, to make them
  `constexpr`, members of the `<stdexcept>` exceptions that `libstdc++.a` also
  defines out of line. On ELF the inline copies are weak; on PE/COFF they clash
  with the archive's, and a program that copies a `std::runtime_error` without
  optimizing, or emits the vtable of a `std::range_error`, fails to link with
  multiple definitions (GCC bug 125151, still open in 16.2.0). libstdc++ already
  marks the same members of the other exceptions `[[gnu::gnu_inline]]`: the inline
  definition serves constant evaluation and inlining but is never emitted, and a
  call that is not inlined uses the library's symbol. The patch marks the
  remaining ones (the constructors and destructor of `range_error`, and the copy
  and move members of `logic_error` and `runtime_error`) the same way. Every one
  of those symbols is in `libstdc++.a`, so only the headers change.
  - The component applies `patches/gcc-<version>-mingw-*.patch` to the installed
    headers (`x86_64-w64-mingw32/include/c++/<version>`) with `patch -p1` at the
    end of the installation; a patch that does not apply stops it. Like the
    toolchain file, the patches are part of the installation (`patch -R
    --dry-run` tells whether they are applied): a compiler without them gets them
    without building anything, and is checked again.
  - Only the cross compiler: the native one, on ELF, does not need it.
  - A static library built in C++26 with the unpatched headers carries the
    clashing copies and must be rebuilt. The check's `-O0` build fails to link
    with the unpatched headers, so a GCC release that still has the bug and no
    patch does not go unnoticed.
- **`std::print` needs `-lstdc++exp`** on Windows: it writes to the console
  through `std::__open_terminal` and `std::__write_to_terminal`, which GCC 16 still
  keeps in `libstdc++exp.a`. The test program prints with `std::format` instead.

### 2.3 qt and qt-wasm

The official Qt 6.12.0 kits, installed with aqtinstall in a virtual environment
of its own (`software/aqt-venv`), which checks every archive against the checksums
of Qt's repository:

- **`qt`:** the desktop kit for Linux x86_64 (`linux_gcc_64`), in
  `software/Qt/6.12.0/gcc_64`. It is the kit of the projects' native builds, and
  the host (`QT_HOST_PATH`) of the WebAssembly kit.
- **`qt-wasm`:**
  - the `wasm_singlethread` kit, in `software/Qt/6.12.0/wasm_singlethread`;
  - emsdk 5.0.5, in `software/emsdk`. It is the Emscripten release that Qt
    release requires: the component fails if the kit's
    `QT_EMCC_RECOMMENDED_VERSION` (in `QtPublicWasmToolchainHelpers.cmake`) is
    not the version in `versions.sh`, so Qt and emsdk are upgraded together;
  - Python 3.12 through uv, in uv's standard location (`~/.local/bin/python3.12`),
    because Emscripten needs 3.10 or later and EL9 ships 3.9. `EMSDK_PYTHON` must
    point to it, also after sourcing `emsdk_env.sh`, which clears it.

Both kits carry, beyond aqt's default modules, one list that is the union of what
the projects need (`lib/aqt.sh`): qttasktree, a dependency of QmlAssetDownloader;
qtwebsockets, guita's persistent channel; and qtshadertools, whose `qsb` the cross
build of Qt Quick for Windows (`qt-mingw`) needs on the host. A kit that lacks one of them is
installed again whole. Requirements: python3 with venv, and git and uv for
`qt-wasm`. Both take a couple of minutes, most of it downloading.

### 2.4 qt-static

Qt 6.12.0, static, for Linux, in `software/Qt/6.12.0-static`: the kit of the
projects' self-contained executables, built with the native GCC from Qt's
sources. Every tarball is checked against the SHA-256 that download.qt.io
publishes (Qt's tarballs are not signed), and they stay in `software/src/qt-6.12.0`
with their source trees.

- **One kit for every project**, with the union of what they use:
  - qtbase with Qt SQL and the SQLite driver on Qt's own copy of SQLite, every
    other driver off;
  - qtshadertools, qtsvg, qtdeclarative and qtwebsockets;
  - the Linguist tools of qttools.

  The six modules are compiled in order against that prefix
  (`qt-configure-module`), qtsvg before qtdeclarative, an optional dependency of
  it. A kit that lacks a module of the list is removed and built again whole,
  after every download is checked: modules built against another configuration of
  qtbase must not be mixed.
- **Every feature that would otherwise depend on the `-devel` packages installed
  is fixed**, so the result does not change with them:
  - only X11 (xcb, with its GLX and EGL integrations), without Wayland or the
    embedded backends;
  - Qt's own copies of PCRE2, HarfBuzz, libpng, libjpeg, double-conversion, libb2
    and md4c, which not every desktop has;
  - the system's zlib, freetype, fontconfig, OpenGL and X11 libraries;
  - OpenSSL and D-Bus loaded at run time (`-openssl-runtime`,
    `-no-feature-dbus-linked`: `-dbus-runtime` does not reach CMake in 6.12.0);
  - no ICU (Qt has its own CLDR data), GLib, Widgets, printing, session
    management, GSSAPI, Brotli or zstd; qttools builds only its Linguist tools.
- **Qt keeps its default C++ standard.** Unlike abseil's, Qt's ABI does not depend
  on the standard of the application.
- **Its build tools get a run path** to the native GCC's `libstdc++` (§1.5).
- **Requirements and cost:** CMake 3.25+, Ninja, and the development packages of
  OpenSSL, libxcb and xcb-util (`xcb-util`, `-wm`, `-image`, `-keysyms`,
  `-renderutil`, `-cursor`), libxkbcommon and libxkbcommon-x11, fontconfig,
  freetype, Mesa (GL and EGL), X11 and zlib. It takes about half an hour with 12
  cores (28 minutes on the development machine), and close to 40 GB of free disk
  at its peak for the build trees, removed after each module; the kit takes
  1.1 GB, and its tarballs and sources 0.8 GB.

### 2.5 qt-mingw

Qt 6.12.0, static, for 64-bit Windows, in `software/Qt/6.12.0-mingw`: the kit of
the projects' self-contained Windows executables, cross-built with `gcc-mingw`
from the tarballs of `qt-static`, with the desktop kit (`qt`) as its host
(`QT_HOST_PATH`).

- **One kit for every project**, with the union of what they use, as
  `qt-static`: qtbase with Qt SQL and Qt's own SQLite, qtshadertools, qtsvg,
  qtdeclarative and qtwebsockets. The Linguist tools come from the host. A kit
  that lacks a module is removed and built again whole.
- **qtbase** is configured with `gcc-mingw`'s toolchain file and
  `QT_QMAKE_TARGET_MKSPEC=win32-g++`. Windows has no system libraries for Qt's
  third-party code, so the kit carries Qt's own copies of all of them (zlib,
  PCRE2, HarfBuzz, libpng, libjpeg, freetype, double-conversion, SQLite). TLS is
  Windows' own, Schannel, without OpenSSL. Desktop OpenGL besides Direct3D; no
  Vulkan, ICU, D-Bus, GLib, Widgets, printing, GSSAPI, Brotli, zstd or libproxy.
- **The other modules** are configured with the kit's `qt-configure-module`,
  whose `qt.toolchain.cmake` chain-loads `gcc-mingw`'s toolchain file and adds
  the kit to the search roots.
- **Using it:** `-DCMAKE_TOOLCHAIN_FILE=software/Qt/6.12.0-mingw/lib/cmake/Qt6/qt.toolchain.cmake`
  and `-DQT_HOST_PATH=software/Qt/6.12.0/gcc_64` (without `..` in the path), and
  `qt_import_plugins` with `Qt6::QWindowsIntegrationPlugin` (and
  `Qt6::QSchannelBackendPlugin` for `wss://`). A minimal Qt Quick application is
  46 MB without symbols and imports only DLLs of Windows.
- **In Wine** (10.6) such an application aborts on
  `mscms.dll.WcsCreateIccProfile`, which Qt calls when it reads the screen's
  colour profile and Wine does not implement; Windows has had it since Vista.
  Without the sRGB profile of the Wine prefix
  (`windows/system32/spool/drivers/color`) it starts, and draws with Direct3D 11.
- **Requirements and cost:** those of `qt-static` without the X11 packages. It
  takes about half an hour with 12 cores (26 minutes on the development
  machine), with close to 40 GB of disk at its peak; the kit takes 0.7 GB.

### 2.6 libpq-static

libpq of PostgreSQL 18.6, static, in `software/libpq-18.6-static`: the libpq of
the projects' self-contained executables, built with the native GCC. The tarball
is checked against the SHA-256 that ftp.postgresql.org publishes.

- **The client part only.** It is PostgreSQL's client-only installation with
  `configure`: the headers, libpq, the common and port libraries libpq needs
  (`libpgcommon_shlib.a`, `libpgport_shlib.a`, the PIC variants its shared libpq
  is built from), and `pg_config`.
- **With OpenSSL**, and `--without-icu --without-readline --without-zlib`, which
  only the server and the tools use. GSSAPI and LDAP are off by default.
- **No shared libpq.** It is removed after installing, so that `FindPostgreSQL`
  can only find `libpq.a`.
- **Requirements:** make, bzip2 and the development packages of OpenSSL. It takes
  about a minute.

### 2.7 Libraries

Built with the native GCC in C++26, from the official repositories at the tag of
their version (`software/src/<name>-<version>`), each in its own prefix:

- **`libpqxx` 8.0.2**, the C++ client of PostgreSQL: static and PIC, since the
  projects also link it into Qt executables. It needs the development files of
  libpq (`libpq5-devel` or `libpq-devel`).
- **`cpp-httplib` 0.61.0**, an embedded HTTP server, header-only, with zlib
  compression (the development files of zlib). TLS is terminated by a reverse
  proxy, and Brotli and zstd stay off, so that the result does not depend on the
  optional libraries installed.
- **`protobuf` 36.2** with abseil (a submodule, installed next to it): static and
  PIC, with `protoc`, which gets a run path to the native GCC's `libstdc++`. abseil
  is built in C++26, the projects' standard, so that it and the projects agree on
  the `std` types it aliases (`string_view`, `optional`, ...).
- **`protobuf-wasm`**: the same protobuf and abseil for WebAssembly, in
  `software/protobuf-36.2-wasm`, built with the emsdk of `qt-wasm` for its
  `wasm_singlethread` kit: no threads and Emscripten's default exception
  handling, as the kit, and C++26. It has no `protoc`: the native one generates
  the code, and both must be the same version, which the generated code checks.
- **`buf` 1.74.0**, the lint and breaking-change checks of Protobuf contracts: the
  release's binary, checked against the release's `sha256.txt`.

They need CMake 3.25+, Ninja and git. Together they take about six minutes with
12 cores, most of it protobuf and abseil, and their build trees take little disk.

### 2.8 Components for Windows

The libraries of the projects' Windows builds, cross-built with `gcc-mingw`, static,
with no DLL in their prefixes, from the same sources as their Linux components (the
compiler is §2.2, and Qt §2.5):

- **`openssl-mingw`:** OpenSSL 3.5.9, of the 3.5 LTS branch (supported until April
  2030), in `software/openssl-3.5.9-mingw`: the TLS of `libpq-mingw`, since Qt for
  Windows uses Schannel. The release tarball of GitHub, checked against its `.asc`
  (§1.4). `Configure mingw64 no-shared no-module no-tests no-docs` with the cross
  compiler's prefix; `no-module` keeps the `legacy` provider out, which would be a
  DLL. Only the libraries and headers are installed (`make install_sw`).
- **`libpq-mingw`:** libpq of PostgreSQL 18.6, in `software/libpq-18.6-mingw`, from
  the tarball of `libpq-static`: its client part, with `openssl-mingw`
  (`--with-ssl=openssl`) and `--without-icu --without-readline --without-zlib`. On
  mingw PostgreSQL only installs `libpq.dll` and its import library (named
  `libpq.a`), so the component makes the static `libpq.a` itself:
  - from the objects of `src/interfaces/libpq`, but those of the DLL (`*_shlib.o`)
    and its version resource (`win32ver.o`), which would clash with the
    executable's; the DLL and the import library are removed;
  - libpq's own pthread functions for Windows (`pthread-win32.c`), whose
    `pthread_mutex_t` is not winpthreads', are renamed `pq_pthread_*` in all of
    its objects (`objcopy --redefine-syms`): every C++ program links winpthreads,
    and the names would clash;
  - from `libpgcommon_shlib.a` go `exec_shlib.o` and `restricted_token_shlib.o`,
    which libpq does not use: `exec.c` defines `_dowildcard`, which mingw's
    `crt2.o` looks for, so the linker would pull it in, and with it code that
    needs the server's `palloc`.

  libpq needs the `_shlib` variants of `libpgcommon` and `libpgport`: the frontend
  one uses private encoding names and leaves `pg_encoding_to_char` undefined.
- **`protobuf-mingw`:** protobuf 36.2 with abseil, in `software/protobuf-36.2-mingw`,
  without `protoc`: the native one generates the code, as for `protobuf-wasm`.
- **`libpqxx-mingw`:** libpqxx 8.0.2, in `software/libpqxx-8.0.2-mingw`, against
  `libpq-mingw`.
- **`cpp-httplib-mingw`:** cpp-httplib 0.61.0, header-only, in
  `software/cpp-httplib-0.61.0-mingw`, without zlib, TLS, Brotli or zstd: on
  Windows the projects embed the backend, which opens no port.

The three last are built with `cmake_mingw` (`lib/common.sh`): the toolchain file,
Ninja, Release and C++26. A static libpq does not carry its dependencies, so a
project links after it `libpgcommon_shlib.a`, `libpgport_shlib.a`, `libssl.a`,
`libcrypto.a` (`OPENSSL_USE_STATIC_LIBS`) and the Windows libraries `ws2_32`,
`secur32` and `crypt32`; mingw's GCC already links `advapi32`, `shell32`, `user32`
and `kernel32`. With libpqxx, they go to `PostgreSQL::PostgreSQL`'s
`INTERFACE_LINK_LIBRARIES`. An executable built with the five imports only DLLs of
Windows (abseil adds `dbghelp.dll`).

They need make, perl, bzip2, CMake 3.25+, Ninja and git. With 12 cores OpenSSL takes
about a minute and a half, libpq under a minute, and the three last about two
minutes, most of it abseil; the five prefixes take 61 MB.

## 3. Using it from a project

- **Where:** toolchain-cpp is cloned next to the project (`~/src/toolchain-cpp`
  beside `~/src/guita`), at the tag of the version the project pins, and installs
  the components the project lists in its documentation and its CI.
- **Presets:** the project's CMake presets name the prefixes from the project's
  parent directory, with no environment variables:
  `${sourceParentDir}/toolchain-cpp/software/gcc-16.2.0/bin/g++`,
  `${sourceParentDir}/toolchain-cpp/software/Qt/6.12.0/gcc_64`, ... Not
  `${sourceDir}/../toolchain-cpp`: in a cross build (WebAssembly), Qt does not find
  the host's packages, such as its Linguist tools, through a `QT_HOST_PATH` with
  `..`, and `${sourceParentDir}` gives the same path normalized. With toolchain-cpp
  somewhere else, a `CMakeUserPresets.json` in the project changes the paths.
- **Scripts:** the project's scripts take the installation directory from
  `SOFTWARE_DIR`, by default `$ROOT/../toolchain-cpp/software`, `$ROOT` being the
  project's root.
- **Windows:** `-DCMAKE_TOOLCHAIN_FILE=` with
  `${sourceParentDir}/toolchain-cpp/software/Qt/6.12.0-mingw/lib/cmake/Qt6/qt.toolchain.cmake`
  (which chain-loads `gcc-mingw`'s toolchain file) and `QT_HOST_PATH` with the
  desktop kit, or `software/gcc-16.2.0-mingw/toolchain.cmake` without Qt; the
  prefixes of the `-mingw` components the project needs in `CMAKE_FIND_ROOT_PATH`
  and `CMAKE_PREFIX_PATH`; and the native `protoc` for the contract. The libraries
  libpq needs after it are in §2.8.
- **CI (GitHub Actions):** inside the official GCC image (`gcc:16.2.0-trixie`),
  the project and toolchain-cpp are checked out side by side, toolchain-cpp at the
  pinned tag. `software/gcc-16.2.0` is a link to the image's GCC (`/usr/local`),
  which the `gcc` component takes as installed (§1.3), so the job never builds
  GCC. `software/` is cached without that link, keyed by the pinned tag and the
  components; `install.sh` then finds everything installed (§1.3) or installs what
  is missing.

## 4. Versions

`versions.sh` holds the version of every component; each one can be overridden
from the environment (`GCC_VERSION=16.2.0 ./install.sh gcc`). The repository's
own version is in `VERSION`, with SemVer read from the point of view of a
project:

- **MAJOR:** the project must change its presets or scripts, because a component
  or a prefix changes its name (a new GCC or Qt release);
- **MINOR:** new components or options, the existing ones untouched;
- **PATCH:** a script is fixed without changing what it installs.

Before 1.0.0 anything may change.
