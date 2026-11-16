class_name SimTestUtil
extends RefCounted
## Helpers shared by the simulation tests.


## A blank-map world with two opposing Aegis players and no starting units.
static func make_world(seed_value: int = 1, size_cells: int = 32) -> SimWorld:
	var data: GameData = GameData.shared()
	var map: SimMap = SimMapGen.blank(size_cells)
	var w: SimWorld = SimWorld.new(data, map, seed_value)
	w.victory_enabled = false
	w.add_player("aegis", Color(0.2, 0.5, 1.0), false, map.starts[0], "Blue")
	w.add_player("aegis", Color(1.0, 0.3, 0.2), false, map.starts[1], "Red")
	# Tests fund themselves generously unless they are about money.
	for p: SimPlayer in w.players:
		p.salvage = 100000
	return w


## Lets every player see the whole map, for tests that are not about fog.
static func reveal_all(w: SimWorld) -> void:
	var size: Vector2 = w.map.world_size()
	for p: SimPlayer in w.players:
		w.reveals.append(Vector4(size.x * 0.5, size.y * 0.5, size.length(), float(p.id)))
	SimVision.recompute(w)


static func run(w: SimWorld, ticks: int) -> void:
	for i: int in ticks:
		w.tick()


static func ids_of(units: Array[SimEntity]) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for e: SimEntity in units:
		out.append(e.id)
	return out


static func spawn_group(w: SimWorld, def_id: String, owner: int, at: Vector2, count: int) -> Array[SimEntity]:
	var out: Array[SimEntity] = []
	var cols: int = int(ceilf(sqrt(float(count))))
	for i: int in count:
		var offset: Vector2 = Vector2(float(i % cols) * 2.4, float(i / cols) * 2.4)
		out.append(w.spawn_unit(def_id, owner, at + offset))
	return out


static func alive_units(w: SimWorld, owner: int) -> int:
	return w.count_units(owner)
