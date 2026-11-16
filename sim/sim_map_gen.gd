class_name SimMapGen
extends RefCounted
## Seeded, symmetric procedural map generator, plus loading of the hand-made
## layouts in res://data/maps. Two-player maps are rotated 180 degrees about
## the centre; four-player maps are rotated in quarter turns, so every start
## is identical.
##
## The seed picks a region and, within it, a kind of country. Every region
## has five kinds of its own: the Greenwood has river valleys, highlands,
## lakeland, plains and the island; the Dustlands have a long ridge, mesa
## country, oases, dunes and rimrock; the Frostline has an ice river, crags,
## frozen lakes, pinewood and the cirque; the Cinder Wastes have a lava
## river, fissures, calderas, burnt plain and the cauldron. The first kind
## of each (a barrier across the middle with fords or passes) only suits two
## players. The last of each is a prize: a moat or a wall round the middle
## of the map with four gates in it and the richest salvage of the map
## inside. Whatever the kind, most of the map stays open ground, so matches
## run to a similar length on all of them.

const START_MARGIN_CELLS: int = 13  ## start position, in cells from the corner
const START_CLEAR_CELLS: int = 11  ## radius kept free of obstacles around a start
const NEAR_FIELD_AMOUNT: int = 7500
const MID_FIELD_AMOUNT: int = 13500
const PRIZE_FIELD_AMOUNT: int = 20000  ## what lies inside the wall of a prize map, in all
const PRIZE_GATE_CELLS: float = 5.0  ## width of each of the four ways in
const SMALL_CELLS: int = 64  ## 128 x 128 world units: the compact two-player map and the layouts
const STANDARD_CELLS: int = 88  ## 176 x 176 world units: the default two-player map
const LARGE_CELLS: int = 96  ## 192 x 192 world units, up to four players
const LAYOUT_DIR: String = "res://data/maps"
## Parts of the world a battlefield can lie in. A region changes how the land
## looks (ground, plants, water, light) and nothing about how it plays.
const REGIONS: Array[String] = ["temperate", "desert", "tundra", "ashland"]
const REGION_NAMES: Dictionary[String, String] = {
	"temperate": "Greenwood", "desert": "Dustlands", "tundra": "Frostline", "ashland": "Cinder Wastes",
}
const THEME_NAMES: Dictionary[String, String] = {
	"plains": "Plains", "river": "River Valley", "highlands": "Highlands", "lakes": "Lakeland", "open": "Open Ground",
	"longridge": "Long Ridge", "mesas": "Mesa Country", "oasis": "Oasis", "dunes": "Dunes",
	"iceriver": "Ice River", "crags": "Crags", "frozenlakes": "Frozen Lakes", "pinewood": "Pinewood",
	"lavariver": "Lava River", "fissures": "Fissures", "calderas": "Calderas", "burntplain": "Burnt Plain",
	"island": "The Island", "rimrock": "Rimrock", "cirque": "The Cirque", "cauldron": "The Cauldron",
}
## The kinds of country in each region. The first of each is the one with a
## barrier across the middle, which is left out for more than two players.
const REGION_KINDS: Dictionary[String, Array] = {
	"temperate": ["river", "highlands", "lakes", "plains", "island"],
	"desert": ["longridge", "mesas", "oasis", "dunes", "rimrock"],
	"tundra": ["iceriver", "crags", "frozenlakes", "pinewood", "cirque"],
	"ashland": ["lavariver", "fissures", "calderas", "burntplain", "cauldron"],
}
## The prize kinds: what the wall round the middle is made of, and how far
## from the centre it starts and ends (in cells).
const PRIZE_WALLS: Dictionary[String, Vector3] = {
	"island": Vector3(SimMap.Terrain.WATER, 9.0, 12.0),
	"rimrock": Vector3(SimMap.Terrain.ROCK, 9.0, 12.5),
	"cirque": Vector3(SimMap.Terrain.ROCK, 9.5, 12.5),
	"cauldron": Vector3(SimMap.Terrain.WATER, 9.0, 11.5),
}


## Generates a map for `players` starts (2 or 4) on a square of `size_cells`.
static func generate(seed_value: int, size_cells: int = SMALL_CELLS, players: int = 2, region: String = "") -> SimMap:
	var order: int = 4 if players > 2 else 2
	var where: String = pick_region(seed_value, region)
	var attempt: int = 0
	while attempt < 24:
		var m: SimMap = _generate_once(seed_value + attempt * 7919, size_cells, order, attempt >= 16, where)
		if _starts_connected(m):
			m.name = "%s %d" % [m.name, seed_value]
			m.region = where
			return m
		attempt += 1
	# Fall back to open ground; always playable.
	var plain: SimMap = _generate_once(seed_value, size_cells, order, true, where)
	plain.name = "Open Ground %d" % seed_value
	plain.region = where
	return plain


## The region a seed gives, unless a particular one is asked for.
static func pick_region(seed_value: int, wanted: String = "") -> String:
	if REGIONS.has(wanted):
		return wanted
	return REGIONS[SimRng.new(seed_value * 13 + 101).range_i(0, REGIONS.size() - 1)]


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

static func _generate_once(seed_value: int, n: int, order: int, sparse: bool, region: String) -> SimMap:
	var rng: SimRng = SimRng.new(seed_value)
	var m: SimMap = SimMap.new()
	m.setup(n, n)
	var size: Vector2 = m.world_size()
	var start_a: Vector2 = Vector2(float(START_MARGIN_CELLS) * SimMap.CELL, float(START_MARGIN_CELLS) * SimMap.CELL)
	m.starts = point_images(m, start_a, order)
	if order == 4:
		# Opposite corners first, so two players on a four-start map face each other.
		m.starts = [m.starts[0], m.starts[2], m.starts[1], m.starts[3]]

	var theme: String = _pick_theme(rng, order, sparse, region)
	m.name = THEME_NAMES[theme]
	# Feature counts are per symmetric copy, so divide by the symmetry order.
	var scale: float = float(n * n) / float(SMALL_CELLS * SMALL_CELLS) * 2.0 / float(order)
	var rock: int = SimMap.Terrain.ROCK
	var water: int = SimMap.Terrain.WATER
	var wood: int = SimMap.Terrain.FOREST
	# A prize map gets its wall first; the gates are opened again at the end.
	var gate_at: float = 0.0
	if PRIZE_WALLS.has(theme):
		var wall: Vector3 = PRIZE_WALLS[theme]
		gate_at = _ring_wall(m, rng, int(wall.x), wall.y, wall.z, false)
	# Rock and water go down first; woods only grow on what is still open.
	match theme:
		# ---- The prize kinds: the country round the wall.
		"island":
			_scatter(m, rng, order, 3.0 * scale, rock, 1.4, 2.6)
			_scatter(m, rng, order, 0.8 * scale, water, 1.8, 2.8)
			_scatter(m, rng, order, 6.0 * scale, wood, 2.6, 4.8)
			_scatter(m, rng, order, 7.0 * scale, wood, 1.2, 2.2)
		"rimrock":
			_scatter(m, rng, order, 6.0 * scale, rock, 1.4, 2.8)
			_ridges(m, rng, order, 1.2 * scale, 5.0, 9.0)
			_oases(m, rng, order, 0.7 * scale)
			_scatter(m, rng, order, 2.0 * scale, wood, 1.3, 2.2)
		"cirque":
			_scatter(m, rng, order, 3.5 * scale, rock, 1.3, 2.6)
			_scatter(m, rng, order, 1.0 * scale, water, 1.8, 3.0)
			_scatter(m, rng, order, 3.5 * scale, wood, 3.0, 5.5)
			_scatter(m, rng, order, 4.5 * scale, wood, 1.3, 2.3)
		"cauldron":
			_scatter(m, rng, order, 8.0 * scale, rock, 1.4, 2.8)
			_ridges(m, rng, order, 1.4 * scale, 5.0, 9.0)
			_scatter(m, rng, order, 3.5 * scale, wood, 1.8, 3.4)
		# ---- Greenwood: well watered and wooded.
		"river":
			_river(m, rng, water)
			_scatter(m, rng, order, 3.2 * scale, rock, 1.4, 2.6)
			_ridges(m, rng, order, 0.6 * scale, 5.0, 8.0)
			_scatter(m, rng, order, 6.0 * scale, wood, 2.6, 4.8)
			_scatter(m, rng, order, 7.0 * scale, wood, 1.2, 2.2)
		"highlands":
			_ridges(m, rng, order, 3.0 * scale, 7.0, 13.0)
			_scatter(m, rng, order, 3.5 * scale, rock, 1.3, 2.4)
			_scatter(m, rng, order, 1.0 * scale, water, 1.8, 2.8)
			_scatter(m, rng, order, 5.0 * scale, wood, 2.6, 4.8)
			_scatter(m, rng, order, 7.0 * scale, wood, 1.2, 2.2)
		"lakes":
			_scatter(m, rng, order, 2.2 * scale, water, 3.0, 5.0)
			_scatter(m, rng, order, 1.6 * scale, water, 1.6, 2.4)
			_scatter(m, rng, order, 3.5 * scale, rock, 1.4, 2.6)
			_scatter(m, rng, order, 6.0 * scale, wood, 2.6, 5.0)
			_scatter(m, rng, order, 7.0 * scale, wood, 1.2, 2.2)
		"plains":
			_scatter(m, rng, order, 4.5 * scale, rock, 1.5, 3.0)
			_ridges(m, rng, order, 0.8 * scale, 5.0, 9.0)
			_scatter(m, rng, order, 1.4 * scale, water, 2.2, 3.6)
			_scatter(m, rng, order, 6.0 * scale, wood, 3.0, 5.6)
			_scatter(m, rng, order, 8.0 * scale, wood, 1.3, 2.3)
		# ---- Dustlands: rock everywhere, water rare, green only round it.
		"longridge":
			_river(m, rng, rock)
			_scatter(m, rng, order, 6.5 * scale, rock, 1.6, 3.0)
			_oases(m, rng, order, 0.8 * scale)
			_scatter(m, rng, order, 2.0 * scale, wood, 1.3, 2.2)
		"mesas":
			_scatter(m, rng, order, 3.8 * scale, rock, 3.2, 4.8)
			_ridges(m, rng, order, 2.2 * scale, 8.0, 14.0)
			_scatter(m, rng, order, 4.5 * scale, rock, 1.2, 2.0)
			_oases(m, rng, order, 0.6 * scale)
			_scatter(m, rng, order, 2.0 * scale, wood, 1.3, 2.2)
		"oasis":
			_oases(m, rng, order, 2.6 * scale)
			_scatter(m, rng, order, 8.0 * scale, rock, 1.3, 2.4)
			_ridges(m, rng, order, 1.4 * scale, 5.0, 9.0)
		"dunes":
			_scatter(m, rng, order, 9.0 * scale, rock, 1.4, 2.6)
			_ridges(m, rng, order, 2.0 * scale, 5.0, 9.0)
			_oases(m, rng, order, 0.5 * scale)
			_scatter(m, rng, order, 2.5 * scale, wood, 1.3, 2.2)
		# ---- Frostline: frozen water and big stands of pine.
		"iceriver":
			_river(m, rng, water)
			_scatter(m, rng, order, 3.0 * scale, rock, 1.4, 2.6)
			_scatter(m, rng, order, 4.0 * scale, wood, 3.5, 6.0)
			_scatter(m, rng, order, 5.0 * scale, wood, 1.3, 2.3)
		"crags":
			_ridges(m, rng, order, 3.2 * scale, 7.0, 13.0)
			_scatter(m, rng, order, 4.5 * scale, rock, 1.3, 2.6)
			_scatter(m, rng, order, 1.2 * scale, water, 1.8, 3.0)
			_scatter(m, rng, order, 3.0 * scale, wood, 3.0, 5.0)
			_scatter(m, rng, order, 4.0 * scale, wood, 1.3, 2.3)
		"frozenlakes":
			_scatter(m, rng, order, 3.0 * scale, water, 3.0, 5.5)
			_scatter(m, rng, order, 2.0 * scale, water, 1.6, 2.6)
			_scatter(m, rng, order, 3.0 * scale, rock, 1.4, 2.6)
			_scatter(m, rng, order, 3.5 * scale, wood, 3.0, 5.0)
			_scatter(m, rng, order, 4.0 * scale, wood, 1.3, 2.3)
		"pinewood":
			_scatter(m, rng, order, 3.0 * scale, rock, 1.4, 2.6)
			_scatter(m, rng, order, 1.2 * scale, water, 2.0, 3.2)
			_scatter(m, rng, order, 4.0 * scale, wood, 4.5, 7.0)
			_scatter(m, rng, order, 7.0 * scale, wood, 1.4, 2.6)
		# ---- Cinder Wastes: black rock and burnt woods, with lava as the rare,
		# large feature of a map rather than something scattered all over it.
		"lavariver":
			_river(m, rng, water)
			_scatter(m, rng, order, 8.0 * scale, rock, 1.4, 2.8)
			_ridges(m, rng, order, 1.6 * scale, 5.0, 9.0)
			_scatter(m, rng, order, 3.5 * scale, wood, 1.8, 3.4)
		"fissures":
			# A few long cracks, not a field of puddles.
			_ridges(m, rng, order, 1.1 * scale, 15.0, 24.0, water, 0.75, 1.0)
			_scatter(m, rng, order, 9.5 * scale, rock, 1.4, 2.8)
			_ridges(m, rng, order, 1.6 * scale, 5.0, 9.0)
			_scatter(m, rng, order, 3.5 * scale, wood, 1.8, 3.4)
		"calderas":
			_calderas(m, rng, order, 0.8 * scale)
			_scatter(m, rng, order, 9.0 * scale, rock, 1.4, 2.6)
			_ridges(m, rng, order, 2.0 * scale, 5.0, 9.0)
			_scatter(m, rng, order, 3.5 * scale, wood, 1.8, 3.4)
		"burntplain":
			_scatter(m, rng, order, 10.0 * scale, rock, 1.4, 3.0)
			_ridges(m, rng, order, 2.6 * scale, 5.0, 10.0)
			_scatter(m, rng, order, 0.5 * scale, water, 2.4, 3.4)
			_scatter(m, rng, order, 4.5 * scale, wood, 1.8, 3.6)
		_:
			# Open ground: the fallback when nothing denser stays connected.
			_scatter(m, rng, order, 2.0 * scale, rock, 1.6, 3.0)
			_scatter(m, rng, order, 7.0 * scale, wood, 2.4, 5.0)

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
	if PRIZE_WALLS.has(theme):
		# Whatever was scattered since, the ways in and the ground inside stay
		# open; the prize is shared out round the very middle.
		var wall: Vector3 = PRIZE_WALLS[theme]
		_ring_wall(m, rng, SimMap.Terrain.GROUND, wall.y - 1.0, wall.z + 1.0, true, gate_at)
		_clear_disc(m, centre, int(wall.y) - 3)
		var out: Vector2 = Vector2(cos(gate_at + PI * 0.25), sin(gate_at + PI * 0.25)) * (10.0 if order == 4 else 8.0)
		_add_field(m, order, centre + out, PRIZE_FIELD_AMOUNT / order)
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


## Which kind of country a seed gives within its region. The barrier kind
## only suits two players: it cannot be laid symmetrically between four.
static func _pick_theme(rng: SimRng, order: int, sparse: bool, region: String) -> String:
	var roll: float = rng.next_float()
	if sparse:
		return "open"
	var kinds: Array = REGION_KINDS.get(region, REGION_KINDS["temperate"])
	if order == 2 and roll < 0.28:
		return str(kinds[0])
	var rest: float = (roll - 0.28) / 0.72 if order == 2 else roll
	var others: int = kinds.size() - 1
	return str(kinds[1 + clampi(int(rest * float(others)), 0, others - 1)])


## Paints a ring round the middle of the map, between `inner` and `outer`
## cells from the centre, leaving four gates a quarter turn apart; or, with
## `gates_only`, paints just the four gates (to open them again). The ring
## is the same under quarter and half turns, so it suits both map sizes.
## Returns the direction of the first gate.
static func _ring_wall(m: SimMap, rng: SimRng, terrain: int, inner: float, outer: float, gates_only: bool, first_gate: float = -1.0) -> float:
	var centre: Vector2 = Vector2(float(m.w), float(m.h)) * 0.5
	var first: float = first_gate if first_gate >= 0.0 else rng.range_f(0.0, PI * 0.5)
	var wobble: float = rng.range_f(0.0, TAU) if first_gate < 0.0 else 0.0
	for y: int in m.h:
		for x: int in m.w:
			var d: Vector2 = Vector2(float(x) + 0.5, float(y) + 0.5) - centre
			var r: float = d.length()
			if r < inner - 1.5 or r > outer + 1.5:
				continue
			var ang: float = d.angle()
			# The wall bulges in and out eight times round, so it is not a compass circle.
			var bulge: float = 0.0 if gates_only else sin(ang * 8.0 + wobble) * 0.8
			if r < inner or r > outer + bulge:
				continue
			# How far along the ring this cell is from the middle of the nearest gate.
			var off: float = absf(wrapf(ang - first, -PI * 0.25, PI * 0.25)) * r
			var in_gate: bool = off < PRIZE_GATE_CELLS * 0.5
			if in_gate == gates_only:
				m.set_terrain(Vector2i(x, y), terrain)
	return first


## Oases: a pool with a ring of green round it.
static func _oases(m: SimMap, rng: SimRng, order: int, count: float) -> void:
	for i: int in int(round(count)):
		var at: Vector2 = Vector2(rng.range_f(5.0, float(m.w) - 5.0), rng.range_f(5.0, float(m.h) - 5.0))
		var pool: float = rng.range_f(2.0, 3.2)
		_blob(m, rng, order, SimMap.Terrain.WATER, pool, at)
		var first: float = rng.range_f(0.0, TAU)
		for k: int in 5:
			var ang: float = first + float(k) * TAU / 5.0 + rng.range_f(-0.3, 0.3)
			_blob(m, rng, order, SimMap.Terrain.FOREST, rng.range_f(1.3, 2.1), at + Vector2(cos(ang), sin(ang)) * (pool + 2.0))


## Calderas: a lake of lava with a broken wall of rock round it.
static func _calderas(m: SimMap, rng: SimRng, order: int, count: float) -> void:
	for i: int in int(round(count)):
		var at: Vector2 = Vector2(rng.range_f(6.0, float(m.w) - 6.0), rng.range_f(6.0, float(m.h) - 6.0))
		var pool: float = rng.range_f(2.6, 3.8)
		var first: float = rng.range_f(0.0, TAU)
		# Rock first, so the lava cuts a clean edge into it; two gaps in the wall.
		for k: int in 7:
			if k == 2 or k == 5:
				continue
			var ang: float = first + float(k) * TAU / 7.0
			_blob(m, rng, order, SimMap.Terrain.ROCK, rng.range_f(1.4, 2.0), at + Vector2(cos(ang), sin(ang)) * (pool + 1.6))
		_blob(m, rng, order, SimMap.Terrain.WATER, pool, at)


## `count` irregular blobs of one terrain at random places.
static func _scatter(m: SimMap, rng: SimRng, order: int, count: float, terrain: int, r_min: float, r_max: float) -> void:
	for i: int in int(round(count)):
		var at: Vector2 = Vector2(rng.range_f(2.0, float(m.w) - 2.0), rng.range_f(2.0, float(m.h) - 2.0))
		_blob(m, rng, order, terrain, rng.range_f(r_min, r_max), at)


## Paints an irregular blob centred on cell position `at`, and its symmetric
## images. Forest only takes open ground, so it never bridges water or rock.
static func _blob(m: SimMap, rng: SimRng, order: int, terrain: int, radius_cells: float, at: Vector2) -> void:
	var squash: float = rng.range_f(0.55, 1.0)
	var tilt: float = rng.range_f(0.0, PI)
	var w1: float = rng.range_f(0.0, TAU)
	var w2: float = rng.range_f(0.0, TAU)
	var w3: float = rng.range_f(0.0, TAU)
	var r: int = int(ceilf(radius_cells * 1.45)) + 1
	for dy: int in range(-r, r + 1):
		for dx: int in range(-r, r + 1):
			var v: Vector2 = Vector2(float(dx), float(dy)).rotated(tilt)
			v.y /= squash
			var ang: float = v.angle()
			var edge: float = radius_cells * (1.0 + 0.20 * sin(ang * 3.0 + w1) + 0.13 * sin(ang * 5.0 + w2) + 0.07 * sin(ang * 9.0 + w3))
			if v.length() <= edge:
				_paint(m, order, Vector2i(int(at.x) + dx, int(at.y) + dy), terrain)


## Sets one cell and its symmetric images.
static func _paint(m: SimMap, order: int, c: Vector2i, terrain: int) -> void:
	for image: Vector2i in cell_images(m, c, order):
		if not m.in_bounds(image):
			continue
		if terrain == SimMap.Terrain.FOREST and m.terrain_cell(image) != SimMap.Terrain.GROUND:
			continue
		m.set_terrain(image, terrain)


## A filled circle of one terrain around cell position `at`, with its images.
static func _disc(m: SimMap, order: int, at: Vector2, radius_cells: float, terrain: int) -> void:
	var r: int = int(ceilf(radius_cells)) + 1
	var c0: Vector2i = Vector2i(int(floor(at.x)), int(floor(at.y)))
	for dy: int in range(-r, r + 1):
		for dx: int in range(-r, r + 1):
			var c: Vector2i = Vector2i(c0.x + dx, c0.y + dy)
			if Vector2(float(c.x) + 0.5 - at.x, float(c.y) + 0.5 - at.y).length() <= radius_cells:
				_paint(m, order, c, terrain)


## Ridges: long, slightly bent walls of rock (or, as fissures, of lava). The
## longer ones have a pass cut through them, so a ridge shapes the fighting
## without sealing anything off.
static func _ridges(m: SimMap, rng: SimRng, order: int, count: float, len_min: float, len_max: float, terrain: int = SimMap.Terrain.ROCK, girth_min: float = 1.2, girth_max: float = 1.9) -> void:
	for i: int in int(round(count)):
		var mid: Vector2 = Vector2(rng.range_f(5.0, float(m.w) - 5.0), rng.range_f(5.0, float(m.h) - 5.0))
		var length: float = rng.range_f(len_min, len_max)
		var along: Vector2 = Vector2.RIGHT.rotated(rng.range_f(0.0, PI))
		var bend: float = rng.range_f(-0.3, 0.3) * length
		var girth: float = rng.range_f(girth_min, girth_max)
		var pass_at: float = rng.range_f(0.35, 0.65) if length >= 8.0 else -1.0
		var steps: int = int(length / 0.7)
		for k: int in steps + 1:
			var t: float = float(k) / float(steps)
			if pass_at >= 0.0 and absf(t - pass_at) * length < 1.9:
				continue
			var at: Vector2 = mid + along * (t - 0.5) * length + along.orthogonal() * bend * sin(t * PI)
			_disc(m, order, at, girth * rng.range_f(0.75, 1.15), terrain)


## A barrier across the middle of a two-player map: a river, a river of lava
## or a long ridge of rock, depending on the region. It runs between the two
## far corners so it lies square across the way from one base to the other.
## It can be crossed at the centre of the map, at two fords on each arm, and
## round both ends, where it runs out into a small lake short of the corner.
static func _river(m: SimMap, rng: SimRng, terrain: int) -> void:
	var n: float = float(m.w)
	var centre: Vector2 = Vector2(n * 0.5, n * 0.5)
	var along: Vector2 = Vector2(1.0, -1.0).normalized()
	var across: Vector2 = Vector2(1.0, 1.0).normalized()
	var length: float = n * 0.7071 * rng.range_f(0.60, 0.72)
	var swing: float = rng.range_f(2.0, 4.5)
	var waves: float = rng.range_f(1.4, 2.4)
	var phase: float = rng.range_f(0.0, TAU)
	var ford_at: Array[float] = [rng.range_f(0.30, 0.40), rng.range_f(0.62, 0.74)]
	var steps: int = int(length / 0.6)
	var fords: Array[Vector2] = []
	var mouth: Vector2 = centre
	for k: int in steps + 1:
		var t: float = float(k) / float(steps)
		# The meander dies away towards the centre, where the two arms meet.
		var at: Vector2 = centre + along * t * length + across * swing * sin(t * waves * PI + phase) * minf(1.0, t * 4.0)
		_disc(m, 2, at, rng.range_f(1.5, 2.1), terrain)
		for want: float in ford_at:
			if absf(t - want) < 0.5 / float(steps):
				fords.append(at)
		mouth = at
	_blob(m, rng, 2, terrain, rng.range_f(2.6, 3.4), mouth)
	_disc(m, 2, centre, 3.2, SimMap.Terrain.GROUND)
	for ford: Vector2 in fords:
		_disc(m, 2, ford, 2.8, SimMap.Terrain.GROUND)
	# Woods along the banks.
	for k: int in 3:
		var t: float = rng.range_f(0.12, 0.9)
		var bank: float = (1.0 if rng.chance(0.5) else -1.0) * rng.range_f(4.5, 6.5)
		_blob(m, rng, 2, SimMap.Terrain.FOREST, rng.range_f(2.0, 3.2), centre + along * t * length + across * bank)


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


## Every start must reach every other start, every salvage field and every
## uplink site.
static func _starts_connected(m: SimMap) -> bool:
	if m.starts.size() < 2:
		return true
	var targets: Array[Vector2] = []
	for i: int in range(1, m.starts.size()):
		targets.append(m.starts[i])
	for f: Vector3 in m.field_spots:
		targets.append(Vector2(f.x, f.y))
	for u: Vector2 in m.uplink_spots:
		targets.append(u)
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
	var home: String = str(d.get("region", "temperate"))
	m.region = home if REGIONS.has(home) else "temperate"
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
