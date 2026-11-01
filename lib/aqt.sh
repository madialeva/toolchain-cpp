# The official Qt kits, installed with aqtinstall in a virtual environment of its own:
# common to the qt and qt-wasm components (docs/toolchain.md, "qt and qt-wasm").
# shellcheck shell=bash

QT_DIR="$SOFTWARE_DIR/Qt"
AQT="$SOFTWARE_DIR/aqt-venv/bin/aqt"

# The modules beyond aqt's defaults, the union of what the projects need, with the
# directory that marks each one in a kit
declare -A QT_MODULES=(
    [qttasktree]=lib/cmake/Qt6TaskTree      # a dependency of QmlAssetDownloader
    [qtwebsockets]=lib/cmake/Qt6WebSockets  # guita's persistent channel
)

# has_modules <kit>: whether <kit> has every module of the list
has_modules() {
    local module
    for module in "${!QT_MODULES[@]}"; do
        [[ -d "$1/${QT_MODULES[$module]}" ]] || return 1
    done
}

# aqt_install <host> <target> <arch>: installs that kit of QT_VERSION with the modules
# of the list. aqt checks every archive against the checksums of Qt's repository
aqt_install() {
    if [[ ! -x "$AQT" ]]; then
        python3 -m venv "$SOFTWARE_DIR/aqt-venv"
        "$SOFTWARE_DIR/aqt-venv/bin/pip" install -q --upgrade pip aqtinstall
    fi
    # aqtinstall writes aqtinstall.log to the current directory
    (cd "$SOFTWARE_DIR" &&
        "$AQT" install-qt "$1" "$2" "$QT_VERSION" "$3" -m "${!QT_MODULES[@]}" -O "$QT_DIR")
}
