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
				menu.start_skirmish()
				_next(5)
		2:
			var battle: BattleScene = scene as BattleScene
			if battle != null and battle.world != null:
				_expect(not battle.world.game_over, "match is running")
				_next(90)
		3:
			var battle: BattleScene = scene as BattleScene
			if battle != null:
				_expect(battle.world.tick_count > 20, "simulation advanced (%d ticks)" % battle.world.tick_count)
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


func _next(wait_frames: int) -> void:
	_stage += 1
	_wait = wait_frames


func _expect(cond: bool, what: String) -> void:
	if not cond:
		print("BOOT FAILED: flow check '%s' (stage %d)" % [what, _stage])
