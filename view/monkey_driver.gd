class_name MonkeyDriver
extends Node
## Random-input soak test. Added to the battle scene when it is started with
## the user argument --monkey (optionally --monkey=<seed>). Every frame it
## feeds a few random mouse clicks, drags, wheel turns and key presses into
## the engine's input queue, exactly as a real player's would arrive, so they
## pass through the HUD, minimap, command card, Directive bar, camera and
## selection code. tools/check.sh runs it and fails on any script error.
##
## It never presses Escape and never clicks the pause-menu button, so it
## stays in the match, and it only acts while the match window has nothing
## modal open. It is a test harness: it gives the local player
## salvage so that building and training actually happen.

const ACTIONS_PER_FRAME: int = 2
const RUN_FRAMES: int = 3000

var battle: BattleScene = null
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _frame: int = 0
var _actions: int = 0
var _held: Array[Key] = []
var _done: bool = false
var _last_desc: String = ""  ## the last few inputs, for the pause note
var _spot: Vector2 = Vector2.ZERO  ## where the build sequence is about to click
var _sites: Dictionary[int, bool] = {}  ## construction sites the monkey managed to place

## Keys a player might press during a match (Escape is left out on purpose).
const KEYS: Array[Key] = [
	KEY_A, KEY_S, KEY_H, KEY_G, KEY_Q, KEY_E, KEY_W, KEY_D, KEY_PERIOD, KEY_F1,
	KEY_B, KEY_C, KEY_F, KEY_I, KEY_K, KEY_L, KEY_N, KEY_P, KEY_R, KEY_T, KEY_U,
	KEY_V, KEY_Y, KEY_M, KEY_J, KEY_O, KEY_X, KEY_Z,
	KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9,
	KEY_F5, KEY_F6, KEY_F7, KEY_F8, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT,
	KEY_SPACE, KEY_F2, KEY_TAB, KEY_HOME, KEY_DELETE, KEY_BACKSPACE,
]


func setup(scene: BattleScene, seed_value: int) -> void:
	battle = scene
	rng.seed = seed_value
	battle.time_scale = 4.0


func _process(_delta: float) -> void:
	if _done or battle.world == null:
		return
	_frame += 1
	_release_held()
	var w: SimWorld = battle.world
	if battle.paused and not w.game_over:
		# Only Escape and the menu button should pause, and the monkey uses
		# neither: say what led here, then carry on.
		print("Monkey note: the game paused at frame %d; last inputs:%s" % [_frame, _last_desc])
		battle.toggle_pause_menu()
	if _frame % 60 == 1 and not w.game_over:
		w.players[battle.local_player].salvage = maxi(w.players[battle.local_player].salvage, 3000)
	if _frame % 10 == 0:
		for e: SimEntity in w.entities:
			if e.alive and e.owner == battle.local_player and e.kind == SimEntity.Kind.BUILDING and not e.constructed:
				_sites[e.id] = true
	if _frame > 5 and not w.game_over and not battle.paused:
		if _frame % 90 < 6:
			_build_something(_frame % 90)
		else:
			for i: int in ACTIONS_PER_FRAME:
				_random_action()
	if _frame >= RUN_FRAMES or w.game_over:
		_done = true
		var me: SimPlayer = w.players[battle.local_player]
		var secs: int = int(w.seconds())
		print("Monkey finished: %d actions over %d frames, game time %d:%02d, %d units built, %d sites placed, %d buildings finished%s" % [
			_actions, _frame, secs / 60, secs % 60, me.stat_units_built, _sites.size(), me.stat_buildings_built,
			", match over" if w.game_over else "",
		])


## A short deliberate sequence among the noise, so that the select-builder,
## command-card, placement-ghost path is walked to the end regularly:
## step 0 centres on a builder, step 1 clicks it, step 2 presses a command
## card button, step 3 looks at the headquarters, step 4 points beside it
## and step 5 clicks there.
func _build_something(step: int) -> void:
	var w: SimWorld = battle.world
	_actions += 1
	match step:
		0:
			battle.cancel_placement()
			battle.cancel_directive()
			for e: SimEntity in w.entities:
				if e.alive and e.owner == battle.local_player and e.def != null and e.def.builder:
					battle.cam.center_on(e.pos)
					return
		1:
			for e: SimEntity in w.entities:
				if e.alive and e.owner == battle.local_player and e.def != null and e.def.builder:
					_click(MOUSE_BUTTON_LEFT, battle.controller.screen_pos(e), false, false)
					return
		2:
			_click(MOUSE_BUTTON_LEFT, _point_on_button(true), false, false)
		3:
			# Look at the headquarters: ground near it is covered and mostly free.
			for e: SimEntity in w.entities:
				if e.alive and e.owner == battle.local_player and e.def != null and e.def.signal_root:
					battle.cam.center_on(e.pos)
					return
		4:
			# Move first and click a frame later, as a hand does: the ghost
			# follows the pointer once a frame.
			_spot = _view_size() * 0.5 + Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(110.0, 330.0)
			_move(_spot)
		_:
			_click(MOUSE_BUTTON_LEFT, _spot, false, false)


func _note(what: String) -> void:
	_last_desc = (_last_desc + what).right(300)


func _view_size() -> Vector2:
	return get_viewport().get_visible_rect().size


## Where the pause-menu button is, grown a little, so clicks can avoid it.
func _menu_rect() -> Rect2:
	var menu: Button = battle.hud.find_child("MenuButton", true, false) as Button
	if menu == null:
		return Rect2()
	return menu.get_global_rect().grow(6.0)


## A random point on screen, kept off the pause-menu button.
func _random_point() -> Vector2:
	var size: Vector2 = _view_size()
	var p: Vector2 = Vector2(rng.randf_range(0.0, size.x - 1.0), rng.randf_range(0.0, size.y - 1.0))
	var menu: Rect2 = _menu_rect()
	if menu.has_point(p):
		p.y = menu.end.y + 4.0
	return p


## A screen point on or near something interesting, when there is one.
func _point_near_entity(owner_filter: int) -> Vector2:
	var w: SimWorld = battle.world
	if w.entities.is_empty():
		return _random_point()
	for attempt: int in 6:
		var e: SimEntity = w.entities[rng.randi_range(0, w.entities.size() - 1)]
		if not e.alive:
			continue
		if owner_filter == -2 or e.owner == owner_filter:
			var sp: Vector2 = battle.controller.screen_pos(e)
			var size: Vector2 = _view_size()
			if sp.x >= 0.0 and sp.y >= 0.0 and sp.x < size.x and sp.y < size.y and not _menu_rect().has_point(sp):
				return sp
	return _random_point()


## A point on a HUD button, so the command card and Directive bar get clicked.
## With card_only, a button of the command card that can be pressed now.
func _point_on_button(card_only: bool = false) -> Vector2:
	var buttons: Array[Node] = battle.hud.find_children("*", "Button", true, false)
	var shown: Array[Button] = []
	for n: Node in buttons:
		var b: Button = n as Button
		if b == null or not b.is_visible_in_tree() or b.name == "MenuButton":
			continue
		if card_only and (b.disabled or not (b.get_parent() is GridContainer)):
			continue
		shown.append(b)
	if shown.is_empty():
		return _random_point()
	var pick: Button = shown[rng.randi_range(0, shown.size() - 1)]
	return pick.get_global_rect().get_center()


func _random_action() -> void:
	_actions += 1
	var roll: float = rng.randf()
	var me: int = battle.local_player
	# With a building ghost or a Directive armed, usually place it near our
	# own things, where it is likely to be valid, so placement really happens.
	if (battle.placing != null or battle.targeting != null) and rng.randf() < 0.7:
		var near: Vector2 = _point_near_entity(me) + Vector2(rng.randf_range(-90.0, 90.0), rng.randf_range(-90.0, 90.0))
		_click(MOUSE_BUTTON_LEFT, near, rng.randf() < 0.2, false)
		return
	if roll < 0.18:
		_click(MOUSE_BUTTON_LEFT, _point_near_entity(me), rng.randf() < 0.2, rng.randf() < 0.1)
	elif roll < 0.30:
		_click(MOUSE_BUTTON_LEFT, _random_point(), rng.randf() < 0.2, false)
	elif roll < 0.46:
		_click(MOUSE_BUTTON_RIGHT, _point_near_entity(-2), rng.randf() < 0.2, false)
	elif roll < 0.54:
		_click(MOUSE_BUTTON_RIGHT, _random_point(), false, false)
	elif roll < 0.62:
		_drag(_random_point(), _random_point())
	elif roll < 0.74:
		_click(MOUSE_BUTTON_LEFT, _point_on_button(), false, false)
	elif roll < 0.78:
		_wheel(rng.randf() < 0.5)
	elif roll < 0.81:
		_move(_random_point())
	else:
		var key: Key = KEYS[rng.randi_range(0, KEYS.size() - 1)]
		var digit: bool = key >= KEY_1 and key <= KEY_9
		var ctrl: bool = (digit or (key >= KEY_F5 and key <= KEY_F8)) and rng.randf() < 0.3
		var alt: bool = digit and not ctrl and rng.randf() < 0.3
		_key(key, ctrl, rng.randf() < 0.1, alt)


## Into the root viewport, in its own coordinates: the GUI sees the event
## first, then the scene's unhandled-input handlers, as with real input.
## (Input.parse_input_event is not dispatched by the headless display
## server, and window coordinates would be rescaled by the stretch mode.)
func _send(ev: InputEvent) -> void:
	get_tree().root.push_input(ev, true)


func _move(at: Vector2) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	_send(motion)


func _click(button: MouseButton, at: Vector2, shift: bool, double_click: bool) -> void:
	var menu: Rect2 = _menu_rect()
	if menu.has_point(at):
		at.y = menu.end.y + 4.0
	_note(" | click %d at %s%s" % [button, str(at.round()), " double" if double_click else ""])
	_move(at)
	for pressed: bool in [true, false]:
		var ev: InputEventMouseButton = InputEventMouseButton.new()
		ev.button_index = button
		ev.pressed = pressed
		ev.position = at
		ev.global_position = at
		ev.shift_pressed = shift
		ev.double_click = double_click and pressed
		_send(ev)


func _drag(from: Vector2, to: Vector2) -> void:
	_move(from)
	var down: InputEventMouseButton = InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = from
	down.global_position = from
	_send(down)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = to
	motion.global_position = to
	motion.relative = to - from
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	_send(motion)
	var up: InputEventMouseButton = InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = to
	up.global_position = to
	_send(up)


func _wheel(up: bool) -> void:
	var at: Vector2 = _random_point()
	for pressed: bool in [true, false]:
		var ev: InputEventMouseButton = InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN
		ev.pressed = pressed
		ev.position = at
		ev.global_position = at
		_send(ev)


func _key(code: Key, ctrl: bool, shift: bool, alt: bool) -> void:
	_note(" | key %s%s%s" % ["Ctrl+" if ctrl else "", "Alt+" if alt else "", OS.get_keycode_string(code)])
	var ev: InputEventKey = InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = true
	ev.ctrl_pressed = ctrl
	ev.shift_pressed = shift
	ev.alt_pressed = alt
	_send(ev)
	_held.append(code)


## Keys are released on the next frame, so held-key code (camera pan) runs.
func _release_held() -> void:
	for code: Key in _held:
		var ev: InputEventKey = InputEventKey.new()
		ev.physical_keycode = code
		ev.keycode = code
		ev.pressed = false
		_send(ev)
	_held.clear()
