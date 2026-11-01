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
- **`std::print` needs `-lstdc++exp`** on Windows: it writes to the console
  through `std::__open_terminal` and `std::__write_to_terminal`, which GCC 16 still
  keeps in `libstdc++exp.a`. The test program prints with `std::format` instead.

## 3. Versions

`versions.sh` holds the version of every component; each one can be overridden
from the environment (`GCC_VERSION=16.2.0 ./install.sh gcc`). The repository's
own version is in `VERSION`, with SemVer read from the point of view of a
project:

- **MAJOR:** the project must change its presets or scripts, because a component
  or a prefix changes its name (a new GCC or Qt release);
- **MINOR:** new components or options, the existing ones untouched;
- **PATCH:** a script is fixed without changing what it installs.

Before 1.0.0 anything may change.
