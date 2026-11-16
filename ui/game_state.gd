class_name GameState
extends Node
## Autoload ("Game"). Carries the match configuration and result between
## scenes and switches scenes.

const MENU_SCENE: String = "res://scenes/main.tscn"
const BATTLE_SCENE: String = "res://scenes/battle.tscn"

var pending_config: MatchConfig = null
var last_config: MatchConfig = null


func _ready() -> void:
	# Menus keep working while a match is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_cmdline_user_args().has("--flow-smoke"):
		var smoke: FlowSmoke = FlowSmoke.new()
		smoke.name = "FlowSmoke"
		add_child(smoke)


func start_match(config: MatchConfig) -> void:
	pending_config = config
	last_config = config
	get_tree().change_scene_to_file(BATTLE_SCENE)


## The battle scene calls this once; returns a default skirmish when the
## scene was started directly.
func take_config() -> MatchConfig:
	var c: MatchConfig = pending_config
	pending_config = null
	if c == null:
		c = MatchConfig.skirmish(1)
		last_config = c
	return c


func to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)
