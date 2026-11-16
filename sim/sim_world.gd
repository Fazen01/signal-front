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
	players.append(p)
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
	map.set_occupied(Rect2i(cell, def.footprint), e.id)
	e.rally = e.pos + Vector2(0.0, float(def.footprint.y) * SimMap.CELL * 0.5 + 3.0)
	emit_event(SimEvent.Type.SPAWNED, e.id, owner, e.pos)
	if constructed:
		_on_building_completed(e, false)
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


func _on_building_completed(e: SimEntity, announce: bool) -> void:
	if e.owner < 0:
		return
	var p: SimPlayer = players[e.owner]
	p.building_counts[e.def.id] = p.building_counts.get(e.def.id, 0) + 1
	if announce:
		p.stat_buildings_built += 1
		emit_event(SimEvent.Type.BUILDING_DONE, e.id, e.owner, e.pos)


func on_building_removed(e: SimEntity) -> void:
	map.set_occupied(Rect2i(e.footprint_cell, e.def.footprint), 0)
	if e.constructed and e.owner >= 0:
		var p: SimPlayer = players[e.owner]
		p.building_counts[e.def.id] = maxi(0, p.building_counts.get(e.def.id, 0) - 1)


## Removes an entity from play at the end of this tick.
func remove_entity(e: SimEntity) -> void:
	if not e.alive:
		return
	e.alive = false
	_dead.append(e)


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

	var pending: Array[SimCommand] = commands
	commands = []
	for cmd: SimCommand in pending:
		SimOrders.apply_command(self, cmd)

	if not game_over:
		for e: SimEntity in entities:
			if e.alive and e.kind == SimEntity.Kind.UNIT:
				SimOrders.update_unit(self, e)
		SimMovement.update(self)
		SimCombat.update(self)

	_flush_dead()
	tick_count += 1


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
