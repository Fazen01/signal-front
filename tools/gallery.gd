extends Node3D
## Lays out every model on a neutral floor so a session without a screen can
## check them in a screenshot (tools/screenshot.sh gallery 10 "" res://tools/gallery.tscn).


func _ready() -> void:
	var data: GameData = GameData.shared()
	SceneLight.add_to(self, true)
	var floor_mesh: PlaneMesh = PlaneMesh.new()
	floor_mesh.size = Vector2(120.0, 120.0)
	var floor_node: MeshInstance3D = MeshInstance3D.new()
	floor_node.mesh = floor_mesh
	floor_node.material_override = ModelFactory.mat(Color(0.36, 0.44, 0.24))
	add_child(floor_node)

	var units: Array[EntityDef] = []
	var buildings: Array[EntityDef] = []
	for def: EntityDef in data.entities.values():
		if def.is_building:
			buildings.append(def)
		else:
			units.append(def)
	# "page<N>" as the capture script shows eight models at a time, close up:
	# tools/screenshot.sh gallery_p0 10 page0 res://tools/gallery.tscn
	for arg: String in OS.get_cmdline_user_args():
		# "upage<N>": the same, counting units only (so that the last units
		# do not share a page with the first buildings).
		if arg.begins_with("--script=upage"):
			_show_page(units, int(arg.trim_prefix("--script=upage")))
			return
		if arg.begins_with("--script=page"):
			_show_page(units + buildings, int(arg.trim_prefix("--script=page")))
			return
	# Units in rows of seven at the front, buildings in rows of five behind.
	var i: int = 0
	for def: EntityDef in units:
		var model: Node3D = ModelFactory.build(def.model, MatchConfig.TEAM_COLORS[0])
		_put(model, Vector3(-15.0 + float(i % 7) * 5.0, def.altitude() * 0.35, 9.0 + float(i / 7) * 6.5), def.name)
		i += 1
	_put(ModelFactory.build_wreck("bulwark", 3), Vector3(-15.0 + float(i % 7) * 5.0, 0.0, 9.0 + float(i / 7) * 6.5), "Wreck")
	i = 0
	for def: EntityDef in buildings:
		_put(ModelFactory.build(def.model, MatchConfig.TEAM_COLORS[1]), Vector3(-18.0 + float(i % 5) * 9.5, 0.0, -14.0 + float(i / 5) * 10.0), def.name)
		i += 1
	_put(ModelFactory.build_field(5), Vector3(22.0, 0.0, 9.0), "Salvage Field")
	_put(ModelFactory.build_uplink(), Vector3(22.0, 0.0, 16.0), "Uplink Site")

	var cam: Camera3D = Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	cam.look_at_from_position(Vector3(2.0, 40.0, 46.0), Vector3(2.0, 0.0, 3.0), Vector3.UP)
	cam.current = true


func _show_page(defs: Array[EntityDef], page: int) -> void:
	for k: int in 8:
		var index: int = page * 8 + k
		if index >= defs.size():
			break
		var def: EntityDef = defs[index]
		var model: Node3D = ModelFactory.build(def.model, MatchConfig.TEAM_COLORS[index % 2])
		var gap: float = 9.5 if def.is_building else 5.5
		_put(model, Vector3((float(k % 4) - 1.5) * gap, def.altitude() * 0.35, (float(k / 4) - 0.5) * gap), def.name)
	var close: bool = page * 8 < defs.size() and not defs[page * 8].is_building
	var cam: Camera3D = Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	if close:
		cam.look_at_from_position(Vector3(0.0, 13.0, 15.0), Vector3(0.0, 0.0, 0.6), Vector3.UP)
	else:
		cam.look_at_from_position(Vector3(0.0, 24.0, 27.0), Vector3(0.0, 0.0, 1.5), Vector3.UP)
	cam.current = true


func _put(model: Node3D, at: Vector3, label: String) -> void:
	model.position = at
	model.rotation.y = -0.6
	add_child(model)
	var text: Label3D = Label3D.new()
	text.text = label
	text.font_size = 48
	text.pixel_size = 0.012
	text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	text.position = at + Vector3(0.0, -0.1, 3.4)
	text.no_depth_test = true
	add_child(text)
