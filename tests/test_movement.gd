extends TestCase
## Move orders, formations and separation.


func test_unit_walks_to_target() -> void:
	var w: SimWorld = SimTestUtil.make_world()
	var e: SimEntity = w.spawn_unit("trooper", 0, Vector2(10, 10))
	w.push_command(SimCommand.move(0, PackedInt32Array([e.id]), Vector2(30, 22)))
	SimTestUtil.run(w, 20 * 12)
	check(e.pos.distance_to(Vector2(30, 22)) < 0.2, "arrived (at %s)" % str(e.pos))
	check(not e.moving, "stopped")
	check(e.orders.is_empty(), "order finished")


func test_speed_matches_definition() -> void:
	var w: SimWorld = SimTestUtil.make_world()
	var e: SimEntity = w.spawn_unit("trooper", 0, Vector2(10, 10))
	w.push_command(SimCommand.move(0, PackedInt32Array([e.id]), Vector2(50, 10)))
	SimTestUtil.run(w, 1)
	var start: Vector2 = e.pos
	SimTestUtil.run(w, 100)
	var travelled: float = e.pos.distance_to(start)
	check_near(travelled, e.def.speed * 5.0, 0.3, "5 seconds of travel")


func test_vehicle_avoids_rock() -> void:
	var w: SimWorld = SimTestUtil.make_world()
	for y: int in range(3, 13):
		w.map.set_terrain(Vector2i(10, y), SimMap.Terrain.ROCK)
	w.map.finalize()
	var e: SimEntity = w.spawn_unit("bulwark", 0, Vector2(10, 15))
	w.push_command(SimCommand.move(0, PackedInt32Array([e.id]), Vector2(34, 15)))
	var ok: bool = true
	for i: int in 20 * 25:
		w.tick()
		if not w.map.is_passable(e.pos):
			ok = false
	check(ok, "never entered a blocked cell")
	check(e.pos.distance_to(Vector2(34, 15)) < 0.5, "arrived (at %s)" % str(e.pos))


func test_group_move_keeps_units_apart() -> void:
	var w: SimWorld = SimTestUtil.make_world()
	var group: Array[SimEntity] = SimTestUtil.spawn_group(w, "trooper", 0, Vector2(8, 8), 12)
	w.push_command(SimCommand.move(0, SimTestUtil.ids_of(group), Vector2(40, 40)))
	SimTestUtil.run(w, 20 * 25)
	var centre: Vector2 = Vector2.ZERO
	var moving: int = 0
	for e: SimEntity in group:
		centre += e.pos
		if e.moving:
			moving += 1
	centre /= float(group.size())
	check_eq(moving, 0, "everyone stopped")
	check(centre.distance_to(Vector2(40, 40)) < 3.0, "group centre near target (%s)" % str(centre))
	var overlaps: int = 0
	for i: int in group.size():
		for j: int in range(i + 1, group.size()):
			if group[i].pos.distance_to(group[j].pos) < (group[i].radius + group[j].radius) * 0.8:
				overlaps += 1
	check_eq(overlaps, 0, "no units stacked on each other")


func test_stop_command() -> void:
	var w: SimWorld = SimTestUtil.make_world()
	var e: SimEntity = w.spawn_unit("courser", 0, Vector2(10, 10))
	w.push_command(SimCommand.move(0, PackedInt32Array([e.id]), Vector2(50, 50)))
	SimTestUtil.run(w, 20)
	check(e.moving, "moving after a move order")
	w.push_command(SimCommand.stop(0, PackedInt32Array([e.id])))
	SimTestUtil.run(w, 2)
	check(not e.moving, "stopped after a stop order")
	var at: Vector2 = e.pos
	SimTestUtil.run(w, 20)
	check(e.pos.distance_to(at) < 0.01, "stays put")


func test_cannot_command_enemy_units() -> void:
	var w: SimWorld = SimTestUtil.make_world()
	var e: SimEntity = w.spawn_unit("trooper", 1, Vector2(10, 10))
	w.push_command(SimCommand.move(0, PackedInt32Array([e.id]), Vector2(30, 30)))
	SimTestUtil.run(w, 20)
	check(e.pos.distance_to(Vector2(10, 10)) < 0.01, "enemy unit ignored the order")


func test_queued_moves() -> void:
	var w: SimWorld = SimTestUtil.make_world()
	var e: SimEntity = w.spawn_unit("courser", 0, Vector2(10, 10))
	var ids: PackedInt32Array = PackedInt32Array([e.id])
	w.push_command(SimCommand.move(0, ids, Vector2(30, 10)))
	w.push_command(SimCommand.move(0, ids, Vector2(30, 30), true))
	SimTestUtil.run(w, 2)
	check_eq(e.orders.size(), 2, "two orders queued")
	SimTestUtil.run(w, 20 * 14)
	check(e.pos.distance_to(Vector2(30, 30)) < 0.3, "finished at the second waypoint (%s)" % str(e.pos))
