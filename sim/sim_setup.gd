class_name SimSetup
extends RefCounted
## Builds a ready-to-run SimWorld from a MatchConfig.


static func create_match(config: MatchConfig) -> SimWorld:
	var data: GameData = GameData.shared()
	var map: SimMap = SimMapGen.generate(config.seed_value, config.map_cells)
	var w: SimWorld = SimWorld.new(data, map, config.seed_value)
	for i: int in config.player_count():
		var p: SimPlayer = w.add_player(
			config.factions[i], MatchConfig.TEAM_COLORS[i % MatchConfig.TEAM_COLORS.size()],
			config.is_ai[i], map.starts[i], config.names[i]
		)
		p.ai_level = config.ai_levels[i]
	for f: Vector3 in map.field_spots:
		w.spawn_field(Vector2(f.x, f.y), int(f.z))
	for u: Vector2 in map.uplink_spots:
		w.spawn_uplink(u)
	for p: SimPlayer in w.players:
		place_base(w, p)
		if p.is_ai:
			w.ais.append(SimAI.new(p.id, p.ai_level, config.seed_value))
	SimSignal.recompute(w)
	w.signal_next_tick = 0
	SimVision.recompute(w)
	w.vision_next_tick = 0
	return w


## Puts the faction's HQ on the player's start position with the starting
## units fanned out towards the middle of the map.
static func place_base(w: SimWorld, p: SimPlayer) -> void:
	var hq_def: EntityDef = w.data.entity(p.faction.hq)
	var centre_cell: Vector2i = w.map.cell_of(p.start_pos)
	var cell: Vector2i = Vector2i(centre_cell.x - hq_def.footprint.x / 2, centre_cell.y - hq_def.footprint.y / 2)
	var hq: SimEntity = w.spawn_building(hq_def.id, p.id, cell, true)
	var to_centre: Vector2 = w.map.world_size() * 0.5 - hq.pos
	var base_angle: float = to_centre.angle()
	hq.rally = hq.pos + to_centre.normalized() * (hq.radius + 5.0)
	var n: int = p.faction.start_units.size()
	for i: int in n:
		var spread: float = (float(i) - float(n - 1) * 0.5) * 0.32
		var dist: float = hq.radius + 4.0 + float(i % 2) * 2.4
		var at: Vector2 = hq.pos + Vector2.from_angle(base_angle + spread) * dist
		var u: SimEntity = w.spawn_unit(p.faction.start_units[i], p.id, w.map.nearest_free_pos(at), base_angle)
		if u.def.harvester:
			# Starting haulers go straight to work on the nearest field.
			var res: SimEntity = SimEconomy.find_resource(w, hq.pos, 60.0)
			if res != null:
				u.orders.append(SimOrder.make(SimOrder.Type.HARVEST, res.pos, res.id))
				SimEconomy.start_harvest(u, res, false)
