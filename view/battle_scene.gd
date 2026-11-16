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
var signal_view: SignalView = null
var cam: RtsCamera = null
var controller: SelectionController = null
var overlay: BattleOverlay = null
var hud: Hud = null
var ui_layer: CanvasLayer = null

# Building placement
var placing: EntityDef = null
var ghost: Node3D = null
var ghost_cell: Vector2i = Vector2i.ZERO
var ghost_ok: bool = false
var _ghost_shown_ok: int = -1

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

	signal_view = SignalView.new()
	signal_view.name = "Signal"
	add_child(signal_view)
	signal_view.setup(world, local_player)

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
	hud = Hud.new()
	hud.name = "Hud"
	ui_layer.add_child(hud)
	hud.setup(self)
	if OS.get_cmdline_user_args().has("--smoke"):
		var smoke: SmokeDriver = SmokeDriver.new()
		smoke.name = "Smoke"
		add_child(smoke)
		smoke.setup(self)
	print("Battle scene ready: %s, %d entities" % [world.map.name, world.entities.size()])


func _exit_tree() -> void:
	if world != null:
		print("Battle scene exit at tick %d" % world.tick_count)


## Extra scripted steps for the headless smoke run: HUD card, placement,
## production. Prints BOOT FAILED lines that tools/check.sh treats as errors.
func smoke_extra(driver: SmokeDriver) -> void:
	var p: SimPlayer = world.players[local_player]
	p.salvage = 5000
	# Select an engineer, open the build card and place a relay next to the HQ.
	var eng: SimEntity = null
	var hq: SimEntity = null
	for e: SimEntity in world.entities:
		if e.owner == local_player and e.def != null:
			if e.def.builder and eng == null:
				eng = e
			if e.def.signal_root:
				hq = e
	controller.set_selection([eng.id])
	var entry: Hud.CardEntry = hud.find_entry("build", "relay")
	driver.expect(entry != null, "builder card offers the relay")
	driver.expect(hud.activate(entry), "relay entry activates")
	driver.expect(placing != null and ghost != null, "placement mode started")
	ghost_cell = world.map.cell_of(hq.pos) + Vector2i(5, 5)
	driver.expect(on_left_click(Vector2.ZERO, false), "placement click consumed")
	driver.expect(placing == null, "placement ended after the click")
	# Cancel paths.
	begin_placement(world.data.entity("depot"))
	driver.expect(on_right_click(Vector2.ZERO), "right click cancels placement")
	# Train from the HQ through the card and its hotkey.
	controller.set_selection([hq.id])
	var train: Hud.CardEntry = hud.find_entry("train", "hauler")
	driver.expect(train != null and hud.activate(train), "HQ card trains a hauler")
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_F
	key.pressed = true
	driver.expect(hud.handle_hotkey(key), "card hotkey F trains an engineer")
	hud.push_alert("Smoke alert", Hud.GOLD)
	var gkey: InputEventKey = InputEventKey.new()
	gkey.physical_keycode = KEY_G
	gkey.pressed = true
	driver.expect(on_hotkey(gkey) and not signal_view.is_overlay_visible(), "G hides the coverage overlay")
	driver.expect(on_hotkey(gkey) and signal_view.is_overlay_visible(), "G shows it again")


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
	_update_placement()


func _handle_event(ev: SimEvent) -> void:
	world_view.handle_event(ev)
	match ev.type:
		SimEvent.Type.ALERT:
			if ev.player == local_player:
				hud.push_alert(ev.text, Hud.RED)
		SimEvent.Type.BUILDING_DONE:
			if ev.player == local_player:
				var done: SimEntity = world.get_entity(ev.id)
				if done != null:
					hud.push_alert("%s complete" % done.def.name, Hud.CYAN)
				hud.rebuild_card()


func _on_selection_changed() -> void:
	for id: int in world_view.views.keys():
		world_view.views[id].set_selected(controller.selected.has(id))
	if placing != null and _selected_builders(placing.id).is_empty():
		cancel_placement()
	if hud != null:
		hud.rebuild_card()


# Hooks the controller calls before its default handling. They return true
# when the event was consumed (for example by building placement).

func is_input_blocked() -> bool:
	return paused


func on_left_click(_screen: Vector2, shift: bool) -> bool:
	if placing == null:
		return false
	var builders: PackedInt32Array = _selected_builders(placing.id)
	if builders.is_empty():
		cancel_placement()
		return true
	var why: String = SimEconomy.placement_error(world, local_player, placing, ghost_cell)
	if why == "" and world.players[local_player].salvage < placing.cost:
		why = "Not enough salvage"
	if why != "":
		hud.push_alert(why, Hud.RED)
		return true
	world.push_command(SimCommand.build(local_player, builders, placing.id, ghost_cell, shift))
	if not shift:
		cancel_placement()
	return true


func on_right_click(_screen: Vector2) -> bool:
	if placing != null:
		cancel_placement()
		return true
	return false


func on_hotkey(key: InputEventKey) -> bool:
	if key.physical_keycode == KEY_G:
		signal_view.set_overlay_visible(not signal_view.is_overlay_visible())
		return true
	if key.physical_keycode == KEY_ESCAPE:
		if placing != null:
			cancel_placement()
			return true
		if controller.mode != SelectionController.Mode.NORMAL:
			return false  # the controller cancels its own mode
		toggle_pause_menu()
		return true
	return hud.handle_hotkey(key)


func toggle_pause_menu() -> void:
	pass


# ------------------------------------------------------ building placement

func _selected_builders(def_id: String) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for e: SimEntity in controller.selected_entities():
		if e.owner == local_player and e.kind == SimEntity.Kind.UNIT and e.def.builds.has(def_id):
			out.append(e.id)
	return out


## Starts placing a building: a ghost follows the mouse until the player
## clicks (place) or right-clicks / presses Escape (cancel).
func begin_placement(def: EntityDef) -> void:
	cancel_placement()
	placing = def
	ghost = ModelFactory.build(def.model, world.players[local_player].color)
	ghost.name = "Ghost"
	add_child(ghost)
	if def.signal_radius > 0.0:
		# Show how far the new emitter will reach.
		var reach: MeshInstance3D = ModelFactory.ring(ghost, def.signal_radius - 0.15, def.signal_radius + 0.15, Vector3(0.0, 0.3, 0.0), ModelFactory.mat(Color(0.5, 0.9, 1.0), 1.0))
		reach.name = "ReachRing"
		reach.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost_shown_ok = -1
	_update_placement()


func cancel_placement() -> void:
	placing = null
	if ghost != null:
		ghost.queue_free()
		ghost = null


func placement_cell_at(ground: Vector2, def: EntityDef) -> Vector2i:
	return Vector2i(
		int(roundf(ground.x / SimMap.CELL - float(def.footprint.x) * 0.5)),
		int(roundf(ground.y / SimMap.CELL - float(def.footprint.y) * 0.5))
	)


func _update_placement() -> void:
	if placing == null or ghost == null:
		return
	var ground: Vector2 = controller.ground_point(get_viewport().get_mouse_position())
	ghost_cell = placement_cell_at(ground, placing)
	var centre: Vector2 = Vector2(
		(float(ghost_cell.x) + float(placing.footprint.x) * 0.5) * SimMap.CELL,
		(float(ghost_cell.y) + float(placing.footprint.y) * 0.5) * SimMap.CELL
	)
	ghost.position = Vector3(centre.x, world.map.height_at(world.map.clamp_to_map(centre)) + 0.05, centre.y)
	ghost_ok = SimEconomy.can_place(world, local_player, placing, ghost_cell) and world.players[local_player].salvage >= placing.cost
	var state: int = 1 if ghost_ok else 0
	if state != _ghost_shown_ok:
		_ghost_shown_ok = state
		var tint: Color = Color(0.3, 1.0, 0.45, 0.55) if ghost_ok else Color(1.0, 0.25, 0.2, 0.55)
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.albedo_color = tint
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		for child: Node in ghost.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = child as MeshInstance3D
			if mi.name == "ReachRing":
				continue
			mi.material_override = m
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


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
