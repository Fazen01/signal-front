class_name SimMapGen
extends RefCounted
## Seeded, mirrored procedural map generator. Everything is rotated 180
## degrees about the map centre so both starts are identical.

const START_MARGIN_CELLS: int = 13  ## start position, in cells from the corner
const START_CLEAR_CELLS: int = 11  ## radius kept free of obstacles around a start
const NEAR_FIELD_AMOUNT: int = 5000
const MID_FIELD_AMOUNT: int = 9000


## Generates a two-player map of `size_cells` x `size_cells` cells.
static func generate(seed_value: int, size_cells: int = 64) -> SimMap:
	var attempt: int = 0
	while attempt < 24:
		var m: SimMap = _generate_once(seed_value + attempt * 7919, size_cells, attempt >= 16)
		if _starts_connected(m):
			m.name = "Generated %d" % seed_value
			return m
		attempt += 1
	# Fall back to open ground; always playable.
	var plain: SimMap = _generate_once(seed_value, size_cells, true)
	plain.name = "Open Ground %d" % seed_value
	return plain


## A flat, empty map for tests.
static func blank(size_cells: int = 32) -> SimMap:
	var m: SimMap = SimMap.new()
	m.setup(size_cells, size_cells)
	m.name = "Blank"
	var size: Vector2 = m.world_size()
	m.starts = [Vector2(12.0, 12.0), Vector2(size.x - 12.0, size.y - 12.0)]
	m.finalize()
	return m


static func _generate_once(seed_value: int, n: int, sparse: bool) -> SimMap:
	var rng: SimRng = SimRng.new(seed_value)
	var m: SimMap = SimMap.new()
	m.setup(n, n)
	var size: Vector2 = m.world_size()
	var start_a: Vector2 = Vector2(float(START_MARGIN_CELLS) * SimMap.CELL, float(START_MARGIN_CELLS) * SimMap.CELL)
	var start_b: Vector2 = size - start_a
	m.starts = [start_a, start_b]

	var scale: float = float(n) / 64.0
	var rocks: int = int(round((2.0 if sparse else 7.0) * scale * scale))
	var ponds: int = int(round((0.0 if sparse else 2.0) * scale * scale))
	var forests: int = int(round(7.0 * scale * scale))

	for i: int in rocks:
		_blob(m, rng, SimMap.Terrain.ROCK, rng.range_f(1.6, 3.6))
	for i: int in ponds:
		_blob(m, rng, SimMap.Terrain.WATER, rng.range_f(2.2, 4.2))
	for i: int in forests:
		_blob(m, rng, SimMap.Terrain.FOREST, rng.range_f(2.4, 5.0))

	# Salvage near each start, on the side facing the map centre.
	var centre: Vector2 = size * 0.5
	var to_centre: float = (centre - start_a).angle()
	var near_dist: float = 17.0
	for k: int in 2:
		var ang: float = to_centre + (-0.75 if k == 0 else 0.75) + rng.range_f(-0.12, 0.12)
		var p: Vector2 = start_a + Vector2(cos(ang), sin(ang)) * near_dist
		_add_field_pair(m, p, NEAR_FIELD_AMOUNT)
	# Richer contested fields around the middle, off the direct line.
	var across: Vector2 = Vector2(-sin(to_centre), cos(to_centre))
	var mid_off: float = rng.range_f(0.16, 0.24) * size.x
	_add_field_pair(m, centre + across * mid_off, MID_FIELD_AMOUNT)
	# One extra expansion field per side, further out along the edge.
	var exp_pos: Vector2 = Vector2(start_a.x + rng.range_f(0.30, 0.38) * size.x, start_a.y + rng.range_f(-4.0, 4.0))
	_add_field_pair(m, exp_pos, NEAR_FIELD_AMOUNT)

	# Uplink sites on the two empty flanks.
	var flank: Vector2 = Vector2(size.x - start_a.x - rng.range_f(0.0, 8.0), start_a.y + rng.range_f(0.0, 8.0))
	flank = m.cell_center(m.cell_of(flank))
	m.uplink_spots = [flank, size - flank]
	for u: Vector2 in m.uplink_spots:
		_clear_disc(m, u, 3)

	for s: Vector2 in m.starts:
		_clear_disc(m, s, START_CLEAR_CELLS)

	_build_heights(m, rng)
	m.finalize()
	return m


## Paints a roughly round blob and its mirror image.
static func _blob(m: SimMap, rng: SimRng, terrain: int, radius_cells: float) -> void:
	var cx: float = rng.range_f(2.0, float(m.w) - 2.0)
	var cy: float = rng.range_f(2.0, float(m.h) - 2.0)
	var squash: float = rng.range_f(0.6, 1.0)
	var tilt: float = rng.range_f(0.0, PI)
	var wobble: float = rng.range_f(0.0, TAU)
	var r: int = int(ceilf(radius_cells)) + 1
	for dy: int in range(-r, r + 1):
		for dx: int in range(-r, r + 1):
			var v: Vector2 = Vector2(float(dx), float(dy)).rotated(tilt)
			v.y /= squash
			var edge: float = radius_cells * (1.0 + 0.18 * sin(v.angle() * 3.0 + wobble))
			if v.length() <= edge:
				var c: Vector2i = Vector2i(int(cx) + dx, int(cy) + dy)
				m.set_terrain(c, terrain)
				m.set_terrain(Vector2i(m.w - 1 - c.x, m.h - 1 - c.y), terrain)


## Turns every cell whose centre is within `radius_cells` cells of `centre`
## into open ground. Works on world distances so mirrored calls stay mirrored.
static func _clear_disc(m: SimMap, centre: Vector2, radius_cells: int) -> void:
	var c0: Vector2i = m.cell_of(centre)
	var reach: float = float(radius_cells) * SimMap.CELL + 0.01
	for dy: int in range(-radius_cells - 1, radius_cells + 2):
		for dx: int in range(-radius_cells - 1, radius_cells + 2):
			var c: Vector2i = Vector2i(c0.x + dx, c0.y + dy)
			if m.in_bounds(c) and m.cell_center(c).distance_to(centre) <= reach:
				m.set_terrain(c, SimMap.Terrain.GROUND)


static func _add_field_pair(m: SimMap, p: Vector2, amount: int) -> void:
	var size: Vector2 = m.world_size()
	var q: Vector2 = Vector2(clampf(p.x, 6.0, size.x - 6.0), clampf(p.y, 6.0, size.y - 6.0))
	# Snap to a cell centre so the mirror image lands on a cell centre too.
	q = m.cell_center(m.cell_of(q))
	var mirror: Vector2 = size - q
	m.field_spots.append(Vector3(q.x, q.y, float(amount)))
	_clear_disc(m, q, 3)
	if mirror.distance_to(q) > 4.0:
		m.field_spots.append(Vector3(mirror.x, mirror.y, float(amount)))
		_clear_disc(m, mirror, 3)


static func _build_heights(m: SimMap, rng: SimRng) -> void:
	var p1: float = rng.range_f(0.0, TAU)
	var p2: float = rng.range_f(0.0, TAU)
	var p3: float = rng.range_f(0.0, TAU)
	var row: int = m.w + 1
	for y: int in range(0, m.h + 1):
		for x: int in range(0, m.w + 1):
			var a: float = _roll(float(x), float(y), p1, p2, p3)
			var b: float = _roll(float(m.w - x), float(m.h - y), p1, p2, p3)
			m.heights[y * row + x] = (a + b) * 0.5
	# Flatten the ground around each start so bases sit level.
	for s: Vector2 in m.starts:
		var c0: Vector2i = m.cell_of(s)
		for dy: int in range(-9, 10):
			for dx: int in range(-9, 10):
				var x: int = c0.x + dx
				var y: int = c0.y + dy
				if x < 0 or y < 0 or x > m.w or y > m.h:
					continue
				var d: float = sqrt(float(dx * dx + dy * dy))
				var keep: float = clampf((d - 5.0) / 4.0, 0.0, 1.0)
				m.heights[y * row + x] *= keep
	# Rock rises and water sinks: each corner takes the average of the four
	# cells around it, so cliffs and shores slope instead of stepping.
	for y: int in range(0, m.h + 1):
		for x: int in range(0, m.w + 1):
			var lift: float = 0.0
			for cy: int in [y - 1, y]:
				for cx: int in [x - 1, x]:
					var t: int = m.terrain_cell(Vector2i(clampi(cx, 0, m.w - 1), clampi(cy, 0, m.h - 1)))
					if t == SimMap.Terrain.ROCK:
						lift += 2.4
					elif t == SimMap.Terrain.WATER:
						lift -= 1.3
			m.heights[y * row + x] += lift * 0.25


static func _roll(x: float, y: float, p1: float, p2: float, p3: float) -> float:
	return 0.9 * sin(x * 0.11 + p1) * cos(y * 0.13 + p2) + 0.45 * sin((x + y) * 0.07 + p3) + 0.6


static func _starts_connected(m: SimMap) -> bool:
	if m.starts.size() < 2:
		return true
	var path: PackedVector2Array = m.find_path(m.starts[0], m.starts[1], true)
	if path.size() == 0:
		return false
	if path[path.size() - 1].distance_to(m.starts[1]) > SimMap.CELL * 2.0:
		return false
	# Every salvage field must be reachable from the first start.
	for f: Vector3 in m.field_spots:
		var fp: Vector2 = Vector2(f.x, f.y)
		var to_field: PackedVector2Array = m.find_path(m.starts[0], fp, true)
		if to_field.size() == 0 or to_field[to_field.size() - 1].distance_to(fp) > SimMap.CELL * 2.0:
			return false
	return true
