#!/usr/bin/env python3
"""Plays every faction against every other, AI against AI, and prints a table.

Each pairing is played over the given seeds, with the two factions swapping
seats on alternate seeds so that neither always starts in the same corner.
Pairings run in parallel, one Godot process each (tools/pace_batch.gd does
the playing). Use it to see whether the factions are balanced, and with
--scale to try a change before editing the data files:

    tools/balance_league.py --seeds 1-12
    tools/balance_league.py --seeds 1-12 --scale mote.cost:1.1,halberd.hp:0.95
    tools/balance_league.py --seeds 1-8 --only vesper      # one faction's pairings

A faction is in balance when its win rate is inside the margin printed at
the bottom: with N games the rate of an even faction still wanders by about
one standard error, 50 / sqrt(N) points, so small batches prove little.
"""
import argparse
import concurrent.futures
import json
import math
import os
import re
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = os.path.join(ROOT, ".godot-bin", "godot")


def parse_seeds(text):
    seeds = []
    for part in text.split(","):
        if "-" in part:
            low, high = part.split("-")
            seeds.extend(range(int(low), int(high) + 1))
        else:
            seeds.append(int(part))
    return seeds


def play(first, second, seeds, scale, max_minutes):
    """One process: `first` in seat one against `second` over the seeds."""
    if not seeds:
        return first, second, 0, 0, 0, []
    args = [
        GODOT, "--headless", "--path", ROOT, "-s", "res://tools/pace_batch.gd", "--",
        "--seeds=" + ",".join(str(s) for s in seeds), "--pairs=%s:%s" % (first, second),
        "--max-minutes=%d" % max_minutes,
    ]
    if scale:
        args.append("--scale=" + scale)
    out = subprocess.run(args, capture_output=True, text=True).stdout
    match = re.search(r"PACE %s %s (\d+)-(\d+) draws (\d+) avg [\d.]+ \[([^\]]*)\]" % (first, second), out)
    if match is None:
        sys.stderr.write("no result for %s against %s:\n%s\n" % (first, second, out[-2000:]))
        return first, second, 0, 0, len(seeds), []
    lengths = [float(x) for x in match.group(4).split()]
    return first, second, int(match.group(1)), int(match.group(2)), int(match.group(3)), lengths


def playable_factions():
    data = json.load(open(os.path.join(ROOT, "data", "factions.json")))
    return [k for k, v in data.items() if v.get("playable", True)]


def run_league(seeds, jobs, scale="", only="", max_minutes=60):
    """Plays the league and returns (wins, games, pair_wins, lengths, draws)."""
    factions = playable_factions()
    work = []
    for i, a in enumerate(factions):
        for b in factions[i + 1:]:
            if only and only not in (a, b):
                continue
            work.append((a, b, seeds[0::2]))
            work.append((b, a, seeds[1::2]))
    wins = {f: 0 for f in factions}
    games = {f: 0 for f in factions}
    pair_wins = {}
    lengths = []
    draws = 0
    with concurrent.futures.ThreadPoolExecutor(max_workers=jobs) as pool:
        for first, second, won, lost, drawn, mins in pool.map(lambda j: play(j[0], j[1], j[2], scale, max_minutes), work):
            total = won + lost + drawn
            wins[first] += won
            wins[second] += lost
            games[first] += total
            games[second] += total
            draws += drawn
            lengths.extend(mins)
            a, b = sorted((first, second))
            score = pair_wins.setdefault((a, b), [0, 0, 0])
            score[0] += won if first == a else lost
            score[1] += lost if first == a else won
            score[2] += drawn
    return wins, games, pair_wins, lengths, draws


def print_table(title, wins, games, pair_wins, lengths, draws, max_minutes=60):
    print(title)
    for (a, b), (wa, wb, d) in sorted(pair_wins.items()):
        print("  %-10s %2d - %-2d %-10s%s" % (a, wa, wb, b, "  (%d drawn)" % d if d else ""))
    print("  ----")
    worst = 0.0
    for f in sorted(wins, key=lambda f: -wins[f] / max(1, games[f])):
        if games[f] == 0:
            continue
        rate = 100.0 * wins[f] / games[f]
        worst = max(worst, abs(rate - 50.0))
        print("  %-10s %5.1f%%  (%d of %d)" % (f, rate, wins[f], games[f]))
    per_faction = max(games.values()) if games else 0
    if lengths and per_faction:
        lengths = sorted(lengths)
        print("  match length: median %.1f min, %.0f%% between 12 and 25, %d not decided in %d min" % (
            lengths[len(lengths) // 2], 100.0 * sum(1 for x in lengths if 12.0 <= x <= 25.0) / len(lengths), draws, max_minutes))
        print("  furthest from even: %.1f points; one standard error at %d games a faction is %.1f points" % (
            worst, per_faction, 50.0 / math.sqrt(per_faction)))
    sys.stdout.flush()


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--seeds", default="1-8", help="for example 1-12 or 3,5,9")
    parser.add_argument("--jobs", type=int, default=max(1, (os.cpu_count() or 2) - 1))
    parser.add_argument("--scale", default="", help="passed to pace_batch.gd, for example mote.cost:1.1")
    parser.add_argument("--only", default="", help="play only the pairings of this faction")
    parser.add_argument("--max-minutes", type=int, default=60)
    opts = parser.parse_args()
    started = time.time()
    wins, games, pair_wins, lengths, draws = run_league(parse_seeds(opts.seeds), opts.jobs, opts.scale, opts.only, opts.max_minutes)
    title = "LEAGUE seeds %s%s  (%d games, %.0f s)" % (opts.seeds, "  scale " + opts.scale if opts.scale else "", len(lengths), time.time() - started)
    print_table(title, wins, games, pair_wins, lengths, draws, opts.max_minutes)


if __name__ == "__main__":
    main()
