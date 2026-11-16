extends TestCase
## Generated map sizes, hand-made layouts and matches with more than two players.


func _symmetry_mismatches(m: SimMap, order: int) -> int:
	var bad: int = 0
	for y: int in m.h:
		for x: int in m.w:
			var t: int = m.terrain_cell(Vector2i(x, y))
			for image: Vector2i in SimMapGen.cell_images(m, Vector2i(x, y), order):
				if m.terrain_cell(image) != t:
					bad += 1
	return bad


func _all_reachable(m: SimMap) -> bool:
	for i: int in range(1, m.starts.size()):
		var path: PackedVector2Array = m.find_path(m.starts[0], m.starts[i], true)
		if path.size() == 0 or path[path.size() - 1].distance_to(m.starts[i]) > SimMap.CELL * 2.0:
			return false
	for f: Vector3 in m.field_spots:
		var fp: Vector2 = Vector2(f.x, f.y)
		var to_field: PackedVector2Array = m.find_path(m.starts[0], fp, true)
		if to_field.size() == 0 or to_field[to_field.size() - 1].distance_to(fp) > SimMap.CELL * 2.0:
			return false
	return true


func _hq_fits(m: SimMap, start: Vector2) -> bool:
	var c: Vector2i = m.cell_of(start) - Vector2i(2, 2)
	for y: int in range(c.y, c.y + 4):
		for x: int in range(c.x, c.x + 4):
			if not m.is_cell_buildable(Vector2i(x, y)):
				return false
	return true


func test_four_player_generated_map() -> void:
	for seed_value: int in [1, 9, 42]:
		var m: SimMap = SimMapGen.generate(seed_value, SimMapGen.LARGE_CELLS, 4)
		check_eq(m.w, 96, "192 x 192 world units")
		check_eq(m.starts.size(), 4, "four starts")
		check_eq(_symmetry_mismatches(m, 4), 0, "seed %d: quarter-turn symmetric" % seed_value)
		check(_all_reachable(m), "seed %d: every start and field is reachable" % seed_value)
		check_eq(m.field_spots.size() % 4, 0, "seed %d: fields come in fours" % seed_value)
		check_eq(m.uplink_spots.size(), 4, "seed %d: four uplink sites" % seed_value)
		check(m.starts[0].distance_to(m.starts[1]) > m.starts[0].distance_to(m.starts[2]), "the first two starts are opposite corners")
		for s: Vector2 in m.starts:
			check(_hq_fits(m, s), "seed %d: an HQ fits on every start" % seed_value)


func test_two_player_generation_is_unchanged_by_the_size_option() -> void:
	var a: SimMap = SimMapGen.generate(7, SimMapGen.SMALL_CELLS, 2)
	var b: SimMap = SimMapGen.generate(7)
	check(a.terrain == b.terrain, "default arguments give the two-player map")
	check_eq(a.starts.size(), 2, "two starts")


func test_hand_made_layouts_load_and_are_fair() -> void:
	var ids: Array[String] = SimMapGen.layout_ids()
	check(ids.size() >= 3, "three layouts ship (%d found)" % ids.size())
	for id: String in ids:
		var info: Dictionary = SimMapGen.layout_info(id)
		var m: SimMap = SimMapGen.load_layout(id)
		check(m != null, "%s loads" % id)
		if m == null:
			continue
		var players: int = int(info["players"])
		check_eq(m.starts.size(), players, "%s: start count matches its player count" % id)
		check(str(info["name"]) != "" and str(info["desc"]) != "", "%s has a name and description" % id)
		check_eq(_symmetry_mismatches(m, 4 if players > 2 else 2), 0, "%s is symmetric" % id)
		check(_all_reachable(m), "%s: every start and field is reachable" % id)
		check(m.field_spots.size() >= players * 3, "%s has enough salvage fields" % id)
		check(m.uplink_spots.size() >= 2, "%s has uplink sites" % id)
		for s: Vector2 in m.starts:
			check(_hq_fits(m, s), "%s: an HQ fits on every start" % id)
		for f: Vector3 in m.field_spots:
			check(m.is_passable(Vector2(f.x, f.y)), "%s: fields sit on open ground" % id)


func test_layout_match_setup() -> void:
	var config: MatchConfig = MatchConfig.skirmish(3)
	config.map_id = "twin_fords"
	var w: SimWorld = SimSetup.create_match(config)
	check_eq(w.map.name, "Twin Fords", "the chosen layout is used")
	var hqs: int = 0
	for e: SimEntity in w.entities:
		if e.def != null and e.def.signal_root:
			hqs += 1
	check_eq(hqs, 2, "both headquarters placed")
	SimTestUtil.run(w, 20 * 45)
	check(w.players[0].stat_salvage_collected > 0, "haulers find the layout's fields")


func test_four_player_match_setup() -> void:
	var config: MatchConfig = MatchConfig.skirmish(11)
	config.add_ai("foundry", 1, "Third")
	config.add_ai("nomad", 1, "Fourth")
	var w: SimWorld = SimSetup.create_match(config)
	check_eq(w.players.size(), 4, "four players")
	check_eq(w.map.starts.size(), 4, "a four-start map was generated")
	check_eq(w.ais.size(), 3, "three AI opponents")
	var hq_owners: Dictionary[int, bool] = {}
	for e: SimEntity in w.entities:
		if e.def != null and e.def.signal_root:
			hq_owners[e.owner] = true
	check_eq(hq_owners.size(), 4, "everyone has a headquarters")
	check(w.are_enemies(1, 2) and w.are_enemies(0, 3), "it is a free-for-all")
	# One player falling does not end a four-player match.
	w.push_command(SimCommand.surrender(3))
	SimTestUtil.run(w, 12)
	check(w.players[3].defeated and not w.game_over, "the match goes on with three")


func test_too_many_players_for_a_layout_falls_back_to_generated() -> void:
	var config: MatchConfig = MatchConfig.skirmish(11)
	config.map_id = "twin_fords"
	config.add_ai("aegis", 1, "Third")
	var w: SimWorld = SimSetup.create_match(config)
	check(w.map.starts.size() >= 3, "a map with enough starts is used instead")
