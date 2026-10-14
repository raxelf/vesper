#!/usr/bin/env bash
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Installing Vesper ==="

# 1. Check Runtime (Node.js >= 18 or Bun)
if command -v node &>/dev/null; then
  NODE_VER=$(node -v | sed 's/v//' | cut -d. -f1)
  if [ "$NODE_VER" -lt 18 ]; then
    echo "Warning: Node.js version is older than 18. Recommended: Node 18+ or Bun."
  fi
  echo "✔ Node.js runtime detected: $(node -v)"
elif command -v bun &>/dev/null; then
  echo "✔ Bun runtime detected: $(bun -v)"
else
  echo "Error: Node.js (>= 18) or Bun is required to run Vesper."
  echo "Install Node.js: https://nodejs.org or Bun: https://bun.sh"
  exit 1
fi

# 2. Install CLI binary
INSTALL_BIN_DIR="${HOME}/.local/bin"
mkdir -p "${INSTALL_BIN_DIR}"
cp -f "${REPO_DIR}/bin/vesper" "${INSTALL_BIN_DIR}/vesper"
chmod +x "${INSTALL_BIN_DIR}/vesper"
echo "✔ CLI installed: ${INSTALL_BIN_DIR}/vesper"

if [[ ":$PATH:" != *":${INSTALL_BIN_DIR}:"* ]]; then
  echo "  Note: ${INSTALL_BIN_DIR} is not in your \$PATH. Add it to ~/.bashrc or ~/.zshrc:"
  echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

# 3. Detect Roblox Studio Plugin directory
PLUGIN_TARGETS=()

# Flatpak Vinegar (Linux)
VINEGAR_PLUGINS="${HOME}/.var/app/org.vinegarhq.Vinegar/data/vinegar/prefixes/studio/drive_c/users/${USER}/AppData/Local/Roblox/Plugins"
if [ -d "$(dirname "${VINEGAR_PLUGINS}")" ]; then
  mkdir -p "${VINEGAR_PLUGINS}"
  PLUGIN_TARGETS+=("${VINEGAR_PLUGINS}")
fi

# Standard Wine (Linux)
WINE_PLUGINS="${HOME}/.wine/drive_c/users/${USER}/AppData/Local/Roblox/Plugins"
if [ -d "$(dirname "${WINE_PLUGINS}")" ]; then
  mkdir -p "${WINE_PLUGINS}"
  PLUGIN_TARGETS+=("${WINE_PLUGINS}")
fi

# macOS
MAC_PLUGINS="${HOME}/Library/Application Support/Roblox/Plugins"
if [ -d "$(dirname "${MAC_PLUGINS}")" ]; then
  mkdir -p "${MAC_PLUGINS}"
  PLUGIN_TARGETS+=("${MAC_PLUGINS}")
fi

# Windows / WSL
if [ -n "${LOCALAPPDATA}" ] && [ -d "${LOCALAPPDATA}/Roblox" ]; then
  WIN_PLUGINS="${LOCALAPPDATA}/Roblox/Plugins"
  mkdir -p "${WIN_PLUGINS}"
  PLUGIN_TARGETS+=("${WIN_PLUGINS}")
fi

if [ ${#PLUGIN_TARGETS[@]} -eq 0 ]; then
  FALLBACK_DIR="${HOME}/.local/share/Roblox/Plugins"
  mkdir -p "${FALLBACK_DIR}"
  PLUGIN_TARGETS+=("${FALLBACK_DIR}")
fi

for pdir in "${PLUGIN_TARGETS[@]}"; do
  cp -f "${REPO_DIR}/plugin/Vesper.server.lua" "${pdir}/Vesper.server.lua"
  echo "✔ Plugin installed: ${pdir}/Vesper.server.lua"
done

echo ""
echo "=== Vesper Installation Complete ==="
echo "1. Start server: vesper serve"
echo "2. Open Roblox Studio and click Connect in the Vesper dock panel."
echo "3. Run commands or build: vesper tree Workspace"
