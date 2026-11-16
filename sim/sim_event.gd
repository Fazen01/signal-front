class_name SimEvent
extends RefCounted
## Something that happened during a tick that presentation may want to show or
## sound. The view drains SimWorld.events after each tick; the sim never reads
## them back.

enum Type {
	SPAWNED, DIED, SHOT, PROJECTILE, IMPACT, BUILDING_PLACED, BUILDING_DONE, UNIT_READY,
	ALERT, ORDER_ACK, DEPOSIT, MATCH_OVER,
}

var type: int = Type.SPAWNED
var id: int = 0  ## main entity
var other_id: int = 0  ## secondary entity (target, building)
var player: int = -1
var pos: Vector2 = Vector2.ZERO
var pos2: Vector2 = Vector2.ZERO
var value: float = 0.0
var text: String = ""
