#!/bin/bash
# Installs the Roblox toolchain pinned in rokit.toml (rojo, selene, stylua) for
# Claude Code on the web sessions, using the prebuilt Linux release binaries.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

cd "${CLAUDE_PROJECT_DIR:-$(pwd)}"

BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"

# Read "owner/repo@version" for a tool from rokit.toml.
tool_version() {
  sed -n "s/^$1 *= *\"[^@]*@\([^\"]*\)\".*/\1/p" rokit.toml
}

# install <binary> <version> <download url>
install_tool() {
  local name="$1" version="$2" url="$3"
  if "$BIN_DIR/$name" --version 2>/dev/null | grep -q "$version"; then
    echo "$name $version already installed"
    return
  fi
  local tmp
  tmp="$(mktemp -d)"
  curl -fsSL --retry 4 --retry-delay 2 -o "$tmp/tool.zip" "$url"
  python3 -c "import zipfile,sys; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])" "$tmp/tool.zip" "$tmp"
  install -m 755 "$tmp/$name" "$BIN_DIR/$name"
  rm -rf "$tmp"
  echo "installed $name $version"
}

ROJO="$(tool_version rojo)"
SELENE="$(tool_version selene)"
STYLUA="$(tool_version stylua)"

install_tool rojo "$ROJO" \
  "https://github.com/rojo-rbx/rojo/releases/download/v$ROJO/rojo-$ROJO-linux-x86_64.zip"
install_tool selene "$SELENE" \
  "https://github.com/Kampfkarren/selene/releases/download/$SELENE/selene-$SELENE-linux.zip"
install_tool stylua "$STYLUA" \
  "https://github.com/JohnnyMorganz/StyLua/releases/download/v$STYLUA/stylua-linux-x86_64.zip"

# selene's Roblox standard library is generated from Roblox's API dump
# (setup.rbxcdn.com). Non-fatal: if the network policy blocks that host,
# selene is unavailable but everything else still works. roblox.yml is gitignored.
if ! "$BIN_DIR/selene" generate-roblox-std >/dev/null 2>&1; then
  echo "warning: could not generate selene roblox std (is setup.rbxcdn.com allowed?)" >&2
fi

if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export PATH=\"$BIN_DIR:\$PATH\"" >> "$CLAUDE_ENV_FILE"
fi
