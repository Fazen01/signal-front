class_name SelectionController
extends Node
## Mouse and keyboard control of the local player's forces: selection,
## context orders, command hotkeys and control groups. Talks to the sim only
## through SimCommand.

signal selection_changed

const DRAG_THRESHOLD: float = 6.0
const DOUBLE_TAP_MS: int = 350

enum Mode { NORMAL, ATTACK_MOVE }

var battle: BattleScene = null
var world: SimWorld = null
var cam: RtsCamera = null
var player: int = 0
var selected: Array[int] = []
var groups: Array[PackedInt32Array] = []
var mode: int = Mode.NORMAL
var dragging: bool = false
var drag_start: Vector2 = Vector2.ZERO
var drag_now: Vector2 = Vector2.ZERO
var _last_group: int = -1
var _idle_cursor: int = 0
var _bookmarks: Dictionary[int, Vector4] = {}  ## F5..F8 -> focus x, focus z, yaw, distance
var _last_group_ms: int = 0


func setup(scene: BattleScene) -> void:
	battle = scene
	world = scene.world
	cam = scene.cam
	player = scene.local_player
	groups.resize(10)
	for i: int in 10:
		groups[i] = PackedInt32Array()


# ------------------------------------------------------------- selection

func selected_entities() -> Array[SimEntity]:
	var out: Array[SimEntity] = []
	for id: int in selected:
		var e: SimEntity = world.get_entity(id)
		if e != null:
			out.append(e)
	return out


func selected_ids() -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for e: SimEntity in selected_entities():
		out.append(e.id)
	return out


## Ids of selected units owned by the local player (the ones that take orders).
func own_unit_ids() -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for e: SimEntity in selected_entities():
		if e.owner == player and e.kind == SimEntity.Kind.UNIT:
			out.append(e.id)
	return out


func set_selection(ids: Array[int]) -> void:
	selected = ids
	selection_changed.emit()


func clear_selection() -> void:
	set_selection([])


## Drops dead entities from the selection. Called every frame by the scene.
func prune() -> void:
	var kept: Array[int] = []
	for id: int in selected:
		if world.get_entity(id) != null:
			kept.append(id)
	if kept.size() != selected.size():
		set_selection(kept)


# --------------------------------------------------------------- picking

func screen_pos(e: SimEntity) -> Vector2:
	return cam.cam.unproject_position(Vector3(e.pos.x, world.map.height_at(e.pos) + 0.5, e.pos.y))


func is_on_screen(e: SimEntity) -> bool:
	var wp: Vector3 = Vector3(e.pos.x, world.map.height_at(e.pos) + 0.5, e.pos.y)
	if cam.cam.is_position_behind(wp):
		return false
	return cam.get_viewport().get_visible_rect().has_point(cam.cam.unproject_position(wp))


## World (x, z) under a screen position.
func ground_point(screen: Vector2) -> Vector2:
	var from: Vector3 = cam.cam.project_ray_origin(screen)
	var dir: Vector3 = cam.cam.project_ray_normal(screen)
	var y: float = 0.0
	var hit: Vector3 = from
	for i: int in 3:
		if absf(dir.y) < 0.0001:
			break
		var t: float = (y - from.y) / dir.y
		hit = from + dir * t
		y = world.map.height_at(Vector2(hit.x, hit.z))
	return Vector2(hit.x, hit.z)


## The entity under a screen position: units first, then whatever stands on
## the ground point (buildings by footprint, fields and wrecks by radius).
func pick_entity(screen: Vector2) -> SimEntity:
	var best: SimEntity = null
	var best_d: float = INF
	var right: Vector3 = cam.cam.global_transform.basis.x
	for e: SimEntity in world.entities:
		if not e.alive or e.kind != SimEntity.Kind.UNIT or not battle.world_view.is_shown(e.id):
			continue
		var wp: Vector3 = Vector3(e.pos.x, world.map.height_at(e.pos) + 0.6, e.pos.y)
		if cam.cam.is_position_behind(wp):
			continue
		var sp: Vector2 = cam.cam.unproject_position(wp)
		var edge: Vector2 = cam.cam.unproject_position(wp + right * e.radius)
		var reach: float = maxf(sp.distance_to(edge) * 1.3, 12.0)
		var d: float = sp.distance_to(screen)
		if d <= reach and d < best_d:
			best_d = d
			best = e
	if best != null:
		return best
	var g: Vector2 = ground_point(screen)
	var occupant: SimEntity = world.get_entity(world.map.occupant_at(world.map.cell_of(g)))
	if occupant != null and battle.world_view.is_shown(occupant.id):
		return occupant
	for e: SimEntity in world.entities:
		if e.alive and e.kind != SimEntity.Kind.UNIT and e.pos.distance_to(g) <= e.radius + 0.3 and battle.world_view.is_shown(e.id):
			return e
	return null


# ----------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if world == null or battle.is_input_blocked():
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null:
		_on_mouse_button(mb)
		return
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null:
		if dragging:
			drag_now = mm.position
		return
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo:
		_on_key(key)


func _on_mouse_button(mb: InputEventMouseButton) -> void:
	if mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			if mode == Mode.ATTACK_MOVE:
				order_attack_move(ground_point(mb.position), mb.shift_pressed)
				if not mb.shift_pressed:
					mode = Mode.NORMAL
				return
			if battle.on_left_click(mb.position, mb.shift_pressed):
				return
			dragging = true
			drag_start = mb.position
			drag_now = mb.position
		elif dragging:
			dragging = false
			if drag_start.distance_to(mb.position) < DRAG_THRESHOLD:
				_click_select(mb.position, mb.shift_pressed, mb.double_click)
			else:
				_box_select(Rect2(drag_start, mb.position - drag_start).abs(), mb.shift_pressed)
	elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
		if mode != Mode.NORMAL:
			mode = Mode.NORMAL
			return
		if battle.on_right_click(mb.position):
			return
		context_order(mb.position, mb.shift_pressed)


func _click_select(screen: Vector2, add: bool, double_click: bool) -> void:
	var e: SimEntity = pick_entity(screen)
	if e == null:
		if not add:
			clear_selection()
		return
	if double_click and e.owner == player and e.kind == SimEntity.Kind.UNIT:
		select_same_type_on_screen(e, add)
		return
	if add and e.owner == player:
		var ids: Array[int] = selected.duplicate()
		if ids.has(e.id):
			ids.erase(e.id)
		else:
			# Mixed selections are own units only.
			ids = _own_only(ids)
			ids.append(e.id)
		set_selection(ids)
	else:
		set_selection([e.id])


func _own_only(ids: Array[int]) -> Array[int]:
	var out: Array[int] = []
	for id: int in ids:
		var e: SimEntity = world.get_entity(id)
		if e != null and e.owner == player:
			out.append(id)
	return out


func select_same_type_on_screen(sample: SimEntity, add: bool) -> void:
	var ids: Array[int] = []
	if add:
		ids = _own_only(selected)
	for e: SimEntity in world.entities:
		if e.alive and e.owner == player and e.def == sample.def and is_on_screen(e) and not ids.has(e.id):
			ids.append(e.id)
	set_selection(ids)


func _box_select(rect: Rect2, add: bool) -> void:
	var units: Array[int] = []
	var buildings: Array[int] = []
	for e: SimEntity in world.entities:
		if not e.alive or e.owner != player:
			continue
		var wp: Vector3 = Vector3(e.pos.x, world.map.height_at(e.pos) + 0.5, e.pos.y)
		if cam.cam.is_position_behind(wp):
			continue
		if rect.has_point(cam.cam.unproject_position(wp)):
			if e.kind == SimEntity.Kind.UNIT:
				units.append(e.id)
			elif e.kind == SimEntity.Kind.BUILDING:
				buildings.append(e.id)
	var picked: Array[int] = units if not units.is_empty() else buildings
	if picked.is_empty():
		if not add:
			clear_selection()
		return
	if add:
		var ids: Array[int] = _own_only(selected)
		for id: int in picked:
			if not ids.has(id):
				ids.append(id)
		set_selection(ids)
	else:
		set_selection(picked)


func _on_key(key: InputEventKey) -> void:
	var code: Key = key.physical_keycode
	if code >= KEY_1 and code <= KEY_6 and key.alt_pressed:
		battle.hud.activate_directive(int(code) - int(KEY_1))
		get_viewport().set_input_as_handled()
		return
	if code >= KEY_0 and code <= KEY_9:
		var index: int = int(code) - int(KEY_0)
		if key.ctrl_pressed:
			groups[index] = PackedInt32Array(_own_only(selected))
		else:
			_recall_group(index, key.shift_pressed)
		get_viewport().set_input_as_handled()
		return
	if code >= KEY_F5 and code <= KEY_F8:
		if key.ctrl_pressed:
			_bookmarks[int(code)] = Vector4(cam.focus.x, cam.focus.y, cam.yaw, cam.distance)
		elif _bookmarks.has(int(code)):
			var b: Vector4 = _bookmarks[int(code)]
			cam.yaw = b.z
			cam.set_distance(b.w)
			cam.center_on(Vector2(b.x, b.y))
		get_viewport().set_input_as_handled()
		return
	if code == KEY_PERIOD or code == KEY_F1:
		select_next_idle_builder()
		get_viewport().set_input_as_handled()
		return
	if key.ctrl_pressed or key.alt_pressed:
		return
	if battle.on_hotkey(key):
		get_viewport().set_input_as_handled()
		return
	var ids: PackedInt32Array = own_unit_ids()
	if ids.is_empty():
		return
	match code:
		KEY_A:
			mode = Mode.ATTACK_MOVE
			get_viewport().set_input_as_handled()
		KEY_S:
			world.push_command(SimCommand.stop(player, ids))
			get_viewport().set_input_as_handled()
		KEY_H:
			world.push_command(SimCommand.hold(player, ids))
			get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			if mode != Mode.NORMAL:
				mode = Mode.NORMAL
				get_viewport().set_input_as_handled()


## Selects the next builder that has nothing to do and looks at it.
func select_next_idle_builder() -> bool:
	var idle: Array[SimEntity] = []
	for e: SimEntity in world.entities:
		if e.alive and e.owner == player and e.kind == SimEntity.Kind.UNIT and e.def.builder and e.orders.is_empty():
			idle.append(e)
	if idle.is_empty():
		return false
	_idle_cursor = (_idle_cursor + 1) % idle.size()
	var pick: SimEntity = idle[_idle_cursor]
	set_selection([pick.id])
	cam.center_on(pick.pos)
	return true


func _recall_group(index: int, add: bool) -> void:
	var ids: Array[int] = []
	if add:
		ids = _own_only(selected)
	for id: int in groups[index]:
		if world.get_entity(id) != null and not ids.has(id):
			ids.append(id)
	if ids.is_empty():
		return
	set_selection(ids)
	var now: int = Time.get_ticks_msec()
	if _last_group == index and now - _last_group_ms < DOUBLE_TAP_MS:
		var centre: Vector2 = Vector2.ZERO
		var n: int = 0
		for e: SimEntity in selected_entities():
			centre += e.pos
			n += 1
		if n > 0:
			cam.center_on(centre / float(n))
	_last_group = index
	_last_group_ms = now


# ---------------------------------------------------------------- orders

func order_attack_move(at: Vector2, queued: bool) -> void:
	var ids: PackedInt32Array = own_unit_ids()
	if ids.is_empty():
		return
	world.push_command(SimCommand.attack_move(player, ids, at, queued))
	battle.show_order_marker(at, Color(1.0, 0.35, 0.3))


## An order given on the minimap: move (or attack-move while A is armed).
func order_at_world(at: Vector2, queued: bool) -> void:
	var ids: PackedInt32Array = own_unit_ids()
	if ids.is_empty():
		return
	if mode == Mode.ATTACK_MOVE:
		order_attack_move(at, queued)
		mode = Mode.NORMAL
		return
	world.push_command(SimCommand.move(player, ids, at, queued))
	battle.show_order_marker(at, Color(0.4, 1.0, 0.5))


## Right-click: decide what the selection should do with whatever is there.
func context_order(screen: Vector2, queued: bool) -> void:
	var at: Vector2 = ground_point(screen)
	var target: SimEntity = pick_entity(screen)
	var ids: PackedInt32Array = own_unit_ids()
	if ids.is_empty():
		# Buildings only: set rally points.
		for e: SimEntity in selected_entities():
			if e.owner == player and e.kind == SimEntity.Kind.BUILDING and not e.def.produces.is_empty():
				world.push_command(SimCommand.rally(player, e.id, at))
				battle.show_order_marker(at, Color(0.4, 0.8, 1.0))
		return
	if target != null and world.are_enemies(player, target.owner):
		world.push_command(SimCommand.attack(player, ids, target.id, queued))
		battle.show_order_marker(target.pos, Color(1.0, 0.3, 0.25))
		return
	if target != null and target.kind == SimEntity.Kind.UPLINK and target.owner != player:
		var capturers: PackedInt32Array = _filter(ids, func(e: SimEntity) -> bool: return e.def.builder)
		if not capturers.is_empty():
			world.push_command(SimCommand.capture(player, capturers, target.id, queued))
			battle.show_order_marker(target.pos, Color(0.9, 0.9, 1.0))
			return
	if target != null and target.is_harvestable():
		var haulers: PackedInt32Array = _filter(ids, func(e: SimEntity) -> bool: return e.def.harvester)
		if not haulers.is_empty():
			world.push_command(SimCommand.harvest(player, haulers, target.id, queued))
			battle.show_order_marker(target.pos, Color(1.0, 0.85, 0.3))
			var rest: PackedInt32Array = _filter(ids, func(e: SimEntity) -> bool: return not e.def.harvester)
			if not rest.is_empty():
				world.push_command(SimCommand.move(player, rest, at, queued))
			return
	if target != null and target.owner == player and target.kind == SimEntity.Kind.BUILDING:
		var builders: PackedInt32Array = _filter(ids, func(e: SimEntity) -> bool: return e.def.builder)
		if not builders.is_empty() and (not target.constructed or target.hp < target.max_hp):
			world.push_command(SimCommand.repair(player, builders, target.id, queued))
			battle.show_order_marker(target.pos, Color(0.4, 1.0, 0.5))
			return
		var loaded: PackedInt32Array = _filter(ids, func(e: SimEntity) -> bool: return e.def.harvester)
		if not loaded.is_empty() and target.def.depot and target.constructed:
			world.push_command(SimCommand.harvest(player, loaded, target.id, queued))
			battle.show_order_marker(target.pos, Color(1.0, 0.85, 0.3))
			return
	world.push_command(SimCommand.move(player, ids, at, queued))
	battle.show_order_marker(at, Color(0.4, 1.0, 0.5))


func _filter(ids: PackedInt32Array, keep: Callable) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for id: int in ids:
		var e: SimEntity = world.get_entity(id)
		if e != null and keep.call(e):
			out.append(id)
	return out
