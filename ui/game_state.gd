class_name GameState
extends Node
## Autoload ("Game"). Carries the match configuration and result between
## scenes and switches scenes.

const MENU_SCENE: String = "res://scenes/main.tscn"
const BATTLE_SCENE: String = "res://scenes/battle.tscn"

var pending_config: MatchConfig = null
var pending_world: SimWorld = null  ## a loaded save waiting for the battle scene
var loaded_slot: String = ""  ## the manual slot the current match was loaded from, if any
var last_config: MatchConfig = null


func _ready() -> void:
	# Menus keep working while a match is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# One theme for every menu and HUD element.
	get_tree().root.theme = UiTheme.theme()
	GameSettings.ensure_loaded()
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


## Loads a save slot (the one written last, if none is named) and continues
## that match. Returns false if there is no usable save there.
func load_saved_match(slot: String = "") -> bool:
	var from: String = slot if slot != "" else SimSave.newest_slot()
	if from == "":
		return false
	var d: Dictionary = SimSave.read_slot(from)
	if d.is_empty():
		return false
	var world: SimWorld = SimSave.from_dict(d)
	if world == null:
		return false
	pending_world = world
	pending_config = SimSave.config_from_dict(d["config"])
	last_config = pending_config
	# Saving again goes back to the slot the match came from, unless that
	# was the game's own autosave.
	loaded_slot = from if SimSave.MANUAL_SLOTS.has(from) else ""
	get_tree().change_scene_to_file(BATTLE_SCENE)
	return true


## The battle scene calls this once: a loaded world, or null for a new match.
func take_world() -> SimWorld:
	var w: SimWorld = pending_world
	pending_world = null
	return w


func to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)
