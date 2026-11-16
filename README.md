# Signal Front

A near-future real-time strategy game where every army runs on signal.
Build a base, harvest salvage, field tanks and infantry — and keep your relay
network alive, because units outside it fight blind and slow. Cut the enemy's
chain and their front goes dark.

Built with Godot 4.7.2 in typed GDScript. Models, terrain, shaders, effects,
interface art and sound are all generated in code; there are no downloaded
assets.

## Run it

1. Install [Godot 4.7.2](https://godotengine.org/download) (standard build).
2. Open this folder as a project (Import → select `project.godot`). The first
   open takes a few seconds while Godot scans the scripts.
3. Press F5.

From the main menu:

- **Tutorials** — three short missions (economy, the Signal Grid, Directives).
  Start here.
- **Skirmish** — pick a map, a region and a seed, then fill the seats. Each
  of the four seats has a row: who plays it (you, an AI, or nobody), its
  faction, its **team** and the AI's skill. Seats on the same team are
  allies: they do not fight each other, share what they see, and win or
  lose together, so an AI on your team fights at your side (two against
  two, two against one, or everyone for themselves). Give seat one to the
  AI to **watch** instead: no fog of war, and + and - change the speed.
  The setup panel dresses itself in the interface of the faction you pick:
  each of the eight has its own colours, shapes, lettering and emblem, and
  the match's HUD wears the same.
- **Continue Saved Game** — pick up the match you saved from the pause menu
  ("Save Game", or "Save and Quit to Menu"), exactly where it stopped.
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
| Ctrl+A or F2 | Select the whole army (every armed unit) |
| Shift + order | Queue the order |
| Ctrl+1..9, then 1..9 | Set / recall a control group (double-tap centres the camera) |
| G | Toggle the signal coverage overlay |
| . (period) or F1 | Select the next idle builder |
| Ctrl+F5..F8, then F5..F8 | Save / recall a camera bookmark |
| Minimap: left click / right click | Move the camera / order the selection there |
| Alt+1..6, or click a Directive in the bottom bar | Unlock or use a Directive (left click to target, right click to cancel) |
| Letter on a command card button | Build or train that item (hold Shift to queue five) |
| Space | Look at the latest warning |
| + / - | Game speed, from half to three times |
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

**Vesper Array** — an automated legion of drone frames: cheap, quick and
many, but fragile. Linked frames move 15% faster, and frames that go Dark
keep nearly all of their rate of fire, so the Array can raid beyond its own
network. It has no aircraft and no heavy tank.

- Frames: Mote (cheap walking drone), Shard (anti-armor), Weaver (builds,
  repairs, captures).
- Skimmers (hover vehicles): Porter (hauler), Glint (scout), Lash (twin
  repeaters), Halberd (battle skimmer), Aureole (anti-air), Prism (siege,
  tier 3).
- Buildings: Nexus, Cistern, **Spire** (a cheaper relay with a shorter
  reach), Cradle, Assembler, Ward Node (fires at ground and air), Oracle
  (tier 3).

**Verdigris Order** — few, costly and hard to kill. Linked units shrug off
15% of every hit; Dark ones fire at barely half rate, so the Order fights
best on ground it has wired.

- Knights: Vigil (armored rifleman with a shield), Pike (anti-armor lance),
  Mason (builds, repairs, captures).
- Walkers: Dray (four-legged hauler), Outrider (scout), Thresher (twin
  cannons), Castellan (the heaviest gun and armor on the field), Canopy
  (anti-air), Mangonel (siege, tier 3).
- Buildings: Keep, Tithe Barn, **Lantern** (a costly relay with the longest
  reach), Chapterhouse, Armoury, Rampart (gun tower), Watchfire (anti-air),
  Reliquary (tier 3).

**Zephyr Accord** — rules the sky. A thin ground force screens a fleet of
aircraft that fly over any terrain. Linked units see a quarter further.
Flak is its bane.

- Ground: Ranger, Flare (missiles that hit vehicles and aircraft), Rigger
  (builder), Tender (hauler), Lookout (spotter car), Squall (flak truck).
- Aircraft: Swift (light gunship), Lanner (strike craft, anti-armor), Condor
  (heavy bomber, tier 3).
- Buildings: Aerie, Hangar, Mast, Roost, Flight Deck, Gun Pit (fires at
  ground and air), Control Tower (tier 3).

**Crimson Tally** — mercenaries. Everything they destroy pays a bounty of
15% of its value in salvage, so an army that keeps attacking pays for
itself.

- Infantry: Gunhand, Petard (rockets), Tallyman (builder).
- Vehicles: Strongbox (armored hauler), Jackal (raider), Brigand (gun
  truck), Ravager (quick-firing tank), Flakjack (anti-air), Ransom (rocket
  artillery, tier 3).
- Buildings: Counting House, Vault, Signal Post, Billet, Motor Pool, Gun
  Nest, Exchange (tier 3).

**Umbral Veil** — ambushers. Inside their own coverage Veil ground units
vanish whenever they stand still, and their **Sentinel** turrets stay hidden
until they fire. Fragile and costly, with the longest guns on the field.

- Infantry: Shade, Needle (anti-armor sharpshooter), Veilwright (builder).
- Vehicles: Gleaner (hauler), Wisp (the fastest scout), Mirage (gun car),
  Stalker (tank hunter), Pall (anti-air), Eclipse (siege mortar, tier 3).
- Buildings: Sanctum, Reservoir, Obelisk, Hollow, Shroudworks, Sentinel,
  Occulus (tier 3).

### The AI

One to three opponents at Easy, Normal or Hard. Normal and Hard opponents
draw a **doctrine** from the seed: balanced, an aggressor (small waves, early
and often), a fortifier (turrets first, then a big army) or a raider (goes
for relays and depots). They scout, they counter what you field, they cut
your relay chain where it hurts most, and a couple of times a match they
will pull a beaten army back instead of feeding it to you.

## Maps

A seeded, symmetric generator (176 × 176 for two players, a compact 128 × 128
option for shorter matches, 192 × 192 for three or four). The seed also picks
the kind of country: open **plains**, **highlands** crossed by rock ridges
with passes through them, **lakeland**, or (two players only) a **river
valley** with fords. Worn tracks show the routes between the bases.

A battlefield also lies in one of four **regions**, picked by the seed or in
the skirmish setup: the **Greenwood** (grass and woods), the **Dustlands**
(sand, red mesas, cactus and oases), the **Frostline** (snow, capped pines,
ice) and the **Cinder Wastes** (ash, burnt trees and lava). A region changes
how the land looks and nothing about how it plays.

There are also three hand-made layouts: **Twin Fords** (a river with three
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
- Balance and pacing are measured with AI-vs-AI leagues
  (`tools/balance_league.py`), which says how the AI fares with each
  faction, not how a person will. The session log in `docs/ROADMAP.md` has
  the latest table. One-on-one matches between AIs on the default map last
  about a quarter of an hour (the design aims for 15–25 minutes); the
  compact map gives about ten.
- Five of the eight factions were added in one day. They share the AI and
  most rules with the first three, each with one rule of its own, and have
  had far less testing.

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
to ten minutes.

Other tools:

```bash
tools/screenshot.sh battle 120
```

Captures `screenshots/battle.png` with software rendering (needs `xvfb-run`).
`tools/gallery.tscn` puts every model on one sheet, or eight at a time close
up with `page0`..`page7` as the capture script; `scenery_wide`,
`scenery_water`, `scenery_forest`, `scenery_rock` and `scenery_edge` show the
bare landscape with fog off, and `layout_twin_fords`, `layout_crater_ring`
and `layout_crossroads` show a hand-made map whole.

```bash
.godot-bin/godot --headless --path . -s res://tools/headless_match.gd -- --seed=7 --factions=aegis,nomad
```

Plays one AI-vs-AI match (two to four factions; `--map=twin_fords` for a
hand-made layout).

```bash
.godot-bin/godot --headless --path . -s res://tools/balance_batch.gd -- --seeds=1,2,3,4
```

Plays every faction pairing over the seeds and prints win counts.

```bash
.godot-bin/godot --headless --path . -s res://tools/pace_batch.gd -- --seeds=1,2,3 --harvest=5.0 --scale=prowler.cost:0.9
```

Plays every faction pairing with pacing or stats changed in memory and prints
match lengths and win rates; `--trace=1` adds a timeline of each match. See
the comment at the top of the script for every option.

```bash
tools/balance_league.py --seeds 1-8
```

Plays every faction against every other, in parallel, and prints a win-rate
table with the margin to read it by. `--scale mote.cost:1.1` tries a change
without editing the data.

```bash
tools/balance_tune.py --rounds 3 --seeds 1-6
```

Plays leagues and nudges the price of each faction's fighting units toward
an even win rate; `--write` puts the prices into `data/units.json`.

```bash
.godot-bin/godot --headless --path . -s res://tools/invariant_check.gd -- --seeds=1,2 --minutes=15
```

Bug hunt: plays AI matches with every faction and reports any state that
should be impossible.

```bash
.godot-bin/godot --headless --path . -s res://tools/perf_bench.gd
```

Times the simulation tick with 300 units; `tools/frame_bench.tscn` times a
whole frame of the real battle scene.

The hand-made layouts in `data/maps/` are written by `tools/make_layouts.py`;
edit the shapes there and re-run it.
