extends Node3D
## Lays out every model on a neutral floor so a session without a screen can
## check them in a screenshot (tools/screenshot.sh gallery 10 "" res://tools/gallery.tscn).


func _ready() -> void:
	var data: GameData = GameData.shared()
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	sun.shadow_enabled = true
	add_child(sun)
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.1, 0.12, 0.14)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.65, 0.7, 0.8)
	env.ambient_light_energy = 0.6
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	add_child(we)
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
