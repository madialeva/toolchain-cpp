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
| Signature, against a key pinned by its fingerprint: fetched once from keyserver.ubuntu.com, and gpgv's `VALIDSIG` must name that primary key, so a good signature of another key fails | mingw-w64 |
| The SHA-256 its server publishes (`<url>.sha256`) | Qt's tarballs, PostgreSQL |
| The checksums of the release | buf |
| A shallow clone of the version's tag from the official repository | libpqxx, cpp-httplib, protobuf |

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
  - it builds with no extra flags a C++26 test program the script carries: four
    `std::jthread`s that count in a `thread_local` variable and catch an
    exception, a `shared_ptr` copied into each, and pack indexing;
  - it fails, naming them, if the program imports any DLL other than
    `KERNEL32.dll`, `ucrtbase.dll` and the UCRT's `api-ms-win-crt-*.dll` (the
    cross `objdump -p`), or carries symbols of the emulated TLS (`__emutls*`, with
    `nm`);
  - with Wine in the PATH, it runs the program and compares its output and exit
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

### 2.5 libpq-static

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

### 2.6 Libraries

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
