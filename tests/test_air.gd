extends TestCase
## Tier 3: aircraft, anti-air rules, artillery and the tech chain.


func test_aircraft_fly_straight_over_obstacles() -> void:
	var w: SimWorld = SimTestUtil.make_world(4, 40)
	for y: int in range(0, 40):
		w.map.set_terrain(Vector2i(20, y), SimMap.Terrain.ROCK)
	w.map.finalize()
	var drone: SimEntity = w.spawn_unit("scout_drone", 0, Vector2(20, 40))
	var tank: SimEntity = w.spawn_unit("bulwark", 0, Vector2(20, 44))
	w.push_command(SimCommand.move(0, PackedInt32Array([drone.id, tank.id]), Vector2(60, 40)))
	SimTestUtil.run(w, 20 * 8)
	check(drone.pos.distance_to(Vector2(60, 40)) < 3.0, "drone crossed the wall (%s)" % str(drone.pos))
	check(tank.pos.x < 40.0, "the tank could not (%s)" % str(tank.pos))


func test_ground_only_weapons_ignore_aircraft() -> void:
	var w: SimWorld = SimTestUtil.make_world(4, 40)
	SimTestUtil.reveal_all(w)
	var tank: SimEntity = w.spawn_unit("bulwark", 0, Vector2(30, 30))
	var drone: SimEntity = w.spawn_unit("scout_drone", 1, Vector2(36, 30))
	w.push_command(SimCommand.hold(1, PackedInt32Array([drone.id])))
	SimTestUtil.run(w, 20 * 8)
	check_near(drone.hp, drone.max_hp, 0.01, "tank cannon cannot hit aircraft")
	check_eq(tank.target_id, 0, "the tank does not even target it")
	check(SimCombat.best_multiplier(w, tank, drone) <= 0.0, "no usable weapon against air")


func test_flak_hits_air_and_flak_post_ignores_ground() -> void:
	var w: SimWorld = SimTestUtil.make_world(4, 40)
	SimTestUtil.reveal_all(w)
	var post: SimEntity = w.spawn_building("flak_post", 0, Vector2i(15, 15), true)
	var walker: SimEntity = w.spawn_unit("hauler", 1, post.pos + Vector2(6, 0))
	var flyer: SimEntity = w.spawn_unit("kestrel", 1, post.pos + Vector2(-8, 0))
	w.push_command(SimCommand.hold(1, PackedInt32Array([flyer.id])))
	SimTestUtil.run(w, 20 * 10)
	check_near(walker.hp, walker.max_hp, 0.01, "flak post leaves ground units alone")
	check(not flyer.alive or flyer.hp < flyer.max_hp * 0.5, "flak post tears into the gunship")
	var flak: int = GameData.DAMAGE_TYPES.find("flak")
	var air: int = w.data.armor_classes.find("air")
	check(w.data.damage_multiplier(flak, air) > 1.3, "flak is strong against air")


func test_kestrel_attacks_ground_not_air() -> void:
	var w: SimWorld = SimTestUtil.make_world(4, 40)
	SimTestUtil.reveal_all(w)
	var gunship: SimEntity = w.spawn_unit("kestrel", 0, Vector2(30, 30))
	var enemy_drone: SimEntity = w.spawn_unit("scout_drone", 1, Vector2(34, 30))
	var truck: SimEntity = w.spawn_unit("hauler", 1, Vector2(36, 34))
	w.push_command(SimCommand.hold(1, PackedInt32Array([enemy_drone.id])))
	SimTestUtil.run(w, 20 * 10)
	check(not truck.alive or truck.hp < truck.max_hp, "rockets hit the truck")
	check_near(enemy_drone.hp, enemy_drone.max_hp, 0.01, "rockets cannot hit aircraft")
	check(gunship.alive, "gunship fine")


func test_longbow_has_minimum_range_and_long_reach() -> void:
	var w: SimWorld = SimTestUtil.make_world(4, 64)
	SimTestUtil.reveal_all(w)
	var gun: SimEntity = w.spawn_unit("longbow", 0, Vector2(30, 60))
	w.push_command(SimCommand.hold(0, PackedInt32Array([gun.id])))
	var close: SimEntity = w.spawn_unit("hauler", 1, Vector2(34, 60))
	SimTestUtil.run(w, 20 * 10)
	check_near(close.hp, close.max_hp, 0.01, "target inside minimum range is not shelled")
	var far: SimEntity = w.spawn_building("barracks", 1, w.map.cell_of(Vector2(48, 58)), true)
	SimTestUtil.run(w, 20 * 20)
	check(far.hp < far.max_hp, "a building 18 away is shelled")
	check_near(close.hp, close.max_hp, 0.01, "still no hits on the close target")


func test_tier_three_tech_chain() -> void:
	var w: SimWorld = SimTestUtil.make_world(4, 64)
	var p: SimPlayer = w.players[0]
	var hq_cell: Vector2i = w.map.cell_of(p.start_pos) - Vector2i(2, 2)
	w.spawn_building("hq", 0, hq_cell, true)
	SimSignal.recompute(w)
	var lab: EntityDef = w.data.entity("command_lab")
	var pad: EntityDef = w.data.entity("airpad")
	var spot: Vector2i = hq_cell + Vector2i(6, 0)
	check(not SimEconomy.can_place(w, 0, lab, spot), "Command Lab needs a Vehicle Works")
	w.spawn_building("barracks", 0, hq_cell + Vector2i(0, 6), true)
	var works: SimEntity = w.spawn_building("vehicle_works", 0, hq_cell + Vector2i(-6, 0), true)
	check(SimEconomy.can_place(w, 0, lab, spot), "Command Lab allowed once the Works stands")
	check(not SimEconomy.can_place(w, 0, pad, spot), "Airpad needs a Command Lab")
	check(SimEconomy.train_error(w, works, w.data.entity("longbow")) != "", "Longbow needs a Command Lab")
	check_eq(SimEconomy.train_error(w, works, w.data.entity("tempest")), "", "Tempest is available at tier 2")
	w.spawn_building("command_lab", 0, spot, true)
	SimTestUtil.run(w, 8)
	check(SimEconomy.can_place(w, 0, pad, hq_cell + Vector2i(6, 5)), "Airpad allowed with a Command Lab")
	p.salvage = 5000
	check_eq(SimEconomy.train_error(w, works, w.data.entity("longbow")), "", "Longbow unlocked")


func test_command_lab_shortens_directive_cooldowns() -> void:
	var w: SimWorld = SimTestUtil.make_world(4, 64)
	var hq_cell: Vector2i = w.map.cell_of(w.players[0].start_pos) - Vector2i(2, 2)
	w.spawn_building("hq", 0, hq_cell, true)
	SimSignal.recompute(w)
	check_near(SimDirectives.cooldown_mult(w, 0), 1.0, 0.001, "no bonus without a lab")
	w.spawn_building("command_lab", 0, hq_cell + Vector2i(6, 0), true)
	SimTestUtil.run(w, 8)
	check_near(SimDirectives.cooldown_mult(w, 0), 0.75, 0.001, "25% faster with a linked lab")
	w.players[0].unlocked["recon_sweep"] = true
	w.push_command(SimCommand.directive(0, "recon_sweep", Vector2(60, 60)))
	SimTestUtil.run(w, 2)
	var def: DirectiveDef = w.data.directive("recon_sweep")
	check(SimDirectives.cooldown_left(w, 0, def) < def.cooldown * 0.76, "cooldown started shorter")


func test_every_model_key_is_known_to_the_factory() -> void:
	var data: GameData = GameData.shared()
	var source: String = FileAccess.get_file_as_string("res://view/model_factory.gd")
	for def: EntityDef in data.entities.values():
		check(source.contains("\"%s\":" % def.model), "model '%s' for %s has a builder" % [def.model, def.id])
