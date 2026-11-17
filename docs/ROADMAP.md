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

## M21 — Regions (owner request, 16 November)

- [x] Four regions: Greenwood, Dustlands, Frostline, Cinder Wastes. Each
      has its own ground, rock, water (or lava), plants and light
- [x] The seed picks the region; the skirmish setup can override it; the
      hand-made layouts have a home region each
- [x] A region changes the look only: tests check that terrain, heights,
      fields and uplinks are identical in all four
- [x] Minimap colours follow the region

## M22 — Verdigris Order, and regions that generate differently (owner request)

- [x] Fifth faction: nine units, eight buildings, `linked_damage_resist`
- [x] Four kinds of country per region (sixteen in all), each region with
      its own mix of rock, water and woods
- [x] Cinder Wastes reworked after the owner disliked it: lava is a rare
      large feature, drawn as dark crust with glowing cracks

## M23 — Playing it (owner request)

- [x] Game speed (+ / -), Ctrl+A or F2 for the whole army, Space to the
      latest warning, Shift to queue five
- [x] Order lines and rally lines for the selection; weapon range rings
- [x] Income readout in the top bar
- [x] **Watch**: the AI plays every side, no fog of war, no orders
- [x] **Save and Quit to Menu**; "Continue Saved Game" on the main menu

## M24 — AI design (owner request)

- [x] Doctrines from the seed: balanced, aggressor, fortifier, raider
- [x] A fighting retreat, at most a few times a match
- [x] A touring scout

## M25 — Three more factions (owner request)

- [x] Zephyr Accord: aircraft; `linked_sight_bonus`
- [x] Crimson Tally: bounties; `kill_bounty`
- [x] Umbral Veil: hidden while still inside its coverage; `linked_cloak`
- [x] Models, tests and an AI match in `tools/check.sh` for each

## M26 — Balance across eight factions (owner request)

- [x] `tools/balance_league.py`: every pairing, both seats, in parallel
- [ ] Every faction within about ten points of even over a league of at
      least 48 games a faction
- [x] Match length still 15-25 minutes for most pairings (17 November,
      720 games over sixteen seeds: the average is between 15 and 25
      minutes in 44 of the 45 pairings; the median game is 16.2 minutes)

## M27 — Bug hunt (owner request)

- [x] `tools/invariant_check.gd`: plays AI matches and, once a second,
      checks the world for states that should be impossible (units outside
      the map or inside rock, health and cargo out of range, bandwidth
      that does not add up, footprints and occupied cells that disagree,
      dead players with a headquarters, not-a-number positions)
- [x] Tests that every model builds and fits its unit, that no command
      card repeats a key, and that every faction can reach all it owns
- [x] Save and reload mid-match for every faction, in both modes
- [x] Whole matches of the new factions through the real battle scene
- [x] Fixed what these found (three bugs, listed in the session log)

## M28 — An interface of its own for each faction (owner request)

- [x] Each faction's HUD has its own accent colours, panel and button
      shapes, lettering and emblem
- [x] The skirmish setup previews the chosen faction's style

## M29 — Teams, and a new match setup (owner request)

- [x] Players belong to teams; allies do not shoot each other, share what
      they see, and win or lose together
- [x] The AI can be on the player's team and fights alongside
- [x] A match setup screen with one row per seat: who plays it (you, an AI,
      nobody), its faction, its team, its difficulty
- [x] Saved games, the Watch option and the result screen know about teams

## M30 — Two more factions (owner request)

- [x] Ninth faction: design, data, one rule of its own, models, tests
      (the Brackenfold)
- [x] Tenth faction: the same (the Lodestone Circle)
- [x] Both in `tools/check.sh` and in the balance league

## M31 — A better AI, round two (owner request)

- [x] Attacks from more than one direction when the map allows it (every
      other big wave comes round the side; a wave is never split, see log)
- [x] Guards its haulers and its relay chain, and rebuilds what it loses
- [x] Works with an allied player or AI (M29): defends an ally's base,
      joins an ally's attack
- [x] Uses each faction's own trick on purpose (cloaked ambushes for the
      Veil, air strikes on relays for the Accord, raids that pay for the
      Tally, early retreats for the Brackenfold)
- [x] Matches end: a beaten AI concedes, and a headquarters cannot be
      out-repaired while it is under fire (found while testing the above)

## M32 — Stronger faction design (owner request)

- [x] Every faction has at least one unit or building no other has in any
      form (see the log for the list). "Plays visibly differently in the
      first five minutes" is only partly true: five of the six new units
      come from the vehicle works, which is up at about four minutes
- [x] The three plainest rosters (Vesper, Tally, Veil share one template
      with Aegis) get units that break the template (and so do the
      Brackenfold, the Lodestone Circle and the Verdigris Order)
- [x] Faction descriptions, the How to Play screen and the tutorials say
      what is special about each

## M33 — Maps and map generation, round three (owner request)

- [x] More shapes within each region, and features that matter in play:
      chokepoints and islands of salvage worth fighting for (a fifth kind
      of country in every region: a prize behind a wall or a moat)
- [x] High ground that matters in play: hills on every generated map;
      ground units and buildings on one shoot 15% further and see 25%
      further (aircraft do not), and buildings need level ground
- [x] Three more hand-made layouts, one for each new region
- [x] A preview of the map in the match setup

## M34 — Look, round two (owner request)

- [x] Units and buildings: a better look for every faction's models. The
      Brackenfold was redrawn (the owner called it the worst looking), the
      Wardrum became the Paymaster, vehicles lie along the slope under
      them and walking machines and beasts step. The other eight factions
      were looked at whole, side by side, and kept as they are; the owner
      has the sheet and can name any to redo. (The first attempt, a
      camouflage and weathering shader with extra kit on every model, was
      withdrawn because the owner disliked it: do not bring that back.)
- [x] Combat: bigger and more varied explosions, smoke that lingers,
      wrecks that burn, weapon effects per faction
- [x] Lighting by hour, as an option only: the skirmish setup has a Light
      setting (Midday, Morning, Evening, Overcast). The owner first said
      "I don't want that", then that it need not be removed if it was
      already built, which it was. So it is kept, but a match is lit for
      midday, as before, unless another hour is picked
- [x] The game as a whole: water and sky. Water has a soft, wandering
      shore, clear shallows, ripples and the sky's colour in its deeps;
      Frostline water is frozen over. The sky itself is never on screen
      (the camera looks down), so its part is what it does to the water and
      the cloud shadows that cross land and water alike

## M35 — The owner's picks from the ideas list (owner request, 17 Nov)

- [x] Autosave every few minutes, and more than one save slot (three
      slots and an autosave; "Load Game" on the main menu lists them)
- [x] Unit stances: aggressive, hold fire, return fire (Z, or the stance
      button on the command card)

## Ideas not taken up

Session 1 proposed a list of further ideas. The owner picked the two in M35
and said of the rest "I don't care". They are not to be built unless the
owner asks: an active ability per signature unit; a patrol order and
formations with tanks in front; garrisons; neutral structures besides
uplinks; destructible bridges and flooding fords; weather that touches the
Signal Grid; rebindable keys and a colour-blind palette; an in-game
encyclopedia. Earlier the owner also struck a campaign, play against other
people and a map editor.

## Session log

Newest first. One entry per session: date, what was finished, decisions made,
anything left half-done, whether Godot verification was available.

### 2026-11-16 — session 5, 14:50-15:55 UTC (branch `claude/relay-session-1116-1450`)

Status: **stopped early, on purpose.** Session 1 turned out to be alive and
working on the same item (M26), so this session stood down after bringing
its own two pieces of work to a state that can be picked up. Nothing is
half-done. No roadmap box was ticked.

- **What happened.** At 14:50 the newest remote commit was 73 minutes old,
  so the liveness rule in `CLAUDE.md` said nobody was running, and this
  session started on M26. Session 1 then pushed at 14:53, 15:08 and 15:09
  (its worker had been restarted; see its entry). That was noticed at
  15:20, when listing pull requests showed #1 had moved. From then on this
  session only finished and measured what it already had in hand.
  **For the rule:** 25 minutes is too short a quiet spell to mean "dead" —
  session 1 was silent for 76 minutes and came back.
- This branch is session 1's branch at `a7369d8` (merged cleanly at 15:20)
  plus two things, each in its own commit. `tools/check.sh` passes on the
  tip (it failed once on the way; see point 2). Godot verification: available.

**1. `tools/check.sh` plays every faction through the real interface with
random input** (`view/monkey_driver.gd`, from session 2's commit `577198b`,
brought up to date; session 1's M27 entry listed this as not covered).

- About 5,800 clicks, drags, wheel turns and key presses a faction, plus a
  deliberate sequence every 90 frames: select a builder, press a command
  card button, look at the headquarters, point beside it, click. All eight
  factions run with no script errors, before and after the M28 interface,
  and each places 20-40 construction sites. It adds about 90 seconds to the
  check.
- What had to change for it to work on today's interface:
  - The pause-menu button has a node name (`MenuButton`); the test finds it
    by that, not by its text or a fixed corner of the screen.
  - **The building ghost follows the last mouse event**
    (`BattleScene.pointer()`), not `Viewport.get_mouse_position()`. On a
    real machine the two are the same. Headless, the window has no pointer,
    so pushed-in clicks always tried to build at one fixed spot and failed.
  - The test points first and clicks a frame later, as a hand does.
- It found no bugs in the game. Buildings are placed but rarely finished,
  because the random orders keep calling the builders away.

**2. A rule that keeps an AI attack wave together — written, tested,
measured, and left switched off** (`SimAI.keeps_together`, false by
default; `test_a_wave_keeps_together_on_the_way_in` runs it both ways).

- **Why it is off: with it on, `tools/check.sh` failed.** The Array against
  Aegis on seed 4 ends in 15:31 without the rule and was still undecided at
  45:00 with it: the Array got far ahead (50 units to 13 at minute 17) and
  then spent wave after wave against the Aegis headquarters without
  finishing it, until the map ran dry. One match does not show the rule
  causes that, but a check may not be weakened to let it through, and this
  session is not the one to tune it. With the flag off the AI plays exactly
  as on session 1's branch.
- Likely flaw, for whoever takes it up: a unit told to wait can be standing
  inside the range of a headquarters gun or turret it cannot answer (it
  waits unless it has a target of its own). Letting a unit that was hit in
  the last few seconds carry on, and not waiting within about 20 of the
  target rather than 14, would be the first things to try.
  `tools/pace_batch.gd --ai.keeps_together=1` turns the rule on for a batch
  without editing anything.
- **Finding: nothing in the game matches a group's speed, and the AI sent
  each wave with one attack-move.** Aircraft (speed 6.6-7.0) and scout cars
  reached the enemy alone, two to three times sooner than the infantry
  (2.7), and died there. In one Accord match against the Pact the Accord
  built 14 aircraft and lost all 14, and destroyed 4,500 salvage worth
  while losing about 15,000.
- The rule: for the first two minutes of an assault, a wave unit that is
  more than 9 ahead of the main body (the two-thirds point of the wave by
  distance to the target), is not yet within 14 of the target and has
  nothing to shoot at, stops and waits. In the test two gunships get more
  than 25 ahead of six troopers in ten seconds without it and stay within
  18 with it.
- **Measured for the Accord only**, AI against AI, seeds 1-6, all seven
  opponents, 42 games each, on session 1's numbers as of `a7369d8`:
  **without the rule 9 of 42 (21%), with it 13 of 42 (31%)**; 95% of the
  matches with it lasted 12-25 minutes, none undecided. Ten points is
  about one standard error of the difference, so this is a lean, not
  proof.
- **What the rule does to the other 21 pairings** is being measured as
  this is written: a full league (seeds 1-6, 168 games) with the rule on
  and another with it off, from scratch copies of the tree. The result will
  be added here.
- **A second finding, not applied** (the data files are session 1's at the
  moment): the Accord has one Flight Deck and by minute four it has 1,200
  to 2,000 salvage it cannot spend, so its aircraft are limited by build
  time, not price. With the rule above, plus build times of 12 / 16 / 21
  seconds for the Swift / Lanner / Condor instead of 18 / 25 / 30 (and
  aircraft about as strong as session 1's), the Accord won **18 of 42
  (43%)** over the same seeds and opponents. Cheaper and tougher aircraft
  alone gave 8 of 42 here and 19% in session 1's own league.
- Every AI banks salvage the same way (the Pact had 7,000 unspent at minute
  six of that match). A second production building once the bank passes a
  threshold belongs under M31; it will move match length, so it was not
  tried here.

- **A mistake to avoid:** do not edit scripts in the working tree while
  `tools/check.sh` or a league is running there. Every step starts a fresh
  Godot that reads whatever is on disk at that moment, so a half-made edit
  fails the run (it did, once). The leagues above were played from copies
  of the tree in a scratch folder.
- `claude/relay-session-1116-0451` (session 2) and
  `claude/relay-session-1116-0654` (session 4) are still not merged, apart
  from the random-input test.

### 2026-11-16 — session 7, 19:50 UTC (branch `claude/relay-session-1116-1950`)

**Working now (20:30 UTC):** M31 is written with eleven unit tests on a
side branch (not pushed yet; it goes up when `tools/check.sh` passes on
it). Batches of twenty AI matches are being played to see what each new
behaviour does to match length before it is switched on for good.

- **M30 ticked.** Session 1 had pushed both factions complete (design
  paragraph, data, rule, models, skin, tests, a match each in the check)
  and left the boxes open. The league tool reads the faction list from
  `data/factions.json`, so both are in it; the monkey test now plays them
  too. What is still owed is a league *run* over all ten: that is M26's
  open box, not M30's.

- Started from `claude/gracious-lovelace-fxl9n2` (`aa02b86`, the newest
  remote commit, 16:36 UTC; nothing newer anywhere, so no session was
  running).
- **Session 1's M31 never arrived.** Its last note says M31 was committed
  locally and waiting on the check. No such commit is on any remote branch,
  so that work is lost and M31 starts from the pushed code.
- Merged `claude/relay-session-1116-1450` (session 5): the random-input
  monkey test in `tools/check.sh` and the keep-the-wave-together AI rule
  (off by default). One conflict, two blocks of constants in
  `sim/sim_ai.gd`, both kept. The monkey test now also runs as the
  Brackenfold and the Lodestone Circle.
- **Decision: `claude/relay-session-1116-1550` (session 6) is not merged.**
  It holds a second, independent M29 (teams, match setup) and a faction
  called the Ember Rite. Session 1's M29 is already here and the two touch
  the same forty files; merging would mean choosing between two team
  systems line by line with no gain. The Ember Rite (weapons that set
  targets alight) is a candidate to port by hand later; the branch is left
  as it is for the owner.
- `claude/relay-session-1116-0451` and `-0654` remain unmerged, as session 1
  left them.

### 2026-11-16 — session 1, resumed 09:05 UTC (branch `claude/gracious-lovelace-fxl9n2`)

**Working now (07:53 UTC, 17 Nov) — session 1 is alive, for sessions 5, 6
and 7 to read.** Everything written is pushed, with `tools/check.sh`
passing (32 steps): M28 to M35 complete, three AI fixes that came out of
the balance leagues (factories before relays when rich, relays kept at
home under fire, at most three hijackers), and the unit prices the
leagues arrived at. M26's second box (match length) is ticked. Its first
is open: before the third AI fix, 720 games over sixteen seeds put nine
factions within 7.6 points of even and the Veil 11.8 below (see "Balance
(M26)" in the log below); that fix makes the Nomad AI stronger, so the
same league is being played again with it and one more price step.
At 07:53 it had played 10 of its 90 jobs; it resumes if it is cut off.

- **Session 7** (`claude/relay-session-1116-1950`): M31 is here and pushed;
  if yours has behaviour this one lacks, leave it on your branch and say
  which in your log, and it can be ported. Please do not push a second M31
  or M32 over these.
- Session 6's branch (`-1550`, a second M29 and the Ember Rite) stays
  unmerged, as session 7 decided.
- This session's worker was down from about 16:45 to 20:54 UTC and again
  from 21:10 to 22:00. Each restart kills a running check; it is now
  started in its own process session (`setsid`), which survived.

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

**11:55 UTC — the owner asked for more regions (M21).**

- **Decision: a region is a label in the simulation and a palette in the
  view.** `SimMap.region` is a string the generator sets from the seed (on
  its own random stream, so adding regions did not change any map).
  `RegionLook` turns it into colours, plant shapes and light. Nothing in the
  rules reads it; a test generates one seed in all four regions and compares
  terrain, heights, fields and uplinks.
- Lava in the Cinder Wastes is the same impassable "water" terrain, drawn
  glowing. Ice in the Frostline is still water too: it cannot be crossed.
- Crater Ring now lies in the Cinder Wastes and Crossroads on the Frostline.
  The region dropdown in the skirmish setup overrides either.
- `tools/screenshot.sh region_tundra 30 region_tundra` (or `region_desert`,
  `region_ashland`) shows seed 4 in that region.

**12:10-12:45 UTC — a run of owner requests; work in progress, not all
pushed yet.** In hand, committed locally and being checked:

- A fifth faction, the Verdigris Order (armored knights and walkers; Linked
  units take 15% less damage).
- Every region generates its own kinds of country (mesas and oases, ice
  rivers and pinewood, fissures and calderas). The owner did not like the
  first Cinder Wastes (too many lava pools): lava is now a rare large
  feature drawn as a dark crust with glowing cracks.
- Playing: game speed keys, Ctrl+A, Space to the latest warning, Shift to
  queue five, order lines, weapon range rings, an income readout.
- AI: doctrines from the seed, a fighting retreat, a touring scout.
- `tools/balance_league.py`: every faction against every other, in parallel.

**`tools/check.sh` failed on that commit, so it has not been pushed:** the
three-way AI match did not end in 90 minutes. The new retreat rule is too
eager (one AI called back six of its first eight waves), both sides ran out
of salvage and nobody could finish. Being fixed before anything goes up.

Also asked for and being worked on: three more factions (Zephyr Accord,
Crimson Tally, Umbral Veil), a Watch option (the AI plays every side),
"Save and Quit", a balance pass over all factions, and a bug hunt.

**13:10 UTC — the retreat rule is fixed and the rest is in.**

- **Decision: an AI may retreat only a few times a match** (twice; once for
  an aggressor, three times for a fortifier), only when the wave is down to
  two fifths of its strength against something 1.6 times stronger, and
  never after minute 22. The same three-way match that ran out the clock
  now ends in 39 minutes.
- **Finding: the AI already knew where the enemy HQ was within three
  seconds**, because it unlocks Recon Sweep with its first Command Point
  and uses it on the enemy start. The scout therefore matters for relays
  and depots, not for the HQ; a soldier is only pressed into scouting when
  nothing at all is known.
- **Three more factions.** Each plugs into the same role table the AI
  already uses and adds one rule in the simulation:
  `linked_sight_bonus` (Zephyr Accord), `kill_bounty` (Crimson Tally),
  `linked_cloak` (Umbral Veil). The Veil's Sentinel turret uses the stealth
  flag that mines already had. All names are new.
- The Accord's aircraft use the roles `anti_infantry`, `anti_armor` and
  `artillery` rather than `air`, so the AI picks them by what the enemy
  fields, and its works building (the Flight Deck) builds them.
- **Watch** is `MatchConfig.watch`: every seat is an AI, fog is off, and the
  interface refuses every order (selection, camera, speed and the pause
  menu still work). `tools/check.sh`'s spectate step now runs in this mode.
- **Not yet balanced.** Eight factions make 28 pairings. First numbers for
  the newest are in the M26 entry when the league has run.
- `tools/screenshot.sh base_tally 60 base_tally` (any faction id) shows a
  full base with one of every unit; `watch` shows a watched match.
- The commit before this one (`89feaa8`) is in the history with a failing
  check: it was pushed together with the commit that fixes it, after the
  fix had passed. The branch tip has passed `tools/check.sh` at every push.

**13:15 UTC — bug hunt (M27).** What was run, and what it found:

- `tools/invariant_check.gd`, 26 AI matches of 10-22 minutes over every
  faction, two to four players. **Bug 1: a Nomad Skiff carried 112 salvage
  in a bed that holds 80.** The wreck bonus was added after the load had
  been capped. Fixed: a Skiff takes less off the wreck per trip, so the
  wreck lasts longer and still pays half as much again in total; the test
  now also checks the load never exceeds the capacity. Nothing else failed.
- A test that builds every model. **Bug 2: the Accord's arched hangars
  were whole cylinders with their lower half 1.6 units under the ground**,
  which would show on a slope and while the building rises. Fixed with a
  proper half-arch mesh.
- Reading my own new code with the owner's keyboard in mind. **Bug 3: the
  speed keys went by key position**, and on a Nordic keyboard the key
  printed "+" sits where a US keyboard has "-", so "+" would have slowed
  the game down. They now go by the character on the key.
- Save and reload in the middle of a match for all eight factions, with
  and without Watch and a chosen region: 16 round trips, each identical to
  the original two and a half minutes later.
- Three whole matches of the new factions through the real battle scene
  and HUD with no script errors.
- Also fixed in passing: the minimap kept its fog of war in Watch mode.
- **Not covered:** anything that needs eyes or hands on a real machine
  (sound, feel, the frame rate, how the interface behaves at other window
  sizes), and the interface under random input. Session 2's branch has a
  random-input "monkey" driver for the HUD that is not merged here.

**13:45 UTC — balance pass (M26), in progress.**

- First eight-faction league, 168 AI-vs-AI games (seeds 1-6, every pairing,
  both seats): Nomad 76%, Foundry 71%, Verdigris 57%, Vesper 55%, Tally
  48%, Veil 48%, Aegis 29%, Zephyr 12%. One standard error at 42 games a
  faction is about 8 points, so the middle four are even and the ends are
  not. Median match 15.0 minutes, 84% between 12 and 25, 2 of 168 undecided
  after an hour.
- The Nomad figure was measured with the overfilled-Skiff bug still in.
- **Decision: fix the Accord by design first, then tune prices.** A faction
  at 12% is not a pricing problem. Its aircraft are cheaper and tougher and
  the Lanner hits harder (committed locally, being measured). Aegis's Dark
  penalty goes from 60% to 65%.
- `tools/balance_tune.py` is running two more league rounds on that, seeded
  with the first league's result. Each round is about half an hour here.
  Prices will be written into `data/units.json` when it settles.

**14:55 UTC — after a break of about an hour (the session's worker was
restarted three times; the background tuner died with it).**

- Tuner round 1, 168 games, with prices seeded from the first league (Aegis
  x0.925, Foundry x1.075, Nomad x1.07, Zephyr x0.92) and the Accord's
  aircraft strengthened: Nomad 71%, Foundry 57%, Aegis 55%, Vesper 52%,
  Tally 52%, Verdigris 48%, Veil 40%, Zephyr 19%. Aegis is back in the
  pack; Nomad and Zephyr are still far out. The multipliers after that
  round are kept in `.godot-bin/balance_state.json`.
- The owner struck two proposed milestones (a campaign; play against other
  people) and the map editor from the ideas list, and asked for a different
  interface design for each faction (M28 now).
- **15:00 UTC — the owner added seven things to the roadmap** (M28-M34):
  an interface per faction, teams with AI allies and a new match setup,
  two more factions, a better AI, stronger faction design, more work on
  maps, and another pass on the look of units, buildings and combat. The
  order above is the order they will be worked in, after the balance pass
  that is already running. The three ideas of mine that were not struck are
  kept below them without numbers.

- **15:25 UTC — M28 done: an interface for each faction.** `ui/ui_skin.gd`
  holds one skin per faction (colours, corner and border shapes, slant,
  lettering, emblem) and builds a whole theme from it; the HUD, pause menu,
  result screen, settings and tutorial panel take the local player's skin,
  and the skirmish setup panel puts on the skin of the faction picked.
  Aegis: cool glass, thin lines. Foundry: square iron plates, heavy lower
  edge, furnace orange. Nomad: canvas brown and teal, opposite corners
  folded. Vesper: violet pills, wide lettering. Verdigris: eight-sided
  plates with a bronze edge. Zephyr: pale slate, slanted flight strips,
  orange. Tally: black ledger ruled in gold above and below, oxblood when
  pressed. Veil: dusk with ghost-green hairlines and two cut corners.
  Watch mode uses a neutral skin. Checked by screenshot for all eight
  (`tools/screenshot.sh hud_x 40 base_<faction>`, and `setup_<faction>`
  with the menu scene); tests check that every faction's skin is its own
  and that text stays readable on it.
- **The owner said the "CP" box takes up a lot of the screen.** It did: the
  Directive bar floated over the battlefield, 1040 x 70. Decision: the
  Directives now sit inside the bottom bar, between the selection panel and
  the command card (a 2 x 3 grid of short chips: name, and "Unlock 3 CP" /
  seconds left / "Ready Alt+3"). Nothing covers the playfield any more and
  the bar is no taller than before. While there: the selection panel has a
  health bar (green, amber, red; for a group, the whole group's health)
  and a line of facts (armour class, speed, sight).

- **15:40 UTC — the owner on M34:** "you don't have to show me that. Do it
  without showing me one change at a time." The roadmap item is reworded:
  the look pass on units and buildings goes ahead in one go, with pictures
  sent at the end. What was withdrawn before (camouflage and weathering
  shader, yards, extra kit) stays withdrawn.
- **M29 in progress (teams).** The sim already had a team number per
  player and used it for targeting and victory; added: teams in
  `MatchConfig` (and in saves), shared vision between allies (and allied
  detectors reveal cloaked units for the whole team), allied starts side
  by side on four-start maps, no attack orders on allies, no capturing an
  ally's uplink. The skirmish setup is now one row per seat (played by,
  faction, team, AI skill); seat one given to the AI is the old Watch
  option. AIs are named after their faction. Decision: allies do not share
  signal coverage; each army runs on its own grid.
- **An AI stall found by the first two-against-two match**, and it is not
  special to teams: a wave stays "out" until its last unit dies, and the
  army gathering at home waits for it. One survivor that could not hurt
  its target kept an AI with 125 units at home for ten minutes (the match
  never ended). Fix: a wave worn down to a third of what set out, or out
  for four minutes, is joined by whatever has gathered at home
  (`_wave_spent`, `_reinforce`). The same match now ends at 17:34; three
  other two-against-two matches end at 14, 19 and 27 minutes. This changes
  every AI match, so the balance tables above are out of date and the
  league has to be run again.
- **That fix failed `tools/check.sh`** (the commit was not pushed): sending
  home units after the wave in batches of half a wave made attacks trickle
  in, and the three-way free-for-all of the check, which used to end at 19
  minutes, was still going at 90. Second version: a spent wave no longer
  holds back the next one, but the next one still has to be a full wave
  (or, after a long wait, whatever a starved economy has), and it stages
  before it attacks with the survivors of the old wave folded in
  (`_next_wave_ready`). The three-way match ends at 17:25, the
  two-against-two at 15:05.
- **M30, first half: two more factions, ten in all.** The Brackenfold
  (`bracken`): grown war beasts; everything it owns mends 1.2% of its
  health a second once it has not been hit for six seconds (`regrowth`);
  cheap, plentiful, nothing hits hard. The Lodestone Circle (`lodestone`):
  coil guns and magnets; whatever its weapons hit moves 35% slower for
  2.5 s (`hit_slow`); its guns hit a little less hard. Both follow the
  usual roster (builder, hauler, two infantry, scout, gun car, tank,
  anti-air, artillery; seven buildings); M32 is where rosters get units
  that break that template. Each has models, an interface skin and an
  emblem, tests for its rule, and a match in the check.
- **The owner on the Brackenfold: "the worst looking faction right now."**
  The first version was bark-brown and moss-green balls: on grass, next to
  the map's own trees, it looked like scenery, and the beasts were dark
  lumps. Redone with nothing green in it: buildings are flowers (rings of
  autumn-red petals round a sap-bright heart, on decks of dark heartwood
  with bone thorns at the corners), the barracks is a pod under ribs of
  bone, and the beasts are plated in pale horn with dark rims, a crest of
  red fins, horns, bright eyes and jointed legs. Lesson for M34: a faction
  has to contrast with the ground it stands on, and crisp faceted shapes
  read better than balls at this size.

- **M31: the AI, round two.** What went in:
  - *Faction tricks*, read from the faction's data on the AI's first think
    (`_adapt`), Normal and Hard only: `linked_cloak` -> the army waits at
    the forward relay, unseen; `kill_bounty` -> raids; `regrowth` -> pulls
    back at 60% strength instead of 40%, two more times a match; two or
    more kinds of armed aircraft -> between waves, three or more idle
    aircraft go for the relay whose loss cuts off the most, or a depot.
  - *Allies*: an AI sends its home army to an ally's headquarters when
    three or more armed enemies are within 28 of it and its own base is
    quiet; it takes an allied AI's wave target as its own, or the enemy
    building nearest to where an allied person's army is fighting, and
    sets out with half a wave when an ally is already attacking.
  - *Direction*: tried first as a split (the quicker third of a wave
    gathered at a second point 55 degrees round the target). It made three
    of eight test matches stall: an attack split in two breaks on defences
    one would carry, and then nobody can finish. Dropped. Now every other
    wave of ten or more gathers, whole, round one side (alternating sides,
    only when the way round is no more than half again as long), and not
    after 22 minutes, when waves go straight for the headquarters.
  - *Rebuilding and guarding* were already there by design (the build
    order refills what is missing; attacks on haulers and on any building
    call the home army). The test for rebuilding found a bug instead:
    builders told to mend a building that has since gone Dark stood beside
    it for ever (repairs need the grid), which froze an AI's construction
    for three minutes. Such a repair order now ends.
- **Why matches would not end, found while testing M31.** Two causes, both
  older than today: (1) builders mend 4% of a building's health a second
  each (root of two for two builders), so two builders restored a
  6000-point headquarters by about 340 a second *while it was being shot*:
  more than a late-game wave of infantry can deal. Now a building hit in
  the last three seconds is mended at a fifth of that
  (`repair_under_fire_mult` in `data/rules.json`). (2) Once the map's
  salvage is gone both sides field infantry from the emergency trickle,
  and a beaten AI holds its headquarters with a Shell Barrage every 90
  seconds on the wave that gathers in front of it. Decision: an AI that is
  plainly beaten concedes (not before 14 minutes; eight buildings or
  fewer; the strongest enemy side at 2.5 times its side's strength, army
  counted double, for 150 seconds on end; never when a person is on its
  team). This is a rule of the AI, not of the game: a person can still
  fight to the last building. All eight matches I use for testing now end
  between 9 and 21 minutes.

- **M32: what each faction has that no other does.** Before today: Aegis
  (Marksman, Kestrel and Scout Drone, three kinds of turret, the Airpad),
  Foundry (Crawler, mines, Ratchet), Nomad (Caravan, Beacon Rig, Splicer,
  jammer, snare turret), Zephyr (its aircraft). The other six shared one
  roster. Each now has a tenth unit built on two small additions to the
  sim: **auras** (`aura_radius` plus one of `aura_rof`, `aura_cloak`,
  `aura_slow`, `aura_link`, `aura_heal` on a unit; laid every five ticks
  on everything in reach, lapsing twelve ticks after the unit leaves or
  dies) and a **bursting weapon** (`burst`: the unit is its own bomb).
  - Vesper **Tether**: units within 9 count as Linked.
  - Verdigris **Almoner**: infantry within 6 mend 7 points a second.
  - Tally **Paymaster**: guns within 8 fire 20% faster. (First built as a
    "Wardrum", a truck with a great drum; the owner did not like it, so
    the same rule now rides on an armored pay wagon with its strongroom
    door open on the gold: mercenaries shoot faster with the pay in sight.)
  - Veil **Mantle**: ground units within 8 are hidden while still.
  - Brackenfold **Burster**: 120 explosive damage over 2.8, once.
  - Lodestone **Dragline**: enemies within 9 move 40% slower.
  All but the Burster are unarmed "support" units; the AI keeps up to two.
  The selection ring shows an aura's reach. How to Play has a second page,
  The Factions (emblem, name in the faction's colour, what is its alone);
  faction descriptions name the new unit; the Tutorials panel points
  there. Not done: nothing in the first five minutes of a match looks
  different between these six beyond the models and the interface.
  **None of this has been through a league**: the support units are
  priced by eye.

- **M33: maps, round three.**
  - *A picture of the map in the skirmish setup* (`ui/map_preview.gd`):
    terrain in the region's colours, salvage (gold), uplink sites (white)
    and a square in each seat's colour where it starts. It is drawn from
    `SimSetup.map_for(config)`, the call the match itself makes, and from
    the same start assignment, so allies show side by side. Generating a
    map takes 40-60 ms, so it redraws on every change.
  - *A fifth kind of country in every region, the prize*: the Island
    (Greenwood, a moat), Rimrock (Dustlands), the Cirque (Frostline), the
    Cauldron (Cinder Wastes, a lava moat). A ring 9-12 cells from the
    centre with four gates five cells wide a quarter turn apart, and
    20,000 salvage inside, more than anywhere else on the map. The ring is
    the same under quarter and half turns, so it serves two and four
    starts. The gates and the ground inside are cleared again after the
    rest of the country is scattered. Adding a kind changed which kind
    each seed gives (the barrier kind keeps its 28%; the other four share
    the rest), so every seed is a different map from yesterday's.
  - *Three layouts*: Dry Gulch (Dustlands, two players), Frozen Strait
    (Frostline, two players), Ember Lake (Cinder Wastes, four players).
    `tools/make_layouts.py` now writes all six and their regions (the
    regions of the first three had been added to the JSON by hand; running
    the tool would have dropped them).
  - High ground was left out of this commit and done afterwards (see
    "High ground" further down).

- **`tools/check.sh` failed on the M32 commit** (not pushed alone): the
  Lodestone against Verdigris match was undecided at 45 minutes. Both ran
  out of salvage; the Order, with thirteen buildings and almost no army or
  income from minute 18, held behind its turrets, and it was neither "down
  to eight buildings" nor outmatched 2.5 to 1, so it never conceded. Two
  changes: the AI weighs artillery up by 0.45 for every enemy turret it
  knows of (to +3.0), since siege guns out-range turrets; and a second way
  to be beaten: from minute 18, less than 150 salvage in over four minutes,
  less than 400 in the bank, and the strongest enemy side at 1.5 times
  ours. The same match then ends at 24 minutes.
- **The owner on conceding: "if I play against AI would be boring if it
  concede, I'm not sure."** Decision: no AI concedes while a person is
  still playing, on either side. Conceding stays for matches the AI plays
  against itself (Watch, the checks, the leagues), which is what it was
  for. Tests cover both.
- **The owner, looking at a capture of a fight: the tanks "line up so it
  looks like they are merged".** Part of that was the capture (I had
  spawned pairs on top of each other). The rest is real: units were pushed
  apart only as far as the sum of their radii, and vehicle models are
  longer than that and drawn 10% over size, so two tanks nose to tail
  overlapped by a metre and read as one long machine. Now vehicles keep
  1.45 times the sum of their radii and aircraft 2.1 times
  (`SimMovement.personal_space`), formations of vehicles are 1.2 times
  deeper than wide, and each rank stands behind the gaps of the one in
  front. `tools/screenshot.sh x 360 crowd_<unit id>` drops twelve of a unit
  on one spot and marches them off, to look at this. What is left: a long
  gun still reaches over the vehicle ahead when twelve are dropped on one
  point. A measurement of every model against its footprint showed the
  worst overhangs are gun barrels (Stalker, Halberd, Mauler, Castellan).
- **M34, the combat half.** Each faction's weapons burn in its own colour
  (`fx_color` in `data/factions.json`: tracers, muzzle flashes, shells and
  the shock ring of their bursts). Explosions lean a different way each
  time; from a certain size they get a second, slower fireball, and the
  biggest a ring of dust and a pillar of smoke that hangs for four
  seconds. A vehicle's wreck burns for twelve seconds and smokes for
  twenty-six (only a wreck made in view: one already lying there when a
  save is loaded does not catch fire again). Tried and removed: a glowing
  disc of embers under big explosions, which drew as a flat orange circle.
  Still open in M34: a better look for every faction's models, and
  lighting, water and sky.
- **High ground (M33's last box).** Not a terrain of its own after all: a
  second layer on the map (`SimMap.high`, one byte a cell), so a hill can
  be grass, forest or sand and nothing in the path finder changes. Rules,
  in `data/rules.json`: a ground unit or a building standing on a high
  cell shoots 15% further and sees 25% further; aircraft get nothing. The
  generator scatters hills on every map with the same mirroring as the
  rest, never on rock or water and never within a base's reach of a start;
  the six hand-made layouts have hills too (a second grid, "high", in
  their JSON, written by `tools/make_layouts.py`: over the fords, beside
  the passes, on the shore roads). Units cross a bank anywhere.
  Buildings cannot stand on one ("Too steep to build on":
  `SimMap.is_bank`), because a hall half on a slope hangs in the air. The
  selection panel says when what is selected stands on high ground, and
  the minimap and the setup preview draw high ground lighter.
  - *How it looks.* The first version marked each hilltop with a paler top
    and a dark line round it, on ground that rose too gently to see. **The
    owner, on a capture of it: "looks weird"** — it looked drawn on with a
    marker. Replaced: a hill is now a real terrace 2.8 high with a bank
    about two cells wide, which the sun lights on one side and shades on
    the other; steep ground shows earth (stone only beside rock), and the
    top is a little drier. No outline.
  - Adding hills moves the random stream, so every seed is once more a
    different map from before.
  - Not done: the AI does not know about hills (it neither seeks them for
    its guns nor avoids attacking up one); the three-way and team matches
    in the check are unchanged by that.
- **Water and sky (M34).** The old water was one flat blue with a hard
  white line round it, and the line ran straight from mesh corner to mesh
  corner, so every lake was a polygon. Now the sheet is pulled back from
  its true edge by an uneven amount (noise, in the shader), so the shore
  wanders and sand shows under clear shallows; foam is a thin line that
  comes and goes instead of an outline; thin ripples drift over it; the
  deeps take a little of the sky's colour for the hour (`SceneLight.
  sky_over`), and the cloud shadows that cross the land cross the water
  too. Frostline water is frozen (`RegionLook.water_ice`): a matte sheet,
  clouded in patches, cracked, with snow drifted over it from the shore.
  Lava keeps its look and gains the ragged edge. The sky is never in the
  picture, so nothing was built for it beyond that; the box is ticked on
  that understanding. `tools/screenshot.sh x 140 region_<id>_<seed>_water`
  looks at the water nearest the middle of a map.
- **Units and buildings (M34's last box).** `tools/gallery.tscn` has two
  new pages: `faction_<id>` (everything one faction has) and `model_<id>`
  (one model close up). All ten factions were captured this way and looked
  at. Decision: the eight older factions each have a look of their own
  that holds together (Aegis a modern base in grey and blue, the Foundry
  black works with stacks, the Nomads tents and buggies, Vesper pale
  hexagons, Verdigris a castle order on legs, Zephyr a white airfield, the
  Tally black and gilt, the Veil dusk-blue spires), so they are not
  redrawn; redrawing what already works is how the first attempt went
  wrong. What was added is motion, which no still picture shows:
  - Ground vehicles and wrecks lie along the slope under them (measured
    across their own length, smoothed), so a tank climbing a bank noses up
    instead of hanging level in the air. Needed anyway now that hills have
    real banks.
  - Walking machines (Verdigris) and beasts (Brackenfold) step: every leg
    is its own group hinged at the hip (`_leg_group`, "Leg0", "Leg1"...),
    swung while the unit moves, diagonal legs together, the body riding up
    a little at each step. Wrecks keep their legs where they stood.
  - Not done: wheels do not turn (they are plain cylinders, so it would
    not show) and tracks do not run.
  - **The owner asked whether the old designs were saved, to compare, and
    then withdrew it ("never mind, don't save old Brackenfold design").**
    So nothing was added for that. For the record: the first Brackenfold
    (bark and moss) was never pushed on its own and exists only in this
    container's reflog; the Wardrum is in history at `5c20c17`.
- **M35, asked for by the owner at 00:50 UTC: "Autosave every few minutes,
  and more than one save slot" and "Unit stances: aggressive, hold fire,
  return fire"; of the rest of the ideas list, "I don't care".** The list
  is now "Ideas not taken up" above.
- **Stances.** `SimEntity.stance` (aggressive by default), set with a new
  command (`SimCommand.stance`), for units only: buildings always shoot.
  Hold fire: the unit never picks a target itself. Return fire: its target
  is whoever hit it in the last five seconds, or failing that whoever hit
  one of its own side within 9 units of it, so a squad on return fire
  defends itself as a squad. An attack order is obeyed in every stance,
  and changing stance drops a target the unit had picked for itself at
  once. Attack-move in a stance other than aggressive is a move that
  answers (or ignores) fire: that follows from the rule and is left so.
  The AI never changes stance. In the interface: Z cycles the selection's
  stance, the command card has a button that names the current one, and a
  unit that is not aggressive says so in the selection panel. Stance is
  in the save (a plain field; old saves load as aggressive).
- **Save slots and autosave.** Saves live in `user://saves/`: `slot1` to
  `slot3`, written from the pause menu, and `auto`, written by the game.
  A slot file is two values: a short header (when, how far in, which map,
  who is playing) and then the match as before, so a load screen can
  describe a save without rebuilding it. A save is written beside its slot
  and moved over it, so being cut off half-way cannot spoil a good one.
  The single save file of earlier builds (`user://skirmish.sav`) is still
  read, as Slot 1, until Slot 1 is saved to. "Save Game" and "Save and
  Quit" in the pause menu now open the slots (the one this match last
  used is picked out); "Continue Saved Game" on the main menu became
  "Load Game", a page of every save, newest first. A match loaded from a
  slot saves back to that slot. Autosave counts minutes of play, not of
  pause, and does nothing in a tutorial, in a match nobody is playing or
  after the match is over; Settings has Off, 2, 5 (the default) and 10
  minutes. The tests and the flow check use slots of their own names
  (`test_slot`, `smoke_slot`), so running them never touches a player's
  saves. One autosave, not a rolling set: a second would only matter if
  the first were written at a bad moment, and the three slots cover that.
- **A mistake of this session, and its repair (00:45 UTC).** Two status
  pushes (`e1aa916` at 00:23 and `1eb8be5` at 00:40) replaced the wrong
  paragraph of this log: the text search for "Working now" found session
  7's paragraph first, so the body of session 7's entry and this
  session's heading were overwritten on the remote for some minutes each.
  No code was touched. The entry was restored word for word from the
  commit before (`3b8d701`), and the status is now written by a script
  that looks only below this session's own heading and refuses to
  replace more than a paragraph's worth.
- The frame benchmark after tonight's view changes (vehicles tilting,
  legs, the new water and ground shaders are not in it: no GPU): 7.31 ms
  a frame with 300 units, as before.
- **Found while adding a line about hills to How to Play: the page did
  not fit on the screen.** It was one column of forty-odd lines, taller
  than the window, centred, so its heading was cut off at the top and its
  two buttons (The Factions, Back) were off the bottom. It had been so
  since the controls list grew, some sessions ago; nobody had looked at
  that page whole since. It is now two columns: what the game is on the
  left, the controls as a table of keys on the right, and it needs 1325 by
  697 of the 1600 by 900 the interface is laid out for. The flow check
  now asks the menu for any page that needs more room than that
  (`MainMenu.pages_too_big`), so a page cannot outgrow the screen again
  without failing the check. The page also says that hills give range
  and sight, and where the save slots are.
- **Balance (M26): two leagues over all ten factions, and what they
  showed.** 180 games a round, seeds 1-4, the AI of 23:40 UTC, maps
  without hills.
  - Round 1, prices as in the data files: Nomad 88.9%, Foundry 66.7%,
    Brackenfold 58.3%, Verdigris 55.6%, Veil 44.4%, Aegis 41.7%, Vesper
    41.7%, Lodestone 41.7%, Tally 36.1%, Zephyr 19.4%. Median match 14.9
    minutes, 93% between 12 and 25, two undecided at an hour.
  - Round 2, prices Nomad x1.136, Foundry x1.058, Brackenfold x1.029,
    Tally x0.951, Zephyr x0.893: Nomad 63.9%, Brackenfold 63.9%,
    Verdigris 61.1%, Vesper 58.3%, Foundry 55.6%, Tally 44.4%, Lodestone
    44.4%, Aegis 41.7%, Veil 30.6%, Zephyr 25.0%. Median 15.3 minutes,
    88% between 12 and 25, four undecided. Furthest from even 25 points
    (39 in round 1); one standard error at 36 games is 8.3 points.
  - **Zephyr did not answer to price, and the reason was the AI.** One of
    its matches, traced minute by minute, showed it sitting on 2,000 to
    5,000 salvage with one Roost and one Flight Deck from start to finish.
    `_next_building` returns the first need that is not met, and "fewer
    relays than the early count" stood before "salvage is piling up: add
    production". An enemy that shot its forward Masts down as fast as it
    raised them kept it at the relay step for the whole match. Cheaper
    units do nothing for a faction that cannot spend what it has. Fix:
    with 1,500 or more in the bank the AI builds a works and a barracks
    (up to three over its usual number) before it goes back to relays.
    Every faction's AI has this, so the two leagues above describe an AI
    that no longer exists, and nothing from them was written to the data
    files. The tuner is playing again from its present prices.
  - The same trace showed the other half of it: with its Masts gone the
    AI's bandwidth fell to 20 and it could field nothing, with 5,000
    salvage in hand, while it went on raising each new Mast at the same
    forward spot, under the guns that had killed the last one. Now a relay
    whose spot has armed enemies within 16 units is raised in the ring
    behind the base instead: it reaches nothing new, but it carries
    bandwidth (`relays_kept_home` counts them).
  - **With the fixed AI** (both changes above), hills on the maps, 180
    games a round, seeds 1-4:
    - Round 1 (02:30 UTC), prices as the tuner had left them for the old
      AI (Nomad x1.191, Brackenfold x1.079, Foundry x1.058, Verdigris
      x1.039, Vesper x1.029, Tally x0.951, Veil x0.932, Zephyr x0.815):
      Brackenfold 72.2%, Tally 58.3%, Veil 58.3%, Lodestone 52.8%, Vesper
      50.0%, Verdigris 50.0%, Zephyr 44.4%, Foundry 36.1%, Nomad 36.1%,
      Aegis 30.6%. Median match 16.3 minutes, 87% between 12 and 25, four
      undecided. Furthest from even 22.2 points. Zephyr went from 25% to
      44%: most of its trouble was the AI, as traced. The prices that
      were right for the old AI overcharged Nomad and Foundry.
    - Round 2 (03:03 UTC), prices Brackenfold x1.163, Nomad x1.133,
      Verdigris x1.039, Vesper x1.029, Foundry x1.007, Tally x0.979, Veil
      x0.959, Aegis x0.932, Zephyr x0.815: Veil 61.1%, Tally 55.6%,
      Foundry 52.8%, Nomad 52.8%, Brackenfold 52.8%, Lodestone 50.0%,
      Vesper 47.2%, Verdigris 47.2%, Aegis 36.1%, Zephyr 36.1%. Median
      16.0 minutes, 92% between 12 and 25, three undecided. Furthest from
      even 13.9 points.
    - Round 3 (03:34 UTC), prices Brackenfold x1.163, Nomad x1.133,
      Verdigris x1.039, Vesper x1.029, Foundry x1.007, Veil x0.996, Tally
      x0.979, Aegis x0.887, Zephyr x0.775: Aegis 58.3%, Brackenfold 58.3%,
      Foundry 52.8%, Vesper 52.8%, Tally 52.8%, Nomad 50.0%, Veil 50.0%,
      Verdigris 41.7%, Lodestone 41.7%, Zephyr 38.9%. Median 16.1
      minutes, 95% between 12 and 25, one undecided. Furthest from even
      11.1 points, with one standard error at 8.3.
  - **Prices written (03:35 UTC):** the tuner's last step from round 3,
    Aegis x0.913, Brackenfold x1.197, Nomad x1.133, Verdigris x1.039,
    Vesper x1.029, Foundry x1.007, Veil x0.996, Tally x0.979, Zephyr
    x0.745, Lodestone as it was, each cost rounded to five: 47 unit costs
    in `data/units.json` (a Trooper 55 to 50, a Bulwark 380 to 345, a
    Barkhide 360 to 430, a Prowler 266 to 300, a Lanner 320 to 240). Only
    armed units the AI builds are repriced; buildings, builders, haulers
    and the six signature support units are as they were. The tuner saw
    seeds 1 to 4 only, so these prices are being tested on seeds 5 to 10.
  - **The prices tested on seeds the tuner never saw (04:26 UTC): seeds 5
    to 10, 270 games, 54 a faction.** Nomad 55.6%, Vesper 55.6%, Zephyr
    53.7%, Aegis 51.9%, Foundry 50.0%, Tally 50.0%, Veil 50.0%, Verdigris
    48.1%, Lodestone 42.6%, Brackenfold 37.0%. Nine of ten within 7.4
    points of even; Brackenfold 13.0 below, so the box is not ticked on
    this league. One standard error at 54 games is 6.8 points. Median
    match 16.3 minutes; 57% of games between 15 and 25 minutes (31%
    shorter, 12% longer); by pairing, the average length is between 15 and
    25 minutes in 41 of the 45 (shortest Aegis against Nomad at 13.5,
    longest Nomad against Tally at 28.9); three games undecided at an hour.
  - Brackenfold had won 72%, 53% and 58% on seeds 1 to 4 and was priced
    up for it (x1.197); on other maps that was too much. The tuner's own
    rule applied to this league (a price change of 0.35 of the distance
    from even, nothing inside one standard error) gives Brackenfold x0.955
    and Lodestone x0.974 on top: 14 more costs (a Barkhide 430 to 410, an
    Armature 380 to 370). Being tested again on seeds 11 to 16.
  - **The second league on unseen seeds (05:15 UTC), seeds 11 to 16, 270
    games, with Brackenfold and Lodestone made cheaper:** Aegis 72.2%,
    Foundry 64.8%, Tally 55.6%, Vesper 51.9%, Verdigris 51.9%, Nomad
    48.1%, Zephyr 44.4%, Brackenfold 44.4%, Veil 35.2%, Lodestone 27.8%.
    Median 16.5 minutes, 89% between 12 and 25, two undecided. Furthest
    from even 22.2 points.
  - **Finding: which maps are drawn moves a faction by fifteen points and
    more.** Aegis took 58%, 52% and 72% of its games on seeds 1 to 4, 5 to
    10 and 11 to 16 at almost the same prices; Lodestone 42%, 43% and
    28%; Brackenfold 58%, 37% and 44%. Games on one seed share a map, so
    they are not independent, and the "standard error" the tools print
    (6.8 points at 54 games) understates the spread between leagues by
    about half. A league of 54 games a faction on six maps is not enough
    to judge "within ten points"; nor was tuning on four maps.
  - **All three leagues at near-final prices pooled (16 seeds, 144 games a
    faction):** Aegis 61.1%, Foundry 56.2%, Vesper 53.5%, Tally 52.8%,
    Nomad 51.4%, Verdigris 47.9%, Zephyr 46.5%, Brackenfold 45.1%, Veil
    44.4%, Lodestone 36.8%. Eight within 6.2 points of even; Aegis 11.1
    above, Lodestone 13.2 below. Box not ticked.
  - The tuner's rule applied to the pooled result (nothing inside one
    standard error of 4.2 points): Aegis x1.039, Foundry x1.022,
    Brackenfold x0.983, Veil x0.981, Lodestone x0.954. Written (28
    costs: a Bulwark 345 to 360, an Armature 370 to 355), and being
    measured over all sixteen seeds at once: 720 games, 144 a faction,
    about two hours.
  - **The league over all sixteen seeds (07:04 UTC), 720 games, 144 a
    faction, with the pooled correction:** Foundry 56.9%, Nomad 56.9%,
    Tally 54.9%, Vesper 53.5%, Verdigris 50.7%, Zephyr 48.6%, Aegis
    47.9%, Lodestone 43.1%, Brackenfold 42.4%, Veil 38.2%. Nine within 7.6
    points of even; the Veil 11.8 below. One standard error at 144 games
    is 4.2 points (and see the finding above: the real spread is wider).
    Median game 16.2 minutes; 60% of games between 15 and 25 minutes, 31%
    shorter, 9% longer; ten of 720 undecided at an hour. **By pairing the
    average length is between 15 and 25 minutes in 44 of the 45** (the
    one outside is Brackenfold against Veil at 14.5; the longest is
    Brackenfold against Tally at 24.0), so M26's second box is ticked.
    The first is not: the Veil is not within "about ten".
  - One more step of the tuner's rule from that league: Foundry x1.024,
    Nomad x1.024, Tally x1.017, Lodestone x0.976, Brackenfold x0.973, Veil
    x0.959 (29 costs: a Stalker 355 to 340, a Mauler 535 to 550). Being
    measured over the same sixteen seeds again.
  - **That step failed the check (07:25 UTC) and was not pushed:** the
    three-way match (Foundry, Nomad, Aegis, seed 5) had no winner after
    ninety minutes; with the prices before it had ended at 35. Traced:
    by minute 50 the map's salvage was gone and both survivors lived on
    their uplinks, and the Nomad AI had 20 to 37 Splicers at any time (its
    vehicle thief, which does not fight and so does not die) and a dozen
    Drifters. Nothing limited how many it trained: one infantry order in
    seven for the whole match, 140 salvage and a point of bandwidth each.
    It had been doing this in every long match. Fix: an AI keeps at most
    three hijackers (`MAX_HIJACKERS`); the same match then ends at 31
    minutes. This makes the Nomad AI stronger, so the league is being
    played again before the box is judged.
  - The session's worker was restarted at about 01:55 UTC and this time
    took the running check and the league with it (both had been started
    with `setsid`, which had been enough before). A league round is fifty
    minutes of matches, so `tools/balance_league.py` now remembers every
    finished job in `.godot-bin/league_cache.json`, under a hash of `sim/`,
    `data/` and the batch script: a league that is cut off picks up where
    it stopped, and one played on a changed game starts again.
  - A test had to change with it: "a starved AI concedes" starved its AI
    by killing its units and emptying its bank, but the AI now has an
    uplink by minute eighteen, which pays 180 a minute, so it was (rightly)
    not starving. The test takes the uplinks away as well.

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
