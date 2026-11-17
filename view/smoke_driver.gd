class_name SmokeDriver
extends Node
## Headless exercise of the input paths. Added to the battle scene when it is
## started with the user argument --smoke. It feeds synthetic mouse and key
## events to the controller the same way real input arrives, so script errors
## in selection, ordering and HUD code show up in tools/check.sh.

var battle: BattleScene = null
var _frame: int = 0
var _steps_run: int = 0


func setup(scene: BattleScene) -> void:
	battle = scene


func _process(_delta: float) -> void:
	_frame += 1
	var ctl: SelectionController = battle.controller
	var w: SimWorld = battle.world
	var me: int = battle.local_player
	match _frame:
		10:
			# Click on an own unit.
			var u: SimEntity = _first(me, SimEntity.Kind.UNIT)
			_click(MOUSE_BUTTON_LEFT, ctl.screen_pos(u), false)
			expect(ctl.selected.size() == 1, "click selects one unit")
		20:
			# Drag a box over the whole screen.
			var size: Vector2 = get_viewport().get_visible_rect().size
			_drag(Vector2(2.0, 2.0), size - Vector2(2.0, 2.0))
			expect(ctl.own_unit_ids().size() >= 2, "box select finds units")
		30:
			_key(KEY_1, true, false)  # Ctrl+1: set group
			_click(MOUSE_BUTTON_RIGHT, get_viewport().get_visible_rect().size * 0.5 + Vector2(120.0, -80.0), false)
		40:
			var moving: int = 0
			for e: SimEntity in ctl.selected_entities():
				if e.moving:
					moving += 1
			expect(moving > 0, "right click moves the selection")
		50:
			_key(KEY_O, false, false)
		55:
			_key(KEY_A, false, false)
			expect(ctl.mode == SelectionController.Mode.NORMAL, "A belongs to the camera: it arms nothing")
			_key(KEY_X, false, false)
			expect(ctl.mode == SelectionController.Mode.ATTACK_MOVE, "X arms attack-move")
			_click(MOUSE_BUTTON_LEFT, get_viewport().get_visible_rect().size * 0.5 + Vector2(-150.0, 60.0), false)
			expect(ctl.mode == SelectionController.Mode.NORMAL, "attack-move click returns to normal")
		70:
			_key(KEY_H, false, false)
			ctl.clear_selection()
			expect(ctl.selected.is_empty(), "selection cleared")
		75:
			_key(KEY_1, false, false)  # recall group
			expect(ctl.selected.size() >= 2, "control group recalled")
			_key(KEY_1, false, false)  # double tap: centre camera
		80:
			# Click the HQ, then double-click a unit type.
			var hq: SimEntity = _first(me, SimEntity.Kind.BUILDING)
			battle.cam.center_on(hq.pos)
		82:
			var hq2: SimEntity = _first(me, SimEntity.Kind.BUILDING)
			_click(MOUSE_BUTTON_LEFT, ctl.screen_pos(hq2), false)
			expect(ctl.selected.size() == 1 and ctl.selected[0] == hq2.id, "click selects the HQ")
			_click(MOUSE_BUTTON_RIGHT, ctl.screen_pos(hq2) + Vector2(160.0, 40.0), false)  # rally
		90:
			var u2: SimEntity = _first(me, SimEntity.Kind.UNIT)
			battle.cam.center_on(u2.pos)
		92:
			var u3: SimEntity = _first(me, SimEntity.Kind.UNIT)
			_click(MOUSE_BUTTON_LEFT, ctl.screen_pos(u3), false, true)
			expect(ctl.selected.size() >= 1, "double click selects by type")
		100:
			# Attack order on an enemy unit, straight through the command path.
			var foe: SimEntity = _first(1 - me, SimEntity.Kind.UNIT)
			if foe != null:
				w.push_command(SimCommand.attack(me, ctl.own_unit_ids(), foe.id))
		110:
			battle.smoke_extra(self)
		_:
			pass
	if _frame == 125:
		# The relay ordered at frame 110 must exist as a site, and the HQ must
		# have both units queued.
		var sites: int = 0
		var queued: int = 0
		for e: SimEntity in w.entities:
			if e.owner == me and e.def != null and e.def.id == "relay":
				sites += 1
			if e.owner == me and e.def != null and e.def.signal_root:
				queued = e.queue.size()
		expect(sites == 1, "relay site was placed through the HUD")
		expect(queued == 2, "HQ queue holds the two HUD orders (has %d)" % queued)
	if _frame == 130:
		print("Smoke driver finished: %d checks" % _steps_run)


func _first(owner_id: int, kind: int) -> SimEntity:
	for e: SimEntity in battle.world.entities:
		if e.alive and e.owner == owner_id and e.kind == kind:
			return e
	return null


func expect(cond: bool, what: String) -> void:
	_steps_run += 1
	if not cond:
		print("BOOT FAILED: smoke check '%s' (frame %d)" % [what, _frame])


func _send(ev: InputEvent) -> void:
	battle.controller._unhandled_input(ev)
	battle.cam._unhandled_input(ev)


func _click(button: MouseButton, at: Vector2, shift: bool, double_click: bool = false) -> void:
	var down: InputEventMouseButton = InputEventMouseButton.new()
	down.button_index = button
	down.pressed = true
	down.position = at
	down.shift_pressed = shift
	down.double_click = double_click
	_send(down)
	var up: InputEventMouseButton = InputEventMouseButton.new()
	up.button_index = button
	up.pressed = false
	up.position = at
	up.shift_pressed = shift
	up.double_click = double_click
	_send(up)


func _drag(from: Vector2, to: Vector2) -> void:
	var down: InputEventMouseButton = InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = from
	_send(down)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = to
	motion.relative = to - from
	_send(motion)
	var up: InputEventMouseButton = InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = to
	_send(up)


func _key(code: Key, ctrl: bool, shift: bool) -> void:
	var ev: InputEventKey = InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = true
	ev.ctrl_pressed = ctrl
	ev.shift_pressed = shift
	_send(ev)
