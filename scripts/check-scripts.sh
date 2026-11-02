#!/usr/bin/env bash
# Checks every script of the repository, as the CI does (docs/toolchain.md, "Checking
# the scripts"):
#
#   scripts/check-scripts.sh
#
# The scripts are install.sh, versions.sh and those of lib/, components/ and scripts/.
# First their bash syntax, then shellcheck, at the version fixed below, with its
# default checks and the repository's .shellcheckrc. shellcheck is the one in the PATH
# if it is that version; otherwise its official binary for Linux x86_64, downloaded
# once to $SOFTWARE_DIR/src and checked against the SHA-256 below before it is used.
# Any finding fails, naming the script, the line and the code; in GitHub Actions each
# one is also an annotation on its file and line.
#
# System requirements: curl, tar with xz, and sha256sum.
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$(dirname "$0")/../lib/common.sh"

SHELLCHECK_VERSION=0.11.0
# The SHA-256 of shellcheck-v$SHELLCHECK_VERSION.linux.x86_64.tar.xz, as its GitHub
# release gives it
SHELLCHECK_SHA256=8c3be12b05d5c177a04c29e3c78ce89ac86f1595681cab149b65b97c4e227198

# annotate <level> <file> <line> <column> <message>: in GitHub Actions, an annotation
# of <level> (error or warning) on <file>, at <line> and <column> if they are not empty
annotate() {
    local level="$1" file="$2" line="$3" column="$4" message="$5" where
    [[ "${GITHUB_ACTIONS:-}" == true ]] || return 0
    where="file=$file"
    [[ -z "$line" ]] || where+=",line=$line"
    [[ -z "$column" ]] || where+=",col=$column"
    echo "::$level $where::${message//%/%25}"
}

# version_of <binary>: the version the shellcheck <binary> reports, or nothing
version_of() {
    "$1" --version 2>/dev/null | awk '$1 == "version:" { print $2 }' || true
}

# find_shellcheck: sets SHELLCHECK to a shellcheck of SHELLCHECK_VERSION: the one in the
# PATH, the one already downloaded, or one downloaded now
find_shellcheck() {
    local name="shellcheck-v$SHELLCHECK_VERSION" tarball actual
    if command -v shellcheck >/dev/null &&
        [[ "$(version_of shellcheck)" == "$SHELLCHECK_VERSION" ]]; then
        SHELLCHECK=shellcheck
        return
    fi
    SHELLCHECK="$SRC/$name/shellcheck"
    if [[ -x "$SHELLCHECK" && "$(version_of "$SHELLCHECK")" == "$SHELLCHECK_VERSION" ]]; then
        return
    fi
    [[ "$(uname -m)" == x86_64 ]] ||
        die "shellcheck $SHELLCHECK_VERSION is only downloaded for x86_64: put it in the PATH"

    say "shellcheck $SHELLCHECK_VERSION is not in the PATH: downloading it to $SRC"
    tarball="$SRC/$name.linux.x86_64.tar.xz"
    download "https://github.com/koalaman/shellcheck/releases/download/v$SHELLCHECK_VERSION/$name.linux.x86_64.tar.xz" \
        "$tarball"
    actual="$(sha256sum "$tarball" | cut -d' ' -f1)"
    [[ "$actual" == "$SHELLCHECK_SHA256" ]] ||
        die "checksum mismatch for $tarball: remove it and run this again"
    rm -rf "${SRC:?}/$name"
    tar -xJf "$tarball" -C "$SRC"
    [[ "$(version_of "$SHELLCHECK")" == "$SHELLCHECK_VERSION" ]] ||
        die "$SHELLCHECK does not report version $SHELLCHECK_VERSION"
}

cd "$TOOLCHAIN_ROOT"
scripts=(install.sh versions.sh lib/*.sh components/*.sh scripts/*.sh)

# 1. The syntax: shellcheck would say nothing useful of a script bash cannot read
status=0
for script in "${scripts[@]}"; do
    if ! bash -n "$script"; then
        echo "error: syntax error in $script" >&2
        annotate error "$script" "" "" "Syntax error in $script"
        status=1
    fi
done
((status == 0)) || die "the scripts above have syntax errors"

# 2. shellcheck, all the scripts at once, in its gcc format:
#    <file>:<line>:<column>: <level>: <message> [SC<code>]
find_shellcheck
output="$("$SHELLCHECK" --format=gcc "${scripts[@]}")" || status=$?
if ((status != 0)); then
    [[ -z "$output" ]] || echo "$output" >&2
    while IFS= read -r line; do
        if [[ "$line" =~ ^([^:]+):([0-9]+):([0-9]+):\ ([a-z]+):\ (.*)$ ]]; then
            level=warning
            [[ "${BASH_REMATCH[4]}" != error ]] || level=error
            annotate "$level" "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}" \
                "${BASH_REMATCH[5]}"
        fi
    done <<<"$output"
    die "shellcheck $SHELLCHECK_VERSION reports the findings above (exit status $status)"
fi
say "${#scripts[@]} scripts checked: bash syntax and shellcheck $SHELLCHECK_VERSION"
