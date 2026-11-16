extends TestCase
## One unit for each of six factions that no other faction has: the Tether
## (Vesper), the Paymaster (Tally), the Mantle (Veil), the Dragline
## (Lodestone), the Burster (Brackenfold) and the Almoner (Verdigris).


func _world(faction: String) -> SimWorld:
	var config: MatchConfig = MatchConfig.skirmish(6)
	config.factions = [faction, "aegis"]
	config.is_ai = [false, false]
	var w: SimWorld = SimSetup.create_match(config)
	w.victory_enabled = false
	return w


## A free spot well outside both players' coverage.
func _wilds(w: SimWorld) -> Vector2:
	var middle: Vector2 = w.map.nearest_free_pos(w.map.world_size() * 0.5)
	return middle


func test_the_tether_carries_the_signal() -> void:
	var w: SimWorld = _world("vesper")
	var at: Vector2 = _wilds(w)
	var mote: SimEntity = w.spawn_unit("mote", 0, at)
	SimTestUtil.run(w, 20)
	check(not mote.linked, "a Mote in the middle of the map is Dark")
	var tether: SimEntity = w.spawn_unit("tether", 0, w.map.nearest_free_pos(at + Vector2(4.0, 0.0)))
	SimTestUtil.run(w, 20)
	check(mote.linked, "with a Tether beside it, it is Linked")
	check(tether.linked, "and so is the Tether")
	var foe: SimEntity = w.spawn_unit("trooper", 1, w.map.nearest_free_pos(at + Vector2(0.0, 30.0)))
	SimTestUtil.run(w, 20)
	check(not foe.linked, "it does nothing for the enemy")
	SimCombat.kill(w, tether, null, -1)
	SimTestUtil.run(w, 20)
	check(not mote.linked, "once the Tether is gone the Mote is Dark again")


func test_the_paymaster_quickens_the_guns() -> void:
	var w: SimWorld = _world("tally")
	var at: Vector2 = w.map.nearest_free_pos(w.players[0].start_pos + Vector2(12.0, 0.0))
	var gun: SimEntity = w.spawn_unit("gunhand", 0, at)
	SimTestUtil.run(w, 20)
	check(is_equal_approx(SimCombat.rof_mult(w, gun), 1.0), "a Gunhand at home fires at its usual rate")
	var wagon: SimEntity = w.spawn_unit("paymaster", 0, w.map.nearest_free_pos(at + Vector2(3.0, 0.0)))
	SimTestUtil.run(w, 20)
	check(is_equal_approx(SimCombat.rof_mult(w, gun), 1.2), "with a Paymaster in sight it fires a fifth faster (%.2f)" % SimCombat.rof_mult(w, gun))
	check(wagon.boost_until <= w.tick_count, "the wagon does not quicken itself")
	var far: SimEntity = w.spawn_unit("gunhand", 0, w.map.nearest_free_pos(at + Vector2(0.0, 20.0)))
	SimTestUtil.run(w, 20)
	check(far.boost_until <= w.tick_count, "a Gunhand too far off is not quickened")


func test_the_mantle_hides_what_stands_near_it() -> void:
	var w: SimWorld = _world("veil")
	var at: Vector2 = _wilds(w)
	var shade: SimEntity = w.spawn_unit("shade", 0, at)
	SimTestUtil.run(w, 80)
	check(not shade.linked and not SimVision.is_stealthed(w, shade), "outside its coverage a Shade is in plain sight")
	var mantle: SimEntity = w.spawn_unit("mantle", 0, w.map.nearest_free_pos(at + Vector2(3.0, 0.0)))
	SimTestUtil.run(w, 80)
	check(SimVision.is_stealthed(w, shade), "beside a Mantle it is hidden")
	check(SimVision.is_stealthed(w, mantle), "and so is the Mantle")
	var watcher: SimEntity = w.spawn_unit("courser", 1, w.map.nearest_free_pos(at + Vector2(0.0, 10.0)))
	watcher.hold = true
	SimTestUtil.run(w, 10)
	check(SimVision.is_visible(w, 1, shade.pos), "an enemy looking straight at the place")
	check(not SimVision.can_see(w, 1, shade), "does not see the Shade")
	w.push_command(SimCommand.move(0, PackedInt32Array([shade.id]), w.map.nearest_free_pos(at + Vector2(-2.0, 0.0))))
	SimTestUtil.run(w, 6)
	check(not SimVision.is_stealthed(w, shade), "until the Shade moves")


func test_the_dragline_slows_whatever_comes_near() -> void:
	var w: SimWorld = _world("lodestone")
	var at: Vector2 = _wilds(w)
	var engine: SimEntity = w.spawn_unit("dragline", 0, at)
	var friend: SimEntity = w.spawn_unit("keeper", 0, w.map.nearest_free_pos(at + Vector2(3.0, 0.0)))
	var foe: SimEntity = w.spawn_unit("hauler", 1, w.map.nearest_free_pos(at + Vector2(0.0, 6.0)))
	foe.orders.clear()
	SimTestUtil.run(w, 20)
	check(foe.slow_until > w.tick_count and is_equal_approx(foe.slow_amount, 0.4), "an enemy inside the field is dragged (%.2f)" % foe.slow_amount)
	check(friend.slow_until <= w.tick_count and engine.slow_until <= w.tick_count, "its own side is not")
	# (The Keeper goes too: its own shots drag what they hit.)
	SimCombat.kill(w, engine, null, -1)
	SimCombat.kill(w, friend, null, -1)
	SimTestUtil.run(w, 20 * 4)
	check(foe.slow_until <= w.tick_count, "the drag lets go soon after the engine is gone")


func test_the_burster_bursts_once() -> void:
	var w: SimWorld = _world("bracken")
	var at: Vector2 = _wilds(w)
	var squad: Array[SimEntity] = SimTestUtil.spawn_group(w, "trooper", 1, at, 4)
	for e: SimEntity in squad:
		e.hold = true
	var pod: SimEntity = w.spawn_unit("burster", 0, w.map.nearest_free_pos(at + Vector2(9.0, 0.0)))
	w.push_command(SimCommand.attack_move(0, PackedInt32Array([pod.id]), at))
	SimTestUtil.run(w, 20 * 8)
	check(not pod.alive, "the Burster is gone")
	var hurt: int = 0
	for e: SimEntity in squad:
		if not e.alive or e.hp < e.max_hp * 0.6:
			hurt += 1
	check(hurt >= 2 or w.players[0].stat_kills >= 1, "and took a good part of the squad with it (%d of 4 hurt)" % hurt)


func test_the_almoner_heals_infantry() -> void:
	var w: SimWorld = _world("verdigris")
	var at: Vector2 = w.map.nearest_free_pos(w.players[0].start_pos + Vector2(12.0, 0.0))
	var knight: SimEntity = w.spawn_unit("vigil", 0, at)
	var walker: SimEntity = w.spawn_unit("outrider", 0, w.map.nearest_free_pos(at + Vector2(0.0, 3.0)))
	var far: SimEntity = w.spawn_unit("vigil", 0, w.map.nearest_free_pos(at + Vector2(0.0, 16.0)))
	knight.hp = 40.0
	walker.hp = 100.0
	far.hp = 40.0
	SimTestUtil.run(w, 40)
	check_near(knight.hp, 40.0, 0.01, "nothing heals a Vigil on its own")
	var almoner: SimEntity = w.spawn_unit("almoner", 0, w.map.nearest_free_pos(at + Vector2(2.0, 0.0)))
	almoner.hp = 60.0
	SimTestUtil.run(w, 20 * 5)
	check(knight.hp > 65.0 and knight.hp < 85.0, "an Almoner beside it mends about seven points a second (%.0f after five seconds)" % knight.hp)
	check_near(walker.hp, 100.0, 0.01, "it does nothing for machines")
	check_near(far.hp, 40.0, 0.01, "nor for a knight out of reach")
	check_near(almoner.hp, 60.0, 0.01, "nor for itself")
	SimTestUtil.run(w, 20 * 30)
	check_near(knight.hp, knight.max_hp, 0.01, "it stops at full health")


func test_the_ai_fields_its_signature_unit() -> void:
	var units: Dictionary[String, String] = {"vesper": "tether", "tally": "paymaster", "veil": "mantle", "lodestone": "dragline", "bracken": "burster", "verdigris": "almoner"}
	for faction: String in units:
		var config: MatchConfig = MatchConfig.ai_vs_ai(4)
		config.factions = [faction, "aegis"]
		var w: SimWorld = SimSetup.create_match(config)
		w.collect_events = false
		var seen: bool = false
		while w.tick_count < 20 * 60 * 14 and not seen and not w.game_over:
			SimTestUtil.run(w, 20 * 10)
			for e: SimEntity in w.entities:
				if e.alive and e.owner == 0 and e.def != null and e.def.id == units[faction]:
					seen = true
					break
		check(seen, "%s: the AI builds a %s (by %d min)" % [faction, units[faction], int(w.seconds() / 60.0)])
