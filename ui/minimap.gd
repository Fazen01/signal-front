class_name Minimap
extends Control
## North-up map of the battlefield: terrain, fog, own coverage, everything
## the player can see, the camera's view box and alert pings. Left click or
## drag moves the camera; right click orders the selection there.

var battle: BattleScene = null
var world: SimWorld = null
var player: int = 0
var _texture: ImageTexture = null
var _version: int = -1
var _signal_version: int = -1
var _pings: Array[Vector3] = []  ## x, z, age
var _dragging: bool = false


func setup(scene: BattleScene) -> void:
	battle = scene
	world = scene.world
	player = scene.local_player
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var map: SimMap = world.map
	_texture = ImageTexture.create_from_image(Image.create(map.w, map.h, false, Image.FORMAT_RGBA8))
	_refresh_texture()


## Flash a ring at a world position (alerts, attacks).
func ping(at: Vector2) -> void:
	for p: Vector3 in _pings:
		if Vector2(p.x, p.y).distance_to(at) < 8.0 and p.z < 1.0:
			return
	_pings.append(Vector3(at.x, at.y, 0.0))


func _process(delta: float) -> void:
	if world == null:
		return
	if world.vision_version != _version or world.coverage_version != _signal_version:
		_refresh_texture()
	var kept: Array[Vector3] = []
	for p: Vector3 in _pings:
		if p.z + delta < 3.0:
			kept.append(Vector3(p.x, p.y, p.z + delta))
	_pings = kept
	queue_redraw()


func _terrain_color(t: int) -> Color:
	match t:
		SimMap.Terrain.FOREST:
			return Color(0.16, 0.30, 0.16)
		SimMap.Terrain.ROCK:
			return Color(0.45, 0.44, 0.42)
		SimMap.Terrain.WATER:
			return Color(0.16, 0.32, 0.48)
		_:
			return Color(0.33, 0.41, 0.23)


func _refresh_texture() -> void:
	_version = world.vision_version
	_signal_version = world.coverage_version
	var map: SimMap = world.map
	var vis: PackedByteArray = world.visible[player]
	var seen: PackedByteArray = world.explored[player]
	var cover: PackedByteArray = world.coverage[player]
	var team: Color = world.players[player].color
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(map.w * map.h * 4)
	var n: int = map.w * map.h
	for i: int in n:
		var c: Color = Color(0.02, 0.03, 0.04)
		if seen[i] != 0:
			c = _terrain_color(map.terrain[i])
			if cover[i] != 0:
				c = c.lerp(team, 0.3)
			if vis[i] == 0:
				c = c.darkened(0.5)
		var o: int = i * 4
		bytes[o] = int(c.r * 255.0)
		bytes[o + 1] = int(c.g * 255.0)
		bytes[o + 2] = int(c.b * 255.0)
		bytes[o + 3] = 255
	_texture.update(Image.create_from_data(map.w, map.h, false, Image.FORMAT_RGBA8, bytes))


func _to_map(world_pos: Vector2) -> Vector2:
	var ws: Vector2 = world.map.world_size()
	return Vector2(world_pos.x / ws.x * size.x, world_pos.y / ws.y * size.y)


func _to_world(local: Vector2) -> Vector2:
	var ws: Vector2 = world.map.world_size()
	return Vector2(clampf(local.x / size.x, 0.0, 1.0) * ws.x, clampf(local.y / size.y, 0.0, 1.0) * ws.y)


func _draw() -> void:
	if world == null:
		return
	var full: Rect2 = Rect2(Vector2.ZERO, size)
	draw_texture_rect(_texture, full, false)
	for e: SimEntity in world.entities:
		if not e.alive or not battle.world_view.is_shown(e.id):
			continue
		var p: Vector2 = _to_map(e.pos)
		match e.kind:
			SimEntity.Kind.FIELD:
				draw_rect(Rect2(p - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), Color(1.0, 0.82, 0.3))
			SimEntity.Kind.UPLINK:
				var col: Color = Color(0.95, 0.95, 1.0) if e.owner < 0 else world.players[e.owner].color.lightened(0.3)
				draw_circle(p, 3.5, col)
				draw_arc(p, 5.0, 0.0, TAU, 12, col, 1.0)
			SimEntity.Kind.BUILDING:
				var half: float = maxf(2.0, e.radius / world.map.world_size().x * size.x)
				draw_rect(Rect2(p - Vector2(half, half), Vector2(half, half) * 2.0), world.players[e.owner].color)
			SimEntity.Kind.UNIT:
				draw_circle(p, 1.8, world.players[e.owner].color.lightened(0.25))
			_:
				pass
	# The camera's view of the ground.
	var ctl: SelectionController = battle.controller
	var view: Vector2 = get_viewport_rect().size
	var corners: PackedVector2Array = PackedVector2Array()
	for sp: Vector2 in [Vector2(0.0, 0.0), Vector2(view.x, 0.0), Vector2(view.x, view.y), Vector2(0.0, view.y)]:
		var g: Vector2 = _to_map(ctl.ground_point(sp))
		corners.append(Vector2(clampf(g.x, -40.0, size.x + 40.0), clampf(g.y, -40.0, size.y + 40.0)))
	corners.append(corners[0])
	draw_polyline(corners, Color(1.0, 1.0, 1.0, 0.85), 1.0)
	for ping_data: Vector3 in _pings:
		var t: float = fposmod(ping_data.z, 1.0)
		var at: Vector2 = _to_map(Vector2(ping_data.x, ping_data.y))
		draw_arc(at, lerpf(3.0, 16.0, t), 0.0, TAU, 20, Color(1.0, 0.3, 0.25, 1.0 - t), 2.0)
	draw_rect(full, Color(0.25, 0.55, 0.9, 0.8), false, 1.0)


func _gui_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null:
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
			if mb.pressed:
				battle.cam.center_on(_to_world(mb.position))
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			battle.controller.order_at_world(_to_world(mb.position), mb.shift_pressed)
		accept_event()
		return
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null and _dragging:
		battle.cam.center_on(_to_world(mm.position))
		accept_event()
