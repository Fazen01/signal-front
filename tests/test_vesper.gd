extends TestCase
## The Vesper Array: cheap drone frames that are quicker while Linked and
## keep nearly all of their rate of fire when Dark.


func _world() -> SimWorld:
	var config: MatchConfig = MatchConfig.skirmish(6)
	config.map_cells = SimMapGen.SMALL_CELLS
	config.factions = ["vesper", "aegis"]
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


func test_the_array_starts_with_its_own_base() -> void:
	var w: SimWorld = _world()
	check_eq(w.players[0].faction.name, "Vesper Array", "the faction is loaded")
	check_eq(_own(w, 0, "nexus").size(), 1, "Nexus placed")
	check_eq(_own(w, 0, "weaver").size(), 2, "two weavers")
	check_eq(_own(w, 0, "porter").size(), 2, "two porters")
	check_eq(_own(w, 0, "mote").size(), 3, "three motes")
	check_eq(_own(w, 1, "hq").size(), 1, "the Aegis player keeps its own HQ")
	SimTestUtil.run(w, 20 * 60)
	check(w.players[0].stat_salvage_collected > 0, "porters harvest on their own")


func test_everything_the_array_owns_can_be_made() -> void:
	var data: GameData = GameData.shared()
	var made: Dictionary[String, bool] = {}
	var built: Dictionary[String, bool] = {}
	for def: EntityDef in data.entities.values():
		if def.faction != "vesper":
			continue
		for id: String in def.produces:
			made[id] = true
			check(data.entity(id).faction == "vesper", "%s produces only Array units (%s)" % [def.name, id])
		for id: String in def.builds:
			built[id] = true
			check(data.entity(id).faction == "vesper", "%s builds only Array buildings (%s)" % [def.name, id])
	var count: int = 0
	for def: EntityDef in data.entities.values():
		if def.faction != "vesper":
			continue
		count += 1
		if def.is_building:
			check(built.has(def.id) or def.id == "nexus", "%s can be built by a Weaver" % def.name)
		else:
			check(made.has(def.id), "%s is produced somewhere" % def.name)
	check_eq(count, 17, "ten units (the Tether is the tenth) and seven buildings")
	var f: FactionDef = data.faction("vesper")
	for role: String in ["builder", "hauler", "relay", "barracks", "works", "depot", "turret_ground", "turret_armor", "turret_air", "tier3"]:
		check(data.entities.has(f.role(role)), "the AI has a %s (%s)" % [role, f.role(role)])


func test_linked_frames_move_faster() -> void:
	var w: SimWorld = _world()
	var nexus: SimEntity = _own(w, 0, "nexus")[0]
	var toward: Vector2 = (w.map.world_size() * 0.5 - nexus.pos).normalized()
	# One mote well inside coverage, one far outside it, both walking the same way.
	var near: SimEntity = w.spawn_unit("mote", 0, w.map.nearest_free_pos(nexus.pos + toward * 9.0))
	var far: SimEntity = w.spawn_unit("mote", 0, w.map.nearest_free_pos(nexus.pos + toward * 44.0))
	SimTestUtil.run(w, 3)
	check(near.linked, "the near mote is Linked")
	check(not far.linked, "the far mote is Dark")
	var side: Vector2 = Vector2(-toward.y, toward.x)
	var near_from: Vector2 = near.pos
	var far_from: Vector2 = far.pos
	w.push_command(SimCommand.move(0, PackedInt32Array([near.id]), near.pos + side * 12.0))
	w.push_command(SimCommand.move(0, PackedInt32Array([far.id]), far.pos + side * 12.0))
	SimTestUtil.run(w, 40)
	var near_went: float = near.pos.distance_to(near_from)
	var far_went: float = far.pos.distance_to(far_from)
	check(far_went > 3.0, "the Dark mote moved (%.1f)" % far_went)
	check(near_went > far_went * 1.08, "the Linked mote went further in the same time (%.1f against %.1f)" % [near_went, far_went])
	check(near_went < far_went * 1.25, "but only by about 15%")
	# Other factions get no such bonus.
	var trooper: SimEntity = _own(w, 1, "trooper")[0]
	check_eq(w.players[1].faction.linked_speed_bonus, 0.0, "Aegis has no speed bonus")
	check(trooper.linked, "the trooper is Linked")


func test_dark_frames_keep_nearly_all_their_rate_of_fire() -> void:
	var w: SimWorld = _world()
	var nexus: SimEntity = _own(w, 0, "nexus")[0]
	var toward: Vector2 = (w.map.world_size() * 0.5 - nexus.pos).normalized()
	var far: SimEntity = w.spawn_unit("mote", 0, w.map.nearest_free_pos(nexus.pos + toward * 44.0))
	var hq: SimEntity = _own(w, 1, "hq")[0]
	var lost: SimEntity = w.spawn_unit("trooper", 1, w.map.nearest_free_pos(hq.pos - toward * 44.0))
	SimTestUtil.run(w, 3)
	check(not far.linked and not lost.linked, "both are Dark")
	var mine: float = SimCombat.rof_mult(w, far)
	var theirs: float = SimCombat.rof_mult(w, lost)
	check(mine > 0.9 and mine < 1.0, "a Dark frame fires at %.2f of its rate" % mine)
	check(mine > theirs + 0.2, "far better than a Dark Aegis trooper (%.2f)" % theirs)


func test_the_ai_plays_the_array() -> void:
	var config: MatchConfig = MatchConfig.ai_vs_ai(9)
	config.map_cells = SimMapGen.SMALL_CELLS
	config.factions = ["vesper", "aegis"]
	var w: SimWorld = SimSetup.create_match(config)
	SimTestUtil.run(w, 20 * 60 * 6)
	check(_own(w, 0, "cradle").size() >= 1, "the AI built a Cradle")
	check(_own(w, 0, "spire").size() >= 1, "and extended its grid with a Spire")
	check(w.players[0].stat_salvage_collected > 500, "and collected salvage")
	var army: int = 0
	for e: SimEntity in w.entities:
		if e.alive and e.owner == 0 and e.kind == SimEntity.Kind.UNIT and e.def.is_armed():
			army += 1
	check(army + w.players[0].stat_units_lost >= 8, "and raised an army (%d alive, %d lost)" % [army, w.players[0].stat_units_lost])
