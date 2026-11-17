extends TestCase
## Saving and loading a skirmish.


const TEST_SLOT: String = "test_slot"
const OTHER_SLOT: String = "test_slot_two"


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
	SimSave.delete_slot(TEST_SLOT)
	check(not SimSave.has_slot(TEST_SLOT), "the slot starts empty")
	check(SimSave.save_to_slot(w, config, TEST_SLOT), "save written")
	check(SimSave.has_slot(TEST_SLOT), "save slot is occupied")
	var loaded: Dictionary = SimSave.read_slot(TEST_SLOT)
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
	SimSave.delete_slot(TEST_SLOT)
	check(not SimSave.has_slot(TEST_SLOT), "and the slot can be emptied again")


func test_slots_are_separate_and_describe_themselves() -> void:
	var first: MatchConfig = MatchConfig.ai_vs_ai(31)
	var second: MatchConfig = MatchConfig.ai_vs_ai(32)
	var a: SimWorld = _play(first, 20 * 20)
	var b: SimWorld = _play(second, 20 * 65)
	SimSave.delete_slot(TEST_SLOT)
	SimSave.delete_slot(OTHER_SLOT)
	check(SimSave.read_slot(TEST_SLOT).is_empty(), "an empty slot reads as nothing")
	check(SimSave.slot_info(TEST_SLOT).is_empty(), "and has nothing to say")
	check_eq(SimSave.describe({}), "empty", "which a save screen shows as empty")
	check(SimSave.save_to_slot(a, first, TEST_SLOT) and SimSave.save_to_slot(b, second, OTHER_SLOT), "two matches saved to two slots")
	var info: Dictionary = SimSave.slot_info(OTHER_SLOT)
	check_eq(int(info.get("tick", -1)), b.tick_count, "a slot knows how far into the match it is")
	check_eq(str(info.get("map", "")), b.map.name, "and on which map")
	check_eq((info.get("sides", []) as Array).size(), 2, "and who is playing")
	check(absi(int(info.get("saved_at", 0)) - int(Time.get_unix_time_from_system())) < 120, "and when it was written")
	var text: String = SimSave.describe(info)
	check(text.contains(b.map.name) and text.contains("1:05 in") and text.contains("saved "), "described in a line: %s" % text)
	var back_a: SimWorld = SimSave.from_dict(SimSave.read_slot(TEST_SLOT))
	var back_b: SimWorld = SimSave.from_dict(SimSave.read_slot(OTHER_SLOT))
	check(back_a != null and back_b != null, "both load")
	if back_a != null and back_b != null:
		check_eq(back_a.state_hash(), a.state_hash(), "the first slot holds the first match")
		check_eq(back_b.state_hash(), b.state_hash(), "the second slot holds the second")
	# Saving over a slot replaces it.
	check(SimSave.save_to_slot(b, second, TEST_SLOT), "saved over the first slot")
	check_eq(int(SimSave.slot_info(TEST_SLOT).get("tick", -1)), b.tick_count, "which now holds the other match")
	check(not SimSave.save_to_slot(a, first, "../elsewhere"), "a slot name that is not a plain word is refused")
	check(not FileAccess.file_exists(SimSave.path_of(TEST_SLOT) + ".part"), "nothing half-written is left behind")
	SimSave.delete_slot(TEST_SLOT)
	SimSave.delete_slot(OTHER_SLOT)


func test_the_named_slots_and_settings_line_up() -> void:
	check_eq(SimSave.SLOTS.size(), SimSave.MANUAL_SLOTS.size() + 1, "the autosave and the slots a player saves to")
	check(SimSave.SLOTS.has(SimSave.AUTO) and not SimSave.MANUAL_SLOTS.has(SimSave.AUTO), "the autosave is not one a player saves to")
	for slot: String in SimSave.SLOTS:
		check(SimSave.SLOT_NAMES.has(slot), "%s has a name" % slot)
		check(slot.is_valid_identifier(), "%s is a plain word" % slot)
	check_eq(GameSettings.AUTOSAVE_MINUTES.size(), GameSettings.AUTOSAVE_NAMES.size(), "every autosave choice has a name")
	check(GameSettings.AUTOSAVE_MINUTES.has(0), "autosave can be switched off")
	check(GameSettings.AUTOSAVE_MINUTES.has(GameSettings.autosave_minutes), "the setting is one of the choices")


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


func test_the_hour_a_match_is_lit_for_survives_a_save() -> void:
	var config: MatchConfig = MatchConfig.skirmish(3)
	check_eq(config.time_of_day, "", "a match is lit for midday unless told otherwise")
	config.time_of_day = "evening"
	var again: MatchConfig = SimSave.config_from_dict(SimSave.config_to_dict(config))
	check_eq(again.time_of_day, "evening", "the hour picked in the setup is kept")
	for id: String in SceneLight.TIMES:
		check(SceneLight.TIME_NAMES.has(id), "%s has a name for the setup screen" % id)
	check(MainMenu.LIGHT_ORDER[0] == "noon", "midday is the first choice")
	for id: String in MainMenu.LIGHT_ORDER:
		check(SceneLight.TIMES.has(id), "%s is an hour the light knows" % id)
