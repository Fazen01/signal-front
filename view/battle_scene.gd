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
var fog_view: FogView = null
var audio: AudioManager = null
var cam: RtsCamera = null
var controller: SelectionController = null
var overlay: BattleOverlay = null
var hud: Hud = null
var menus: MatchMenus = null
var tutorial_panel: TutorialPanel = null
var _tutorial_marker: MeshInstance3D = null
var _tutorial_index: int = -1
var _tutorial_ping_in: float = 0.0
var ui_layer: CanvasLayer = null

# Directive targeting
var targeting: DirectiveDef = null
var target_ring: MeshInstance3D = null
var _target_ok: int = -1

# Building placement
var placing: EntityDef = null
var placing_deploy: bool = false  ## placing a unit's deploy footprint, not a new building
var ghost: Node3D = null
var ghost_cell: Vector2i = Vector2i.ZERO
var ghost_ok: bool = false
var _ghost_shown_ok: int = -1

var _accum: float = 0.0
var spectating: bool = false  ## an AI-vs-AI match run for checking, not played
var perf_enabled: bool = false  ## tools/frame_bench.gd: time the stages of _process
var perf: Dictionary[String, int] = {}  ## stage -> microseconds, plus "frames"
var _markers: Array[MeshInstance3D] = []
var _marker_age: Array[float] = []


func _ready() -> void:
	var game: GameState = get_node_or_null("/root/Game") as GameState
	config = game.take_config() if game != null else MatchConfig.skirmish(1)
	world = game.take_world() if game != null else null
	_read_spectate_args()
	if world == null:
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
	audio = AudioManager.new()
	audio.name = "Audio"
	add_child(audio)
	world_view.audio = audio

	signal_view = SignalView.new()
	signal_view.name = "Signal"
	add_child(signal_view)
	signal_view.setup(world, local_player)

	fog_view = FogView.new()
	fog_view.name = "FogOfWar"
	add_child(fog_view)
	fog_view.terrain = terrain
	fog_view.setup(world, local_player)

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
	menus = MatchMenus.new()
	menus.name = "Menus"
	ui_layer.add_child(menus)
	menus.setup(self)
	if world.tutorial != null:
		tutorial_panel = TutorialPanel.new()
		tutorial_panel.name = "TutorialPanel"
		ui_layer.add_child(tutorial_panel)
		tutorial_panel.setup(world)
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
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = hud.minimap.size * 0.5
	hud.minimap._gui_input(click)
	driver.expect(cam.focus.distance_to(world.map.world_size() * 0.5) < 2.0, "minimap click centres the camera")
	click.pressed = false
	hud.minimap._gui_input(click)
	controller.set_selection([eng.id])
	var rclick: InputEventMouseButton = InputEventMouseButton.new()
	rclick.button_index = MOUSE_BUTTON_RIGHT
	rclick.pressed = true
	rclick.position = hud.minimap.size * 0.25
	hud.minimap._gui_input(rclick)
	hud.minimap.ping(hq.pos)
	cam.center_on(hq.pos)
	# Directives: unlock through the bar, target, fire, and the Alt hotkey.
	p.command_points = 20
	driver.expect(hud.activate_directive(0), "Recon Sweep unlock click accepted")
	world.tick()
	world.tick()
	driver.expect(p.unlocked.has("recon_sweep"), "Recon Sweep unlocked")
	driver.expect(hud.activate_directive(0), "Recon Sweep enters targeting")
	driver.expect(targeting != null and target_ring != null, "targeting ring shown")
	driver.expect(on_left_click(get_viewport().get_visible_rect().size * 0.5, false), "targeting click consumed")
	driver.expect(targeting == null, "targeting ended after firing")
	world.tick()
	world.tick()
	driver.expect(p.stat_directives_used == 1, "Recon Sweep was used")
	var akey: InputEventKey = InputEventKey.new()
	akey.physical_keycode = KEY_4
	akey.alt_pressed = true
	akey.pressed = true
	controller._unhandled_input(akey)
	world.tick()
	world.tick()
	driver.expect(p.unlocked.has("signal_surge"), "Alt+4 unlocked Signal Surge")
	controller._unhandled_input(akey)
	hud.activate_directive(1)
	world.tick()
	world.tick()
	hud.activate_directive(1)
	driver.expect(targeting != null, "Shell Barrage targeting started")
	driver.expect(on_right_click(Vector2.ZERO) and targeting == null, "right click cancels targeting")
	# Right-click hijack: a Splicer on a Dark enemy vehicle next to it.
	var wild: Vector2 = world.map.nearest_free_pos(hq.pos + (world.map.world_size() * 0.5 - hq.pos).normalized() * 44.0)
	var prize: SimEntity = world.spawn_unit("hauler", 1 - local_player, wild)
	var thief: SimEntity = world.spawn_unit("splicer", local_player, world.map.nearest_free_pos(wild + Vector2(3.0, 0.0)))
	for i: int in 8:
		world.tick()  # long enough for fog of war to notice the new units
	world_view.sync(1.0)
	cam.center_on(wild)
	controller.set_selection([thief.id])
	controller.context_order(controller.screen_pos(prize), false)
	world.tick()
	world.tick()
	driver.expect(not thief.orders.is_empty() and thief.orders[0].type == SimOrder.Type.CAPTURE, "right click on a Dark vehicle orders a hijack")
	cam.center_on(hq.pos)
	# Sound and settings.
	driver.expect(audio.played_count > 0, "interface sounds were played (%d)" % audio.played_count)
	toggle_pause_menu()
	menus.open_settings()
	driver.expect(menus.is_pause_open(), "settings open from the pause menu")
	GameSettings.set_volume("SFX", 0.6)
	toggle_pause_menu()
	driver.expect(not paused and not menus.is_pause_open(), "closing the pause menu closes settings")
	world_view.fx.explosion(Vector3(hq.pos.x, 1.0, hq.pos.y), 2.0)
	world_view.fx.sparks(Vector3(hq.pos.x, 1.0, hq.pos.y))
	# Idle-builder key and camera bookmarks.
	world.push_command(SimCommand.stop(local_player, PackedInt32Array([eng.id])))
	controller.clear_selection()
	var fkey: InputEventKey = InputEventKey.new()
	fkey.physical_keycode = KEY_F6
	fkey.pressed = true
	fkey.ctrl_pressed = true
	controller._unhandled_input(fkey)
	cam.center_on(world.map.world_size() * 0.5)
	fkey.ctrl_pressed = false
	controller._unhandled_input(fkey)
	driver.expect(cam.focus.distance_to(hq.pos) < 1.0, "camera bookmark recalled")
	driver.expect(controller.select_next_idle_builder() or true, "idle builder key runs")
	var gkey: InputEventKey = InputEventKey.new()
	gkey.physical_keycode = KEY_G
	gkey.pressed = true
	driver.expect(on_hotkey(gkey) and not signal_view.is_overlay_visible(), "G hides the coverage overlay")
	driver.expect(on_hotkey(gkey) and signal_view.is_overlay_visible(), "G shows it again")


## `-- --spectate=aegis,nomad [--speed=30]` turns the scene into an AI-vs-AI
## match watched from player one's side and run fast. tools/check.sh uses it
## to put every view, HUD and effect path through a whole match.
func _read_spectate_args() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--spectate="):
			var c: MatchConfig = MatchConfig.ai_vs_ai(7)
			c.factions.clear()
			c.is_ai.clear()
			c.ai_levels.clear()
			c.names.clear()
			for fname: String in arg.trim_prefix("--spectate=").split(","):
				c.add_ai(fname, 1, "%s AI" % fname.capitalize())
			config = c
			world = null
			spectating = true
			time_scale = 30.0
		elif arg.begins_with("--speed="):
			time_scale = float(arg.trim_prefix("--speed="))


func _build_environment() -> void:
	SceneLight.add_to(self, GameSettings.shadows, world.map.region)


func _process(delta: float) -> void:
	if world == null:
		return
	var t0: int = Time.get_ticks_usec()
	var t_events: int = 0
	if not paused:
		_accum += delta * time_scale
		var steps: int = 0
		while _accum >= SimWorld.DT and steps < 10:
			world.tick()
			_accum -= SimWorld.DT
			steps += 1
			var e0: int = Time.get_ticks_usec()
			for ev: SimEvent in world.events:
				_handle_event(ev)
			world.events.clear()
			t_events += Time.get_ticks_usec() - e0
		if steps >= 10:
			_accum = 0.0  # too far behind: drop the backlog rather than spiral
	var t1: int = Time.get_ticks_usec()
	controller.prune()
	audio.listener = cam.focus
	cam.wasd_free = controller.own_unit_ids().is_empty()
	world_view.sync(clampf(_accum / SimWorld.DT, 0.0, 1.0))
	var t2: int = Time.get_ticks_usec()
	_update_markers(delta)
	_update_placement()
	_update_targeting()
	if world.tutorial != null:
		_update_tutorial(delta)
	if perf_enabled:
		perf["sim"] = perf.get("sim", 0) + t1 - t0 - t_events
		perf["events"] = perf.get("events", 0) + t_events
		perf["sync"] = perf.get("sync", 0) + t2 - t1
		perf["frames"] = perf.get("frames", 0) + 1


func _handle_event(ev: SimEvent) -> void:
	world_view.handle_event(ev)
	match ev.type:
		SimEvent.Type.ALERT:
			if ev.player == local_player:
				hud.push_alert(ev.text, Hud.RED)
				audio.play_ui("alert", -6.0)
				if ev.pos != Vector2.ZERO:
					hud.minimap.ping(ev.pos)
		SimEvent.Type.BUILDING_DONE:
			if ev.player == local_player:
				var done: SimEntity = world.get_entity(ev.id)
				if done != null:
					hud.push_alert("%s complete" % done.def.name, Hud.CYAN)
				hud.rebuild_card()
				audio.play_ui("ready")
		SimEvent.Type.BUILDING_PLACED:
			if ev.player == local_player:
				audio.play_ui("place")
		SimEvent.Type.UNIT_READY:
			if ev.player == local_player:
				audio.play_ui("ready", -10.0)
		SimEvent.Type.DEPOSIT:
			if ev.player == local_player:
				audio.play_at("deposit", ev.pos, 150, -6.0)
		SimEvent.Type.RANK_UP:
			if ev.player == local_player:
				audio.play_ui("rank", -8.0)
		SimEvent.Type.DIRECTIVE:
			if ev.player == local_player and ev.text != "drop_arrived":
				audio.play_ui("directive", -5.0)
			if ev.player == local_player and ev.text == "signal_surge":
				hud.push_alert("Signal Surge: emitter range +50%", Hud.CYAN)
		SimEvent.Type.MATCH_OVER:
			cancel_placement()
			cancel_directive()
			menus.show_result(world, local_player)
			if spectating:
				var secs: int = int(world.seconds())
				print("Spectate finished: winner %d at %d:%02d, %d views, %d sounds played" % [
					world.winner, secs / 60, secs % 60, world_view.views.size(), audio.played_count,
				])
				get_tree().quit(0)


func _on_selection_changed() -> void:
	for id: int in world_view.views.keys():
		world_view.views[id].set_selected(controller.selected_set.has(id))
	if placing != null and _selected_builders(placing.id).is_empty():
		cancel_placement()
	if hud != null:
		hud.rebuild_card()
	if audio != null and not controller.selected.is_empty():
		audio.play_ui("select", -12.0)


# Hooks the controller calls before its default handling. They return true
# when the event was consumed (for example by building placement).

func is_input_blocked() -> bool:
	return paused or world.game_over


func on_left_click(screen: Vector2, shift: bool) -> bool:
	if targeting != null:
		var at: Vector2 = controller.ground_point(screen)
		var bad: String = SimDirectives.use_error(world, local_player, targeting, at)
		if bad != "":
			hud.push_alert(bad, Hud.RED)
			return true
		world.push_command(SimCommand.directive(local_player, targeting.id, at))
		cancel_directive()
		return true
	if placing == null:
		return false
	var builders: PackedInt32Array = _selected_builders(placing.id)
	if builders.is_empty():
		cancel_placement()
		return true
	var why: String = _placement_error()
	if why != "":
		hud.push_alert(why, Hud.RED)
		return true
	if placing_deploy:
		world.push_command(SimCommand.deploy(local_player, builders, ghost_cell, shift))
		cancel_placement()
		return true
	world.push_command(SimCommand.build(local_player, builders, placing.id, ghost_cell, shift))
	if not shift:
		cancel_placement()
	return true


func on_right_click(_screen: Vector2) -> bool:
	if targeting != null:
		cancel_directive()
		return true
	if placing != null:
		cancel_placement()
		return true
	return false


func on_hotkey(key: InputEventKey) -> bool:
	if key.physical_keycode == KEY_G:
		signal_view.set_overlay_visible(not signal_view.is_overlay_visible())
		return true
	if key.physical_keycode == KEY_ESCAPE:
		if targeting != null:
			cancel_directive()
			return true
		if placing != null:
			cancel_placement()
			return true
		if controller.mode != SelectionController.Mode.NORMAL:
			return false  # the controller cancels its own mode
		toggle_pause_menu()
		return true
	return hud.handle_hotkey(key)


func toggle_pause_menu() -> void:
	if world.game_over:
		return
	paused = not paused
	menus.set_pause_open(paused)


func _unhandled_key_input(event: InputEvent) -> void:
	# While paused the controller ignores input, so Escape is handled here.
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.physical_keycode == KEY_ESCAPE and paused:
		toggle_pause_menu()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- tutorial

## Points at the current objective (a gold ring on the ground and a ping on
## the minimap) and shows the completion screen when the mission ends.
func _update_tutorial(delta: float) -> void:
	var t: SimTutorial = world.tutorial
	var index: int = t.steps.size() if t.done else t.index
	if index != _tutorial_index:
		_tutorial_index = index
		_tutorial_ping_in = 0.0
		if _tutorial_marker != null:
			_tutorial_marker.queue_free()
			_tutorial_marker = null
		var step: SimTutorial.Step = t.current()
		if step != null and step.marker != Vector2.INF:
			var at: Vector2 = world.map.clamp_to_map(step.marker)
			_tutorial_marker = ModelFactory.ring(self, 3.4, 3.8, Vector3(at.x, world.map.height_at(at) + 0.35, at.y), ModelFactory.mat(Color(1.0, 0.82, 0.3), 1.3))
			_tutorial_marker.name = "ObjectiveMarker"
			_tutorial_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if index > 0:
			audio.play_ui("ready")
		if t.done:
			menus.show_tutorial_complete(t.id)
	if _tutorial_marker != null:
		var pulse: float = 1.0 + 0.12 * sin(float(Time.get_ticks_msec()) * 0.005)
		_tutorial_marker.scale = Vector3(pulse, 1.0, pulse)
		_tutorial_ping_in -= delta
		if _tutorial_ping_in <= 0.0:
			_tutorial_ping_in = 3.0
			hud.minimap.ping(world.tutorial.current().marker)


## Writes the match to the save slot (from the pause menu).
func save_game() -> bool:
	if world.tutorial != null:
		hud.push_alert("Tutorial missions cannot be saved", Hud.RED)
		return false
	var ok: bool = SimSave.save_to_file(world, config)
	hud.push_alert("Game saved" if ok else "Could not write the save file", Hud.CYAN if ok else Hud.RED)
	return ok


## Picks up settings changed in the pause menu.
func apply_settings() -> void:
	var sun: DirectionalLight3D = get_node_or_null("Sun") as DirectionalLight3D
	if sun != null:
		sun.shadow_enabled = GameSettings.shadows
	hud.rebuild_card()


func surrender() -> void:
	paused = false
	menus.set_pause_open(false)
	world.push_command(SimCommand.surrender(local_player))


func quit_to_menu() -> void:
	var game: GameState = get_node_or_null("/root/Game") as GameState
	if game != null:
		game.to_menu()


func start_tutorial(tutorial_id: String) -> void:
	var game: GameState = get_node_or_null("/root/Game") as GameState
	if game != null:
		game.start_match(SimTutorial.config_for(tutorial_id))


func play_again() -> void:
	var game: GameState = get_node_or_null("/root/Game") as GameState
	if game != null:
		game.start_match(config)


# ----------------------------------------------------- directive targeting

## Starts choosing where to use a Directive: a ring follows the mouse, green
## where the target is allowed. Left click fires, right click or Esc cancels.
func begin_directive(def: DirectiveDef) -> void:
	cancel_placement()
	cancel_directive()
	targeting = def
	var r: float = maxf(def.radius, 1.0)
	target_ring = ModelFactory.ring(self, r - 0.2, r, Vector3.ZERO, ModelFactory.mat(Color(0.4, 1.0, 0.5), 1.0))
	target_ring.name = "TargetRing"
	target_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_target_ok = -1
	_update_targeting()


func cancel_directive() -> void:
	targeting = null
	if target_ring != null:
		target_ring.queue_free()
		target_ring = null


func _update_targeting() -> void:
	if targeting == null or target_ring == null:
		return
	var at: Vector2 = controller.ground_point(get_viewport().get_mouse_position())
	target_ring.position = Vector3(at.x, world.map.height_at(world.map.clamp_to_map(at)) + 0.4, at.y)
	var ok: int = 1 if SimDirectives.use_error(world, local_player, targeting, at) == "" else 0
	if ok != _target_ok:
		_target_ok = ok
		target_ring.material_override = ModelFactory.mat(Color(0.4, 1.0, 0.5) if ok == 1 else Color(1.0, 0.3, 0.25), 1.0)


# ------------------------------------------------------ building placement

## Selected units that can carry out the current placement: builders of the
## building, or units that deploy into it.
func _selected_builders(def_id: String) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for e: SimEntity in controller.selected_entities():
		if e.owner != local_player or e.kind != SimEntity.Kind.UNIT:
			continue
		if (placing_deploy and e.def.deploys_to == def_id) or (not placing_deploy and e.def.builds.has(def_id)):
			out.append(e.id)
	return out


## Why the ghost cannot go where it is, or "".
func _placement_error() -> String:
	if placing_deploy:
		for e: SimEntity in controller.selected_entities():
			if e.owner == local_player and e.def != null and e.def.deploys_to == placing.id:
				return SimEconomy.deploy_error(world, local_player, e.def, ghost_cell)
		return "Nothing selected can deploy"
	var why: String = SimEconomy.placement_error(world, local_player, placing, ghost_cell)
	if why == "" and world.players[local_player].salvage < placing.cost:
		why = "Not enough salvage"
	return why


## Starts placing a building: a ghost follows the mouse until the player
## clicks (place) or right-clicks / presses Escape (cancel).
func begin_placement(def: EntityDef, deploy: bool = false) -> void:
	cancel_placement()
	placing = def
	placing_deploy = deploy
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
	placing_deploy = false
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
	ghost_ok = _placement_error() == ""
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
	audio.play_ui("ack", -9.0)
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
