extends TestCase
## Weapons, damage, projectiles, death, wrecks and combat orders.


func test_damage_uses_armor_table() -> void:
	var w: SimWorld = SimTestUtil.make_world()
	var tank: SimEntity = w.spawn_unit("bulwark", 1, Vector2(20, 20))
	var man: SimEntity = w.spawn_unit("trooper", 1, Vector2(30, 20))
	var ballistic: int = GameData.DAMAGE_TYPES.find("ballistic")
	SimCombat.apply_damage(w, tank, 100.0, ballistic, null, 0)
	SimCombat.apply_damage(w, man, 10.0, ballistic, null, 0)
	var heavy: int = w.data.armor_classes.find("heavy")
	var inf: int = w.data.armor_classes.find("infantry")
	check_near(tank.def.hp - tank.hp, 100.0 * w.data.damage_multiplier(ballistic, heavy), 0.01, "heavy armor")
	check_near(man.def.hp - man.hp, 10.0 * w.data.damage_multiplier(ballistic, inf), 0.01, "infantry armor")


func test_forest_protects_infantry() -> void:
	var w: SimWorld = SimTestUtil.make_world()
	w.map.set_terrain(w.map.cell_of(Vector2(21, 21)), SimMap.Terrain.FOREST)
	w.map.finalize()
	var covered: SimEntity = w.spawn_unit("trooper", 1, Vector2(21, 21))
	var open: SimEntity = w.spawn_unit("trooper", 1, Vector2(31, 21))
	var ballistic: int = GameData.DAMAGE_TYPES.find("ballistic")
	SimCombat.apply_damage(w, covered, 20.0, ballistic, null, 0)
	SimCombat.apply_damage(w, open, 20.0, ballistic, null, 0)
	var lost_covered: float = covered.def.hp - covered.hp
	var lost_open: float = open.def.hp - open.hp
	check_near(lost_covered, lost_open * w.data.forest_infantry_damage_mult, 0.01, "forest cover")


func test_units_auto_engage_and_kill() -> void:
	var w: SimWorld = SimTestUtil.make_world()
	var a: Array[SimEntity] = SimTestUtil.spawn_group(w, "trooper", 0, Vector2(20, 20), 4)
	var b: SimEntity = w.spawn_unit("trooper", 1, Vector2(26, 21))
	SimTestUtil.run(w, 20 * 15)
	check(not b.alive, "outnumbered trooper dies")
	check(SimTestUtil.alive_units(w, 0) >= 3, "most of the squad survives")
	check(w.players[0].stat_kills >= 1, "kill credited")
	check(a[0].alive or a[1].alive, "squad alive")


func test_vehicle_leaves_wreck_infantry_does_not() -> void:
	var w: SimWorld = SimTestUtil.make_world()
	var tank: SimEntity = w.spawn_unit("bulwark", 1, Vector2(20, 20))
	var man: SimEntity = w.spawn_unit("trooper", 1, Vector2(30, 30))
	SimCombat.kill(w, tank, null, 0)
	SimCombat.kill(w, man, null, 0)
	w.tick()
	var wrecks: Array[SimEntity] = []
	for e: SimEntity in w.entities:
		if e.kind == SimEntity.Kind.WRECK:
			wrecks.append(e)
	check_eq(wrecks.size(), 1, "exactly one wreck")
	if wrecks.size() == 1:
		check_eq(wrecks[0].salvage, int(float(tank.def.cost) * w.data.wreck_fraction), "wreck is worth 25% of cost")
		check(wrecks[0].pos.distance_to(Vector2(20, 20)) < 0.01, "wreck where the tank died")


func test_projectile_weapons_hit() -> void:
	var w: SimWorld = SimTestUtil.make_world()
	var lancer: SimEntity = w.spawn_unit("lancer", 0, Vector2(20, 20))
	var tank: SimEntity = w.spawn_unit("hauler", 1, Vector2(28, 20))
	var saw_projectile: bool = false
	for i: int in 20 * 8:
		w.tick()
		if w.projectiles.size() > 0:
			saw_projectile = true
	check(saw_projectile, "missile was in flight")
	check(tank.hp < tank.max_hp, "missile did damage")
	check(lancer.alive, "lancer unharmed by unarmed hauler")


func test_attack_order_chases_target() -> void:
	var w: SimWorld = SimTestUtil.make_world()
	var tank: SimEntity = w.spawn_unit("bulwark", 0, Vector2(10, 10))
	var prey: SimEntity = w.spawn_unit("hauler", 1, Vector2(45, 45))
	w.push_command(SimCommand.attack(0, PackedInt32Array([tank.id]), prey.id))
	SimTestUtil.run(w, 20 * 40)
	check(not prey.alive, "target destroyed")
	check(tank.pos.distance_to(Vector2(10, 10)) > 20.0, "tank closed the distance")
	check(tank.orders.is_empty(), "attack order finished")


func test_attack_move_fights_on_the_way() -> void:
	var w: SimWorld = SimTestUtil.make_world()
	var squad: Array[SimEntity] = SimTestUtil.spawn_group(w, "warden", 0, Vector2(8, 30), 3)
	var guard: SimEntity = w.spawn_unit("trooper", 1, Vector2(30, 31))
	w.push_command(SimCommand.attack_move(0, SimTestUtil.ids_of(squad), Vector2(54, 30)))
	SimTestUtil.run(w, 20 * 40)
	check(not guard.alive, "enemy on the route was killed")
	var centre: Vector2 = Vector2.ZERO
	for e: SimEntity in squad:
		centre += e.pos
	centre /= 3.0
	check(centre.distance_to(Vector2(54, 30)) < 4.0, "squad continued to the destination (%s)" % str(centre))


func test_plain_move_does_not_chase() -> void:
	var w: SimWorld = SimTestUtil.make_world()
	var scout: SimEntity = w.spawn_unit("courser", 0, Vector2(8, 30))
	w.spawn_unit("hauler", 1, Vector2(30, 44))
	w.push_command(SimCommand.move(0, PackedInt32Array([scout.id]), Vector2(54, 30)))
	SimTestUtil.run(w, 20 * 12)
	check(scout.pos.distance_to(Vector2(54, 30)) < 0.5, "scout went straight to its destination")


func test_hold_position_does_not_chase() -> void:
	var w: SimWorld = SimTestUtil.make_world()
	var tank: SimEntity = w.spawn_unit("bulwark", 0, Vector2(20, 20))
	w.spawn_unit("hauler", 1, Vector2(20.0 + 13.5, 20))  # in sight, out of range
	w.push_command(SimCommand.hold(0, PackedInt32Array([tank.id])))
	SimTestUtil.run(w, 20 * 6)
	check(tank.pos.distance_to(Vector2(20, 20)) < 0.01, "holding unit did not move")
	check(tank.hold, "hold flag set")


func test_mixed_squads_fight_to_deterministic_result() -> void:
	var first: Array[int] = _run_battle(99)
	var second: Array[int] = _run_battle(99)
	check_eq(first, second, "same seed, same battle")
	check(first[1] == 0 or first[2] == 0, "one side was wiped out (blue %d, red %d)" % [first[1], first[2]])
	check(first[1] > 0 or first[2] > 0, "somebody survived")
	check(first[3] > 0, "wrecks were left behind")


## Returns [state hash, blue units left, red units left, wreck count].
func _run_battle(seed_value: int) -> Array[int]:
	var w: SimWorld = SimTestUtil.make_world(seed_value, 40)
	var blue: Array[SimEntity] = []
	blue.append_array(SimTestUtil.spawn_group(w, "trooper", 0, Vector2(14, 30), 6))
	blue.append_array(SimTestUtil.spawn_group(w, "lancer", 0, Vector2(14, 40), 3))
	blue.append_array(SimTestUtil.spawn_group(w, "bulwark", 0, Vector2(8, 34), 2))
	var red: Array[SimEntity] = []
	red.append_array(SimTestUtil.spawn_group(w, "trooper", 1, Vector2(62, 30), 4))
	red.append_array(SimTestUtil.spawn_group(w, "warden", 1, Vector2(62, 40), 3))
	red.append_array(SimTestUtil.spawn_group(w, "courser", 1, Vector2(68, 34), 2))
	w.push_command(SimCommand.attack_move(0, SimTestUtil.ids_of(blue), Vector2(64, 36)))
	w.push_command(SimCommand.attack_move(1, SimTestUtil.ids_of(red), Vector2(12, 36)))
	var ticks: int = 0
	while ticks < 20 * 240 and SimTestUtil.alive_units(w, 0) > 0 and SimTestUtil.alive_units(w, 1) > 0:
		w.tick()
		ticks += 1
	var wrecks: int = 0
	for e: SimEntity in w.entities:
		if e.kind == SimEntity.Kind.WRECK:
			wrecks += 1
	return [w.state_hash(), SimTestUtil.alive_units(w, 0), SimTestUtil.alive_units(w, 1), wrecks]
