#!/usr/bin/env bash
# Builds the Windows release into build/windows/SignalFront.exe using the
# "Windows Desktop" preset in export_presets.cfg.
#
# Needs Godot 4.7.2 export templates. In the editor: Editor > Manage Export
# Templates > Download and Install. On Linux without the editor:
#   tools/export_windows.sh --install-templates
# downloads them (about 1 GB) into ~/.local/share/godot/export_templates/.
set -euo pipefail

VERSION="4.7.2-stable"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE_DIR="${HOME}/.local/share/godot/export_templates/4.7.2.stable"

if [ "${1:-}" = "--install-templates" ]; then
	mkdir -p "${TEMPLATE_DIR}"
	TMP="$(mktemp -d)"
	echo "Downloading export templates for ${VERSION}"
	curl -sSL --fail --max-time 1800 -o "${TMP}/templates.tpz" \
		"https://github.com/godotengine/godot/releases/download/${VERSION}/Godot_v${VERSION}_export_templates.tpz"
	# Only the Windows 64-bit templates are needed.
	unzip -o -q -j "${TMP}/templates.tpz" \
		"templates/windows_release_x86_64.exe" "templates/windows_debug_x86_64.exe" \
		"templates/windows_release_x86_64_console.exe" "templates/windows_debug_x86_64_console.exe" \
		"templates/version.txt" -d "${TEMPLATE_DIR}"
	rm -rf "${TMP}"
	echo "Templates installed in ${TEMPLATE_DIR}"
fi

"${ROOT}/tools/install_godot.sh" >/dev/null
if [ ! -f "${TEMPLATE_DIR}/windows_release_x86_64.exe" ]; then
	echo "Export templates are not installed. Run: tools/export_windows.sh --install-templates" >&2
	exit 1
fi
mkdir -p "${ROOT}/build/windows"
"${ROOT}/.godot-bin/godot" --headless --path "${ROOT}" --import >/dev/null 2>&1 || true
"${ROOT}/.godot-bin/godot" --headless --path "${ROOT}" --export-release "Windows Desktop" "${ROOT}/build/windows/SignalFront.exe"
ls -la "${ROOT}/build/windows/"
