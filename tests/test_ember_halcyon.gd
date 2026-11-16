extends TestCase
## The ninth and tenth factions: the Ember Rite (what it hits keeps burning).

const NEW: Array[String] = ["ember"]


func _world(faction: String) -> SimWorld:
	var config: MatchConfig = MatchConfig.skirmish(6)
	config.map_cells = SimMapGen.SMALL_CELLS
	config.factions = [faction, "aegis"]
	config.is_ai = [false, false]
	var w: SimWorld = SimSetup.create_match(config)
	for p: SimPlayer in w.players:
		p.salvage = 5000
	return w


## A blank world: an Ember player against an Aegis one, nothing on the map.
func _blank() -> SimWorld:
	var w: SimWorld = SimTestUtil.make_world(5, 48)
	w.players[0].faction = w.data.faction("ember")
	SimTestUtil.reveal_all(w)
	return w


func _own(w: SimWorld, owner: int, def_id: String) -> Array[SimEntity]:
	var out: Array[SimEntity] = []
	for e: SimEntity in w.entities:
		if e.alive and e.owner == owner and e.def != null and e.def.id == def_id:
			out.append(e)
	return out


func test_each_starts_with_its_own_base() -> void:
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


func test_the_ai_plays_each() -> void:
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


# ------------------------------------------------------------ Ember Rite

func test_what_a_flamer_hits_keeps_burning() -> void:
	var w: SimWorld = _blank()
	var brand: SimEntity = w.spawn_unit("brand", 0, Vector2(30.0, 30.0))
	var victim: SimEntity = w.spawn_unit("bulwark", 1, Vector2(34.0, 30.0))
	w.push_command(SimCommand.hold(1, PackedInt32Array([victim.id])))
	var t: int = 0
	while t < 200 and not SimCombat.is_burning(w, victim):
		w.tick()
		t += 1
	check(SimCombat.is_burning(w, victim), "the tank is alight after the first hits")
	check_eq(victim.burn_owner, 0, "and the fire is put down to whoever lit it")
	# Take the flamer away: the fire goes on by itself, then goes out.
	w.remove_entity(brand)
	SimTestUtil.run(w, 2)
	var before: float = victim.hp
	# Nothing on this map has a signal grid, so the tank is Dark and burns faster.
	var rate: float = SimCombat.burn_rate(w, victim)
	SimTestUtil.run(w, 20 * 2)
	check(victim.hp < before - 5.0, "it goes on losing health with nobody shooting (%.1f lost)" % (before - victim.hp))
	SimTestUtil.run(w, 20 * 4)
	check(not SimCombat.is_burning(w, victim), "the fire burns out")
	var after: float = victim.hp
	SimTestUtil.run(w, 20 * 3)
	check_near(victim.hp, after, 0.001, "and then it stops losing health")
	var lost: float = before - after
	var wd: WeaponDef = w.data.weapon("brand_flamer")
	check_near(rate, wd.burn_dps * 1.5, 0.001, "the Dark tank burns half again as fast")
	check(lost > rate * wd.burn_seconds * 0.6 and lost < rate * wd.burn_seconds * 1.1, "about a whole fire's worth was lost (%.1f)" % lost)


func test_fires_do_not_stack_and_spare_aircraft() -> void:
	var w: SimWorld = _blank()
	var flamer: WeaponDef = w.data.weapon("brand_flamer")
	var mortar: WeaponDef = w.data.weapon("pitchfall_mortar")
	var tank: SimEntity = w.spawn_unit("bulwark", 1, Vector2(30.0, 30.0))
	for i: int in 5:
		SimCombat.ignite(w, tank, flamer, 0)
	check_near(tank.burn_dps, flamer.burn_dps, 0.001, "five flamers burn no hotter than one")
	SimCombat.ignite(w, tank, mortar, 0)
	check_near(tank.burn_dps, mortar.burn_dps, 0.001, "a hotter fire takes over")
	check_eq(tank.burn_until, w.tick_count + int(mortar.burn_seconds * 20.0), "and a longer one lasts longer")
	SimCombat.ignite(w, tank, flamer, 0)
	check_near(tank.burn_dps, mortar.burn_dps, 0.001, "a cooler one does not cool it")
	var plane: SimEntity = w.spawn_unit("kestrel", 1, Vector2(36.0, 30.0))
	SimCombat.ignite(w, plane, mortar, 0)
	check(not SimCombat.is_burning(w, plane), "aircraft do not burn")
	var rifle: WeaponDef = w.data.weapon("rifle")
	var other: SimEntity = w.spawn_unit("bulwark", 1, Vector2(30.0, 36.0))
	SimCombat.ignite(w, other, rifle, 0)
	check(not SimCombat.is_burning(w, other), "ordinary weapons set nothing alight")


func test_dark_targets_and_buildings_burn_differently() -> void:
	var w: SimWorld = _blank()
	var mortar: WeaponDef = w.data.weapon("pitchfall_mortar")
	var lit: SimEntity = w.spawn_unit("bulwark", 1, Vector2(30.0, 30.0))
	var dark: SimEntity = w.spawn_unit("bulwark", 1, Vector2(36.0, 30.0))
	var house: SimEntity = w.spawn_building("barracks", 1, Vector2i(20, 20), true)
	lit.linked = true
	dark.linked = false
	house.linked = true
	for e: SimEntity in [lit, dark, house]:
		SimCombat.ignite(w, e, mortar, 0)
	check_near(SimCombat.burn_rate(w, lit), mortar.burn_dps, 0.001, "a Linked vehicle burns at the weapon's rate")
	check_near(SimCombat.burn_rate(w, dark), mortar.burn_dps * 1.5, 0.001, "a Dark one half again as fast")
	check_near(SimCombat.burn_rate(w, house), mortar.burn_dps * 0.5, 0.001, "a building at half")
	# The same fire lit by somebody without the Rite's rule gains nothing from the dark.
	dark.burn_owner = 1
	check_near(SimCombat.burn_rate(w, dark), mortar.burn_dps, 0.001, "the Dark bonus is the Rite's own")


func test_a_fire_can_kill_and_the_kill_counts() -> void:
	var w: SimWorld = _blank()
	var mortar: WeaponDef = w.data.weapon("pitchfall_mortar")
	var man: SimEntity = w.spawn_unit("trooper", 1, Vector2(30.0, 30.0))
	man.hp = 6.0
	SimCombat.ignite(w, man, mortar, 0)
	SimTestUtil.run(w, 20 * 3)
	check(not man.alive, "a man on fire with little health left dies of it")
	check_eq(w.players[0].stat_kills, 1, "the kill goes to whoever lit the fire")
	check_eq(w.players[1].stat_units_lost, 1, "and the loss to the victim")


func test_a_burning_match_saves_and_loads() -> void:
	var config: MatchConfig = MatchConfig.ai_vs_ai(31)
	config.map_cells = SimMapGen.SMALL_CELLS
	config.factions = ["ember", "foundry"]
	var w: SimWorld = SimSetup.create_match(config)
	w.collect_events = false
	var target: SimEntity = null
	for e: SimEntity in w.entities:
		if e.owner == 1 and e.def != null and e.def.harvester:
			target = e
	SimCombat.ignite(w, target, w.data.weapon("pitchfall_mortar"), 0)
	SimTestUtil.run(w, 20)
	var back: SimWorld = SimSave.from_dict(SimSave.to_dict(w, config))
	check(back != null, "it restores")
	if back == null:
		return
	back.collect_events = false
	var again: SimEntity = back.get_entity(target.id)
	check(again != null and SimCombat.is_burning(back, again), "the fire is still burning after loading")
	SimTestUtil.run(w, 20 * 30)
	SimTestUtil.run(back, 20 * 30)
	check_eq(back.state_hash(), w.state_hash(), "and the match continues identically")
