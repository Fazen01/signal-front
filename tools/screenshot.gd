extends Node
## Screenshot harness for sessions that cannot see the game. Loads a scene,
## lets it run, then saves PNGs of the viewport into res://screenshots/
## (git-ignored). Run through tools/screenshot.sh.
##
## User args: --scene=res://scenes/battle.tscn --frames=120 --name=battle
##            --script=<name>  optional scripted camera/selection steps

var _scene_path: String = "res://scenes/battle.tscn"
var _frames: int = 120
var _shot_name: String = "shot"
var _script_name: String = ""
var _count: int = 0
var _scene: Node = null


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			_scene_path = arg.trim_prefix("--scene=")
		elif arg.begins_with("--frames="):
			_frames = int(arg.trim_prefix("--frames="))
		elif arg.begins_with("--name="):
			_shot_name = arg.trim_prefix("--name=")
		elif arg.begins_with("--script="):
			_script_name = arg.trim_prefix("--script=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots"))
	var packed: PackedScene = load(_scene_path) as PackedScene
	if packed == null:
		print("BOOT FAILED: cannot load %s" % _scene_path)
		get_tree().quit(1)
		return
	_scene = packed.instantiate()
	add_child(_scene)


func _process(_delta: float) -> void:
	_count += 1
	var battle: BattleScene = _scene as BattleScene
	if battle != null and _script_name != "":
		_run_script(battle)
	var menu: MainMenu = _scene as MainMenu
	if menu != null and _script_name == "setup" and _count == 3:
		menu.open_skirmish()
	if menu != null and _script_name == "help" and _count == 3:
		menu.call("_show", menu.get("_help"))
	if _count == _frames:
		_save(_shot_name)
		get_tree().quit(0)


func _save(shot: String) -> void:
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = "res://screenshots/%s.png" % shot
	img.save_png(path)
	print("Saved %s (%dx%d)" % [path, img.get_width(), img.get_height()])


func _run_script(battle: BattleScene) -> void:
	match _script_name:
		"closeup":
			if _count == 2:
				battle.cam.set_distance(20.0)
		"select":
			if _count == 5:
				var ids: Array[int] = []
				for e: SimEntity in battle.world.entities:
					if e.owner == battle.local_player:
						ids.append(e.id)
				battle.controller.set_selection(ids)
		"hud_builder":
			if _count == 5:
				for e: SimEntity in battle.world.entities:
					if e.owner == battle.local_player and e.def != null and e.def.builder:
						battle.controller.set_selection([e.id])
						break
			if _count == 8:
				battle.begin_placement(battle.world.data.entity("barracks"))
				Input.warp_mouse(Vector2(1050.0, 380.0))
		"hud_hq":
			if _count == 5:
				for e: SimEntity in battle.world.entities:
					if e.owner == battle.local_player and e.def != null and e.def.signal_root:
						battle.controller.set_selection([e.id])
						battle.world.push_command(SimCommand.train(battle.local_player, e.id, "hauler"))
						battle.world.push_command(SimCommand.train(battle.local_player, e.id, "field_engineer"))
				battle.hud.push_alert("Bandwidth limit reached - build Relays", Hud.RED)
		"signal":
			if _count == 2:
				# A relay chain towards the middle, one cut-off relay, and
				# units both inside and outside coverage.
				var w: SimWorld = battle.world
				var me: int = battle.local_player
				var hq_pos: Vector2 = w.players[me].start_pos
				var dir: Vector2 = (w.map.world_size() * 0.5 - hq_pos).normalized()
				var side: Vector2 = Vector2(-dir.y, dir.x)
				for k: int in 2:
					var at: Vector2 = hq_pos + dir * (26.0 * float(k + 1))
					w.map.set_terrain(w.map.cell_of(at), SimMap.Terrain.GROUND)
					w.spawn_building("relay", me, w.map.cell_of(at), true)
				for k: int in 4:
					w.spawn_unit("bulwark", me, hq_pos + dir * 40.0 + side * (float(k) * 3.0 - 4.0))
					w.spawn_unit("trooper", me, hq_pos + dir * 74.0 + side * (float(k) * 2.0 - 3.0))
				battle.cam.set_distance(80.0)
				battle.cam.center_on(hq_pos + dir * 36.0)
		"directives":
			if _count == 3:
				var pl: SimPlayer = battle.world.players[battle.local_player]
				pl.command_points = 6
				pl.unlocked["recon_sweep"] = true
				pl.unlocked["shell_barrage"] = true
				pl.unlocked["blackout"] = true
				var hq_at: Vector2 = pl.start_pos
				battle.world.push_command(SimCommand.directive(battle.local_player, "recon_sweep", hq_at + Vector2(44.0, 30.0)))
				battle.world.push_command(SimCommand.directive(battle.local_player, "shell_barrage", hq_at + Vector2(16.0, 22.0)))
				battle.begin_directive(battle.world.data.directive("blackout"))
				battle.cam.set_distance(70.0)
				battle.cam.center_on(hq_at + Vector2(20.0, 16.0))
				for e: SimEntity in battle.world.entities:
					if e.owner == battle.local_player and e.def != null and e.def.is_armed() and e.kind == SimEntity.Kind.UNIT:
						e.rank = 2
		"result":
			if _count == 5:
				battle.world.push_command(SimCommand.surrender(battle.local_player))
		"pause":
			if _count == 5:
				battle.toggle_pause_menu()
		"wide":
			if _count == 2:
				battle.cam.set_distance(95.0)
				battle.cam.center_on(battle.world.map.world_size() * 0.5)
