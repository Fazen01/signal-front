class_name MatchConfig
extends RefCounted
## Everything needed to start a match.

const TEAM_COLORS: Array[Color] = [
	Color(0.20, 0.55, 1.00),
	Color(1.00, 0.30, 0.22),
	Color(0.30, 0.85, 0.35),
	Color(1.00, 0.80, 0.20),
]

const LONE_TEAM: int = 1000  ## team numbers from here up mean "on its own"

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
var teams: Array[int] = []  ## the team of each seat; a seat past the end of the list is on a team of its own


func player_count() -> int:
	return factions.size()


static func skirmish(seed_number: int, ai_level: int = 1) -> MatchConfig:
	var c: MatchConfig = MatchConfig.new()
	c.seed_value = seed_number
	c.ai_levels = [1, ai_level]
	return c


## Adds an AI: an opponent, or an ally when it is given the team of another seat.
func add_ai(faction_id: String, level: int, ai_name: String, team: int = -1) -> void:
	factions.append(faction_id)
	is_ai.append(true)
	ai_levels.append(level)
	names.append(ai_name)
	if team >= 0:
		set_team(factions.size() - 1, team)


## Seats with the same team number fight on the same side.
func set_team(seat: int, team: int) -> void:
	while teams.size() <= seat:
		teams.append(LONE_TEAM + teams.size())
	teams[seat] = team


func team_of(seat: int) -> int:
	return teams[seat] if seat < teams.size() else LONE_TEAM + seat


## True when at least two seats share a team.
func has_teams() -> bool:
	for a: int in player_count():
		for b: int in range(a + 1, player_count()):
			if team_of(a) == team_of(b):
				return true
	return false


## How many sides there are: a match needs at least two.
func side_count() -> int:
	var seen: Dictionary[int, bool] = {}
	for i: int in player_count():
		seen[team_of(i)] = true
	return seen.size()


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
