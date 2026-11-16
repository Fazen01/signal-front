extends TestCase
## The Nomad Circuit: Beacon Rigs, the relocating HQ, jammers, forest cloak,
## hijacking and wreck salvage.


func _world() -> SimWorld:
	var config: MatchConfig = MatchConfig.skirmish(6)
	# The spots used below were picked on the compact map's terrain.
	config.map_cells = SimMapGen.SMALL_CELLS
	config.factions = ["nomad", "aegis"]
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


func test_beacon_rig_deploys_within_link_range_and_packs() -> void:
	var w: SimWorld = _world()
	var hub: SimEntity = _own(w, 0, "caravan_hub")[0]
	var rig: SimEntity = _own(w, 0, "beacon_rig")[0]
	var out: Vector2 = hub.pos + (w.map.world_size() * 0.5 - hub.pos).normalized() * 29.0
	var cell: Vector2i = w.map.cell_of(w.map.nearest_free_pos(out))
	check(not SimSignal.is_covered(w, 0, w.map.cell_center(cell)), "the spot is outside coverage")
	check_eq(SimEconomy.deploy_error(w, 0, rig.def, cell), "", "a rig may deploy outside coverage within link range")
	var too_far: Vector2i = w.map.cell_of(hub.pos + (w.map.world_size() * 0.5 - hub.pos).normalized() * 40.0)
	check(SimEconomy.deploy_error(w, 0, rig.def, too_far) != "", "but not beyond link range")
	w.push_command(SimCommand.deploy(0, PackedInt32Array([rig.id]), cell))
	SimTestUtil.run(w, 20 * 25)
	var beacons: Array[SimEntity] = _own(w, 0, "beacon")
	check_eq(beacons.size(), 1, "rig became a beacon")
	if beacons.is_empty():
		return
	SimTestUtil.run(w, 8)
	check(beacons[0].linked, "the beacon links to the hub")
	check(SimSignal.is_covered(w, 0, beacons[0].pos + Vector2(10, 0).rotated(0.3)), "and projects coverage")
	check_eq(w.players[0].bandwidth_cap, 20 + beacons[0].def.bandwidth_provided, "a beacon adds its bandwidth")
	w.push_command(SimCommand.pack(0, beacons[0].id))
	SimTestUtil.run(w, 8)
	check_eq(_own(w, 0, "beacon_rig").size(), 1, "it packs back into a rig")
	check_eq(w.players[0].bandwidth_cap, 20, "and the bandwidth goes with it")


func test_headquarters_can_relocate() -> void:
	var w: SimWorld = _world()
	var hub: SimEntity = _own(w, 0, "caravan_hub")[0]
	var soldier: SimEntity = _own(w, 0, "drifter")[0]
	SimTestUtil.run(w, 6)
	check(soldier.linked, "units are Linked while the hub stands")
	w.push_command(SimCommand.pack(0, hub.id))
	SimTestUtil.run(w, 12)
	var caravans: Array[SimEntity] = _own(w, 0, "caravan")
	check_eq(caravans.size(), 1, "the hub packed into a caravan")
	check(not w.players[0].defeated and not w.game_over, "a moving headquarters is not a defeat")
	check(not soldier.linked, "everything is Dark while the headquarters moves")
	check_eq(w.players[0].bandwidth_cap, 0, "and there is no bandwidth")
	if caravans.is_empty():
		return
	var spot: Vector2 = w.map.nearest_free_pos(hub.pos + (w.map.world_size() * 0.5 - hub.pos).normalized() * 34.0)
	var cell: Vector2i = w.map.cell_of(spot) - Vector2i(2, 2)
	for y: int in range(cell.y, cell.y + 4):
		for x: int in range(cell.x, cell.x + 4):
			w.map.set_terrain(Vector2i(x, y), SimMap.Terrain.GROUND)
	w.map.finalize()
	w.push_command(SimCommand.deploy(0, PackedInt32Array([caravans[0].id]), cell))
	SimTestUtil.run(w, 20 * 50)
	var hubs: Array[SimEntity] = _own(w, 0, "caravan_hub")
	check_eq(hubs.size(), 1, "the caravan redeployed as a hub")
	if hubs.size() == 1:
		check(hubs[0].pos.distance_to(hub.pos) > 20.0, "in a new place")
		check(SimSignal.is_covered(w, 0, hubs[0].pos + Vector2(10, 0)), "and the network is back")
		check_eq(w.players[0].bandwidth_cap, 20, "with its bandwidth")


func test_losing_the_caravan_loses_the_match() -> void:
	var w: SimWorld = _world()
	var hub: SimEntity = _own(w, 0, "caravan_hub")[0]
	w.push_command(SimCommand.pack(0, hub.id))
	SimTestUtil.run(w, 12)
	SimCombat.kill(w, _own(w, 0, "caravan")[0], null, 1)
	SimTestUtil.run(w, 12)
	check(w.players[0].defeated, "destroying the caravan defeats its owner")
	check_eq(w.winner, 1, "the other side wins")


func test_jammer_removes_enemy_coverage_around_it() -> void:
	var w: SimWorld = _world()
	var enemy_hq: SimEntity = _own(w, 1, "hq")[0]
	var spot: Vector2 = w.map.nearest_free_pos(enemy_hq.pos + (w.map.world_size() * 0.5 - enemy_hq.pos).normalized() * 14.0)
	var defender: SimEntity = w.spawn_unit("bulwark", 1, spot + Vector2(2, 0))
	w.push_command(SimCommand.hold(1, PackedInt32Array([defender.id])))
	SimTestUtil.run(w, 8)
	check(defender.linked, "defender is Linked at home")
	var jammer: SimEntity = w.spawn_unit("jammer_buggy", 0, spot)
	jammer.hp = 100000.0
	jammer.max_hp = 100000.0
	SimTestUtil.run(w, 12)
	check(not SimSignal.is_covered(w, 1, spot), "the jammer wipes enemy coverage around itself")
	check(not defender.linked, "the defender goes Dark")
	check(SimSignal.is_covered(w, 1, enemy_hq.pos - (w.map.world_size() * 0.5 - enemy_hq.pos).normalized() * 12.0), "coverage away from the jammer is untouched")
	check(SimSignal.is_covered(w, 0, w.players[0].start_pos), "it does not jam its own side")
	SimCombat.kill(w, jammer, null, 1)
	SimTestUtil.run(w, 12)
	check(defender.linked, "coverage returns when the jammer dies")


func test_nomads_cloak_when_still_in_forest() -> void:
	var w: SimWorld = _world()
	var spot: Vector2 = w.map.world_size() * 0.5
	var open: Vector2 = spot + Vector2(0, 6)
	w.map.set_terrain(w.map.cell_of(spot), SimMap.Terrain.FOREST)
	w.map.set_terrain(w.map.cell_of(open), SimMap.Terrain.GROUND)
	w.map.finalize()
	var hidden: SimEntity = w.spawn_unit("drifter", 0, w.map.cell_center(w.map.cell_of(spot)))
	var exposed: SimEntity = w.spawn_unit("drifter", 0, w.map.cell_center(w.map.cell_of(open)))
	var aegis_in_forest: SimEntity = w.spawn_unit("trooper", 1, hidden.pos + Vector2(0.6, 0.0))
	w.add_reveal(spot, 20.0, 1, -1)
	w.add_reveal(spot, 20.0, 0, -1)
	SimVision.recompute(w)
	# Nobody has fired yet at tick 0: stealth applies straight away.
	check(SimVision.is_stealthed(w, hidden), "a still Nomad in forest is cloaked")
	check(not SimVision.is_stealthed(w, exposed), "one in the open is not")
	check(not SimVision.is_stealthed(w, aegis_in_forest), "other factions do not cloak")
	SimCombat.kill(w, aegis_in_forest, null, -1)
	w.tick()
	var far_enemy: SimEntity = w.spawn_unit("scout_drone", 1, spot + Vector2(9, 0))
	check(not SimVision.can_see(w, 1, hidden), "the enemy cannot see the cloaked unit from 9 away")
	check(SimVision.can_see(w, 1, exposed), "but sees the exposed one")
	check(far_enemy.alive, "observer alive")


func test_splicer_hijacks_a_dark_vehicle() -> void:
	var w: SimWorld = _world()
	var mid: Vector2 = w.map.nearest_free_pos(w.map.world_size() * 0.5)
	var tank: SimEntity = w.spawn_unit("bulwark", 1, mid)
	var splicer: SimEntity = w.spawn_unit("splicer", 0, w.map.nearest_free_pos(mid + Vector2(5, 0)))
	splicer.hp = 100000.0
	splicer.max_hp = 100000.0
	w.push_command(SimCommand.hold(1, PackedInt32Array([tank.id])))
	SimTestUtil.run(w, 6)
	check(not tank.linked, "the tank is Dark in the middle of the map")
	check_eq(SimEconomy.hijack_error(w, splicer, tank), "", "a Dark vehicle can be hijacked")
	var used_before: int = w.players[1].bandwidth_used
	w.push_command(SimCommand.capture(0, PackedInt32Array([splicer.id]), tank.id))
	SimTestUtil.run(w, 20 * 12)
	check_eq(tank.owner, 0, "the tank changed sides")
	check(not splicer.alive, "the splicer is used up")
	check_eq(w.players[1].bandwidth_used, used_before - tank.def.bandwidth, "the old owner's bandwidth is freed")
	check(tank.orders.is_empty(), "the tank's old orders are gone")


func test_linked_vehicles_cannot_be_hijacked() -> void:
	var w: SimWorld = _world()
	var enemy_hq: SimEntity = _own(w, 1, "hq")[0]
	var tank: SimEntity = w.spawn_unit("bulwark", 1, w.map.nearest_free_pos(enemy_hq.pos + Vector2(-12, 0)))
	var splicer: SimEntity = w.spawn_unit("splicer", 0, tank.pos + Vector2(-3, 0))
	w.add_reveal(tank.pos, 10.0, 0, -1)
	SimTestUtil.run(w, 6)
	check(tank.linked, "the tank is Linked at home")
	check(SimEconomy.hijack_error(w, splicer, tank).contains("Dark"), "refused: the vehicle is not Dark")
	var trooper: SimEntity = w.spawn_unit("trooper", 1, w.map.nearest_free_pos(w.map.world_size() * 0.5))
	check(SimEconomy.hijack_error(w, splicer, trooper) != "", "infantry cannot be hijacked")


func test_nomads_get_more_from_wrecks() -> void:
	var w: SimWorld = _world()
	var hub: SimEntity = _own(w, 0, "caravan_hub")[0]
	var wreck: SimEntity = w.spawn_wreck(w.map.nearest_free_pos(hub.pos + Vector2(12, 12)), 60, 1.0, "bulwark", 0.0)
	var skiff: SimEntity = _own(w, 0, "skiff")[0]
	var before: int = w.players[0].salvage
	w.push_command(SimCommand.harvest(0, PackedInt32Array([skiff.id]), wreck.id))
	var ticks: int = 0
	var fullest: int = 0
	while wreck.alive and ticks < 20 * 60:
		w.tick()
		ticks += 1
		fullest = maxi(fullest, skiff.cargo)
	while skiff.cargo > 0 and ticks < 20 * 100:
		w.tick()
		ticks += 1
		fullest = maxi(fullest, skiff.cargo)
	check(w.players[0].salvage - before >= 90, "60 salvage of wreck pays 90 to a Nomad (got %d)" % (w.players[0].salvage - before))
	check(fullest <= skiff.def.capacity, "and the Skiff never carries more than it can hold (%d of %d)" % [fullest, skiff.def.capacity])
