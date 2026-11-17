class_name SimAI
extends RefCounted
## Scripted-priority skirmish AI. One instance per AI player. It runs on a
## slow tick and acts only through SimCommands, exactly like a human player.
## It does not get extra income; difficulty changes how fast it thinks, how
## efficiently it builds and how aggressive it is.

enum Wave { NONE, STAGING, ASSAULT }

const STAGE_DISTANCE: float = 26.0
const STALL_TICKS: int = 20 * 150  ## attack with what we have after this long without a wave
const THREAT_RANGE: float = 22.0
const LATE_GAME_TICKS: int = 20 * 60 * 22  ## after this, waves head for the enemy HQ
const REINFORCE_TICKS: int = 20 * 240  ## a wave out this long no longer holds back the next one
const RELAY_DANGER_RADIUS: float = 16.0  ## enemies this close to a relay site send the relay home
const FLANK_MIN_WAVE: int = 10  ## smaller waves take the straight road
const FLANK_ANGLE: float = 0.95  ## how far round the target a flanking wave gathers (radians)
const STRIKE_MIN_CRAFT: int = 3  ## aircraft needed for a strike between waves
const CONCEDE_AFTER_TICKS: int = 20 * 60 * 14  ## nobody gives up in the first fourteen minutes
const CONCEDE_HOLD_TICKS: int = 20 * 150  ## hopeless for this long without a break
const CONCEDE_RATIO: float = 2.5  ## the enemy has this many times our strength
const CONCEDE_MAX_BUILDINGS: int = 8  ## and we are down to this many buildings
const STARVED_AFTER_TICKS: int = 20 * 60 * 18  ## from here on, having no income counts against holding out
const STARVED_WINDOW_TICKS: int = 20 * 240  ## income is measured over windows this long
const STARVED_INCOME: int = 150  ## less than this in a window is no income
const STARVED_BANK: int = 400  ## with less than this put by
const STARVED_RATIO: float = 1.5  ## a starved side gives up against this much more strength
const LEASH_LEAD: float = 9.0  ## how far ahead of the main body a wave unit may get
const LEASH_NEAR: float = 14.0  ## no waiting this close to the target
const LEASH_TICKS: int = 20 * 120  ## the wave stops waiting for stragglers after this long
## How an AI likes to fight. Normal and Hard opponents draw one from the
## seed, so two matches against the same difficulty need not feel alike.
const DOCTRINES: Array[String] = ["balanced", "aggressor", "fortifier", "raider"]

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
var wave_cooldown_ticks: int = 20 * 60
var max_barracks: int = 1
var relays_kept_home: int = 0  ## relays raised behind the base because the forward spot was under fire
var max_works: int = 1
var builds_turrets: bool = true
var uses_directives: bool = true
var hunts_relays: bool = true
var doctrine: String = "balanced"
var keeps_together: bool = false  ## fast wave units wait for the slow ones on the way in (off: see the session 5 log)
var retreats: bool = true  ## pulls a beaten wave back instead of losing it to the last unit
var max_retreats: int = 2  ## how often in one match; after that the AI commits
var scouts: bool = true  ## keeps one unit out looking for the enemy's buildings
var raids: bool = false  ## raider: goes for depots and relays before anything else
var faction_tricks: bool = true  ## plays to its faction's own rule (Normal and Hard)
var flanks: bool = true  ## every other big wave comes in from the side when the ground allows it
var helps_allies: bool = true  ## defends an ally's headquarters and joins an ally's attack
var concedes: bool = true  ## in a match with no person in it, gives up once it is plainly lost
var ambushes: bool = false  ## waits hidden at its forward relay (factions that cloak inside coverage)
var strikes: bool = false  ## sends idle aircraft at the enemy's relays and depots between waves
var retreat_share: float = 0.4  ## a wave worn down to this share of its strength may pull back
var max_turrets: int = 5
var turret_salvage: int = 1500  ## spare salvage above which more turrets go up

# Army state
var wave_state: int = Wave.NONE
var wave_ids: Array[int] = []
var wave_target: int = 0
var wave_target_pos: Vector2 = Vector2.ZERO
var wave_stage: Vector2 = Vector2.ZERO
var wave_side: int = 0  ## 0: this wave comes straight in; 1 or -1: round one side of the target
var flanks_sent: int = 0
var strikes_sent: int = 0
var ally_rescues: int = 0  ## times it sent its army to an ally's headquarters
var _rescuing_tick: int = -1
var wave_tick: int = 0
var wave_size: int = 7
var waves_sent: int = 0
var last_wave_end: int = -100000
var wave_launch_power: int = 0  ## salvage value of the wave when it set out
var retreats_made: int = 0
var scouts_sent: int = 0
var _scout_id: int = 0
var _scout_leg: int = 0

# Per-think scratch lists
var _f: FactionDef = null  ## this player's faction; roles map jobs to its definitions
var _hq: SimEntity = null
var _mobile: Array[SimEntity] = []  ## deployable units (Crawlers, Beacon Rigs)
var _hijackers: Array[SimEntity] = []
var _engineers: Array[SimEntity] = []
var _haulers: Array[SimEntity] = []
var _army: Array[SimEntity] = []
var _buildings: Array[SimEntity] = []
var _sites: Array[SimEntity] = []
var _enemies: Array[SimEntity] = []
var _enemy_buildings: Array[SimEntity] = []
var _ally_hqs: Array[SimEntity] = []
var _ally_army: Array[SimEntity] = []  ## armed units of allies that are played by a person
var _adapted: bool = false
var _hopeless_since: int = -1  ## tick at which its position last became hopeless, or -1
var _income_mark: int = 0  ## start of the window income is being measured over
var _income_seen: int = 0  ## salvage collected up to that moment
var _starving: bool = false  ## the last whole window brought in next to nothing
var _known_buildings: Dictionary[int, bool] = {}  ## enemy buildings we have seen
var _enemy_air_seen: int = 0  ## most enemy aircraft seen at once
var _wish: Dictionary[int, String] = {}  ## building id -> unit it is saving up for
var _wish_tick: Dictionary[int, int] = {}
var _want_haulers: int = 3  ## how many haulers the economy is aiming for
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
			wave_cooldown_ticks = 20 * 110
			builds_turrets = false
			hunts_relays = false
			uses_directives = false
			keeps_together = false
		2:
			think_ticks = 10
			max_haulers = 8
			max_engineers = 3
			first_wave = 6
			wave_growth = 3
			wave_cooldown_ticks = 20 * 38
			max_barracks = 2
			max_works = 2
		_:
			pass
	if difficulty == 0:
		retreats = false
		scouts = false
	else:
		doctrine = DOCTRINES[rng.range_i(0, DOCTRINES.size() - 1)]
		match doctrine:
			"aggressor":
				# Strikes early and often with smaller forces.
				first_wave = maxi(4, first_wave - 2)
				wave_growth = maxi(2, wave_growth - 1)
				wave_cooldown_ticks = int(float(wave_cooldown_ticks) * 0.75)
				max_retreats = 1
			"fortifier":
				# Digs in behind turrets, then comes with a big army.
				first_wave += 3
				wave_growth += 1
				max_turrets = 8
				turret_salvage = 1000
				max_retreats = 3
			"raider":
				# Goes for the enemy's relays and depots rather than its guns.
				raids = true
			_:
				pass
	wave_size = first_wave
	next_think = 10


func update(w: SimWorld) -> void:
	if w.tick_count < next_think:
		return
	next_think = w.tick_count + think_ticks
	var me: SimPlayer = w.players[player_id]
	if me.defeated:
		return
	_f = me.faction
	if not _adapted:
		_adapt(w)
	_survey(w)
	if _hq == null:
		return
	if concedes and _should_concede(w):
		w.alert(player_id, "%s concedes" % me.name, _hq.pos)
		w.push_command(SimCommand.surrender(player_id))
		return
	_spent = 0
	_bandwidth_committed = 0
	_run_economy(w, me)
	_run_construction(w, me)
	_run_mobile_factory(w, me)
	_run_mobile_relays(w, me)
	_run_production(w, me)
	_run_scout(w)
	_run_military(w)
	_run_hijackers(w)
	_run_directives(w, me)


## Once, on the first think: a Normal or Hard AI plays to the rule its
## faction has. Nothing here names a faction; it reads what the faction can do.
func _adapt(w: SimWorld) -> void:
	_adapted = true
	if level == 0 or not faction_tricks:
		return
	# Hidden while standing still inside its own coverage: wait for the
	# enemy at the forward relay instead of at the headquarters.
	if _f.linked_cloak:
		ambushes = true
	# Paid for what it destroys: go where the value is and the guns are not.
	if _f.kill_bounty > 0.0:
		raids = true
	# Grows back when left alone: pull back sooner and more often.
	if _f.regrowth > 0.0:
		max_retreats += 2
		retreat_share = 0.6
	# A real air arm: use it on the enemy's relays between waves.
	var craft: int = 0
	for def: EntityDef in w.data.entities.values():
		if def.faction == _f.id and not def.is_building and def.is_air() and def.is_armed() and def.ai_weight > 0.0:
			craft += 1
	strikes = craft >= 2


## What a side has left to fight with: its army counted twice over, and
## its buildings other than headquarters.
func _strength(w: SimWorld, team: int) -> int:
	var total: int = 0
	for e: SimEntity in w.entities:
		if not e.alive or e.def == null or e.owner < 0 or w.players[e.owner].team != team:
			continue
		if e.kind == SimEntity.Kind.UNIT:
			total += e.def.cost * (2 if e.def.is_armed() else 1)
		elif e.kind == SimEntity.Kind.BUILDING and e.constructed and not e.def.signal_root:
			total += e.def.cost
	return total


## True once the match has plainly been lost for a while. Two ways to be
## beaten: reduced to a handful of buildings with the strongest enemy side
## at two and a half times our side's strength; or, later in the game,
## starved (next to no income for four minutes and nothing put by) with the
## enemy at half again our strength. Either has to hold for two and a half
## minutes on end. A beaten AI otherwise holds its headquarters for as long
## as it has turrets and a barrage to call, and the match never ends.
## This is for matches the AI plays against itself (watched, or in the
## checks). While a person is still playing, on either side, no AI gives
## up: the owner would rather fight an opponent to its last building.
func _should_concede(w: SimWorld) -> bool:
	var me: SimPlayer = w.players[player_id]
	for p: SimPlayer in w.players:
		if not p.is_ai and not p.defeated:
			_hopeless_since = -1
			return false
	if w.tick_count - _income_mark >= STARVED_WINDOW_TICKS:
		_starving = me.stat_salvage_collected - _income_seen < STARVED_INCOME
		_income_mark = w.tick_count
		_income_seen = me.stat_salvage_collected
	if w.tick_count < CONCEDE_AFTER_TICKS:
		_hopeless_since = -1
		return false
	var few: bool = _buildings.size() <= CONCEDE_MAX_BUILDINGS
	var starved: bool = _starving and me.salvage < STARVED_BANK and w.tick_count >= STARVED_AFTER_TICKS
	if not few and not starved:
		_hopeless_since = -1
		return false
	var my_team: int = me.team
	var best_enemy: int = 0
	var seen: Dictionary[int, bool] = {}
	for p: SimPlayer in w.players:
		if p.defeated:
			continue
		if p.team != my_team and not seen.has(p.team):
			seen[p.team] = true
			best_enemy = maxi(best_enemy, _strength(w, p.team))
	var mine: float = float(_strength(w, my_team))
	var beaten: bool = (few and mine * CONCEDE_RATIO <= float(best_enemy)) or (starved and mine * STARVED_RATIO <= float(best_enemy))
	if not beaten:
		_hopeless_since = -1
		return false
	if _hopeless_since < 0:
		_hopeless_since = w.tick_count
	return w.tick_count - _hopeless_since >= CONCEDE_HOLD_TICKS


# ------------------------------------------------------------------ survey

func _survey(w: SimWorld) -> void:
	_hq = null
	_engineers.clear()
	_mobile.clear()
	_hijackers.clear()
	_haulers.clear()
	_army.clear()
	_buildings.clear()
	_sites.clear()
	_enemies.clear()
	_enemy_buildings.clear()
	_ally_hqs.clear()
	_ally_army.clear()
	for e: SimEntity in w.entities:
		if not e.alive or e.def == null:
			continue
		if w.are_allies(player_id, e.owner):
			if e.kind == SimEntity.Kind.BUILDING and e.def.signal_root and e.constructed:
				_ally_hqs.append(e)
			elif e.kind == SimEntity.Kind.UNIT and e.def.is_armed() and not w.players[e.owner].is_ai:
				_ally_army.append(e)
		elif e.owner == player_id:
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
			elif e.def.deploys_to != "":
				_mobile.append(e)
			elif e.def.hijacker:
				_hijackers.append(e)
			elif e.def.is_armed() or e.def.ai_role == "support":
				_army.append(e)
		elif w.are_enemies(player_id, e.owner):
			# The AI plays by the same fog of war as a human: it only knows
			# units it can see right now and buildings it has seen before.
			var seen: bool = SimVision.can_see(w, player_id, e)
			if e.kind == SimEntity.Kind.BUILDING:
				if seen:
					_known_buildings[e.id] = true
				if seen or _known_buildings.has(e.id):
					_enemy_buildings.append(e)
			elif seen:
				_enemies.append(e)


## The definition id this faction uses for a job ("" if it has none).
func _r(role_name: String) -> String:
	return _f.role(role_name)


func _can(w: SimWorld, me: SimPlayer, def_id: String) -> bool:
	return def_id != "" and me.meets_requirements(w.data.entity(def_id))


func _count(def_id: String, include_sites: bool = true) -> int:
	var n: int = 0
	if def_id == "":
		return n
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


## Where the nearest surviving enemy's headquarters is (or started).
func _enemy_hq_pos(w: SimWorld) -> Vector2:
	var from: Vector2 = _hq.pos if _hq != null else w.players[player_id].start_pos
	var best: Vector2 = w.map.world_size() * 0.5
	var best_d: float = INF
	for p: SimPlayer in w.players:
		if not w.are_enemies(player_id, p.id) or p.defeated:
			continue
		var at: Vector2 = p.start_pos
		for b: SimEntity in _enemy_buildings:
			if b.owner == p.id and b.def.signal_root:
				at = b.pos
		var d: float = at.distance_to(from)
		if d < best_d:
			best_d = d
			best = at
	return best


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
	_want_haulers = mini(max_haulers, 3 + _count(_r("depot"), false) * 2 + (1 if w.tick_count > 20 * 120 else 0))
	if _haulers.size() + _queued(_r("hauler")) < _want_haulers and _best_resource(w) != null:
		_train_at_any(w, me, _r("hauler"))
	if _engineers.size() + _queued(_r("builder")) < max_engineers:
		_train_at_any(w, me, _r("builder"))


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
	# Too far to be worth the trip: 90 units on a 128-unit map, scaled with it.
	if best_score > w.map.world_size().x * 0.7:
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
	if def == null or not _can_afford(me, def.cost) or not me.meets_requirements(def):
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

	# A spare engineer claims any uplink site our network already reaches.
	if free.size() >= 2 or w.tick_count > 20 * 90:
		for e: SimEntity in w.entities:
			if e.kind == SimEntity.Kind.UPLINK and e.owner != player_id and not w.are_allies(player_id, e.owner) and SimSignal.is_covered(w, player_id, e.pos):
				if _threat_near(e.pos, 16.0) == null:
					var one: Array[SimEntity] = [free[free.size() - 1]]
					w.push_command(SimCommand.capture(player_id, _ids(one), e.id))
					free.remove_at(free.size() - 1)
					break
		if free.is_empty():
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
	var relay: String = _r("relay")
	var barracks: String = _r("barracks")
	var works: String = _r("works")
	var ground: String = _r("turret_ground")
	var armor: String = _r("turret_armor")
	var flak: String = _r("turret_air")
	var tier3: String = _r("tier3")
	var airpad: String = _r("airpad")
	var relays: int = _count(relay)
	var turrets: int = _count(ground) + (_count(armor) if armor != ground else 0)
	var headroom: int = me.bandwidth_cap - me.bandwidth_used - _queued_bandwidth(w)
	# Short-range relays (Foundry Pylons) need to come in greater numbers.
	var early_relays: int = 3 if w.data.entity(relay).signal_radius >= 15.0 else 6
	var has_barracks: bool = me.has_building(barracks)
	# Factions whose relays are deployed units expand in _run_mobile_relays.
	var build_relays: bool = w.data.entity(relay).buildable
	if _count(barracks) == 0:
		return barracks
	if build_relays and relays == 0:
		return relay
	if build_relays and headroom < 6 and me.bandwidth_cap < w.data.bandwidth_max:
		return relay
	if works != "" and _count(works) == 0 and has_barracks:
		return works
	if _wants_depot(w):
		return _r("depot")
	# Salvage piling up means production is the bottleneck: add capacity,
	# and do it before the steps below that an enemy can keep undoing. (An
	# AI whose forward relays were shot down as fast as it raised them used
	# to stand at the relay step for the whole match, with one barracks, one
	# works and thousands of salvage in the bank.)
	var spare: int = mini(3, me.salvage / 1500)
	if spare > 0 and has_barracks:
		if works != "" and _count(works) < max_works + spare:
			return works
		if _count(barracks) < max_barracks + spare:
			return barracks
	if build_relays and relays < early_relays and _relay_goal(w) != Vector2.INF:
		return relay
	if builds_turrets and _can(w, me, ground) and _count(ground) < 1:
		return ground
	if builds_turrets and armor != ground and _can(w, me, armor) and _count(armor) < 1:
		return armor
	if builds_turrets and _can(w, me, flak) and _enemy_air_seen > 0 and _count(flak) < 2:
		return flak
	if level > 0 and _can(w, me, tier3) and _count(tier3) == 0 and me.salvage > 650 and w.tick_count > 20 * 240:
		return tier3
	if level > 0 and _can(w, me, airpad) and _count(airpad) == 0 and me.salvage > 550:
		return airpad
	if build_relays and relays < early_relays * 2 and _relay_goal(w) != Vector2.INF and me.salvage > 500:
		return relay
	if me.salvage > 900 and _count(barracks) < max_barracks + spare:
		return barracks
	if works != "" and me.salvage > 1200 and _count(works) < max_works + spare and has_barracks:
		return works
	if builds_turrets and me.salvage > turret_salvage and turrets < max_turrets:
		return armor if _can(w, me, armor) and rng.chance(0.5) else (ground if _can(w, me, ground) else "")
	return ""


## The nearest salvage field or uplink site on our half of the map that our
## signal does not reach yet. Uplinks matter most late, when fields run dry.
func _relay_goal(w: SimWorld) -> Vector2:
	var best: Vector2 = Vector2.INF
	var best_d: float = INF
	for e: SimEntity in w.entities:
		var wanted: bool = e.kind == SimEntity.Kind.UPLINK or (e.kind == SimEntity.Kind.FIELD and e.is_harvestable())
		if not wanted or SimSignal.is_covered(w, player_id, e.pos):
			continue
		var d: float = e.pos.distance_to(_hq.pos)
		# Leave the enemy's half alone.
		if e.pos.distance_to(_enemy_hq_pos(w)) < d:
			continue
		if d < best_d:
			best_d = d
			best = e.pos
	if best == Vector2.INF and _count(_r("relay")) < 4:
		# Nothing left to claim: push the network towards the middle.
		var mid: Vector2 = w.map.world_size() * 0.5
		if not SimSignal.is_covered(w, player_id, mid):
			best = mid
	return best


func _wants_depot(w: SimWorld) -> bool:
	if _count(_r("depot")) >= 2:
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
	if def.id == _r("relay"):
		around = _relay_spot(w, def)
		if around == Vector2.INF:
			return Vector2i(-1, -1)
		spread = 5
	elif def.id == _r("depot"):
		var spot: Vector2 = _depot_spot(w)
		if spot != Vector2.INF:
			around = spot
		spread = 6
	elif def.is_armed():
		# Guard the front of the base and the forward relays in turn.
		var anchor: SimEntity = _hq
		var n: int = _count(_r("turret_ground")) + _count(_r("turret_armor")) + _count(_r("turret_air"))
		if n % 2 == 1:
			anchor = _forward_relay(w)
		around = anchor.pos + toward_enemy * (anchor.radius + 5.0) + Vector2(-toward_enemy.y, toward_enemy.x) * rng.range_f(-5.0, 5.0)
		spread = 5
	else:
		around = _base_ring_spot(toward_enemy)
	return _find_cell(w, def, around, spread, null)


## Where the next relay should go: a step from the nearest linked emitter
## towards the next uncovered goal, close enough to cover it.
func _relay_spot(w: SimWorld, relay_def: EntityDef) -> Vector2:
	var goal: Vector2 = _relay_goal(w)
	if goal == Vector2.INF:
		goal = _hq.pos + (_enemy_hq_pos(w) - _hq.pos).normalized() * 40.0
	var from: SimEntity = _nearest_linked_emitter(w, goal)
	if from == null:
		return Vector2.INF
	var gap: float = from.pos.distance_to(goal)
	var step: float = clampf(gap - relay_def.signal_radius * 0.4, 6.0, w.data.link_range - 4.0)
	var spot: Vector2 = from.pos + (goal - from.pos).normalized() * step
	# A relay raised under the enemy's guns is a relay lost, and with it
	# the bandwidth the army is waiting for. While they stand there, raise
	# it behind the base instead: it reaches nothing new, but it carries
	# bandwidth, and that comes before ground.
	if _threat_near(spot, RELAY_DANGER_RADIUS) != null:
		relays_kept_home += 1
		return _base_ring_spot((_enemy_hq_pos(w) - _hq.pos).normalized())
	return spot


## A spot in the ring around the HQ, biased away from the enemy.
func _base_ring_spot(toward_enemy: Vector2) -> Vector2:
	var ang: float = toward_enemy.angle() + PI + rng.range_f(-1.9, 1.9)
	return _hq.pos + Vector2.from_angle(ang) * rng.range_f(11.0, 17.0)


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
		if b.def.id == _r("relay") and b.linked:
			var d: float = b.pos.distance_to(target)
			if d < best_d:
				best_d = d
				best = b
	return best


## Searches outward from `around` for a legal footprint with a free border,
## so buildings never wall each other in.
## With `deployer` set, `def` is the building a unit deploys into and the
## deploy rules are used instead of the build rules.
func _find_cell(w: SimWorld, def: EntityDef, around: Vector2, max_ring: int, deployer: EntityDef) -> Vector2i:
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
				if deployer != null:
					if SimEconomy.deploy_error(w, player_id, deployer, c) != "":
						continue
				elif not SimEconomy.can_place(w, player_id, def, c):
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

## Factions whose vehicle factory is a deployed unit (the Foundry Crawler):
## keep one built and set up next to the HQ.
func _run_mobile_factory(w: SimWorld, me: SimPlayer) -> void:
	var unit_id: String = _r("mobile_unit")
	if unit_id == "":
		return
	var factory_def: EntityDef = w.data.entity(_r("mobile_factory"))
	var want: int = mini(3, max_works + me.salvage / 1500)
	if _count(factory_def.id, false) + _mobile.size() + _queued(unit_id) < want and _can(w, me, unit_id):
		_train_at_any(w, me, unit_id)
	var toward_enemy: Vector2 = (_enemy_hq_pos(w) - _hq.pos).normalized()
	for c: SimEntity in _mobile:
		if c.def.id != unit_id or not c.orders.is_empty():
			continue
		var cell: Vector2i = _find_cell(w, factory_def, _base_ring_spot(toward_enemy), 10, c.def)
		if cell.x >= 0:
			w.push_command(SimCommand.deploy(player_id, PackedInt32Array([c.id]), cell))


## Factions whose relays are deployed units (Nomad Beacon Rigs): build rigs
## when the network needs to grow and drive them out to where a relay belongs.
func _run_mobile_relays(w: SimWorld, me: SimPlayer) -> void:
	var unit_id: String = _r("relay_unit")
	if unit_id == "":
		return
	var relay_def: EntityDef = w.data.entity(_r("relay"))
	var rigs: Array[SimEntity] = []
	for c: SimEntity in _mobile:
		if c.def.id == unit_id:
			rigs.append(c)
	var relays: int = _count(relay_def.id, false)
	var pending: int = rigs.size() + _queued(unit_id)
	var headroom: int = me.bandwidth_cap - me.bandwidth_used - _queued_bandwidth(w)
	var want: bool = false
	if relays + pending == 0:
		want = true
	elif pending == 0 and headroom < 6 and me.bandwidth_cap < w.data.bandwidth_max:
		want = true
	elif pending == 0 and relays < 7 and _relay_goal(w) != Vector2.INF and me.salvage > 250:
		want = true
	if want:
		_train_at_any(w, me, unit_id)
	for rig: SimEntity in rigs:
		if not rig.orders.is_empty():
			continue
		var spot: Vector2 = _relay_spot(w, relay_def)
		if spot == Vector2.INF:
			continue
		var cell: Vector2i = _find_cell(w, relay_def, spot, 5, rig.def)
		if cell.x >= 0:
			w.push_command(SimCommand.deploy(player_id, PackedInt32Array([rig.id]), cell))


## Splicers go after any enemy vehicle seen outside its owner's signal.
func _run_hijackers(w: SimWorld) -> void:
	for h: SimEntity in _hijackers:
		if not h.orders.is_empty():
			continue
		var best: SimEntity = null
		var best_d: float = 55.0
		for e: SimEntity in _enemies:
			if SimEconomy.hijack_error(w, h, e) != "":
				continue
			var d: float = e.pos.distance_to(h.pos)
			if d < best_d:
				best_d = d
				best = e
		if best != null:
			w.push_command(SimCommand.capture(player_id, PackedInt32Array([h.id]), best.id))


func _run_production(w: SimWorld, me: SimPlayer) -> void:
	# Keep enough in the bank for the next building in the build order.
	var reserve: int = 0
	var next: String = _next_building(w, me)
	if next != "" and not _engineers.is_empty():
		reserve = w.data.entity(next).cost
	# Never spend the last salvage on soldiers while there is nobody to
	# collect more or to build anything.
	# The same goes for an economy that has been raided down to under half
	# of the haulers it wants: replace them before buying more soldiers.
	if _haulers.size() + _queued(_r("hauler")) < maxi(2, (_want_haulers + 1) / 2) and _best_resource(w) != null:
		reserve = maxi(reserve, w.data.entity(_r("hauler")).cost)
	if _engineers.size() + _queued(_r("builder")) == 0:
		reserve = maxi(reserve, w.data.entity(_r("builder")).cost)
	var heavy: int = 0
	var light: int = 0
	var infantry: int = 0
	var air: int = 0
	for e: SimEntity in _enemies:
		if e.def.is_air():
			air += 1
		elif e.def.is_infantry():
			infantry += 1
		elif w.data.armor_classes[e.def.armor] == "heavy":
			heavy += 1
		else:
			light += 1
	_enemy_air_seen = maxi(_enemy_air_seen, air)
	var support: int = 0
	for e: SimEntity in _army:
		if e.def.ai_role == "support":
			support += 1
	# Guns the enemy has built: what they out-range is worth having.
	var turrets_known: int = 0
	for b: SimEntity in _enemy_buildings:
		if b.def.is_armed() and b.constructed and not b.def.is_mine() and not b.def.signal_root:
			turrets_known += 1
	var depth: int = 3 if me.salvage > 1000 else 2
	for b: SimEntity in _buildings:
		if b.def.produces.is_empty() or not b.linked or b.queue.size() >= depth:
			continue
		# Having decided what to build here, wait until it can be afforded
		# rather than settling for whatever is cheapest right now.
		if _wish.has(b.id):
			var wanted: EntityDef = w.data.entity(_wish[b.id])
			if not me.meets_requirements(wanted) or not b.def.produces.has(wanted.id):
				_wish.erase(b.id)
			elif me.bandwidth_used + _queued_bandwidth(w) + wanted.bandwidth > me.bandwidth_cap:
				_wish.erase(b.id)
			elif _can_afford(me, wanted.cost + reserve):
				w.push_command(SimCommand.train(player_id, b.id, wanted.id))
				_spent += wanted.cost
				_bandwidth_committed += wanted.bandwidth
				_wish.erase(b.id)
				continue
			elif w.tick_count - _wish_tick.get(b.id, 0) > 20 * 90:
				_wish.erase(b.id)  # waited long enough; think again
			else:
				continue
		var options: Array[String] = []
		var weights: Array[float] = []
		var total: float = 0.0
		for id: String in b.def.produces:
			var def: EntityDef = w.data.entity(id)
			if def.ai_weight <= 0.0:
				continue  # builders, haulers and factories are handled elsewhere
			if not me.meets_requirements(def):
				continue
			if me.bandwidth_used + _queued_bandwidth(w) + def.bandwidth > me.bandwidth_cap:
				continue
			# Base weight from data, raised by what the enemy is fielding.
			var wgt: float = def.ai_weight
			match def.ai_role:
				"anti_infantry":
					wgt += float(infantry) * 0.25
				"anti_armor":
					wgt += float(heavy) * 0.6 + float(light) * 0.3
				"anti_air":
					# Enough flak to matter, never an army of nothing else: an
					# opponent with a few aircraft is not answered with a
					# force that cannot fight what is on the ground.
					wgt += minf(float(_enemy_air_seen) * 1.2, 3.6)
				"artillery":
					# An enemy behind turrets is answered with siege guns.
					wgt += minf(float(turrets_known) * 0.45, 3.0)
				"support":
					if support + _queued(id) >= 2:
						wgt = 0.0
				_:
					pass
			if wgt <= 0.0:
				continue
			options.append(id)
			weights.append(wgt)
			total += wgt
		if options.is_empty():
			continue
		var roll: float = rng.range_f(0.0, total)
		var pick: String = options[options.size() - 1]
		for i: int in options.size():
			roll -= weights[i]
			if roll <= 0.0:
				pick = options[i]
				break
		if _can_afford(me, w.data.entity(pick).cost + reserve):
			w.push_command(SimCommand.train(player_id, b.id, pick))
			_spent += w.data.entity(pick).cost
			_bandwidth_committed += w.data.entity(pick).bandwidth
		else:
			_wish[b.id] = pick
			_wish_tick[b.id] = w.tick_count


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
	if ambushes:
		# Lie in wait where the enemy has to come past, inside our own
		# coverage, where nothing that stands still can be seen.
		var forward: SimEntity = _forward_relay(w)
		if forward != null and forward.pos.distance_to(_hq.pos) > 14.0:
			rally = w.map.nearest_free_pos(forward.pos + toward_enemy * 3.0)

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
		if not wave_ids.has(e.id) and e.id != _scout_id:
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
		var in_need: SimEntity = _ally_threat() if helps_allies else null
		if in_need != null and home.size() >= 4:
			# An ally's headquarters is under attack and ours is not: go.
			var rescuers: Array[SimEntity] = []
			for e: SimEntity in home:
				if e.orders.is_empty() or e.pos.distance_to(in_need.pos) > 30.0:
					rescuers.append(e)
			if not rescuers.is_empty():
				if _rescuing_tick < 0 or w.tick_count - _rescuing_tick > 20 * 30:
					ally_rescues += 1
				_rescuing_tick = w.tick_count
				w.push_command(SimCommand.attack_move(player_id, _ids(rescuers), in_need.pos))
		else:
			# Idle units gather at the rally point.
			var strays: Array[SimEntity] = []
			for e: SimEntity in home:
				if e.orders.is_empty() and e.pos.distance_to(rally) > 9.0:
					strays.append(e)
			if not strays.is_empty():
				w.push_command(SimCommand.attack_move(player_id, _ids(strays), rally))
			if strikes:
				_run_strike(w, home)

	match wave_state:
		Wave.NONE:
			var since: int = w.tick_count - maxi(last_wave_end, 0)
			var ready: bool = home.size() >= wave_size and since >= wave_cooldown_ticks
			# A starved economy may never reach the full wave size: after a long
			# quiet spell go with whatever has gathered, and aim lower next time.
			if not ready and since >= STALL_TICKS and home.size() >= maxi(4, wave_size / 4):
				ready = true
				wave_size = maxi(first_wave, home.size())
			# An ally is attacking: go with half a wave rather than wait for a whole one.
			if not ready and helps_allies and since >= wave_cooldown_ticks / 2 and home.size() >= maxi(4, wave_size / 2) and _ally_target(w) != null:
				ready = true
			if threat == null and ready:
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
			if retreats and _should_retreat(w):
				_retreat(w, rally)
			elif threat == null and _wave_spent(w) and _next_wave_ready(w, home.size()):
				# What is left of the old wave falls in with the new one.
				var both: Array[SimEntity] = home.duplicate()
				for id: int in wave_ids:
					both.append(w.get_entity(id))
				_end_wave(w)
				_launch_wave(w, both)
			else:
				_assault(w, false)


## True when the wave is down to two fifths of what it set out with and what
## it faces is clearly stronger: time to save what is left. An AI only does
## this a couple of times in a match, and never late in a long one: an army
## that keeps pulling back never finishes anything, and both sides starve.
func _should_retreat(w: SimWorld) -> bool:
	if wave_ids.is_empty() or wave_launch_power <= 0 or w.tick_count > LATE_GAME_TICKS:
		return false
	if retreats_made >= max_retreats:
		return false
	var mine: int = 0
	var centre: Vector2 = Vector2.ZERO
	for id: int in wave_ids:
		var e: SimEntity = w.get_entity(id)
		mine += e.def.cost
		centre += e.pos
	centre /= float(wave_ids.size())
	if float(mine) > float(wave_launch_power) * retreat_share:
		return false
	var theirs: int = 0
	for e: SimEntity in _enemies:
		if e.def.is_armed() and e.pos.distance_to(centre) < 18.0:
			theirs += e.def.cost
	for b: SimEntity in _enemy_buildings:
		if b.def.is_armed() and b.constructed and not b.def.is_mine() and b.pos.distance_to(centre) < 16.0:
			theirs += b.def.cost
	return theirs * 10 > mine * 16


## True when the wave out there is no longer much of an attack: worn down
## to a third of what set out, or out for four minutes. A handful of
## survivors (or one unit that cannot hurt what it was sent against) must
## not keep the next wave waiting at home for ever.
func _wave_spent(w: SimWorld) -> bool:
	if w.tick_count - wave_tick > REINFORCE_TICKS:
		return true
	var left: int = 0
	for id: int in wave_ids:
		left += w.get_entity(id).def.cost
	return left * 3 <= wave_launch_power


## Whether enough has gathered at home to set out as a wave while the last
## one is still in the field: a full wave, or, when the last one has been
## out a long time, whatever a starved economy has managed.
func _next_wave_ready(w: SimWorld, at_home: int) -> bool:
	if at_home >= wave_size:
		return true
	if w.tick_count - wave_tick >= REINFORCE_TICKS + STALL_TICKS and at_home >= maxi(4, wave_size / 4):
		wave_size = maxi(first_wave, at_home)
		return true
	return false


## Calls the wave home. The next one will be bigger.
func _retreat(w: SimWorld, rally: Vector2) -> void:
	w.push_command(SimCommand.move(player_id, PackedInt32Array(wave_ids), rally))
	retreats_made += 1
	_end_wave(w)


## Keeps one unit out looking: it tours the fields on the enemy's side, the
## uplink sites and the approach to the enemy base, so that the AI learns
## where the enemy's relays and depots are before it has to attack them.
func _run_scout(w: SimWorld) -> void:
	if not scouts:
		return
	var scout: SimEntity = w.get_entity(_scout_id) if _scout_id != 0 else null
	if scout != null and (scout.owner != player_id or wave_ids.has(scout.id)):
		scout = null
	if scout != null and scout.def.ai_role != "scout" and not _known_buildings.is_empty():
		# A soldier pressed into scouting has done its job: back to the ranks.
		w.push_command(SimCommand.stop(player_id, PackedInt32Array([scout.id])))
		scout = null
	if scout == null:
		_scout_id = 0
		for e: SimEntity in _army:
			if e.def.ai_role == "scout" and not wave_ids.has(e.id) and (scout == null or e.def.speed > scout.def.speed):
				scout = e
		if scout == null and _known_buildings.is_empty() and w.tick_count > 20 * 75:
			# No proper scout and nothing known yet: send the quickest soldier.
			for e: SimEntity in _army:
				if not wave_ids.has(e.id) and not e.def.is_air() and (scout == null or e.def.speed > scout.def.speed):
					scout = e
		if scout == null:
			return
		_scout_id = scout.id
		scouts_sent += 1
		w.push_command(SimCommand.stop(player_id, PackedInt32Array([scout.id])))
		return
	if not scout.orders.is_empty():
		return
	var route: Array[Vector2] = _scout_route(w)
	_scout_leg = (_scout_leg + 1) % route.size()
	w.push_command(SimCommand.move(player_id, PackedInt32Array([scout.id]), w.map.nearest_free_pos(route[_scout_leg])))


func _scout_route(w: SimWorld) -> Array[Vector2]:
	var enemy: Vector2 = _enemy_hq_pos(w)
	var out: Array[Vector2] = [w.map.world_size() * 0.5]
	for f: Vector3 in w.map.field_spots:
		var at: Vector2 = Vector2(f.x, f.y)
		if at.distance_to(enemy) < at.distance_to(_hq.pos):
			out.append(at)
	for u: Vector2 in w.map.uplink_spots:
		out.append(u)
	out.append(enemy + (_hq.pos - enemy).normalized() * 12.0)
	return out


func _count_near(list: Array[SimEntity], pos: Vector2, radius: float) -> int:
	var n: int = 0
	for e: SimEntity in list:
		if e.pos.distance_to(pos) <= radius:
			n += 1
	return n


func _launch_wave(w: SimWorld, units: Array[SimEntity]) -> void:
	var target: SimEntity = _pick_target(w)
	wave_ids.clear()
	for e: SimEntity in units:
		wave_ids.append(e.id)
	# With nothing scouted yet, head for where the enemy started.
	wave_target = target.id if target != null else 0
	wave_target_pos = target.pos if target != null else _enemy_hq_pos(w)
	wave_state = Wave.STAGING
	wave_tick = w.tick_count
	waves_sent += 1
	wave_launch_power = 0
	for e: SimEntity in units:
		wave_launch_power += e.def.cost
	var back: Vector2 = (_hq.pos - wave_target_pos).normalized()
	wave_stage = w.map.nearest_free_pos(w.map.clamp_to_map(wave_target_pos + back * STAGE_DISTANCE))
	wave_side = 0
	# Every other big wave comes round the side instead: a defence built
	# across the straight road does not cover everything. The wave stays
	# whole; an attack split in two breaks on defences that one would carry.
	if flanks and level > 0 and units.size() >= FLANK_MIN_WAVE and waves_sent % 2 == 0 and w.tick_count < LATE_GAME_TICKS:
		_plan_flank(w, back)
	w.push_command(SimCommand.move(player_id, PackedInt32Array(wave_ids), wave_stage))


## Moves the gathering place round to one side of the target, alternating
## sides, unless the way there is blocked or much longer than the way
## straight in.
func _plan_flank(w: SimWorld, back: Vector2) -> void:
	var side: int = 1 if flanks_sent % 2 == 0 else -1
	for attempt: int in 2:
		var spot: Vector2 = w.map.clamp_to_map(wave_target_pos + back.rotated(float(side) * FLANK_ANGLE) * STAGE_DISTANCE)
		spot = w.map.nearest_free_pos(spot)
		var direct: float = _hq.pos.distance_to(spot)
		var path: PackedVector2Array = w.map.find_path(_hq.pos, spot, true)
		var along: float = 0.0
		for i: int in range(1, path.size()):
			along += path[i - 1].distance_to(path[i])
		if path.size() >= 2 and along <= direct * 1.5 and spot.distance_to(wave_stage) > 12.0:
			wave_stage = spot
			wave_side = side
			flanks_sent += 1
			return
		side = -side


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
		var goal: Vector2 = target.pos if target != null else _enemy_hq_pos(w)
		if target != null or goal.distance_to(wave_target_pos) > 1.0:
			fresh = true
		wave_target = target.id if target != null else 0
		wave_target_pos = goal
	else:
		wave_target_pos = target.pos
	# Keep the wave together. Aircraft and scout cars are two or three times
	# as fast as infantry and used to reach the enemy alone and die there
	# before the rest arrived: anything well ahead of the main body waits.
	var body: float = 0.0
	var leashed: bool = keeps_together and wave_ids.size() >= 3 and w.tick_count - wave_tick < LEASH_TICKS
	if leashed:
		var dists: Array[float] = []
		for id: int in wave_ids:
			dists.append(w.get_entity(id).pos.distance_to(wave_target_pos))
		dists.sort()
		body = dists[(dists.size() * 2) / 3]
	var who: PackedInt32Array = PackedInt32Array()
	var wait: PackedInt32Array = PackedInt32Array()
	for id: int in wave_ids:
		var e: SimEntity = w.get_entity(id)
		var d: float = e.pos.distance_to(wave_target_pos)
		if leashed and d < body - LEASH_LEAD and d > LEASH_NEAR and e.target_id == 0:
			if not e.orders.is_empty():
				wait.append(id)
			continue
		if fresh or e.orders.is_empty():
			who.append(id)
	if not wait.is_empty():
		w.push_command(SimCommand.stop(player_id, wait))
	if not who.is_empty():
		w.push_command(SimCommand.attack_move(player_id, who, wave_target_pos))


# -------------------------------------------------------------- directives

const UNLOCK_ORDER: Array[String] = [
	"recon_sweep", "shell_barrage", "field_repair", "reinforcement_drop", "blackout", "signal_surge",
]


func _ready_to_use(w: SimWorld, me: SimPlayer, id: String) -> bool:
	return me.unlocked.has(id) and SimDirectives.cooldown_left(w, player_id, w.data.directive(id)) <= 0.0


func _run_directives(w: SimWorld, me: SimPlayer) -> void:
	if not uses_directives:
		return
	# Unlock in a fixed order, saving points for the next one on the list.
	for id: String in UNLOCK_ORDER:
		if not me.unlocked.has(id):
			if me.command_points >= w.data.directive(id).cost:
				w.push_command(SimCommand.unlock(player_id, id))
			break

	if _ready_to_use(w, me, "shell_barrage"):
		var def: DirectiveDef = w.data.directive("shell_barrage")
		var best: Vector2 = Vector2.INF
		var best_n: int = 2
		var candidates: Array[SimEntity] = []
		candidates.append_array(_enemies)
		for b: SimEntity in _enemy_buildings:
			if SimVision.can_see(w, player_id, b):
				candidates.append(b)
		for c: SimEntity in candidates:
			if SimDirectives.target_error(w, player_id, def, c.pos) != "":
				continue
			var n: int = _count_near(candidates, c.pos, def.radius)
			if n > best_n:
				best_n = n
				best = c.pos
		if best != Vector2.INF:
			w.push_command(SimCommand.directive(player_id, def.id, best))

	if _ready_to_use(w, me, "field_repair"):
		var def: DirectiveDef = w.data.directive("field_repair")
		var hurt: Array[SimEntity] = []
		for e: SimEntity in _army:
			if e.hp < e.max_hp * 0.6 and e.linked:
				hurt.append(e)
		for b: SimEntity in _buildings:
			if b.hp < b.max_hp * 0.6 and b.linked:
				hurt.append(b)
				hurt.append(b)  # buildings count double
		for e: SimEntity in hurt:
			if _count_near(hurt, e.pos, def.radius) >= 3:
				w.push_command(SimCommand.directive(player_id, def.id, e.pos))
				break

	if _ready_to_use(w, me, "reinforcement_drop") and me.bandwidth_used + 5 <= me.bandwidth_cap:
		var toward_enemy: Vector2 = (_enemy_hq_pos(w) - _hq.pos).normalized()
		var at: Vector2 = w.map.nearest_free_pos(_hq.pos + toward_enemy * (_hq.radius + 10.0))
		if SimSignal.is_covered(w, player_id, at):
			w.push_command(SimCommand.directive(player_id, "reinforcement_drop", at))

	if _ready_to_use(w, me, "recon_sweep") and wave_state == Wave.NONE:
		w.push_command(SimCommand.directive(player_id, "recon_sweep", _enemy_hq_pos(w)))

	if wave_state == Wave.ASSAULT:
		if _ready_to_use(w, me, "blackout") and SimVision.is_visible(w, player_id, wave_target_pos):
			for other: SimPlayer in w.players:
				if w.are_enemies(player_id, other.id) and SimSignal.is_covered(w, other.id, wave_target_pos):
					w.push_command(SimCommand.directive(player_id, "blackout", wave_target_pos))
					break
		if _ready_to_use(w, me, "signal_surge"):
			w.push_command(SimCommand.directive(player_id, "signal_surge", Vector2.ZERO))


## What to hit next. Normal and Hard AIs go for the relay whose loss would
## black out the most of the enemy network (raiders most of all, and they
## go for depots too); otherwise the nearest building, and the HQ once the
## outlying network is gone.
func _pick_target(w: SimWorld) -> SimEntity:
	if _enemy_buildings.is_empty():
		return null
	if helps_allies:
		var joined: SimEntity = _ally_target(w)
		if joined != null:
			return joined
	var from: Vector2 = _hq.pos
	if not wave_ids.is_empty():
		var lead: SimEntity = w.get_entity(wave_ids[0])
		if lead != null:
			from = lead.pos
	# Late in a long match, go for the headquarters: picking off outlying
	# buildings can drag on until both sides run out of salvage.
	var go_for_hq: bool = w.tick_count > LATE_GAME_TICKS
	var best: SimEntity = null
	var best_score: float = -INF
	for b: SimEntity in _enemy_buildings:
		if b.def.is_mine():
			continue
		var score: float = -from.distance_to(b.pos) * 0.05
		if b.def.signal_root:
			score += 12.0 if go_for_hq else 1.5
		elif hunts_relays and b.def.signal_radius > 0.0 and b.constructed:
			score += (2.0 + 2.5 * float(_downstream_count(w, b))) * (1.6 if raids else 1.0)
		elif raids and b.def.depot:
			score += 3.0
		elif b.def.is_armed():
			score -= 1.0
		if score > best_score:
			best_score = score
			best = b
	return best


## What an ally is attacking, if any is: an allied AI's wave target, or the
## enemy building nearest to where an allied person's army is fighting.
func _ally_target(w: SimWorld) -> SimEntity:
	for other: SimAI in w.ais:
		if other == self or not w.are_allies(player_id, other.player_id) or other.wave_state == Wave.NONE:
			continue
		var theirs: SimEntity = w.get_entity(other.wave_target)
		if theirs != null and theirs.alive and w.are_enemies(player_id, theirs.owner):
			return theirs
	if _ally_army.size() < 5:
		return null
	# Units of an allied person that are well away from that person's base.
	var front: Vector2 = Vector2.ZERO
	var away: int = 0
	for e: SimEntity in _ally_army:
		if e.pos.distance_to(w.players[e.owner].start_pos) > 45.0:
			front += e.pos
			away += 1
	if away < 5:
		return null
	front /= float(away)
	var best: SimEntity = null
	var best_d: float = 30.0
	for b: SimEntity in _enemy_buildings:
		if b.def.is_mine():
			continue
		var d: float = b.pos.distance_to(front)
		if d < best_d:
			best_d = d
			best = b
	return best


## An enemy near an ally's headquarters when that headquarters is under a
## real attack (three or more armed enemies close by), or null.
func _ally_threat() -> SimEntity:
	for hq: SimEntity in _ally_hqs:
		var near: SimEntity = null
		var near_d: float = INF
		var count: int = 0
		for e: SimEntity in _enemies:
			if not e.def.is_armed():
				continue
			var d: float = e.pos.distance_to(hq.pos)
			if d < 28.0:
				count += 1
				if d < near_d:
					near_d = d
					near = e
		if count >= 3:
			return near
	return null


## Between waves, idle aircraft go for the enemy relay whose loss would cut
## off the most, or failing that a depot: buildings that seldom shoot back.
func _run_strike(w: SimWorld, home: Array[SimEntity]) -> void:
	var craft: Array[SimEntity] = []
	for e: SimEntity in home:
		if e.def.is_air() and e.def.is_armed() and e.orders.is_empty():
			craft.append(e)
	if craft.size() < STRIKE_MIN_CRAFT:
		return
	var best: SimEntity = null
	var best_score: float = -INF
	for b: SimEntity in _enemy_buildings:
		if b.def.signal_root or b.def.is_mine() or b.def.is_armed():
			continue
		var score: float = -_hq.pos.distance_to(b.pos) * 0.03
		if b.def.signal_radius > 0.0 and b.constructed:
			score += 2.0 + 2.5 * float(_downstream_count(w, b))
		elif b.def.depot:
			score += 2.5
		else:
			continue
		# Leave alone what is ringed with guns that reach the sky.
		for g: SimEntity in _enemy_buildings:
			if g.def.is_armed() and g.constructed and g.pos.distance_to(b.pos) < 12.0:
				score -= 1.5
		if score > best_score:
			best_score = score
			best = b
	if best == null:
		return
	strikes_sent += 1
	w.push_command(SimCommand.attack(player_id, _ids(craft), best.id))


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
