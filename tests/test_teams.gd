extends TestCase
## Teams: allies do not fight each other, share what they see, and win or
## lose together.


func _two_against_two(seed_value: int = 11) -> MatchConfig:
	var config: MatchConfig = MatchConfig.ai_vs_ai(seed_value)
	config.add_ai("foundry", 1, "Third")
	config.add_ai("nomad", 1, "Fourth")
	config.teams = [1, 1, 2, 2]
	return config


## A blank world with three players: 0 and 1 allied, 2 against them.
func _allied_world() -> SimWorld:
	var w: SimWorld = SimTestUtil.make_world(3, 48)
	w.add_player("aegis", Color(0.3, 0.85, 0.35), false, Vector2(48.0, 48.0), "Green")
	w.players[0].team = 7
	w.players[1].team = 7
	w.players[2].team = 8
	return w


func test_config_teams() -> void:
	var c: MatchConfig = MatchConfig.skirmish(3)
	check(not c.has_allies(), "a plain skirmish has no allies")
	check(c.team_of(0) != c.team_of(1), "players without a team entry are on their own")
	c.add_ai("foundry", 1, "Ally", c.team_of(0))
	check(c.has_allies(), "an AI can be added to a player's team")
	check_eq(c.team_of(2), c.team_of(0), "it is on that team")
	check(c.team_of(1) != c.team_of(0), "the earlier opponent is still an enemy")


func test_setup_gives_players_their_teams() -> void:
	var w: SimWorld = SimSetup.create_match(_two_against_two())
	check(w.are_allies(0, 1) and w.are_allies(2, 3), "the pairs are allies")
	check(w.are_enemies(0, 2) and w.are_enemies(1, 3) and w.are_enemies(0, 3), "the pairs oppose each other")
	check(not w.are_enemies(0, 1) and not w.are_allies(0, 0), "an ally is not an enemy, and nobody is their own ally")


func test_allies_start_side_by_side() -> void:
	for seed_value: int in [3, 11, 20]:
		var w: SimWorld = SimSetup.create_match(_two_against_two(seed_value))
		var size: float = w.map.world_size().x
		var mates: float = w.players[0].start_pos.distance_to(w.players[1].start_pos)
		var foes: float = w.players[2].start_pos.distance_to(w.players[3].start_pos)
		check(mates < size * 0.95, "seed %d: allies are on one side, not in opposite corners" % seed_value)
		check_near(mates, foes, 0.5, "seed %d: both teams are spaced alike" % seed_value)
		var used: Dictionary[Vector2, bool] = {}
		for p: SimPlayer in w.players:
			used[p.start_pos] = true
		check_eq(used.size(), 4, "seed %d: every player has a start of their own" % seed_value)
	# Mixed-up seat order still pairs the allies.
	var config: MatchConfig = _two_against_two(5)
	config.teams = [1, 2, 1, 2]
	var w2: SimWorld = SimSetup.create_match(config)
	var diagonal: float = w2.map.starts[0].distance_to(w2.map.starts[1])
	check(w2.players[0].start_pos.distance_to(w2.players[2].start_pos) < diagonal - 1.0, "allies in seats one and three are neighbours")
	# A free-for-all is untouched: player i on start i.
	var ffa: MatchConfig = _two_against_two(5)
	ffa.teams = []
	var w3: SimWorld = SimSetup.create_match(ffa)
	for i: int in 4:
		check_eq(w3.players[i].start_pos, w3.map.starts[i], "free-for-all keeps start %d" % i)


func test_allies_do_not_shoot_each_other() -> void:
	var w: SimWorld = _allied_world()
	SimTestUtil.reveal_all(w)
	var mine: SimEntity = w.spawn_unit("bulwark", 0, Vector2(20.0, 20.0))
	var friend: SimEntity = w.spawn_unit("bulwark", 1, Vector2(26.0, 20.0))
	SimTestUtil.run(w, 20 * 6)
	check_near(mine.hp, mine.max_hp, 0.001, "an ally standing next to me does not fire")
	check_near(friend.hp, friend.max_hp, 0.001, "and I do not fire on the ally")
	# Not even when told to.
	w.push_command(SimCommand.attack(0, PackedInt32Array([mine.id]), friend.id))
	SimTestUtil.run(w, 20 * 6)
	check_near(friend.hp, friend.max_hp, 0.001, "an attack order on an ally is not carried out")
	# The enemy of both is fair game for both.
	var foe: SimEntity = w.spawn_unit("trooper", 2, Vector2(23.0, 25.0))
	SimTestUtil.run(w, 20 * 10)
	check(not foe.alive or foe.hp < foe.max_hp, "the common enemy is shot at")


func test_shells_do_not_hurt_allies() -> void:
	var w: SimWorld = _allied_world()
	SimTestUtil.reveal_all(w)
	var gun: SimEntity = w.spawn_unit("longbow", 0, Vector2(20.0, 40.0))
	var foe: SimEntity = w.spawn_building("sentry_turret", 2, Vector2i(20, 20), true)
	var friend: SimEntity = w.spawn_unit("trooper", 1, foe.pos + Vector2(2.6, 0.0))
	w.push_command(SimCommand.hold(1, PackedInt32Array([friend.id])))
	w.push_command(SimCommand.attack(0, PackedInt32Array([gun.id]), foe.id))
	var t: int = 0
	while t < 20 * 40 and foe.hp >= foe.max_hp:
		w.tick()
		t += 1
	check(foe.hp < foe.max_hp, "the shell landed")
	SimTestUtil.run(w, 20)
	check(not friend.alive or friend.last_attacker != gun.id, "the ally beside the target was not hit by my shell")


func test_allies_share_sight() -> void:
	var w: SimWorld = _allied_world()
	var far: Vector2 = Vector2(80.0, 80.0)
	check(not SimVision.is_visible(w, 0, far), "nothing there yet")
	var scout: SimEntity = w.spawn_unit("courser", 1, far)
	var lurker: SimEntity = w.spawn_unit("trooper", 2, far + Vector2(4.0, 0.0))
	SimVision.recompute(w)
	check(SimVision.is_visible(w, 1, far), "the ally sees round its own scout")
	check(SimVision.is_visible(w, 0, far), "and so do I")
	check(SimVision.is_explored(w, 0, far), "it counts as explored for me")
	check(SimVision.can_see(w, 0, lurker), "I see the enemy my ally is looking at")
	check(SimVision.can_see(w, 0, scout), "I always see my ally's units")
	check(not SimVision.is_visible(w, 2, Vector2(10.0, 10.0)), "the enemy does not share in it")
	w.push_command(SimCommand.surrender(1))
	SimTestUtil.run(w, 12)
	check(not scout.alive, "the ally is gone")
	SimVision.recompute(w)
	check(not SimVision.is_visible(w, 0, far), "and so is what it saw")


func test_allies_do_not_take_each_others_uplinks() -> void:
	var w: SimWorld = _allied_world()
	var site: SimEntity = w.spawn_uplink(Vector2(30.0, 30.0))
	site.owner = 1
	var eng: SimEntity = w.spawn_unit("field_engineer", 0, Vector2(33.0, 30.0))
	w.push_command(SimCommand.capture(0, PackedInt32Array([eng.id]), site.id))
	SimTestUtil.run(w, 20 * 30)
	check_eq(site.owner, 1, "an ally's uplink site stays theirs")
	site.owner = 2
	w.push_command(SimCommand.capture(0, PackedInt32Array([eng.id]), site.id))
	SimTestUtil.run(w, 20 * 30)
	check_eq(site.owner, 0, "an enemy's is taken as before")


func test_a_team_wins_and_loses_together() -> void:
	var w: SimWorld = SimSetup.create_match(_two_against_two())
	w.push_command(SimCommand.surrender(1))
	SimTestUtil.run(w, 12)
	check(w.players[1].defeated and not w.game_over, "one of a pair falling does not end the match")
	check(not w.team_defeated(1) and not w.team_defeated(0), "their team is still in it")
	w.push_command(SimCommand.surrender(2))
	SimTestUtil.run(w, 12)
	check(not w.game_over, "three down to two, on different teams: still going")
	w.push_command(SimCommand.surrender(3))
	SimTestUtil.run(w, 12)
	check(w.game_over, "the last enemy falling ends it")
	check_eq(w.winner, 0, "the survivor is named")
	check_eq(w.winner_team, w.players[0].team, "the team is named")
	check(w.has_won(0) and w.has_won(1), "the fallen ally shares the win")
	check(not w.has_won(2) and not w.has_won(3), "the other team lost")
	check(w.team_defeated(2), "and is marked as out")


func test_allied_ais_fight_the_other_team_only() -> void:
	var config: MatchConfig = _two_against_two(4)
	var w: SimWorld = SimSetup.create_match(config)
	w.collect_events = false
	SimTestUtil.run(w, 20 * 60 * 8)
	for e: SimEntity in w.entities:
		if e.alive and e.owner >= 0 and e.last_attacker != 0:
			var by: SimEntity = w.get_entity(e.last_attacker)
			if by != null and by.owner >= 0:
				check(w.are_enemies(by.owner, e.owner), "%s was hit by a unit of its own side" % e.def.name)
	check(w.players[0].stat_units_built + w.players[1].stat_units_built > 4, "both allies build an army")
	check(w.tick_count > 0, "the match ran")


func test_saved_team_match_comes_back_with_its_teams() -> void:
	var config: MatchConfig = _two_against_two(9)
	var w: SimWorld = SimSetup.create_match(config)
	w.collect_events = false
	SimTestUtil.run(w, 20 * 120)
	var snapshot: Dictionary = SimSave.to_dict(w, config)
	var back: SimWorld = SimSave.from_dict(snapshot)
	check(back != null, "it restores")
	if back == null:
		return
	back.collect_events = false
	var c: MatchConfig = SimSave.config_from_dict(snapshot["config"])
	check_eq(c.teams, config.teams, "the configuration keeps its teams")
	check(back.are_allies(0, 1) and back.are_enemies(1, 2), "the players are on their teams again")
	check_eq(back.state_hash(), w.state_hash(), "same state")
	for i: int in 4:
		check_eq(back.players[i].start_pos, w.players[i].start_pos, "player %d starts where it did" % i)
	SimTestUtil.run(w, 20 * 60)
	SimTestUtil.run(back, 20 * 60)
	check_eq(back.state_hash(), w.state_hash(), "still identical a minute later")
