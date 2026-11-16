class_name SimEntity
extends RefCounted
## Any object in the simulation: a unit, a building, a wreck, a salvage field
## or an uplink site. Plain data; SimWorld and its systems do the work.

enum Kind { UNIT, BUILDING, WRECK, FIELD, UPLINK }

var id: int = 0
var kind: int = Kind.UNIT
var def: EntityDef = null  ## null for wrecks, fields and uplinks
var owner: int = -1  ## player id, -1 = neutral
var alive: bool = true

# Transform. The simulation is 2D: pos.x is world X, pos.y is world Z.
var pos: Vector2 = Vector2.ZERO
var prev_pos: Vector2 = Vector2.ZERO
var facing: float = 0.0  ## radians, 0 = +X
var prev_facing: float = 0.0
var aim: float = 0.0  ## turret direction in world space
var prev_aim: float = 0.0
var radius: float = 0.5

var hp: float = 1.0
var max_hp: float = 1.0

# Orders and movement
var orders: Array[SimOrder] = []
var hold: bool = false
var moving: bool = false
var path: PackedVector2Array = PackedVector2Array()
var path_index: int = 0
var move_goal: Vector2 = Vector2.ZERO
var stuck_ticks: int = 0
var repath_tick: int = 0
var last_progress: float = 0.0
var chasing: bool = false  ## moving because of an auto-acquired target
var guard_pos: Vector2 = Vector2.ZERO  ## where the unit last went idle

# Combat
var target_id: int = 0  ## current weapon target, 0 = none
var cooldowns: PackedInt32Array = PackedInt32Array()  ## ticks until each weapon is ready
var scan_tick: int = 0  ## next tick to look for targets
var last_hit_tick: int = -100000
var last_fire_tick: int = -100000
var last_attacker: int = 0
var kills: int = 0
var xp: float = 0.0
var rank: int = 0

# Fire (see SimCombat.ignite)
var burn_until: int = 0  ## tick the fire goes out, 0 = not burning
var burn_dps: float = 0.0
var burn_owner: int = -1  ## who set it, for the credit if it kills

# Signal
var linked: bool = true  ## emitters: chained to the HQ; others: inside own coverage

# Economy (haulers, wrecks, fields)
var cargo: int = 0
var salvage: int = 0  ## salvage left in a field or wreck
var work_ticks: int = 0  ## progress of harvesting or unloading
var job: int = 0  ## SimEconomy.Job state of a hauler
var harvest_target: int = 0
var decay_tick: int = 0  ## wrecks vanish at this tick

# Construction and production (buildings)
var constructed: bool = true
var build_progress: float = 1.0  ## 0..1
var builders_now: int = 0  ## builders that worked on this building this tick
var footprint_cell: Vector2i = Vector2i.ZERO  ## top-left cell
var queue: Array[String] = []
var prod_progress: float = 0.0  ## seconds of work on queue[0]
var rally: Vector2 = Vector2.ZERO
var has_rally: bool = false

# Uplink sites
var capture_progress: float = 0.0  ## seconds of capture work so far
var capturer: int = -1  ## player currently capturing

# Wreck visuals
var wreck_model: String = ""


func is_unit() -> bool:
	return kind == Kind.UNIT


func is_building() -> bool:
	return kind == Kind.BUILDING


func is_mobile() -> bool:
	return kind == Kind.UNIT


func is_combatant() -> bool:
	return kind == Kind.UNIT or kind == Kind.BUILDING


func is_harvestable() -> bool:
	return alive and salvage > 0 and (kind == Kind.WRECK or kind == Kind.FIELD)


func current_order() -> SimOrder:
	if orders.is_empty():
		return null
	return orders[0]


func hp_fraction() -> float:
	return clampf(hp / max_hp, 0.0, 1.0)
