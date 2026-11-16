class_name SimWorld
extends RefCounted
## The whole match state and the fixed-tick loop that advances it. Nothing in
## here touches the scene tree. Presentation reads this state and changes it
## only by calling push_command().

const TICK_RATE: int = 20
const DT: float = 1.0 / 20.0
const BUCKET: float = 4.0

var data: GameData = null
var map: SimMap = null
var rng: SimRng = null
var tick_count: int = 0

var players: Array[SimPlayer] = []
var entities: Array[SimEntity] = []  ## alive entities in creation order
var by_id: Dictionary[int, SimEntity] = {}
var projectiles: Array[SimProjectile] = []
var events: Array[SimEvent] = []
var collect_events: bool = true
var commands: Array[SimCommand] = []
var next_id: int = 1

# Signal Grid (see SimSignal)
var coverage: Array[PackedByteArray] = []  ## per player: 1 where covered, one byte per map cell
var signal_links: Array[PackedInt32Array] = []  ## per player: flattened (from id, to id) pairs
var signal_dirty: bool = true
var signal_next_tick: int = 0
var coverage_version: int = 0  ## bumps whenever coverage is rebuilt

# Fog of war (see SimVision)
var visible: Array[PackedByteArray] = []  ## per player: 1 where currently seen
var explored: Array[PackedByteArray] = []  ## per player: 1 where ever seen
var reveals: Array[Vector4] = []  ## reveals: x, z, radius, player id
var reveal_until: PackedInt32Array = PackedInt32Array()  ## expiry tick per reveal, -1 = never
var vision_next_tick: int = 0
var vision_version: int = 0

# Directives (see SimDirectives)
var timed: Array[SimDirectives.Timed] = []
var blackouts: Array[Vector4] = []  ## x, z, radius, player id of the caster
var blackout_until: PackedInt32Array = PackedInt32Array()

var ais: Array[SimAI] = []

var victory_enabled: bool = true  ## tests without bases switch this off
var game_over: bool = false
var winner: int = -1  ## player id, -1 = nobody (yet)

var _dead: Array[SimEntity] = []
var bucket_w: int = 0
var bucket_h: int = 0
var buckets: Array[Array] = []


func _init(game_data: GameData, sim_map: SimMap, seed_value: int) -> void:
	data = game_data
	map = sim_map
	rng = SimRng.new(seed_value)
	var size: Vector2 = map.world_size()
	bucket_w = int(ceilf(size.x / BUCKET))
	bucket_h = int(ceilf(size.y / BUCKET))
	buckets.resize(bucket_w * bucket_h)
	for i: int in buckets.size():
		buckets[i] = []


func seconds() -> float:
	return float(tick_count) * DT


# ---------------------------------------------------------------- players

func add_player(faction_id: String, color: Color, is_ai: bool, start_pos: Vector2, player_name: String = "") -> SimPlayer:
	var p: SimPlayer = SimPlayer.new()
	p.id = players.size()
	p.faction = data.faction(faction_id)
	p.color = color
	p.is_ai = is_ai
	p.team = p.id
	p.start_pos = start_pos
	p.name = player_name if player_name != "" else "Player %d" % (p.id + 1)
	p.salvage = data.start_salvage
	p.command_points = data.start_command_points
	players.append(p)
	var grid: PackedByteArray = PackedByteArray()
	grid.resize(map.w * map.h)
	coverage.append(grid)
	signal_links.append(PackedInt32Array())
	visible.append(grid.duplicate())
	explored.append(grid.duplicate())
	return p


func player(id: int) -> SimPlayer:
	if id < 0 or id >= players.size():
		return null
	return players[id]


func are_enemies(a: int, b: int) -> bool:
	if a < 0 or b < 0 or a == b:
		return false
	return players[a].team != players[b].team


# --------------------------------------------------------------- entities

func get_entity(id: int) -> SimEntity:
	var e: SimEntity = by_id.get(id, null)
	if e != null and not e.alive:
		return null
	return e


func _register(e: SimEntity) -> void:
	e.id = next_id
	next_id += 1
	e.prev_pos = e.pos
	e.prev_facing = e.facing
	e.prev_aim = e.aim
	entities.append(e)
	by_id[e.id] = e


func spawn_unit(def_id: String, owner: int, at: Vector2, facing: float = 0.0) -> SimEntity:
	var def: EntityDef = data.entity(def_id)
	if def == null or def.is_building:
		push_error("spawn_unit: bad def '%s'" % def_id)
		return null
	var e: SimEntity = SimEntity.new()
	e.kind = SimEntity.Kind.UNIT
	e.def = def
	e.owner = owner
	e.pos = map.clamp_to_map(at)
	e.facing = facing
	e.aim = facing
	e.radius = def.radius
	e.max_hp = def.hp
	e.hp = def.hp
	e.cooldowns.resize(def.weapons.size())
	_register(e)
	e.guard_pos = e.pos
	e.scan_tick = tick_count + e.id % 5
	if owner >= 0:
		players[owner].bandwidth_used += def.bandwidth
	emit_event(SimEvent.Type.SPAWNED, e.id, owner, e.pos)
	return e


## Places a building with its top-left footprint cell at `cell`. A building
## spawned with `constructed` false starts as a construction site.
func spawn_building(def_id: String, owner: int, cell: Vector2i, constructed: bool = true) -> SimEntity:
	var def: EntityDef = data.entity(def_id)
	if def == null or not def.is_building:
		push_error("spawn_building: bad def '%s'" % def_id)
		return null
	var e: SimEntity = SimEntity.new()
	e.kind = SimEntity.Kind.BUILDING
	e.def = def
	e.owner = owner
	e.footprint_cell = cell
	e.pos = Vector2(
		(float(cell.x) + float(def.footprint.x) * 0.5) * SimMap.CELL,
		(float(cell.y) + float(def.footprint.y) * 0.5) * SimMap.CELL
	)
	e.radius = def.radius
	e.max_hp = def.hp
	e.constructed = constructed
	e.build_progress = 1.0 if constructed else 0.0
	e.hp = def.hp if constructed else def.hp * 0.1
	e.cooldowns.resize(def.weapons.size())
	e.facing = -PI * 0.5
	e.aim = e.facing
	_register(e)
	e.scan_tick = tick_count + e.id % 5
	# Emitters start unlinked until the grid is rebuilt; everything else is
	# Linked or Dark according to the coverage it stands in.
	e.linked = def.signal_radius <= 0.0 and SimSignal.is_covered(self, owner, e.pos)
	if def.blocks:
		map.set_occupied(Rect2i(cell, def.footprint), e.id)
	e.rally = e.pos + Vector2(0.0, float(def.footprint.y) * SimMap.CELL * 0.5 + 3.0)
	emit_event(SimEvent.Type.SPAWNED, e.id, owner, e.pos)
	if constructed:
		on_building_completed(e, false)
	return e


func spawn_field(at: Vector2, amount: int) -> SimEntity:
	var e: SimEntity = SimEntity.new()
	e.kind = SimEntity.Kind.FIELD
	e.pos = at
	e.radius = 2.6
	e.salvage = amount
	e.max_hp = float(amount)
	e.hp = float(amount)
	_register(e)
	emit_event(SimEvent.Type.SPAWNED, e.id, -1, e.pos)
	return e


## A neutral uplink site. A Field Engineer captures it; it then pays its
## owner a salvage trickle while it sits inside that owner's coverage.
func spawn_uplink(at: Vector2) -> SimEntity:
	var e: SimEntity = SimEntity.new()
	e.kind = SimEntity.Kind.UPLINK
	e.pos = at
	e.radius = 2.2
	e.linked = false
	_register(e)
	emit_event(SimEvent.Type.SPAWNED, e.id, -1, e.pos)
	return e


func spawn_wreck(at: Vector2, amount: int, radius: float, model: String, facing: float) -> SimEntity:
	var e: SimEntity = SimEntity.new()
	e.kind = SimEntity.Kind.WRECK
	e.pos = at
	e.radius = radius
	e.salvage = amount
	e.max_hp = float(maxi(amount, 1))
	e.hp = e.max_hp
	e.facing = facing
	e.wreck_model = model
	e.decay_tick = tick_count + int(data.wreck_decay_seconds * float(TICK_RATE))
	_register(e)
	emit_event(SimEvent.Type.SPAWNED, e.id, -1, e.pos)
	return e


func on_building_completed(e: SimEntity, announce: bool) -> void:
	if e.owner < 0:
		return
	var p: SimPlayer = players[e.owner]
	p.building_counts[e.def.id] = p.building_counts.get(e.def.id, 0) + 1
	if announce:
		p.stat_buildings_built += 1
		emit_event(SimEvent.Type.BUILDING_DONE, e.id, e.owner, e.pos)
	SimSignal.mark_dirty(self)
	SimEconomy.recompute_bandwidth(self)


func on_building_removed(e: SimEntity) -> void:
	if e.def.blocks:
		map.set_occupied(Rect2i(e.footprint_cell, e.def.footprint), 0)
	if e.constructed and e.owner >= 0:
		var p: SimPlayer = players[e.owner]
		p.building_counts[e.def.id] = maxi(0, p.building_counts.get(e.def.id, 0) - 1)
	SimSignal.mark_dirty(self)


## Removes an entity from play at the end of this tick.
func remove_entity(e: SimEntity) -> void:
	if not e.alive:
		return
	e.alive = false
	_dead.append(e)


# ---------------------------------------------------------------- reveals

## Lets `player_id` see a disc until `until_tick` (-1 = for the whole match).
func add_reveal(pos: Vector2, radius: float, player_id: int, until_tick: int) -> void:
	reveals.append(Vector4(pos.x, pos.y, radius, float(player_id)))
	reveal_until.append(until_tick)


func expire_reveals() -> void:
	var i: int = reveal_until.size() - 1
	while i >= 0:
		if reveal_until[i] >= 0 and tick_count >= reveal_until[i]:
			reveals.remove_at(i)
			reveal_until.remove_at(i)
		i -= 1


# ----------------------------------------------------------------- events

func emit_event(type: int, id: int, player_id: int, pos: Vector2) -> SimEvent:
	var ev: SimEvent = SimEvent.new()
	ev.type = type
	ev.id = id
	ev.player = player_id
	ev.pos = pos
	if collect_events:
		events.append(ev)
	return ev


func alert(player_id: int, text: String, pos: Vector2) -> void:
	var ev: SimEvent = emit_event(SimEvent.Type.ALERT, 0, player_id, pos)
	ev.text = text


# --------------------------------------------------------------- commands

func push_command(cmd: SimCommand) -> void:
	commands.append(cmd)


# ------------------------------------------------------------ spatial hash

func _rebuild_buckets() -> void:
	for b: Array in buckets:
		b.clear()
	for e: SimEntity in entities:
		if e.alive:
			buckets[_bucket_index(e.pos)].append(e)


func _bucket_index(p: Vector2) -> int:
	var bx: int = clampi(int(p.x / BUCKET), 0, bucket_w - 1)
	var by: int = clampi(int(p.y / BUCKET), 0, bucket_h - 1)
	return by * bucket_w + bx


## All alive entities whose centre is within `r` of `p` (as of the start of
## this tick's movement).
func query_radius(p: Vector2, r: float) -> Array[SimEntity]:
	var out: Array[SimEntity] = []
	var x0: int = clampi(int((p.x - r) / BUCKET), 0, bucket_w - 1)
	var x1: int = clampi(int((p.x + r) / BUCKET), 0, bucket_w - 1)
	var y0: int = clampi(int((p.y - r) / BUCKET), 0, bucket_h - 1)
	var y1: int = clampi(int((p.y + r) / BUCKET), 0, bucket_h - 1)
	var r2: float = r * r
	for by: int in range(y0, y1 + 1):
		for bx: int in range(x0, x1 + 1):
			var bucket: Array = buckets[by * bucket_w + bx]
			for item: SimEntity in bucket:
				if item.alive and item.pos.distance_squared_to(p) <= r2:
					out.append(item)
	return out


# ------------------------------------------------------------------- tick

func tick() -> void:
	if not collect_events:
		events.clear()
	for e: SimEntity in entities:
		e.prev_pos = e.pos
		e.prev_facing = e.facing
		e.prev_aim = e.aim
	_rebuild_buckets()
	SimSignal.update(self)
	SimVision.update(self)

	var pending: Array[SimCommand] = commands
	commands = []
	for cmd: SimCommand in pending:
		SimOrders.apply_command(self, cmd)

	if not game_over:
		for ai: SimAI in ais:
			ai.update(self)
		for e: SimEntity in entities:
			if e.alive and e.kind == SimEntity.Kind.UNIT:
				SimOrders.update_unit(self, e)
		SimEconomy.update(self)
		SimDirectives.update(self)
		SimMovement.update(self)
		SimCombat.update(self)
		if victory_enabled and tick_count % 10 == 0:
			_check_victory()

	_flush_dead()
	tick_count += 1


# ---------------------------------------------------------------- victory

## A player whose HQ is gone is defeated; the last team standing wins.
func _check_victory() -> void:
	var has_hq: Dictionary[int, bool] = {}
	for e: SimEntity in entities:
		if e.alive and e.owner >= 0 and e.kind == SimEntity.Kind.BUILDING and e.def.signal_root and e.constructed:
			has_hq[e.owner] = true
	for p: SimPlayer in players:
		if not p.defeated and not has_hq.has(p.id):
			defeat_player(p.id)
	if game_over:
		return
	var teams: Dictionary[int, bool] = {}
	var last: int = -1
	for p: SimPlayer in players:
		if not p.defeated:
			teams[p.team] = true
			last = p.id
	if teams.size() <= 1 and players.size() > 1:
		game_over = true
		winner = last if teams.size() == 1 else -1
		var ev: SimEvent = emit_event(SimEvent.Type.MATCH_OVER, 0, winner, Vector2.ZERO)
		ev.value = seconds()


## Marks a player as out of the match and destroys everything they own.
func defeat_player(id: int) -> void:
	var p: SimPlayer = player(id)
	if p == null or p.defeated:
		return
	p.defeated = true
	for other: SimPlayer in players:
		alert(other.id, "%s has been defeated" % p.name, p.start_pos)
	var n: int = entities.size()
	for i: int in n:
		var e: SimEntity = entities[i]
		if e.alive and e.owner == id:
			if e.kind == SimEntity.Kind.UPLINK:
				e.owner = -1  # uplinks outlive their owner and go neutral
				e.linked = false
			else:
				SimCombat.kill(self, e, null, -1)
	SimSignal.mark_dirty(self)


func _flush_dead() -> void:
	if _dead.is_empty():
		return
	for e: SimEntity in _dead:
		by_id.erase(e.id)
	_dead.clear()
	var kept: Array[SimEntity] = []
	for e: SimEntity in entities:
		if e.alive:
			kept.append(e)
	entities = kept


# ------------------------------------------------------------------ misc

## Order-independent digest of the match state, for determinism tests.
func state_hash() -> int:
	var hsh: int = tick_count
	for e: SimEntity in entities:
		var v: int = e.id * 73856093
		v ^= int(roundf(e.pos.x * 1000.0)) * 19349663
		v ^= int(roundf(e.pos.y * 1000.0)) * 83492791
		v ^= int(roundf(e.hp * 100.0)) * 2971215073
		v ^= (e.owner + 2) * 433494437
		hsh = (hsh * 31 + v) & 0x7FFFFFFFFFFF
	for p: SimPlayer in players:
		hsh = (hsh * 31 + p.salvage * 7 + p.bandwidth_used) & 0x7FFFFFFFFFFF
	return hsh


func count_units(owner: int) -> int:
	var n: int = 0
	for e: SimEntity in entities:
		if e.alive and e.owner == owner and e.kind == SimEntity.Kind.UNIT:
			n += 1
	return n
