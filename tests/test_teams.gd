extends TestCase
## Teams: allies do not shoot each other, see what the other sees, start
## side by side and win or lose together.


## Three or four seats; `teams` gives the team of each.
func _world(teams: Array[int], seed_value: int = 4) -> SimWorld:
	var config: MatchConfig = _config(teams, seed_value)
	return SimSetup.create_match(config)


func _config(teams: Array[int], seed_value: int = 4) -> MatchConfig:
	var config: MatchConfig = MatchConfig.skirmish(seed_value)
	var roster: Array[String] = ["aegis", "foundry", "nomad", "vesper"]
	config.factions.clear()
	config.is_ai.clear()
	config.ai_levels.clear()
	config.names.clear()
	for i: int in teams.size():
		config.factions.append(roster[i])
		config.is_ai.append(false)
		config.ai_levels.append(1)
		config.names.append("Seat %d" % (i + 1))
		config.set_team(i, teams[i])
	return config


func test_allies_hold_their_fire() -> void:
	var w: SimWorld = _world([0, 0, 1])
	check(w.are_allies(0, 1) and not w.are_enemies(0, 1), "seats one and two are allies")
	check(w.are_enemies(0, 2) and w.are_enemies(1, 2), "seat three is the enemy of both")
	check(not w.are_allies(0, 0), "nobody is their own ally")
	var middle: Vector2 = w.map.nearest_free_pos(w.map.world_size() * 0.5)
	var mine: SimEntity = w.spawn_unit("trooper", 0, middle)
	var friend: SimEntity = w.spawn_unit("trooper", 1, w.map.nearest_free_pos(middle + Vector2(3.0, 0.0)))
	SimTestUtil.run(w, 20 * 8)
	check(is_equal_approx(friend.hp, friend.max_hp) and is_equal_approx(mine.hp, mine.max_hp), "allies standing together do not fight")
	# Ordered to attack an ally: nothing happens.
	w.push_command(SimCommand.attack(0, PackedInt32Array([mine.id]), friend.id))
	SimTestUtil.run(w, 20 * 6)
	check(is_equal_approx(friend.hp, friend.max_hp), "an attack order on an ally is ignored")
	var foe: SimEntity = w.spawn_unit("trooper", 2, w.map.nearest_free_pos(middle + Vector2(0.0, 4.0)))
	SimTestUtil.run(w, 20 * 8)
	check(not foe.alive or foe.hp < foe.max_hp, "the two of them shoot the enemy")


func test_allies_share_what_they_see() -> void:
	var w: SimWorld = _world([0, 0, 1])
	SimTestUtil.run(w, 10)
	var ally_base: Vector2 = w.players[1].start_pos
	var enemy_base: Vector2 = w.players[2].start_pos
	check(SimVision.is_visible(w, 0, ally_base), "I see my ally's base")
	check(SimVision.is_visible(w, 1, w.players[0].start_pos), "and my ally sees mine")
	check(not SimVision.is_visible(w, 0, enemy_base), "but not the enemy's")
	check(not SimVision.is_visible(w, 2, ally_base), "and the enemy sees neither of us")
	var ally_hq: SimEntity = null
	for e: SimEntity in w.entities:
		if e.alive and e.owner == 1 and e.def != null and e.def.signal_root:
			ally_hq = e
	check(ally_hq != null and SimVision.can_see(w, 0, ally_hq), "an ally's buildings are always in view")
	# Without teams nothing is shared.
	var ffa: SimWorld = _world([0, 1, 2])
	SimTestUtil.run(ffa, 10)
	check(not SimVision.is_visible(ffa, 0, ffa.players[1].start_pos), "a free-for-all shares nothing")


func test_allies_start_side_by_side() -> void:
	for teams: Array in [[0, 0, 1, 1], [0, 1, 0, 1], [0, 1, 1, 0]]:
		var typed: Array[int] = []
		typed.assign(teams)
		var w: SimWorld = _world(typed, 9)
		for a: SimPlayer in w.players:
			var to_ally: float = 0.0
			var to_enemy: float = INF
			for b: SimPlayer in w.players:
				if w.are_allies(a.id, b.id):
					to_ally = a.start_pos.distance_to(b.start_pos)
				elif w.are_enemies(a.id, b.id):
					to_enemy = minf(to_enemy, a.start_pos.distance_to(b.start_pos))
			check(to_ally > 0.0 and to_ally <= to_enemy + 0.01, "%s: seat %d starts no further from its ally (%.0f) than from an enemy (%.0f)" % [str(teams), a.id + 1, to_ally, to_enemy])
		var taken: Dictionary[Vector2, bool] = {}
		for p: SimPlayer in w.players:
			taken[p.start_pos] = true
		check_eq(taken.size(), 4, "%s: every seat has a start of its own" % str(teams))
	# Without teams the seats take the starts in order, as before.
	var plain: MatchConfig = _config([0, 1, 2])
	var starts: Array[Vector2] = [Vector2(1.0, 1.0), Vector2(9.0, 9.0), Vector2(9.0, 1.0), Vector2(1.0, 9.0)]
	check_eq(SimSetup.assign_starts(plain, starts), starts.slice(0, 3), "a free-for-all keeps the order of the starts")


func test_a_team_wins_and_loses_together() -> void:
	var w: SimWorld = _world([0, 0, 1, 1])
	w.defeat_player(1)
	SimTestUtil.run(w, 5)
	check(not w.game_over, "losing one ally does not end the match")
	w.defeat_player(2)
	SimTestUtil.run(w, 5)
	check(not w.game_over, "one enemy still stands")
	w.defeat_player(3)
	SimTestUtil.run(w, 5)
	check(w.game_over, "the match ends when one team is left")
	check(w.has_won(0), "the survivor won")
	check(w.has_won(1), "and so did the ally who fell on the way")
	check(not w.has_won(2) and not w.has_won(3), "the other team lost")
	check_eq(w.winners().size(), 2, "two winners")


func test_teams_survive_a_save() -> void:
	var config: MatchConfig = _config([0, 1, 1, 0])
	var w: SimWorld = SimSetup.create_match(config)
	SimTestUtil.run(w, 40)
	var again: SimWorld = SimSave.from_dict(SimSave.to_dict(w, config))
	check(again != null, "the save loads")
	if again == null:
		return
	for i: int in 4:
		check_eq(again.players[i].team, w.players[i].team, "seat %d keeps its team" % (i + 1))
		check_eq(again.players[i].start_pos, w.players[i].start_pos, "seat %d keeps its start" % (i + 1))
	check(again.are_allies(0, 3) and again.are_allies(1, 2) and again.are_enemies(0, 1), "the sides are the same")
	var loaded: MatchConfig = SimSave.config_from_dict(SimSave.config_to_dict(config))
	check_eq(loaded.teams, config.teams, "the configuration keeps its teams")


func test_the_config_counts_sides() -> void:
	var c: MatchConfig = MatchConfig.skirmish(1)
	check(not c.has_teams(), "a plain skirmish has no teams")
	check_eq(c.side_count(), 2, "and two sides")
	c.add_ai("foundry", 1, "Ally", c.team_of(0))
	check(c.has_teams(), "an AI given my team is my ally")
	check_eq(c.side_count(), 2, "still two sides")
	check_eq(c.team_of(2), c.team_of(0), "it is on my team")
	c.add_ai("nomad", 1, "Another")
	check_eq(c.side_count(), 3, "a third AI on its own makes three")
	var one: MatchConfig = MatchConfig.skirmish(1)
	one.set_team(0, 0)
	one.set_team(1, 0)
	check_eq(one.side_count(), 1, "everybody on one team is no match")


func test_an_ai_fights_beside_its_ally() -> void:
	# Two AIs against one: the pair never attacks each other and the single
	# AI loses in reasonable time.
	var config: MatchConfig = MatchConfig.ai_vs_ai(3)
	config.add_ai("nomad", 1, "Third", config.team_of(0))
	var w: SimWorld = SimSetup.create_match(config)
	w.collect_events = false
	var limit: int = 45 * 60 * SimWorld.TICK_RATE
	while not w.game_over and w.tick_count < limit:
		w.tick()
	check(w.game_over, "the match ends (%d min)" % int(w.seconds() / 60.0))
	check(w.has_won(0) and w.has_won(2), "the pair wins together")
	check(not w.players[0].defeated or not w.players[2].defeated, "at least one of the pair is standing")
