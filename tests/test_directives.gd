extends TestCase
## Command Points, Directives and veterancy.


func _world() -> SimWorld:
	var w: SimWorld = SimTestUtil.make_world(8, 64)
	w.spawn_building("hq", 0, w.map.cell_of(w.players[0].start_pos) - Vector2i(2, 2), true)
	w.spawn_building("hq", 1, w.map.cell_of(w.players[1].start_pos) - Vector2i(2, 2), true)
	SimSignal.recompute(w)
	SimVision.recompute(w)
	w.signal_next_tick = 0
	w.vision_next_tick = 0
	return w


func _grant(w: SimWorld, player_id: int, id: String) -> DirectiveDef:
	w.players[player_id].unlocked[id] = true
	return w.data.directive(id)


func test_directive_data() -> void:
	var data: GameData = GameData.shared()
	check_eq(data.directives.size(), 6, "six Directives")
	check_eq(data.directive_order.size(), 6, "bar order recorded")
	for id: String in ["recon_sweep", "shell_barrage", "field_repair", "signal_surge", "blackout", "reinforcement_drop"]:
		check(data.directive(id) != null, "%s defined" % id)


func test_kills_earn_command_points_and_unlock() -> void:
	var w: SimWorld = _world()
	var p: SimPlayer = w.players[0]
	var start: int = p.command_points
	var victim: SimEntity = w.spawn_unit("bulwark", 1, Vector2(60, 60))
	var value: int = victim.def.cost
	SimCombat.kill(w, victim, null, 0)
	check_eq(p.command_points, start + value / w.data.command_point_value, "value destroyed converts to Command Points")
	p.command_points = 3
	w.push_command(SimCommand.unlock(0, "shell_barrage"))
	SimTestUtil.run(w, 2)
	check(p.unlocked.has("shell_barrage"), "unlocked")
	check_eq(p.command_points, 0, "points were spent")
	w.push_command(SimCommand.unlock(0, "blackout"))
	SimTestUtil.run(w, 2)
	check(not p.unlocked.has("blackout"), "cannot unlock without points")


func test_locked_or_cooling_directive_is_refused() -> void:
	var w: SimWorld = _world()
	var def: DirectiveDef = w.data.directive("recon_sweep")
	check(SimDirectives.use_error(w, 0, def, Vector2(90, 90)) != "", "locked Directive refused")
	_grant(w, 0, "recon_sweep")
	check_eq(SimDirectives.use_error(w, 0, def, Vector2(90, 90)), "", "unlocked Directive allowed")
	w.push_command(SimCommand.directive(0, "recon_sweep", Vector2(90, 90)))
	SimTestUtil.run(w, 2)
	check(SimDirectives.cooldown_left(w, 0, def) > def.cooldown - 1.0, "cooldown started")
	check(SimDirectives.use_error(w, 0, def, Vector2(90, 90)) != "", "refused while cooling down")
	SimTestUtil.run(w, int(def.cooldown * 20.0) + 5)
	check_eq(SimDirectives.use_error(w, 0, def, Vector2(90, 90)), "", "ready again after the cooldown")


func test_recon_sweep_reveals_then_expires() -> void:
	var w: SimWorld = _world()
	var def: DirectiveDef = _grant(w, 0, "recon_sweep")
	var spot: Vector2 = Vector2(80, 40)
	check(not SimVision.is_visible(w, 0, spot), "hidden before")
	w.push_command(SimCommand.directive(0, "recon_sweep", spot))
	SimTestUtil.run(w, 8)
	check(SimVision.is_visible(w, 0, spot), "revealed")
	check(SimVision.is_visible(w, 0, spot + Vector2(def.radius - 3.0, 0)), "out to its radius")
	SimTestUtil.run(w, int(def.duration * 20.0) + 10)
	check(not SimVision.is_visible(w, 0, spot), "hidden again after 20 s")
	check(SimVision.is_explored(w, 0, spot), "but stays explored")


func test_shell_barrage_needs_coverage_and_hurts() -> void:
	var w: SimWorld = _world()
	var def: DirectiveDef = _grant(w, 0, "shell_barrage")
	var hq_pos: Vector2 = w.players[0].start_pos
	check(SimDirectives.target_error(w, 0, def, hq_pos + Vector2(70, 60)) != "", "far from coverage is refused")
	var near: Vector2 = hq_pos + Vector2(38, 0)  # 10 outside the HQ radius
	check_eq(SimDirectives.target_error(w, 0, def, near), "", "within 15 of coverage is allowed")
	# Unarmed vehicles on both sides, so only the barrage can hurt anyone.
	var victims: Array[SimEntity] = SimTestUtil.spawn_group(w, "hauler", 1, near - Vector2(2, 2), 4)
	var friend: SimEntity = w.spawn_unit("hauler", 0, near)
	w.push_command(SimCommand.directive(0, "shell_barrage", near))
	SimTestUtil.run(w, 20 * 7)
	var hurt: int = 0
	for v: SimEntity in victims:
		if not v.alive or v.hp < v.max_hp:
			hurt += 1
	check(hurt >= 3, "barrage hit the enemy group (%d of 4)" % hurt)
	check_near(friend.hp, friend.max_hp, 0.01, "no friendly fire")


func test_field_repair_heals_own_only_in_coverage() -> void:
	var w: SimWorld = _world()
	var def: DirectiveDef = _grant(w, 0, "field_repair")
	var hq_pos: Vector2 = w.players[0].start_pos
	check(SimDirectives.target_error(w, 0, def, hq_pos + Vector2(60, 0)) != "", "outside coverage is refused")
	var mine: SimEntity = w.spawn_unit("bulwark", 0, hq_pos + Vector2(14, 0))
	var theirs: SimEntity = w.spawn_unit("bulwark", 1, hq_pos + Vector2(16, 3))
	mine.hp = 100.0
	theirs.hp = 100.0
	w.push_command(SimCommand.hold(1, PackedInt32Array([theirs.id])))
	w.push_command(SimCommand.directive(0, "field_repair", hq_pos + Vector2(14, 0)))
	w.tick()
	w.tick()
	check(mine.hp >= 100.0 + mine.max_hp * def.heal_fraction - 60.0, "own unit healed (hp %.0f)" % mine.hp)
	check(theirs.hp <= 100.0, "enemy unit not healed")


func test_signal_surge_grows_coverage_temporarily() -> void:
	var w: SimWorld = _world()
	var def: DirectiveDef = _grant(w, 0, "signal_surge")
	var hq_pos: Vector2 = w.players[0].start_pos
	var edge: Vector2 = hq_pos + Vector2(36, 0)
	check(not SimSignal.is_covered(w, 0, edge), "36 out is uncovered normally")
	w.push_command(SimCommand.directive(0, "signal_surge", Vector2.ZERO))
	SimTestUtil.run(w, 12)
	check(SimSignal.is_covered(w, 0, edge), "surge extends coverage to 42")
	SimTestUtil.run(w, int(def.duration * 20.0) + 15)
	check(not SimSignal.is_covered(w, 0, edge), "coverage returns to normal afterwards")


func test_blackout_removes_enemy_coverage_temporarily() -> void:
	var w: SimWorld = _world()
	var def: DirectiveDef = _grant(w, 0, "blackout")
	var enemy_hq: Vector2 = w.players[1].start_pos
	var spot: Vector2 = enemy_hq + Vector2(-16, 0)
	check(SimDirectives.target_error(w, 0, def, spot) != "", "cannot target what we cannot see")
	w.add_reveal(spot, 20.0, 0, -1)
	SimVision.recompute(w)
	check_eq(SimDirectives.target_error(w, 0, def, spot), "", "revealed area can be targeted")
	var tank: SimEntity = w.spawn_unit("bulwark", 1, spot)
	w.push_command(SimCommand.hold(1, PackedInt32Array([tank.id])))
	SimTestUtil.run(w, 8)
	check(tank.linked, "enemy unit is Linked in its own base")
	w.push_command(SimCommand.directive(0, "blackout", spot))
	SimTestUtil.run(w, 12)
	check(not SimSignal.is_covered(w, 1, spot), "enemy coverage removed in the area")
	check(not tank.linked, "enemy unit there goes Dark")
	check(SimSignal.is_covered(w, 1, enemy_hq + Vector2(0, -20)), "coverage outside the disc is untouched")
	SimTestUtil.run(w, int(def.duration * 20.0) + 15)
	check(SimSignal.is_covered(w, 1, spot), "coverage returns when the Blackout ends")
	check(tank.linked, "and the unit is Linked again")


func test_reinforcement_drop_delivers_squad() -> void:
	var w: SimWorld = _world()
	var def: DirectiveDef = _grant(w, 0, "reinforcement_drop")
	var hq_pos: Vector2 = w.players[0].start_pos
	var at: Vector2 = hq_pos + Vector2(14, 6)
	var before: int = w.count_units(0)
	w.push_command(SimCommand.directive(0, "reinforcement_drop", at))
	SimTestUtil.run(w, 10)
	check_eq(w.count_units(0), before, "nothing yet during the delay")
	SimTestUtil.run(w, int(def.duration * 20.0) + 5)
	var squad_size: int = w.players[0].faction.drop_squad.size()
	check_eq(w.count_units(0), before + squad_size, "squad delivered")
	var close: int = 0
	for e: SimEntity in w.entities:
		if e.owner == 0 and e.kind == SimEntity.Kind.UNIT and e.pos.distance_to(at) < 6.0:
			close += 1
	check_eq(close, squad_size, "squad arrives at the target")


func test_veterancy_ranks() -> void:
	var w: SimWorld = _world()
	var tank: SimEntity = w.spawn_unit("bulwark", 0, Vector2(60, 60))
	check_eq(tank.rank, 0, "starts unranked")
	var kills_needed: int = 0
	while tank.rank < 1 and kills_needed < 20:
		var v: SimEntity = w.spawn_unit("bulwark", 1, Vector2(90, 90))
		SimCombat.kill(w, v, tank, 0)
		kills_needed += 1
	check_eq(kills_needed, 2, "rank 1 after destroying twice its own cost")
	check_near(tank.max_hp, tank.def.hp * 1.1, 0.01, "+10% health at rank 1")
	for i: int in 8:
		var v: SimEntity = w.spawn_unit("bulwark", 1, Vector2(90, 90))
		SimCombat.kill(w, v, tank, 0)
	check_eq(tank.rank, 3, "three ranks at most")
	check_near(tank.max_hp, tank.def.hp * 1.3, 0.01, "+30% health at rank 3")
	tank.hp = tank.max_hp * 0.5
	SimTestUtil.run(w, 20 * 20)
	check(tank.hp > tank.max_hp * 0.5 + 10.0, "top rank self-repairs when left alone (%.0f)" % tank.hp)
