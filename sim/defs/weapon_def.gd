class_name WeaponDef
extends RefCounted
## One weapon definition, loaded from data/weapons.json.

var id: String = ""
var name: String = ""
var damage_type: int = 0  ## index into GameData.DAMAGE_TYPES
var damage: float = 0.0
var max_range: float = 0.0
var min_range: float = 0.0
var cooldown: float = 1.0  ## seconds between shots
var projectile_speed: float = 0.0  ## 0 = hitscan
var homing: bool = false
var splash: float = 0.0  ## splash radius in world units, 0 = single target
var scatter: float = 0.0  ## max miss distance for unguided shells
var hits_ground: bool = true
var hits_air: bool = false
var fx: String = "tracer"
var burst: bool = false  ## the unit blows itself up: `splash` round where it stands, once
