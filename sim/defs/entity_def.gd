class_name EntityDef
extends RefCounted
## One unit or building definition, loaded from data/units.json or
## data/buildings.json.

const MOVE_NONE: int = 0
const MOVE_INFANTRY: int = 1
const MOVE_VEHICLE: int = 2
const MOVE_AIR: int = 3

var id: String = ""
var name: String = ""
var desc: String = ""
var faction: String = ""
var is_building: bool = false
var tier: int = 1
var cost: int = 0
var build_time: float = 1.0  ## seconds
var bandwidth: int = 0  ## population used
var bandwidth_provided: int = 0
var hp: float = 1.0
var armor: int = 0  ## index into GameData.armor_classes
var move: int = MOVE_NONE
var speed: float = 0.0
var turn_rate: float = 10.0  ## radians per second
var radius: float = 0.5
var sight: float = 8.0
var weapons: Array[WeaponDef] = []
var turret: bool = false  ## weapon is on a traversing turret
var model: String = ""
var hotkey: String = ""
var requires: Array[String] = []
var buildable: bool = true

# Units
var builder: bool = false
var builds: Array[String] = []
var harvester: bool = false
var stealth: bool = false  ## hidden from enemies while standing still
var detect_range: float = 5.0  ## how close an enemy must be to see it while stealthed
var deploys_to: String = ""  ## unit -> building it deploys into
var repair_rate: float = 0.0  ## hp per second this unit repairs on nearby friends
var repair_radius: float = 0.0
var jam_radius: float = 0.0  ## > 0: removes enemy coverage this far around the unit
var hijacker: bool = false  ## can take over enemy vehicles that are Dark
# Auras: what a unit does to everything within `aura_radius` of it.
var aura_radius: float = 0.0
var aura_rof: float = 0.0  ## friends fire this much faster (0.2 = a fifth)
var aura_cloak: bool = false  ## friendly ground units are hidden while they stand still
var aura_slow: float = 0.0  ## enemy units move this much slower
var aura_link: bool = false  ## friendly units count as Linked, wherever they are
var ai_role: String = ""  ## how the skirmish AI classes this unit
var ai_weight: float = 0.0  ## base production weight for the AI (0 = never built for the army)
var capacity: int = 0

# Buildings
var footprint: Vector2i = Vector2i(1, 1)  ## size in map cells
var signal_radius: float = 0.0
var signal_root: bool = false
var depot: bool = false
var produces: Array[String] = []
var directive_cooldown_mult: float = 1.0  ## owning one shortens Directive cooldowns
var blocks: bool = true  ## occupies its footprint cells (mines do not)
var needs_coverage: bool = true  ## must be placed inside own coverage
var packs_to: String = ""  ## building -> unit it packs up into
var mine_trigger: float = 0.0  ## > 0: explodes when an enemy ground unit is this close
var mine_damage: float = 0.0
var mine_splash: float = 0.0

const AIR_ALTITUDE: float = 6.0


# Filled in by GameData after loading: the best this entity's weapons can do
# against each armor class, so targeting never has to loop over weapons.
var vs_armor: PackedFloat32Array = PackedFloat32Array()  ## best damage multiplier
var reach_vs: PackedFloat32Array = PackedFloat32Array()  ## longest usable range
var min_range_vs: PackedFloat32Array = PackedFloat32Array()  ## shortest minimum range


func is_infantry() -> bool:
	return move == MOVE_INFANTRY


func is_vehicle() -> bool:
	return move == MOVE_VEHICLE


func is_air() -> bool:
	return move == MOVE_AIR


## Height above the ground this entity is drawn (and aimed) at.
func altitude() -> float:
	return AIR_ALTITUDE if move == MOVE_AIR else 0.0


func is_mine() -> bool:
	return mine_trigger > 0.0


func is_armed() -> bool:
	return weapons.size() > 0


func max_weapon_range() -> float:
	var best: float = 0.0
	for w: WeaponDef in weapons:
		best = maxf(best, w.max_range)
	return best
