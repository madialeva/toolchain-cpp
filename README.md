# toolchain-cpp

Scripts that build, without root, the toolchain of C++ projects on GCC 16.2: the
native GCC and a cross compiler for Windows, the Qt 6.12 kits and the libraries
the projects link. Each piece is a component, installed by name; everything goes
to `software/`, inside this repository.

It serves the maintainer's projects, such as
[guita](https://github.com/madialeva/guita) and
[gambasse](https://github.com/madialeva/gambasse), which clone it next to them and
keep only their own build scripts and presets. The technical reference is
[docs/toolchain.md](docs/toolchain.md).

## Components

| Component | What it installs | Prefix in `software/` | Needs |
|---|---|---|---|
| `gcc` | GCC 16.2.0, C and C++, built from the GNU sources | `gcc-16.2.0` | the system's C++ compiler |
| `gcc-mingw` | GCC 16.2.0 cross compiler for 64-bit Windows, with binutils 2.47 and mingw-w64 14.0.0 | `gcc-16.2.0-mingw` | `gcc` |
| `qt` | Qt 6.12.0 desktop kit, with qttasktree and qtwebsockets | `Qt/6.12.0/gcc_64` | python3 with venv |
| `qt-wasm` | Qt 6.12.0 `wasm_singlethread` kit, emsdk 5.0.5 and Python 3.12 (uv) | `Qt/6.12.0/wasm_singlethread`, `emsdk` | `qt` |
| `qt-static` | Qt 6.12.0, static, for Linux | `Qt/6.12.0-static` | `gcc` |
| `libpq-static` | libpq of PostgreSQL 18.6, static | `libpq-18.6-static` | `gcc` |
| `libpqxx` | libpqxx 8.0.2 | `libpqxx-8.0.2` | `gcc` |
| `cpp-httplib` | cpp-httplib 0.61.0 | `cpp-httplib-0.61.0` | `gcc` |
| `protobuf` | protobuf 36.2 with abseil and `protoc` | `protobuf-36.2` | `gcc` |
| `protobuf-wasm` | protobuf 36.2 with abseil, for WebAssembly | `protobuf-36.2-wasm` | `qt-wasm` |
| `buf` | buf 1.74.0 | `buf-1.74.0` | — |

## Getting started

```sh
git clone https://github.com/madialeva/toolchain-cpp.git ~/src/toolchain-cpp
cd ~/src/toolchain-cpp
./install.sh --list              # every component, its version and whether it is installed
./install.sh --dry-run qt-static # what would be installed: gcc qt-static
./install.sh gcc qt              # install them, with the components they need
```

A component already installed is not built again, and an installation that did
not finish starts again from scratch. `SOFTWARE_DIR` installs somewhere else
than `software/`.

What is built carries absolute paths: do not move the repository after building,
and do not run `git clean -xdf` in it, which would remove everything built.

## Versions

`versions.sh` holds the version of every component. The repository has its own
version (`VERSION`, tags `vX.Y.Z`), which the projects pin: a MAJOR version means
that a project must change its presets or scripts to move to it, such as with a
new GCC or Qt release.

## License

Released under the **MIT License**. See [LICENSE.md](LICENSE.md).
