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

- [ ] Salvage Fields, Haulers, Depots, wreck harvesting
- [ ] Builder units, placement ghost, construction progress, cancel/refund
- [ ] Production queues, rally points, Bandwidth cap
- [ ] HUD: resources, selection panel, command card with hotkeys

## M4 — Signal Grid

- [ ] Emitters, link graph back to HQ, coverage grid
- [ ] Linked/Dark effects on units, turrets and production
- [ ] Placement rules (buildings in coverage, relays in link range)
- [ ] Overlay, link lines, blackout alert, Dark indicator
- [ ] Tests: cutting a mid-chain relay unlinks everything downstream

## M5 — First playable (tag `v0.1`)

- [ ] Aegis Directorate roster complete through T2
- [ ] Skirmish AI: economy, relay expansion, army, attack waves, defense
- [ ] Win/lose conditions, victory screen with stats
- [ ] Main menu → skirmish setup → match → back to menu
- [ ] `tools/check.sh` runs a full headless AI-vs-AI match that ends with a winner
- [ ] README: how to run, controls, what is in the build

## M6 — Battlefield awareness

- [ ] Fog of war and shared vision through coverage
- [ ] Minimap with camera box, click-to-move, alerts
- [ ] Uplink Sites; capture by Field Engineer
- [ ] Double-click select, idle-builder key, camera bookmarks

## M7 — Directives and veterancy

- [ ] Command Points, Directive bar, all six Directives with targeting UI
- [ ] Veterancy ranks and indicators
- [ ] AI uses Directives

## M8 — T3 and air

- [ ] Command Lab, Airpad, Longbow, Kestrel, Scout Drone, Tempest, Flak Post
- [ ] Air movement layer, anti-air targeting rules

## M9 — Foundry Pact

- [ ] Roster, Pylon network, Crawler mobile factory, self-repair when Linked
- [ ] AI plays Foundry Pact

## M10 — Nomad Circuit

- [ ] Roster, Beacon Rigs, relocating HQ, jammers, forest cloak, hijack of Dark vehicles
- [ ] AI plays Nomad Circuit

## M11 — Maps

- [ ] Seeded mirrored map generator; 2- and 4-player sizes
- [ ] Three hand-tuned layouts; up to 3 AI opponents

## M12 — Feel

- [ ] Particles: tracers, muzzle flash, explosions, smoke, debris
- [ ] Procedural SFX and ambient audio, volume settings
- [ ] Unit response feedback: order markers, attack flashes, alert pings

## M13 — Balance and performance

- [ ] Batch AI-vs-AI runs across factions; tune costs and stats toward even win rates
- [ ] AI difficulty levels
- [ ] Profile and hold 60 fps with 300 units

## M14 — Finish

- [ ] Settings (video, audio, key hints), pause menu, save/load of a skirmish
- [ ] Three scripted tutorial missions teaching economy, signal and Directives
- [ ] Windows export preset; final README

## Session log

Newest first. One entry per session: date, what was finished, decisions made,
anything left half-done, whether Godot verification was available.

### 2026-11-16 — session 1 (branch `claude/gracious-lovelace-fxl9n2`)

Status: **in progress** — this entry is updated as work lands.

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

Half-done / next: M3 economy and construction.
