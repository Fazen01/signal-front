#!/usr/bin/env bash
# The gate for every push: import the project, run the unit tests, boot the
# real scenes headless, drive the interface with synthetic input, walk the
# whole menu -> match -> result -> load -> tutorial flow, play headless
# AI-vs-AI matches, and repeat the flow from an exported pack. Fails on any
# script error, engine error or warning-treated-as-error in the output.
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
	if [ "${1:-}" = "--main-pack" ]; then
		# Run an exported pack from somewhere else, so nothing can be read
		# from the project folder by accident.
		(cd "${LOG_DIR}" && timeout "${limit}" "${GODOT}" --headless "$@" >"${log}" 2>&1)
	else
		timeout "${limit}" "${GODOT}" --headless --path "${ROOT}" "$@" >"${log}" 2>&1
	fi
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
		if [ -n "${required}" ]; then
			grep -F "${required}" "${log}" | tail -1 | sed 's/^/       /'
		fi
	fi
}

run_step import 600 "" --import
run_step tests 900 "TESTS PASSED" -s res://tests/run_tests.gd
run_step boot_menu 300 "Main menu ready" --fixed-fps 60 --quit-after 300
run_step boot_battle 600 "Battle scene exit at tick" --fixed-fps 60 --quit-after 600 res://scenes/battle.tscn
run_step smoke_battle 600 "Smoke driver finished" --fixed-fps 60 --quit-after 400 res://scenes/battle.tscn -- --smoke
run_step flow 600 "Flow smoke finished" --fixed-fps 60 --quit-after 4000 -- --flow-smoke
run_step spectate 900 "Spectate finished" --fixed-fps 60 --quit-after 9000 res://scenes/battle.tscn -- --spectate=nomad,foundry
run_step ai_match 900 "MATCH RESULT" -s res://tools/headless_match.gd -- --seed=1 --max-minutes=45
run_step ai_match_foundry 900 "MATCH RESULT" -s res://tools/headless_match.gd -- --seed=2 --max-minutes=45 --factions=foundry,aegis
run_step ai_match_nomad 900 "MATCH RESULT" -s res://tools/headless_match.gd -- --seed=3 --max-minutes=45 --factions=nomad,foundry
run_step ai_match_vesper 900 "MATCH RESULT" -s res://tools/headless_match.gd -- --seed=4 --max-minutes=45 --factions=vesper,aegis
run_step ai_match_verdigris 900 "MATCH RESULT" -s res://tools/headless_match.gd -- --seed=6 --max-minutes=45 --factions=verdigris,nomad
run_step ai_match_layout 900 "MATCH RESULT" -s res://tools/headless_match.gd -- --seed=5 --max-minutes=45 --map=twin_fords --factions=aegis,foundry
# Three-way free-for-alls run 17-55 game minutes since the 1v1 pacing change
# (this seed is the slowest measured); the cap only has to catch stalemates.
run_step ai_match_three 900 "MATCH RESULT" -s res://tools/headless_match.gd -- --seed=5 --max-minutes=90 --factions=foundry,nomad,aegis

# The exported game: build the pack the Windows preset would ship and play the
# whole flow from it. Catches data files or scenes missing from the export.
PACK="${LOG_DIR}/export_check.pck"
rm -f "${PACK}"
run_step export_pack 600 "" --export-pack "Windows Desktop" "${PACK}"
if [ -f "${PACK}" ]; then
	run_step flow_exported 600 "Flow smoke finished" --main-pack "${PACK}" --fixed-fps 60 --quit-after 4000 -- --flow-smoke
else
	echo "[FAIL] export_pack: no pack was written"
	failed=1
fi

if [ "${failed}" -ne 0 ]; then
	echo "CHECK FAILED"
	exit 1
fi
echo "CHECK PASSED"
