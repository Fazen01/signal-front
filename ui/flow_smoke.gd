class_name FlowSmoke
extends Node
## Headless walk through the whole game loop: main menu -> skirmish setup ->
## match -> surrender -> result screen -> back to the menu. Started by the
## Game autoload when the user argument --flow-smoke is present; check.sh
## treats any "BOOT FAILED" line or script error as a failure.

var _stage: int = 0
var _wait: int = 0
var _frames: int = 0


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
				menu.open_skirmish()
				_expect(menu.is_setup_open(), "skirmish setup opens")
				_next(5)
		1:
			var menu: MainMenu = scene as MainMenu
			if menu != null:
				menu.choose_factions("foundry", "aegis")
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
				battle.surrender()
				_next(30)
		5:
			var battle: BattleScene = scene as BattleScene
			if battle != null:
				_expect(battle.world.game_over, "surrender ends the match")
				_expect(battle.menus.result_shown, "result screen is shown")
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
			if scene is MainMenu:
				print("Flow smoke finished: menu -> skirmish -> match -> result -> menu in %d frames" % _frames)
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
