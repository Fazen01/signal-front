class_name SimPlayer
extends RefCounted
## Per-player simulation state.

var id: int = 0
var name: String = ""
var faction: FactionDef = null
var color: Color = Color.WHITE
var is_ai: bool = false
var ai_level: int = 1  ## 0 easy, 1 normal, 2 hard
var team: int = 0
var start_pos: Vector2 = Vector2.ZERO
var defeated: bool = false

var salvage: int = 0
var bandwidth_used: int = 0
var bandwidth_cap: int = 0
var command_points: int = 0
var last_attack_alert: int = -100000  ## tick of the last "under attack" alert
var cp_progress: float = 0.0  ## destroyed value counted towards the next Command Point
var unlocked: Dictionary[String, bool] = {}  ## Directive ids
var directive_ready: Dictionary[String, int] = {}  ## Directive id -> tick it is ready again
var signal_radius_mult: float = 1.0  ## raised temporarily by Signal Surge
var surge_until: int = 0

# Completed building counts by def id; drives tech requirements.
var building_counts: Dictionary[String, int] = {}

# Match statistics, shown on the result screen.
var stat_units_built: int = 0
var stat_units_lost: int = 0
var stat_buildings_built: int = 0
var stat_buildings_lost: int = 0
var stat_kills: int = 0
var stat_value_destroyed: int = 0
var stat_salvage_collected: int = 0
var stat_salvage_spent: int = 0
var stat_directives_used: int = 0


func has_building(def_id: String) -> bool:
	return building_counts.get(def_id, 0) > 0


func meets_requirements(def: EntityDef) -> bool:
	for req: String in def.requires:
		if not has_building(req):
			return false
	return true
