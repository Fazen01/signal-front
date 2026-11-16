extends TestCase
## Every tutorial mission can be completed by doing what its objectives say.

const P: int = SimTutorial.PLAYER


func _world(id: String) -> SimWorld:
	var w: SimWorld = SimSetup.create_match(SimTutorial.config_for(id))
	w.collect_events = false
	return w


func _own(w: SimWorld, def_id: String) -> Array[SimEntity]:
	var out: Array[SimEntity] = []
	for e: SimEntity in w.entities:
		if e.alive and e.owner == P and e.def != null and e.def.id == def_id:
			out.append(e)
	return out


## Runs until the mission reaches `step` (or is done), at most `seconds`.
func _run_to(w: SimWorld, step: int, seconds: int) -> bool:
	for i: int in seconds * 20:
		if w.tutorial.done or w.tutorial.index >= step:
			return true
		w.tick()
	return w.tutorial.done or w.tutorial.index >= step


## A legal cell for `def_id` as near as possible to `around`.
func _cell_near(w: SimWorld, def_id: String, around: Vector2) -> Vector2i:
	var def: EntityDef = w.data.entity(def_id)
	var c0: Vector2i = w.map.cell_of(around)
	for r: int in range(0, 14):
		for dy: int in range(-r, r + 1):
			for dx: int in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) == r and SimEconomy.can_place(w, P, def, c0 + Vector2i(dx, dy)):
					return c0 + Vector2i(dx, dy)
	return Vector2i(-1, -1)


func test_missions_are_listed() -> void:
	check_eq(SimTutorial.IDS.size(), 3, "three missions")
	for id: String in SimTutorial.IDS:
		check(SimTutorial.TITLES.has(id) and SimTutorial.BLURBS.has(id), "%s has a title and blurb" % id)
		var w: SimWorld = _world(id)
		check(w.tutorial != null and w.tutorial.steps.size() >= 4, "%s has objectives" % id)
		check(not w.victory_enabled, "%s cannot be lost by accident" % id)
		for s: SimTutorial.Step in w.tutorial.steps:
			check(s.text.length() > 20 and s.hint.length() > 10, "%s: every objective has text and a hint" % id)
		SimTutorial_run_idle(w)
		check_eq(w.tutorial.index, 0, "%s: nothing completes on its own in the first seconds" % id)


func SimTutorial_run_idle(w: SimWorld) -> void:
	for i: int in 60:
		w.tick()


func test_economy_mission_can_be_completed() -> void:
	var w: SimWorld = _world("economy")
	var hq: SimEntity = _own(w, "hq")[0]
	var engineers: Array[SimEntity] = _own(w, "field_engineer")
	w.push_command(SimCommand.train(P, hq.id, "hauler"))
	check(_run_to(w, 1, 30), "step 1: train a hauler")
	w.push_command(SimCommand.build(P, PackedInt32Array([engineers[0].id]), "barracks", _cell_near(w, "barracks", hq.pos + Vector2(14, 0))))
	check(_run_to(w, 2, 60), "step 2: build a barracks")
	var barracks: SimEntity = _own(w, "barracks")[0]
	for i: int in 3:
		w.push_command(SimCommand.train(P, barracks.id, "trooper"))
	check(_run_to(w, 3, 60), "step 3: train three troopers")
	w.push_command(SimCommand.build(P, PackedInt32Array([engineers[1].id]), "relay", _cell_near(w, "relay", hq.pos + Vector2(0, 16))))
	check(_run_to(w, 4, 60), "step 4: build a relay")
	SimTestUtil.run(w, 10)  # the wreck appears when its objective begins
	var wreck_at: Vector2 = w.tutorial.current().marker
	var wreck: SimEntity = null
	for e: SimEntity in w.entities:
		if e.kind == SimEntity.Kind.WRECK and e.pos.distance_to(wreck_at) < 1.0:
			wreck = e
	check(wreck != null, "the marker points at the wreck")
	if wreck != null:
		w.push_command(SimCommand.harvest(P, PackedInt32Array([_own(w, "hauler")[0].id]), wreck.id))
	check(_run_to(w, 5, 90), "step 5: salvage the wreck")
	check(_run_to(w, 6, 240), "step 6: collect another 500 salvage")
	check(w.tutorial.done, "economy mission complete")


func test_signal_mission_can_be_completed() -> void:
	var w: SimWorld = _world("signal")
	var hq: SimEntity = _own(w, "hq")[0]
	var engineers: Array[SimEntity] = _own(w, "field_engineer")
	var trooper: SimEntity = _own(w, "trooper")[0]
	var out: Vector2 = hq.pos + (w.map.world_size() * 0.5 - hq.pos).normalized() * 36.0
	w.push_command(SimCommand.move(P, PackedInt32Array([trooper.id]), w.map.nearest_free_pos(out)))
	check(_run_to(w, 1, 40), "step 1: a unit goes Dark outside coverage")
	var first: Vector2i = _cell_near(w, "relay", w.tutorial.current().marker)
	w.push_command(SimCommand.build(P, PackedInt32Array([engineers[0].id]), "relay", first))
	check(_run_to(w, 2, 80), "step 2: first relay linked")
	var second: Vector2i = _cell_near(w, "relay", w.tutorial.current().marker)
	check(second.x >= 0, "a second relay can be placed further out")
	w.push_command(SimCommand.build(P, PackedInt32Array([engineers[1].id]), "relay", second))
	check(_run_to(w, 3, 100), "step 3: second relay linked")
	var tanks: PackedInt32Array = SimTestUtil.ids_of(_own(w, "bulwark"))
	var target_at: Vector2 = w.tutorial.current().marker
	var relay: SimEntity = null
	var turret: SimEntity = null
	for e: SimEntity in w.entities:
		if e.owner == SimTutorial.ENEMY and e.def != null:
			if e.def.id == "relay" and e.pos.distance_to(target_at) < 3.0:
				relay = e
			if e.def.id == "sentry_turret":
				turret = e
	check(relay != null and turret != null, "the enemy outpost exists")
	if relay == null or turret == null:
		return
	check(turret.linked, "the outpost's turrets are Linked before the cut")
	w.push_command(SimCommand.attack(P, tanks, relay.id))
	check(_run_to(w, 4, 200), "step 4: the mid-chain relay is destroyed")
	SimTestUtil.run(w, 12)
	check(not turret.linked, "the outpost's turrets go Dark when the chain is cut")
	w.push_command(SimCommand.attack(P, tanks, turret.id))
	check(_run_to(w, 5, 200), "step 5: a Dark turret is destroyed")
	check(w.tutorial.done, "signal mission complete")


func test_directives_mission_can_be_completed() -> void:
	var w: SimWorld = _world("directives")
	check_eq(w.players[P].command_points, 12, "the mission grants Command Points")
	var squad_at: Vector2 = w.tutorial.steps[1].marker
	check(not SimVision.is_visible(w, P, squad_at), "the enemy squad starts hidden")
	w.push_command(SimCommand.unlock(P, "recon_sweep"))
	check(_run_to(w, 1, 5), "step 1: unlock Recon Sweep")
	w.push_command(SimCommand.directive(P, "recon_sweep", squad_at))
	check(_run_to(w, 2, 5), "step 2: use Recon Sweep")
	check(SimVision.is_visible(w, P, squad_at), "the squad is revealed")
	var enemies_before: int = w.count_units(SimTutorial.ENEMY)
	w.push_command(SimCommand.unlock(P, "shell_barrage"))
	SimTestUtil.run(w, 3)
	check_eq(SimDirectives.target_error(w, P, w.data.directive("shell_barrage"), squad_at), "", "the squad is close enough to coverage to barrage")
	w.push_command(SimCommand.directive(P, "shell_barrage", squad_at))
	check(_run_to(w, 3, 5), "step 3: fire Shell Barrage")
	SimTestUtil.run(w, 20 * 7)
	check(w.count_units(SimTutorial.ENEMY) < enemies_before, "the barrage kills some of the squad")
	var tanks: Array[SimEntity] = _own(w, "bulwark")
	var hp_before: float = tanks[0].hp
	w.push_command(SimCommand.unlock(P, "field_repair"))
	SimTestUtil.run(w, 3)
	w.push_command(SimCommand.directive(P, "field_repair", w.tutorial.current().marker))
	check(_run_to(w, 4, 5), "step 4: use Field Repair")
	check(tanks[0].hp > hp_before + 100.0, "the damaged tanks are repaired")
	w.push_command(SimCommand.unlock(P, "signal_surge"))
	SimTestUtil.run(w, 3)
	w.push_command(SimCommand.directive(P, "signal_surge", Vector2.ZERO))
	check(_run_to(w, 5, 5), "step 5: use Signal Surge")
	check(w.tutorial.done, "directives mission complete")
