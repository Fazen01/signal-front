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


func test_generated_two_player_sizes() -> void:
	var standard: SimWorld = SimSetup.create_match(MatchConfig.skirmish(3))
	check_eq(standard.map.w, SimMapGen.STANDARD_CELLS, "a skirmish uses the standard generated size")
	var config: MatchConfig = MatchConfig.skirmish(3)
	config.map_cells = SimMapGen.SMALL_CELLS
	var compact: SimWorld = SimSetup.create_match(config)
	check_eq(compact.map.w, SimMapGen.SMALL_CELLS, "the compact option is honoured")
	# Fields must be reachable on the larger map too.
	SimTestUtil.run(standard, 20 * 60)
	check(standard.players[0].stat_salvage_collected > 0, "haulers find fields on the standard map")


func _kind_of(m: SimMap) -> String:
	return m.name.rsplit(" ", true, 1)[0]


func _reaches(m: SimMap, from: Vector2, to: Vector2) -> bool:
	var path: PackedVector2Array = m.find_path(from, to, true)
	return path.size() > 0 and path[path.size() - 1].distance_to(to) <= SimMap.CELL * 2.0


func test_generated_maps_come_in_several_kinds() -> void:
	var kinds: Dictionary[String, int] = {}
	for seed_value: int in range(1, 25):
		var m: SimMap = SimMapGen.generate(seed_value, SimMapGen.STANDARD_CELLS, 2, "temperate")
		kinds[_kind_of(m)] = int(kinds.get(_kind_of(m), 0)) + 1
		check_eq(_symmetry_mismatches(m, 2), 0, "seed %d (%s): half-turn symmetric" % [seed_value, m.name])
		check(_all_reachable(m), "seed %d (%s): every start and field is reachable" % [seed_value, m.name])
		for u: Vector2 in m.uplink_spots:
			check(_reaches(m, m.starts[0], u), "seed %d (%s): uplink sites are reachable" % [seed_value, m.name])
		for s: Vector2 in m.starts:
			check(_hq_fits(m, s), "seed %d (%s): an HQ fits on every start" % [seed_value, m.name])
		var open: int = 0
		for t: int in m.terrain:
			if t == SimMap.Terrain.GROUND:
				open += 1
		var share: float = float(open) / float(m.w * m.h)
		check(share > 0.74 and share < 0.95, "seed %d (%s): %d%% open ground" % [seed_value, m.name, int(share * 100.0)])
	for kind: String in ["River Valley", "Highlands", "Lakeland", "Plains", "The Island"]:
		check(kinds.has(kind), "%s turns up among 24 seeds" % kind)
	check(not kinds.has("Open Ground"), "no seed needed the open-ground fallback")


func test_same_seed_gives_the_same_map() -> void:
	var a: SimMap = SimMapGen.generate(11, SimMapGen.STANDARD_CELLS, 2)
	var b: SimMap = SimMapGen.generate(11, SimMapGen.STANDARD_CELLS, 2)
	check(a.terrain == b.terrain and a.name == b.name, "generation is deterministic")
	check(a.heights == b.heights, "heights too")
	var c: SimMap = SimMapGen.generate(12, SimMapGen.STANDARD_CELLS, 2)
	check(a.terrain != c.terrain, "another seed gives another map")


func test_a_river_can_be_crossed_in_more_than_one_place() -> void:
	var found: int = 0
	for seed_value: int in range(1, 40):
		var m: SimMap = SimMapGen.generate(seed_value, SimMapGen.STANDARD_CELLS, 2, "temperate")
		if _kind_of(m) != "River Valley":
			continue
		found += 1
		var water: int = 0
		for t: int in m.terrain:
			if t == SimMap.Terrain.WATER:
				water += 1
		check(water > m.w, "seed %d: there is a river (%d water cells)" % [seed_value, water])
		# Dam the ford in the middle of the map: the bases must still connect.
		var mid: Vector2i = Vector2i(m.w / 2, m.h / 2)
		for dy: int in range(-5, 6):
			for dx: int in range(-5, 6):
				m.set_terrain(mid + Vector2i(dx, dy), SimMap.Terrain.WATER)
		m.finalize()
		check(_reaches(m, m.starts[0], m.starts[1]), "seed %d: the river has another crossing besides the middle" % seed_value)
		if found >= 4:
			break
	check(found >= 3, "river valleys turn up (%d found)" % found)


func test_four_player_maps_never_get_a_river() -> void:
	for seed_value: int in range(1, 13):
		var m: SimMap = SimMapGen.generate(seed_value, SimMapGen.LARGE_CELLS, 4)
		check(not ["River Valley", "Long Ridge", "Ice River", "Lava River"].has(_kind_of(m)), "seed %d: %s" % [seed_value, m.name])
		check_eq(_symmetry_mismatches(m, 4), 0, "seed %d: quarter-turn symmetric" % seed_value)
		check(_all_reachable(m), "seed %d: every start and field is reachable" % seed_value)


func test_every_region_has_its_own_kinds_of_country() -> void:
	for region: String in SimMapGen.REGIONS:
		var kinds: Dictionary[String, int] = {}
		var open_total: float = 0.0
		for seed_value: int in range(1, 25):
			var m: SimMap = SimMapGen.generate(seed_value, SimMapGen.STANDARD_CELLS, 2, region)
			check_eq(m.region, region, "the region asked for is the region given")
			kinds[_kind_of(m)] = int(kinds.get(_kind_of(m), 0)) + 1
			check_eq(_symmetry_mismatches(m, 2), 0, "%s seed %d (%s): half-turn symmetric" % [region, seed_value, m.name])
			check(_all_reachable(m), "%s seed %d (%s): every start and field is reachable" % [region, seed_value, m.name])
			for u: Vector2 in m.uplink_spots:
				check(_reaches(m, m.starts[0], u), "%s seed %d: uplink sites are reachable" % [region, seed_value])
			for s: Vector2 in m.starts:
				check(_hq_fits(m, s), "%s seed %d: an HQ fits on every start" % [region, seed_value])
			var open: int = 0
			for t: int in m.terrain:
				if t == SimMap.Terrain.GROUND:
					open += 1
			var share: float = float(open) / float(m.w * m.h)
			open_total += share / 24.0
			check(share > 0.72 and share < 0.96, "%s seed %d (%s): %d%% open ground" % [region, seed_value, m.name, int(share * 100.0)])
		for id: Variant in SimMapGen.REGION_KINDS[region]:
			var label: String = SimMapGen.THEME_NAMES[str(id)]
			check(kinds.has(label), "%s: %s turns up among 24 seeds" % [region, label])
		check(not kinds.has("Open Ground"), "%s: no seed needed the open-ground fallback" % region)
		check(open_total > 0.80 and open_total < 0.92, "%s: %d%% open ground on average" % [region, int(open_total * 100.0)])
	var a: SimMap = SimMapGen.generate(9, SimMapGen.STANDARD_CELLS, 2, "desert")
	var b: SimMap = SimMapGen.generate(9, SimMapGen.STANDARD_CELLS, 2, "tundra")
	check(a.terrain != b.terrain, "the same seed is a different battlefield in another region")
	check(a.terrain == SimMapGen.generate(9, SimMapGen.STANDARD_CELLS, 2, "desert").terrain, "and always the same one in the same region")
	check(a.starts == b.starts, "the bases stand in the same places")
	var seeded: SimMap = SimMapGen.generate(9, SimMapGen.STANDARD_CELLS, 2)
	check_eq(SimMapGen.generate(9, SimMapGen.STANDARD_CELLS, 2, "nowhere").region, seeded.region, "an unknown region falls back to the seed's")


func test_the_barrier_kinds_can_be_crossed() -> void:
	for region: String in SimMapGen.REGIONS:
		var barrier: String = SimMapGen.THEME_NAMES[str(SimMapGen.REGION_KINDS[region][0])]
		var found: int = 0
		for seed_value: int in range(1, 40):
			var m: SimMap = SimMapGen.generate(seed_value, SimMapGen.STANDARD_CELLS, 2, region)
			if _kind_of(m) != barrier:
				continue
			found += 1
			# Block the crossing in the middle of the map: the bases must still connect.
			var mid: Vector2i = Vector2i(m.w / 2, m.h / 2)
			for dy: int in range(-5, 6):
				for dx: int in range(-5, 6):
					m.set_terrain(mid + Vector2i(dx, dy), SimMap.Terrain.ROCK)
			m.finalize()
			check(_reaches(m, m.starts[0], m.starts[1]), "%s seed %d (%s): another way across besides the middle" % [region, seed_value, barrier])
			if found >= 3:
				break
		check(found >= 2, "%s: %s turns up (%d found)" % [region, barrier, found])


func test_seeds_spread_over_all_regions() -> void:
	var seen: Dictionary[String, int] = {}
	for seed_value: int in range(1, 41):
		var region: String = SimMapGen.pick_region(seed_value)
		seen[region] = int(seen.get(region, 0)) + 1
		check_eq(SimMapGen.pick_region(seed_value), region, "seed %d always gives the same region" % seed_value)
	for region: String in SimMapGen.REGIONS:
		check(int(seen.get(region, 0)) >= 4, "%s turns up among 40 seeds (%d times)" % [region, int(seen.get(region, 0))])


func test_match_settings_choose_the_region() -> void:
	var config: MatchConfig = MatchConfig.skirmish(3)
	config.region = "tundra"
	check_eq(SimSetup.create_match(config).map.region, "tundra", "a generated match takes the chosen region")
	config.map_id = "twin_fords"
	check_eq(SimSetup.create_match(config).map.region, "tundra", "so does a hand-made layout")
	config.region = ""
	check_eq(SimSetup.create_match(config).map.region, "temperate", "left alone, Twin Fords is in the Greenwood")
	config.map_id = "crater_ring"
	check_eq(SimSetup.create_match(config).map.region, "ashland", "and Crater Ring in the Cinder Wastes")
	config.region = "desert"
	var back: MatchConfig = SimSave.config_from_dict(SimSave.config_to_dict(config))
	check_eq(back.region, "desert", "the region survives a save")


func test_a_prize_map_has_a_walled_middle_with_four_gates() -> void:
	for region: String in SimMapGen.REGIONS:
		var kinds: Array = SimMapGen.REGION_KINDS[region]
		var prize: String = SimMapGen.THEME_NAMES[str(kinds[kinds.size() - 1])]
		var found: int = 0
		for players: int in [2, 4]:
			var cells: int = SimMapGen.STANDARD_CELLS if players == 2 else SimMapGen.LARGE_CELLS
			for seed_value: int in range(1, 60):
				var m: SimMap = SimMapGen.generate(seed_value, cells, players, region)
				if _kind_of(m) != prize:
					continue
				found += 1
				var middle: Vector2 = m.world_size() * 0.5
				check_eq(_symmetry_mismatches(m, players if players == 4 else 2), 0, "%s seed %d (%s, %d starts): symmetric" % [region, seed_value, prize, players])
				# The richest salvage of the map lies close round the middle.
				var inside: int = 0
				var outside_best: int = 0
				for f: Vector3 in m.field_spots:
					if Vector2(f.x, f.y).distance_to(middle) < 16.0:
						inside += int(f.z)
					else:
						outside_best = maxi(outside_best, int(f.z))
				check_eq(inside, SimMapGen.PRIZE_FIELD_AMOUNT, "%s seed %d: the prize is inside the wall" % [region, seed_value])
				check(inside > outside_best, "%s seed %d: and it is the richest place on the map" % [region, seed_value])
				check(_all_reachable(m), "%s seed %d: every start and field can be reached" % [region, seed_value])
				# Walk a circle through the wall: it is shut except at four gates.
				# (A way through is a stretch at least two cells wide; a single
				# open sample where the circle clips a corner does not count.)
				var wall: Vector3 = SimMapGen.PRIZE_WALLS[str(kinds[kinds.size() - 1])]
				var ring: float = (wall.y + 1.0) * SimMap.CELL
				var steps: int = 720
				var two_cells: int = int(2.0 * SimMap.CELL / (TAU * ring / float(steps)))
				var first_shut: int = 0
				while first_shut < steps and m.is_passable(middle + Vector2.from_angle(TAU * float(first_shut) / float(steps)) * ring):
					first_shut += 1
				var open_runs: int = 0
				var run: int = 0
				for k: int in steps + 1:
					var ang: float = TAU * float(first_shut + k) / float(steps)
					if m.is_passable(middle + Vector2.from_angle(ang) * ring):
						run += 1
					else:
						if run >= two_cells:
							open_runs += 1
						run = 0
				check_eq(open_runs, 4, "%s seed %d (%s): four ways through the wall" % [region, seed_value, prize])
				break
		check(found >= 2, "%s: %s turns up for two and for four starts" % [region, prize])


func test_the_setup_preview_shows_the_map_the_match_gets() -> void:
	var config: MatchConfig = MatchConfig.skirmish(31)
	var preview: MapPreview = MapPreview.new()
	preview.show_config(config)
	check_eq(preview.seats_shown(), 2, "two seats, two starts drawn")
	var w: SimWorld = SimSetup.create_match(config)
	check(preview.caption.begins_with(w.map.name), "the picture is of the map the match is played on (%s)" % preview.caption)
	check(SimSetup.map_for(config).terrain == w.map.terrain, "the same land, cell for cell")
	config.add_ai("nomad", 1, "Third", config.team_of(0))
	config.add_ai("vesper", 1, "Fourth", config.team_of(1))
	preview.show_config(config)
	check_eq(preview.seats_shown(), 4, "four seats, four starts drawn")
	preview.free()


func test_generated_maps_have_fair_high_ground() -> void:
	for region: String in SimMapGen.REGIONS:
		var with_hills: int = 0
		for players: int in [2, 4]:
			var cells: int = SimMapGen.STANDARD_CELLS if players == 2 else SimMapGen.LARGE_CELLS
			for seed_value: int in range(1, 9):
				var m: SimMap = SimMapGen.generate(seed_value, cells, players, region)
				var count: int = 0
				var wrong_ground: int = 0
				var lopsided: int = 0
				var near_start: int = 0
				for y: int in m.h:
					for x: int in m.w:
						if m.high[y * m.w + x] == 0:
							continue
						count += 1
						var t: int = m.terrain[y * m.w + x]
						if t == SimMap.Terrain.ROCK or t == SimMap.Terrain.WATER:
							wrong_ground += 1
						for image: Vector2i in SimMapGen.cell_images(m, Vector2i(x, y), 4 if players == 4 else 2):
							if m.high[image.y * m.w + image.x] == 0:
								lopsided += 1
						for s: Vector2 in m.starts:
							if m.cell_center(Vector2i(x, y)).distance_to(s) < float(SimMapGen.START_CLEAR_CELLS) * SimMap.CELL:
								near_start += 1
				if count > 0:
					with_hills += 1
				check_eq(wrong_ground, 0, "%s seed %d: no high ground on rock or water" % [region, seed_value])
				check_eq(lopsided, 0, "%s seed %d (%d starts): every side has the same hills" % [region, seed_value, players])
				check_eq(near_start, 0, "%s seed %d: every base stands on level ground" % [region, seed_value])
				check(count < m.w * m.h / 8, "%s seed %d: hills are the exception (%d cells)" % [region, seed_value, count])
				check(m.is_high(m.starts[0]) == false, "%s seed %d: a start is not high" % [region, seed_value])
		check(with_hills >= 12, "%s: nearly every map has some high ground (%d of 16)" % [region, with_hills])
	var a: SimMap = SimMapGen.generate(5, SimMapGen.STANDARD_CELLS, 2, "desert")
	var b: SimMap = SimMapGen.generate(5, SimMapGen.STANDARD_CELLS, 2, "desert")
	check(a.high == b.high, "the same seed gives the same hills")


func test_buildings_need_level_ground() -> void:
	var w: SimWorld = SimTestUtil.make_world()
	var hill: Vector2i = Vector2i(20, 20)
	for dy: int in 8:
		for dx: int in 8:
			w.map.high[(hill.y + dy) * w.map.w + hill.x + dx] = 1
	check(w.map.is_bank(hill), "the edge of a hilltop is bank")
	check(w.map.is_bank(hill + Vector2i(-1, 3)), "so is the ground at its foot")
	check(not w.map.is_bank(hill + Vector2i(3, 3)), "the middle of the top is level")
	check(not w.map.is_bank(hill + Vector2i(-4, 3)), "and so is the ground well clear of it")
	check(not w.map.is_bank(Vector2i(-1, 0)), "off the map nothing is bank")
	# Any building of theirs that needs nothing else built first.
	var def: EntityDef = null
	for candidate: EntityDef in w.data.entities.values():
		if candidate.is_building and candidate.buildable and candidate.blocks and candidate.faction == "aegis" and candidate.requires.is_empty():
			def = candidate
			break
	check(def != null, "there is a building to try")
	if def == null:
		return
	var on_top: String = SimEconomy.placement_error(w, 0, def, hill + Vector2i(3, 3))
	var across: String = SimEconomy.placement_error(w, 0, def, hill + Vector2i(-1, 3))
	check(across == "Too steep to build on", "a turret cannot be built across the bank (%s)" % across)
	check(on_top != "Too steep to build on", "but it can on the level top (%s)" % on_top)
	# Units cross the bank like any other ground.
	var tank: SimEntity = w.spawn_unit("bulwark", 0, w.map.cell_center(hill + Vector2i(-5, 3)))
	w.push_command(SimCommand.move(0, PackedInt32Array([tank.id]), w.map.cell_center(hill + Vector2i(3, 3))))
	SimTestUtil.run(w, 20 * 20)
	check(w.map.is_high(tank.pos), "a tank drives up onto the hill")


func test_hand_made_layouts_have_fair_high_ground() -> void:
	for id: String in SimMapGen.layout_ids():
		var m: SimMap = SimMapGen.load_layout(id)
		check(m != null, "%s loads" % id)
		if m == null:
			continue
		var order: int = 4 if m.starts.size() == 4 else 2
		var count: int = 0
		var wrong: int = 0
		var lopsided: int = 0
		for y: int in m.h:
			for x: int in m.w:
				if m.high[y * m.w + x] == 0:
					continue
				count += 1
				var t: int = m.terrain[y * m.w + x]
				if t == SimMap.Terrain.ROCK or t == SimMap.Terrain.WATER:
					wrong += 1
				for image: Vector2i in SimMapGen.cell_images(m, Vector2i(x, y), order):
					if m.high[image.y * m.w + image.x] == 0:
						lopsided += 1
		check(count >= 30, "%s has hills (%d cells of high ground)" % [id, count])
		check(count < m.w * m.h / 8, "%s: hills are the exception" % id)
		check_eq(wrong, 0, "%s: no high ground on rock or water" % id)
		check_eq(lopsided, 0, "%s: every side has the same hills" % id)
		for s: Vector2 in m.starts:
			check(not m.is_high(s), "%s: a start is on level ground" % id)
			check(not m.is_bank(m.cell_of(s)), "%s: and not on a bank" % id)
		check(SimMapGen._starts_connected(m), "%s: still connected" % id)
