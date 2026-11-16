class_name SimOrder
extends RefCounted
## One order in a unit's order queue.

enum Type { MOVE, ATTACK, ATTACK_MOVE, HOLD, HARVEST, BUILD, REPAIR, CAPTURE, DEPLOY }

var type: int = Type.MOVE
var pos: Vector2 = Vector2.ZERO
var target_id: int = 0
var cell: Vector2i = Vector2i.ZERO  ## footprint cell for DEPLOY
var started: bool = false


static func make(order_type: int, at: Vector2, target: int = 0) -> SimOrder:
	var o: SimOrder = SimOrder.new()
	o.type = order_type
	o.pos = at
	o.target_id = target
	return o
