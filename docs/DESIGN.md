# Signal Front — Game Design

## Pitch

Near-future real-time strategy in 3D. Build a base, harvest salvage, field a
combined-arms army and destroy the enemy — on a battlefield where **every army
runs on signal**. Units fight at full strength only inside their own command
network. Relays chain back to the HQ, and one cut link can black out a whole
front. You win by out-building and out-fighting the enemy, or by taking their
network apart.

It sits in the modern-military base-building RTS genre (harvesters, tech tiers,
tanks and infantry, commander powers). It is **not** a recreation of any
existing game: every name, faction, unit, map, sound and piece of text is
original. Never borrow names, units, factions, art, audio, quotes or map
layouts from an existing game.

## Pillars

1. **The network is the map.** Territory is signal coverage. Expanding,
   defending and cutting relay chains is the central strategic layer.
2. **Readable combined arms.** Few unit types, clear counters, clear silhouettes.
3. **Fast matches.** A 1v1 skirmish lasts 15–25 minutes.
4. **Asymmetric factions** that each relate to signal differently.

## Core systems

### Signal Grid (the twist)

- **Emitters** project signal in a radius: HQ (radius 28, always linked — the
  root), Relay (radius 18), plus some faction-specific units and buildings.
- An emitter is **linked** if it is within link range (30) of another linked
  emitter of the same player. The chain must reach the HQ. Unlinked emitters
  project nothing.
- A player's **coverage** is the union of the discs of their linked emitters,
  stored on a coarse grid (cell = 2 world units), recomputed when emitters are
  added, removed or moved (dirty flag, at most 4 times a second).
- A unit inside its own coverage is **Linked**: full stats, shared vision, can
  be healed/repaired, can receive Directives.
- A unit outside is **Dark**: −30% rate of fire, −30% sight range, no repair.
  A Dark building pauses production; a Dark turret fires at half rate.
- Buildings may only be placed inside own coverage. A Relay must be placed
  within link range of a linked emitter — that is how you expand.
- **Jamming** removes enemy coverage inside the jammer's radius.
- UI: coverage overlay toggle (G), animated link lines between emitters, a
  blackout alert when a chain is cut, a Dark icon over affected units.

### Economy

- **Salvage** is the only currency. It comes from finite Salvage Fields and
  from **wrecks**: every destroyed vehicle or building leaves a wreck worth 25%
  of its cost, which any player can harvest. Battles create resources where
  they happen.
- **Haulers** carry 100 salvage per trip to the nearest Depot (the HQ counts).
- **Bandwidth** is the population cap: HQ gives 20, each linked Relay +10,
  maximum 200. Units cost 1–6. Losing relays can put you over the cap, which
  blocks production until fixed.
- **Uplink Sites** are neutral points that pay a salvage trickle to whichever
  player has them inside their coverage.

### Construction and production

- Builder units construct buildings over time; extra builders speed it up with
  diminishing returns. Unfinished buildings can be cancelled for a refund.
- Tech tiers: T1 HQ → Depot, Relay, Barracks. T2 Vehicle Works, turrets.
  T3 Command Lab → Airpad, artillery, Directive upgrades.
- Production queues hold 5; production buildings have rally points.

### Combat

- Damage types: Ballistic, Explosive, Piercing, Flak. Armor classes: Infantry,
  Light, Heavy, Structure, Air. One multiplier table drives all counters.
- Small arms are hitscan; shells and missiles are simulated projectiles.
  Vehicles have turret traverse; artillery has minimum range and scatter.
- Veterancy: three ranks earned by value destroyed (+damage, +health, slow
  self-repair at top rank).
- Forest gives infantry −40% damage taken and slows vehicles by half.

### Directives (commander powers)

Destroying enemy value earns Command Points, spent to unlock Directives, each
on a cooldown:

| Directive | Effect |
|---|---|
| Recon Sweep | Reveals an area for 20 s. Usable anywhere. |
| Shell Barrage | Off-map artillery on an area. Target must be in own coverage or within 15 of it. |
| Field Repair | Heals own units and buildings in an area. Own coverage only. |
| Signal Surge | +50% radius on all own emitters for 30 s. |
| Blackout | Removes enemy coverage in an area for 20 s. Usable anywhere revealed. |
| Reinforcement Drop | Delivers a small squad. Own coverage only. |

### Factions

The first playable build ships **Aegis Directorate** only (mirror match).
The other two follow in later milestones.

**Aegis Directorate** — disciplined, precise, networked. Fixed long-range
relays. Linked units also gain +15% weapon range; Dark hits them hardest.

- Infantry: Trooper (rifle squad), Lancer (anti-armor missile team),
  Field Engineer (builds, repairs, captures), Marksman (T2, long sight, stealth
  while still).
- Vehicles: Hauler, Courser (scout car), Warden (autocannon IFV), Bulwark
  (main battle tank), Tempest (anti-air track), Longbow (T3 artillery).
- Air: Kestrel (T3 gunship), Scout Drone.
- Buildings: HQ, Depot, Relay, Barracks, Vehicle Works, Sentry Turret
  (anti-infantry), Lance Battery (anti-armor), Flak Post, Command Lab, Airpad.

**Foundry Pact** — slow heavy industry. Relays are cheap armored Pylons with
short radius, so the network is a dense, tough web. Linked vehicles self-repair.

- Signature: Crawler (mobile factory that deploys anywhere inside coverage),
  Mauler (heavy tank), Anvil (siege mortar carrier), Ratchet (repair truck),
  Levy (cheap massed infantry), Sapper (builder, lays mines).

**Added on 16 November at the owner's request**, each with one rule of its
own on top of the shared Signal Grid:

- **Verdigris Order** — few, costly, armored knights and walkers. Linked
  units take 15% less damage; Dark ones fire at 55%.
- **Zephyr Accord** — air power: gunships, strike craft and bombers over a
  thin ground force. Linked units see 25% further.
- **Crimson Tally** — mercenaries paid a bounty of 15% of the value of
  everything they destroy.
- **Umbral Veil** — ambushers: Linked ground units are hidden while they
  stand still, and their turrets are hidden until they fire.

**Vesper Array** (added 16 November at the owner's request) — an automated
legion of drone frames: cheap, quick and many, but fragile. Linked frames
move 15% faster; Dark frames keep 92% of their rate of fire. No aircraft and
no heavy tank; its relay, the Spire, is cheaper than a Relay and reaches less
far.

- Signature: Mote (cheap walking drone), Halberd (battle skimmer), Prism
  (siege skimmer); everything with wheels elsewhere hovers here.

**Nomad Circuit** — fast, light, elusive. No fixed relays: signal comes from
mobile Beacon Rigs that deploy and pack up, and the HQ itself can relocate.

- Signature: +50% salvage from wrecks; Jammer Buggy; units cloak when
  stationary in forest; Splicer infantry can **hijack enemy vehicles that are
  Dark**; cheap fast raiders (Dart bikes, Sidewinder missile trucks).

### Maps

- Flat-to-rolling terrain with impassable rock and water, forest patches,
  Salvage Fields near each start and richer contested fields mid-map, Uplink
  Sites on the flanks.
- Sizes: 176×176 world units (2 players; a compact 128×128 option for
  shorter matches), 192×192 (up to 4). The hand-made two-player layouts are
  128×128.
- A seeded, mirrored procedural generator plus three hand-tuned layouts stored
  as data. Start positions are always symmetric.

### Controls and UI

- Camera: WASD / edge pan, mouse-wheel zoom, middle-drag or Q/E rotate.
- Left click / drag box selects; double-click selects same type on screen;
  Shift adds. Right click is a context order (move, attack, harvest, repair,
  capture, set rally). A = attack-move, S = stop, H = hold position.
- Ctrl+1..9 set control groups, 1..9 recall, double-tap centers the camera.
- HUD: salvage and bandwidth at the top, minimap bottom-left (click to move
  the camera, right-click to order), selection panel and command card with
  hotkeys bottom-center/right, Directive bar, alerts feed.
- Build placement shows a ghost tinted valid/invalid, plus the coverage overlay.
- Screens: main menu, skirmish setup (map, faction, AI difficulty, seed),
  pause menu, settings, victory/defeat summary with stats.

### Skirmish AI

- Scripted-priority AI on a slow tick: economy (haulers, depots), expansion
  (relays toward salvage and Uplink Sites), tech, army composition that reacts
  to what it has scouted, attack waves, base defense.
- It understands the twist: it protects its own relay chain and prefers to
  attack relays whose loss would unlink the most enemy coverage.
- Easy / Normal / Hard differ in reaction time, build efficiency and
  aggression — not in cheating income.

### Presentation

- Stylised low-poly look built entirely from code: primitive and procedural
  meshes, team-colour emissive trim, strong silhouettes per unit class.
- Signal coverage drawn as a soft tinted ground overlay with animated link
  lines; Dark zones visibly desaturated.
- Tracers, muzzle flashes, explosions, smoke and wreck debris from particles.
- Audio is generated procedurally (synthesised SFX and a simple ambient bed).
  No downloaded assets.

## Technical architecture

- **Godot 4.7.2**, typed GDScript, Compatibility renderer (so software-GL
  screenshot checks work in CI; the look is stylised anyway).
- **Simulation is separate from presentation.**
  - `sim/` — plain classes (`RefCounted`), no scene-tree dependencies, fixed
    20 Hz tick, seeded RNG. Owns the map grid, entities, orders, pathfinding
    (grid A* with local steering/separation), combat, economy, signal, AI.
  - `view/` — `Node3D` scenes that mirror sim state and interpolate between
    ticks: models, health bars, effects, overlays, camera.
  - `ui/` — HUD and menus. Sends orders to the sim; never mutates sim state
    directly.
  - `data/` — unit, building, weapon and faction definitions as data files,
    validated by a test.
- Because the sim has no rendering dependency, a whole AI-vs-AI match can run
  headless at full speed. That is the main regression test for a team that
  cannot see the screen.
- Target: 300 units at 60 fps on a mid-range desktop.
