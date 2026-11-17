class_name FlowSmoke
extends Node
## Headless walk through the whole game loop: main menu -> skirmish setup ->
## match -> surrender -> result screen -> back to the menu. Started by the
## Game autoload when the user argument --flow-smoke is present; check.sh
## treats any "BOOT FAILED" line or script error as a failure.

const SMOKE_SLOT: String = "smoke_slot"
const SMOKE_AUTO: String = "smoke_auto"

var _stage: int = 0
var _wait: int = 0
var _frames: int = 0
var _saved_tick: int = 0
var _saved_entities: int = 0


func _process(_delta: float) -> void:
	_frames += 1
	if _wait > 0:
		_wait -= 1
		return
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	match _stage:
		0:
			var menu: MainMenu = scene as MainMenu
			if menu != null:
				var too_big: Array[String] = menu.pages_too_big()
				_expect(too_big.is_empty(), "every menu page fits on the screen (%s)" % ", ".join(PackedStringArray(too_big)))
				menu.open_skirmish()
				_expect(menu.is_setup_open(), "skirmish setup opens")
				_next(5)
		1:
			var menu: MainMenu = scene as MainMenu
			if menu != null:
				menu.choose_factions("foundry", "aegis")
				# Everybody on one team is no match; allies are picked by team.
				menu.choose_team(1, 0)
				_expect(not menu.can_start(), "a match with one team cannot start")
				menu.choose_team(1, 1)
				_expect(menu.can_start(), "two teams can")
				menu.choose_map("", 2)
				menu.choose_team(2, 0)
				var lineup: MatchConfig = menu.build_config()
				_expect(lineup.player_count() == 3 and lineup.team_of(2) == lineup.team_of(0) and lineup.side_count() == 2, "an AI can be put on the player's team")
				menu.choose_map("", 1)
				menu.start_skirmish()
				_next(5)
		2:
			var battle: BattleScene = scene as BattleScene
			if battle != null and battle.world != null:
				_expect(not battle.world.game_over, "match is running")
				_expect(battle.world.players[0].faction.id == "foundry", "the chosen faction is in play")
				_foundry_steps(battle)
				_next(90)
		3:
			var battle: BattleScene = scene as BattleScene
			if battle != null:
				_expect(battle.world.tick_count > 20, "simulation advanced (%d ticks)" % battle.world.tick_count)
				var factory: SimEntity = null
				for e: SimEntity in battle.world.entities:
					if e.owner == battle.local_player and e.def != null and e.def.packs_to != "":
						factory = e
				_expect(factory != null, "the Crawler deployed into a factory")
				if factory != null:
					battle.controller.set_selection([factory.id])
					var pack_key: InputEventKey = InputEventKey.new()
					pack_key.physical_keycode = KEY_Y
					pack_key.pressed = true
					_expect(battle.hud.handle_hotkey(pack_key), "Y packs the factory up")
				battle.toggle_pause_menu()
				_expect(battle.paused and battle.menus.is_pause_open(), "pause menu opens")
				var ticks: int = battle.world.tick_count
				battle.set_meta("paused_at", ticks)
				_next(10)
		4:
			var battle: BattleScene = scene as BattleScene
			if battle != null:
				_expect(battle.world.tick_count == int(battle.get_meta("paused_at")), "simulation holds while paused")
				battle.menus.open_saves(false)
				_expect(battle.menus.is_pause_open(), "the save slots open from the pause menu")
				battle.menus.open_settings()
				var cramped: Array[String] = battle.menus.panels_too_big()
				_expect(cramped.is_empty(), "the pause menu, its settings and the save slots fit between the bars (%s)" % ", ".join(PackedStringArray(cramped)))
				battle.menus.close_settings()
				battle.menus.close_saves()
				# A slot of the test's own, so that nobody's saves are touched.
				_expect(battle.save_game(SMOKE_SLOT), "the match saves to a slot")
				# The autosave, also into a slot of the test's own: nothing while
				# the match is paused, nothing before its time, then one save.
				battle.autosave_slot = SMOKE_AUTO
				SimSave.delete_slot(SMOKE_AUTO)
				var minutes: int = GameSettings.autosave_minutes
				GameSettings.autosave_minutes = 2
				battle.tick_autosave(500.0)
				_expect(not SimSave.has_slot(SMOKE_AUTO), "no autosave while the match is paused")
				battle.paused = false
				battle.tick_autosave(60.0)
				_expect(not SimSave.has_slot(SMOKE_AUTO), "none before its time")
				battle.tick_autosave(61.0)
				_expect(SimSave.has_slot(SMOKE_AUTO), "after two minutes of play the game saves itself")
				_expect(int(SimSave.slot_info(SMOKE_AUTO).get("tick", -1)) == battle.world.tick_count, "which a load screen can describe")
				SimSave.delete_slot(SMOKE_AUTO)
				GameSettings.autosave_minutes = 0
				battle.tick_autosave(5000.0)
				_expect(not SimSave.has_slot(SMOKE_AUTO), "and never, with autosave switched off")
				GameSettings.autosave_minutes = minutes
				battle.paused = true
				_saved_tick = battle.world.tick_count
				_saved_entities = battle.world.entities.size()
				battle.surrender()
				_next(30)
		5:
			var battle: BattleScene = scene as BattleScene
			if battle != null:
				_expect(battle.world.game_over, "surrender ends the match")
				_expect(battle.menus.result_shown, "result screen is shown")
				var tall: Array[String] = battle.menus.panels_too_big()
				_expect(tall.is_empty(), "and fits between the bars (%s)" % ", ".join(PackedStringArray(tall)))
				_expect(battle.world.winner != battle.local_player, "the surrendering player lost")
				battle.play_again()
				_next(20)
		6:
			var battle: BattleScene = scene as BattleScene
			if battle != null and battle.world != null:
				_expect(not battle.world.game_over, "play again starts a fresh match")
				battle.quit_to_menu()
				_next(10)
		7:
			var menu: MainMenu = scene as MainMenu
			if menu != null:
				_expect(SimSave.has_slot(SMOKE_SLOT), "a save exists for the menu to load")
				menu.open_loads()
				menu.load_saved(SMOKE_SLOT)
				_next(10)
		8:
			var battle: BattleScene = scene as BattleScene
			if battle != null and battle.world != null:
				_expect(battle.world.tick_count >= _saved_tick and battle.world.tick_count < _saved_tick + 40, "the loaded match resumes where it was saved (tick %d)" % battle.world.tick_count)
				_expect(absi(battle.world.entities.size() - _saved_entities) <= 3, "with the same forces on the field")
				_expect(battle.world.players[0].faction.id == "foundry", "and the same factions")
				SimSave.delete_slot(SMOKE_SLOT)
				battle.quit_to_menu()
				_next(10)
		9:
			var menu: MainMenu = scene as MainMenu
			if menu != null:
				menu.start_tutorial("directives")
				_next(10)
		10:
			# Play the Directives tutorial through its real objectives.
			var battle: BattleScene = scene as BattleScene
			if battle != null and battle.world != null and battle.world.tutorial != null:
				_expect(battle.tutorial_panel != null, "the objective panel is shown")
				_expect(not battle.save_game(), "tutorials refuse to save")
				var w: SimWorld = battle.world
				var squad_at: Vector2 = w.tutorial.steps[1].marker
				for id: String in ["recon_sweep", "shell_barrage", "field_repair", "signal_surge"]:
					w.push_command(SimCommand.unlock(SimTutorial.PLAYER, id))
				w.push_command(SimCommand.directive(SimTutorial.PLAYER, "recon_sweep", squad_at))
				w.push_command(SimCommand.directive(SimTutorial.PLAYER, "shell_barrage", squad_at))
				w.push_command(SimCommand.directive(SimTutorial.PLAYER, "field_repair", w.tutorial.steps[3].marker))
				w.push_command(SimCommand.directive(SimTutorial.PLAYER, "signal_surge", Vector2.ZERO))
				_next(120)
		11:
			var battle: BattleScene = scene as BattleScene
			if battle != null:
				_expect(battle.world.tutorial.done, "the tutorial completes (objective %d)" % battle.world.tutorial.index)
				_expect(battle.menus.result_shown, "the mission-complete screen is shown")
				battle.quit_to_menu()
				_next(10)
		12:
			if scene is MainMenu:
				print("Flow smoke finished: menu -> skirmish -> match -> result -> menu -> load -> tutorial -> menu in %d frames" % _frames)
				get_tree().quit(0)
	if _frames > 3000:
		print("BOOT FAILED: flow smoke stuck at stage %d" % _stage)
		get_tree().quit(1)


## Drives the Foundry-only interface paths: the Deploy card entry, the
## deploy ghost and Pack up.
func _foundry_steps(battle: BattleScene) -> void:
	var w: SimWorld = battle.world
	var me: int = battle.local_player
	var hq_pos: Vector2 = w.players[me].start_pos
	var crawler: SimEntity = w.spawn_unit("crawler", me, w.map.nearest_free_pos(hq_pos + Vector2(10.0, 10.0)))
	battle.controller.set_selection([crawler.id])
	var deploy: Hud.CardEntry = null
	for i: int in 12:
		var key: InputEventKey = InputEventKey.new()
		key.physical_keycode = KEY_Y
		key.pressed = true
		if i == 0 and battle.hud.handle_hotkey(key):
			deploy = Hud.CardEntry.new()
	_expect(deploy != null, "Y starts deploy placement for a Crawler")
	_expect(battle.placing != null and battle.placing_deploy, "deploy ghost is shown")
	battle.ghost_cell = w.map.cell_of(crawler.pos) - Vector2i(1, 1)
	_expect(battle.on_left_click(Vector2.ZERO, false), "deploy click consumed")
	_expect(battle.placing == null, "placement ended")


func _next(wait_frames: int) -> void:
	_stage += 1
	_wait = wait_frames


func _expect(cond: bool, what: String) -> void:
	if not cond:
		print("BOOT FAILED: flow check '%s' (stage %d)" % [what, _stage])
