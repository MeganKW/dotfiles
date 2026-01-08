#!/bin/bash
set -eufx -o pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_BIN_DIR="${DOTFILES_DIR}/bin"
DOTFILES_COMPLETIONS_DIR="${DOTFILES_DIR}/completions.d"

if ! grep ".dotfiles" "${HOME}/.bashrc"; then
    echo "Adding .dotfiles to .bashrc"
    echo "" >> "${HOME}/.bashrc"
    echo '[ ! -f "${HOME}/.dotfiles/.bashrc" ] || . "${HOME}/.dotfiles/.bashrc"' >> "${HOME}/.bashrc"
fi

source "${HOME}/.dotfiles/.bashrc"

if ! grep ".dotfiles" "${HOME}/.gitconfig"; then
    cat <<EOF >> "${HOME}/.gitconfig"
[include]
    path = ${HOME}/.dotfiles/.gitconfig
EOF
fi

mkdir -p "${DOTFILES_BIN_DIR}"
mkdir -p "${DOTFILES_COMPLETIONS_DIR}"

YQ_VERSION=4.45.1
if ! command -v yq &> /dev/null; then
    [ $(uname -m) == "aarch64" ] && ARCH="arm64" || ARCH="amd64"
    curl -fsSL "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_${ARCH}" -o "${DOTFILES_BIN_DIR}/yq"
    chmod +x "${DOTFILES_BIN_DIR}/yq"
fi

NODE_VERSION=22.16.0
if ! command -v node &> /dev/null; then
    [ $(uname -m) == "aarch64" ] && ARCH="arm64" || ARCH="x64"
    mkdir -p "${DOTFILES_DIR}/.node"
    curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${ARCH}.tar.xz" \
        | tar -xJ -C "${DOTFILES_DIR}/.node" --strip-components=1

    while read -r file; do
        ln -s "$file" "${DOTFILES_BIN_DIR}/$(basename "$file")"
    done < <(find "${DOTFILES_DIR}/.node/bin" -executable -print)
fi

mkdir -p "${NPM_CONFIG_PREFIX}"
if ! command -v claude &> /dev/null; then
    npm install -g @anthropic-ai/claude-code
fi