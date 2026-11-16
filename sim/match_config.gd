class_name MatchConfig
extends RefCounted
## Everything needed to start a match.

const TEAM_COLORS: Array[Color] = [
	Color(0.20, 0.55, 1.00),
	Color(1.00, 0.30, 0.22),
	Color(0.30, 0.85, 0.35),
	Color(1.00, 0.80, 0.20),
]

var seed_value: int = 1
var map_cells: int = 64
var factions: Array[String] = ["aegis", "aegis"]
var is_ai: Array[bool] = [false, true]
var ai_levels: Array[int] = [1, 1]
var names: Array[String] = ["Commander", "Opponent"]


func player_count() -> int:
	return factions.size()


static func skirmish(seed_number: int, ai_level: int = 1) -> MatchConfig:
	var c: MatchConfig = MatchConfig.new()
	c.seed_value = seed_number
	c.ai_levels = [1, ai_level]
	return c


## Both sides played by the AI; used by the headless match and demos.
static func ai_vs_ai(seed_number: int) -> MatchConfig:
	var c: MatchConfig = MatchConfig.new()
	c.seed_value = seed_number
	c.is_ai = [true, true]
	c.names = ["North AI", "South AI"]
	return c
