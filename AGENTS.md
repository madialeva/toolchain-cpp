# AGENTS.md — toolchain-cpp

## Project

toolchain-cpp builds, without root, the toolchain of the maintainer's C++
projects (guita, gambasse and the next ones), all on GCC 16.2:

- the native GCC, and a GCC cross compiler for 64-bit Windows;
- the Qt 6.12 kits: desktop, WebAssembly with emsdk, and static for Linux;
- the libraries the projects link.

Each piece is a component, installed by name with `./install.sh`, and
everything goes to `software/` in this repository.

The projects clone this repository next to them and point their presets,
scripts and CI at it; they keep only their own build scripts. The technical
reference is `docs/toolchain.md`: consult it before changing a component and
keep it up to date.

Principles that every change must keep:

- No root. Everything goes to `SOFTWARE_DIR` (by default `software/`, ignored
  by git); nothing goes outside it but the Python that uv manages, in uv's
  standard location.
- One component, one script in `components/`, with its row in `install.sh`
  (what it needs, its version) and its section in `docs/toolchain.md`.
- Versions live only in `versions.sh`. Options are fixed explicitly in the
  component, so that the result does not depend on the `-devel` packages
  installed: every feature that would follow them is set.
- Every download is checked before anything is built or removed:
  - with its signature, against the keyring of its project, or against a key
    pinned by its fingerprint and required in gpgv's `VALIDSIG`;
  - without a signature, with the SHA-256 its server publishes;
  - from git, with the tag of the version in the official repository.
- Installing is idempotent. A component stamps each of its prefixes as its
  last step (`lib/common.sh`): a stamped prefix is never touched again, and an
  unstamped one is removed and installed from the start.
- The component names and prefixes are the contract with the projects, whose
  presets name them: changing one is a MAJOR version (`VERSION`).
- Components are generic and serve every project. What only one project does
  with them (building its executable, checking it) stays in that project. A
  component's module list and options are the union of what the projects
  need.
- What is built with the native GCC gets a run path to its `libstdc++`, newer
  than the system's. The C++ libraries are built in C++26, the projects'
  standard, so that abseil and the projects agree on the `std` types it
  aliases.
- Do not introduce new components or dependencies without an approved
  OpenSpec change.

## Repository layout

```text
install.sh            installs components by name, with what they need
versions.sh           the version of every component
components/           one script per component
lib/common.sh         functions common to the components
patches/              patches the components apply, named after what they patch
scripts/              tools of the repository (check-version.sh)
docs/toolchain.md     the technical reference
software/             what the components download, build and install (ignored)
openspec/             specs and changes, versioned and public
```

`software/` holds the sources in `src/` and one prefix per component and
version (`gcc-16.2.0`, `Qt/6.12.0/gcc_64`, `Qt/6.12.0-static`, ...).

Built results carry absolute paths, such as run paths and `.la` files. Never
move the repository after building, and never run `git clean -xdf` in it: it
would remove everything built.

A component script defines `NAME`, `VERSION`, `PREFIXES` and `install`, and
ends with `component_main "$@"` (`lib/common.sh`). It can run alone, failing
with a message that names a missing component; `install.sh` installs what it
needs first.

## Verification

- There is no test suite. Each change verifies its components as its tasks
  describe:
  - installed from scratch;
  - the versions and the files of the results;
  - the failure cases, in a `SOFTWARE_DIR` under `tmp/` with links to what is
    already built, removed afterwards.
- The CI (`.github/workflows/ci.yml`) runs the quick checks on every push and
  pull request: the version against the branch, the syntax of the scripts, and
  a test installation of quick components in the official GCC image.
- Long builds run in the background, with their time and peak disk measured
  for `docs/toolchain.md`.
- GUI checks run on a virtual display (`Xvfb :99`), never on the user's
  desktop. Wine runs Windows executables with a temporary prefix, never
  `~/.wine`.

## OpenSpec

OpenSpec is the default workflow for changes. For each change: create
`proposal.md` and `design.md` (plus `tasks.md` and required `specs/` deltas),
then STOP until the user approves proposal and design. Do not start
implementing the tasks until then, and archive only on user confirmation.

This is not mandatory. If the maintainer explicitly states in a change request
that OpenSpec should not be used (or that the change should be made directly),
skip the OpenSpec workflow and implement the change directly.

Artifact language: prose in `proposal.md`, `design.md`, `tasks.md` and
`specs/*.md` (motivation, decisions, requirement/scenario descriptions, etc.)
is written in Spanish, except the fixed labels imposed by the OpenSpec skills,
which stay in English as-is (`Why`, `What Changes`, `Capabilities`, `Impact`,
`Context`, `Goals`/`Non-Goals`, `Decisions`, `Risks / Trade-offs`, `Migration
Plan`, `Open Questions`, `Purpose`, `ADDED`/`MODIFIED`/`REMOVED`/`RENAMED
Requirements`, `Requirement:`, `Scenario:`, `WHEN`/`THEN`/`AND`,
`SHALL`/`MUST`). Identifiers (scripts, variables, components) also stay in
English inside the Spanish text. This is independent of the GitHub issues
language (always English, see below).

## Language and files

Use English for scripts, comments, technical docs (README, `docs/`), commits,
and pull requests. GitHub issues and milestones: titles and descriptions
always in English. OpenSpec artifacts and user conversation remain in Spanish.

Text uses LF.

## Local environment

- The repository lives next to the projects that use it (`~/src/toolchain-cpp`
  beside `~/src/guita` and `~/src/gambasse`).
- System packages:
  - a C++ compiler to build GCC (gcc-toolset-14 on EL9, whose binutils that
    GCC keeps using);
  - make, m4, bzip2, xz, curl, git, gpgv, CMake ≥ 3.25, Ninja, and python3
    with venv;
  - for the components that need them: uv (`qt-wasm`), zlib (`cpp-httplib`),
    libpq (`libpqxx`), and the X11, xcb and OpenSSL development packages that
    `docs/toolchain.md` lists for `qt-static` and `libpq-static`.
- Wine is optional: the check of `gcc-mingw` runs its test program with it.
- Docker, to try the CI's steps in its image locally.

## Working preferences

- Every message addressed to the user is written in Spanish: questions,
  progress updates, explanations and final summaries alike, even when the
  scripts, docs and commits being discussed are in English.
- Prefer durable context in repo files (this AGENTS.md) over internal agent
  memory, so it survives clones/moves of the repository.
- `openspec/` is versioned and public on purpose: it shows how the toolchain is
  developed with OpenSpec, so write its artifacts knowing anyone can read them.
- `.opencode/`, `.claude/` and `tmp/` stay private working material: they are
  git-ignored and NOT published. Do not reference them from published files.
  The public documentation is the README, kept light (what it is, the
  components, getting started, use from a project), and `docs/toolchain.md`,
  the technical reference.
- `CHANGELOG.md` follows Keep a Changelog 1.1.0 and Semantic Versioning. Every
  change that is visible to the projects or to the people installing the
  toolchain adds its entry under `[Unreleased]` (Added, Changed, Deprecated,
  Removed, Fixed, Security) as part of the same work, written in English from
  the reader's point of view, not as a commit log. On release, `[Unreleased]`
  becomes `[X.Y.Z] - YYYY-MM-DD`, matching `VERSION` and the `vX.Y.Z` tag.

## GitHub workflow (issues, branches, PRs)

There is no `main`/`master`. The long-lived, default branch is
`develop/vX.Y.Z`, which holds the version currently under development.
Releasing cuts `release/vX.Y.Z` from it and tags `vX.Y.Z`; the projects pin
those tags. When a new cycle starts, `develop/vX.Y.Z` is created from the
released tag and becomes the default branch. The version lives as the single
source of truth in `VERSION` and must match the branch suffix; the CI checks it
with `scripts/check-version.sh` on `develop/**` and `release/**` pushes and on
the pull requests toward them.

Versions follow what a project must do to move to them:

- MAJOR when it must change its presets or scripts: a component or a prefix
  changes its name, as with a new GCC or Qt release;
- MINOR when components or options are added without touching the existing
  ones;
- PATCH when a script is fixed without changing what it installs.

Before 1.0.0 anything may change.

Each OpenSpec change is tracked on GitHub with this cycle:

1. OpenSpec proposal approved by the user.
2. GitHub issue for the change, linking its `openspec/changes/<name>/` folder
   (plus its milestone). While active, the change folder is named
   `is<n>-<slug>` after its issue; the date prefix is added only when the
   change is archived. The `toolchain-cpp` Projects board stays light
   (Todo / In Progress / Done).
3. Branch `change/is<n>-<slug>` from `develop/vX.Y.Z`, linked to the issue
   (`gh issue develop`). Creating it moves the issue to In Progress on the
   board (`gh project item-edit`).
4. Implementation on the branch + push (pushes are done by the user). Commits
   are partial, one per task group of `tasks.md`, so that no commit is huge
   and the branch history follows the tasks:
   - The agent commits a group as soon as all its tasks are done and verified;
     the commit carries the group's scripts, documentation and its `tasks.md`
     checkboxes. The planning artifacts (proposal, design, specs, tasks) go in
     the first commit.
   - The title starts with the issue as `[is<n>]`, then an English summary of
     the group and its number, for example
     `[is1] Add the installer and the common functions (group 1)`. The body
     ends with `Refs #<n>`.
   - Nothing outside the task groups is committed without the user's
     confirmation, and the change is not archived nor sent to a PR until the
     user validates it.
   - Commits and PRs carry no co-authorship or AI attribution: no
     `Co-Authored-By` trailers, no "Generated with" lines.
5. Once the user validates the change, and before any PR, the agent archives
   it on the same branch: syncs its delta specs into `openspec/specs/`, moves
   it to `openspec/changes/archive/YYYY-MM-DD-is<n>-<slug>/` and commits that
   as the last commit of the branch (`[is<n>] Archive the <slug> change`).
   Then it reviews the change's Non-Goals and creates a follow-up issue for
   each one that leaves useful pending work.
6. The user pushes and opens the PR toward `develop/vX.Y.Z` with
   `Closes #<n>` in the description → the CI validates the PR → the user
   reviews the diff.
7. Merge commit as the norm (no squash), so the per-group commits land on the
   development branch as they are.
