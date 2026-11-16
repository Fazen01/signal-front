class_name DirectiveDef
extends RefCounted
## One commander power, loaded from data/directives.json.

const TARGET_MODES: Array[String] = ["none", "anywhere", "coverage", "near_coverage", "revealed"]

var id: String = ""
var name: String = ""
var desc: String = ""
var cost: int = 1  ## Command Points to unlock
var cooldown: float = 60.0  ## seconds between uses
var radius: float = 0.0
var duration: float = 0.0
var target: String = "anywhere"  ## one of TARGET_MODES
var damage: float = 0.0
var shells: int = 0
var splash: float = 0.0
var heal_fraction: float = 0.0
var radius_mult: float = 1.0
var squad: Array[String] = []
var slot: int = 0  ## position in the Directives panel


func needs_target() -> bool:
	return target != "none"
