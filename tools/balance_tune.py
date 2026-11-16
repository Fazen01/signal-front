#!/usr/bin/env python3
"""Balances the factions against each other by playing leagues.

Each round plays every faction against every other (tools/balance_league.py)
and then nudges the price of each faction's fighting units: a faction that
wins too often pays more for its army, one that loses too often pays less.
The nudge is proportional to how far its win rate is from even, so it gets
smaller as the factions close in. Only costs are touched; what the units
do stays as designed.

    tools/balance_tune.py --rounds 3 --seeds 1-6          # try, print, change nothing
    tools/balance_tune.py --rounds 3 --seeds 1-6 --write  # and write the prices into data/units.json

The multipliers found so far are kept in .godot-bin/balance_state.json, so
a run can be stopped and picked up again (--fresh starts over).
"""
import argparse
import importlib.util
import json
import math
import os
import re
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STATE = os.path.join(ROOT, ".godot-bin", "balance_state.json")
spec = importlib.util.spec_from_file_location("balance_league", os.path.join(ROOT, "tools", "balance_league.py"))
league = importlib.util.module_from_spec(spec)
spec.loader.exec_module(league)


def army_units():
    """The fighting units of each faction: armed, and built by the AI."""
    units = json.load(open(os.path.join(ROOT, "data", "units.json")))
    out = {}
    for unit_id, u in units.items():
        if u.get("weapons") and float(u.get("ai_weight", 0.0)) > 0.0:
            out.setdefault(u["faction"], []).append(unit_id)
    return out


def scale_arg(mult, army):
    parts = []
    for faction, m in sorted(mult.items()):
        if abs(m - 1.0) < 0.0005:
            continue
        for unit_id in army.get(faction, []):
            parts.append("%s.cost:%.4f" % (unit_id, m))
    return ",".join(parts)


def write_costs(mult, army):
    """Rewrites the cost of each army unit in data/units.json, keeping the file's layout."""
    path = os.path.join(ROOT, "data", "units.json")
    text = open(path).read()
    units = json.loads(text)
    changed = []
    for faction, m in sorted(mult.items()):
        for unit_id in army.get(faction, []):
            old = int(units[unit_id]["cost"])
            new = max(5, int(round(old * m / 5.0)) * 5)
            if new == old:
                continue
            block = re.search(r'\t"%s": \{.*?\n\t\}' % re.escape(unit_id), text, re.S)
            fixed = re.sub(r'"cost": %d\b' % old, '"cost": %d' % new, block.group(0), count=1)
            text = text[:block.start()] + fixed + text[block.end():]
            changed.append("%s %d -> %d" % (unit_id, old, new))
    open(path, "w").write(text)
    return changed


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--rounds", type=int, default=3)
    parser.add_argument("--seeds", default="1-6")
    parser.add_argument("--jobs", type=int, default=max(1, (os.cpu_count() or 2) - 1))
    parser.add_argument("--gain", type=float, default=0.35, help="price change per unit of win rate off even (0.35: a 70%% faction pays 7%% more)")
    parser.add_argument("--within", type=float, default=8.0, help="stop when every faction is within this many points of even")
    parser.add_argument("--write", action="store_true", help="write the prices found into data/units.json")
    parser.add_argument("--fresh", action="store_true", help="forget the multipliers of earlier runs")
    opts = parser.parse_args()

    army = army_units()
    mult = {f: 1.0 for f in league.playable_factions()}
    if os.path.exists(STATE) and not opts.fresh:
        mult.update(json.load(open(STATE)))
    seeds = league.parse_seeds(opts.seeds)
    for rnd in range(1, opts.rounds + 1):
        started = time.time()
        wins, games, pair_wins, lengths, draws = league.run_league(seeds, opts.jobs, scale_arg(mult, army))
        prices = ", ".join("%s x%.3f" % (f, m) for f, m in sorted(mult.items()) if abs(m - 1.0) >= 0.0005) or "as in the data files"
        league.print_table("TUNE round %d, seeds %s, prices %s  (%d games, %.0f s)" % (rnd, opts.seeds, prices, len(lengths), time.time() - started),
                           wins, games, pair_wins, lengths, draws)
        worst = 0.0
        for f in mult:
            if games[f] == 0:
                continue
            off = wins[f] / games[f] - 0.5
            worst = max(worst, abs(off) * 100.0)
            # Inside one standard error there is nothing to correct.
            if abs(off) * 100.0 < 50.0 / math.sqrt(games[f]):
                continue
            mult[f] = min(1.5, max(0.67, mult[f] * (1.0 + opts.gain * off)))
        json.dump(mult, open(STATE, "w"), indent=1)
        if worst <= opts.within:
            print("TUNE done: every faction within %.1f points of even" % opts.within)
            break
    print("TUNE prices: " + ", ".join("%s x%.3f" % (f, m) for f, m in sorted(mult.items())))
    if opts.write:
        changed = write_costs(mult, army)
        os.remove(STATE)
        print("TUNE wrote %d prices: %s" % (len(changed), "; ".join(changed)))
    sys.stdout.flush()


if __name__ == "__main__":
    main()
