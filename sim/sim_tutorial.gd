class_name SimTutorial
extends RefCounted
## Scripted tutorial missions. Each is a prepared battlefield plus an ordered
## list of objectives checked against the simulation, so a mission can be
## played (and tested) without any interface code.

class Step:
	var text: String = ""  ## what to do
	var hint: String = ""  ## how to do it
	var marker: Vector2 = Vector2.INF  ## a place to point at, or INF
	var check: Callable = Callable()  ## func(w: SimWorld) -> bool
	var on_start: Callable = Callable()  ## optional func(w: SimWorld), run when the step begins

const IDS: Array[String] = ["economy", "signal", "directives"]
const TITLES: Dictionary[String, String] = {
	"economy": "Tutorial 1: Salvage and Supply",
	"signal": "Tutorial 2: The Signal Grid",
	"directives": "Tutorial 3: Directives",
}
const BLURBS: Dictionary[String, String] = {
	"economy": "Haulers, wrecks, building, training and bandwidth.",
	"signal": "Linked and Dark, relay chains, and how to cut one.",
	"directives": "Command Points and the commander powers they unlock.",
}
const PLAYER: int = 0
const ENEMY: int = 1

var id: String = ""
var steps: Array[Step] = []
var index: int = 0
var done: bool = false
var changed_tick: int = 0  ## tick of the last step change, for the interface
var memo: Dictionary[String, int] = {}  ## numbers a step records when it begins
var _started: int = -1  ## index of the last step whose on_start has run


## The match configuration for a tutorial mission.
static func config_for(tutorial_id: String) -> MatchConfig:
	var c: MatchConfig = MatchConfig.skirmish(101 + IDS.find(tutorial_id))
	c.is_ai = [false, false]  # the opponent only stands there
	c.names = ["Commander", "Training Opponent"]
	c.tutorial = tutorial_id
	return c


## Prepares the world and returns the mission. Called by SimSetup.
static func create(w: SimWorld, tutorial_id: String) -> SimTutorial:
	var t: SimTutorial = SimTutorial.new()
	t.id = tutorial_id
	w.victory_enabled = false
	match tutorial_id:
		"signal":
			t._setup_signal(w)
		"directives":
			t._setup_directives(w)
		_:
			t._setup_economy(w)
	return t


func current() -> Step:
	if done or index >= steps.size():
		return null
	return steps[index]


## Advances past every objective that has been met. Called by SimWorld.
func update(w: SimWorld) -> void:
	if done:
		return
	while index < steps.size():
		if _started < index:
			_started = index
			if steps[index].on_start.is_valid():
				steps[index].on_start.call(w)
			return  # give the world a moment before judging a fresh objective
		if not steps[index].check.call(w):
			return
		index += 1
		changed_tick = w.tick_count
		w.alert(PLAYER, "Objective complete", Vector2.ZERO)
	done = true
	changed_tick = w.tick_count


func _add(text: String, hint: String, check: Callable, marker: Vector2 = Vector2.INF, on_start: Callable = Callable()) -> void:
	var s: Step = Step.new()
	s.text = text
	s.hint = hint
	s.check = check
	s.marker = marker
	s.on_start = on_start
	steps.append(s)


# ---------------------------------------------------------------- helpers

static func _count(w: SimWorld, owner: int, def_id: String, finished: bool = true) -> int:
	var n: int = 0
	for e: SimEntity in w.entities:
		if e.alive and e.owner == owner and e.def != null and e.def.id == def_id and (e.constructed or not finished):
			n += 1
	return n


static func _hq(w: SimWorld, owner: int) -> SimEntity:
	for e: SimEntity in w.entities:
		if e.alive and e.owner == owner and e.def != null and e.def.signal_root:
			return e
	return null


static func _used(w: SimWorld, directive_id: String) -> bool:
	return w.players[PLAYER].directive_ready.has(directive_id)


## Open ground at `at` so scripted buildings and units always fit.
static func _flatten(w: SimWorld, at: Vector2, radius_cells: int) -> void:
	var c0: Vector2i = w.map.cell_of(at)
	for dy: int in range(-radius_cells, radius_cells + 1):
		for dx: int in range(-radius_cells, radius_cells + 1):
			w.map.set_terrain(Vector2i(c0.x + dx, c0.y + dy), SimMap.Terrain.GROUND)
	w.map.finalize()
	for e: SimEntity in w.entities:
		if e.alive and e.kind == SimEntity.Kind.BUILDING and e.def.blocks:
			w.map.set_occupied(Rect2i(e.footprint_cell, e.def.footprint), e.id)


static func _hold(w: SimWorld, units: Array[SimEntity]) -> void:
	for e: SimEntity in units:
		e.hold = true


# ---------------------------------------------------------------- economy

func _setup_economy(w: SimWorld) -> void:
	var hq: SimEntity = _hq(w, PLAYER)
	var toward: Vector2 = (w.map.world_size() * 0.5 - hq.pos).normalized()
	var wreck_at: Vector2 = w.map.nearest_free_pos(hq.pos + toward.rotated(1.2) * 15.0)
	var start_haulers: int = _count(w, PLAYER, "hauler")
	var start_troopers: int = _count(w, PLAYER, "trooper")
	_add(
		"Salvage is your only resource. Your Haulers are already collecting it. Train one more.",
		"Click the Headquarters, then press U (or click Hauler on the command card).",
		func(x: SimWorld) -> bool: return SimTutorial._count(x, PLAYER, "hauler") > start_haulers
	)
	_add(
		"Build a Barracks so you can train infantry.",
		"Select a Field Engineer (the yellow figures), press B, then click open ground inside the tinted area.",
		func(x: SimWorld) -> bool: return SimTutorial._count(x, PLAYER, "barracks") >= 1
	)
	_add(
		"Train three Troopers.",
		"Select the Barracks and press T three times. Right-click the ground to set where new units gather.",
		func(x: SimWorld) -> bool: return SimTutorial._count(x, PLAYER, "trooper") >= start_troopers + 3
	)
	_add(
		"Bandwidth (top left) caps your army. Each linked Relay adds 10. Build a Relay.",
		"Select a Field Engineer and press R. A Relay must stand within link range of your network.",
		func(x: SimWorld) -> bool: return x.players[PLAYER].bandwidth_cap >= 30
	)
	_add(
		"Destroyed vehicles and buildings leave wrecks worth a quarter of their cost. Salvage the wreck near your base.",
		"Select a Hauler and right-click the wreck.",
		func(x: SimWorld) -> bool: return x.get_entity(x.tutorial.memo.get("wreck", 0)) == null,
		wreck_at,
		# The wreck appears only now, so idle Haulers cannot clear it first.
		func(x: SimWorld) -> void:
			var wreck: SimEntity = x.spawn_wreck(wreck_at, 150, 1.2, "bulwark", 0.6)
			wreck.decay_tick = 1 << 40
			x.tutorial.memo["wreck"] = wreck.id
	)
	_add(
		"Collect another 500 salvage.",
		"More Haulers and a Depot closer to a field both speed this up.",
		func(x: SimWorld) -> bool: return x.players[PLAYER].stat_salvage_collected >= x.tutorial.memo.get("collected", 0) + 500,
		Vector2.INF,
		func(x: SimWorld) -> void: x.tutorial.memo["collected"] = x.players[PLAYER].stat_salvage_collected
	)


# ----------------------------------------------------------------- signal

func _setup_signal(w: SimWorld) -> void:
	var me: SimPlayer = w.players[PLAYER]
	me.salvage = 1500
	var hq: SimEntity = _hq(w, PLAYER)
	var enemy_hq: SimEntity = _hq(w, ENEMY)
	var toward: Vector2 = (enemy_hq.pos - hq.pos).normalized()
	# The player's strike force.
	for i: int in 3:
		w.spawn_unit("bulwark", PLAYER, w.map.nearest_free_pos(hq.pos + toward * 12.0 + toward.rotated(PI * 0.5) * (float(i) * 3.0 - 3.0)))
	# An enemy outpost fed by a two-relay chain from their HQ.
	var back: Vector2 = -toward
	var relay_a_at: Vector2 = enemy_hq.pos + back * 24.0
	var relay_b_at: Vector2 = enemy_hq.pos + back * 44.0
	_flatten(w, relay_a_at, 3)
	_flatten(w, relay_b_at, 5)
	var relay_a: SimEntity = w.spawn_building("relay", ENEMY, w.map.cell_of(relay_a_at), true)
	w.spawn_building("relay", ENEMY, w.map.cell_of(relay_b_at), true)
	var turrets: Array[SimEntity] = []
	for k: int in 2:
		var side: Vector2 = toward.rotated(PI * 0.5) * (5.0 if k == 0 else -5.0)
		turrets.append(w.spawn_building("sentry_turret", ENEMY, w.map.cell_of(relay_b_at + side + back * 3.0), true))
	var relay_a_id: int = relay_a.id
	var turret_count: int = turrets.size()
	# The enemy's own garrison stays at home.
	var garrison: Array[SimEntity] = []
	for e: SimEntity in w.entities:
		if e.owner == ENEMY and e.kind == SimEntity.Kind.UNIT:
			garrison.append(e)
	_hold(w, garrison)
	# The player has scouted the outpost already.
	w.add_reveal(relay_a_at, 12.0, PLAYER, -1)
	w.add_reveal(relay_b_at, 14.0, PLAYER, -1)
	SimSignal.recompute(w)
	SimVision.recompute(w)

	_add(
		"The tinted ground is your signal coverage. Units inside it are Linked. Move a unit outside it and watch it go Dark.",
		"Select a Trooper and right-click beyond the edge of the tint. Dark units fire and see about a third worse.",
		func(x: SimWorld) -> bool:
			for e: SimEntity in x.entities:
				if e.alive and e.owner == PLAYER and e.kind == SimEntity.Kind.UNIT and not e.linked:
					return true
			return false
	)
	_add(
		"Relays extend coverage, but only while they are chained back to the Headquarters. Build a Relay towards the enemy.",
		"Select a Field Engineer, press R and place it near the edge of your coverage.",
		func(x: SimWorld) -> bool: return SimTutorial._linked_relays(x) >= 1,
		hq.pos + toward * 28.0
	)
	_add(
		"Chain a second Relay beyond the first. Blue lines show the links.",
		"It must be within link range of a relay that is itself linked.",
		func(x: SimWorld) -> bool: return SimTutorial._linked_relays(x) >= 2,
		hq.pos + toward * 46.0  # close to the outpost, but outside its turrets' reach
	)
	_add(
		"The enemy outpost ahead is fed by a chain of two relays. Destroy the one nearer their base to cut it.",
		"Take your Bulwarks around the outpost's turrets and attack the relay behind them (right-click it).",
		func(x: SimWorld) -> bool: return x.get_entity(relay_a_id) == null,
		relay_a_at
	)
	_add(
		"The outpost's relay is unlinked now, so its turrets are Dark and fire at half rate. Destroy one.",
		"Dark buildings show a red no-signal icon.",
		func(x: SimWorld) -> bool: return SimTutorial._count(x, ENEMY, "sentry_turret") < turret_count,
		relay_b_at
	)


static func _linked_relays(w: SimWorld) -> int:
	var n: int = 0
	for e: SimEntity in w.entities:
		if e.alive and e.owner == PLAYER and e.def != null and e.def.id == "relay" and e.constructed and e.linked:
			n += 1
	return n


# ------------------------------------------------------------- directives

func _setup_directives(w: SimWorld) -> void:
	var me: SimPlayer = w.players[PLAYER]
	me.command_points = 12
	var hq: SimEntity = _hq(w, PLAYER)
	var enemy_hq: SimEntity = _hq(w, ENEMY)
	var toward: Vector2 = (enemy_hq.pos - hq.pos).normalized()
	# Damaged tanks waiting for repair.
	var tank_at: Vector2 = w.map.nearest_free_pos(hq.pos + toward.rotated(-0.9) * 13.0)
	for i: int in 3:
		var tank: SimEntity = w.spawn_unit("bulwark", PLAYER, w.map.nearest_free_pos(tank_at + Vector2(float(i) * 2.8, 0.0)))
		tank.hp = tank.max_hp * 0.3
	# An enemy squad dug in just beyond the player's coverage.
	var squad_at: Vector2 = hq.pos + toward * 38.0
	_flatten(w, squad_at, 4)
	var squad: Array[SimEntity] = []
	for i: int in 6:
		squad.append(w.spawn_unit("trooper", ENEMY, squad_at + Vector2(float(i % 3) * 1.6 - 1.6, float(i / 3) * 1.6)))
	squad.append(w.spawn_unit("warden", ENEMY, squad_at + Vector2(-3.0, 3.5)))
	squad.append(w.spawn_unit("warden", ENEMY, squad_at + Vector2(3.0, 3.5)))
	for e: SimEntity in w.entities:
		if e.owner == ENEMY and e.kind == SimEntity.Kind.UNIT:
			squad.append(e)
	_hold(w, squad)

	_add(
		"Destroying enemy units and buildings earns Command Points (CP). You have 12. Unlock Recon Sweep.",
		"Click Recon Sweep on the bar above the command card, or press Alt+1.",
		func(x: SimWorld) -> bool: return x.players[PLAYER].unlocked.has("recon_sweep")
	)
	_add(
		"An enemy squad is hiding beyond your coverage. Use Recon Sweep on the marked area to reveal it.",
		"Click Recon Sweep again (or Alt+1), then click the ground. Right-click cancels.",
		func(x: SimWorld) -> bool: return SimTutorial._used(x, "recon_sweep"),
		squad_at
	)
	_add(
		"Unlock Shell Barrage and fire it on the squad.",
		"A barrage must land inside your coverage or within 15 of it: the ring turns red where it cannot.",
		func(x: SimWorld) -> bool: return SimTutorial._used(x, "shell_barrage"),
		squad_at
	)
	_add(
		"Your Bulwarks are badly damaged. Unlock Field Repair and use it on them.",
		"Field Repair only works inside your own coverage.",
		func(x: SimWorld) -> bool: return SimTutorial._used(x, "field_repair"),
		tank_at
	)
	_add(
		"Unlock Signal Surge and use it. Every emitter reaches half again as far for 30 seconds.",
		"Signal Surge needs no target. Watch the tinted area grow.",
		func(x: SimWorld) -> bool: return SimTutorial._used(x, "signal_surge")
	)
