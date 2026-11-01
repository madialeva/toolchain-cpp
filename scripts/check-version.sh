#!/usr/bin/env bash
# Checks that the version of the repository (VERSION) matches the version of a
# development or release branch:
#
#   scripts/check-version.sh <branch>
#
# develop/vX.Y.Z and release/vX.Y.Z must carry version X.Y.Z; any other branch (a
# change branch, for example) has no version to compare and passes. The CI passes the
# branch it pushes to or the base branch of the pull request.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
branch="${1:?usage: $0 <branch>}"

version="$(tr -d '[:space:]' <"$ROOT/VERSION")"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "error: VERSION holds no version X.Y.Z" >&2
    exit 1
fi

if [[ ! "$branch" =~ ^(develop|release)/v([0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
    echo "Branch $branch carries no version: nothing to compare (VERSION has $version)"
    exit 0
fi

expected="${BASH_REMATCH[2]}"
if [[ "$version" != "$expected" ]]; then
    echo "error: VERSION has version $version, but branch $branch is version $expected" >&2
    exit 1
fi
echo "VERSION $version matches branch $branch"
