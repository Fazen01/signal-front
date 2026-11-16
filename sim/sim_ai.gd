class_name SimAI
extends RefCounted
## Scripted-priority skirmish AI. One instance per AI player. It runs on a
## slow tick and acts only through SimCommands, exactly like a human player.
## It does not get extra income; difficulty changes how fast it thinks, how
## efficiently it builds and how aggressive it is.

enum Wave { NONE, STAGING, ASSAULT }

const STAGE_DISTANCE: float = 26.0
const THREAT_RANGE: float = 22.0

var player_id: int = 0
var level: int = 1  ## 0 easy, 1 normal, 2 hard
var rng: SimRng = null
var next_think: int = 0

# Tuning, set from the difficulty level.
var think_ticks: int = 20
var max_haulers: int = 6
var max_engineers: int = 2
var first_wave: int = 7
var wave_growth: int = 3
var max_wave: int = 26
var wave_cooldown_ticks: int = 20 * 40
var max_barracks: int = 1
var max_works: int = 1
var builds_turrets: bool = true
var hunts_relays: bool = true

# Army state
var wave_state: int = Wave.NONE
var wave_ids: Array[int] = []
var wave_target: int = 0
var wave_stage: Vector2 = Vector2.ZERO
var wave_tick: int = 0
var wave_size: int = 7
var waves_sent: int = 0
var last_wave_end: int = -100000

# Per-think scratch lists
var _hq: SimEntity = null
var _engineers: Array[SimEntity] = []
var _haulers: Array[SimEntity] = []
var _army: Array[SimEntity] = []
var _buildings: Array[SimEntity] = []
var _sites: Array[SimEntity] = []
var _enemies: Array[SimEntity] = []
var _enemy_buildings: Array[SimEntity] = []
var _spent: int = 0  ## salvage committed by commands issued this think
var _bandwidth_committed: int = 0  ## bandwidth of units ordered this think


func _init(owner_id: int, difficulty: int, seed_value: int) -> void:
	player_id = owner_id
	level = difficulty
	rng = SimRng.new(seed_value * 31 + owner_id * 977 + 5)
	match difficulty:
		0:
			think_ticks = 40
			max_haulers = 4
			first_wave = 9
			wave_growth = 4
			wave_cooldown_ticks = 20 * 75
			builds_turrets = false
			hunts_relays = false
		2:
			think_ticks = 10
			max_haulers = 8
			max_engineers = 3
			first_wave = 6
			wave_growth = 3
			wave_cooldown_ticks = 20 * 25
			max_barracks = 2
			max_works = 2
		_:
			pass
	wave_size = first_wave
	next_think = 10 + owner_id * 3


func update(w: SimWorld) -> void:
	if w.tick_count < next_think:
		return
	next_think = w.tick_count + think_ticks
	var me: SimPlayer = w.players[player_id]
	if me.defeated:
		return
	_survey(w)
	if _hq == null:
		return
	_spent = 0
	_bandwidth_committed = 0
	_run_economy(w, me)
	_run_construction(w, me)
	_run_production(w, me)
	_run_military(w)


# ------------------------------------------------------------------ survey

func _survey(w: SimWorld) -> void:
	_hq = null
	_engineers.clear()
	_haulers.clear()
	_army.clear()
	_buildings.clear()
	_sites.clear()
	_enemies.clear()
	_enemy_buildings.clear()
	for e: SimEntity in w.entities:
		if not e.alive or e.def == null:
			continue
		if e.owner == player_id:
			if e.kind == SimEntity.Kind.BUILDING:
				if e.constructed:
					_buildings.append(e)
					if e.def.signal_root:
						_hq = e
				else:
					_sites.append(e)
			elif e.def.builder:
				_engineers.append(e)
			elif e.def.harvester:
				_haulers.append(e)
			elif e.def.is_armed():
				_army.append(e)
		elif w.are_enemies(player_id, e.owner):
			if e.kind == SimEntity.Kind.BUILDING:
				_enemy_buildings.append(e)
			else:
				_enemies.append(e)


func _count(def_id: String, include_sites: bool = true) -> int:
	var n: int = 0
	for b: SimEntity in _buildings:
		if b.def.id == def_id:
			n += 1
	if include_sites:
		for b: SimEntity in _sites:
			if b.def.id == def_id:
				n += 1
	return n


func _first_building(def_id: String) -> SimEntity:
	for b: SimEntity in _buildings:
		if b.def.id == def_id:
			return b
	return null


func _can_afford(me: SimPlayer, cost: int) -> bool:
	return me.salvage - _spent >= cost


func _enemy_hq_pos(w: SimWorld) -> Vector2:
	for b: SimEntity in _enemy_buildings:
		if b.def.signal_root:
			return b.pos
	for p: SimPlayer in w.players:
		if w.are_enemies(player_id, p.id) and not p.defeated:
			return p.start_pos
	return w.map.world_size() * 0.5


# ---------------------------------------------------------------- economy

func _run_economy(w: SimWorld, me: SimPlayer) -> void:
	# Put idle haulers to work.
	var idle: PackedInt32Array = PackedInt32Array()
	for h: SimEntity in _haulers:
		if h.orders.is_empty():
			idle.append(h.id)
	if not idle.is_empty():
		var res: SimEntity = _best_resource(w)
		if res != null:
			w.push_command(SimCommand.harvest(player_id, idle, res.id))
	# Train haulers and engineers from the HQ (or a depot).
	var want_haulers: int = mini(max_haulers, 3 + _count("depot", false) * 2 + (1 if w.tick_count > 20 * 120 else 0))
	if _haulers.size() + _queued("hauler") < want_haulers and _best_resource(w) != null:
		_train_at_any(w, me, "hauler")
	if _engineers.size() + _queued("field_engineer") < max_engineers:
		_train_at_any(w, me, "field_engineer")


## Nearest salvage that is reasonably close to one of our depots.
func _best_resource(w: SimWorld) -> SimEntity:
	var best: SimEntity = null
	var best_score: float = INF
	for e: SimEntity in w.entities:
		if not e.is_harvestable():
			continue
		var d: float = INF
		for b: SimEntity in _buildings:
			if b.def.depot:
				d = minf(d, b.pos.distance_to(e.pos))
		# Prefer salvage inside our own coverage: it is safer.
		var score: float = d * (1.0 if SimSignal.is_covered(w, player_id, e.pos) else 1.8)
		if score < best_score:
			best_score = score
			best = e
	if best_score > 90.0:
		return null
	return best


func _queued(def_id: String) -> int:
	var n: int = 0
	for b: SimEntity in _buildings:
		for q: String in b.queue:
			if q == def_id:
				n += 1
	return n


func _queued_bandwidth(w: SimWorld) -> int:
	var n: int = _bandwidth_committed
	for b: SimEntity in _buildings:
		for q: String in b.queue:
			n += w.data.entity(q).bandwidth
	return n


func _train_at_any(w: SimWorld, me: SimPlayer, def_id: String) -> bool:
	var def: EntityDef = w.data.entity(def_id)
	if not _can_afford(me, def.cost) or not me.meets_requirements(def):
		return false
	if me.bandwidth_used + _queued_bandwidth(w) + def.bandwidth > me.bandwidth_cap:
		return false
	var best: SimEntity = null
	for b: SimEntity in _buildings:
		if b.def.produces.has(def_id) and b.linked and b.queue.size() < 2:
			if best == null or b.queue.size() < best.queue.size():
				best = b
	if best == null:
		return false
	w.push_command(SimCommand.train(player_id, best.id, def_id))
	_spent += def.cost
	_bandwidth_committed += def.bandwidth
	return true


# ----------------------------------------------------------- construction

func _run_construction(w: SimWorld, me: SimPlayer) -> void:
	if _engineers.is_empty():
		return
	# Help with anything unfinished or damaged first.
	var free: Array[SimEntity] = []
	for e: SimEntity in _engineers:
		if e.orders.is_empty():
			free.append(e)
	if free.is_empty():
		return
	if not _sites.is_empty():
		w.push_command(SimCommand.repair(player_id, _ids(free), _sites[0].id))
		return
	for b: SimEntity in _buildings:
		if b.hp < b.max_hp * 0.7 and b.linked and _threat_near(b.pos, 14.0) == null:
			w.push_command(SimCommand.repair(player_id, _ids(free), b.id))
			return

	var next: String = _next_building(w, me)
	if next == "":
		return
	var def: EntityDef = w.data.entity(next)
	if not _can_afford(me, def.cost):
		return
	var cell: Vector2i = _site_for(w, def)
	if cell.x < 0:
		return
	w.push_command(SimCommand.build(player_id, _ids(free), def.id, cell))
	_spent += def.cost


## The next building in the build order, or "" when nothing is needed.
func _next_building(w: SimWorld, me: SimPlayer) -> String:
	var relays: int = _count("relay")
	var barracks: int = _count("barracks")
	var works: int = _count("vehicle_works")
	var headroom: int = me.bandwidth_cap - me.bandwidth_used - _queued_bandwidth(w)
	if barracks == 0:
		return "barracks"
	if relays == 0:
		return "relay"
	if headroom < 6 and me.bandwidth_cap < w.data.bandwidth_max:
		return "relay"
	if works == 0 and me.has_building("barracks"):
		return "vehicle_works"
	if _wants_depot(w):
		return "depot"
	if relays < 3 and _relay_goal(w) != Vector2.INF:
		return "relay"
	if builds_turrets and me.has_building("barracks") and _count("sentry_turret") < 1:
		return "sentry_turret"
	if builds_turrets and me.has_building("vehicle_works") and _count("lance_battery") < 1:
		return "lance_battery"
	if relays < 6 and _relay_goal(w) != Vector2.INF and me.salvage > 500:
		return "relay"
	if me.salvage > 900 and barracks < max_barracks:
		return "barracks"
	if me.salvage > 1200 and works < max_works and me.has_building("barracks"):
		return "vehicle_works"
	if builds_turrets and me.salvage > 1500 and _count("sentry_turret") + _count("lance_battery") < 5:
		return "lance_battery" if me.has_building("vehicle_works") and rng.chance(0.5) else "sentry_turret"
	return ""


## Salvage fields, in order of distance, that our signal does not reach yet.
func _relay_goal(w: SimWorld) -> Vector2:
	var best: Vector2 = Vector2.INF
	var best_d: float = INF
	for e: SimEntity in w.entities:
		if e.kind != SimEntity.Kind.FIELD or not e.is_harvestable():
			continue
		if SimSignal.is_covered(w, player_id, e.pos):
			continue
		var d: float = e.pos.distance_to(_hq.pos)
		# Leave the enemy's home fields alone.
		if e.pos.distance_to(_enemy_hq_pos(w)) < d:
			continue
		if d < best_d:
			best_d = d
			best = e.pos
	if best == Vector2.INF and _count("relay") < 4:
		# Nothing left to claim: push the network towards the middle.
		var mid: Vector2 = w.map.world_size() * 0.5
		if not SimSignal.is_covered(w, player_id, mid):
			best = mid
	return best


func _wants_depot(w: SimWorld) -> bool:
	if _count("depot") >= 2:
		return false
	return _depot_spot(w) != Vector2.INF


## A covered salvage field that is a long haul from every depot.
func _depot_spot(w: SimWorld) -> Vector2:
	for e: SimEntity in w.entities:
		if e.kind != SimEntity.Kind.FIELD or e.salvage < 1500:
			continue
		if not SimSignal.is_covered(w, player_id, e.pos):
			continue
		var near: float = INF
		for b: SimEntity in _buildings:
			if b.def.depot:
				near = minf(near, b.pos.distance_to(e.pos))
		for b: SimEntity in _sites:
			if b.def.depot:
				near = minf(near, b.pos.distance_to(e.pos))
		if near > 30.0:
			return e.pos + (_hq.pos - e.pos).normalized() * 8.0
	return Vector2.INF


## Picks a footprint cell for a new building, or (-1, -1).
func _site_for(w: SimWorld, def: EntityDef) -> Vector2i:
	var toward_enemy: Vector2 = (_enemy_hq_pos(w) - _hq.pos).normalized()
	var around: Vector2 = _hq.pos
	var spread: int = 10
	match def.id:
		"relay":
			var goal: Vector2 = _relay_goal(w)
			if goal == Vector2.INF:
				goal = _hq.pos + toward_enemy * 40.0
			var from: SimEntity = _nearest_linked_emitter(w, goal)
			if from == null:
				return Vector2i(-1, -1)
			var gap: float = from.pos.distance_to(goal)
			var step: float = clampf(gap - 5.0, 8.0, w.data.link_range - 4.0)
			around = from.pos + (goal - from.pos).normalized() * step
			spread = 5
		"depot":
			var spot: Vector2 = _depot_spot(w)
			if spot != Vector2.INF:
				around = spot
			spread = 6
		"sentry_turret", "lance_battery":
			# Guard the front of the base and the forward relays in turn.
			var anchor: SimEntity = _hq
			var n: int = _count("sentry_turret") + _count("lance_battery")
			if n % 2 == 1:
				anchor = _forward_relay(w)
			around = anchor.pos + toward_enemy * (anchor.radius + 5.0) + Vector2(-toward_enemy.y, toward_enemy.x) * rng.range_f(-5.0, 5.0)
			spread = 5
		_:
			# Production and other buildings ring the HQ, biased away from the enemy.
			var ang: float = toward_enemy.angle() + PI + rng.range_f(-1.9, 1.9)
			around = _hq.pos + Vector2.from_angle(ang) * rng.range_f(11.0, 17.0)
	return _find_cell(w, def, around, spread)


func _nearest_linked_emitter(w: SimWorld, to: Vector2) -> SimEntity:
	var best: SimEntity = null
	var best_d: float = INF
	for b: SimEntity in _buildings:
		if SimSignal.is_emitter(b) and b.linked:
			var d: float = b.pos.distance_to(to)
			if d < best_d:
				best_d = d
				best = b
	return best


func _forward_relay(w: SimWorld) -> SimEntity:
	var target: Vector2 = _enemy_hq_pos(w)
	var best: SimEntity = _hq
	var best_d: float = _hq.pos.distance_to(target)
	for b: SimEntity in _buildings:
		if b.def.id == "relay" and b.linked:
			var d: float = b.pos.distance_to(target)
			if d < best_d:
				best_d = d
				best = b
	return best


## Searches outward from `around` for a legal footprint with a free border,
## so buildings never wall each other in.
func _find_cell(w: SimWorld, def: EntityDef, around: Vector2, max_ring: int) -> Vector2i:
	var c0: Vector2i = Vector2i(
		int(roundf(around.x / SimMap.CELL - float(def.footprint.x) * 0.5)),
		int(roundf(around.y / SimMap.CELL - float(def.footprint.y) * 0.5))
	)
	for r: int in range(0, max_ring + 1):
		for dy: int in range(-r, r + 1):
			for dx: int in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var c: Vector2i = Vector2i(c0.x + dx, c0.y + dy)
				if not SimEconomy.can_place(w, player_id, def, c):
					continue
				if _border_free(w, c, def.footprint):
					return c
	return Vector2i(-1, -1)


func _border_free(w: SimWorld, cell: Vector2i, footprint: Vector2i) -> bool:
	for y: int in range(cell.y - 1, cell.y + footprint.y + 1):
		for x: int in range(cell.x - 1, cell.x + footprint.x + 1):
			var inside: bool = x >= cell.x and y >= cell.y and x < cell.x + footprint.x and y < cell.y + footprint.y
			if not inside and not w.map.is_cell_passable(Vector2i(x, y)):
				return false
	return true


# -------------------------------------------------------------- production

func _run_production(w: SimWorld, me: SimPlayer) -> void:
	# Keep enough in the bank for the next building in the build order.
	var reserve: int = 0
	var next: String = _next_building(w, me)
	if next != "" and not _engineers.is_empty():
		reserve = w.data.entity(next).cost
	var heavy: int = 0
	var light: int = 0
	var infantry: int = 0
	for e: SimEntity in _enemies:
		if e.def.is_infantry():
			infantry += 1
		elif w.data.armor_classes[e.def.armor] == "heavy":
			heavy += 1
		else:
			light += 1
	# Weights react to what the enemy fields.
	var weights: Dictionary[String, float] = {
		"trooper": 3.0 + float(infantry) * 0.25,
		"lancer": 2.0 + float(heavy) * 0.7 + float(light) * 0.35,
		"marksman": 0.8 + float(infantry) * 0.2,
		"courser": 0.5,
		"warden": 2.0 + float(infantry) * 0.3 + float(light) * 0.2,
		"bulwark": 2.5 + float(heavy) * 0.5 + float(light) * 0.3,
	}
	for b: SimEntity in _buildings:
		if b.def.produces.is_empty() or b.def.signal_root or b.def.depot or not b.linked:
			continue
		if b.queue.size() >= 2:
			continue
		var options: Array[String] = []
		var total: float = 0.0
		for id: String in b.def.produces:
			if not weights.has(id):
				continue
			var def: EntityDef = w.data.entity(id)
			if not me.meets_requirements(def) or not _can_afford(me, def.cost + reserve):
				continue
			if me.bandwidth_used + _queued_bandwidth(w) + def.bandwidth > me.bandwidth_cap:
				continue
			options.append(id)
			total += weights[id]
		if options.is_empty():
			continue
		var roll: float = rng.range_f(0.0, total)
		var pick: String = options[options.size() - 1]
		for id: String in options:
			roll -= weights[id]
			if roll <= 0.0:
				pick = id
				break
		w.push_command(SimCommand.train(player_id, b.id, pick))
		_spent += w.data.entity(pick).cost
		_bandwidth_committed += w.data.entity(pick).bandwidth


# ---------------------------------------------------------------- military

func _ids(units: Array[SimEntity]) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for e: SimEntity in units:
		out.append(e.id)
	return out


func _threat_near(pos: Vector2, radius: float) -> SimEntity:
	var best: SimEntity = null
	var best_d: float = radius
	for e: SimEntity in _enemies:
		if not e.def.is_armed():
			continue
		var d: float = e.pos.distance_to(pos)
		if d < best_d:
			best_d = d
			best = e
	return best


## The most pressing enemy near anything we own, or null.
func _base_threat(w: SimWorld) -> SimEntity:
	var best: SimEntity = null
	var best_d: float = INF
	for e: SimEntity in _enemies:
		if not e.def.is_armed():
			continue
		for b: SimEntity in _buildings:
			var d: float = e.pos.distance_to(b.pos) - b.radius
			if d < THREAT_RANGE and d < best_d:
				best_d = d
				best = e
	if best != null:
		return best
	# Also react to anything shooting at our haulers.
	for h: SimEntity in _haulers:
		if w.tick_count - h.last_hit_tick < 60:
			var attacker: SimEntity = w.get_entity(h.last_attacker)
			if attacker != null:
				return attacker
	return null


func _run_military(w: SimWorld) -> void:
	var toward_enemy: Vector2 = (_enemy_hq_pos(w) - _hq.pos).normalized()
	var rally: Vector2 = w.map.nearest_free_pos(_hq.pos + toward_enemy * (_hq.radius + 12.0))

	# Drop dead units from the wave.
	var alive_wave: Array[int] = []
	for id: int in wave_ids:
		if w.get_entity(id) != null:
			alive_wave.append(id)
	wave_ids = alive_wave
	if wave_state != Wave.NONE and wave_ids.is_empty():
		_end_wave(w)

	var home: Array[SimEntity] = []
	for e: SimEntity in _army:
		if not wave_ids.has(e.id):
			home.append(e)

	# Defence comes first.
	var threat: SimEntity = _base_threat(w)
	if threat != null:
		var defenders: Array[SimEntity] = []
		for e: SimEntity in home:
			if e.orders.is_empty() or e.pos.distance_to(threat.pos) > 14.0:
				defenders.append(e)
		if not defenders.is_empty():
			w.push_command(SimCommand.attack_move(player_id, _ids(defenders), threat.pos))
		# A serious attack on the HQ pulls the wave back.
		if wave_state != Wave.NONE and threat.pos.distance_to(_hq.pos) < 26.0 and _count_near(_enemies, _hq.pos, 26.0) >= 4:
			var back: PackedInt32Array = PackedInt32Array(wave_ids)
			w.push_command(SimCommand.attack_move(player_id, back, threat.pos))
			_end_wave(w)
	else:
		# Idle units gather at the rally point.
		var strays: Array[SimEntity] = []
		for e: SimEntity in home:
			if e.orders.is_empty() and e.pos.distance_to(rally) > 9.0:
				strays.append(e)
		if not strays.is_empty():
			w.push_command(SimCommand.attack_move(player_id, _ids(strays), rally))

	match wave_state:
		Wave.NONE:
			if threat == null and home.size() >= wave_size and w.tick_count - last_wave_end >= wave_cooldown_ticks:
				_launch_wave(w, home)
		Wave.STAGING:
			var arrived: int = 0
			for id: int in wave_ids:
				if w.get_entity(id).pos.distance_to(wave_stage) < 11.0:
					arrived += 1
			var waited: int = w.tick_count - wave_tick
			if arrived * 10 >= wave_ids.size() * 7 or waited > 20 * 45:
				wave_state = Wave.ASSAULT
				wave_tick = w.tick_count
				_assault(w, true)
		Wave.ASSAULT:
			_assault(w, false)


func _count_near(list: Array[SimEntity], pos: Vector2, radius: float) -> int:
	var n: int = 0
	for e: SimEntity in list:
		if e.pos.distance_to(pos) <= radius:
			n += 1
	return n


func _launch_wave(w: SimWorld, units: Array[SimEntity]) -> void:
	var target: SimEntity = _pick_target(w)
	if target == null:
		return
	wave_ids.clear()
	for e: SimEntity in units:
		wave_ids.append(e.id)
	wave_target = target.id
	wave_state = Wave.STAGING
	wave_tick = w.tick_count
	waves_sent += 1
	var back: Vector2 = (_hq.pos - target.pos).normalized()
	wave_stage = w.map.nearest_free_pos(w.map.clamp_to_map(target.pos + back * STAGE_DISTANCE))
	w.push_command(SimCommand.move(player_id, PackedInt32Array(wave_ids), wave_stage))


func _end_wave(w: SimWorld) -> void:
	wave_state = Wave.NONE
	wave_ids.clear()
	wave_target = 0
	last_wave_end = w.tick_count
	wave_size = mini(max_wave, wave_size + wave_growth)


func _assault(w: SimWorld, fresh: bool) -> void:
	var target: SimEntity = w.get_entity(wave_target)
	if target == null:
		target = _pick_target(w)
		if target == null:
			_end_wave(w)
			return
		wave_target = target.id
		fresh = true
	var who: PackedInt32Array = PackedInt32Array()
	for id: int in wave_ids:
		var e: SimEntity = w.get_entity(id)
		if fresh or e.orders.is_empty():
			who.append(id)
	if not who.is_empty():
		w.push_command(SimCommand.attack_move(player_id, who, target.pos))


## What to hit next. Normal and Hard AIs go for the relay whose loss would
## black out the most of the enemy network; otherwise the nearest building,
## and the HQ once the outlying network is gone.
func _pick_target(w: SimWorld) -> SimEntity:
	if _enemy_buildings.is_empty():
		return null
	var from: Vector2 = _hq.pos
	if not wave_ids.is_empty():
		var lead: SimEntity = w.get_entity(wave_ids[0])
		if lead != null:
			from = lead.pos
	var best: SimEntity = null
	var best_score: float = -INF
	for b: SimEntity in _enemy_buildings:
		var score: float = -from.distance_to(b.pos) * 0.05
		if b.def.signal_root:
			score += 1.5
		elif hunts_relays and b.def.signal_radius > 0.0 and b.constructed:
			score += 2.0 + 2.5 * float(_downstream_count(w, b))
		elif b.def.is_armed():
			score -= 1.0
		if score > best_score:
			best_score = score
			best = b
	return best


## How many other enemy emitters would lose their link if `relay` died.
func _downstream_count(w: SimWorld, relay: SimEntity) -> int:
	var emitters: Array[SimEntity] = []
	for b: SimEntity in _enemy_buildings:
		if b.owner == relay.owner and SimSignal.is_emitter(b) and b != relay:
			emitters.append(b)
	var linked: Dictionary[int, bool] = {}
	var frontier: Array[SimEntity] = []
	for b: SimEntity in emitters:
		if b.def.signal_root:
			linked[b.id] = true
			frontier.append(b)
	var head: int = 0
	while head < frontier.size():
		var a: SimEntity = frontier[head]
		head += 1
		for b: SimEntity in emitters:
			if not linked.has(b.id) and a.pos.distance_to(b.pos) <= w.data.link_range:
				linked[b.id] = true
				frontier.append(b)
	var cut: int = 0
	for b: SimEntity in emitters:
		if b.linked and not linked.has(b.id):
			cut += 1
	return cut
