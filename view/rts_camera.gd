class_name RtsCamera
extends Node3D
## Top-down strategy camera: pan (keys, screen edge), zoom (wheel), rotate
## (Q/E or middle-drag), clamped to the map.

const MIN_DISTANCE: float = 14.0
const MAX_DISTANCE: float = 95.0
const MIN_PITCH: float = 0.60
const MAX_PITCH: float = 1.35
const EDGE_MARGIN: float = 10.0

var cam: Camera3D = null
var map: SimMap = null
var focus: Vector2 = Vector2.ZERO  ## world x, z the camera looks at
var yaw: float = 0.0
var pitch: float = 0.98
var distance: float = 42.0
var edge_pan: bool = true
var _rotating: bool = false
var _target_distance: float = 42.0


func setup(sim_map: SimMap, start_focus: Vector2) -> void:
	map = sim_map
	focus = start_focus
	cam = Camera3D.new()
	cam.name = "Camera"
	cam.fov = 42.0
	cam.near = 0.5
	cam.far = 400.0
	add_child(cam)
	cam.current = true
	_target_distance = distance
	_apply()


func ground_forward() -> Vector2:
	return -Vector2(sin(yaw), cos(yaw))


func ground_right() -> Vector2:
	return Vector2(cos(yaw), -sin(yaw))


func set_distance(d: float) -> void:
	distance = clampf(d, MIN_DISTANCE, MAX_DISTANCE)
	_target_distance = distance


func center_on(p: Vector2) -> void:
	focus = p
	_clamp_focus()
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null:
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_target_distance = maxf(MIN_DISTANCE, _target_distance * 0.88)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_target_distance = minf(MAX_DISTANCE, _target_distance * 1.14)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_rotating = mb.pressed
		return
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null and _rotating:
		yaw -= mm.relative.x * 0.006
		pitch = clampf(pitch + mm.relative.y * 0.004, MIN_PITCH, MAX_PITCH)


func _process(delta: float) -> void:
	var move: Vector2 = Vector2.ZERO
	if Input.is_action_pressed("cam_forward"):
		move.y += 1.0
	if Input.is_action_pressed("cam_back"):
		move.y -= 1.0
	if Input.is_action_pressed("cam_left"):
		move.x -= 1.0
	if Input.is_action_pressed("cam_right"):
		move.x += 1.0
	# A and S pan like W and D, whatever is selected (no unit order sits on
	# them), except with Ctrl held: Ctrl+A selects the army.
	if not Input.is_key_pressed(KEY_CTRL):
		if Input.is_physical_key_pressed(KEY_A):
			move.x -= 1.0
		if Input.is_physical_key_pressed(KEY_S):
			move.y -= 1.0
	if edge_pan and DisplayServer.get_name() != "headless" and get_window().has_focus():
		var vp: Viewport = get_viewport()
		var mouse: Vector2 = vp.get_mouse_position()
		var size: Vector2 = vp.get_visible_rect().size
		if mouse.x >= 0.0 and mouse.y >= 0.0 and mouse.x <= size.x and mouse.y <= size.y:
			if mouse.x < EDGE_MARGIN:
				move.x -= 1.0
			elif mouse.x > size.x - EDGE_MARGIN:
				move.x += 1.0
			if mouse.y < EDGE_MARGIN:
				move.y += 1.0
			elif mouse.y > size.y - EDGE_MARGIN:
				move.y -= 1.0
	if move != Vector2.ZERO:
		var speed: float = distance * 0.9
		focus += (ground_right() * move.x + ground_forward() * move.y).normalized() * speed * delta
	if Input.is_action_pressed("cam_rotate_left"):
		yaw += 1.6 * delta
	if Input.is_action_pressed("cam_rotate_right"):
		yaw -= 1.6 * delta
	distance = lerpf(distance, _target_distance, clampf(delta * 10.0, 0.0, 1.0))
	_clamp_focus()
	_apply()


func _clamp_focus() -> void:
	if map == null:
		return
	var size: Vector2 = map.world_size()
	focus = Vector2(clampf(focus.x, 0.0, size.x), clampf(focus.y, 0.0, size.y))


func _apply() -> void:
	if cam == null:
		return
	var y: float = map.height_at(focus) if map != null else 0.0
	var target: Vector3 = Vector3(focus.x, y, focus.y)
	var offset: Vector3 = Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
	cam.look_at_from_position(target + offset, target, Vector3.UP)
