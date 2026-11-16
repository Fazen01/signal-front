class_name SimMapGen
extends RefCounted
## Seeded, symmetric procedural map generator, plus loading of the hand-made
## layouts in res://data/maps. Two-player maps are rotated 180 degrees about
## the centre; four-player maps are rotated in quarter turns, so every start
## is identical.

const START_MARGIN_CELLS: int = 13  ## start position, in cells from the corner
const START_CLEAR_CELLS: int = 11  ## radius kept free of obstacles around a start
const NEAR_FIELD_AMOUNT: int = 10000
const MID_FIELD_AMOUNT: int = 16000
const SMALL_CELLS: int = 64  ## 128 x 128 world units, two players
const LARGE_CELLS: int = 96  ## 192 x 192 world units, up to four players
const LAYOUT_DIR: String = "res://data/maps"


## Generates a map for `players` starts (2 or 4) on a square of `size_cells`.
static func generate(seed_value: int, size_cells: int = SMALL_CELLS, players: int = 2) -> SimMap:
	var order: int = 4 if players > 2 else 2
	var attempt: int = 0
	while attempt < 24:
		var m: SimMap = _generate_once(seed_value + attempt * 7919, size_cells, order, attempt >= 16)
		if _starts_connected(m):
			m.name = "Generated %d" % seed_value
			return m
		attempt += 1
	# Fall back to open ground; always playable.
	var plain: SimMap = _generate_once(seed_value, size_cells, order, true)
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


# ------------------------------------------------------------- symmetry

## The images of a cell under the map's rotational symmetry (including itself).
static func cell_images(m: SimMap, c: Vector2i, order: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = [c]
	if order == 4:
		var q: Vector2i = c
		for i: int in 3:
			q = Vector2i(m.w - 1 - q.y, q.x)
			out.append(q)
	else:
		out.append(Vector2i(m.w - 1 - c.x, m.h - 1 - c.y))
	return out


## The images of a world position under the map's rotational symmetry.
static func point_images(m: SimMap, p: Vector2, order: int) -> Array[Vector2]:
	var size: Vector2 = m.world_size()
	var out: Array[Vector2] = [p]
	if order == 4:
		var q: Vector2 = p
		for i: int in 3:
			q = Vector2(size.x - q.y, q.x)
			out.append(q)
	else:
		out.append(size - p)
	return out


# ------------------------------------------------------------ generator

static func _generate_once(seed_value: int, n: int, order: int, sparse: bool) -> SimMap:
	var rng: SimRng = SimRng.new(seed_value)
	var m: SimMap = SimMap.new()
	m.setup(n, n)
	var size: Vector2 = m.world_size()
	var start_a: Vector2 = Vector2(float(START_MARGIN_CELLS) * SimMap.CELL, float(START_MARGIN_CELLS) * SimMap.CELL)
	m.starts = point_images(m, start_a, order)
	if order == 4:
		# Opposite corners first, so two players on a four-start map face each other.
		m.starts = [m.starts[0], m.starts[2], m.starts[1], m.starts[3]]

	# Blob counts are per symmetric copy, so divide by the symmetry order.
	var scale: float = float(n * n) / float(SMALL_CELLS * SMALL_CELLS) * 2.0 / float(order)
	var rocks: int = int(round((2.0 if sparse else 7.0) * scale))
	var ponds: int = int(round((0.0 if sparse else 2.0) * scale))
	var forests: int = int(round(7.0 * scale))
	for i: int in rocks:
		_blob(m, rng, order, SimMap.Terrain.ROCK, rng.range_f(1.6, 3.6))
	for i: int in ponds:
		_blob(m, rng, order, SimMap.Terrain.WATER, rng.range_f(2.2, 4.2))
	for i: int in forests:
		_blob(m, rng, order, SimMap.Terrain.FOREST, rng.range_f(2.4, 5.0))

	# Salvage near each start, on the side facing the map centre.
	var centre: Vector2 = size * 0.5
	var to_centre: float = (centre - start_a).angle()
	var near_dist: float = 17.0
	for k: int in 2:
		var ang: float = to_centre + (-0.75 if k == 0 else 0.75) + rng.range_f(-0.12, 0.12)
		_add_field(m, order, start_a + Vector2(cos(ang), sin(ang)) * near_dist, NEAR_FIELD_AMOUNT)
	# Richer contested fields around the middle.
	var across: Vector2 = Vector2(-sin(to_centre), cos(to_centre))
	var mid_off: float = rng.range_f(0.16, 0.24) * size.x
	if order == 4:
		_add_field(m, order, centre + Vector2(0.0, -1.0) * mid_off * 0.7, MID_FIELD_AMOUNT)
	else:
		_add_field(m, order, centre + across * mid_off, MID_FIELD_AMOUNT)
	# One extra expansion field per start, further out along the edge.
	var exp_pos: Vector2 = Vector2(start_a.x + rng.range_f(0.30, 0.38) * size.x, start_a.y + rng.range_f(-4.0, 4.0))
	_add_field(m, order, exp_pos, NEAR_FIELD_AMOUNT)

	# Uplink sites: the empty flanks for two players, the edge midpoints for four.
	var flank: Vector2
	if order == 4:
		flank = Vector2(size.x * 0.5 + rng.range_f(-6.0, 6.0), start_a.y + rng.range_f(0.0, 6.0))
	else:
		flank = Vector2(size.x - start_a.x - rng.range_f(0.0, 8.0), start_a.y + rng.range_f(0.0, 8.0))
	flank = m.cell_center(m.cell_of(flank))
	m.uplink_spots = point_images(m, flank, order)
	for u: Vector2 in m.uplink_spots:
		_clear_disc(m, u, 3)
	for s: Vector2 in m.starts:
		_clear_disc(m, s, START_CLEAR_CELLS)

	build_heights(m, rng)
	m.finalize()
	return m


## Paints a roughly round blob and its symmetric images.
static func _blob(m: SimMap, rng: SimRng, order: int, terrain: int, radius_cells: float) -> void:
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
				for c: Vector2i in cell_images(m, Vector2i(int(cx) + dx, int(cy) + dy), order):
					m.set_terrain(c, terrain)


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


## Adds a salvage field and its symmetric images, clearing the ground around
## each. Images that land on top of each other (at the centre) are merged.
static func _add_field(m: SimMap, order: int, p: Vector2, amount: int) -> void:
	var size: Vector2 = m.world_size()
	var q: Vector2 = Vector2(clampf(p.x, 6.0, size.x - 6.0), clampf(p.y, 6.0, size.y - 6.0))
	# Snap to a cell centre so every image lands on a cell centre too.
	q = m.cell_center(m.cell_of(q))
	for image: Vector2 in point_images(m, q, order):
		var taken: bool = false
		for f: Vector3 in m.field_spots:
			if Vector2(f.x, f.y).distance_to(image) < 4.0:
				taken = true
		if not taken:
			m.field_spots.append(Vector3(image.x, image.y, float(amount)))
			_clear_disc(m, image, 3)


## Fills in the cosmetic height field: gentle rolls, flat bases, raised rock
## and sunken water.
static func build_heights(m: SimMap, rng: SimRng) -> void:
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


## Every start must reach every other start and every salvage field.
static func _starts_connected(m: SimMap) -> bool:
	if m.starts.size() < 2:
		return true
	var targets: Array[Vector2] = []
	for i: int in range(1, m.starts.size()):
		targets.append(m.starts[i])
	for f: Vector3 in m.field_spots:
		targets.append(Vector2(f.x, f.y))
	for t: Vector2 in targets:
		var path: PackedVector2Array = m.find_path(m.starts[0], t, true)
		if path.size() == 0 or path[path.size() - 1].distance_to(t) > SimMap.CELL * 2.0:
			return false
	return true


# ---------------------------------------------------- hand-made layouts

## Ids of the layouts in res://data/maps, sorted.
static func layout_ids() -> Array[String]:
	var out: Array[String] = []
	var dir: DirAccess = DirAccess.open(LAYOUT_DIR)
	if dir == null:
		return out
	for f: String in dir.get_files():
		if f.ends_with(".json"):
			out.append(f.trim_suffix(".json"))
	out.sort()
	return out


## Name, description and player count of a layout without building it.
static func layout_info(id: String) -> Dictionary:
	var d: Dictionary = _read_layout(id)
	if d.is_empty():
		return {}
	return {"name": str(d.get("name", id)), "players": int(d.get("players", 2)), "desc": str(d.get("desc", ""))}


static func _read_layout(id: String) -> Dictionary:
	var path: String = "%s/%s.json" % [LAYOUT_DIR, id]
	if not FileAccess.file_exists(path):
		return {}
	var json: JSON = JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or typeof(json.data) != TYPE_DICTIONARY:
		push_error("SimMapGen: cannot parse %s" % path)
		return {}
	var d: Dictionary = json.data
	return d


## Builds a hand-made layout. Rows are strings, one character per cell:
##   . ground   f forest   r rock   w water
##   1-4 player starts   s salvage field   S rich salvage field   u uplink site
## Returns null if the layout is missing or malformed.
static func load_layout(id: String) -> SimMap:
	var d: Dictionary = _read_layout(id)
	if d.is_empty() or not d.has("rows"):
		return null
	var rows: Array = d["rows"]
	var h: int = rows.size()
	if h == 0:
		return null
	var w: int = str(rows[0]).length()
	var m: SimMap = SimMap.new()
	m.setup(w, h)
	m.name = str(d.get("name", id))
	var starts: Dictionary[int, Vector2] = {}
	for y: int in h:
		var line: String = str(rows[y])
		if line.length() != w:
			push_error("SimMapGen: layout %s row %d has the wrong length" % [id, y])
			return null
		for x: int in w:
			var c: Vector2i = Vector2i(x, y)
			var centre: Vector2 = m.cell_center(c)
			match line[x]:
				"f":
					m.set_terrain(c, SimMap.Terrain.FOREST)
				"r":
					m.set_terrain(c, SimMap.Terrain.ROCK)
				"w":
					m.set_terrain(c, SimMap.Terrain.WATER)
				"s":
					m.field_spots.append(Vector3(centre.x, centre.y, float(NEAR_FIELD_AMOUNT)))
				"S":
					m.field_spots.append(Vector3(centre.x, centre.y, float(MID_FIELD_AMOUNT)))
				"u":
					m.uplink_spots.append(centre)
				"1", "2", "3", "4":
					# The marker is the cell whose top-left corner is the centre
					# of the headquarters footprint.
					starts[int(line[x])] = Vector2(float(x) * SimMap.CELL, float(y) * SimMap.CELL)
				_:
					pass
	for i: int in range(1, 5):
		if starts.has(i):
			m.starts.append(starts[i])
	if m.starts.size() < 2:
		push_error("SimMapGen: layout %s needs at least two starts" % id)
		return null
	build_heights(m, SimRng.new(id.hash()))
	m.finalize()
	return m
