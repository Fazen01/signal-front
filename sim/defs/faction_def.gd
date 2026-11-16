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
var roles: Dictionary[String, String] = {}  ## what the AI builds for each job (see SimAI)
var playable: bool = true


## The definition id this faction uses for a role, or "" if it has none.
func role(role_name: String) -> String:
	return roles.get(role_name, "")
