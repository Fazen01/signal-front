class_name TerrainView
extends Node3D
## Builds the battlefield visuals from a SimMap: a flat-shaded ground mesh,
## water, trees on forest cells and boulders on rock cells. All geometry is
## generated here; nothing is loaded from disk.

const WATER_LEVEL: float = -0.45

var map: SimMap = null
var _rng: SimRng = null
var _prop_meshes: Array[MultiMesh] = []
var _prop_cells: Array[PackedInt32Array] = []  ## map cell index of each instance
var _prop_state: Array[PackedByteArray] = []  ## last fog state applied per instance


func build(sim_map: SimMap, seed_value: int) -> void:
	map = sim_map
	_rng = SimRng.new(seed_value + 4711)
	_build_ground()
	_build_water()
	_build_trees()
	_build_rocks()
	_build_skirt()


func _cell_color(t: int, shade: float) -> Color:
	var c: Color
	match t:
		SimMap.Terrain.FOREST:
			c = Color(0.20, 0.33, 0.17)
		SimMap.Terrain.ROCK:
			c = Color(0.42, 0.40, 0.38)
		SimMap.Terrain.WATER:
			c = Color(0.36, 0.34, 0.26)
		_:
			c = Color(0.36, 0.44, 0.24)
	return c.lightened(shade) if shade >= 0.0 else c.darkened(-shade)


func _corner(x: int, y: int) -> Vector3:
	return Vector3(float(x) * SimMap.CELL, map.heights[y * (map.w + 1) + x], float(y) * SimMap.CELL)


func _build_ground() -> void:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for y: int in map.h:
		for x: int in map.w:
			var t: int = map.terrain_cell(Vector2i(x, y))
			var shade: float = _rng.range_f(-0.07, 0.07)
			var col: Color = _cell_color(t, shade)
			var p00: Vector3 = _corner(x, y)
			var p10: Vector3 = _corner(x + 1, y)
			var p01: Vector3 = _corner(x, y + 1)
			var p11: Vector3 = _corner(x + 1, y + 1)
			_tri(st, p00, p10, p11, col)
			_tri(st, p00, p11, p01, col.darkened(0.03))
	var mesh: ArrayMesh = st.commit()
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Ground"
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	var n: Vector3 = (b - a).cross(c - a).normalized()
	if n.y < 0.0:
		n = -n
	st.set_color(col)
	st.set_normal(n)
	st.add_vertex(a)
	st.set_color(col)
	st.set_normal(n)
	st.add_vertex(b)
	st.set_color(col)
	st.set_normal(n)
	st.add_vertex(c)


func _build_water() -> void:
	var size: Vector2 = map.world_size()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = size
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.36, 0.50, 0.82)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.25
	mat.metallic = 0.2
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Water"
	mi.mesh = plane
	mi.material_override = mat
	mi.position = Vector3(size.x * 0.5, WATER_LEVEL, size.y * 0.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## A dark apron around the map so the edge does not float in the void.
func _build_skirt() -> void:
	var size: Vector2 = map.world_size()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = size * 4.0
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.03, 0.04, 0.05)
	mat.roughness = 1.0
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Skirt"
	mi.mesh = plane
	mi.material_override = mat
	mi.position = Vector3(size.x * 0.5, -1.6, size.y * 0.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _build_trees() -> void:
	var spots: Array[Transform3D] = []
	for y: int in map.h:
		for x: int in map.w:
			if map.terrain_cell(Vector2i(x, y)) != SimMap.Terrain.FOREST:
				continue
			var count: int = _rng.range_i(2, 3)
			for i: int in count:
				var p: Vector2 = Vector2(
					(float(x) + _rng.range_f(0.12, 0.88)) * SimMap.CELL,
					(float(y) + _rng.range_f(0.12, 0.88)) * SimMap.CELL
				)
				var s: float = _rng.range_f(0.75, 1.35)
				var xf: Basis = Basis(Vector3.UP, _rng.range_f(0.0, TAU)).scaled(Vector3(s, s * _rng.range_f(0.9, 1.3), s))
				spots.append(Transform3D(xf, Vector3(p.x, map.height_at(p), p.y)))
	if spots.is_empty():
		return
	var trunk: CylinderMesh = CylinderMesh.new()
	trunk.top_radius = 0.09
	trunk.bottom_radius = 0.13
	trunk.height = 0.7
	trunk.radial_segments = 5
	trunk.rings = 1
	var lower: CylinderMesh = CylinderMesh.new()
	lower.top_radius = 0.0
	lower.bottom_radius = 0.62
	lower.height = 1.2
	lower.radial_segments = 6
	lower.rings = 1
	var upper: CylinderMesh = CylinderMesh.new()
	upper.top_radius = 0.0
	upper.bottom_radius = 0.44
	upper.height = 0.95
	upper.radial_segments = 6
	upper.rings = 1
	var st_trunk: SurfaceTool = SurfaceTool.new()
	st_trunk.append_from(trunk, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.35, 0.0)))
	var mesh: ArrayMesh = st_trunk.commit()
	var st_leaf: SurfaceTool = SurfaceTool.new()
	st_leaf.append_from(lower, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, 1.2, 0.0)))
	st_leaf.append_from(upper, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, 1.95, 0.0)))
	st_leaf.commit(mesh)
	var bark: StandardMaterial3D = StandardMaterial3D.new()
	bark.albedo_color = Color(0.30, 0.22, 0.15)
	bark.roughness = 1.0
	bark.vertex_color_use_as_albedo = true
	var leaf: StandardMaterial3D = StandardMaterial3D.new()
	leaf.albedo_color = Color(0.16, 0.36, 0.18)
	leaf.roughness = 1.0
	leaf.vertex_color_use_as_albedo = true
	mesh.surface_set_material(0, bark)
	mesh.surface_set_material(1, leaf)
	_add_multimesh("Trees", mesh, spots, true)


func _build_rocks() -> void:
	var spots: Array[Transform3D] = []
	for y: int in map.h:
		for x: int in map.w:
			if map.terrain_cell(Vector2i(x, y)) != SimMap.Terrain.ROCK:
				continue
			if not _rng.chance(0.6):
				continue
			var p: Vector2 = Vector2(
				(float(x) + _rng.range_f(0.25, 0.75)) * SimMap.CELL,
				(float(y) + _rng.range_f(0.25, 0.75)) * SimMap.CELL
			)
			var s: float = _rng.range_f(0.7, 1.5)
			var tilt: Basis = Basis.from_euler(Vector3(_rng.range_f(-0.3, 0.3), _rng.range_f(0.0, TAU), _rng.range_f(-0.3, 0.3)))
			var xf: Basis = tilt.scaled(Vector3(s, s * _rng.range_f(0.7, 1.5), s))
			spots.append(Transform3D(xf, Vector3(p.x, map.height_at(p) + 0.2, p.y)))
	if spots.is_empty():
		return
	var rock: SphereMesh = SphereMesh.new()
	rock.radius = 0.95
	rock.height = 1.7
	rock.radial_segments = 6
	rock.rings = 3
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.47, 0.45, 0.43)
	mat.roughness = 1.0
	mat.vertex_color_use_as_albedo = true
	rock.material = mat
	_add_multimesh("Rocks", rock, spots, true)


## Darkens trees and boulders that stand in fog so they do not glow out of
## it. `vis` and `seen` are the local player's visible / explored grids.
func apply_fog(vis: PackedByteArray, seen: PackedByteArray) -> void:
	for m: int in _prop_meshes.size():
		var mm: MultiMesh = _prop_meshes[m]
		var cells: PackedInt32Array = _prop_cells[m]
		var state: PackedByteArray = _prop_state[m]
		for i: int in cells.size():
			var cell: int = cells[i]
			var now: int = 2 if vis[cell] != 0 else (1 if seen[cell] != 0 else 0)
			if now != state[i]:
				state[i] = now
				var b: float = 1.0 if now == 2 else (0.5 if now == 1 else 0.13)
				mm.set_instance_color(i, Color(b, b, b))
		_prop_state[m] = state


func _add_multimesh(node_name: String, mesh: Mesh, spots: Array[Transform3D], shadows: bool) -> void:
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = spots.size()
	var cells: PackedInt32Array = PackedInt32Array()
	var state: PackedByteArray = PackedByteArray()
	for i: int in spots.size():
		mm.set_instance_transform(i, spots[i])
		mm.set_instance_color(i, Color.WHITE)
		var c: Vector2i = map.cell_of(Vector2(spots[i].origin.x, spots[i].origin.z))
		cells.append(clampi(c.y, 0, map.h - 1) * map.w + clampi(c.x, 0, map.w - 1))
		state.append(2)
	_prop_meshes.append(mm)
	_prop_cells.append(cells)
	_prop_state.append(state)
	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	if not shadows:
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
