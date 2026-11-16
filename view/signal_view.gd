class_name SignalView
extends Node3D
## Draws the local player's Signal Grid: a soft tinted ground overlay for
## coverage (uncovered ground is dimmed) and animated link lines between
## emitters. Rebuilt only when the simulation's coverage changes.

var world: SimWorld = null
var player: int = 0
var _overlay: MeshInstance3D = null
var _image: Image = null
var _texture: ImageTexture = null
var _version: int = -1
var _lines: Node3D = null
var _beads: Array[MeshInstance3D] = []
var _bead_from: Array[Vector3] = []
var _bead_to: Array[Vector3] = []
var _time: float = 0.0


func setup(sim_world: SimWorld, local_player: int) -> void:
	world = sim_world
	player = local_player
	_build_overlay()
	_lines = Node3D.new()
	_lines.name = "Links"
	add_child(_lines)
	refresh()


func set_overlay_visible(on: bool) -> void:
	_overlay.visible = on


func is_overlay_visible() -> bool:
	return _overlay.visible


## A mesh that hugs the terrain `lift` above it, with UVs spanning the map,
## for ground overlays driven by a map-sized texture.
static func build_overlay_mesh(map: SimMap, lift: float) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var row: int = map.w + 1
	for y: int in range(0, map.h + 1):
		for x: int in range(0, map.w + 1):
			st.set_uv(Vector2(float(x) / float(map.w), float(y) / float(map.h)))
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(float(x) * SimMap.CELL, map.heights[y * row + x] + lift, float(y) * SimMap.CELL))
	for y: int in map.h:
		for x: int in map.w:
			var i: int = y * row + x
			st.add_index(i)
			st.add_index(i + 1)
			st.add_index(i + row + 1)
			st.add_index(i)
			st.add_index(i + row + 1)
			st.add_index(i + row)
	return st.commit()


func _build_overlay() -> void:
	var map: SimMap = world.map
	_image = Image.create(map.w, map.h, false, Image.FORMAT_RGBA8)
	_texture = ImageTexture.create_from_image(_image)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = _texture
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.render_priority = 1
	_overlay = MeshInstance3D.new()
	_overlay.name = "CoverageOverlay"
	_overlay.mesh = build_overlay_mesh(map, 0.12)
	_overlay.material_override = mat
	_overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_overlay)


func _process(delta: float) -> void:
	if world == null:
		return
	if world.coverage_version != _version:
		refresh()
	_time += delta
	for i: int in _beads.size():
		var t: float = fposmod(_time * 0.45 + float(i) * 0.37, 1.0)
		_beads[i].position = _bead_from[i].lerp(_bead_to[i], t)


## Re-reads coverage and links from the simulation.
func refresh() -> void:
	_version = world.coverage_version
	var map: SimMap = world.map
	var grid: PackedByteArray = world.coverage[player]
	var team: Color = world.players[player].color
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(map.w * map.h * 4)
	var team_r: int = int(team.r * 255.0)
	var team_g: int = int(team.g * 255.0)
	var team_b: int = int(team.b * 255.0)
	for y: int in map.h:
		for x: int in map.w:
			var i: int = y * map.w + x
			var o: int = i * 4
			if grid[i] != 0:
				# Cells on the rim of coverage glow a little brighter.
				var rim: bool = false
				if x == 0 or y == 0 or x == map.w - 1 or y == map.h - 1:
					rim = false
				elif grid[i - 1] == 0 or grid[i + 1] == 0 or grid[i - map.w] == 0 or grid[i + map.w] == 0:
					rim = true
				bytes[o] = team_r
				bytes[o + 1] = team_g
				bytes[o + 2] = team_b
				bytes[o + 3] = 120 if rim else 24
			else:
				bytes[o] = 0
				bytes[o + 1] = 0
				bytes[o + 2] = 0
				bytes[o + 3] = 44
	_image = Image.create_from_data(map.w, map.h, false, Image.FORMAT_RGBA8, bytes)
	_texture.update(_image)
	_rebuild_links()


func _mast_top(e: SimEntity) -> Vector3:
	var lift: float = 7.3 if e.def.signal_root else 4.6
	var off: Vector2 = Vector2(0.9, 0.9) if e.def.signal_root else Vector2.ZERO
	return Vector3(e.pos.x + off.x, world.map.height_at(e.pos) + lift, e.pos.y + off.y)


func _rebuild_links() -> void:
	for child: Node in _lines.get_children():
		_lines.remove_child(child)
		child.queue_free()
	_beads.clear()
	_bead_from.clear()
	_bead_to.clear()
	var team: Color = world.players[player].color
	var line_mat: StandardMaterial3D = StandardMaterial3D.new()
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.albedo_color = Color(team.r, team.g, team.b, 0.55)
	line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var bead_mat: StandardMaterial3D = StandardMaterial3D.new()
	bead_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bead_mat.albedo_color = team.lightened(0.6)
	var line_mesh: BoxMesh = BoxMesh.new()
	line_mesh.size = Vector3(0.09, 0.09, 1.0)
	var bead_mesh: SphereMesh = SphereMesh.new()
	bead_mesh.radius = 0.22
	bead_mesh.height = 0.44
	bead_mesh.radial_segments = 6
	bead_mesh.rings = 3
	var links: PackedInt32Array = world.signal_links[player]
	var i: int = 0
	while i + 1 < links.size():
		var a: SimEntity = world.get_entity(links[i])
		var b: SimEntity = world.get_entity(links[i + 1])
		i += 2
		if a == null or b == null:
			continue
		var from: Vector3 = _mast_top(a)
		var to: Vector3 = _mast_top(b)
		var line: MeshInstance3D = MeshInstance3D.new()
		line.mesh = line_mesh
		line.material_override = line_mat
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_lines.add_child(line)
		line.look_at_from_position((from + to) * 0.5, to, Vector3.UP)
		line.scale = Vector3(1.0, 1.0, from.distance_to(to))
		var bead: MeshInstance3D = MeshInstance3D.new()
		bead.mesh = bead_mesh
		bead.material_override = bead_mat
		bead.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_lines.add_child(bead)
		_beads.append(bead)
		_bead_from.append(from)
		_bead_to.append(to)
