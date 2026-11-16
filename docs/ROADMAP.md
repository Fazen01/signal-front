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

- [ ] Fixed-tick `SimWorld`, seeded RNG, entity registry, player state
- [ ] Map grid with terrain types and passability
- [ ] Grid pathfinding + steering and separation; move orders
- [ ] Weapons, damage/armor table, projectiles, death, wrecks
- [ ] Orders: move, attack, attack-move, stop, hold
- [ ] Headless test: two mixed squads fight to a deterministic result

## M2 — View and controls

- [ ] Terrain mesh, lighting, RTS camera (pan, zoom, rotate, bounds)
- [ ] Procedural low-poly models for units and buildings with team colours
- [ ] View layer interpolating sim state; health bars; selection rings
- [ ] Click and box selection, context orders, control groups
- [ ] Headless boot test of the battle scene for 600 frames with zero errors

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

Half-done / next: M1 simulation core is being written.
