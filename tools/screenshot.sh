#!/usr/bin/env bash
# Captures a PNG of a scene using a software-GL display, so a session without
# a screen can still look at the game. Output goes to screenshots/ (ignored).
# Usage: tools/screenshot.sh [name] [frames] [script] [scene]
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NAME="${1:-battle}"
FRAMES="${2:-120}"
SCRIPT="${3:-}"
SCENE="${4:-res://scenes/battle.tscn}"
"${ROOT}/tools/install_godot.sh" >/dev/null || exit 1
if ! command -v xvfb-run >/dev/null; then
	echo "xvfb-run is not available; cannot take screenshots here" >&2
	exit 2
fi
xvfb-run -a -s "-screen 0 1600x900x24" "${ROOT}/.godot-bin/godot" --path "${ROOT}" \
	--rendering-driver opengl3 --audio-driver Dummy --fixed-fps 30 \
	--resolution 1600x900 res://tools/screenshot_runner.tscn -- \
	"--scene=${SCENE}" "--frames=${FRAMES}" "--name=${NAME}" "--script=${SCRIPT}" 2>&1 \
	| grep -E "Saved|ERROR|error|BOOT FAILED" || true
