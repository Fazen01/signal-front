extends TestCase
## The Zephyr Accord (air power, Linked sight), the Crimson Tally (bounties),
## the Umbral Veil (hidden while still inside its own coverage), the
## Brackenfold (everything grows back) and the Lodestone Circle (what it
## hits is slowed).

const NEW: Array[String] = ["zephyr", "tally", "veil", "bracken", "lodestone"]


func _world(faction: String) -> SimWorld:
	var config: MatchConfig = MatchConfig.skirmish(6)
	config.map_cells = SimMapGen.SMALL_CELLS
	config.factions = [faction, "aegis"]
	config.is_ai = [false, false]
	var w: SimWorld = SimSetup.create_match(config)
	for p: SimPlayer in w.players:
		p.salvage = 5000
	return w


func _own(w: SimWorld, owner: int, def_id: String) -> Array[SimEntity]:
	var out: Array[SimEntity] = []
	for e: SimEntity in w.entities:
		if e.alive and e.owner == owner and e.def != null and e.def.id == def_id:
			out.append(e)
	return out


func test_each_new_faction_starts_with_its_own_base() -> void:
	for faction: String in NEW:
		var w: SimWorld = _world(faction)
		var f: FactionDef = w.players[0].faction
		check_eq(_own(w, 0, f.hq).size(), 1, "%s: headquarters placed" % f.name)
		check_eq(_own(w, 0, f.role("builder")).size(), 2, "%s: two builders" % f.name)
		check_eq(_own(w, 0, f.role("hauler")).size(), 2, "%s: two haulers" % f.name)
		SimTestUtil.run(w, 20 * 60)
		check(w.players[0].stat_salvage_collected > 0, "%s: haulers harvest on their own" % f.name)


func test_everything_they_own_can_be_made() -> void:
	var data: GameData = GameData.shared()
	for faction: String in NEW:
		var f: FactionDef = data.faction(faction)
		var made: Dictionary[String, bool] = {}
		var built: Dictionary[String, bool] = {}
		for def: EntityDef in data.entities.values():
			if def.faction != faction:
				continue
			for id: String in def.produces:
				made[id] = true
				check(data.entity(id).faction == faction, "%s produces only its own units (%s)" % [def.name, id])
			for id: String in def.builds:
				built[id] = true
				check(data.entity(id).faction == faction, "%s builds only its own buildings (%s)" % [def.name, id])
		var count: int = 0
		for def: EntityDef in data.entities.values():
			if def.faction != faction:
				continue
			count += 1
			if def.is_building:
				check(built.has(def.id) or def.id == f.hq, "%s can be built" % def.name)
			else:
				check(made.has(def.id), "%s is produced somewhere" % def.name)
		check_eq(count, 16, "%s: nine units and seven buildings" % f.name)
		for role: String in ["builder", "hauler", "relay", "barracks", "works", "depot", "turret_ground", "turret_armor", "turret_air", "tier3"]:
			check(data.entities.has(f.role(role)), "%s: the AI has a %s (%s)" % [f.name, role, f.role(role)])


func test_the_ai_plays_each_new_faction() -> void:
	for faction: String in NEW:
		var config: MatchConfig = MatchConfig.ai_vs_ai(9)
		config.map_cells = SimMapGen.SMALL_CELLS
		config.factions = [faction, "aegis"]
		var w: SimWorld = SimSetup.create_match(config)
		w.collect_events = false
		var f: FactionDef = w.players[0].faction
		SimTestUtil.run(w, 20 * 60 * 6)
		check(_own(w, 0, f.role("barracks")).size() >= 1, "%s: the AI built its barracks" % f.name)
		check(_own(w, 0, f.role("relay")).size() >= 1, "%s: and extended its grid" % f.name)
		check(w.players[0].stat_salvage_collected > 500, "%s: and collected salvage" % f.name)
		check(w.players[0].stat_units_built >= 8, "%s: and raised an army (%d built)" % [f.name, w.players[0].stat_units_built])


func test_linked_accord_units_see_further() -> void:
	var w: SimWorld = _world("zephyr")
	var aerie: SimEntity = _own(w, 0, "aerie")[0]
	var toward: Vector2 = (w.map.world_size() * 0.5 - aerie.pos).normalized()
	var near: SimEntity = w.spawn_unit("ranger", 0, w.map.nearest_free_pos(aerie.pos + toward * 9.0))
	var far: SimEntity = w.spawn_unit("ranger", 0, w.map.nearest_free_pos(aerie.pos + toward * 44.0))
	SimTestUtil.run(w, 3)
	check(near.linked and not far.linked, "one ranger is Linked and one is Dark")
	check(absf(SimCombat.sight_range(w, near) - near.def.sight * 1.25) < 0.01, "the Linked ranger sees a quarter further (%.1f)" % SimCombat.sight_range(w, near))
	check(SimCombat.sight_range(w, far) < far.def.sight, "the Dark one sees less than normal")
	var trooper: SimEntity = _own(w, 1, "trooper")[0]
	check(absf(SimCombat.sight_range(w, trooper) - trooper.def.sight) < 0.01, "a Linked Aegis trooper sees the normal distance")


func test_accord_aircraft_fly_over_anything() -> void:
	var data: GameData = GameData.shared()
	for id: String in ["swift", "lanner", "condor"]:
		check(data.entity(id).is_air(), "%s is an aircraft" % id)
	check(not data.entity("lanner").weapons[0].hits_air, "the Lanner cannot fire at aircraft")
	check(data.entity("flare").weapons[0].hits_air, "the Flare can")
	var w: SimWorld = _world("zephyr")
	var aerie: SimEntity = _own(w, 0, "aerie")[0]
	var swift: SimEntity = w.spawn_unit("swift", 0, aerie.pos + Vector2(6.0, 6.0))
	var hq: SimEntity = _own(w, 1, "hq")[0]
	w.push_command(SimCommand.move(0, PackedInt32Array([swift.id]), hq.pos + Vector2(-14.0, -14.0)))
	var from: Vector2 = swift.pos
	SimTestUtil.run(w, 20 * 8)
	check(swift.pos.distance_to(from) > 30.0, "a Swift covers ground fast (%.0f in eight seconds)" % swift.pos.distance_to(from))


func test_the_tally_is_paid_for_what_it_destroys() -> void:
	var w: SimWorld = _world("tally")
	var house: SimEntity = _own(w, 0, "counting_house")[0]
	var victim: SimEntity = w.spawn_unit("bulwark", 1, w.map.nearest_free_pos(house.pos + Vector2(12.0, 12.0)))
	var killer: SimEntity = _own(w, 0, "gunhand")[0]
	var before: int = w.players[0].salvage
	SimCombat.apply_damage(w, victim, 100000.0, GameData.DAMAGE_TYPES.find("piercing"), killer, 0)
	check(not victim.alive, "the tank is destroyed")
	check_eq(w.players[0].salvage - before, int(float(victim.def.cost) * 0.15), "the Tally is paid 15% of its value")
	# Nobody else is.
	var other: SimEntity = w.spawn_unit("gunhand", 0, w.map.nearest_free_pos(house.pos + Vector2(-12.0, 12.0)))
	var aegis_before: int = w.players[1].salvage
	SimCombat.apply_damage(w, other, 100000.0, GameData.DAMAGE_TYPES.find("ballistic"), _own(w, 1, "trooper")[0], 1)
	check_eq(w.players[1].salvage, aegis_before, "Aegis gets nothing for a kill")


func test_veil_units_hide_while_still_inside_their_coverage() -> void:
	var w: SimWorld = _world("veil")
	var sanctum: SimEntity = _own(w, 0, "sanctum")[0]
	var toward: Vector2 = (w.map.world_size() * 0.5 - sanctum.pos).normalized()
	var inside: SimEntity = w.spawn_unit("shade", 0, w.map.nearest_free_pos(sanctum.pos + toward * 12.0))
	var outside: SimEntity = w.spawn_unit("shade", 0, w.map.nearest_free_pos(sanctum.pos + toward * 44.0))
	SimTestUtil.run(w, 30)
	check(inside.linked and not outside.linked, "one shade is Linked and one is Dark")
	check(SimVision.is_stealthed(w, inside), "the Linked shade is hidden while it stands still")
	check(not SimVision.is_stealthed(w, outside), "the Dark one is not")
	check(not SimVision.can_see(w, 1, inside), "the enemy cannot see the hidden shade")
	# An enemy that comes close finds it.
	var seeker: SimEntity = w.spawn_unit("trooper", 1, inside.pos + Vector2(2.0, 0.0))
	SimTestUtil.run(w, 10)
	check(SimVision.can_see(w, 1, inside), "an enemy two steps away does (%s)" % seeker.def.name)
	# Moving gives it away as well.
	seeker.hp = 0.0
	w.remove_entity(seeker)
	w.push_command(SimCommand.move(0, PackedInt32Array([inside.id]), inside.pos - toward * 4.0))
	SimTestUtil.run(w, 10)
	check(not SimVision.is_stealthed(w, inside), "a shade on the move is not hidden")
	# Sentinels are hidden until they fire; other buildings never are.
	check(w.data.entity("sentinel").stealth, "the Sentinel turret is a hidden building")
	check(not SimVision.is_stealthed(w, sanctum), "the Sanctum itself is always visible")
	# Aegis units get no such thing.
	var trooper: SimEntity = _own(w, 1, "trooper")[0]
	check(trooper.linked and not SimVision.is_stealthed(w, trooper), "a Linked Aegis trooper standing still is in plain view")


func test_the_brackenfold_grows_back() -> void:
	var w: SimWorld = _world("bracken")
	var beast: SimEntity = w.spawn_unit("barkhide", 0, w.map.nearest_free_pos(w.players[0].start_pos + Vector2(10.0, 0.0)))
	var other: SimEntity = w.spawn_unit("bulwark", 1, w.map.nearest_free_pos(w.players[1].start_pos + Vector2(10.0, 0.0)))
	var hq: SimEntity = _own(w, 0, "heartroot")[0]
	beast.hp = beast.max_hp * 0.5
	other.hp = other.max_hp * 0.5
	hq.hp = hq.max_hp * 0.5
	# Just hit: nothing mends for the first few seconds.
	beast.last_hit_tick = w.tick_count
	SimTestUtil.run(w, SimCombat.REGROW_DELAY - 10)
	check(is_equal_approx(beast.hp, beast.max_hp * 0.5), "a Barkhide that was just hit does not mend yet")
	SimTestUtil.run(w, 20 * 20)
	check(beast.hp > beast.max_hp * 0.68, "left alone, it grows back (%.0f of %.0f)" % [beast.hp, beast.max_hp])
	check(hq.hp > hq.max_hp * 0.68, "and so do the Brackenfold's buildings")
	check(is_equal_approx(other.hp, other.max_hp * 0.5), "another faction's tank stays as damaged as it was")
	SimTestUtil.run(w, 20 * 60)
	check(is_equal_approx(beast.hp, beast.max_hp), "it mends all the way and no further")


func test_what_the_circle_hits_is_slowed() -> void:
	var w: SimWorld = _world("lodestone")
	var middle: Vector2 = w.map.nearest_free_pos(w.map.world_size() * 0.5)
	var runner: SimEntity = w.spawn_unit("courser", 1, middle)
	var far: Vector2 = w.map.nearest_free_pos(middle + Vector2(30.0, 0.0))
	# How far it gets in three seconds when nobody is shooting.
	w.push_command(SimCommand.move(1, PackedInt32Array([runner.id]), far))
	SimTestUtil.run(w, 60)
	var free_run: float = runner.pos.distance_to(middle)
	check(free_run > 6.0, "the car moves freely (%.1f)" % free_run)
	check(runner.slow_until <= w.tick_count, "and is not dragged")
	# The same run after a Keeper's bullet.
	var keeper: SimEntity = w.spawn_unit("keeper", 0, w.map.nearest_free_pos(runner.pos + Vector2(0.0, 5.0)))
	SimCombat.apply_damage(w, runner, 1.0, 0, keeper, 0)
	check(runner.slow_until > w.tick_count and runner.slow_amount > 0.3, "a hit from the Circle drags it")
	var from: Vector2 = runner.pos
	SimTestUtil.run(w, 20)
	var dragged: float = runner.pos.distance_to(from)
	check(dragged < free_run / 3.0 * 0.8, "it covers less ground while dragged (%.1f in a second, %.1f free)" % [dragged, free_run / 3.0])
	# Buildings are not dragged, and another faction's hits drag nothing.
	var hq: SimEntity = _own(w, 1, "hq")[0]
	SimCombat.apply_damage(w, hq, 1.0, 0, keeper, 0)
	check(hq.slow_until <= w.tick_count, "a building is not dragged")
	var mine: SimEntity = w.spawn_unit("compass", 0, w.map.nearest_free_pos(middle + Vector2(-8.0, 0.0)))
	var trooper: SimEntity = w.spawn_unit("trooper", 1, w.map.nearest_free_pos(middle + Vector2(-8.0, 3.0)))
	SimCombat.apply_damage(w, mine, 1.0, 0, trooper, 1)
	check(mine.slow_until <= w.tick_count, "other factions' weapons do not drag")
