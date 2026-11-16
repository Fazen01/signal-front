extends TestCase
## The Signal Grid: link chains, coverage, Linked/Dark effects, placement.


## A 64x64-cell blank world with player 0's HQ at its start and no other units.
func _world() -> SimWorld:
	var w: SimWorld = SimTestUtil.make_world(5, 64)
	w.spawn_building("hq", 0, w.map.cell_of(w.players[0].start_pos) - Vector2i(2, 2), true)
	SimSignal.recompute(w)
	w.signal_next_tick = 0
	return w


func _relay(w: SimWorld, at: Vector2) -> SimEntity:
	var r: SimEntity = w.spawn_building("relay", 0, w.map.cell_of(at), true)
	return r


func _hq(w: SimWorld) -> SimEntity:
	for e: SimEntity in w.entities:
		if e.def != null and e.def.signal_root and e.owner == 0:
			return e
	return null


func test_hq_projects_coverage() -> void:
	var w: SimWorld = _world()
	var hq: SimEntity = _hq(w)
	check(hq.linked, "the HQ is always linked")
	check(SimSignal.is_covered(w, 0, hq.pos + Vector2(20, 0)), "inside the HQ radius is covered")
	check(not SimSignal.is_covered(w, 0, hq.pos + Vector2(34, 0)), "outside the HQ radius is not")
	check(not SimSignal.is_covered(w, 1, hq.pos), "coverage is per player")
	check_eq(w.players[0].bandwidth_cap, 20, "HQ bandwidth")


func test_relay_chain_extends_coverage() -> void:
	var w: SimWorld = _world()
	var hq: SimEntity = _hq(w)
	var a: SimEntity = _relay(w, hq.pos + Vector2(28, 0))
	var b: SimEntity = _relay(w, hq.pos + Vector2(56, 0))
	var c: SimEntity = _relay(w, hq.pos + Vector2(84, 0))
	SimTestUtil.run(w, 8)
	check(a.linked and b.linked and c.linked, "the whole chain is linked")
	check(SimSignal.is_covered(w, 0, c.pos + Vector2(12, 0)), "far relay projects coverage")
	check_eq(w.players[0].bandwidth_cap, 50, "three relays add 30 bandwidth")
	check_eq(w.signal_links[0].size(), 6, "three links recorded")


func test_cutting_mid_chain_relay_unlinks_downstream() -> void:
	var w: SimWorld = _world()
	var hq: SimEntity = _hq(w)
	var a: SimEntity = _relay(w, hq.pos + Vector2(28, 0))
	var b: SimEntity = _relay(w, hq.pos + Vector2(56, 0))
	var c: SimEntity = _relay(w, hq.pos + Vector2(84, 0))
	var far_unit: SimEntity = w.spawn_unit("bulwark", 0, c.pos + Vector2(6, 6))
	var near_unit: SimEntity = w.spawn_unit("bulwark", 0, hq.pos + Vector2(12, 6))
	var far_shop: SimEntity = w.spawn_building("barracks", 0, w.map.cell_of(c.pos) + Vector2i(-1, 3), true)
	SimTestUtil.run(w, 8)
	check(far_unit.linked and near_unit.linked, "both units linked before the cut")
	check(far_shop.linked, "far building linked before the cut")
	w.events.clear()
	SimCombat.kill(w, a, null, 1)
	SimTestUtil.run(w, 8)
	check(not b.linked, "relay after the cut is unlinked")
	check(not c.linked, "relay two hops after the cut is unlinked")
	check(not SimSignal.is_covered(w, 0, c.pos), "unlinked relays project nothing")
	check(not far_unit.linked, "unit downstream goes Dark")
	check(near_unit.linked, "unit near the HQ stays Linked")
	check(not far_shop.linked, "building downstream goes Dark")
	check_eq(w.players[0].bandwidth_cap, 20, "unlinked relays give no bandwidth")
	var alerted: bool = false
	for ev: SimEvent in w.events:
		if ev.type == SimEvent.Type.ALERT and ev.player == 0 and ev.text.contains("Blackout"):
			alerted = true
	check(alerted, "owner gets a blackout alert")
	# Rebuilding the missing link restores everything.
	_relay(w, hq.pos + Vector2(28, 2))
	SimTestUtil.run(w, 8)
	check(b.linked and c.linked, "chain restored by a replacement relay")
	check(far_unit.linked, "downstream unit is Linked again")
	check_eq(w.players[0].bandwidth_cap, 50, "bandwidth restored")


func test_unfinished_relay_does_not_emit() -> void:
	var w: SimWorld = _world()
	var hq: SimEntity = _hq(w)
	var site: SimEntity = w.spawn_building("relay", 0, w.map.cell_of(hq.pos + Vector2(28, 0)), false)
	SimTestUtil.run(w, 8)
	check(not site.linked, "construction site is not linked")
	check(not SimSignal.is_covered(w, 0, site.pos + Vector2(10, 0)), "and projects nothing")


func test_dark_units_fight_worse() -> void:
	var w: SimWorld = _world()
	var hq: SimEntity = _hq(w)
	var inside: SimEntity = w.spawn_unit("trooper", 0, hq.pos + Vector2(12, 0))
	var outside: SimEntity = w.spawn_unit("trooper", 0, hq.pos + Vector2(60, 40))
	SimTestUtil.run(w, 2)
	check(inside.linked, "unit in coverage is Linked")
	check(not outside.linked, "unit outside coverage is Dark")
	check_near(SimCombat.rof_mult(w, inside), 1.0, 0.001, "Linked rate of fire")
	check(SimCombat.rof_mult(w, outside) <= 0.7, "Dark rate of fire is cut by at least 30%")
	check_near(SimCombat.sight_range(w, outside), outside.def.sight * 0.7, 0.01, "Dark sight is cut by 30%")
	check(SimCombat.range_mult(w, inside) > SimCombat.range_mult(w, outside), "Aegis range bonus only when Linked")
	var turret: SimEntity = w.spawn_building("sentry_turret", 0, w.map.cell_of(hq.pos + Vector2(60, 44)), true)
	SimTestUtil.run(w, 2)
	check(not turret.linked, "turret outside coverage is Dark")
	check_near(SimCombat.rof_mult(w, turret), 0.5, 0.001, "Dark turret fires at half rate")


func test_dark_building_pauses_production() -> void:
	var w: SimWorld = _world()
	var hq: SimEntity = _hq(w)
	var shop: SimEntity = w.spawn_building("barracks", 0, w.map.cell_of(hq.pos + Vector2(36, 0)), true)
	SimTestUtil.run(w, 2)
	check(not shop.linked, "barracks outside coverage is Dark")
	w.push_command(SimCommand.train(0, shop.id, "trooper"))
	var before: int = w.count_units(0)
	SimTestUtil.run(w, 20 * 12)
	check_eq(w.count_units(0), before, "Dark barracks produced nothing")
	check_near(shop.prod_progress, 0.0, 0.001, "production did not advance")
	_relay(w, hq.pos + Vector2(28, 0))
	SimTestUtil.run(w, 20 * 9)
	check(shop.linked, "a relay brings it back online")
	check_eq(w.count_units(0), before + 1, "production resumed")


func test_placement_needs_coverage_and_link_range() -> void:
	var w: SimWorld = _world()
	var hq: SimEntity = _hq(w)
	var barracks: EntityDef = w.data.entity("barracks")
	var relay: EntityDef = w.data.entity("relay")
	var inside: Vector2i = w.map.cell_of(hq.pos + Vector2(14, 0))
	var outside: Vector2i = w.map.cell_of(hq.pos + Vector2(40, 0))
	check(SimEconomy.can_place(w, 0, barracks, inside), "building inside coverage is allowed")
	check(not SimEconomy.can_place(w, 0, barracks, outside), "building outside coverage is refused")
	check(SimEconomy.placement_error(w, 0, barracks, outside).contains("coverage"), "error mentions coverage")
	var just_out: Vector2i = w.map.cell_of(hq.pos + Vector2(29, 0))
	check(not SimSignal.is_covered(w, 0, w.map.cell_center(just_out)), "29 units out is beyond the HQ radius")
	check(SimEconomy.can_place(w, 0, relay, just_out), "relay may sit outside coverage within link range")
	check(not SimEconomy.can_place(w, 0, relay, w.map.cell_of(hq.pos + Vector2(36, 0))), "relay beyond link range is refused")
	check(not SimEconomy.can_place(w, 1, relay, just_out), "another player cannot use this network")


func test_recompute_is_rate_limited() -> void:
	var w: SimWorld = _world()
	var hq: SimEntity = _hq(w)
	SimTestUtil.run(w, 6)
	var version: int = w.coverage_version
	for i: int in 4:
		_relay(w, hq.pos + Vector2(10.0 + float(i) * 4.0, 16))
		w.tick()
	check(w.coverage_version - version <= 2, "at most one rebuild per 5 ticks (%d)" % (w.coverage_version - version))
	SimTestUtil.run(w, 6)
	check_eq(w.players[0].bandwidth_cap, 60, "all four relays counted in the end")
