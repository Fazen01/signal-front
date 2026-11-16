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


func _army_of(w: SimWorld, owner: int) -> int:
	var n: int = 0
	for e: SimEntity in w.entities:
		if e.alive and e.owner == owner and e.kind == SimEntity.Kind.UNIT and e.def.is_armed():
			n += 1
	return n


func test_ai_leaves_the_opening_alone_and_keeps_a_guard() -> void:
	var w: SimWorld = SimSetup.create_match(MatchConfig.ai_vs_ai(11))
	w.collect_events = false
	var ai: SimAI = w.ais[0]
	SimTestUtil.run(w, ai.first_attack_tick - 20)
	for other: SimAI in w.ais:
		check_eq(other.waves_sent, 0, "no attack wave before the opening is over")
	# Play on to the first wave: part of the army has to stay behind.
	var limit: int = 20 * 60 * 12
	while ai.waves_sent == 0 and w.tick_count < limit and not w.game_over:
		w.tick()
	check(ai.waves_sent == 1, "the first wave leaves once the opening is over")
	var army: int = _army_of(w, ai.player_id)
	check(ai.wave_ids.size() >= 3, "the wave is a real force (%d)" % ai.wave_ids.size())
	check(army - ai.wave_ids.size() >= 2, "a guard stays home (%d of %d left)" % [ai.wave_ids.size(), army])


func test_ai_avoids_a_spot_where_its_site_was_destroyed() -> void:
	var w: SimWorld = SimSetup.create_match(MatchConfig.ai_vs_ai(12))
	w.collect_events = false
	SimTestUtil.run(w, 60)
	var ai: SimAI = w.ais[0]
	var spot: Vector2 = w.players[0].start_pos + Vector2(10.0, 0.0)
	check(ai._site_is_safe(w, spot), "an untouched spot is fine")
	ai._lost_spots.append(Vector3(spot.x, spot.y, float(w.tick_count)))
	check(not ai._site_is_safe(w, spot + Vector2(3.0, 0.0)), "not next to a site that was just shot down")
	check(ai._site_is_safe(w, spot + Vector2(30.0, 0.0)), "further away is fine")
	ai._lost_spots[0].z = float(w.tick_count - SimAI.SITE_AVOID_TICKS - 1)
	check(ai._site_is_safe(w, spot + Vector2(3.0, 0.0)), "and the spot is usable again later")
	# A visible armed enemy next to the spot rules it out as well.
	w.spawn_unit("trooper", 1, spot + Vector2(4.0, 0.0))
	SimTestUtil.run(w, 40)
	check(not ai._site_is_safe(w, spot), "not under enemy guns")


func test_ai_build_order_skips_what_it_cannot_place() -> void:
	var w: SimWorld = SimSetup.create_match(MatchConfig.ai_vs_ai(13))
	w.collect_events = false
	SimTestUtil.run(w, 20 * 60)
	var ai: SimAI = w.ais[0]
	var me: SimPlayer = w.players[0]
	me.salvage = 5000
	var first: String = ai._next_building(w, me)
	check(first != "", "the AI wants a building")
	ai._blocked_until[first] = w.tick_count + 1000
	var second: String = ai._next_building(w, me)
	check(second != first, "a blocked building does not hold up the build order (%s then %s)" % [first, second])
	ai._blocked_until[first] = w.tick_count
	check_eq(ai._next_building(w, me), first, "and it is tried again once the block runs out")


func test_loading_time_follows_the_load() -> void:
	var data: GameData = GameData.shared()
	check(data.harvest_seconds >= 8.0, "loading is slow enough for salvage to matter (%.1f s per 100)" % data.harvest_seconds)
	var w: SimWorld = SimSetup.create_match(MatchConfig.ai_vs_ai(14))
	w.collect_events = false
	# Watch the first hauler through one whole loading spell.
	var hauler: SimEntity = null
	for e: SimEntity in w.entities:
		if e.owner == 0 and e.def != null and e.def.harvester:
			hauler = e
			break
	check(hauler != null, "there is a hauler")
	var loading: int = 0
	for i: int in 20 * 90:
		w.tick()
		if hauler.alive and hauler.job == SimEconomy.Job.LOADING:
			loading += 1
		elif loading > 0:
			break
	var expected: int = int(data.harvest_seconds * 20.0 * float(hauler.def.capacity) / 100.0)
	check(absi(loading - expected) <= 2, "a full load takes harvest_seconds per 100 salvage (%d ticks, expected %d)" % [loading, expected])
