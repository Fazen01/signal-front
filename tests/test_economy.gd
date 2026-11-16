extends TestCase
## Harvesting, construction, production and bandwidth.


func _world_with_hq() -> SimWorld:
	var w: SimWorld = SimTestUtil.make_world(3, 40)
	for p: SimPlayer in w.players:
		SimSetup.place_base(w, p)
		p.salvage = 1000
	SimSignal.recompute(w)
	w.signal_next_tick = 0
	return w


func _own(w: SimWorld, owner: int, def_id: String) -> Array[SimEntity]:
	var out: Array[SimEntity] = []
	for e: SimEntity in w.entities:
		if e.alive and e.owner == owner and e.def != null and e.def.id == def_id:
			out.append(e)
	return out


func test_hauler_harvests_field_and_delivers() -> void:
	var w: SimWorld = _world_with_hq()
	var field: SimEntity = w.spawn_field(w.players[0].start_pos + Vector2(16, 4), 250)
	var hauler: SimEntity = _own(w, 0, "hauler")[0]
	var before: int = w.players[0].salvage
	w.push_command(SimCommand.harvest(0, PackedInt32Array([hauler.id]), field.id))
	SimTestUtil.run(w, 20 * 30)
	check(w.players[0].salvage >= before + 100, "at least one load delivered (%d)" % (w.players[0].salvage - before))
	check(field.salvage < 250, "field was depleted a little")
	SimTestUtil.run(w, 20 * 60)
	check_eq(w.players[0].salvage, before + 250, "the whole field was collected, nothing lost")
	check(not field.alive, "empty field is removed")
	check_eq(w.players[0].stat_salvage_collected, 250, "collection stat")
	check(hauler.orders.is_empty(), "hauler goes idle when nothing is left")


func test_haulers_collect_wrecks() -> void:
	var w: SimWorld = _world_with_hq()
	var wreck: SimEntity = w.spawn_wreck(w.players[0].start_pos + Vector2(14, 0), 95, 1.0, "bulwark", 0.0)
	var hauler: SimEntity = _own(w, 0, "hauler")[0]
	var before: int = w.players[0].salvage
	w.push_command(SimCommand.harvest(0, PackedInt32Array([hauler.id]), wreck.id))
	SimTestUtil.run(w, 20 * 30)
	check_eq(w.players[0].salvage, before + 95, "wreck salvage delivered")
	check(not wreck.alive, "wreck consumed")


func test_wrecks_decay() -> void:
	var w: SimWorld = SimTestUtil.make_world()
	var wreck: SimEntity = w.spawn_wreck(Vector2(20, 20), 50, 1.0, "hauler", 0.0)
	SimTestUtil.run(w, int(w.data.wreck_decay_seconds * 20.0) + 5)
	check(not wreck.alive, "wreck decays")


func test_builder_constructs_building() -> void:
	var w: SimWorld = _world_with_hq()
	var eng: SimEntity = _own(w, 0, "field_engineer")[0]
	var cell: Vector2i = w.map.cell_of(w.players[0].start_pos) + Vector2i(6, -1)
	var before: int = w.players[0].salvage
	w.push_command(SimCommand.build(0, PackedInt32Array([eng.id]), "barracks", cell))
	SimTestUtil.run(w, 2)
	var sites: Array[SimEntity] = _own(w, 0, "barracks")
	check_eq(sites.size(), 1, "construction site placed")
	if sites.is_empty():
		return
	var site: SimEntity = sites[0]
	check(not site.constructed, "starts unfinished")
	check_eq(w.players[0].salvage, before - site.def.cost, "cost paid up front")
	check(not w.map.is_cell_passable(cell), "footprint blocks movement")
	check(not w.players[0].has_building("barracks"), "does not count for tech until finished")
	SimTestUtil.run(w, int((site.def.build_time + 12.0) * 20.0))
	check(site.constructed, "construction finished (progress %.2f)" % site.build_progress)
	check_near(site.hp, site.max_hp, 1.0, "finished building has full health")
	check(w.players[0].has_building("barracks"), "counts for tech once finished")
	check(eng.orders.is_empty(), "builder is idle afterwards")


func test_two_builders_are_faster_but_not_double() -> void:
	var one: int = _ticks_to_build(1)
	var two: int = _ticks_to_build(2)
	check(two < one, "two builders are faster (%d vs %d ticks)" % [two, one])
	check(float(two) > float(one) * 0.55, "but with diminishing returns")


func _ticks_to_build(builders: int) -> int:
	var w: SimWorld = _world_with_hq()
	var engs: Array[SimEntity] = _own(w, 0, "field_engineer")
	var ids: PackedInt32Array = PackedInt32Array()
	for i: int in builders:
		ids.append(engs[i].id)
	var cell: Vector2i = w.map.cell_of(w.players[0].start_pos) + Vector2i(6, -1)
	w.push_command(SimCommand.build(0, ids, "relay", cell))
	var ticks: int = 0
	while ticks < 20 * 120:
		w.tick()
		ticks += 1
		var done: Array[SimEntity] = _own(w, 0, "relay")
		if done.size() == 1 and done[0].constructed:
			break
	return ticks


func test_cancel_building_refunds() -> void:
	var w: SimWorld = _world_with_hq()
	var eng: SimEntity = _own(w, 0, "field_engineer")[0]
	var cell: Vector2i = w.map.cell_of(w.players[0].start_pos) + Vector2i(6, -1)
	var before: int = w.players[0].salvage
	w.push_command(SimCommand.build(0, PackedInt32Array([eng.id]), "depot", cell))
	SimTestUtil.run(w, 40)
	var site: SimEntity = _own(w, 0, "depot")[0]
	w.push_command(SimCommand.cancel_building(0, site.id))
	SimTestUtil.run(w, 2)
	check(not site.alive, "site removed")
	check_eq(w.players[0].salvage, before, "full refund")
	check(w.map.is_cell_passable(cell), "footprint freed")


func test_placement_rules() -> void:
	var w: SimWorld = _world_with_hq()
	var def: EntityDef = w.data.entity("barracks")
	var hq_cell: Vector2i = w.map.cell_of(w.players[0].start_pos)
	check(not SimEconomy.can_place(w, 0, def, hq_cell), "cannot build on the HQ")
	check(not SimEconomy.can_place(w, 0, def, Vector2i(-1, 5)), "cannot build off the map")
	w.map.set_terrain(hq_cell + Vector2i(8, 0), SimMap.Terrain.FOREST)
	check(not SimEconomy.can_place(w, 0, def, hq_cell + Vector2i(7, -1)), "cannot build on forest")
	check(SimEconomy.can_place(w, 0, def, hq_cell + Vector2i(4, 4)), "open ground near the HQ is fine")
	var works: EntityDef = w.data.entity("vehicle_works")
	check(not SimEconomy.can_place(w, 0, works, hq_cell + Vector2i(4, 4)), "tech requirement enforced")
	check(SimEconomy.placement_error(w, 0, works, hq_cell + Vector2i(4, 4)).contains("Barracks"), "error names the requirement")


func test_cannot_build_without_salvage() -> void:
	var w: SimWorld = _world_with_hq()
	w.players[0].salvage = 50
	var eng: SimEntity = _own(w, 0, "field_engineer")[0]
	var cell: Vector2i = w.map.cell_of(w.players[0].start_pos) + Vector2i(6, -1)
	w.push_command(SimCommand.build(0, PackedInt32Array([eng.id]), "barracks", cell))
	SimTestUtil.run(w, 3)
	check_eq(_own(w, 0, "barracks").size(), 0, "no site without funds")
	check_eq(w.players[0].salvage, 50, "nothing charged")


func test_production_queue_and_rally() -> void:
	var w: SimWorld = _world_with_hq()
	var hq: SimEntity = _own(w, 0, "hq")[0]
	var rally: Vector2 = hq.pos + Vector2(14, 6)
	w.push_command(SimCommand.rally(0, hq.id, rally))
	var before_units: int = w.count_units(0)
	var before: int = w.players[0].salvage
	for i: int in 3:
		w.push_command(SimCommand.train(0, hq.id, "field_engineer"))
	SimTestUtil.run(w, 2)
	check_eq(hq.queue.size(), 3, "three queued")
	check_eq(w.players[0].salvage, before - 3 * w.data.entity("field_engineer").cost, "paid on queueing")
	w.push_command(SimCommand.cancel_train(0, hq.id, 2))
	SimTestUtil.run(w, 2)
	check_eq(hq.queue.size(), 2, "one cancelled")
	check_eq(w.players[0].salvage, before - 2 * w.data.entity("field_engineer").cost, "cancel refunds")
	SimTestUtil.run(w, int(w.data.entity("field_engineer").build_time * 2.0 * 20.0) + 20 * 12)
	check_eq(w.count_units(0), before_units + 2, "two units delivered")
	check(hq.queue.is_empty(), "queue drained")
	var newest: SimEntity = w.entities[w.entities.size() - 1]
	check(newest.pos.distance_to(rally) < 4.0, "new unit walked to the rally point (%s)" % str(newest.pos))


func test_queue_limit_and_requirements() -> void:
	var w: SimWorld = _world_with_hq()
	w.players[0].salvage = 100000
	var hq: SimEntity = _own(w, 0, "hq")[0]
	for i: int in 9:
		w.push_command(SimCommand.train(0, hq.id, "field_engineer"))
	SimTestUtil.run(w, 2)
	check_eq(hq.queue.size(), w.data.queue_max, "queue is capped")
	w.push_command(SimCommand.train(0, hq.id, "bulwark"))
	SimTestUtil.run(w, 2)
	check(not hq.queue.has("bulwark"), "HQ cannot build tanks")
	check(SimEconomy.train_error(w, hq, w.data.entity("bulwark")) != "", "train_error explains")


func test_bandwidth_cap_blocks_production() -> void:
	var w: SimWorld = _world_with_hq()
	var p: SimPlayer = w.players[0]
	p.salvage = 100000
	check_eq(p.bandwidth_cap, 20, "HQ provides 20 bandwidth")
	var hq: SimEntity = _own(w, 0, "hq")[0]
	# Fill the cap exactly, then queue one more.
	while p.bandwidth_used < p.bandwidth_cap:
		w.spawn_unit("trooper", 0, hq.pos + Vector2(12, 12))
	w.push_command(SimCommand.train(0, hq.id, "field_engineer"))
	var at_cap: int = w.count_units(0)
	SimTestUtil.run(w, 20 * 20)
	check_eq(w.count_units(0), at_cap, "no unit delivered over the cap")
	check_eq(hq.queue.size(), 1, "order waits in the queue")
	# A relay raises the cap and production resumes.
	w.spawn_building("relay", 0, w.map.cell_of(hq.pos) + Vector2i(5, 5), true)
	SimTestUtil.run(w, 20 * 3)
	check_eq(p.bandwidth_cap, 30, "relay adds 10 bandwidth")
	check_eq(w.count_units(0), at_cap + 1, "production resumes under the new cap")


func test_new_hauler_goes_to_work_on_its_own() -> void:
	var w: SimWorld = _world_with_hq()
	var hq: SimEntity = _own(w, 0, "hq")[0]
	w.spawn_field(hq.pos + Vector2(15, 5), 3000)
	var before: int = w.players[0].stat_salvage_collected
	w.push_command(SimCommand.train(0, hq.id, "hauler"))
	SimTestUtil.run(w, 20 * 50)
	check(w.players[0].stat_salvage_collected > before, "fresh hauler started harvesting without orders")


func test_match_setup_economy_runs() -> void:
	var w: SimWorld = SimSetup.create_match(MatchConfig.skirmish(4))
	var start: int = w.players[0].salvage
	SimTestUtil.run(w, 20 * 60)
	check(w.players[0].salvage > start, "starting haulers earn salvage in the first minute (%d)" % (w.players[0].salvage - start))
	check_eq(w.players[0].salvage, w.players[1].salvage, "mirrored starts earn the same")


func test_hotkeys_do_not_clash() -> void:
	var data: GameData = GameData.shared()
	var reserved: Array[String] = ["W", "A", "S", "D", "Q", "E", "G", "H"]
	for def: EntityDef in data.entities.values():
		if def.hotkey != "":
			check(not reserved.has(def.hotkey), "%s uses reserved key %s" % [def.id, def.hotkey])
		for list: Array[String] in [def.builds, def.produces]:
			var seen: Array[String] = []
			for id: String in list:
				var key: String = data.entity(id).hotkey
				check(key != "", "%s needs a hotkey" % id)
				check(not seen.has(key), "%s: hotkey %s used twice in one card" % [def.id, key])
				seen.append(key)
