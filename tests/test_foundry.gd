extends TestCase
## The Foundry Pact: Pylons, the Crawler, mines, repair and faction traits.


func _world() -> SimWorld:
	var config: MatchConfig = MatchConfig.skirmish(6)
	config.factions = ["foundry", "aegis"]
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


func test_foundry_starts_with_its_own_base() -> void:
	var w: SimWorld = _world()
	check_eq(_own(w, 0, "foundry_core").size(), 1, "Foundry Core placed")
	check_eq(_own(w, 0, "sapper").size(), 2, "two sappers")
	check_eq(_own(w, 0, "scow").size(), 2, "two scows")
	check_eq(_own(w, 1, "hq").size(), 1, "the Aegis player keeps its own HQ")
	SimTestUtil.run(w, 20 * 60)
	check(w.players[0].stat_salvage_collected > 0, "scows harvest on their own")


func test_factions_cannot_build_each_others_buildings() -> void:
	var w: SimWorld = _world()
	var cell: Vector2i = w.map.cell_of(w.players[0].start_pos) + Vector2i(6, 0)
	check(SimEconomy.can_place(w, 0, w.data.entity("muster_hall"), cell), "Foundry can place a Muster Hall")
	check(not SimEconomy.can_place(w, 0, w.data.entity("barracks"), cell), "Foundry cannot place an Aegis Barracks")


func test_pylons_are_short_range_cheap_and_tough() -> void:
	var data: GameData = GameData.shared()
	var pylon: EntityDef = data.entity("pylon")
	var relay: EntityDef = data.entity("relay")
	check(pylon.cost < relay.cost, "cheaper than a relay")
	check(pylon.hp > relay.hp, "tougher than a relay")
	check(pylon.signal_radius < relay.signal_radius, "shorter radius")
	var w: SimWorld = _world()
	var hq: SimEntity = _own(w, 0, "foundry_core")[0]
	var a: SimEntity = w.spawn_building("pylon", 0, w.map.cell_of(hq.pos + Vector2(28, 0)), true)
	var b: SimEntity = w.spawn_building("pylon", 0, w.map.cell_of(hq.pos + Vector2(28, 10)), true)
	SimTestUtil.run(w, 8)
	check(a.linked and b.linked, "pylons link like relays")
	check_eq(w.players[0].bandwidth_cap, 30, "two pylons add 10 bandwidth")
	check(SimSignal.is_covered(w, 0, a.pos + Vector2(8, 0)), "pylon projects a small disc")
	check(not SimSignal.is_covered(w, 0, a.pos + Vector2(14, 0)), "which ends at radius 11")


func test_crawler_deploys_and_packs() -> void:
	var w: SimWorld = _world()
	var hq: SimEntity = _own(w, 0, "foundry_core")[0]
	var crawler: SimEntity = w.spawn_unit("crawler", 0, hq.pos + Vector2(12, 0))
	var used: int = w.players[0].bandwidth_used
	var cell: Vector2i = w.map.cell_of(hq.pos + Vector2(16, 4))
	w.push_command(SimCommand.deploy(0, PackedInt32Array([crawler.id]), cell))
	SimTestUtil.run(w, 20 * 12)
	var factories: Array[SimEntity] = _own(w, 0, "crawler_factory")
	check_eq(factories.size(), 1, "crawler became a factory")
	check(not crawler.alive, "the unit is gone")
	check_eq(w.players[0].bandwidth_used, used - crawler.def.bandwidth, "its bandwidth is released")
	if factories.is_empty():
		return
	var factory: SimEntity = factories[0]
	check(not w.map.is_cell_passable(cell), "the factory blocks its footprint")
	check_eq(SimEconomy.train_error(w, factory, w.data.entity("tusk")), "", "the factory builds vehicles")
	w.push_command(SimCommand.train(0, factory.id, "tusk"))
	SimTestUtil.run(w, 3)
	var before: int = w.players[0].salvage
	w.push_command(SimCommand.pack(0, factory.id))
	SimTestUtil.run(w, 3)
	check(not factory.alive, "factory packed up")
	check_eq(_own(w, 0, "crawler").size(), 1, "and is a crawler again")
	check(w.map.is_cell_passable(cell), "footprint freed")
	check_eq(w.players[0].salvage, before + w.data.entity("tusk").cost, "queued unit refunded on packing")


func test_crawler_cannot_deploy_outside_coverage() -> void:
	var w: SimWorld = _world()
	var hq: SimEntity = _own(w, 0, "foundry_core")[0]
	var crawler: SimEntity = w.spawn_unit("crawler", 0, hq.pos + Vector2(40, 0))
	var cell: Vector2i = w.map.cell_of(hq.pos + Vector2(42, 0))
	check(SimEconomy.deploy_error(w, 0, crawler.def, cell).contains("coverage"), "refused outside coverage")
	w.push_command(SimCommand.deploy(0, PackedInt32Array([crawler.id]), cell))
	SimTestUtil.run(w, 20 * 6)
	check(crawler.alive, "crawler stays a unit")
	check_eq(_own(w, 0, "crawler_factory").size(), 0, "no factory")


func test_mine_is_hidden_and_explodes_under_ground_units() -> void:
	var w: SimWorld = _world()
	var spot: Vector2 = w.map.world_size() * 0.5
	w.map.set_terrain(w.map.cell_of(spot), SimMap.Terrain.GROUND)
	var mine: SimEntity = w.spawn_building("mine", 0, w.map.cell_of(spot), true)
	check(w.map.is_cell_passable(w.map.cell_of(mine.pos)), "a mine does not block movement")
	w.add_reveal(spot, 20.0, 1, -1)
	SimVision.recompute(w)
	check(not SimVision.can_see(w, 1, mine), "the enemy cannot see it from afar")
	var drone: SimEntity = w.spawn_unit("scout_drone", 1, mine.pos + Vector2(0.5, 0))
	SimTestUtil.run(w, 6)
	check(mine.alive, "aircraft do not set it off")
	check(SimVision.can_see(w, 1, mine), "but a unit right on top of it spots it")
	SimCombat.kill(w, drone, null, -1)
	var truck: SimEntity = w.spawn_unit("hauler", 1, mine.pos + Vector2(8, 0))
	w.push_command(SimCommand.move(1, PackedInt32Array([truck.id]), mine.pos - Vector2(8, 0)))
	SimTestUtil.run(w, 20 * 6)
	check(not mine.alive, "the mine went off")
	check(truck.hp < truck.max_hp - 80.0 or not truck.alive, "and hurt the truck badly (hp %.0f)" % truck.hp)
	var wrecks: int = 0
	for e: SimEntity in w.entities:
		if e.kind == SimEntity.Kind.WRECK and e.pos.distance_to(mine.pos) < 0.5:
			wrecks += 1
	check_eq(wrecks, 0, "a mine leaves no wreck")


func test_mines_can_be_laid_outside_coverage() -> void:
	var w: SimWorld = _world()
	var far: Vector2i = w.map.cell_of(w.map.world_size() * 0.5)
	w.map.set_terrain(far, SimMap.Terrain.GROUND)
	check(SimEconomy.can_place(w, 0, w.data.entity("mine"), far), "mines do not need coverage")
	check(not SimEconomy.can_place(w, 0, w.data.entity("muster_hall"), far), "buildings still do")


func test_linked_foundry_vehicles_self_repair() -> void:
	var w: SimWorld = _world()
	var hq: SimEntity = _own(w, 0, "foundry_core")[0]
	var inside: SimEntity = w.spawn_unit("tusk", 0, hq.pos + Vector2(12, 4))
	var outside: SimEntity = w.spawn_unit("tusk", 0, hq.pos + Vector2(44, 30))
	var aegis_tank: SimEntity = w.spawn_unit("bulwark", 1, w.players[1].start_pos + Vector2(-12, 0))
	inside.hp = 200.0
	outside.hp = 200.0
	aegis_tank.hp = 200.0
	SimTestUtil.run(w, 20 * 12)
	check(inside.hp > 240.0, "Linked Foundry vehicle repairs itself (%.0f)" % inside.hp)
	check_near(outside.hp, 200.0, 0.01, "a Dark one does not")
	check_near(aegis_tank.hp, 200.0, 0.01, "nor do other factions' vehicles")


func test_ratchet_repairs_nearby_vehicles_and_buildings() -> void:
	var w: SimWorld = _world()
	var far: Vector2 = w.players[0].start_pos + Vector2(46, 34)
	w.map.set_terrain(w.map.cell_of(far), SimMap.Terrain.GROUND)
	w.spawn_unit("ratchet", 0, far)
	var hurt: SimEntity = w.spawn_unit("tusk", 0, far + Vector2(4, 0))
	var soldier: SimEntity = w.spawn_unit("levy", 0, far + Vector2(0, 3))
	hurt.hp = 100.0
	soldier.hp = 20.0
	SimTestUtil.run(w, 20 * 6)
	check(hurt.hp > 150.0, "ratchet repaired the vehicle (%.0f)" % hurt.hp)
	check_near(soldier.hp, 20.0, 0.01, "it does not heal infantry")
