class_name SimMap
extends RefCounted
## The battlefield grid: terrain, building occupancy, pathfinding and the
## cosmetic height field. One cell is CELL x CELL world units. World
## coordinates are Vector2(x, z).

const CELL: float = 2.0

enum Terrain { GROUND, FOREST, ROCK, WATER }

var name: String = "Unnamed"
var w: int = 0  ## width in cells
var h: int = 0  ## height in cells
var terrain: PackedByteArray = PackedByteArray()
var occupant: PackedInt32Array = PackedInt32Array()  ## building id per cell, 0 = free
var heights: PackedFloat32Array = PackedFloat32Array()  ## (w+1)*(h+1) corner heights, cosmetic

var starts: Array[Vector2] = []  ## player start positions
var field_spots: Array[Vector3] = []  ## salvage fields: x, z, amount
var uplink_spots: Array[Vector2] = []

var _astar_inf: AStarGrid2D = null
var _astar_veh: AStarGrid2D = null


func setup(width: int, height: int) -> void:
	w = width
	h = height
	terrain = PackedByteArray()
	terrain.resize(w * h)
	occupant = PackedInt32Array()
	occupant.resize(w * h)
	heights = PackedFloat32Array()
	heights.resize((w + 1) * (h + 1))


## Call after the terrain has been filled in. Builds the pathfinding grids.
func finalize() -> void:
	_astar_inf = _make_grid()
	_astar_veh = _make_grid()
	for y: int in h:
		for x: int in w:
			_refresh_cell(Vector2i(x, y))


func _make_grid() -> AStarGrid2D:
	var g: AStarGrid2D = AStarGrid2D.new()
	g.region = Rect2i(0, 0, w, h)
	g.cell_size = Vector2(CELL, CELL)
	g.offset = Vector2(CELL * 0.5, CELL * 0.5)
	g.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	g.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	g.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	g.update()
	return g


func _refresh_cell(c: Vector2i) -> void:
	var solid: bool = not is_cell_passable(c)
	_astar_inf.set_point_solid(c, solid)
	_astar_veh.set_point_solid(c, solid)
	var weight: float = 1.0
	if terrain[c.y * w + c.x] == Terrain.FOREST:
		weight = 2.0
	_astar_veh.set_point_weight_scale(c, weight)


func world_size() -> Vector2:
	return Vector2(float(w) * CELL, float(h) * CELL)


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < w and c.y < h


func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(int(floorf(p.x / CELL)), int(floorf(p.y / CELL)))


func cell_center(c: Vector2i) -> Vector2:
	return Vector2((float(c.x) + 0.5) * CELL, (float(c.y) + 0.5) * CELL)


func clamp_to_map(p: Vector2) -> Vector2:
	var size: Vector2 = world_size()
	return Vector2(clampf(p.x, 0.5, size.x - 0.5), clampf(p.y, 0.5, size.y - 0.5))


func terrain_cell(c: Vector2i) -> int:
	if not in_bounds(c):
		return Terrain.ROCK
	return terrain[c.y * w + c.x]


func terrain_at(p: Vector2) -> int:
	return terrain_cell(cell_of(p))


func set_terrain(c: Vector2i, t: int) -> void:
	if in_bounds(c):
		terrain[c.y * w + c.x] = t


func is_cell_passable(c: Vector2i) -> bool:
	if not in_bounds(c):
		return false
	var i: int = c.y * w + c.x
	var t: int = terrain[i]
	return occupant[i] == 0 and (t == Terrain.GROUND or t == Terrain.FOREST)


func is_passable(p: Vector2) -> bool:
	return is_cell_passable(cell_of(p))


## True if a building footprint could stand on these cells (terrain only).
func is_cell_buildable(c: Vector2i) -> bool:
	if not in_bounds(c):
		return false
	var i: int = c.y * w + c.x
	return occupant[i] == 0 and terrain[i] == Terrain.GROUND


func occupant_at(c: Vector2i) -> int:
	if not in_bounds(c):
		return 0
	return occupant[c.y * w + c.x]


## Marks (id != 0) or clears (id == 0) a building footprint.
func set_occupied(rect: Rect2i, id: int) -> void:
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			var c: Vector2i = Vector2i(x, y)
			if in_bounds(c):
				occupant[y * w + x] = id
				if _astar_inf != null:
					_refresh_cell(c)


## Nearest passable cell to `c`, searching outward in rings. Returns `c`
## itself when it is passable, or (-1, -1) when nothing is found.
func nearest_free_cell(c: Vector2i, max_ring: int = 12) -> Vector2i:
	if is_cell_passable(c):
		return c
	var best: Vector2i = Vector2i(-1, -1)
	var best_d: int = 1 << 30
	for r: int in range(1, max_ring + 1):
		for dy: int in range(-r, r + 1):
			for dx: int in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var n: Vector2i = Vector2i(c.x + dx, c.y + dy)
				if is_cell_passable(n):
					var d: int = dx * dx + dy * dy
					if d < best_d:
						best_d = d
						best = n
		if best.x >= 0:
			return best
	return best


## Nearest passable world position to `p`.
func nearest_free_pos(p: Vector2) -> Vector2:
	if is_passable(p):
		return p
	var c: Vector2i = nearest_free_cell(cell_of(p))
	if c.x < 0:
		return p
	return cell_center(c)


## True if a unit can walk the straight segment a→b. With `avoid_forest`
## (vehicles) forest cells also break the line unless an endpoint is in forest.
func line_clear(a: Vector2, b: Vector2, avoid_forest: bool = false) -> bool:
	var d: Vector2 = b - a
	var dist: float = d.length()
	if dist < 0.001:
		return is_passable(a)
	var steps: int = int(ceilf(dist / 0.5))
	var dir: Vector2 = d / dist
	var side: Vector2 = Vector2(-dir.y, dir.x) * 0.55
	var forest_ok: bool = not avoid_forest
	if avoid_forest and (terrain_at(a) == Terrain.FOREST or terrain_at(b) == Terrain.FOREST):
		forest_ok = true
	for i: int in range(0, steps + 1):
		var p: Vector2 = a + d * (float(i) / float(steps))
		if not is_passable(p) or not is_passable(p + side) or not is_passable(p - side):
			return false
		if not forest_ok and terrain_at(p) == Terrain.FOREST:
			return false
	return true


## Grid path from a to b as world waypoints (excluding the start), smoothed.
## Returns an empty array when there is no way at all. When b is blocked the
## path leads to the nearest free cell.
func find_path(a: Vector2, b: Vector2, vehicle: bool) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var ca: Vector2i = nearest_free_cell(cell_of(clamp_to_map(a)))
	var goal: Vector2 = clamp_to_map(b)
	var cb: Vector2i = cell_of(goal)
	var goal_free: bool = is_cell_passable(cb)
	if not goal_free:
		cb = nearest_free_cell(cb)
	if ca.x < 0 or cb.x < 0:
		return out
	if ca == cb:
		out.append(goal if goal_free else cell_center(cb))
		return out
	var grid: AStarGrid2D = _astar_veh if vehicle else _astar_inf
	var raw: PackedVector2Array = grid.get_point_path(ca, cb, true)
	if raw.size() == 0:
		return out
	var reached: bool = cell_of(raw[raw.size() - 1]) == cb
	# String-pull: drop waypoints that can be skipped in a straight line.
	var anchor: Vector2 = a
	var i: int = 0
	if not is_passable(a):
		anchor = raw[0]
	var anchor_start: Vector2 = anchor
	while i < raw.size():
		var far: int = i
		var j: int = mini(raw.size() - 1, i + 12)
		while j > i:
			if line_clear(anchor, raw[j], vehicle):
				far = j
				break
			j -= 1
		out.append(raw[far])
		anchor = raw[far]
		i = far + 1
	if reached and goal_free and out.size() > 0:
		# Finish on the exact requested point rather than the cell centre.
		var before: Vector2 = out[out.size() - 2] if out.size() >= 2 else anchor_start
		if line_clear(before, goal, vehicle):
			out[out.size() - 1] = goal
		else:
			out.append(goal)
	return out


## Cosmetic ground height at a world position (bilinear over corner heights).
func height_at(p: Vector2) -> float:
	var fx: float = clampf(p.x / CELL, 0.0, float(w) - 0.001)
	var fy: float = clampf(p.y / CELL, 0.0, float(h) - 0.001)
	var x0: int = int(fx)
	var y0: int = int(fy)
	var tx: float = fx - float(x0)
	var ty: float = fy - float(y0)
	var row: int = w + 1
	var h00: float = heights[y0 * row + x0]
	var h10: float = heights[y0 * row + x0 + 1]
	var h01: float = heights[(y0 + 1) * row + x0]
	var h11: float = heights[(y0 + 1) * row + x0 + 1]
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), ty)
