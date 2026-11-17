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
	# The Accord's AI at home with four idle gunships, and an enemy relay it knows of.
	var w: SimWorld = _match(["zephyr", "aegis"], [], [true, false], 7)
	w.victory_enabled = false
	var ai: SimAI = w.ais[0]
	SimTestUtil.run(w, 15)
	check(ai.strikes, "the Accord's AI strikes from the air")
	var home: Vector2 = w.players[0].start_pos
	var craft: Array[SimEntity] = SimTestUtil.spawn_group(w, "swift", 0, w.map.nearest_free_pos(home + Vector2(8.0, 8.0)), 4)
	var relay: SimEntity = w.spawn_building("relay", 1, w.map.cell_of(w.map.nearest_free_pos(w.players[1].start_pos + Vector2(-22.0, -22.0))), true)
	ai._known_buildings[relay.id] = true
	SimTestUtil.run(w, 20 * 4)
	check(ai.strikes_sent >= 1, "idle aircraft are sent out between waves")
	var after_it: int = 0
	for e: SimEntity in craft:
		# (An attack order on a building the player has only heard of
		# becomes an attack-move to where it stands.)
		if e.alive and not e.orders.is_empty() and (e.orders[0].target_id == relay.id or e.orders[0].pos.distance_to(relay.pos) < 6.0):
			after_it += 1
	check(after_it >= 3, "and they go for the relay (%d of 4)" % after_it)
	# Two aircraft are not a strike.
	var few: SimWorld = _match(["zephyr", "aegis"], [], [true, false], 7)
	few.victory_enabled = false
	SimTestUtil.run(few, 15)
	SimTestUtil.spawn_group(few, "swift", 0, few.map.nearest_free_pos(few.players[0].start_pos + Vector2(8.0, 8.0)), 2)
	var other: SimEntity = few.spawn_building("relay", 1, few.map.cell_of(few.map.nearest_free_pos(few.players[1].start_pos + Vector2(-22.0, -22.0))), true)
	few.ais[0]._known_buildings[other.id] = true
	SimTestUtil.run(few, 20 * 4)
	check_eq(few.ais[0].strikes_sent, 0, "two gunships stay at home")


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
				# The wave goes round as one: everybody is sent to the same
				# place (each to its own spot in the formation there). The
				# order is given this tick and reaches the units on the next.
				SimTestUtil.run(w, 2)
				for id: int in ai.wave_ids:
					var e: SimEntity = w.get_entity(id)
					if e != null and not e.orders.is_empty() and e.orders[0].pos.distance_to(ai.wave_stage) > 30.0:
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


func test_a_beaten_ai_concedes_to_another_ai() -> void:
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


func test_no_ai_gives_up_while_a_person_is_playing() -> void:
	# Seat one is a person, seat two their AI ally, seat three an enemy AI.
	var w: SimWorld = _match(["aegis", "foundry", "nomad"], [0, 0, 1], [false, true, true], 4)
	w.victory_enabled = false
	SimTestUtil.run(w, SimAI.CONCEDE_AFTER_TICKS)
	var ally: SimAI = w.ais[0]
	var enemy: SimAI = w.ais[1]
	check_eq(ally.player_id, 1, "the ally sits in seat two")
	for step: int in 24:
		_strip(w, 1)
		_strip(w, 0)
		SimTestUtil.run(w, 20 * 10)
	check(not w.players[1].defeated, "the AI ally fights on beside a person, however bad it looks")
	check(ally._hopeless_since < 0, "and does not even start counting")
	# The other way round: the enemy AI is the one that is beaten.
	for step: int in 24:
		_strip(w, 2)
		SimTestUtil.run(w, 20 * 10)
	check(not w.players[2].defeated, "an AI opponent of a person fights to its last building too")
	check(enemy._hopeless_since < 0, "and does not start counting either")


func test_a_starved_ai_concedes_to_a_stronger_one() -> void:
	var w: SimWorld = _match(["aegis", "foundry"], [], [true, true], 2)
	# Neither side attacks, so that both are still standing at eighteen minutes.
	for ai: SimAI in w.ais:
		ai.first_wave = 999
		ai.wave_size = 999
	SimTestUtil.run(w, SimAI.STARVED_AFTER_TICKS)
	check(not w.game_over, "both sides are standing at eighteen minutes")
	if w.game_over:
		return
	var loser: SimAI = w.ais[1]
	check(w.players[1].stat_salvage_collected > 3000, "it had an income until now")
	check(loser._buildings.size() > SimAI.CONCEDE_MAX_BUILDINGS, "and has a whole base (%d buildings)" % loser._buildings.size())
	# From here on seat two has its base but no haulers, no army, no money
	# and no uplink paying it anything: more than eight buildings, so the
	# first rule does not apply.
	var before: int = w.tick_count
	var limit: int = SimAI.STARVED_WINDOW_TICKS * 2 + SimAI.CONCEDE_HOLD_TICKS + 20 * 180
	while not w.game_over and w.tick_count - before < limit:
		for e: SimEntity in w.entities.duplicate():
			if e.alive and e.owner == 1 and e.kind == SimEntity.Kind.UNIT:
				SimCombat.kill(w, e, null, -1)
			elif e.alive and e.owner == 1 and e.kind == SimEntity.Kind.UPLINK:
				e.owner = -1
		w.players[1].salvage = 0
		for e: SimEntity in w.entities:
			if e.alive and e.owner == 1 and e.kind == SimEntity.Kind.BUILDING:
				e.queue.clear()
		SimTestUtil.run(w, 20 * 5)
	check(w.game_over and w.has_won(0), "with nothing coming in and half again its strength against it, it gives up (after %d s)" % ((w.tick_count - before) / 20))
	check(loser._starving or w.game_over, "it knew it was starving")


func test_the_ai_answers_turrets_with_siege_guns() -> void:
	# The same AI with the same factory, asked what to build three hundred
	# times, with and without enemy turrets known to it.
	var plain: int = _artillery_picked(false)
	var dug_in: int = _artillery_picked(true)
	check(plain > 0, "some artillery either way (%d of 300 without turrets)" % plain)
	check(dug_in > plain * 3 / 2, "a good deal more of it against an enemy behind turrets (%d against %d)" % [dug_in, plain])


## How often an Aegis AI with a Vehicle Works and a Command Lab chooses its
## artillery in 300 choices; with `turrets`, it knows of six enemy turrets.
func _artillery_picked(turrets: bool) -> int:
	var w: SimWorld = _match(["aegis", "aegis"], [], [true, false], 5)
	w.victory_enabled = false
	var ai: SimAI = w.ais[0]
	var me: SimPlayer = w.players[0]
	var home: Vector2i = w.map.cell_of(me.start_pos)
	w.spawn_building("barracks", 0, home + Vector2i(6, -2), true)
	var works: SimEntity = w.spawn_building("vehicle_works", 0, home + Vector2i(-2, 6), true)
	w.spawn_building("command_lab", 0, home + Vector2i(6, 5), true)
	if turrets:
		var base: Vector2i = w.map.cell_of(w.players[1].start_pos)
		for k: int in 6:
			var t: SimEntity = w.spawn_building("sentry_turret", 1, base + Vector2i(6 + k * 2, 8), true)
			ai._known_buildings[t.id] = true
	SimTestUtil.run(w, 30)
	me.salvage = 1000000
	me.bandwidth_cap = 100000
	ai._f = me.faction
	ai._survey(w)
	var picked: int = 0
	for i: int in 300:
		ai._spent = 0
		ai._bandwidth_committed = 0
		ai._wish.clear()
		w.commands.clear()
		ai._run_production(w, me)
		for cmd: SimCommand in w.commands:
			if cmd.type == SimCommand.Type.TRAIN and cmd.target_id == works.id and w.data.entity(cmd.def_id).ai_role == "artillery":
				picked += 1
	w.commands.clear()
	return picked


func test_a_rich_ai_adds_production_before_it_goes_back_to_relays() -> void:
	# An AI with one barracks, one works and one relay left standing (the
	# others shot down), asked what it wants to build next.
	var w: SimWorld = _match(["zephyr", "aegis"], [], [true, false], 5)
	w.victory_enabled = false
	var ai: SimAI = w.ais[0]
	var me: SimPlayer = w.players[0]
	var home: Vector2i = w.map.cell_of(me.start_pos)
	w.spawn_building("roost", 0, home + Vector2i(6, -2), true)
	w.spawn_building("flight_deck", 0, home + Vector2i(-3, 6), true)
	w.spawn_building("hangar", 0, home + Vector2i(6, 5), true)
	w.spawn_building("mast", 0, home + Vector2i(-6, -3), true)
	SimTestUtil.run(w, 30)
	ai._f = me.faction
	ai._survey(w)
	me.bandwidth_cap = 200
	me.salvage = 400
	var poor: String = ai._next_building(w, me)
	check_eq(poor, "mast", "with little in the bank it raises the relays it is short of")
	me.salvage = 1600
	var rich: String = ai._next_building(w, me)
	check_eq(rich, "flight_deck", "with salvage piling up it adds a works first")
	w.spawn_building("flight_deck", 0, home + Vector2i(-9, 6), true)
	ai._survey(w)
	check_eq(ai._next_building(w, me), "roost", "then a barracks")
	w.spawn_building("roost", 0, home + Vector2i(10, -2), true)
	ai._survey(w)
	check_eq(ai._next_building(w, me), "mast", "and with one more of each it is back to relays")
	me.salvage = 4600
	check(ai._next_building(w, me) in ["flight_deck", "roost"], "unless still more has piled up")
	# The most it adds this way is three of each over its usual number.
	for k: int in 6:
		w.spawn_building("flight_deck", 0, home + Vector2i(-12 - k * 4, 12), true)
		w.spawn_building("roost", 0, home + Vector2i(12 + k * 3, 10), true)
	ai._survey(w)
	me.salvage = 100000
	check(not (ai._next_building(w, me) in ["flight_deck", "roost"]), "there is an end to it")


func test_a_relay_goes_behind_the_base_while_the_forward_spot_is_under_fire() -> void:
	var w: SimWorld = _match(["aegis", "aegis"], [], [true, false], 5)
	w.victory_enabled = false
	var ai: SimAI = w.ais[0]
	var me: SimPlayer = w.players[0]
	SimTestUtil.run(w, 30)
	ai._f = me.faction
	ai._survey(w)
	var relay: EntityDef = w.data.entity("relay")
	var forward: Vector2 = ai._relay_spot(w, relay)
	check(forward != Vector2.INF, "there is somewhere worth reaching")
	check_eq(ai.relays_kept_home, 0, "left alone, the next relay goes out towards it")
	# An enemy tank parks on that spot, in plain view.
	w.spawn_unit("bulwark", 1, w.map.nearest_free_pos(forward))
	SimTestUtil.reveal_all(w)
	SimTestUtil.run(w, 2)
	ai._survey(w)
	check(ai._threat_near(forward, SimAI.RELAY_DANGER_RADIUS) != null, "the AI sees the tank there")
	var home: Vector2 = ai._relay_spot(w, relay)
	check_eq(ai.relays_kept_home, 1, "so the relay is kept at home")
	check(home.distance_to(ai._hq.pos) <= 17.5, "in the ring round the headquarters (%.1f from it)" % home.distance_to(ai._hq.pos))
	var toward_enemy: Vector2 = (ai._enemy_hq_pos(w) - ai._hq.pos).normalized()
	check((home - ai._hq.pos).dot(toward_enemy) < (forward - ai._hq.pos).dot(toward_enemy), "further from the enemy than the spot it gave up")


func test_the_ai_keeps_only_a_few_hijackers() -> void:
	# A Nomad AI with a Camp and money to burn, asked what to train many
	# times over, with none, some and its fill of Splicers already about.
	var w: SimWorld = _match(["nomad", "aegis"], [], [true, false], 5)
	w.victory_enabled = false
	var ai: SimAI = w.ais[0]
	var me: SimPlayer = w.players[0]
	var home: Vector2i = w.map.cell_of(me.start_pos)
	var camp: SimEntity = w.spawn_building("camp", 0, home + Vector2i(6, -2), true)
	SimTestUtil.run(w, 30)
	me.salvage = 1000000
	me.bandwidth_cap = 100000
	ai._f = me.faction
	var picked: Array[int] = []
	for have: int in [0, SimAI.MAX_HIJACKERS]:
		for k: int in have:
			w.spawn_unit("splicer", 0, w.map.nearest_free_pos(me.start_pos + Vector2(8.0 + float(k), 6.0)))
		ai._survey(w)
		check_eq(ai._hijackers.size(), have, "the AI counts its Splicers (%d)" % have)
		var splicers: int = 0
		for i: int in 300:
			ai._spent = 0
			ai._bandwidth_committed = 0
			ai._wish.clear()
			w.commands.clear()
			camp.queue.clear()
			ai._run_production(w, me)
			for cmd: SimCommand in w.commands:
				if cmd.type == SimCommand.Type.TRAIN and cmd.def_id == "splicer":
					splicers += 1
		w.commands.clear()
		picked.append(splicers)
	check(picked[0] > 0, "with none it trains some (%d in 300 choices)" % picked[0])
	check_eq(picked[1], 0, "with %d it trains no more" % SimAI.MAX_HIJACKERS)
