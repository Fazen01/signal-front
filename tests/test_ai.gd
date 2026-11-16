extends TestCase
## Skirmish AI behaviour and win/lose rules.


func _has(w: SimWorld, owner: int, def_id: String, finished: bool) -> int:
	var n: int = 0
	for e: SimEntity in w.entities:
		if e.alive and e.owner == owner and e.def != null and e.def.id == def_id and (e.constructed or not finished):
			n += 1
	return n


func test_ai_builds_a_base_and_army() -> void:
	var w: SimWorld = SimSetup.create_match(MatchConfig.ai_vs_ai(11))
	w.collect_events = false
	SimTestUtil.run(w, 20 * 150)
	for p: SimPlayer in w.players:
		check(_has(w, p.id, "barracks", true) >= 1, "%s built a barracks" % p.name)
		check(_has(w, p.id, "relay", true) >= 1, "%s extended its network with a relay" % p.name)
		check(p.bandwidth_cap >= 30, "%s raised its bandwidth cap" % p.name)
		check(p.stat_salvage_collected > 1000, "%s is harvesting (%d)" % [p.name, p.stat_salvage_collected])
		check(p.stat_units_built >= 5, "%s trained units (%d)" % [p.name, p.stat_units_built])
		var army: int = 0
		for e: SimEntity in w.entities:
			if e.alive and e.owner == p.id and e.kind == SimEntity.Kind.UNIT and e.def.is_armed():
				army += 1
		check(army >= 4 or p.stat_units_lost > 0, "%s fields an army" % p.name)


func test_ai_only_builds_inside_its_network() -> void:
	var w: SimWorld = SimSetup.create_match(MatchConfig.ai_vs_ai(12))
	w.collect_events = false
	var bad: int = 0
	for i: int in 20 * 150:
		w.tick()
		if i % 100 == 0:
			for e: SimEntity in w.entities:
				if e.alive and e.kind == SimEntity.Kind.BUILDING and not e.def.signal_root and e.def.signal_radius <= 0.0:
					if not e.linked and w.tick_count - e.last_hit_tick > 2000 and e.constructed:
						# A Dark non-relay building is only legitimate after a relay was lost.
						if w.players[e.owner].stat_buildings_lost == 0:
							bad += 1
	check_eq(bad, 0, "no building was ever placed outside coverage")


func test_ai_match_is_deterministic() -> void:
	var a: SimWorld = SimSetup.create_match(MatchConfig.ai_vs_ai(21))
	var b: SimWorld = SimSetup.create_match(MatchConfig.ai_vs_ai(21))
	a.collect_events = false
	b.collect_events = false
	SimTestUtil.run(a, 20 * 100)
	SimTestUtil.run(b, 20 * 100)
	check_eq(a.state_hash(), b.state_hash(), "same seed gives the same match")
	check_eq(a.entities.size(), b.entities.size(), "same entity count")


func test_losing_the_hq_loses_the_match() -> void:
	var w: SimWorld = SimSetup.create_match(MatchConfig.skirmish(3))
	var hq: SimEntity = null
	for e: SimEntity in w.entities:
		if e.owner == 1 and e.def != null and e.def.signal_root:
			hq = e
	check(hq != null, "enemy HQ exists")
	SimCombat.kill(w, hq, null, 0)
	w.events.clear()
	SimTestUtil.run(w, 12)
	check(w.players[1].defeated, "player without an HQ is defeated")
	check(w.game_over, "match is over")
	check_eq(w.winner, 0, "the other player wins")
	check_eq(w.count_units(1), 0, "the loser's units are destroyed")
	var announced: bool = false
	for ev: SimEvent in w.events:
		if ev.type == SimEvent.Type.MATCH_OVER and ev.player == 0:
			announced = true
	check(announced, "MATCH_OVER event names the winner")
	var tick: int = w.tick_count
	SimTestUtil.run(w, 5)
	check_eq(w.tick_count, tick + 5, "the world keeps ticking safely after the end")


func test_surrender() -> void:
	var w: SimWorld = SimSetup.create_match(MatchConfig.skirmish(3))
	w.push_command(SimCommand.surrender(0))
	SimTestUtil.run(w, 12)
	check(w.players[0].defeated, "surrendering player is defeated")
	check_eq(w.winner, 1, "opponent wins")


func test_difficulty_changes_tempo_not_income() -> void:
	var easy: SimAI = SimAI.new(1, 0, 5)
	var hard: SimAI = SimAI.new(1, 2, 5)
	check(easy.think_ticks > hard.think_ticks, "easy thinks slower")
	check(easy.wave_cooldown_ticks > hard.wave_cooldown_ticks, "easy attacks less often")
	var w: SimWorld = SimSetup.create_match(MatchConfig.skirmish(9, 2))
	check_eq(w.players[0].salvage, w.players[1].salvage, "hard AI starts with the same salvage as the player")


func test_doctrines_come_from_the_seed() -> void:
	var seen: Dictionary[String, int] = {}
	for seed_value: int in range(1, 41):
		var ai: SimAI = SimAI.new(1, 1, seed_value)
		seen[ai.doctrine] = int(seen.get(ai.doctrine, 0)) + 1
		check_eq(SimAI.new(1, 1, seed_value).doctrine, ai.doctrine, "seed %d always gives the same doctrine" % seed_value)
		check(SimAI.DOCTRINES.has(ai.doctrine), "%s is a known doctrine" % ai.doctrine)
	for d: String in SimAI.DOCTRINES:
		check(int(seen.get(d, 0)) >= 3, "%s turns up among 40 seeds (%d times)" % [d, int(seen.get(d, 0))])
	var easy: SimAI = SimAI.new(1, 0, 7)
	check_eq(easy.doctrine, "balanced", "an Easy AI has no doctrine")
	check(not easy.retreats and not easy.scouts, "and neither retreats nor scouts")
	var plain: SimAI = SimAI.new(1, 1, 1)
	for seed_value: int in range(1, 41):
		var ai: SimAI = SimAI.new(1, 1, seed_value)
		if ai.doctrine == "aggressor":
			check(ai.wave_cooldown_ticks < 20 * 60 and ai.first_wave < 7, "an aggressor attacks sooner and more often")
		elif ai.doctrine == "fortifier":
			check(ai.max_turrets > plain.max_turrets or plain.doctrine == "fortifier", "a fortifier builds more turrets")
		elif ai.doctrine == "raider":
			check(ai.raids, "a raider raids")


## A skirmish with the AI's wave already out in the middle of the map.
func _wave_world(survivors: int, launched: int) -> SimWorld:
	var w: SimWorld = SimSetup.create_match(MatchConfig.skirmish(11))
	w.collect_events = false
	var ai: SimAI = w.ais[0]
	var mid: Vector2 = w.map.nearest_free_pos(w.map.world_size() * 0.5)
	var wave: Array[SimEntity] = SimTestUtil.spawn_group(w, "trooper", ai.player_id, mid, survivors)
	ai.wave_ids.clear()
	for e: SimEntity in wave:
		ai.wave_ids.append(e.id)
	ai.wave_state = SimAI.Wave.ASSAULT
	ai.wave_target_pos = mid
	ai.wave_launch_power = launched * w.data.entity("trooper").cost
	ai.retreats = true
	return w


func test_a_beaten_wave_retreats() -> void:
	var w: SimWorld = _wave_world(4, 12)
	var ai: SimAI = w.ais[0]
	var mid: Vector2 = w.map.world_size() * 0.5
	SimTestUtil.spawn_group(w, "bulwark", 0, w.map.nearest_free_pos(mid + Vector2(7.0, 0.0)), 4)
	w.tick()
	ai._f = w.players[ai.player_id].faction
	ai._survey(w)
	check(ai._should_retreat(w), "four troopers left of twelve, facing four tanks: retreat")
	var home: Vector2 = w.players[ai.player_id].start_pos
	var before: float = 0.0
	for id: int in ai.wave_ids:
		before += w.get_entity(id).pos.distance_to(home)
	var ids: Array[int] = ai.wave_ids.duplicate()
	ai.next_think = 0
	SimTestUtil.run(w, 20 * 6)
	check_eq(ai.retreats_made, 1, "the AI called the wave home")
	check(ai.wave_state == SimAI.Wave.NONE, "and the wave is over")
	var after: float = 0.0
	var alive: int = 0
	for id: int in ids:
		var e: SimEntity = w.get_entity(id)
		if e != null:
			alive += 1
			after += e.pos.distance_to(home)
	check(alive > 0, "some of it got away (%d)" % alive)
	check(alive == 0 or after / float(alive) < before / float(ids.size()), "and is heading home")


func test_a_wave_that_is_winning_presses_on() -> void:
	var strong: SimWorld = _wave_world(10, 12)
	var ai: SimAI = strong.ais[0]
	var mid: Vector2 = strong.map.world_size() * 0.5
	SimTestUtil.spawn_group(strong, "bulwark", 0, strong.map.nearest_free_pos(mid + Vector2(7.0, 0.0)), 4)
	strong.tick()
	ai._f = strong.players[ai.player_id].faction
	ai._survey(strong)
	check(not ai._should_retreat(strong), "a wave still near full strength fights on")
	var weak_enemy: SimWorld = _wave_world(4, 12)
	var ai2: SimAI = weak_enemy.ais[0]
	SimTestUtil.spawn_group(weak_enemy, "trooper", 0, weak_enemy.map.nearest_free_pos(mid + Vector2(7.0, 0.0)), 1)
	weak_enemy.tick()
	ai2._f = weak_enemy.players[ai2.player_id].faction
	ai2._survey(weak_enemy)
	check(not ai2._should_retreat(weak_enemy), "a battered wave that still outguns what it faces fights on")
	# An AI that has already pulled back as often as it may commits instead.
	var spent: SimWorld = _wave_world(4, 12)
	var ai3: SimAI = spent.ais[0]
	SimTestUtil.spawn_group(spent, "bulwark", 0, spent.map.nearest_free_pos(mid + Vector2(7.0, 0.0)), 4)
	spent.tick()
	ai3._f = spent.players[ai3.player_id].faction
	ai3._survey(spent)
	check(ai3._should_retreat(spent), "the same beaten wave would retreat")
	ai3.retreats_made = ai3.max_retreats
	check(not ai3._should_retreat(spent), "but not once the AI has used up its retreats")
	ai2.retreats = false
	check(ai2.wave_state == SimAI.Wave.ASSAULT, "and stays in the assault")


## How far the fastest wave unit gets ahead of the troopers in ten seconds
## of an assault across the map, with the AI's orders given once a second.
func _lead_after_ten_seconds(together: bool) -> float:
	var w: SimWorld = SimSetup.create_match(MatchConfig.skirmish(11))
	w.collect_events = false
	var ai: SimAI = w.ais[0]
	ai.next_think = 1 << 40  # only the assault orders below, no other thinking
	ai.keeps_together = together
	var home: Vector2 = w.players[ai.player_id].start_pos
	var enemy: Vector2 = w.players[0].start_pos
	var at: Vector2 = w.map.nearest_free_pos(home + (enemy - home).normalized() * 14.0)
	var slow: Array[SimEntity] = SimTestUtil.spawn_group(w, "trooper", ai.player_id, at, 6)
	var fast: Array[SimEntity] = SimTestUtil.spawn_group(w, "kestrel", ai.player_id, at, 2)
	ai.wave_ids.clear()
	for e: SimEntity in slow + fast:
		ai.wave_ids.append(e.id)
	ai.wave_state = SimAI.Wave.ASSAULT
	ai.wave_target = 0
	ai.wave_target_pos = enemy
	ai.wave_tick = w.tick_count
	ai._f = w.players[ai.player_id].faction
	var worst: float = 0.0
	for second: int in 10:
		ai._survey(w)
		ai._assault(w, second == 0)
		SimTestUtil.run(w, 20)
		var body: float = 0.0
		for e: SimEntity in slow:
			body += e.pos.distance_to(enemy) / float(slow.size())
		for e: SimEntity in fast:
			worst = maxf(worst, body - e.pos.distance_to(enemy))
	return worst


func test_a_wave_keeps_together_on_the_way_in() -> void:
	var loose: float = _lead_after_ten_seconds(false)
	var tight: float = _lead_after_ten_seconds(true)
	check(loose > 25.0, "left alone, gunships run far ahead of the infantry (%.1f)" % loose)
	check(tight < SimAI.LEASH_LEAD + 9.0, "kept together, they wait for it (%.1f ahead at most)" % tight)


func test_the_ai_keeps_a_scout_out() -> void:
	var w: SimWorld = SimSetup.create_match(MatchConfig.skirmish(11))
	w.collect_events = false
	var ai: SimAI = w.ais[0]
	var home: Vector2 = w.players[ai.player_id].start_pos
	var car: SimEntity = w.spawn_unit("courser", ai.player_id, w.map.nearest_free_pos(home + Vector2(-8.0, -8.0)))
	SimTestUtil.run(w, 20 * 20)
	check_eq(ai.scouts_sent, 1, "the AI made its scout car its scout")
	check_eq(ai._scout_id, car.id, "and remembers which unit it is")
	check(car.pos.distance_to(home) > 25.0, "the scout has left the base (%.0f away)" % car.pos.distance_to(home))
	var first_leg: int = ai._scout_leg
	SimTestUtil.run(w, 20 * 90)
	check(not car.alive or ai._scout_leg != first_leg, "it moves on from one place to the next")
	check(not ai.wave_ids.has(car.id), "and is never drafted into a wave")
	var easy: SimWorld = SimSetup.create_match(MatchConfig.skirmish(11, 0))
	easy.collect_events = false
	var lazy: SimAI = easy.ais[0]
	easy.spawn_unit("courser", lazy.player_id, easy.map.nearest_free_pos(easy.players[lazy.player_id].start_pos + Vector2(-8.0, -8.0)))
	SimTestUtil.run(easy, 20 * 20)
	check_eq(lazy.scouts_sent, 0, "an Easy AI does not scout")
