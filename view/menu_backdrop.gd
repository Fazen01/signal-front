class_name MenuBackdrop
extends Node3D
## A live AI-versus-AI match playing behind the main menu, watched by a
## slowly circling camera. No fog, no sound and no input; when the match
## ends another starts on a new seed.

const FACTIONS: Array[String] = ["aegis", "foundry", "nomad", "vesper"]

var world: SimWorld = null
var _stage: Node3D = null  ## terrain and entities of the current match
var _view: WorldView = null
var _cam: Camera3D = null
var _accum: float = 0.0
var _time: float = 0.0
var _round: int = 0
var _rest: float = 0.0  ## seconds the finished match stays on screen
var caption: String = ""  ## "Live match: A vs B", for the menu to show


func _ready() -> void:
	GameSettings.ensure_loaded()
	_cam = Camera3D.new()
	_cam.name = "Camera"
	_cam.fov = 42.0
	_cam.far = 600.0
	add_child(_cam)
	_cam.current = true
	_start()


func _start() -> void:
	if _stage != null:
		_stage.queue_free()
	_stage = Node3D.new()
	_stage.name = "Stage"
	add_child(_stage)
	var config: MatchConfig = MatchConfig.ai_vs_ai(31 + _round * 7)
	config.factions = [FACTIONS[_round % FACTIONS.size()], FACTIONS[(_round + 1) % FACTIONS.size()]]
	world = SimSetup.create_match(config)
	SceneLight.add_to(_stage, GameSettings.shadows, world.map.region)
	caption = "Live match:  %s  vs  %s" % [world.data.faction(config.factions[0]).name, world.data.faction(config.factions[1]).name]
	var terrain: TerrainView = TerrainView.new()
	terrain.name = "Terrain"
	_stage.add_child(terrain)
	terrain.build(world.map, config.seed_value)
	_view = WorldView.new()
	_view.name = "World"
	_view.fog_enabled = false
	_stage.add_child(_view)
	_view.setup(world, 0)
	_accum = 0.0
	_rest = 0.0
	_round += 1


func _process(delta: float) -> void:
	_time += delta
	if world.winner >= 0:
		_rest += delta
		if _rest > 6.0:
			_start()
	else:
		_accum += delta
		var steps: int = 0
		while _accum >= SimWorld.DT and steps < 3:
			world.tick()
			_accum -= SimWorld.DT
			steps += 1
			for ev: SimEvent in world.events:
				_view.handle_event(ev)
			world.events.clear()
		if steps >= 3:
			_accum = 0.0
	_view.sync(clampf(_accum / SimWorld.DT, 0.0, 1.0))
	# Circle the first player's base, leaning towards the middle of the map
	# where the fighting ends up.
	var size: Vector2 = world.map.world_size()
	var home: Vector2 = world.players[0].start_pos
	var focus: Vector2 = home.lerp(size * 0.5, 0.3)
	var yaw: float = _time * 0.045 + 0.6
	var reach: float = 58.0
	var eye: Vector3 = Vector3(focus.x + sin(yaw) * reach * 0.62, 40.0, focus.y + cos(yaw) * reach * 0.62)
	_cam.look_at_from_position(eye, Vector3(focus.x, world.map.height_at(focus), focus.y), Vector3.UP)
