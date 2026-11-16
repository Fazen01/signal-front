#!/usr/bin/env bash
# Fetches the Godot 4.7.2 Linux build into .godot-bin/ (git-ignored) if it is
# not already there. The same binary runs headless with --headless.
set -euo pipefail

VERSION="4.7.2-stable"
ASSET="Godot_v${VERSION}_linux.x86_64"
URL="https://github.com/godotengine/godot/releases/download/${VERSION}/${ASSET}.zip"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_DIR="${ROOT}/.godot-bin"
BIN="${BIN_DIR}/godot"

if [ -x "${BIN}" ] && "${BIN}" --version 2>/dev/null | grep -q "^4\.7\.2\."; then
	echo "Godot already installed: $("${BIN}" --version)"
	exit 0
fi

mkdir -p "${BIN_DIR}"
TMP_ZIP="${BIN_DIR}/godot.zip"
echo "Downloading ${URL}"
ok=0
for attempt in 1 2 3 4; do
	if curl -sSL --fail --max-time 600 -o "${TMP_ZIP}" "${URL}"; then
		ok=1
		break
	fi
	echo "Download attempt ${attempt} failed; retrying" >&2
	sleep $((attempt * 3))
done
if [ "${ok}" -ne 1 ]; then
	echo "ERROR: could not download Godot from ${URL}" >&2
	exit 1
fi

unzip -o -q "${TMP_ZIP}" -d "${BIN_DIR}"
rm -f "${TMP_ZIP}"
mv -f "${BIN_DIR}/${ASSET}" "${BIN}"
chmod +x "${BIN}"
echo "Installed: $("${BIN}" --version)"
