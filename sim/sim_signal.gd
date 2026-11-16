class_name SimSignal
extends RefCounted
## The Signal Grid. (Filled in by milestone M4.)


static func mark_dirty(_w: SimWorld) -> void:
	pass


static func placement_error(_w: SimWorld, _player_id: int, _def: EntityDef, _centre: Vector2) -> String:
	return ""
