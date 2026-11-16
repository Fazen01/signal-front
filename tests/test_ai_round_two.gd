extends TestCase
## The AI's second round: it plays to its faction's rule, comes at a base
## from two sides, helps its allies and rebuilds what it loses.


func _match(factions: Array[String], teams: Array[int], ai: Array[bool], seed_value: int = 7) -> SimWorld:
	var config: MatchConfig = MatchConfig.skirmish(seed_value)
	config.factions.clear()
	config.is_ai.clear()
	config.ai_levels.clear()
	config.names.clear()
	for i: int in factions.size():
		config.factions.append(factions[i])
		config.is_ai.append(ai[i])
		config.ai_levels.append(1)
		config.names.append("Seat %d" % (i + 1))
		if not teams.is_empty():
			config.set_team(i, teams[i])
	var w: SimWorld = SimSetup.create_match(config)
	w.collect_events = false
	return w


func _count(w: SimWorld, owner: int, def_id: String) -> int:
	var n: int = 0
	for e: SimEntity in w.entities:
		if e.alive and e.owner == owner and e.def != null and e.def.id == def_id and e.constructed:
			n += 1
	return n


func test_each_ai_plays_to_its_factions_rule() -> void:
	var w: SimWorld = _match(["veil", "tally", "bracken", "zephyr"], [], [true, true, true, true])
	var plain: SimAI = SimAI.new(0, 1, 7)
	SimTestUtil.run(w, 15)
	var veil: SimAI = w.ais[0]
	var tally: SimAI = w.ais[1]
	var bracken: SimAI = w.ais[2]
	var zephyr: SimAI = w.ais[3]
	check(veil.ambushes, "the Veil lies in wait")
	check(not tally.ambushes and not bracken.ambushes, "the others do not")
	check(tally.raids, "the Tally raids for its bounties")
	check(bracken.retreat_share > plain.retreat_share, "the Brackenfold pulls back sooner (%.1f)" % bracken.retreat_share)
	check(bracken.max_retreats >= 3, "and more often (%d)" % bracken.max_retreats)
	check(zephyr.strikes, "the Accord strikes from the air")
	check(not veil.strikes and not tally.strikes and not bracken.strikes, "factions without an air arm do not")
	# An Easy AI plays every faction the same plain way.
	var easy: SimWorld = _match(["veil", "zephyr"], [], [true, true])
	for ai: SimAI in easy.ais:
		ai.level = 0
	SimTestUtil.run(easy, 15)
	check(not easy.ais[0].ambushes and not easy.ais[1].strikes, "an Easy AI has no tricks")


func test_the_veil_waits_at_its_forward_relay() -> void:
	var w: SimWorld = _match(["veil", "aegis"], [], [true, true], 3)
	var ai: SimAI = w.ais[0]
	var hq: Vector2 = w.players[0].start_pos
	var seen_forward: bool = false
	var hidden: int = 0
	for step: int in 9 * 60:
		SimTestUtil.run(w, 20)
		if ai.wave_state != SimAI.Wave.NONE or ai._hq == null:
			continue
		var out: int = 0
		var idle: int = 0
		hidden = 0
		for e: SimEntity in ai._army:
			if e.orders.is_empty() and e.id != ai._scout_id:
				idle += 1
				if e.pos.distance_to(hq) > 16.0:
					out += 1
					if SimVision.is_stealthed(w, e):
						hidden += 1
		if idle >= 4 and out * 2 >= idle and hidden >= 2:
			seen_forward = true
			break
	check(seen_forward, "its idle army gathers out at a relay, not at the headquarters")
	check(hidden >= 2, "and cannot be seen there (%d hidden)" % hidden)


func test_the_accord_strikes_relays_from_the_air() -> void:
	var w: SimWorld = _match(["zephyr", "aegis"], [], [true, true], 7)
	var ai: SimAI = w.ais[0]
	var limit: int = 20 * 60 * 16
	while w.tick_count < limit and ai.strikes_sent == 0 and not w.game_over:
		w.tick()
	check(ai.strikes_sent >= 1, "its aircraft are sent at a relay or depot between waves (by %d min)" % int(w.seconds() / 60.0))


func test_waves_come_from_different_sides() -> void:
	var w: SimWorld = _match(["aegis", "foundry"], [], [true, true], 1)
	var straight: Vector2 = Vector2.ZERO
	var round_side: Vector2 = Vector2.ZERO
	var whole: bool = true
	var limit: int = 20 * 60 * 20
	var ai: SimAI = w.ais[0]
	var last_wave: int = 0
	while w.tick_count < limit and (straight == Vector2.ZERO or round_side == Vector2.ZERO) and not w.game_over:
		w.tick()
		if ai.wave_state == SimAI.Wave.STAGING and ai.waves_sent != last_wave:
			last_wave = ai.waves_sent
			if ai.wave_side == 0:
				straight = ai.wave_stage
			else:
				round_side = ai.wave_stage
				# The wave goes round as one: everybody is sent to the same place.
				for id: int in ai.wave_ids:
					var e: SimEntity = w.get_entity(id)
					if e != null and not e.orders.is_empty() and e.orders[0].pos.distance_to(ai.wave_stage) > 12.0:
						whole = false
	check(straight != Vector2.ZERO, "some waves take the straight road")
	check(round_side != Vector2.ZERO, "and some come round the side (by %d min)" % int(w.seconds() / 60.0))
	check(whole, "a wave that goes round stays together")
	check(ai.flanks_sent >= 1, "the AI counts them")


func test_an_ai_comes_to_its_allys_aid() -> void:
	# Seat one is a person, seat two an allied AI, seat three the enemy.
	var w: SimWorld = _match(["aegis", "foundry", "nomad"], [0, 0, 1], [false, true, false], 4)
	var ai: SimAI = w.ais[0]
	check_eq(ai.player_id, 1, "the AI sits in seat two")
	var ally_base: Vector2 = w.players[0].start_pos
	var own_base: Vector2 = w.players[1].start_pos
	var guards: Array[SimEntity] = SimTestUtil.spawn_group(w, "levy", 1, w.map.nearest_free_pos(own_base + Vector2(6.0, 6.0)), 8)
	SimTestUtil.run(w, 40)
	check_eq(ai.ally_rescues, 0, "nothing to do while the ally is left alone")
	SimTestUtil.spawn_group(w, "trooper", 2, w.map.nearest_free_pos(ally_base + Vector2(9.0, 0.0)), 5)
	SimTestUtil.run(w, 20 * 4)
	check(ai.ally_rescues >= 1, "the AI answers an attack on its ally's headquarters")
	SimTestUtil.run(w, 20 * 40)
	var closer: int = 0
	for e: SimEntity in guards:
		if not e.alive or e.pos.distance_to(ally_base) < e.pos.distance_to(own_base):
			closer += 1
	check(closer >= 4, "and its army goes there (%d of 8)" % closer)


func test_allied_ais_attack_the_same_target() -> void:
	var w: SimWorld = _match(["aegis", "foundry", "nomad"], [0, 0, 1], [true, true, true], 6)
	var together: bool = false
	var limit: int = 20 * 60 * 18
	while w.tick_count < limit and not together and not w.game_over:
		w.tick()
		if w.tick_count % 20 == 0:
			var a: SimAI = w.ais[0]
			var b: SimAI = w.ais[1]
			if a.wave_state != SimAI.Wave.NONE and b.wave_state != SimAI.Wave.NONE and a.wave_target != 0 and a.wave_target == b.wave_target:
				together = true
	check(together or w.game_over, "two allied AIs have a wave out against the same building (by %d min)" % int(w.seconds() / 60.0))


func test_the_ai_rebuilds_what_it_loses() -> void:
	var w: SimWorld = _match(["aegis", "aegis"], [], [true, true], 11)
	SimTestUtil.run(w, 20 * 60 * 5)
	check(_count(w, 0, "barracks") >= 1 and _count(w, 0, "relay") >= 1, "by five minutes it has a barracks and a relay")
	var relays_before: int = _count(w, 0, "relay")
	for e: SimEntity in w.entities.duplicate():
		if e.alive and e.owner == 0 and e.def != null and (e.def.id == "barracks" or e.def.id == "relay"):
			SimCombat.kill(w, e, null, -1)
	check_eq(_count(w, 0, "barracks"), 0, "the barracks is gone")
	SimTestUtil.run(w, 20 * 60 * 4)
	check(_count(w, 0, "barracks") >= 1, "four minutes later there is a barracks again")
	check(_count(w, 0, "relay") >= mini(relays_before, 1), "and a relay (%d)" % _count(w, 0, "relay"))


## Leaves `owner` with its headquarters and nothing else worth the name.
func _strip(w: SimWorld, owner: int) -> void:
	for e: SimEntity in w.entities.duplicate():
		if e.alive and e.owner == owner and e.def != null and not e.def.signal_root:
			SimCombat.kill(w, e, null, -1)


func test_a_beaten_ai_concedes() -> void:
	var w: SimWorld = _match(["aegis", "foundry"], [], [true, true], 2)
	# Early on nobody gives up, however bad it looks.
	SimTestUtil.run(w, 20 * 60 * 4)
	_strip(w, 1)
	SimTestUtil.run(w, 20 * 60 * 4)
	check(not w.players[1].defeated or w.game_over, "an AI stripped of its base at four minutes is still playing at eight")
	if w.game_over:
		return  # the other AI finished it off by force: nothing left to test
	# Past fourteen minutes, a side that stays hopeless gives the match up.
	SimTestUtil.run(w, SimAI.CONCEDE_AFTER_TICKS - w.tick_count)
	if w.game_over:
		return
	_strip(w, 1)
	var before: int = w.tick_count
	SimTestUtil.run(w, 20 * 60)
	check(not w.players[1].defeated or w.game_over, "it does not give up at once")
	while not w.game_over and w.tick_count - before < SimAI.CONCEDE_HOLD_TICKS + 20 * 90:
		_strip(w, 1)
		SimTestUtil.run(w, 20 * 10)
	check(w.game_over and w.has_won(0), "after two and a half hopeless minutes it concedes (%d s)" % ((w.tick_count - before) / 20))


func test_an_ai_does_not_give_up_on_a_person() -> void:
	# Seat one is a person, seat two their AI ally, seat three a strong enemy AI.
	var w: SimWorld = _match(["aegis", "foundry", "nomad"], [0, 0, 1], [false, true, true], 4)
	w.victory_enabled = false
	SimTestUtil.run(w, SimAI.CONCEDE_AFTER_TICKS)
	var ally: SimAI = w.ais[0]
	check_eq(ally.player_id, 1, "the ally sits in seat two")
	for step: int in 24:
		_strip(w, 1)
		_strip(w, 0)
		SimTestUtil.run(w, 20 * 10)
	check(not w.players[1].defeated, "the AI ally fights on beside a person, however bad it looks")
	check(ally._hopeless_since < 0, "and does not even start counting")
