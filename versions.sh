# The version of every component, in one place (docs/toolchain.md). Each one can be
# overridden from the environment, for example GCC_VERSION=16.2.0 ./install.sh gcc.
#
# A version names the prefix it is installed in (gcc-16.2.0, Qt/6.12.0, ...), and the
# projects' presets name those prefixes: changing one is a MAJOR version of this
# repository (VERSION).
# shellcheck shell=bash

GCC_VERSION="${GCC_VERSION:-16.2.0}"                   # gcc, and gcc-mingw's GCC
BINUTILS_VERSION="${BINUTILS_VERSION:-2.47}"           # gcc-mingw
MINGW_VERSION="${MINGW_VERSION:-14.0.0}"               # gcc-mingw
QT_VERSION="${QT_VERSION:-6.12.0}"                     # qt, qt-wasm, qt-static
EMSDK_VERSION="${EMSDK_VERSION:-5.0.5}"                # qt-wasm: the one its kit recommends
POSTGRESQL_VERSION="${POSTGRESQL_VERSION:-18.6}"       # libpq-static
LIBPQXX_VERSION="${LIBPQXX_VERSION:-8.0.2}"            # libpqxx
HTTPLIB_VERSION="${HTTPLIB_VERSION:-0.61.0}"           # cpp-httplib
PROTOBUF_VERSION="${PROTOBUF_VERSION:-36.2}"           # protobuf, protobuf-wasm
BUF_VERSION="${BUF_VERSION:-1.74.0}"                   # buf
