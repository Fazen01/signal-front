extends TestCase
## Unit stances: aggressive, return fire, hold fire.


func _pair(w: SimWorld, gap: float) -> Array[SimEntity]:
	var mine: SimEntity = w.spawn_unit("bulwark", 0, Vector2(24, 30))
	var theirs: SimEntity = w.spawn_unit("bulwark", 1, Vector2(24 + gap, 30))
	SimTestUtil.reveal_all(w)
	return [mine, theirs]


func test_units_start_aggressive_and_shoot_what_they_see() -> void:
	var w: SimWorld = SimTestUtil.make_world()
	var pair: Array[SimEntity] = _pair(w, 6.0)
	pair[1].stance = SimEntity.Stance.HOLD_FIRE
	check_eq(pair[0].stance, SimEntity.Stance.AGGRESSIVE, "a new unit is aggressive")
	SimTestUtil.run(w, 20 * 4)
	check(pair[1].hp < pair[1].max_hp, "an aggressive tank opens fire on an enemy in range")


func test_hold_fire_never_shoots_first_but_obeys_an_attack_order() -> void:
	var w: SimWorld = SimTestUtil.make_world()
	var pair: Array[SimEntity] = _pair(w, 6.0)
	var mine: SimEntity = pair[0]
	var theirs: SimEntity = pair[1]
	theirs.stance = SimEntity.Stance.HOLD_FIRE
	w.push_command(SimCommand.stance(0, PackedInt32Array([mine.id]), SimEntity.Stance.HOLD_FIRE))
	SimTestUtil.run(w, 20 * 5)
	check_eq(mine.stance, SimEntity.Stance.HOLD_FIRE, "the command sets the stance")
	check(is_equal_approx(theirs.hp, theirs.max_hp), "a tank holding fire does not shoot an enemy beside it")
	check_eq(mine.target_id, 0, "and has no target")
	# Being shot does not change that.
	SimCombat.apply_damage(w, mine, 20.0, 0, theirs, 0)
	SimTestUtil.run(w, 20 * 3)
	check(is_equal_approx(theirs.hp, theirs.max_hp), "not even when it is hit")
	# An order to attack is obeyed all the same.
	w.push_command(SimCommand.attack(0, PackedInt32Array([mine.id]), theirs.id))
	SimTestUtil.run(w, 20 * 4)
	check(theirs.hp < theirs.max_hp, "but it attacks what it is ordered to attack")
	check_eq(mine.stance, SimEntity.Stance.HOLD_FIRE, "and keeps its stance")


func test_return_fire_answers_only_whoever_shot() -> void:
	var w: SimWorld = SimTestUtil.make_world()
	var pair: Array[SimEntity] = _pair(w, 6.0)
	var mine: SimEntity = pair[0]
	var theirs: SimEntity = pair[1]
	var bystander: SimEntity = w.spawn_unit("bulwark", 1, Vector2(24, 36))
	theirs.stance = SimEntity.Stance.HOLD_FIRE
	bystander.stance = SimEntity.Stance.HOLD_FIRE
	w.push_command(SimCommand.stance(0, PackedInt32Array([mine.id]), SimEntity.Stance.RETURN_FIRE))
	SimTestUtil.run(w, 20 * 5)
	check(is_equal_approx(theirs.hp, theirs.max_hp) and is_equal_approx(bystander.hp, bystander.max_hp), "on return fire a tank does not shoot first")
	SimCombat.apply_damage(w, mine, 20.0, 0, theirs, 0)
	SimTestUtil.run(w, 20 * 4)
	check(theirs.hp < theirs.max_hp, "it shoots back at the one that hit it")
	check(is_equal_approx(bystander.hp, bystander.max_hp), "and leaves the one that did not alone")
	# Once the shooting has stopped for a while it stands down again.
	var before: float = theirs.hp
	SimTestUtil.run(w, SimCombat.RETURN_FIRE_TICKS + 20 * 3)
	var later: float = theirs.hp
	SimTestUtil.run(w, 20 * 4)
	check(before > later or is_equal_approx(before, later), "it may finish its answer")
	check(is_equal_approx(theirs.hp, later), "and then holds its fire again")


func test_return_fire_answers_for_a_neighbour() -> void:
	var w: SimWorld = SimTestUtil.make_world()
	var pair: Array[SimEntity] = _pair(w, 6.0)
	var mine: SimEntity = pair[0]
	var theirs: SimEntity = pair[1]
	var friend: SimEntity = w.spawn_unit("bulwark", 0, Vector2(24, 26))
	var far_friend: SimEntity = w.spawn_unit("bulwark", 0, Vector2(4, 56))
	theirs.stance = SimEntity.Stance.HOLD_FIRE
	friend.stance = SimEntity.Stance.HOLD_FIRE
	far_friend.stance = SimEntity.Stance.HOLD_FIRE
	mine.stance = SimEntity.Stance.RETURN_FIRE
	SimCombat.apply_damage(w, far_friend, 20.0, 0, theirs, 0)
	SimTestUtil.run(w, 20 * 3)
	check(is_equal_approx(theirs.hp, theirs.max_hp), "a hit on a unit far away is not its business")
	SimCombat.apply_damage(w, friend, 20.0, 0, theirs, 0)
	SimTestUtil.run(w, 20 * 4)
	check(theirs.hp < theirs.max_hp, "a hit on the unit beside it is")


func test_stance_command_only_touches_own_units_and_valid_stances() -> void:
	var w: SimWorld = SimTestUtil.make_world()
	var pair: Array[SimEntity] = _pair(w, 30.0)
	w.push_command(SimCommand.stance(0, PackedInt32Array([pair[0].id, pair[1].id]), SimEntity.Stance.HOLD_FIRE))
	SimTestUtil.run(w, 2)
	check_eq(pair[0].stance, SimEntity.Stance.HOLD_FIRE, "my unit takes the stance")
	check_eq(pair[1].stance, SimEntity.Stance.AGGRESSIVE, "the enemy's does not")
	w.push_command(SimCommand.stance(0, PackedInt32Array([pair[0].id]), 7))
	SimTestUtil.run(w, 2)
	check_eq(pair[0].stance, SimEntity.Stance.HOLD_FIRE, "a stance that does not exist is ignored")
	w.push_command(SimCommand.stance(0, PackedInt32Array([pair[0].id]), SimEntity.Stance.AGGRESSIVE))
	SimTestUtil.run(w, 2)
	check_eq(pair[0].stance, SimEntity.Stance.AGGRESSIVE, "and it can be set back")


func test_changing_stance_drops_a_target_it_chose_itself() -> void:
	var w: SimWorld = SimTestUtil.make_world()
	var pair: Array[SimEntity] = _pair(w, 6.0)
	pair[1].stance = SimEntity.Stance.HOLD_FIRE
	SimTestUtil.run(w, 20)
	check_eq(pair[0].target_id, pair[1].id, "an aggressive tank has picked the enemy")
	w.push_command(SimCommand.stance(0, PackedInt32Array([pair[0].id]), SimEntity.Stance.HOLD_FIRE))
	SimTestUtil.run(w, 2)
	check_eq(pair[0].target_id, 0, "told to hold fire it lets go at once")
	var hp: float = pair[1].hp
	SimTestUtil.run(w, 20 * 4)
	check(is_equal_approx(pair[1].hp, hp) or pair[1].hp > hp, "and stops shooting")


func test_stance_survives_a_save() -> void:
	var config: MatchConfig = MatchConfig.skirmish(3)
	var w: SimWorld = SimSetup.create_match(config)
	var unit: SimEntity = null
	for e: SimEntity in w.entities:
		if e.kind == SimEntity.Kind.UNIT and e.owner == 0:
			unit = e
			break
	check(unit != null, "the player has a unit")
	if unit == null:
		return
	unit.stance = SimEntity.Stance.RETURN_FIRE
	var back: SimWorld = SimSave.from_dict(SimSave.to_dict(w, config))
	check(back != null, "the save loads")
	if back != null:
		check_eq(back.get_entity(unit.id).stance, SimEntity.Stance.RETURN_FIRE, "the stance is in the save")
