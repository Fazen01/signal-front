class_name SimSetup
extends RefCounted
## Builds a ready-to-run SimWorld from a MatchConfig.


## The map a configuration is played on: its hand-made layout, or one
## generated from its seed. The match setup draws its preview from this.
static func map_for(config: MatchConfig) -> SimMap:
	var map: SimMap = null
	if config.map_id != "":
		map = SimMapGen.load_layout(config.map_id)
		if map != null and SimMapGen.REGIONS.has(config.region):
			map.region = config.region
	if map == null or map.starts.size() < config.player_count():
		# Generated: the large size whenever more than two players need starts.
		var cells: int = config.map_cells
		if config.player_count() > 2:
			cells = maxi(cells, SimMapGen.LARGE_CELLS)
		map = SimMapGen.generate(config.seed_value, cells, config.starts_needed(), config.region)
	return map


static func create_match(config: MatchConfig) -> SimWorld:
	var data: GameData = GameData.shared()
	var map: SimMap = map_for(config)
	var w: SimWorld = SimWorld.new(data, map, config.seed_value)
	var starts: Array[Vector2] = assign_starts(config, map.starts)
	for i: int in config.player_count():
		var p: SimPlayer = w.add_player(
			config.factions[i], MatchConfig.TEAM_COLORS[i % MatchConfig.TEAM_COLORS.size()],
			config.is_ai[i], starts[i], config.names[i]
		)
		p.ai_level = config.ai_levels[i]
		p.team = config.team_of(i)
	for f: Vector3 in map.field_spots:
		w.spawn_field(Vector2(f.x, f.y), int(f.z))
	for u: Vector2 in map.uplink_spots:
		w.spawn_uplink(u)
	for p: SimPlayer in w.players:
		place_base(w, p)
		if p.is_ai:
			w.ais.append(SimAI.new(p.id, p.ai_level, config.seed_value))
	SimSignal.recompute(w)
	if config.tutorial != "":
		w.tutorial = SimTutorial.create(w, config.tutorial)
		SimSignal.recompute(w)
	w.signal_next_tick = 0
	SimVision.recompute(w)
	w.vision_next_tick = 0
	return w


## Which start each seat gets. Without teams, seat i takes start i. With
## teams, allies are put next to each other and the sides apart.
static func assign_starts(config: MatchConfig, starts: Array[Vector2]) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var n: int = config.player_count()
	if not config.has_teams():
		for i: int in n:
			out.append(starts[i])
		return out
	var free: Array[Vector2] = starts.duplicate()
	for i: int in n:
		var mates: Array[Vector2] = []
		var foes: Array[Vector2] = []
		for k: int in i:
			if config.team_of(k) == config.team_of(i):
				mates.append(out[k])
			else:
				foes.append(out[k])
		var best: int = 0
		var best_score: float = -INF
		for s: int in free.size():
			var score: float = -float(s)  # nobody placed yet: the first start
			if not mates.is_empty():
				score = 0.0
				for at: Vector2 in mates:
					score -= free[s].distance_to(at)
			elif not foes.is_empty():
				score = INF
				for at: Vector2 in foes:
					score = minf(score, free[s].distance_to(at))
			if score > best_score + 0.001:
				best_score = score
				best = s
		out.append(free[best])
		free.remove_at(best)
	return out


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
