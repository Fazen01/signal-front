extends TestCase
## Saving and loading a skirmish.


func _play(config: MatchConfig, ticks: int) -> SimWorld:
	var w: SimWorld = SimSetup.create_match(config)
	w.collect_events = false
	SimTestUtil.run(w, ticks)
	return w


func test_restored_match_continues_identically() -> void:
	for factions: Array in [["aegis", "foundry"], ["nomad", "aegis"]]:
		var config: MatchConfig = MatchConfig.ai_vs_ai(17)
		config.factions.assign(factions)
		var original: SimWorld = _play(config, 20 * 200)
		var snapshot: Dictionary = SimSave.to_dict(original, config)
		var restored: SimWorld = SimSave.from_dict(snapshot)
		check(restored != null, "%s: snapshot restores" % str(factions))
		if restored == null:
			continue
		restored.collect_events = false
		check_eq(restored.tick_count, original.tick_count, "same tick")
		check_eq(restored.entities.size(), original.entities.size(), "same entity count")
		check_eq(restored.state_hash(), original.state_hash(), "same state right after loading")
		check_eq(restored.players[0].salvage, original.players[0].salvage, "same salvage")
		check(restored.coverage[0] == original.coverage[0], "same coverage")
		SimTestUtil.run(original, 20 * 120)
		SimTestUtil.run(restored, 20 * 120)
		check_eq(restored.state_hash(), original.state_hash(), "%s: still identical two minutes later" % str(factions))
		check_eq(restored.players[1].stat_kills, original.players[1].stat_kills, "same kills")
		check_eq(restored.ais[0].waves_sent, original.ais[0].waves_sent, "the AI carried on with the same plan")


func test_snapshot_survives_the_file_format() -> void:
	var config: MatchConfig = MatchConfig.ai_vs_ai(23)
	var w: SimWorld = _play(config, 20 * 90)
	check(SimSave.save_to_file(w, config), "save written")
	check(SimSave.has_save(), "save slot is occupied")
	var loaded: Dictionary = SimSave.read_file()
	check(not loaded.is_empty(), "save read back")
	var restored: SimWorld = SimSave.from_dict(loaded)
	check(restored != null, "restores from the file")
	if restored != null:
		check_eq(restored.state_hash(), w.state_hash(), "file round trip keeps the state")
		var c: MatchConfig = SimSave.config_from_dict(loaded["config"])
		check_eq(c.seed_value, 23, "configuration comes back")
		check_eq(c.factions, config.factions, "factions come back")
		check_eq(restored.players[0].faction.id, w.players[0].faction.id, "faction objects are re-linked")
		var with_orders: int = 0
		for e: SimEntity in restored.entities:
			if e.def != null and not e.orders.is_empty():
				with_orders += 1
		check(with_orders > 0, "unit orders are restored")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SimSave.PATH))


func test_bad_saves_are_refused() -> void:
	check(SimSave.from_dict({"version": 999}) == null, "a save from another version is refused")
	var config: MatchConfig = MatchConfig.skirmish(5)
	config.is_ai = [false, false]
	var w: SimWorld = _play(config, 40)
	var snapshot: Dictionary = SimSave.to_dict(w, config)
	var entities: Array = snapshot["entities"]
	var first: Dictionary = entities[0]
	first["def_id"] = "no_such_thing"
	check(SimSave.from_dict(snapshot) == null, "a save naming an unknown unit is refused")


func test_ai_memory_survives_a_save_mid_war() -> void:
	var config: MatchConfig = MatchConfig.ai_vs_ai(19)
	config.factions.assign(["foundry", "nomad"])
	var w: SimWorld = _play(config, 20 * 60 * 8)
	var ai: SimAI = w.ais[0]
	check(ai.waves_sent > 0, "the war has started before the save (%d waves)" % ai.waves_sent)
	# Make sure the newer kinds of AI memory are not empty when saved.
	ai._lost_spots.append(Vector3(30.0, 40.0, float(w.tick_count)))
	ai._blocked_until["depot"] = w.tick_count + 600
	ai.timid = 1
	check(SimSave.save_to_file(w, config), "save written")
	var restored: SimWorld = SimSave.from_dict(SimSave.read_file())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SimSave.PATH))
	check(restored != null, "restores from the file")
	if restored == null:
		return
	restored.collect_events = false
	var back: SimAI = restored.ais[0]
	check_eq(back._lost_spots.size(), ai._lost_spots.size(), "lost-site memory comes back")
	check_eq(back._blocked_until.get("depot", -1), ai._blocked_until["depot"], "blocked build entries come back")
	check_eq(back.timid, 1, "retreat count comes back")
	check_eq(back.wave_state, ai.wave_state, "wave state comes back")
	check_eq(back.wave_ids, ai.wave_ids, "the wave's members come back")
	check_eq(restored.state_hash(), w.state_hash(), "same state right after loading")
	SimTestUtil.run(w, 20 * 90)
	SimTestUtil.run(restored, 20 * 90)
	check_eq(restored.state_hash(), w.state_hash(), "still identical 90 seconds later")
	check_eq(restored.ais[0].waves_sent, w.ais[0].waves_sent, "the AI carried on with the same plan")
