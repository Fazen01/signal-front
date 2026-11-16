# Signal Front

A near-future real-time strategy game where every army runs on signal.
Build a base, harvest salvage, field tanks and infantry — and keep your relay
network alive, because units outside it fight blind and slow. Cut the enemy's
chain and their front goes dark.

Built with Godot 4.7.2 in typed GDScript. All models, effects and interface
art are generated in code; there are no downloaded assets.

## Run it

1. Install [Godot 4.7.2](https://godotengine.org/download) (standard build).
2. Open this folder as a project (Import → select `project.godot`). The first
   open takes a few seconds while Godot scans the scripts.
3. Press F5. The main menu appears; choose **Skirmish**, pick a seed and an
   opponent, and press **Start Match**.

## How to play

Your Headquarters and every Relay linked back to it project **signal
coverage** (the tinted ground). Units inside it are **Linked**; units outside
are **Dark** — they fire and see about a third worse, Dark buildings stop
producing, and Dark turrets fire at half rate. A Relay only works while it is
within link range of another linked emitter, all the way back to the HQ, so
destroying one relay can black out everything chained behind it.

1. Your two Haulers start collecting salvage on their own. Train more at the HQ.
2. Select a Field Engineer and build a **Barracks**, then **Relays** towards
   more salvage. Each linked Relay also adds 10 Bandwidth (the unit cap).
3. Build a **Vehicle Works** for Wardens and Bulwark tanks, add turrets where
   your network is thin, and destroy the enemy Headquarters to win.
4. Destroyed vehicles and buildings leave wrecks that Haulers can collect.

### Controls

| Input | Action |
|---|---|
| W / D / arrow keys / screen edge | Pan the camera (A and S also pan while nothing is selected) |
| Mouse wheel | Zoom |
| Q / E, or middle-drag | Rotate the camera |
| Left click / drag | Select (Shift adds; double-click selects that type on screen) |
| Right click | Context order: move, attack, harvest, repair/assist, set rally point |
| A, then left click | Attack-move |
| S / H | Stop / hold position |
| Shift + order | Queue the order |
| Ctrl+1..9, then 1..9 | Set / recall a control group (double-tap centres the camera) |
| G | Toggle the signal coverage overlay |
| Letter in [brackets] on the command card | Build or train that item |
| Esc | Cancel placement or attack-move; otherwise open the pause menu |

## What is in this build

First playable (`v0.1`): one faction, the **Aegis Directorate**, in a mirror
match against a scripted AI (Easy / Normal / Hard) on seeded, mirrored
128 × 128 maps.

- Units: Trooper, Lancer, Field Engineer, Marksman, Hauler, Courser, Warden,
  Bulwark.
- Buildings: Headquarters, Depot, Relay, Barracks, Vehicle Works, Sentry
  Turret, Lance Battery.
- Systems: salvage economy with wrecks, construction and production queues,
  Bandwidth cap, the Signal Grid (link chains, coverage, Linked/Dark effects,
  placement rules), damage types against armor classes, projectiles, forest
  cover, win/lose with a stats screen.

Not in yet (see the roadmap): fog of war, minimap, Uplink Sites, Directives,
veterancy, air units and tier 3, the Foundry Pact and Nomad Circuit factions,
sound, save/load.

## For developers

- [docs/DESIGN.md](docs/DESIGN.md) — the design.
- [docs/ROADMAP.md](docs/ROADMAP.md) — progress and the session log.
- `sim/` is the simulation (plain classes, fixed 20 Hz tick, seeded RNG, no
  scene-tree access). `view/` and `ui/` read it and send `SimCommand`s.
  Definitions are JSON in `data/`.

Checks, on Linux (they download a headless Godot 4.7.2 into `.godot-bin/`):

```bash
tools/check.sh
```

This imports the project, runs the unit tests, boots the menu and battle
scenes headless, drives the interface with synthetic input, walks the whole
menu → match → result loop, and plays a full AI-vs-AI match that must end
with a winner. It fails on any script error.

```bash
tools/screenshot.sh battle 120
```

Captures `screenshots/battle.png` with software rendering (needs `xvfb-run`).

Run one AI-vs-AI match from the command line:

```bash
.godot-bin/godot --headless --path . -s res://tools/headless_match.gd -- --seed=7
```
