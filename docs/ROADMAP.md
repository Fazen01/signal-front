# Signal Front — Roadmap

Work top to bottom. Tick a box in the same commit that finishes the item.
If an item turns out to be too big, split it in place. Design questions are
answered by [DESIGN.md](DESIGN.md); where it is silent, decide, and note the
decision in the session log at the bottom.

## M0 — Bootstrap

- [x] `project.godot` for Godot 4.7.2 (Compatibility renderer), folder layout
      `sim/ view/ ui/ data/ scenes/ tests/ tools/`, input map
- [x] `tools/install_godot.sh` — fetches the Godot 4.7.2 Linux headless build
      into `.godot-bin/` (git-ignored) if it is not already there
- [x] `tests/run_tests.gd` — minimal headless test runner, non-zero exit on failure
- [x] `tools/check.sh` — import, run tests, fail on any script error
- [x] An empty main scene boots headless with zero errors

## M1 — Simulation core

- [x] Fixed-tick `SimWorld`, seeded RNG, entity registry, player state
- [x] Map grid with terrain types and passability
- [x] Grid pathfinding + steering and separation; move orders
- [x] Weapons, damage/armor table, projectiles, death, wrecks
- [x] Orders: move, attack, attack-move, stop, hold
- [x] Headless test: two mixed squads fight to a deterministic result

## M2 — View and controls

- [x] Terrain mesh, lighting, RTS camera (pan, zoom, rotate, bounds)
- [x] Procedural low-poly models for units and buildings with team colours
- [x] View layer interpolating sim state; health bars; selection rings
- [x] Click and box selection, context orders, control groups
- [x] Headless boot test of the battle scene for 600 frames with zero errors

## M3 — Economy and construction

- [x] Salvage Fields, Haulers, Depots, wreck harvesting
- [x] Builder units, placement ghost, construction progress, cancel/refund
- [x] Production queues, rally points, Bandwidth cap
- [x] HUD: resources, selection panel, command card with hotkeys

## M4 — Signal Grid

- [x] Emitters, link graph back to HQ, coverage grid
- [x] Linked/Dark effects on units, turrets and production
- [x] Placement rules (buildings in coverage, relays in link range)
- [x] Overlay, link lines, blackout alert, Dark indicator
- [x] Tests: cutting a mid-chain relay unlinks everything downstream

## M5 — First playable (tag `v0.1`)

- [x] Aegis Directorate roster complete through T2
- [x] Skirmish AI: economy, relay expansion, army, attack waves, defense
- [x] Win/lose conditions, victory screen with stats
- [x] Main menu → skirmish setup → match → back to menu
- [x] `tools/check.sh` runs a full headless AI-vs-AI match that ends with a winner
- [x] README: how to run, controls, what is in the build

## M6 — Battlefield awareness

- [x] Fog of war and shared vision through coverage
- [x] Minimap with camera box, click-to-move, alerts
- [x] Uplink Sites; capture by Field Engineer
- [x] Double-click select, idle-builder key, camera bookmarks

## M7 — Directives and veterancy

- [x] Command Points, Directive bar, all six Directives with targeting UI
- [x] Veterancy ranks and indicators
- [x] AI uses Directives

## M8 — T3 and air

- [x] Command Lab, Airpad, Longbow, Kestrel, Scout Drone, Tempest, Flak Post
- [x] Air movement layer, anti-air targeting rules

## M9 — Foundry Pact

- [x] Roster, Pylon network, Crawler mobile factory, self-repair when Linked
- [x] AI plays Foundry Pact

## M10 — Nomad Circuit

- [x] Roster, Beacon Rigs, relocating HQ, jammers, forest cloak, hijack of Dark vehicles
- [x] AI plays Nomad Circuit

## M11 — Maps

- [x] Seeded mirrored map generator; 2- and 4-player sizes
- [x] Three hand-tuned layouts; up to 3 AI opponents

## M12 — Feel

- [x] Particles: tracers, muzzle flash, explosions, smoke, debris
- [x] Procedural SFX and ambient audio, volume settings
- [x] Unit response feedback: order markers, attack flashes, alert pings

## M13 — Balance and performance

- [x] Batch AI-vs-AI runs across factions; tune costs and stats toward even win rates
- [x] AI difficulty levels
- [x] Profile the simulation and the view with 300 units and optimise the hot
      spots (`tools/perf_bench.gd`, `tools/frame_bench.tscn`)
- [ ] Confirm 60 fps with 300 units on real hardware (this needs a GPU: the
      sessions only have software rendering, so the draw cost is unmeasured)
- [ ] Bring 1v1 match length up to the 15–25 minute target (AI-vs-AI matches
      average about 9 minutes after tuning)

## M14 — Finish

- [x] Settings (video, audio, key hints), pause menu, save/load of a skirmish
- [x] Three scripted tutorial missions teaching economy, signal and Directives
- [x] Windows export preset; final README

## Session log

Newest first. One entry per session: date, what was finished, decisions made,
anything left half-done, whether Godot verification was available.

### 2026-11-16 — session 4 (branch `claude/relay-session-1116-0654`)

Status: **in progress**, started 06:55 UTC. The newest commit then was
session 3's `b14d2d1` (5 minutes old); waited 10 minutes, nothing new was
pushed, so carried on as CLAUDE.md says. Sessions 2 and 3 had diverged
(both edited `sim/sim_ai.gd`); this branch starts from session 3's tip with
session 2's branch merged in (one conflict, both sides kept).

Godot verification: **available** (4.7.2 downloaded).

The merge broke `tools/check.sh`, although each branch passes it alone: the
three-way match (seed 5) and the spectated Nomad-vs-Foundry match (seed 7)
ran an hour with no winner. Timelines (`tools/match_timeline.gd`, which now
also takes `--map=` and prints haulers, turrets and headquarters health each
minute) showed why: session 2's home guard and retreat rule meant no wave
ever got through a base with turrets, while session 3's emergency income kept
the beaten side alive and the AI spent that trickle rebuilding turrets
instead of haulers. Fixes in `sim/sim_ai.gd`:
- After two failed waves in a row (wiped out or pulled back) the AI masses
  1.4 times the last wave, sends the whole army with no guard, aims it at the
  headquarters and does not retreat.
- When the visible enemy army is worth under a third of ours (and we have 8+
  units), the wave is likewise committed to the headquarters.
- A wave cut to a third of its launch size retreats only if the defence is
  worth more than half of what is left, instead of always.
- Under half its hauler target, the AI keeps a hauler's cost back from
  construction as well as from unit production.
- Known enemy turrets raise the weight of anti-armor units and artillery.

Decision: these are AI rules, not data. They only change what the AI does
when matches stall, so they belong with the wave doctrine in `sim_ai.gd`.

Status (07:45 UTC): **stopped**. `tools/check.sh` passes on `0ef418c` (the
merge plus the fixes above). Then a fetch showed sessions 2 and 3 are
both still running: they pushed at 07:17 and 07:26, after this session's
10-minute wait. Both are on the match-length item, and session 2 has its own
uncommitted stalemate fixes. A third session on the same item would only add
conflicts, so this one stops here as CLAUDE.md says, without opening a PR.

For whoever merges next: this branch holds sessions 2 and 3's pushed work
merged together, with a passing check. Merging it brings in a working
combination; session 2's later anti-stalemate rules may overlap with the
committed-wave rule here (both target the same stalemates), so keep one.

### 2026-11-16 — session 3 (branch `claude/relay-session-1116-0550`)

Status: **in progress**, started 05:50 UTC from `f728680` (session 2's last
commit, 43 minutes old with no later push, so session 2 was taken as cut
off). Godot 4.7.2 downloaded; software GL to be confirmed below.

Godot verification: **available**, including software-GL screenshots.

Done so far:
- Looked at screenshots of every screen (menu, setup, tutorials, settings,
  help, battle, builder and HQ command cards, signal overlay, directives,
  combat, result, pause, Foundry, Nomad, tutorial panel) after session 2's
  HUD commit: nothing clipped, overlapping or missing.
- Softlock fix: a player whose haulers were all killed while they had less
  salvage than a hauler costs could never recover (seen in AI matches: a side
  sat at 35 salvage for three minutes until it died). Such a player now gets
  `emergency_income_per_second` (4) until a hauler is affordable, and the AI
  replaces haulers before soldiers when it is under half its hauler target.
- `tools/pace_batch.gd`: plays batches with pacing knobs scaled in memory
  (build times, harvest time, structure health, turret damage, AI wave
  timing) and has a `--trace=1` timeline. Baseline on seeds 1-3, all nine
  pairings: average 10.0 minutes, median 9.4.

Working on: the open M13 item on 1v1 match length. Findings so far (27
games each): build and harvest times x1.5 -> median 11.1; unit build x2 ->
12.2; HQ health x2.5 with tougher buildings and turrets -> 10.4. Traces show
matches are decided by minute 3-6 when one army is wiped out; the rest is
mopping up. Slower macro plus tougher defences together -> average 13.9; a
larger generated map (88 cells instead of 64) alone -> 13.6, median 12.0.
Tried and dropped: waves that retreat when cut below 40% made matches
shorter (8.4), because the survivors die running and the enemy follows.

### 2026-11-16 — session 2 (branch `claude/relay-session-1116-0451`)

Status: **stopped pushing** at 06:24 UTC (`f959f9e`). Started 04:51 UTC from
`3a43a9e` (session 1's last commit). It ran in parallel with session 3
without either seeing the other's later commits; session 4 merged the two.
The "In progress" paragraph below describes work that was never pushed.

Done so far:
- Looked at screenshots of the menu, skirmish setup, HUD states, signal
  overlay, Directives, combat and result screens. Three faults fixed: the
  minimap's camera box was drawn outside the minimap over the selection
  text; "[C] Command Lab" was cut off on the command card; the bottom panel
  was see-through enough to make its text hard to read.
- `tools/match_timeline.gd`: plays one AI match and prints every wave
  (size, survivors), every building lost and both treasuries each minute.
- Two AI faults the timeline showed, both fixed:
  - It re-placed a building site on the same spot each time the enemy shot
    one down (13 Depots, 3,200 salvage, lost in 80 seconds in one match). It
    now avoids a spot for two minutes after losing a site there and does not
    place sites within 16 units of a visible armed enemy.
  - One unplaceable building (usually that Depot) blocked the whole build
    order, so the AI sat on 3,000-4,000 salvage with one Barracks and one
    Vehicle Works. Blocked entries are now skipped for 30 seconds.
- AI wave doctrine: no attack before 6:00 / 4:00 / 2:30 (Easy / Normal /
  Hard); a guard of 40% / 30% / 25% of the army stays home; Normal and Hard
  pull a wave back when it is down to a third or facing 1.5 times its value.

In progress (07:35 UTC): match length (the open M13 item). Averages over
three seeds per faction pairing, 27 games each:
- baseline 10.0 minutes; first attack delayed to 4:00 alone 10.1; harvesting
  2.5 times slower on top 11.0; guard + retreat + the two fixes above 9.4.
  The first large clash decided the match whenever it happened.
- What moved it: a much slower economy (loading 100 salvage takes 12 s, was
  4 s) 12.7; retreating units defend their base instead of walking through
  the fight 12.9; loading time in proportion to the load 13.1; headquarters
  health +50% and a longer-ranged headquarters gun 17.3 but with two
  60-minute stalemates; anti-stalemate rules (third wave in a row commits,
  siege units when the enemy army is gone) and richer fields 20.6 with one
  stalemate left.
- Still to do before this lands: remove the remaining stalemate, rebalance
  the factions (Aegis is winning too much under the slower economy), run
  the full check. None of this is committed yet; the working tree holds it.

### 2026-11-16 — session 1 (branch `claude/gracious-lovelace-fxl9n2`)

Status: **finished** at about 04:00 UTC, M0 through M14 (two split-out M13
items left open, see below).

Where things stand, for whoever reads this first:
- The game is playable end to end: menu -> tutorials or skirmish (three
  factions, generated or hand-made maps, one to three AI opponents) -> match
  -> result, with save/load, settings and a Windows export preset.
- `tools/check.sh` passes on the last pushed commit: 120 unit tests, headless
  boots, synthetic-input smoke runs, the full flow from the project and from
  an exported pack, and five AI-vs-AI matches that each end with a winner.
- Open roadmap items: confirming 60 fps on a real GPU, and match length (AI
  matches last about 9 minutes, the design wants 15-25).
- Never verified by a person: how it feels with a real mouse and keyboard,
  how it sounds, how it performs on a GPU. Start there.
- The rest of this entry is in the order things were built: each milestone's
  summary, then the decisions taken for it. Notes marked "(later: ...)" were
  true when written and have since been dealt with.

Godot verification: **available**. `tools/install_godot.sh` downloads the
official 4.7.2 Linux build and `tools/check.sh` runs it headless. A
software-GL display (`xvfb-run` + `--rendering-driver opengl3`, Mesa llvmpipe)
also works here, so screenshots can be captured and looked at.

Finished:
- M0 Bootstrap: project file, folder layout, input map, Godot installer, test
  runner, `tools/check.sh` (import → unit tests → headless boot of the main
  scene; fails on any `SCRIPT ERROR`, engine `ERROR:` or warning-as-error).

Decisions:
- GDScript warnings `untyped_declaration`, `unused_variable`,
  `shadowed_variable`, `unreachable_code` and `standalone_expression` are
  errors in `project.godot`, so untyped code does not load at all.
- Godot exits 0 even when a script fails to parse, so `check.sh` greps the
  output of every step instead of trusting exit codes alone.
- Scenes are tiny hand-written `.tscn` files (root node + script); everything
  else is built in code, because nobody can open the editor.
- Camera keys: the design gives WASD to the camera and A/S to attack-move and
  stop. Arrow keys, W and D always pan; A and S pan only while no units are
  selected, otherwise they are the unit orders.
- `.uid` files that Godot generates next to scripts are committed (standard
  for Godot 4.4+); `.godot/` is not.

- M1 Simulation core: `SimWorld` fixed 20 Hz tick, seeded `SimRng`, entity
  registry, players, map grid with terrain, `AStarGrid2D` pathfinding with
  string-pulling, steering/separation, formation move orders, weapons, damage
  table, projectiles, death, wrecks, move / attack / attack-move / stop / hold,
  and a deterministic mixed-squad battle test.

More decisions:
- One map cell is 2x2 world units and is shared by terrain, pathfinding,
  building footprints and (later) signal coverage. A 2-player map is 64x64
  cells = 128x128 world units.
- Pathfinding uses Godot's built-in `AStarGrid2D` (a plain `RefCounted`, no
  scene tree) with one grid for infantry and one for vehicles (forest costs
  vehicles double).
- Definitions are JSON in `data/` loaded into typed `EntityDef` / `WeaponDef`
  / `FactionDef` objects by `sim/defs/game_data.gd`; unknown keys are errors.
- Everything outside `sim/` changes the simulation only through
  `SimWorld.push_command(SimCommand)`; commands apply at the next tick.
- Infantry stop to shoot; turreted vehicles fire on the move. Units on a plain
  move order only shoot what is already in range; attack-move and idle units
  chase what they see (idle units give up 18 units from where they stood).
- The HQ has a light point-defence gun (not in the design) so a couple of
  early raiders cannot end a match on their own.
- GDScript gotcha, now avoided: a method named like a global function
  (`randf`, `randi_range`...) is shadowed by the global one when called
  unqualified inside the class. `SimRng` uses `next_float` / `range_f` /
  `range_i` for that reason.

Notes:
- Early in this session `git push` was refused (the Claude GitHub App had no
  write access to the repository). The owner granted access and pushes work
  now; if a later session sees a 403 on push, that is the cause.

- M2 View and controls: terrain mesh with trees/boulders/water, sun and
  ambient light, RTS camera, procedural models for the whole T1/T2 Aegis
  roster, interpolated entity views with turrets, projectile and tracer
  effects, health bars, selection rings, click/box/double-click selection,
  context orders, attack-move/stop/hold keys, control groups.
- Verification tooling: `tools/screenshot.sh` (software-GL screenshots into
  the git-ignored `screenshots/`), `tools/gallery.tscn` (every model on one
  sheet) and a headless smoke driver (`--smoke`) that feeds synthetic mouse
  and key events through the real input handlers; `check.sh` runs it.

View decisions:
- Models face +X and are built from cached primitive meshes in
  `view/model_factory.gd`; a child named `Turret` follows the weapon aim.
- Health bars and the drag box are drawn in 2D by `ui/battle_overlay.gd`
  from projected positions; selection rings are 3D.
- Map heights are cosmetic (units are simulated in 2D) but are baked into
  `SimMap.heights` so the mesh and unit placement agree.

- M3 Economy and construction: haulers work fields and wrecks and unload at
  depots; engineers place construction sites (ghost tinted valid/invalid),
  extra builders help with diminishing returns (sqrt), unfinished buildings
  cancel for a full refund; production queues of 5 with rally points and the
  bandwidth cap; HUD with resources, selection panel, command card with
  hotkeys, production queue and alerts.

Economy and HUD decisions:
- Costs are paid up front (on placing a site or queueing a unit) and fully
  refunded on cancel. Repair is free but only works on Linked buildings.
- New haulers start harvesting the nearest field on their own unless the
  building has a player-set rally point. Haulers pick up wrecks too.
- Command-card hotkeys never use W, A, S, D, Q, E, G or H (camera and order
  keys); a data test enforces it. Depot is P, Hauler is U, Warden is R.
- A screenshot showed the HUD collapsed into a corner even though every
  headless check passed (`set_anchors_preset` keeps the old zero size; use
  `set_anchors_and_offsets_preset`). Look at screenshots after UI changes.

- M4 Signal Grid: emitters link breadth-first from the HQ within range 30;
  per-player coverage grid rebuilt at most 4x a second; Dark units fire
  slower, see less and lose the Aegis range bonus; Dark buildings pause
  production and cannot be repaired; Dark turrets fire at half rate;
  placement needs coverage (relays need link range); unlinked relays give no
  bandwidth and raise a blackout alert; coverage overlay (G), animated link
  lines, Dark icon over affected units, reach ring on a relay ghost.

Signal decisions:
- Only finished buildings emit. Coverage is "cell centre inside the disc".
- Units without any HQ (test worlds) are simply Dark.
- The overlay dims uncovered ground and tints covered ground in the team
  colour with a brighter rim; it shows only the local player's network.

- M5 First playable (tag `v0.1`): scripted-priority skirmish AI (hauler
  economy, build order, relay expansion toward uncovered salvage, depots at
  far fields, turrets, army mix weighted by enemy composition, staged attack
  waves that prefer relays whose loss cuts the most enemy network, base
  defence, three difficulty levels); HQ-loss defeat and surrender; main menu,
  skirmish setup, pause menu, victory/defeat screen with stats; README.
  `check.sh` now also walks menu → setup → match → result → menu headless and
  plays a full AI-vs-AI match (seed 1 ends at about 8:36 game time in ~8 s).

M5 decisions and known gaps:
- A player is defeated when their HQ is destroyed; all their remaining units
  and buildings are destroyed with it.
- The AI currently sees the whole map (there is no fog of war until M6). When
  fog lands it must be limited to what it has scouted. (later: done in M6.)
- Two T2 roster details wait for later systems: the Marksman's "stealth while
  still" needs fog of war (M6) and the Field Engineer's "capture" needs Uplink
  Sites (M6). Everything else in the T1/T2 Aegis roster is in. (later: both
  done in M6.)
- AI-vs-AI matches on seeds 1-7 all end with a winner in 7-15 game minutes,
  shorter than the 15-25 minute target, and the first player wins more often
  than the second. Income is high (~2,500 salvage a minute mid-game) and the
  AI floats salvage because it runs one Barracks and one Vehicle Works.
  Left for M13 balance; noted so it is not mistaken for a bug. (later: M13
  removed the seat bias and M11 the floating salvage; match length is still
  open.)

Notes on this session's pushes:
- The `v0.1` tag could not be pushed: the session may only write its own
  branch (`send-pack: unexpected disconnect`). The tag exists only in this
  session's clone. The M5 commit to tag is `457055b`.

- M6 Battlefield awareness: fog of war with vision shared through coverage,
  Marksman stealth, minimap (camera box, click to move, right-click orders,
  alert pings), Uplink Sites captured by Field Engineers, double-click
  select, idle-builder key (period or F1), camera bookmarks (Ctrl+F5..F8).

- M7 Directives and veterancy: Command Points from value destroyed, six
  Directives with unlock costs, cooldowns and targeting rules, a Directive
  bar (click or Alt+1..6) with a targeting ring, ground effects, veterancy
  ranks with chevrons; the Normal and Hard AI unlock and use Directives.

- M8 Tier 3 and air: Command Lab, Airpad, Flak Post, Tempest, Longbow,
  Kestrel and Scout Drone with models; an air movement layer (aircraft fly
  straight, ignore terrain and buildings, only crowd each other); per-weapon
  `hits_air` / `hits_ground`; artillery minimum range and scatter.

- M9 Foundry Pact: full second faction (10 units, 9 buildings, own models
  and palette), Pylon web, Crawler deploy/pack with a placement ghost, mines,
  Ratchet repair, Linked-vehicle self-repair, faction choice for both sides
  in the skirmish setup. The AI is now role-based and plays either faction;
  `check.sh` also runs a Foundry-vs-Aegis match and drives the Crawler's
  Deploy/Pack through the real interface.

- M10 Nomad Circuit: full third faction (11 units, 7 buildings, own models
  and palette), deployable Beacon Rigs instead of relays, the Caravan Hub
  that packs up and relocates, Jammer Buggy, forest cloak, Splicer hijack of
  Dark vehicles (right-click), +50% wreck salvage. The AI plays Nomad:
  it builds and deploys rigs toward uncovered salvage and sends Splicers
  after Dark vehicles. `check.sh` adds a Nomad-vs-Foundry match.

- M11 Maps: the generator makes two-player (128 x 128, half-turn symmetric)
  and four-player (192 x 192, quarter-turn symmetric) maps; three hand-made
  layouts in `data/maps/` (Twin Fords, Crater Ring, Crossroads); skirmish
  setup chooses the map and one to three AI opponents (free-for-all).
  `check.sh` adds a match on a layout and a three-way match.

- M12 Feel: CPU-particle debris, smoke, sparks and dust on impacts and
  deaths, missile exhaust trails, smoke from badly damaged vehicles and
  buildings; 17 sounds synthesised in code (`view/sound_bank.gd`) with a
  looping ambient bed, played through a pooled `AudioManager` that fades
  with distance from the camera; Master / Effects / Ambience volume sliders
  saved to `user://settings.cfg`; order acknowledgement and selection blips,
  hit sparks, alert sounds and minimap pings.

- M13 Balance and performance (three of five items; two were split out and
  are still open, see the roadmap): `tools/balance_batch.gd` plays every
  ordered faction pairing over a list of seeds; four tuning passes;
  difficulty levels measured; simulation and view profiled and optimised.

- M14, first item: settings for audio, video (fullscreen, vsync, shadows,
  anti-aliasing) and hotkey hints; Save Game in the pause menu and Load
  Saved Game on the main menu (one slot, `user://skirmish.sav`).

- M14, second item: three tutorial missions (`sim/sim_tutorial.gd`) for the
  economy, the Signal Grid and Directives, with an objective panel, a pulsing
  ground marker, minimap pings and a mission-complete screen that leads to
  the next mission. Tests complete each mission by issuing the commands its
  objectives ask for; `check.sh` plays one through the real interface.

- M14, third item: `export_presets.cfg` with a "Windows Desktop" preset,
  `tools/export_windows.sh`, and the final README. The export was run here
  (templates downloaded): it wrote a 110 MB `SignalFront.exe`. The `.exe`
  could not be executed on Linux, but the same preset exported as a pack
  runs the whole menu -> match -> load -> tutorial flow with the Linux
  binary, and `check.sh` now repeats that on every run (exporting a pack
  needs no templates).

Half-done / next: every roadmap box is ticked except two that were split
out of M13 and need things a headless session does not have:
1. Confirm 60 fps with 300 units on real hardware.
2. Bring 1v1 match length up to 15-25 minutes (see the match-length
   experiment below for what did not work).
After those, the most valuable work is a human play-through: nobody has
used a real mouse, seen the game move, or heard it.

Fog decisions:
- "Shared vision through coverage" is implemented as: everything inside your
  own signal coverage is visible to you, plus a disc of each unit's sight
  (30% shorter when Dark). Units can fire on anything any friendly source
  reveals, if it is in weapon range.
- A stealthed Marksman (standing still, not fired for 2.5 s) is only seen by
  an enemy within 5 units.
- An attack order on a unit you cannot see becomes an attack-move to where it
  was; buildings can be targeted once explored.
- In the view, enemy units show only while seen; enemy buildings and neutral
  objects stay drawn once seen (a building destroyed out of sight stays as a
  ghost until the spot is seen again). Trees and boulders are darkened per
  instance so they do not glow out of the fog.
- "X under attack" alerts fire at most every 15 s per player, for buildings
  and haulers, and ping the minimap.
- Uplink Sites: the design pays "whoever has them inside their coverage" and
  the roadmap adds capture by engineer. Implemented as both: an engineer
  captures the site (8 s), and it pays 3 salvage a second only while inside
  its owner's coverage. An enemy engineer can flip it. Sites cannot be
  destroyed and go neutral if their owner is defeated.
- Directives: 1 Command Point per 300 salvage of enemy value destroyed, plus
  1 to start. Points unlock a Directive permanently; after that it is free to
  use on its cooldown. Unlock costs: Recon 1, Repair 2, Surge 2, Barrage 3,
  Blackout 3, Drop 4. The barrage never hurts its owner's units.
- Veterancy: ranks at 2x, 4x and 8x the unit's own cost in value destroyed;
  each rank +15% damage and +10% health; rank 3 repairs 1% health a second
  after 5 s without taking damage.
- Directive hotkeys are Alt+1..6 (plain digits are control groups).
- The AI unlocks Directives in a fixed order (Recon, Barrage, Repair, Drop,
  Blackout, Surge), barrages visible clusters of 3+, repairs clusters of
  damaged units, blacks out the assault target and surges during assaults.
  The Easy AI does not use Directives.
- With Directives in, AI-vs-AI seed 1 runs 15:29 (was about 9-10 minutes).
- Air: aircraft are simulated in 2D like everything else and drawn 6 units
  up. Rifles, machine guns, autocannons and missiles can hit them (weakly,
  per the damage table); tank cannons, artillery and rockets cannot; the
  Flak Post cannot hit ground. Aircraft leave no wreck.
- The Tempest is tier 2 (Vehicle Works) so anti-air exists before aircraft
  do. The Command Lab's "Directive upgrades" are a 25% shorter cooldown on
  every Directive while a linked lab stands.
- The Field Engineer's command card is now full (9 buildings + 3 orders = 12
  slots). The next faction building for an engineer needs a bigger card or a
  second page.
- The AI builds a Command Lab and Airpad from about minute 4 on Normal/Hard,
  mixes in Kestrels and Longbows, and answers enemy aircraft with Tempests
  and Flak Posts. It does not build Scout Drones yet.
- Foundry additions beyond the design's signature list, so the faction is
  complete: Breaker (anti-armor infantry), Scow (hauler), Tusk (tier 2 line
  vehicle), Harrow (anti-air), and the buildings Foundry Core, Scrapyard,
  Muster Hall, Bastion, Skyspike, Arsenal. The Foundry has no aircraft.
- The Foundry has no fixed vehicle factory: vehicles come from a deployed
  Crawler (trained at the Foundry Core once a Muster Hall stands).
- Mines are non-blocking, stealthed buildings the Sapper places like any
  other building (2.5 s to arm, 40 salvage, anywhere on walkable ground). An
  enemy sees one only within 2.2 units; ground units within 1.7 set it off.
- Pylons give +5 bandwidth (Relays +10) because they cost about half.
- The AI no longer names any unit or building: `data/factions.json` maps
  roles (builder, hauler, relay, barracks, works or mobile factory, depot,
  turrets, tier3, airpad) to definitions and `data/units.json` gives each
  army unit an `ai_role` and `ai_weight`. A new faction needs only data.
- Reinforcement Drop squads are per faction (`drop_squad`).
- Nomad additions beyond the design's signature list: Drifter, Tinker
  (builder), Skiff (hauler), Gnat (anti-air), Prowler (light tank), and the
  buildings Cache, Camp, Chop Shop, Snare Turret, Signal Loom. No aircraft.
- Deploy rules are shared by all deployable units: a headquarters deploys
  anywhere buildable, an emitter (Beacon) within link range of a linked
  emitter, anything else (Crawler) inside coverage.
- A packed headquarters still counts as alive; while it is packed its owner
  has no coverage and no bandwidth. The AI never relocates its HQ.
- A jammer clears enemy coverage in an 11-unit disc that follows it; the
  grid is rebuilt (at most 4x a second) while any jammer is alive.
- Hijack: 4 seconds next to an enemy vehicle that is Dark and visible. The
  vehicle changes owner with its hit points, the Splicer is consumed. Any
  vehicle can be taken, including haulers, Crawlers and Beacon Rigs.
- Forest cloak applies to Nomad ground units standing still in forest that
  have not fired for 2.5 s; enemies within 5 units still see them.
- Balance between the factions is untuned (M13). In the seed-3 samples the
  Nomads beat Aegis from the first seat and lost from the second, and lost
  to Foundry.
- Layouts are JSON grids of characters (legend in `sim/sim_map_gen.gd`).
  They are produced by `tools/make_layouts.py`, which paints explicit shapes
  together with their rotated images; edit and re-run it to change a layout.
- With more than two players every AI is its own team (free-for-all) and
  attacks the nearest surviving enemy. Three players use three of the four
  starts on a four-start map. A layout with too few starts falls back to a
  generated map.
- AI fixes found by the first stalemates (two matches ran 60 minutes with no
  winner): it now keeps enough salvage back for a hauler and a builder when
  it has none, attacks with whatever it has after 2.5 minutes without a wave
  instead of waiting for an ever-larger one, adds production buildings when
  salvage piles up, and saves up for the unit it picked rather than always
  buying the cheapest thing it can afford.
- `check.sh` now takes about three minutes (five AI matches).
- Audio could not be listened to here (the audio driver is the dummy one).
  The sound bank is tested for existing, being audible in amplitude and not
  clipping, but nobody has heard it. Expect to adjust levels and timbre by
  ear; every sound is a few lines in `view/sound_bank.gd`.
- Particle emitters are capped at 56 live bursts; beyond that new bursts are
  skipped rather than queued.
- Balance, measured with `tools/balance_batch.gd` (Normal vs Normal, six
  seeds per ordered pairing, 24 games per faction against the other two):
  - Before tuning: Aegis beat Foundry 11-1 and Nomad 7-4; Foundry beat Nomad
    10-2; the first seat won the Aegis mirror 5-1.
  - After four passes, on seeds 7-12 that the tuning had not seen: Aegis
    58%, Foundry 54%, Nomad 38% (Aegis-Foundry 7-5, Aegis-Nomad 7-5,
    Foundry-Nomad 8-4); every mirror split 3-3. With 24 games each the noise
    is roughly +/-10 points, so only the Nomad figure is clearly off.
  - What changed: units now fire in alternating order each tick and the AIs
    alternate who thinks first (this removed the first-seat bias); Trooper
    60 -> 55; Lance Missile 40 -> 44; Crawler 420 -> 380 and 22 s -> 18 s;
    Tusk hp 620 -> 580; Bastion 220 -> 190; Prowler is tier 2, cheaper (280)
    and armor-piercing; Sidewinder cheaper, tougher, hits harder; Dart and
    Drifter tougher; Beacon +10 bandwidth; Snare Turret tougher; Chop Shop
    340 -> 300.
  - Not addressed: AI-vs-AI matches average about 9 game minutes against the
    15-25 minute target. Slowing income is the obvious lever
    (`harvest_seconds`, field amounts) but it moves every matchup, so it
    needs its own batch.
- Difficulty, same tool with `--levels`: Hard beat Easy in 21 of 24 games,
  Hard beat Normal in 8 of 12, Normal beat Easy in 9 of 12. A unit test that
  asserted one seeded Hard-vs-Easy result was tried and dropped: single
  matches flip with any stat change.
- Performance, on this container's CPU (no GPU): with 313 units in one fight
  the simulation tick averages 6.7-6.9 ms (was 9.9) with spikes of 17-31 ms
  (was 54); the whole frame's script and scene processing averages 6.6-8 ms
  with a 24-25 ms worst frame, against a 16.7 ms budget at 60 fps. Changes:
  per-armor damage, range and minimum-range tables precomputed per unit
  type; target scans walk the spatial buckets inline and run less often when
  a unit already has a target; stationary units are separated every other
  tick; at most 24 new move orders are pathed per tick; path smoothing uses
  shrinking strides; the minimap redraws 20 times a second from a
  precomputed palette; selection lookups use a set.
- `Performance.TIME_PROCESS` read 36 ms per frame in headless mode while
  wall-clock frame time was 8 ms. Do not trust that monitor headless; the
  frame benchmark measures wall-clock time between frames instead.
- Match-length experiment (reverted): cutting hauler loads by a quarter and
  lengthening harvesting from 4 s to 5 s (about -30% income) moved the
  AI-vs-AI average only from about 9 to 10.6 minutes and shifted the win
  rates to Aegis 58% / Foundry 33% / Nomad 58%. Income is not the main
  driver of match length; the AI's early waves are. The next thing to try is
  the AI's wave timing and the durability of headquarters and turrets.
- Save/load (`sim/sim_save.gd`): the map is rebuilt from the match
  configuration and everything else is written as plain values found by
  reflection over script variables, so new fields are saved without touching
  the save code. A restored match continues tick-for-tick identically (a
  test plays on from both and compares state hashes). Pending commands and
  the coverage/vision grids are part of the snapshot. Saves carry a version
  number and are refused if it differs or if they name an unknown unit.
- Godot 4 packed arrays are shared by reference: an early version of the
  snapshot shared the cooldown arrays with the live world and the two
  drifted apart. Everything is deep-copied in and out now.
- Tutorials are simulation-side: a mission is a prepared world plus ordered
  objectives, each a check on the simulation, so missions are testable with
  no interface. The opponent is a non-AI player that only stands there and
  defeat is switched off. Two flaws the tests caught and fixed: Haulers
  salvaged the lesson's wreck before the player was asked to (it now appears
  when that objective begins), and a relay objective sat inside enemy turret
  range. Tutorials cannot be saved.
- The test runner now fails any test during which an engine or script error
  was raised (a `Logger` counts them). Before this a test that crashed
  half-way was printed as ok and only `check.sh`'s grep caught it.
- `export_presets.cfg` was listed in `.gitignore`. It is tracked now (the
  line was removed and a comment explains why): the roadmap asks for the
  preset and it holds no credentials. The preset adds `data/*.json` and
  `data/maps/*.json` to the export, which Godot would otherwise leave out,
  and leaves out `tools/`, `tests/` and `docs/`.
- Second match-length experiment (also reverted): making every AI level wait
  for a larger first wave (7 -> 11 units on Normal) with longer gaps between
  waves left the average at about 9.6 minutes and swung the win rates to
  Aegis 75% / Foundry 17% / Nomad 58%. Neither income nor wave timing moves
  match length much; games end soon after the first army breaks through.
  What is left to try is the defender's side: headquarters and turret
  durability, and how quickly a base falls once its army is gone.
- `check.sh` gained a `spectate` step: the real battle scene plays a whole
  Nomad-vs-Foundry AI match at 30x speed (`-- --spectate=nomad,foundry`), so
  every view, HUD, effect and sound path runs through a full match, not just
  the first seconds.
