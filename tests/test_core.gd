extends TestCase
## RNG, world registry and map basics.


func test_rng_is_deterministic() -> void:
	var a: SimRng = SimRng.new(42)
	var b: SimRng = SimRng.new(42)
	var c: SimRng = SimRng.new(43)
	var same: bool = true
	var differs: bool = false
	for i: int in 200:
		var va: int = a.next_int()
		if va != b.next_int():
			same = false
		if va != c.next_int():
			differs = true
	check(same, "same seed gives same sequence")
	check(differs, "different seed gives different sequence")


func test_rng_ranges() -> void:
	var r: SimRng = SimRng.new(7)
	var lo: int = 99
	var hi: int = -99
	for i: int in 2000:
		var f: float = r.next_float()
		check(f >= 0.0 and f < 1.0, "next_float in [0,1)")
		var v: int = r.range_i(-3, 4)
		lo = mini(lo, v)
		hi = maxi(hi, v)
	check_eq(lo, -3, "range_i reaches the low end")
	check_eq(hi, 4, "range_i reaches the high end")


func test_entity_registry() -> void:
	var w: SimWorld = SimTestUtil.make_world()
	var a: SimEntity = w.spawn_unit("trooper", 0, Vector2(10, 10))
	var b: SimEntity = w.spawn_unit("bulwark", 1, Vector2(40, 40))
	check(a != null and b != null, "units spawn")
	check(a.id != b.id, "ids are unique")
	check_eq(w.get_entity(a.id), a, "lookup by id")
	check_eq(w.players[0].bandwidth_used, 1, "trooper uses 1 bandwidth")
	check_eq(w.players[1].bandwidth_used, 4, "bulwark uses 4 bandwidth")
	SimCombat.kill(w, a, null, -1)
	w.tick()
	check(w.get_entity(a.id) == null, "dead entity is gone")
	check_eq(w.players[0].bandwidth_used, 0, "bandwidth is released on death")
	check_eq(w.tick_count, 1, "tick counter advances")


func test_map_cells_and_passability() -> void:
	var m: SimMap = SimMapGen.blank(16)
	check_eq(m.world_size(), Vector2(32, 32), "world size")
	check_eq(m.cell_of(Vector2(3.9, 0.1)), Vector2i(1, 0), "cell_of")
	check_eq(m.cell_center(Vector2i(1, 0)), Vector2(3, 1), "cell_center")
	check(m.is_passable(Vector2(5, 5)), "open ground is passable")
	check(not m.is_passable(Vector2(-1, 5)), "outside the map is not passable")
	m.set_terrain(Vector2i(4, 4), SimMap.Terrain.ROCK)
	m.finalize()
	check(not m.is_cell_passable(Vector2i(4, 4)), "rock blocks")
	m.set_occupied(Rect2i(6, 6, 2, 2), 99)
	check(not m.is_cell_passable(Vector2i(7, 7)), "buildings block")
	check_eq(m.occupant_at(Vector2i(7, 7)), 99, "occupant recorded")
	m.set_occupied(Rect2i(6, 6, 2, 2), 0)
	check(m.is_cell_passable(Vector2i(7, 7)), "clearing a footprint frees the cells")


func test_pathfinding_goes_around_walls() -> void:
	var m: SimMap = SimMapGen.blank(24)
	# A wall across the map with one gap at the bottom.
	for y: int in range(0, 20):
		m.set_terrain(Vector2i(12, y), SimMap.Terrain.ROCK)
	m.finalize()
	var a: Vector2 = Vector2(5, 5)
	var b: Vector2 = Vector2(43, 5)
	var path: PackedVector2Array = m.find_path(a, b, false)
	check(path.size() >= 2, "path found")
	if path.size() > 0:
		check(path[path.size() - 1].distance_to(b) < 0.01, "path ends at the goal")
	var prev: Vector2 = a
	var length: float = 0.0
	var all_clear: bool = true
	for p: Vector2 in path:
		if not m.line_clear(prev, p):
			all_clear = false
		length += prev.distance_to(p)
		prev = p
	check(all_clear, "every leg of the path is walkable")
	check(length > 70.0, "path detours around the wall (length %.1f)" % length)
	check(length < 110.0, "path is not absurdly long (length %.1f)" % length)


func test_path_to_blocked_goal_ends_nearby() -> void:
	var m: SimMap = SimMapGen.blank(16)
	m.set_terrain(Vector2i(8, 8), SimMap.Terrain.ROCK)
	m.finalize()
	var goal: Vector2 = m.cell_center(Vector2i(8, 8))
	var path: PackedVector2Array = m.find_path(Vector2(3, 3), goal, false)
	check(path.size() > 0, "path found")
	if path.size() > 0:
		var end: Vector2 = path[path.size() - 1]
		check(m.is_passable(end), "path ends on passable ground")
		check(end.distance_to(goal) <= SimMap.CELL * 1.5, "path ends next to the blocked goal")


func test_generated_map_is_symmetric_and_connected() -> void:
	for seed_value: int in [1, 2, 3, 77, 1234]:
		var m: SimMap = SimMapGen.generate(seed_value, 64)
		check_eq(m.starts.size(), 2, "two starts")
		var mismatches: int = 0
		for y: int in m.h:
			for x: int in m.w:
				if m.terrain_cell(Vector2i(x, y)) != m.terrain_cell(Vector2i(m.w - 1 - x, m.h - 1 - y)):
					mismatches += 1
		check_eq(mismatches, 0, "seed %d: terrain is point-symmetric" % seed_value)
		var path: PackedVector2Array = m.find_path(m.starts[0], m.starts[1], true)
		check(path.size() > 0, "seed %d: starts are connected" % seed_value)
		check(m.field_spots.size() >= 6, "seed %d: has salvage fields" % seed_value)
		check_eq(m.field_spots.size() % 2, 0, "seed %d: fields come in mirrored pairs" % seed_value)
		for f: Vector3 in m.field_spots:
			check(m.is_passable(Vector2(f.x, f.y)), "seed %d: field on open ground" % seed_value)
		for s: Vector2 in m.starts:
			check(m.is_cell_buildable(m.cell_of(s)), "seed %d: start is buildable" % seed_value)


func test_same_seed_same_map() -> void:
	var a: SimMap = SimMapGen.generate(5, 64)
	var b: SimMap = SimMapGen.generate(5, 64)
	check(a.terrain == b.terrain, "terrain identical")
	check(a.heights == b.heights, "heights identical")
	check_eq(a.field_spots.size(), b.field_spots.size(), "fields identical")
