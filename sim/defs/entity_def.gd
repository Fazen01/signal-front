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
var capacity: int = 0

# Buildings
var footprint: Vector2i = Vector2i(1, 1)  ## size in map cells
var signal_radius: float = 0.0
var signal_root: bool = false
var depot: bool = false
var produces: Array[String] = []
var directive_cooldown_mult: float = 1.0  ## owning one shortens Directive cooldowns

const AIR_ALTITUDE: float = 6.0


func is_infantry() -> bool:
	return move == MOVE_INFANTRY


func is_vehicle() -> bool:
	return move == MOVE_VEHICLE


func is_air() -> bool:
	return move == MOVE_AIR


## Height above the ground this entity is drawn (and aimed) at.
func altitude() -> float:
	return AIR_ALTITUDE if move == MOVE_AIR else 0.0


func is_armed() -> bool:
	return weapons.size() > 0


func max_weapon_range() -> float:
	var best: float = 0.0
	for w: WeaponDef in weapons:
		best = maxf(best, w.max_range)
	return best
