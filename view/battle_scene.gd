class_name BattleScene
extends Node3D
## The match scene. Owns the SimWorld, advances it at a fixed 20 Hz, and
## wires up the terrain, entity views, camera, controls and HUD.

var config: MatchConfig = null
var world: SimWorld = null
var local_player: int = 0
var paused: bool = false
var time_scale: float = 1.0

var terrain: TerrainView = null
var world_view: WorldView = null
var cam: RtsCamera = null
var controller: SelectionController = null
var overlay: BattleOverlay = null
var ui_layer: CanvasLayer = null

var _accum: float = 0.0
var _markers: Array[MeshInstance3D] = []
var _marker_age: Array[float] = []


func _ready() -> void:
	var game: GameState = get_node_or_null("/root/Game") as GameState
	config = game.take_config() if game != null else MatchConfig.skirmish(1)
	world = SimSetup.create_match(config)
	local_player = 0
	for i: int in config.player_count():
		if not config.is_ai[i]:
			local_player = i
			break

	_build_environment()
	terrain = TerrainView.new()
	terrain.name = "Terrain"
	add_child(terrain)
	terrain.build(world.map, config.seed_value)

	world_view = WorldView.new()
	world_view.name = "World"
	add_child(world_view)
	world_view.setup(world, local_player)

	cam = RtsCamera.new()
	cam.name = "CameraRig"
	add_child(cam)
	var start: Vector2 = world.players[local_player].start_pos
	var to_centre: Vector2 = world.map.world_size() * 0.5 - start
	# Look across the base towards the middle of the map.
	cam.yaw = atan2(-to_centre.x, -to_centre.y)
	cam.setup(world.map, start + to_centre.normalized() * 6.0)

	controller = SelectionController.new()
	controller.name = "Controller"
	add_child(controller)
	controller.setup(self)
	controller.selection_changed.connect(_on_selection_changed)

	ui_layer = CanvasLayer.new()
	ui_layer.name = "UI"
	add_child(ui_layer)
	overlay = BattleOverlay.new()
	overlay.name = "Overlay"
	ui_layer.add_child(overlay)
	overlay.setup(self)
	if OS.get_cmdline_user_args().has("--smoke"):
		var smoke: SmokeDriver = SmokeDriver.new()
		smoke.name = "Smoke"
		add_child(smoke)
		smoke.setup(self)
	print("Battle scene ready: %s, %d entities" % [world.map.name, world.entities.size()])


func _exit_tree() -> void:
	if world != null:
		print("Battle scene exit at tick %d" % world.tick_count)


## Extra scripted steps for the headless smoke run (HUD, placement...).
func smoke_extra(_driver: SmokeDriver) -> void:
	pass


func _build_environment() -> void:
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52.0, -38.0, 0.0)
	sun.light_energy = 1.25
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 140.0
	add_child(sun)
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.07, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.70, 0.82)
	env.ambient_light_energy = 0.6
	var we: WorldEnvironment = WorldEnvironment.new()
	we.name = "Environment"
	we.environment = env
	add_child(we)


func _process(delta: float) -> void:
	if world == null:
		return
	if not paused:
		_accum += delta * time_scale
		var steps: int = 0
		while _accum >= SimWorld.DT and steps < 10:
			world.tick()
			_accum -= SimWorld.DT
			steps += 1
			for ev: SimEvent in world.events:
				_handle_event(ev)
			world.events.clear()
		if steps >= 10:
			_accum = 0.0  # too far behind: drop the backlog rather than spiral
	controller.prune()
	cam.wasd_free = controller.own_unit_ids().is_empty()
	world_view.sync(clampf(_accum / SimWorld.DT, 0.0, 1.0))
	_update_markers(delta)


func _handle_event(ev: SimEvent) -> void:
	world_view.handle_event(ev)


func _on_selection_changed() -> void:
	for id: int in world_view.views.keys():
		world_view.views[id].set_selected(controller.selected.has(id))


# Hooks the controller calls before its default handling. They return true
# when the event was consumed (for example by building placement).

func is_input_blocked() -> bool:
	return paused


func on_left_click(_screen: Vector2, _shift: bool) -> bool:
	return false


func on_right_click(_screen: Vector2) -> bool:
	return false


func on_hotkey(_key: InputEventKey) -> bool:
	return false


# ----------------------------------------------------------- order marker

## A ring that flashes on the ground where an order was given.
func show_order_marker(at: Vector2, color: Color) -> void:
	var m: MeshInstance3D = ModelFactory.ring(self, 0.55, 0.7, Vector3(at.x, world.map.height_at(at) + 0.15, at.y), ModelFactory.mat(color, 1.2))
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_markers.append(m)
	_marker_age.append(0.0)


func _update_markers(delta: float) -> void:
	var i: int = _markers.size() - 1
	while i >= 0:
		_marker_age[i] += delta
		var t: float = _marker_age[i] / 0.45
		if t >= 1.0:
			_markers[i].queue_free()
			_markers.remove_at(i)
			_marker_age.remove_at(i)
		else:
			var s: float = lerpf(1.6, 0.5, t)
			_markers[i].scale = Vector3(s, 1.0, s)
		i -= 1
