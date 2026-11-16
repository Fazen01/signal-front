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
- [x] Bring 1v1 match length up to the 15–25 minute target (AI-vs-AI matches
      averaged about 9-10 minutes; now median 16.6 on the default map, see
      session 3)

## M14 — Finish

- [x] Settings (video, audio, key hints), pause menu, save/load of a skirmish
- [x] Three scripted tutorial missions teaching economy, signal and Directives
- [x] Windows export preset; final README

## M15 — Visual upgrade (owner request, 16 November)

The owner asked for the units, buildings and map to look better. View layer
only (`view/`): nothing here changes the simulation or the data.

- [x] Terrain: blended ground colours instead of per-cell checks, shores,
      ground scatter, better trees and rocks, animated water, sky and lighting
- [x] Models: every unit and building is baked into one mesh per rigid part
      (one draw call each instead of one per box), with chamfered edges and
      ground shading; tracks with road wheels, wheels with hubs, soldiers
      with limbs; lamps, windows, hatches, aerials and radar across all three
      factions
- [x] Life: turret recoil, spinning dishes, hauler cargo that fills up,
      infantry bounce as they walk
- [x] Buildings under construction stand inside scaffolding; buildings and
      vehicles close to destruction burn
- [x] Effects: glowing tracers, muzzle flashes, shock rings, scorch marks,
      flashes that light their surroundings; effects fade out properly
- [x] A live AI-versus-AI match plays behind the main menu
- [x] Minimap and coverage overlay colours retuned for the new ground
- [x] Dust behind ground vehicles on the move

## M16 — Interface (owner request, 16 November)

The owner asked for the UI and main menu to look better. `ui/` only.

- [x] One interface theme built in code (`UiTheme`): glass panels, buttons,
      dropdowns, sliders, entry fields, tooltips, heading and value fonts
- [x] Main menu: logo and menu in a column on the left, the live match in
      full view on the right, a caption saying which factions are fighting
- [x] HUD: top strip with drawn icons and a bandwidth meter; bottom bar in
      three framed sections; command card buttons with a hotkey badge and
      the cost in gold; Directives light up gold when ready
- [x] Skirmish setup, pause, result, settings and tutorial panels share the
      theme; the main action of a panel is a highlighted button

## M17 — Map dressing (owner request, 16 November)

The owner asked for the map to be improved further. View layer only: the
generator, the layouts and everything the simulation reads are untouched.

- [x] Tracks worn along the routes vehicles would take between the bases,
      the middle of the map and the uplink sites; packed earth where the
      bases stand; stained ground under salvage fields
- [x] A shaded border of the same country beyond the playable edge (ground,
      woods, crags) instead of a drop into darkness; it follows the fog of war
- [x] Cloud shadows drifting over the ground and the scatter
- [x] Flowers in patches, reeds along the water, fallen logs and stumps at
      the edge of the woods

## M18 — Map generator (owner request, 16 November)

The owner asked for trees and stones to keep off the tracks, and for the
map generation itself to be improved.

- [x] Trees, bushes, boulders, stones, logs and stumps keep off the tracks
- [x] The seed picks a kind of country: plains, highlands (rock ridges with
      passes), lakeland, or a river valley with fords (two players only)
- [x] Irregular woods, lakes and outcrops instead of round blobs; woods no
      longer overwrite water or rock
- [x] Uplink sites are part of the reachability check; tests for every kind,
      determinism, symmetry and river crossings
- [x] Match length checked against the old generator

## M20 — A fourth faction: the Vesper Array (owner request, 16 November)

- [x] Design: drone frames that are cheap, quick and fragile; faster while
      Linked, nearly unaffected by going Dark; hover skimmers, no aircraft
- [x] Data: nine units, seven buildings, eight weapons, AI roles
- [x] One new rule in the simulation: `linked_speed_bonus` on a faction
- [x] Models for all sixteen, in their own palette (pale shells, dark
      frames, violet light)
- [x] Tests, an AI match in `tools/check.sh`, README and design updated
- [x] Second look pass after the owner said it looked bad: a calmer
      palette instead of stark white, stepped hulls, six-sided turrets, lift
      pods, chunkier frames, lit corner posts on every base
- [ ] Balance against the other three measured over a larger batch

## Session log

Newest first. One entry per session: date, what was finished, decisions made,
anything left half-done, whether Godot verification was available.

### 2026-11-16 — session 1, resumed 09:05 UTC (branch `claude/gracious-lovelace-fxl9n2`)

Status: **finished** (M15, M16, M17). The owner wrote in at about 09:05 UTC asking for
better graphics (units, buildings, map) and to carry on; that is M15 above.

- This branch was fast-forwarded to `claude/relay-session-1116-0550` (the
  newest remote commit, `3043c77`) before starting. Sessions 2 and 3 were
  still pushing at the time. The stand-down rule in `CLAUDE.md` was not
  applied because the owner asked for this work directly and it touches
  only `view/`, which neither of them is changing.
- `claude/relay-session-1116-0451` and `claude/relay-session-1116-0654` do
  not merge cleanly into this branch (`sim/sim_ai.gd` and
  `sim/sim_map_gen.gd` conflict with session 3's changes). They are left for
  the owner or a later session to reconcile; nothing from them is here.
- Godot verification: available, software-GL screenshots included. Baseline
  screenshots of the old look were taken first for comparison.

- **Decision: units are drawn larger than their footprint** (vehicles ×1.1,
  infantry ×1.25, view only). At the usual camera height infantry were a
  dozen pixels tall. Nothing in the simulation changes.
- **Decision: linear tone mapping.** Filmic washed the team colours out to
  pastel; linear keeps them saturated and the light levels are set so
  nothing but lamps reaches full white.
- **Finding: vertex colours arrive in shaders already converted to linear
  light** in the Compatibility renderer. Converting again in the shader
  made every model nearly black. Anything that is a weight rather than a
  colour (the terrain blend) travels in UV channels instead.
- **Finding: water used to disappear on high ground.** The old water was one
  flat plane, and the height field rolls by more than the water is sunk, so
  rivers on a rise showed as dry, impassable grass. The new water surface
  follows the land around it.
- Shader code cannot be checked headless (the dummy renderer does not
  compile it). Every shader here was compiled and looked at through
  `tools/screenshot.sh`; `tools/check.sh` only proves the scripts run.
- New capture scripts: `scenery_water`, `scenery_forest`, `scenery_rock`,
  `scenery_wide` (fog off), and `page0`..`page7` for `tools/gallery.tscn`
  (eight models at a time, close up).

- **Finding: `GeometryInstance3D.transparency` does nothing in the
  Compatibility renderer** (measured: three boxes at 0, 0.4 and 0.8 all
  rendered fully opaque). Every combat effect used it to fade, so until now
  flashes and rings simply popped out of existence. Effects now own a
  material each (pooled) and fade through its alpha.
- **Decision: no bloom.** `Environment.glow_*` was tried and produced no
  visible halo here, so it is left off rather than spend a full-screen pass
  on nothing. Lamps and furnace mouths get their punch from emission alone.
- **Decision: the main menu shows a live AI-versus-AI match** (`MenuBackdrop`,
  fog off, no sound) under a dimming layer. It restarts on a new seed when a
  match ends. It costs one simulation and one set of views while the menu is
  open.
- The frame benchmark is unchanged by all this: 7.3 ms a frame with 300
  units, same as before (`tools/frame_bench.tscn`). Draw calls per unit are
  down from one per box to two or three, which only a real GPU will show.
- Not from this work, for whoever looks next: every scene that plays sound
  exits with "2 ObjectDB instances were leaked" (an `AudioStreamWAV` and its
  playback). It is a warning, it predates M15, and `tools/check.sh` does not
  treat it as a failure.
- `claude/relay-session-1116-0550` (session 3, finished) was merged again at
  09:48 UTC, cleanly.

- The coverage tint inside your own network is lighter than it was (so the
  ground shows through) and uncovered ground is dimmed a little more; the
  bright rim is unchanged.

- Vehicle dust is thinned out when more than 90 effects are already live,
  so a big fight does not pay for it. `tools/screenshot.sh march 75 march`
  captures a column on the move.

Status at 10:15 UTC: M15 is complete and pushed; `tools/check.sh` passes.

**10:20 UTC — the owner asked for a better-looking UI and main menu (M16),
then for more work on the map (M17).**

- **Finding: a theme set on the root window does not reach controls under a
  `CanvasLayer` or a plain `Node`.** The HUD lives under one, so it kept the
  engine's default buttons. `UiTheme.theme()` is set on the root window *and*
  on each top-level control (`Hud`, `MatchMenus`, `TutorialPanel`,
  `SettingsPanel`, `MainMenu`).
- **Decision: no font files.** Headings use the engine's built-in font,
  emboldened and letter-spaced through `FontVariation`. A system font would
  look different on every machine and could not be checked here.
- **Decision: the bottom bar has a fixed height.** The selection text sits
  in a clipped holder, so a long description can no longer stretch the bar
  over the Directive bar (it did, once the themed buttons got taller).
- The HUD's public methods and node names are unchanged; the smoke drivers
  did not need touching. Icons are drawn (`HudIcon`), not images.
- **Decision (M17): the map pass is cosmetic only.** "Improve the map" could
  also mean new layouts or a richer generator. That was left alone on
  purpose: match length and faction balance were tuned on the current
  generator this morning, and two other session branches are still changing
  `sim/sim_map_gen.gd`. If the owner wants different battlefields rather
  than better-looking ones, that is a separate piece of work.
- The tracks are not hand-placed: `TerrainView` asks the map for the path a
  vehicle would take (`SimMap.find_path`, read-only) from each base to the
  middle and from each uplink site to its nearest base, and paints those
  into a texture the ground shader reads. Grass and flowers keep off them.
- The border is 16 cells of the edge terrain carried outwards, sinking and
  darkening. It samples the fog-of-war texture at the nearest map edge, so
  it is never brighter than unexplored ground beside it. Nothing can enter
  it: the simulation does not know it exists.
- `tools/screenshot.sh scenery_edge 40 scenery_edge` looks at a map corner;
  `layout_twin_fords`, `layout_crater_ring` and `layout_crossroads` show a
  hand-made map whole with fog off. All three were looked at: the tracks
  cross Twin Fords at a ford and enter Crater Ring through its gaps.

**10:55 UTC — the owner asked for the generator itself to be improved
(M18), which overrides the decision above to leave it alone.**

- The new generator keeps the share of open ground where it was, so that
  the pacing work is not thrown away: 16 seeds at 176 x 176 give 85.8% open
  ground, 8.1% forest, 3.9% rock, 2.2% water (before: 83.8 / 9.8 / 4.3 /
  2.2), and the route between the bases is no longer than before.
- **Match length, old generator against new**, `tools/pace_batch.gd`, seeds
  1-6, three pairings, 18 matches each: median about 15.6 minutes before
  and 16.3 after, one stalemate in 18 either way.
- **Finding: one ford per arm was not enough.** With a single ford on each
  arm of the river, seed 1 gave a 37-minute match and a stalemate. With two
  fords per arm the same seed plays in 15-19 minutes on all three pairings.
  The river can also be crossed in the middle of the map and round both
  ends. A test dams the middle ford and checks the bases still connect.
- River valleys are two-player only: a river cannot be laid symmetrically
  between four starts. The compact map gets the same kinds as the standard.
- The fields and uplink sites are placed exactly as before; only the
  terrain around them changed.
- **Decision: woods only grow on open ground.** They used to be painted
  last and could overwrite a pond or an outcrop, which on the new maps would
  have bridged rivers with forest.
- `tools/screenshot.sh seed_4 30 seed_4` shows the map for a seed whole.
  `tools/check.sh` plays its five matches on the new maps; all end with a
  winner (the three-way one in 22 minutes, it used to take 55).

**11:10 UTC — the owner asked for a further design pass on units and
buildings. It was tried and withdrawn.**

- What was tried, all in one go: three-tone camouflage on vehicles and
  troops and rain streaks on buildings (in the model shader), a rim of sky
  light, a paved yard with kerbs and corner lamps round every building, and
  extra kit on vehicles (fenders, grilles, cupolas, bedrolls).
- **The owner saw it and did not like it, so none of it was committed.**
  Units and buildings look as they did at `46dcdf2`. Only the flowers were
  kept toned down (they read as confetti in a fight).
- For whoever tries again: change one thing at a time and show it before
  building on it. Which of the four parts was disliked is not known.

**11:25 UTC — the owner asked for one more faction (M20): the Vesper
Array.**

- **Design.** An automated legion of drone frames: cheap, quick, many and
  fragile. Its two rules are that Linked frames move 15% faster
  (`linked_speed_bonus`, the one new rule in the simulation) and that Dark
  frames keep 92% of their rate of fire (`dark_rof_mult`, which already
  existed). It has no aircraft, no heavy tank, no stealth and nothing like
  the Crawler or the Beacon Rig: it plays like a faster, thinner Aegis that
  can afford to raid outside its own network. Its relay, the Spire, costs
  130 against 150 and reaches 16 against 18.
- **Everything else is data**: nine units, seven buildings, eight weapons
  and the AI's role table, in the same files as the other factions. The AI
  plays it without any change to `SimAI`.
- All names are new: Mote, Shard, Weaver, Porter, Glint, Lash, Halberd,
  Aureole, Prism; Nexus, Spire, Cistern, Cradle, Assembler, Ward Node, Oracle.
- **Balance, AI against AI, `tools/pace_batch.gd`.** First numbers: the
  Array won 12 of 18 (seeds 1-6, against each other faction). After making
  the Mote, Lash and Halberd dearer and weaker it won 10 of 24 (seeds 1-8).
  The shipped numbers sit between the two and have **not** been measured:
  Mote 50 salvage / 70 hp, Lash 205 / 330, Halberd 350 / 590. That is the
  open box in M20. Matches with it last 13-15 minutes, a little under the
  others.
- **The owner said the first models looked bad** (stark white boxes). They
  were redone straight away: lavender-grey shells, a two-step hull with an
  engine block and lift pods, six-sided turrets, chunkier frames with
  shoulder pods, violet rims and lit posts on every base.
- `tools/check.sh` gained `ai_match_vesper` (Array against Aegis, seed 4).
  `tools/screenshot.sh vesper 60 vesper` shows an Array base.

Status at 10:50 UTC: M15, M16 and M17 are complete and pushed;
`tools/check.sh` passes on the last commit. Nothing is half-finished. Open
for whoever is next: the real-GPU frame rate, and the two session branches
that do not merge (see above).
Nothing is half-finished. What nobody has seen yet is all of this on a real
GPU — the captures here are software-rendered.

### 2026-11-16 — session 3 (branch `claude/relay-session-1116-0550`)

Status: **finished** at about 09:30 UTC. Started 05:50 UTC from `f728680`
(session 2's last commit was 43 minutes old with no later push, so session 2
was taken as cut off).

Godot verification: **available**, including software-GL screenshots.

For whoever reads this first:
- Every roadmap box is ticked except "Confirm 60 fps with 300 units on real
  hardware", which needs a GPU. No session here can do it.
- `tools/check.sh` passes on the last pushed commit (122 tests, five AI
  matches, export flow) and now takes about nine minutes.
- PR #3 (this branch into `main`) carries sessions 1-3; it supersedes #1.
- Most useful next, if a session has no GPU either: a human play-through is
  still the biggest unknown. Without one, candidates are a Nomad tier-3
  answer to Aegis artillery and aircraft (the 5% cost cut is a stopgap), and
  starved-endgame stalemates (about 4% of AI-vs-AI games, see below).

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

- M13 match length (ticked): AI-vs-AI 1v1 on the default map now averages
  17.1 minutes, median 16.6, range 11-31, no stalemates; 59% of games fall
  inside 15-25 (seeds 1-3, all nine faction pairings, 27 games; it was
  average 10.0, median 9.4). Win rates in that sample: Aegis 50%, Foundry
  58%, Nomad 41% (noise is about +/-15 points at this size).

Match-length decisions:
- The default generated two-player map is 88 cells (176 x 176 world units),
  up from 64. The old size stays as "Generated, compact (shorter match)" in
  the skirmish map list; the hand-made layouts are unchanged (128 x 128) and
  so play shorter. Tests that picked spots on the old terrain pin
  `map_cells` to the compact size.
- Harvesting a load takes 6 s (was 4); generated fields hold 50% more
  (7,500 near, 13,500 mid) so the map does not run dry before the end.
- Every unit and building takes 30% longer to build (rounded to 0.5 s).
- Headquarters have double health (Aegis 6,000, Foundry Core 7,200, Caravan
  Hub and Caravan 5,200); every other building has 25% more, mines excepted.
  Turret damage is unchanged: buffing it caused stalemates.
- AI wave gaps are 50% longer (Easy 110 s, Normal 60 s, Hard 38 s).
- Save files keep the map size they were made with, so older saves still
  load on the old map size.

Working on (after the tick): held-out seeds 4-6 gave median 16.0 but 3 of
27 games hit the 45-minute cap. Causes found and fixed so far:
- The AI ignored salvage more than 90 units from a depot, a limit written for
  the 128-unit map; on the larger map both sides sat broke beside 14,000
  untouched salvage. The limit is now 0.7 x the map width (unchanged on the
  compact map).
- After 22 minutes AI waves head for the enemy HQ instead of outlying relays
  (they were grinding through Pylons for twenty minutes).
- Uplink sites now count as expansion goals alongside salvage fields
  (nearest first); before, they were only considered once every field was
  covered, which on the larger map never happened.
What remains is a starved endgame: both sides out of salvage, one with only
infantry against a Bastion and a double-health HQ that is repaired for free.
A human on either side can still finish it; left as is.
With these fixes, seeds 1-6 across all nine pairings (54 games): average
17.8, median 16.6, range 11-45, 2 draws (4%), 53% inside 15-25. Win rates:
Aegis 54%, Foundry 54%, Nomad 33% (24 non-mirror games each, about +/-10
points of noise), so the Nomads are now clearly behind.
- Nomad rebalance for the longer matches: they were even with Foundry but
  lost to Aegis 2-9, whose tier 3 (artillery, aircraft) now comes online in
  most games. The Nomad army units cost 5% less: Drifter 55 -> 52, Dart
  90 -> 86, Sidewinder 190 -> 181, Prowler 280 -> 266. Nomad then won 12 of
  24 on seeds 1-6 (7-5 against Aegis, 5-7 against Foundry). A 10% cut, or
  15% faster Nomad production, each swung the Aegis matchup to 8-4.
- Three-way free-for-alls (Foundry, Nomad, Aegis) now take 17-55 game
  minutes (seeds 1-5). `check.sh`'s three-way step plays seed 5, the slowest
  at 55:25, against a 60-minute cap, which is too thin a margin: the cap for
  that step is now 90 game minutes. It still has to end with a winner and
  takes about four minutes of wall time.
- Difficulty still ranks correctly with the new pacing (`balance_batch.gd
  --levels`, seeds 1-3): Hard beat Easy 9-0, Normal beat Easy 9-0, Hard beat
  Normal 7-2. A test now pins the generated map sizes (standard 88 cells,
  compact 64) and checks haulers find fields on the larger map.
- `tools/pace_batch.gd --scale=id.field:mult` scales one field of any unit,
  building or weapon for an experiment.
- Frame cost on the larger default map with 300 units (CPU only): average
  7.5-8 ms as before; the worst frame was 30-33 ms (was 24-25 on the old
  map). Switching the minimap, fog or signal view off does not change it,
  and the simulation benchmark's worst tick (18 ms) is inside session 1's
  17-31 ms range, so it is not treated as a regression.

How it was found (27 games each): build and harvest times x1.5 -> median 11.1; unit build x2 ->
12.2; HQ health x2.5 with tougher buildings and turrets -> 10.4. Traces show
matches are decided by minute 3-6 when one army is wiped out; the rest is
mopping up. Slower macro plus tougher defences together -> average 13.9; a
larger generated map (88 cells instead of 64) alone -> 13.6, median 12.0.
The full mix on an 88-cell map overshot: median 16 but six 60-minute
stalemates in 27 games. Traces: the map's salvage (about 46,000) is gone by
minute 24, after which both sides live on trickles and armies of basic
infantry cannot crack buffed turrets and a double-health HQ that is repaired
for free. Without the turret and building buffs, with fields x1.5, harvest
6 s, build times x1.3, HQ x1.5 and AI wave gaps x1.5 on an 88-cell map:
average 16.2, median 15.2, no stalemates (candidate "X1"). Variation "X3"
(the same but HQ health x2 and other buildings x1.25) was better still:
median 16.1, 66% of games inside 15-25, no stalemates, so it was baked in.
Tried and dropped: waves that retreat when cut below 40% made matches
shorter (8.4), because the survivors die running and the enemy follows.

### 2026-11-16 — session 2 (branch `claude/relay-session-1116-0451`)

Status: **cut off** after one HUD commit (`f728680`, 05:07 UTC); nothing
else was pushed. Started 04:51 UTC from `3a43a9e` (session 1's last
commit; `tools/check.sh` passes on it here, Godot and software GL available).

Working on, in order:
1. Looking at screenshots of every screen for layout and visibility faults.
2. The open M13 item: 1v1 match length (defender-side levers, as session 1's
   notes suggest).

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
