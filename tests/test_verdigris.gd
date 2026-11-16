extends TestCase
## The Verdigris Order: few, costly, heavily armored units that take less
## damage while Linked and fire far slower when Dark.


func _world() -> SimWorld:
	var config: MatchConfig = MatchConfig.skirmish(6)
	config.map_cells = SimMapGen.SMALL_CELLS
	config.factions = ["verdigris", "aegis"]
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


func test_the_order_starts_with_its_own_base() -> void:
	var w: SimWorld = _world()
	check_eq(w.players[0].faction.name, "Verdigris Order", "the faction is loaded")
	check_eq(_own(w, 0, "keep").size(), 1, "Keep placed")
	check_eq(_own(w, 0, "mason").size(), 2, "two masons")
	check_eq(_own(w, 0, "dray").size(), 2, "two drays")
	check_eq(_own(w, 0, "vigil").size(), 2, "two vigils")
	SimTestUtil.run(w, 20 * 60)
	check(w.players[0].stat_salvage_collected > 0, "drays harvest on their own")


func test_everything_the_order_owns_can_be_made() -> void:
	var data: GameData = GameData.shared()
	var made: Dictionary[String, bool] = {}
	var built: Dictionary[String, bool] = {}
	for def: EntityDef in data.entities.values():
		if def.faction != "verdigris":
			continue
		for id: String in def.produces:
			made[id] = true
			check(data.entity(id).faction == "verdigris", "%s produces only Order units (%s)" % [def.name, id])
		for id: String in def.builds:
			built[id] = true
			check(data.entity(id).faction == "verdigris", "%s builds only Order buildings (%s)" % [def.name, id])
	var count: int = 0
	for def: EntityDef in data.entities.values():
		if def.faction != "verdigris":
			continue
		count += 1
		if def.is_building:
			check(built.has(def.id) or def.id == "keep", "%s can be built by a Mason" % def.name)
		else:
			check(made.has(def.id), "%s is produced somewhere" % def.name)
	check_eq(count, 17, "nine units and eight buildings")
	var f: FactionDef = data.faction("verdigris")
	for role: String in ["builder", "hauler", "relay", "barracks", "works", "depot", "turret_ground", "turret_armor", "turret_air", "tier3"]:
		check(data.entities.has(f.role(role)), "the AI has a %s (%s)" % [role, f.role(role)])


func _hit(w: SimWorld, e: SimEntity, amount: float) -> float:
	var before: float = e.hp
	SimCombat.apply_damage(w, e, amount, GameData.DAMAGE_TYPES.find("ballistic"), null, 1 - e.owner)
	return before - e.hp


## What a ballistic hit should cost this entity before any faction rule.
func _plain(w: SimWorld, e: SimEntity, amount: float) -> float:
	var mult: float = w.data.damage_multiplier(GameData.DAMAGE_TYPES.find("ballistic"), e.def.armor)
	if e.def.is_infantry() and w.map.terrain_at(e.pos) == SimMap.Terrain.FOREST:
		mult *= w.data.forest_infantry_damage_mult
	return amount * mult


func test_linked_knights_take_less_damage() -> void:
	var w: SimWorld = _world()
	var keep: SimEntity = _own(w, 0, "keep")[0]
	var toward: Vector2 = (w.map.world_size() * 0.5 - keep.pos).normalized()
	var near: SimEntity = w.spawn_unit("vigil", 0, w.map.nearest_free_pos(keep.pos + toward * 9.0))
	var far: SimEntity = w.spawn_unit("vigil", 0, w.map.nearest_free_pos(keep.pos + toward * 44.0))
	SimTestUtil.run(w, 3)
	check(near.linked and not far.linked, "one knight is Linked and one is Dark")
	var far_lost: float = _hit(w, far, 40.0)
	check(absf(far_lost - _plain(w, far, 40.0)) < 0.01, "the Dark knight takes the full hit (%.1f)" % far_lost)
	var near_lost: float = _hit(w, near, 40.0)
	check(absf(near_lost - _plain(w, near, 40.0) * 0.85) < 0.01, "the Linked knight takes 15%% less (%.1f)" % near_lost)
	# Other factions and the Order's own buildings get nothing.
	var trooper: SimEntity = _own(w, 1, "trooper")[0]
	check(trooper.linked, "the Aegis trooper is Linked")
	check(absf(_hit(w, trooper, 40.0) - _plain(w, trooper, 40.0)) < 0.01, "and still takes the full hit")
	check(absf(_hit(w, keep, 40.0) - _plain(w, keep, 40.0)) < 0.01, "the Keep itself gets no reduction")


func test_dark_knights_fire_far_slower() -> void:
	var w: SimWorld = _world()
	var keep: SimEntity = _own(w, 0, "keep")[0]
	var toward: Vector2 = (w.map.world_size() * 0.5 - keep.pos).normalized()
	var far: SimEntity = w.spawn_unit("vigil", 0, w.map.nearest_free_pos(keep.pos + toward * 44.0))
	SimTestUtil.run(w, 3)
	check(not far.linked, "the knight is Dark")
	var rate: float = SimCombat.rof_mult(w, far)
	check(rate < w.data.dark_rof_mult, "a Dark knight fires at %.2f of its rate, worse than the usual %.2f" % [rate, w.data.dark_rof_mult])


func test_the_ai_plays_the_order() -> void:
	var config: MatchConfig = MatchConfig.ai_vs_ai(9)
	config.map_cells = SimMapGen.SMALL_CELLS
	config.factions = ["verdigris", "aegis"]
	var w: SimWorld = SimSetup.create_match(config)
	SimTestUtil.run(w, 20 * 60 * 6)
	check(_own(w, 0, "chapterhouse").size() >= 1, "the AI built a Chapterhouse")
	check(_own(w, 0, "lantern").size() >= 1, "and extended its grid with a Lantern")
	check(w.players[0].stat_salvage_collected > 500, "and collected salvage")
	var army: int = 0
	for e: SimEntity in w.entities:
		if e.alive and e.owner == 0 and e.kind == SimEntity.Kind.UNIT and e.def.is_armed():
			army += 1
	check(army + w.players[0].stat_units_lost >= 6, "and raised an army (%d alive, %d lost)" % [army, w.players[0].stat_units_lost])
