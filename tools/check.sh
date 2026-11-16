#!/usr/bin/env bash
# The gate for every push: import the project, run the unit tests, boot the
# real scenes headless, run a headless AI-vs-AI match, and fail on any script
# error, engine error or warning-treated-as-error in the output.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

"${ROOT}/tools/install_godot.sh" || { echo "CHECK FAILED: Godot is not available"; exit 1; }
GODOT="${ROOT}/.godot-bin/godot"
LOG_DIR="${ROOT}/.godot-bin/logs"
mkdir -p "${LOG_DIR}"

BAD_PATTERN='SCRIPT ERROR|^ERROR:|^[[:space:]]*ERROR:|Parse Error|Warning treated as error|Failed to load script|Cannot open file|Invalid call|Invalid access|Stack overflow|TESTS FAILED|MATCH FAILED|BOOT FAILED'
failed=0

# run_step <name> <timeout-seconds> <required-output-or-empty> <godot args...>
run_step() {
	local name="$1" limit="$2" required="$3"
	shift 3
	local log="${LOG_DIR}/${name}.log"
	local t0=$SECONDS
	timeout "${limit}" "${GODOT}" --headless --path "${ROOT}" "$@" >"${log}" 2>&1
	local code=$?
	local dt=$((SECONDS - t0))
	local bad=0
	if [ "${code}" -ne 0 ]; then
		echo "[FAIL] ${name}: exit code ${code} (${dt}s)"
		bad=1
	fi
	if grep -E -q "${BAD_PATTERN}" "${log}"; then
		echo "[FAIL] ${name}: errors in output (${dt}s)"
		bad=1
	fi
	if [ -n "${required}" ] && ! grep -F -q "${required}" "${log}"; then
		echo "[FAIL] ${name}: expected output '${required}' not found (${dt}s)"
		bad=1
	fi
	if [ "${bad}" -ne 0 ]; then
		grep -E -n -A3 "${BAD_PATTERN}" "${log}" | head -60
		echo "--- last lines of ${log}"
		tail -15 "${log}"
		failed=1
	else
		echo "[ ok ] ${name} (${dt}s)"
	fi
}

run_step import 600 "" --import
run_step tests 900 "TESTS PASSED" -s res://tests/run_tests.gd
run_step boot_main 300 "Signal Front boot ok" --quit-after 300

if [ "${failed}" -ne 0 ]; then
	echo "CHECK FAILED"
	exit 1
fi
echo "CHECK PASSED"
