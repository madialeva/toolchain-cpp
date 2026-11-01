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

## 2. Versions

`versions.sh` holds the version of every component; each one can be overridden
from the environment (`GCC_VERSION=16.2.0 ./install.sh gcc`). The repository's
own version is in `VERSION`, with SemVer read from the point of view of a
project:

- **MAJOR:** the project must change its presets or scripts, because a component
  or a prefix changes its name (a new GCC or Qt release);
- **MINOR:** new components or options, the existing ones untouched;
- **PATCH:** a script is fixed without changing what it installs.

Before 1.0.0 anything may change.
