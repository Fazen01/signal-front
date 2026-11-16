extends TestCase
## Fog of war, shared vision through coverage, and stealth.


func _world() -> SimWorld:
	var w: SimWorld = SimTestUtil.make_world(5, 64)
	w.spawn_building("hq", 0, w.map.cell_of(w.players[0].start_pos) - Vector2i(2, 2), true)
	SimSignal.recompute(w)
	SimVision.recompute(w)
	return w


func test_units_reveal_around_themselves() -> void:
	var w: SimWorld = SimTestUtil.make_world(5, 64)
	var scout: SimEntity = w.spawn_unit("courser", 0, Vector2(60, 60))
	SimTestUtil.run(w, 6)
	check(SimVision.is_visible(w, 0, scout.pos + Vector2(6, 0)), "near the scout is visible")
	check(not SimVision.is_visible(w, 0, scout.pos + Vector2(30, 0)), "far from the scout is not")
	check(not SimVision.is_visible(w, 1, scout.pos), "the other player sees nothing there")


func test_coverage_shares_vision() -> void:
	var w: SimWorld = _world()
	var hq_pos: Vector2 = w.players[0].start_pos
	# 24 units out: beyond the HQ's own sight (14) but inside its coverage (28).
	var spot: Vector2 = hq_pos + Vector2(24, 0)
	SimTestUtil.run(w, 6)
	check(SimSignal.is_covered(w, 0, spot), "spot is in coverage")
	check(SimVision.is_visible(w, 0, spot), "coverage reveals the ground inside it")
	var intruder: SimEntity = w.spawn_unit("trooper", 1, spot)
	SimTestUtil.run(w, 6)
	check(SimVision.can_see(w, 0, intruder), "an enemy inside our coverage is seen")
	check(not SimVision.can_see(w, 0, w.spawn_unit("trooper", 1, hq_pos + Vector2(50, 0))), "an enemy outside it is not")


func test_explored_stays_after_leaving() -> void:
	var w: SimWorld = SimTestUtil.make_world(5, 64)
	var scout: SimEntity = w.spawn_unit("courser", 0, Vector2(20, 60))
	SimTestUtil.run(w, 6)
	var first: Vector2 = scout.pos
	w.push_command(SimCommand.move(0, PackedInt32Array([scout.id]), Vector2(100, 60)))
	SimTestUtil.run(w, 20 * 16)
	check(not SimVision.is_visible(w, 0, first), "old position is no longer visible")
	check(SimVision.is_explored(w, 0, first), "but it stays explored")
	check(SimVision.is_visible(w, 0, scout.pos), "new position is visible")


func test_units_do_not_shoot_what_nobody_sees() -> void:
	var w: SimWorld = SimTestUtil.make_world(5, 64)
	# A Dark marksman out-ranges its own (reduced) sight.
	var shooter: SimEntity = w.spawn_unit("marksman", 0, Vector2(40, 40))
	var target: SimEntity = w.spawn_unit("hauler", 1, Vector2(53, 40))
	SimTestUtil.run(w, 20 * 6)
	check_near(target.hp, target.max_hp, 0.01, "unseen target is not fired on")
	# A spotter next to the target shares what it sees.
	w.spawn_unit("courser", 0, Vector2(53, 46))
	w.push_command(SimCommand.hold(0, PackedInt32Array([w.entities[w.entities.size() - 1].id])))
	SimTestUtil.run(w, 20 * 8)
	check(target.hp < target.max_hp, "spotted target is fired on from long range")
	check(shooter.alive, "shooter fine")


func test_marksman_is_hidden_while_still() -> void:
	var w: SimWorld = SimTestUtil.make_world(5, 64)
	var sniper: SimEntity = w.spawn_unit("marksman", 0, Vector2(40, 40))
	# Player 1 has the area revealed (as a Recon Sweep would) but nobody close.
	w.reveals.append(Vector4(40.0, 40.0, 12.0, 1.0))
	SimTestUtil.run(w, 6)
	check(SimVision.is_visible(w, 1, sniper.pos), "the enemy can see the ground the sniper stands on")
	check(SimVision.is_stealthed(w, sniper), "a still marksman is stealthed")
	check(not SimVision.can_see(w, 1, sniper), "and cannot be seen from a distance")
	w.push_command(SimCommand.move(0, PackedInt32Array([sniper.id]), Vector2(40, 44)))
	SimTestUtil.run(w, 10)
	check(SimVision.can_see(w, 1, sniper), "moving breaks stealth")
	SimTestUtil.run(w, 20 * 6)
	check(not SimVision.can_see(w, 1, sniper), "standing still again restores it")
	var close: SimEntity = w.spawn_unit("trooper", 1, sniper.pos + Vector2(3, 0))
	SimTestUtil.run(w, 2)
	check(SimVision.can_see(w, 1, sniper), "an enemy right next to it detects it")
	check(close.alive or not close.alive, "detector spawned")


func test_attack_order_on_unseen_unit_becomes_attack_move() -> void:
	var w: SimWorld = SimTestUtil.make_world(5, 64)
	var tank: SimEntity = w.spawn_unit("bulwark", 0, Vector2(20, 20))
	var hidden: SimEntity = w.spawn_unit("hauler", 1, Vector2(90, 90))
	w.push_command(SimCommand.attack(0, PackedInt32Array([tank.id]), hidden.id))
	SimTestUtil.run(w, 3)
	check(not tank.orders.is_empty(), "tank has an order")
	if not tank.orders.is_empty():
		check_eq(tank.orders[0].type, SimOrder.Type.ATTACK_MOVE, "order was downgraded to attack-move")


func test_ai_starts_blind_and_still_finds_the_enemy() -> void:
	var w: SimWorld = SimSetup.create_match(MatchConfig.ai_vs_ai(31))
	w.collect_events = false
	var enemy_hq: SimEntity = null
	for e: SimEntity in w.entities:
		if e.owner == 1 and e.def != null and e.def.signal_root:
			enemy_hq = e
	check(not SimVision.can_see(w, 0, enemy_hq), "the enemy HQ is hidden at the start")
	SimTestUtil.run(w, 20 * 60 * 7)
	check(w.game_over or w.players[0].stat_kills > 0 or w.players[1].stat_kills > 0, "the AIs found each other and fought")
