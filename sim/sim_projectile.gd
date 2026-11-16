class_name SimProjectile
extends RefCounted
## A simulated shell or missile in flight.

var id: int = 0
var weapon: WeaponDef = null
var owner: int = -1
var source_id: int = 0
var target_id: int = 0
var pos: Vector2 = Vector2.ZERO
var prev_pos: Vector2 = Vector2.ZERO
var target_pos: Vector2 = Vector2.ZERO
var start_pos: Vector2 = Vector2.ZERO
var damage: float = 0.0
var alive: bool = true
