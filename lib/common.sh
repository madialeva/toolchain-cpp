# Common functions of the components (components/*.sh) and install.sh, sourced by each
# of them (docs/toolchain.md, "Conventions").
# shellcheck shell=bash

TOOLCHAIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../versions.sh
source "$TOOLCHAIN_ROOT/versions.sh"

# Everything goes to SOFTWARE_DIR, by default software/ in this repository (ignored by
# git): the downloads and sources in src/, and each component in prefixes of its own
SOFTWARE_DIR="${SOFTWARE_DIR:-$TOOLCHAIN_ROOT/software}"
SRC="$SOFTWARE_DIR/src"
GCC_DIR="$SOFTWARE_DIR/gcc-$GCC_VERSION"

# The stamp a component writes in each of its prefixes as the last step of installing
STAMP=.toolchain-cpp-installed

say() { echo ">> $*"; }
die() {
    echo "error: $*" >&2
    exit 1
}

# installed <prefix>...: whether every <prefix> holds a finished installation
installed() {
    local prefix
    for prefix; do
        [[ -f "$prefix/$STAMP" ]] || return 1
    done
}

# mark_installed <prefix>...: the last step of an installation
mark_installed() {
    local prefix
    for prefix; do
        date -u +%Y-%m-%dT%H:%M:%SZ >"$prefix/$STAMP"
    done
}

# require <component>: fails unless <component> is installed, saying how to install it
require() {
    "$TOOLCHAIN_ROOT/components/$1.sh" --status ||
        die "the $1 component is not installed in $SOFTWARE_DIR: run ./install.sh $1"
}

# component_main "$@": the command line of a component script, which defines NAME,
# VERSION, PREFIXES and install, and may redefine is_installed, define after_install
# (run once the prefixes are stamped) and set USAGE (its own options). With --status
# it only answers, with its exit status, whether the component is installed; without
# arguments it installs the component unless it is installed
is_installed() { installed "${PREFIXES[@]}"; }
component_main() {
    case "${1:-}" in
        --status)
            [[ $# -eq 1 ]] || component_usage
            is_installed
            exit
            ;;
        "") ;;
        *) component_usage ;;
    esac
    if is_installed; then
        say "$NAME $VERSION already installed in ${PREFIXES[*]}"
        exit 0
    fi
    install
    mark_installed "${PREFIXES[@]}"
    say "$NAME $VERSION installed in ${PREFIXES[*]}"
    if declare -F after_install >/dev/null; then
        after_install
    fi
}
component_usage() {
    echo "usage: $0 ${USAGE:-[--status]}" >&2
    exit 2
}

# ---- The native compiler -----------------------------------------------------------

# gcc_installed: the native compiler is installed, or its prefix is a link to a GCC of
# the same version (the official GCC image's, in the CI of the projects)
gcc_installed() {
    if [[ -L "$GCC_DIR" ]]; then
        [[ -x "$GCC_DIR/bin/g++" && "$("$GCC_DIR/bin/g++" -dumpfullversion)" == "$GCC_VERSION" ]]
    else
        installed "$GCC_DIR"
    fi
}

# use_native_gcc: for the components built with the native compiler. Its libstdc++ is
# newer than the system's, so the executables they install get a run path to its
# directory (LIBSTDCXX_DIR)
use_native_gcc() {
    require gcc
    LIBSTDCXX_DIR="$(dirname "$(readlink -f "$("$GCC_DIR/bin/g++" -print-file-name=libstdc++.so)")")"
}

# cmake_native <source> <build> <prefix> [cmake options...]: configures, builds and
# installs a CMake project with the native compiler, in C++26, from an empty build
# directory, so that one configured with another compiler is not reused
cmake_native() {
    local source="$1" build="$2" prefix="$3"
    shift 3
    rm -rf "$build"
    cmake -S "$source" -B "$build" -G Ninja \
        -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$prefix" \
        -DCMAKE_C_COMPILER="$GCC_DIR/bin/gcc" -DCMAKE_CXX_COMPILER="$GCC_DIR/bin/g++" \
        -DCMAKE_CXX_STANDARD=26 -DCMAKE_EXE_LINKER_FLAGS="-Wl,-rpath,$LIBSTDCXX_DIR" "$@"
    cmake --build "$build" -j"$(nproc)"
    cmake --install "$build"
    rm -rf "$build"
}

# ---- Downloads, checked before anything is built or removed --------------------------

# download <url> <file>: downloads <url> into <file> unless it is there
download() {
    local url="$1" file="$2"
    [[ -f "$file" ]] && return
    mkdir -p "$(dirname "$file")"
    curl -fsSL -o "$file.part" "$url" || die "cannot download $url"
    mv "$file.part" "$file"
}

# check_sha256 <url> <file>: checks <file> against the SHA-256 published at <url>.sha256
# (its first field), as download.qt.io and ftp.postgresql.org publish them
check_sha256() {
    local url="$1" file="$2" expected actual
    expected="$(curl -fsSL "$url.sha256" | awk 'NR == 1 {print $1}')" ||
        die "cannot download $url.sha256"
    actual="$(sha256sum "$file" | cut -d' ' -f1)"
    [[ -n "$expected" && "$expected" == "$actual" ]] ||
        die "checksum mismatch for $file: remove it and run this again"
}

# download_signed <url> <file>: downloads <url> into <file> unless it is there, and its
# signature <url>.sig into <file>.sig every time
download_signed() {
    local url="$1" file="$2"
    download "$url" "$file"
    curl -fsSL -o "$file.sig" "$url.sig" || die "cannot download $url.sig"
}

# check_signature <keyring> <file> [<fingerprint>]: checks <file>.sig with the keys of
# <keyring> and, given a fingerprint, that the primary key of the key that signed is
# that one (the last field of gpgv's VALIDSIG): a good signature of another key fails
check_signature() {
    local keyring="$1" file="$2" key="${3:-}" status
    if status="$(gpgv --status-fd 1 --keyring "$keyring" "$file.sig" "$file")"; then
        [[ -z "$key" ]] && return
        awk -v key="$key" '$2 == "VALIDSIG" && $NF == key {found = 1} END {exit !found}' \
            <<<"$status" && return
    fi
    die "bad signature for $file: remove it and run this again"
}

# gnu_keyring: the keyring of the GNU maintainers, downloaded once into SRC
GNU_KEYRING="$SRC/gnu-keyring.gpg"
gnu_keyring() {
    download https://ftp.gnu.org/gnu/gnu-keyring.gpg "$GNU_KEYRING"
}

# fetch_key <fingerprint> <keyring>: the key of <fingerprint>, downloaded once from
# keyserver.ubuntu.com into <keyring>. The key comes armored and gpgv reads binary
# keyrings: the base64 lines between the armor's headers and its checksum
fetch_key() {
    local key="$1" keyring="$2"
    [[ -f "$keyring" ]] && return
    mkdir -p "$(dirname "$keyring")"
    if ! curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x$key" |
        sed -e '1,/^$/d' -e '/^[=-]/,$d' | base64 -d >"$keyring.part"; then
        die "cannot fetch the key $key from keyserver.ubuntu.com"
    fi
    mv "$keyring.part" "$keyring"
}

# git_tag <url> <tag> <directory> [git clone options...]: a shallow clone of <tag> of the
# official repository into SRC/<directory>, unless it is there
git_tag() {
    local url="$1" tag="$2" dir="$SRC/$3"
    shift 3
    [[ -d "$dir" ]] && return
    rm -rf "$dir.part"
    git clone -q --depth 1 --branch "$tag" "$@" "$url" "$dir.part" || die "cannot clone $tag of $url"
    mv "$dir.part" "$dir"
}
