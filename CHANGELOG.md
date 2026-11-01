# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

First version, to be released as 0.1.0: the toolchain scripts of guita, as
components.

### Added

- `install.sh` installs the components of the toolchain by name, with the
  components they need, without root, into `software/` in the repository (or
  `SOFTWARE_DIR`). `--list` shows every component with its version and whether it
  is installed, and `--dry-run` what would be installed.
- Eleven components, each also runnable alone from `components/`:
  - `gcc`: GCC 16.2.0 from the GNU sources, as the official `gcc:16.2.0-trixie`
    image builds it;
  - `gcc-mingw`: a GCC 16.2.0 cross compiler for 64-bit Windows, with binutils
    2.47 and mingw-w64 14.0.0, whose executables need only system DLLs, and its
    check with Wine;
  - `qt` and `qt-wasm`: the official Qt 6.12.0 desktop and WebAssembly kits, with
    emsdk 5.0.5;
  - `qt-static`: a static Qt 6.12.0 for Linux, one kit for every project;
  - `libpq-static`, `libpqxx`, `cpp-httplib`, `protobuf`, `protobuf-wasm` and
    `buf`.
- Every download is checked before anything is built: signatures (with pinned
  keys where the origin publishes no keyring), published checksums or git tags.
- A component already installed is never built again, and an installation that
  did not finish starts again from scratch.
- `versions.sh` holds the version of every component.
- How a project cloned next to the repository uses it from its presets, scripts
  and CI, in the README and `docs/toolchain.md`.
- Continuous integration on GitHub Actions: the version against the branch, the
  syntax of the scripts, and a test installation in the official GCC image.
