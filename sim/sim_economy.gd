class_name SimEconomy
extends RefCounted
## Harvesting, construction and production. (Filled in by milestone M3.)


static func update_order(_w: SimWorld, e: SimEntity, _o: SimOrder) -> void:
	SimOrders.finish_order(e)
