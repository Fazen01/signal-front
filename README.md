# Signal Front

A near-future real-time strategy game where every army runs on signal.
Build a base, harvest salvage, field tanks and infantry — and keep your relay
network alive, because units outside it fight blind and slow. Cut the enemy's
chain and their front goes dark.

Built with Godot 4.7.2 in typed GDScript. Models, effects, interface art and
sound are all generated in code; there are no downloaded assets.

## Run it

1. Install [Godot 4.7.2](https://godotengine.org/download) (standard build).
2. Open this folder as a project (Import → select `project.godot`). The first
   open takes a few seconds while Godot scans the scripts.
3. Press F5.

From the main menu:

- **Tutorials** — three short missions (economy, the Signal Grid, Directives).
  Start here.
- **Skirmish** — pick a map, one to three AI opponents, the factions, a
  difficulty and a seed.
- **Load Saved Game** — continue the match saved from the pause menu.
- **Settings** — volumes, fullscreen, vsync, shadows, anti-aliasing, hotkey
  hints.

### Windows build

A "Windows Desktop" export preset is included. In the editor: Project →
Export → Windows Desktop → Export Project (install the export templates when
Godot offers to). From a Linux shell, `tools/export_windows.sh` does the same
and writes `build/windows/SignalFront.exe`.

## How to play

Your Headquarters and every Relay linked back to it project **signal
coverage** (the tinted ground). Units inside it are **Linked**; units outside
are **Dark** — they fire and see about a third worse, Dark buildings stop
producing, and Dark turrets fire at half rate. A Relay only works while it is
within link range of another linked emitter, all the way back to the HQ, so
destroying one relay can black out everything chained behind it.

1. Your Haulers start collecting salvage on their own. Train more at the HQ.
2. Select a builder and put up a barracks, then extend your network towards
   more salvage. Each linked relay also raises your Bandwidth (the unit cap).
3. Build a vehicle factory, add turrets where your network is thin, and
   destroy the enemy Headquarters to win.
4. Destroyed vehicles and buildings leave wrecks that Haulers can collect.
5. Send a builder to capture **Uplink Sites** (right-click one). A site pays
   a salvage trickle while it is inside your coverage.
6. Destroying enemy units and buildings earns **Command Points** (CP). Spend
   them on the bar above the command card to unlock **Directives** — Recon
   Sweep, Shell Barrage, Field Repair, Signal Surge, Blackout and
   Reinforcement Drop — then use them whenever their cooldown is ready.
7. Units that destroy a lot earn up to three veterancy ranks (gold chevrons):
   more damage, more health, and self-repair at the top rank.

You only see what your network and your units see: everything inside your
coverage is visible, plus a circle around each unit.

### Controls

| Input | Action |
|---|---|
| W / D / arrow keys / screen edge | Pan the camera (A and S also pan while nothing is selected) |
| Mouse wheel | Zoom |
| Q / E, or middle-drag | Rotate the camera |
| Left click / drag | Select (Shift adds; double-click selects that type on screen) |
| Right click | Context order: move, attack, harvest, repair/assist, capture, hijack, set rally point |
| A, then left click | Attack-move |
| S / H | Stop / hold position |
| Shift + order | Queue the order |
| Ctrl+1..9, then 1..9 | Set / recall a control group (double-tap centres the camera) |
| G | Toggle the signal coverage overlay |
| . (period) or F1 | Select the next idle builder |
| Ctrl+F5..F8, then F5..F8 | Save / recall a camera bookmark |
| Minimap: left click / right click | Move the camera / order the selection there |
| Alt+1..6, or click the Directive bar | Unlock or use a Directive (left click to target, right click to cancel) |
| Letter in [brackets] on the command card | Build or train that item |
| Y | Deploy a deployable unit, or pack a deployed building back up |
| Esc | Cancel placement, targeting or attack-move; otherwise open the pause menu (save, settings, surrender) |

## The factions

**Aegis Directorate** — precise and networked. Long-range Relays, aircraft and
artillery. Linked units gain weapon range; going Dark hurts them most.

- Infantry: Trooper, Lancer (anti-armor), Field Engineer (builds, repairs,
  captures), Marksman (long sight, hidden while still).
- Vehicles: Hauler, Courser (scout), Warden (autocannon), Bulwark (tank),
  Tempest (anti-air), Longbow (artillery: long range, minimum range, needs
  spotters).
- Aircraft: Kestrel (gunship), Scout Drone. Aircraft ignore terrain; only
  some weapons can hit them and flak is by far the best.
- Buildings: Headquarters, Depot, Relay, Barracks, Vehicle Works, Sentry
  Turret, Lance Battery, Flak Post, Command Lab (tier 3, faster Directives),
  Airpad.

**Foundry Pact** — slow heavy industry. Linked vehicles repair themselves.

- Infantry: Levy (cheap, massed), Breaker (rockets), Sapper (builds, repairs,
  captures and lays hidden **mines** anywhere).
- Vehicles: Scow (armored hauler), Ratchet (repair truck), Tusk (assault gun),
  Harrow (flak half-track), Anvil (siege mortar), Mauler (heavy tank), and
  the **Crawler**, a mobile factory: select it, press Y and click to deploy it
  inside your coverage; press Y on the deployed factory to pack it up again.
- Buildings: Foundry Core, **Pylon** (a cheap, armored relay with a short
  radius — build a dense web), Scrapyard, Muster Hall, Bastion (gun turret),
  Skyspike (anti-air), Arsenal (tier 3, faster Directives).

**Nomad Circuit** — fast, light, elusive. Half again as much salvage from
wrecks; ground units vanish when they stand still in forest.

- Infantry: Drifter, Tinker (builder), Splicer — right-click an enemy vehicle
  that is **Dark** and the Splicer hijacks it.
- Vehicles: Skiff (fast hauler), Dart (raider bike), Sidewinder (missile
  truck), Gnat (flak buggy), Prowler (light tank), **Jammer Buggy** (wipes
  enemy coverage around itself) and the **Beacon Rig**: the Circuit has no
  buildable relay — drive a rig out, press Y and click within link range of
  your network to deploy it as a Beacon, press Y on the Beacon to pack it up.
- Buildings: **Caravan Hub** (the headquarters; press Y to pack it into a
  Caravan and relocate — your whole network is Dark while it rolls), Cache,
  Camp, Chop Shop, Snare Turret, Signal Loom (tier 3).

## Maps

A seeded, symmetric generator (128 × 128 for two players, 192 × 192 for three
or four) and three hand-made layouts: **Twin Fords** (a river with three
crossings), **Crater Ring** (rich salvage inside a rock ring) and
**Crossroads** (four players, ridges and a central plaza).

## Known limits

This build was made by unattended sessions that could not see or hear the
game except through software-rendered screenshots, so:

- Nobody has played it with a real mouse and keyboard. Every input path is
  exercised with synthetic events, but expect rough edges in feel.
- Nobody has heard the sound. It is synthesised and checked for level, not
  for taste.
- Frame rate on a real GPU is unmeasured. Script-side cost with 300 units in
  one fight is about 7–8 ms a frame.
- Balance is tuned with AI-vs-AI batches (roughly 53 / 56 / 41 % win rates for
  Aegis / Foundry / Nomad at last measure). Matches between AIs last about 21
  minutes on average, inside the 15–25 the design aims for; Nomad mirrors run
  shorter.

## For developers

- [docs/DESIGN.md](docs/DESIGN.md) — the design.
- [docs/ROADMAP.md](docs/ROADMAP.md) — progress, open items and the session
  log with every decision made along the way.
- `sim/` is the simulation (plain classes, fixed 20 Hz tick, seeded RNG, no
  scene-tree access). `view/` and `ui/` read it and send `SimCommand`s.
  Units, buildings, weapons, factions, Directives, rules and maps are JSON in
  `data/`; a new unit or a balance change needs no code.

Checks, on Linux (they download Godot 4.7.2 into `.godot-bin/`):

```bash
tools/check.sh
```

This imports the project, runs the unit tests, boots the menu and battle
scenes headless, drives the interface with synthetic input, walks the whole
menu → match → result → load → tutorial loop, plays five AI-vs-AI matches
that must each end with a winner, then exports the game as a pack and walks
the loop again from the export. It fails on any script error. About eight
minutes.

Other tools:

```bash
tools/screenshot.sh battle 120
```

Captures `screenshots/battle.png` with software rendering (needs `xvfb-run`).
`tools/gallery.tscn` puts every model on one sheet.

```bash
.godot-bin/godot --headless --path . -s res://tools/headless_match.gd -- --seed=7 --factions=aegis,nomad
```

Plays one AI-vs-AI match (two to four factions; `--map=twin_fords` for a
hand-made layout).

```bash
.godot-bin/godot --headless --path . -s res://tools/match_timeline.gd -- --seed=2 --factions=aegis,foundry
```

Plays one two-player AI match and prints a timeline: every attack wave with
its size and survivors, every building lost, and both treasuries each minute.
The quickest way to see why a match ended when it did.

```bash
.godot-bin/godot --headless --path . -s res://tools/balance_batch.gd -- --seeds=1,2,3,4
```

Plays every faction pairing over the seeds and prints win counts.

```bash
.godot-bin/godot --headless --path . -s res://tools/perf_bench.gd
```

Times the simulation tick with 300 units; `tools/frame_bench.tscn` times a
whole frame of the real battle scene.

The hand-made layouts in `data/maps/` are written by `tools/make_layouts.py`;
edit the shapes there and re-run it.
