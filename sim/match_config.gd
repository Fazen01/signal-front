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
var map_cells: int = SimMapGen.STANDARD_CELLS  ## size of a generated two-player map
var map_id: String = ""  ## a layout in data/maps, or "" for a generated map
var region: String = ""  ## a SimMapGen region, or "" for the seed's (or the layout's) own
var watch: bool = false  ## nobody plays: every side is an AI and the person at the screen watches
var tutorial: String = ""  ## a SimTutorial mission id, or "" for a normal match
var factions: Array[String] = ["aegis", "aegis"]
var is_ai: Array[bool] = [false, true]
var ai_levels: Array[int] = [1, 1]
var names: Array[String] = ["Commander", "Opponent"]
## Team number per player. Players with the same number are allies. Empty
## (or too short) means every player without an entry is on a team alone.
var teams: Array[int] = []


func player_count() -> int:
	return factions.size()


static func skirmish(seed_number: int, ai_level: int = 1) -> MatchConfig:
	var c: MatchConfig = MatchConfig.new()
	c.seed_value = seed_number
	c.ai_levels = [1, ai_level]
	return c


## The team of player `i`: its entry in `teams`, or a team of its own.
func team_of(i: int) -> int:
	if i < teams.size():
		return teams[i]
	return 100 + i


## True when at least two players share a team.
func has_allies() -> bool:
	for i: int in player_count():
		for j: int in range(i + 1, player_count()):
			if team_of(i) == team_of(j):
				return true
	return false


## Adds an AI player. `team` -1 puts it on a team of its own.
func add_ai(faction_id: String, level: int, ai_name: String, team: int = -1) -> void:
	if team >= 0:
		# Everyone before it needs an entry first.
		while teams.size() < factions.size():
			teams.append(100 + teams.size())
		teams.append(team)
	factions.append(faction_id)
	is_ai.append(true)
	ai_levels.append(level)
	names.append(ai_name)


## How many starts the map needs: generated maps come in two sizes.
func starts_needed() -> int:
	return 4 if player_count() > 2 else 2


## Both sides played by the AI; used by the headless match and demos.
static func ai_vs_ai(seed_number: int) -> MatchConfig:
	var c: MatchConfig = MatchConfig.new()
	c.seed_value = seed_number
	c.is_ai = [true, true]
	c.names = ["North AI", "South AI"]
	return c
