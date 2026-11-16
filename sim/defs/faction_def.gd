class_name FactionDef
extends RefCounted
## One faction definition, loaded from data/factions.json.

var id: String = ""
var name: String = ""
var desc: String = ""
var hq: String = ""
var start_units: Array[String] = []
var linked_range_bonus: float = 0.0
var dark_rof_mult: float = -1.0  ## -1 = use the global rule
var linked_vehicle_repair: float = 0.0  ## fraction of max hp per second for Linked vehicles
var forest_cloak: bool = false  ## ground units are hidden while standing still in forest
var wreck_salvage_mult: float = 1.0  ## bonus on salvage hauled from wrecks
var linked_speed_bonus: float = 0.0  ## extra move speed for Linked units (0.15 = 15% faster)
var linked_damage_resist: float = 0.0  ## share of damage Linked units shrug off (0.15 = 15% less)
var linked_sight_bonus: float = 0.0  ## extra sight for Linked units and buildings (0.25 = a quarter further)
var kill_bounty: float = 0.0  ## share of the value of everything destroyed that is paid out in salvage
var linked_cloak: bool = false  ## Linked ground units are hidden while they stand still
var drop_squad: Array[String] = []  ## units delivered by Reinforcement Drop
var roles: Dictionary[String, String] = {}  ## what the AI builds for each job (see SimAI)
var playable: bool = true


## The definition id this faction uses for a role, or "" if it has none.
func role(role_name: String) -> String:
	return roles.get(role_name, "")
