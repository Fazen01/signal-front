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
	if _script_name == "midmatch":
		# An AI-vs-AI match, fast-forwarded; the capture follows the fighting.
		var mgame: GameState = get_node_or_null("/root/Game") as GameState
		if mgame != null:
			var mc: MatchConfig = MatchConfig.ai_vs_ai(7)
			mc.factions = ["aegis", "foundry"]
			mgame.pending_config = mc
	if _script_name.begins_with("tutorial_"):
		var tgame: GameState = get_node_or_null("/root/Game") as GameState
		if tgame != null:
			tgame.pending_config = SimTutorial.config_for(_script_name.trim_prefix("tutorial_"))
	if _script_name == "foundry" or _script_name == "nomad" or _script_name == "vesper" or _script_name == "verdigris":
		# Play as another faction for this capture.
		var config: MatchConfig = MatchConfig.skirmish(1)
		config.factions = [_script_name, "aegis"]
		var game: GameState = get_node_or_null("/root/Game") as GameState
		if game != null:
			game.pending_config = config
	if _script_name.begins_with("layout_"):
		# "layout_<map id>": a hand-made map seen whole, with fog off.
		var lconfig: MatchConfig = MatchConfig.skirmish(1)
		lconfig.map_id = _script_name.trim_prefix("layout_")
		var players: int = int(SimMapGen.layout_info(lconfig.map_id)["players"])
		for extra: int in players - 2:
			lconfig.add_ai("aegis", 1, "AI %d" % (extra + 2))
		var lgame: GameState = get_node_or_null("/root/Game") as GameState
		if lgame != null:
			lgame.pending_config = lconfig
	if _script_name.begins_with("base_"):
		# "base_<faction>": play as that faction, with a full base and one of
		# everything it builds set out in front of it.
		var bgame: GameState = get_node_or_null("/root/Game") as GameState
		if bgame != null:
			var bconfig: MatchConfig = MatchConfig.skirmish(1)
			bconfig.factions = [_script_name.trim_prefix("base_"), "aegis"]
			bconfig.region = "temperate"
			bgame.pending_config = bconfig
	if _script_name.begins_with("time_"):
		# "time_<hour>": the Greenwood on seed 4 at that hour, seen from the base.
		var tgame2: GameState = get_node_or_null("/root/Game") as GameState
		if tgame2 != null:
			var tconfig: MatchConfig = MatchConfig.skirmish(4)
			tconfig.region = "temperate"
			tconfig.time_of_day = _script_name.trim_prefix("time_")
			tgame2.pending_config = tconfig
	if _script_name.begins_with("crowd_"):
		var kgame: GameState = get_node_or_null("/root/Game") as GameState
		var kdef: EntityDef = GameData.shared().entity(_script_name.trim_prefix("crowd_"))
		if kgame != null and kdef != null:
			var kconfig: MatchConfig = MatchConfig.skirmish(1)
			kconfig.factions = [kdef.faction, "aegis"]
			kconfig.region = "temperate"
			kgame.pending_config = kconfig
	if _script_name.begins_with("duel_"):
		# "duel_<faction>_<faction>": the two fight in front of the first one's base.
		var dgame: GameState = get_node_or_null("/root/Game") as GameState
		var dparts: PackedStringArray = _script_name.trim_prefix("duel_").split("_")
		if dgame != null and dparts.size() == 2:
			var dconfig: MatchConfig = MatchConfig.skirmish(1)
			dconfig.factions = [dparts[0], dparts[1]]
			dconfig.region = "temperate"
			dgame.pending_config = dconfig
	if _script_name == "teams" or _script_name == "teams_result":
		# Two against two, with an AI ally: the camera looks at the ally's base.
		var tmgame: GameState = get_node_or_null("/root/Game") as GameState
		if tmgame != null:
			var tmconfig: MatchConfig = MatchConfig.skirmish(5)
			tmconfig.factions = ["verdigris"]
			tmconfig.is_ai = [false]
			tmconfig.ai_levels = [1]
			tmconfig.names = ["Commander"]
			tmconfig.set_team(0, 0)
			tmconfig.add_ai("foundry", 1, "Foundry Pact", 1)
			tmconfig.add_ai("nomad", 1, "Nomad Circuit", 0)
			tmconfig.add_ai("vesper", 1, "Vesper Array", 1)
			tmgame.pending_config = tmconfig
	if _script_name == "watch":
		# A match nobody plays, as the Watch option in the skirmish setup starts it.
		var wgame: GameState = get_node_or_null("/root/Game") as GameState
		if wgame != null:
			var wconfig: MatchConfig = MatchConfig.ai_vs_ai(3)
			wconfig.factions = ["zephyr", "tally"]
			wconfig.names = ["Zephyr Accord", "Crimson Tally"]
			wconfig.watch = true
			wgame.pending_config = wconfig
	if _script_name.begins_with("region_"):
		# "region_<id>": seed 4 in that region, seen whole.
		var rgame: GameState = get_node_or_null("/root/Game") as GameState
		if rgame != null:
			# "region_<id>" is seed 4; "region_<id>_<seed>" any other.
			var rparts: PackedStringArray = _script_name.trim_prefix("region_").split("_")
			var rconfig: MatchConfig = MatchConfig.skirmish(int(rparts[1]) if rparts.size() > 1 else 4)
			rconfig.region = rparts[0]
			rgame.pending_config = rconfig
	if _script_name.begins_with("seed_"):
		# "seed_<n>": the generated two-player map for that seed, seen whole.
		var sgame: GameState = get_node_or_null("/root/Game") as GameState
		if sgame != null:
			sgame.pending_config = MatchConfig.skirmish(int(_script_name.trim_prefix("seed_")))
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
	if menu != null and _script_name == "setupteams" and _count == 3:
		# Two against two: an AI on the player's team.
		menu.choose_factions("zephyr", "")
		menu.choose_map("", 3)
		menu.choose_team(2, 0)
		menu.choose_team(3, 1)
		menu.open_skirmish()
	if menu != null and _script_name.begins_with("setup_") and _count == 3:
		# "setup_<faction>": the skirmish panel dressed for that faction.
		menu.choose_factions(_script_name.trim_prefix("setup_"), "")
		menu.open_skirmish()
	if menu != null and _script_name == "tutorials" and _count == 3:
		menu.call("_show", menu.get("_tutorials"))
	if menu != null and _script_name == "settings" and _count == 3:
		menu.open_settings()
	if menu != null and _script_name == "help" and _count == 3:
		menu.call("_show", menu.get("_help"))
	if menu != null and _script_name == "helpfactions" and _count == 3:
		menu.show_help_page(true)
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
	if _script_name.begins_with("base_") and _count == 3:
		var bw: SimWorld = battle.world
		var bme: int = battle.local_player
		var bf: FactionDef = bw.players[bme].faction
		var bhq: Vector2 = bw.players[bme].start_pos
		var bcell: Vector2i = bw.map.cell_of(bhq)
		var spots: Array[Vector2i] = [Vector2i(5, -2), Vector2i(-1, 5), Vector2i(-6, -1), Vector2i(5, 4), Vector2i(10, 8), Vector2i(9, 1), Vector2i(-6, 4)]
		var jobs: Array[String] = ["barracks", "works", "depot", "tier3", "relay", "turret_ground", "turret_air"]
		var placed: Dictionary[String, bool] = {}
		var line: Array[String] = []
		for k: int in jobs.size():
			var id: String = bf.role(jobs[k])
			if id == "" or placed.has(id) or not bw.data.entities.has(id) or not bw.data.entity(id).is_building:
				continue
			placed[id] = true
			bw.spawn_building(id, bme, bcell + spots[k], true)
			for made: String in bw.data.entity(id).produces:
				if not line.has(made) and not bw.data.entity(made).harvester and not bw.data.entity(made).builder:
					line.append(made)
		for k: int in line.size():
			bw.spawn_unit(line[k], bme, bhq + Vector2(-10.0 + float(k % 4) * 3.4, 12.0 + float(k / 4) * 3.6))
		battle.cam.set_distance(54.0)
		battle.cam.center_on(bhq + Vector2(4.0, 6.0))
	if _script_name.begins_with("base_") and _count == 8:
		# Select a builder so the command card is filled in.
		battle.controller.select_next_idle_builder()
	if _script_name.begins_with("duel_") and _count == 3:
		var dw: SimWorld = battle.world
		var dme: int = battle.local_player
		var dhq: Vector2 = dw.players[dme].start_pos
		var dfront: Vector2 = dw.map.nearest_free_pos(dhq + (dw.map.world_size() * 0.5 - dhq).normalized() * 22.0)
		for side: int in 2:
			var downer: int = dme if side == 0 else 1 - dme
			var drow: int = 0
			for def: EntityDef in dw.data.entities.values():
				if def.is_building or def.faction != dw.players[downer].faction.id or not def.is_armed() or def.is_air():
					continue
				dw.spawn_unit(def.id, downer, dw.map.nearest_free_pos(dfront + Vector2(float(drow % 5) * 4.0 - 8.0, (4.0 if side == 0 else -9.0) + float(drow / 5) * (4.0 if side == 0 else -4.0))))
				drow += 1
		battle.fog_view.visible = false
		battle.terrain.set_fog_texture(null)
		battle.cam.set_distance(36.0)
		battle.cam.center_on(dfront + Vector2(0.0, -2.0))
	if _script_name.begins_with("crowd_") and _count == 3:
		# "crowd_<unit id>": twelve of one unit dropped on almost the same
		# spot, to see how they sort themselves out, then marched off.
		var kw: SimWorld = battle.world
		var kme: int = battle.local_player
		var khq: Vector2 = kw.players[kme].start_pos
		var kat: Vector2 = kw.map.nearest_free_pos(khq + (kw.map.world_size() * 0.5 - khq).normalized() * 20.0)
		for k: int in 12:
			kw.spawn_unit(_script_name.trim_prefix("crowd_"), kme, kat + Vector2(float(k % 4) * 0.5, float(k / 4) * 0.5))
		battle.fog_view.visible = false
		battle.terrain.set_fog_texture(null)
		battle.cam.set_distance(30.0)
		battle.cam.center_on(kat)
	if _script_name.begins_with("crowd_") and _count == 150:
		var mw: SimWorld = battle.world
		var mids: PackedInt32Array = PackedInt32Array()
		var mcentre: Vector2 = Vector2.ZERO
		for e: SimEntity in mw.entities:
			if e.alive and e.owner == battle.local_player and e.def != null and e.def.id == _script_name.trim_prefix("crowd_"):
				mids.append(e.id)
				mcentre += e.pos
		mcentre /= float(maxi(1, mids.size()))
		var mto: Vector2 = mcentre + (mw.map.world_size() * 0.5 - mcentre).normalized() * 16.0
		mw.push_command(SimCommand.move(battle.local_player, mids, mto))
		battle.cam.center_on(mcentre.lerp(mto, 0.6))
	if _script_name == "teams" and _count == 4:
		# Look at the ally's base: it is in view without any unit of ours there.
		battle.cam.center_on(battle.world.players[2].start_pos)
		battle.cam.set_distance(58.0)
	if _script_name == "teams_result" and _count == 5:
		battle.world.defeat_player(1)
		battle.world.defeat_player(3)
	if _script_name == "watch" and _count == 2:
		battle.time_scale = 30.0
	if _script_name == "watch" and _count == _frames - 20:
		battle.time_scale = 1.0
		battle.cam.center_on(battle.world.players[0].start_pos)
		battle.cam.set_distance(60.0)
	if (_script_name.begins_with("seed_") or _script_name.begins_with("region_")) and _count == 2:
		battle.fog_view.visible = false
		battle.terrain.set_fog_texture(null)
		battle.signal_view.set_overlay_visible(false)
		battle.cam.center_on(battle.world.map.world_size() * 0.5)
		battle.cam.set_distance(150.0)
		print("Map: ", battle.world.map.name)
	if _script_name.begins_with("region_") and _script_name.ends_with("_hill") and _count == 3:
		# "region_<id>_<seed>_hill": look at the hill nearest the middle of the map,
		# with a few tanks on it and a few below.
		var hmap: SimMap = battle.world.map
		var hmid: Vector2 = hmap.world_size() * 0.5
		var hbest: Vector2 = hmid
		var hbest_d: float = INF
		for i: int in hmap.w * hmap.h:
			if hmap.high[i] != 0:
				var at: Vector2 = hmap.cell_center(Vector2i(i % hmap.w, i / hmap.w))
				if at.distance_to(hmid) < hbest_d:
					hbest_d = at.distance_to(hmid)
					hbest = at
		# Walk outwards from the hilltop to the bank, and put tanks on and across it.
		var hedge: Vector2 = hbest
		for step: int in 40:
			if not hmap.is_high(hedge + Vector2(1.0, 0.0)):
				break
			hedge += Vector2(1.0, 0.0)
		for k: int in 4:
			battle.world.spawn_unit("bulwark", battle.local_player, hedge + Vector2(float(k) * 2.2 - 4.0, float(k) * 4.0 - 6.0))
		battle.cam.center_on(hedge)
		battle.cam.set_distance(30.0 if _script_name.ends_with("_near_hill") else 46.0)
	if _script_name.begins_with("region_") and _script_name.ends_with("_water") and _count == 3:
		# "region_<id>_<seed>_water": look at the water nearest the middle of the map.
		var wmap: SimMap = battle.world.map
		var wmid: Vector2 = wmap.world_size() * 0.5
		var wbest: Vector2 = wmid
		var wbest_d: float = INF
		for wy: int in wmap.h:
			for wx: int in wmap.w:
				if wmap.terrain_cell(Vector2i(wx, wy)) == SimMap.Terrain.WATER:
					var wat: Vector2 = wmap.cell_center(Vector2i(wx, wy))
					if wat.distance_to(wmid) < wbest_d:
						wbest_d = wat.distance_to(wmid)
						wbest = wat
		battle.cam.center_on(wbest)
		battle.cam.set_distance(40.0)
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
		"foundry":
			if _count == 3:
				var fw: SimWorld = battle.world
				var fme: int = battle.local_player
				var core: Vector2 = fw.players[fme].start_pos
				fw.players[fme].salvage = 3000
				fw.spawn_building("muster_hall", fme, fw.map.cell_of(core) + Vector2i(5, -2), true)
				fw.spawn_building("pylon", fme, fw.map.cell_of(core) + Vector2i(9, 6), true)
				fw.spawn_building("crawler_factory", fme, fw.map.cell_of(core) + Vector2i(-1, 5), true)
				fw.spawn_building("bastion", fme, fw.map.cell_of(core) + Vector2i(7, 4), true)
				fw.spawn_unit("mauler", fme, core + Vector2(15.0, 6.0))
				fw.spawn_unit("tusk", fme, core + Vector2(12.0, 9.0))
				fw.spawn_unit("anvil", fme, core + Vector2(9.0, 12.0))
				fw.spawn_unit("ratchet", fme, core + Vector2(16.0, 10.0))
				var cr: SimEntity = fw.spawn_unit("crawler", fme, core + Vector2(6.0, 14.0))
				battle.controller.set_selection([cr.id])
				battle.cam.set_distance(52.0)
				battle.cam.center_on(core + Vector2(8.0, 6.0))
		"verdigris":
			if _count == 3:
				var ow: SimWorld = battle.world
				var ome: int = battle.local_player
				var okeep: Vector2 = ow.players[ome].start_pos
				var ocell: Vector2i = ow.map.cell_of(okeep)
				ow.spawn_building("chapterhouse", ome, ocell + Vector2i(5, -2), true)
				ow.spawn_building("armoury", ome, ocell + Vector2i(-1, 5), true)
				ow.spawn_building("tithe_barn", ome, ocell + Vector2i(-6, -1), true)
				ow.spawn_building("reliquary", ome, ocell + Vector2i(5, 4), true)
				ow.spawn_building("lantern", ome, ocell + Vector2i(10, 8), true)
				ow.spawn_building("rampart", ome, ocell + Vector2i(8, 2), true)
				ow.spawn_building("watchfire", ome, ocell + Vector2i(9, 5), true)
				var okinds: Array[String] = ["castellan", "thresher", "canopy", "mangonel", "outrider", "pike"]
				for k: int in okinds.size():
					ow.spawn_unit(okinds[k], ome, okeep + Vector2(-9.0 + float(k % 3) * 3.6, 12.0 + float(k / 3) * 3.8))
				battle.cam.set_distance(52.0)
				battle.cam.center_on(okeep + Vector2(5.0, 5.0))
		"vesper":
			if _count == 3:
				var vw: SimWorld = battle.world
				var vme: int = battle.local_player
				var vhq: Vector2 = vw.players[vme].start_pos
				var vcell: Vector2i = vw.map.cell_of(vhq)
				vw.spawn_building("cradle", vme, vcell + Vector2i(5, -2), true)
				vw.spawn_building("assembler", vme, vcell + Vector2i(-1, 5), true)
				vw.spawn_building("cistern", vme, vcell + Vector2i(-6, -1), true)
				vw.spawn_building("oracle", vme, vcell + Vector2i(5, 4), true)
				vw.spawn_building("spire", vme, vcell + Vector2i(10, 8), true)
				vw.spawn_building("ward_node", vme, vcell + Vector2i(8, 2), true)
				var vkinds: Array[String] = ["halberd", "lash", "aureole", "prism", "glint", "shard"]
				for k: int in vkinds.size():
					vw.spawn_unit(vkinds[k], vme, vhq + Vector2(-9.0 + float(k % 3) * 3.4, 12.0 + float(k / 3) * 3.6))
				battle.cam.set_distance(52.0)
				battle.cam.center_on(vhq + Vector2(5.0, 5.0))
		"nomad":
			if _count == 3:
				var nw: SimWorld = battle.world
				var nme: int = battle.local_player
				var hub: Vector2 = nw.players[nme].start_pos
				nw.spawn_building("camp", nme, nw.map.cell_of(hub) + Vector2i(5, -2), true)
				nw.spawn_building("chop_shop", nme, nw.map.cell_of(hub) + Vector2i(-1, 5), true)
				nw.spawn_building("beacon", nme, nw.map.cell_of(hub) + Vector2i(10, 8), true)
				nw.spawn_building("snare_turret", nme, nw.map.cell_of(hub) + Vector2i(7, 4), true)
				nw.spawn_building("cache", nme, nw.map.cell_of(hub) + Vector2i(4, 8), true)
				nw.spawn_unit("prowler", nme, hub + Vector2(15.0, 6.0))
				nw.spawn_unit("sidewinder", nme, hub + Vector2(12.0, 9.0))
				nw.spawn_unit("dart", nme, hub + Vector2(9.0, 12.0))
				nw.spawn_unit("dart", nme, hub + Vector2(11.0, 13.0))
				nw.spawn_unit("gnat", nme, hub + Vector2(16.0, 10.0))
				nw.spawn_unit("splicer", nme, hub + Vector2(13.0, 4.0))
				var jb: SimEntity = nw.spawn_unit("jammer_buggy", nme, hub + Vector2(18.0, 14.0))
				battle.controller.set_selection([jb.id])
				battle.cam.set_distance(56.0)
				battle.cam.center_on(hub + Vector2(8.0, 6.0))
		"combat":
			if _count == 3:
				var cw: SimWorld = battle.world
				var cme: int = battle.local_player
				var chq: Vector2 = cw.players[cme].start_pos
				var front: Vector2 = cw.map.nearest_free_pos(chq + (cw.map.world_size() * 0.5 - chq).normalized() * 20.0)
				for k: int in 3:
					cw.spawn_unit("bulwark", cme, front + Vector2(float(k) * 3.0 - 3.0, 0.0))
					cw.spawn_unit("trooper", cme, front + Vector2(float(k) * 1.5 - 2.0, 3.0))
					cw.spawn_unit("bulwark", 1 - cme, front + Vector2(float(k) * 3.0 - 3.0, -9.0))
					cw.spawn_unit("warden", 1 - cme, front + Vector2(float(k) * 3.0 - 4.0, -12.0))
					cw.spawn_unit("lancer", 1 - cme, front + Vector2(float(k) * 1.5 + 4.0, -8.0))
				var hurt: SimEntity = cw.spawn_building("barracks", cme, cw.map.cell_of(front) + Vector2i(-6, 2), true)
				hurt.hp = hurt.max_hp * 0.3
				battle.cam.set_distance(34.0)
				battle.cam.center_on(front + Vector2(0.0, -3.0))
		"midmatch":
			if _count == 2:
				battle.time_scale = 30.0
			if _count > 2 and _count % 20 == 0:
				# Look at wherever the local player's army is thickest.
				var sum: Vector2 = Vector2.ZERO
				var n: int = 0
				for e: SimEntity in battle.world.entities:
					if e.owner == battle.local_player and e.kind == SimEntity.Kind.UNIT and e.def.is_armed():
						sum += e.pos
						n += 1
				if n > 0:
					battle.cam.center_on(sum / float(n))
				battle.cam.set_distance(46.0)
			if _count == _frames - 30:
				battle.time_scale = 1.0
		"march":
			# An armoured column on the move, for dust trails and tracks.
			if _count == 3:
				var mw: SimWorld = battle.world
				var mme: int = battle.local_player
				var mhq: Vector2 = mw.players[mme].start_pos
				var mdir: Vector2 = (mw.map.world_size() * 0.5 - mhq).normalized()
				var mfrom: Vector2 = mw.map.nearest_free_pos(mhq + mdir * 16.0)
				var mids: PackedInt32Array = PackedInt32Array()
				var mkinds: Array[String] = ["bulwark", "warden", "bulwark", "tempest", "courser", "bulwark", "longbow", "hauler"]
				for k: int in mkinds.size():
					var side: Vector2 = Vector2(-mdir.y, mdir.x) * (float(k % 4) * 3.2 - 4.8)
					var unit: SimEntity = mw.spawn_unit(mkinds[k], mme, mfrom + side - mdir * float(k / 4) * 4.0)
					unit.facing = mdir.angle()
					unit.prev_facing = unit.facing
					mids.append(unit.id)
				mw.push_command(SimCommand.move(mme, mids, mfrom + mdir * 40.0))
				battle.cam.center_on(mfrom + mdir * 5.0)
				battle.cam.set_distance(30.0)
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
		"layout_twin_fords", "layout_crater_ring", "layout_crossroads", "layout_dry_gulch", "layout_frozen_strait", "layout_ember_lake":
			if _count == 2:
				battle.fog_view.visible = false
				battle.terrain.set_fog_texture(null)
				battle.signal_view.set_overlay_visible(false)
				battle.cam.center_on(battle.world.map.world_size() * 0.5)
				battle.cam.set_distance(150.0)
		"scenery_water", "scenery_forest", "scenery_rock", "scenery_wide", "scenery_edge":
			# The bare landscape with fog and coverage switched off, looking at
			# the nearest patch of one kind of terrain to the map centre.
			if _count == 2:
				battle.fog_view.visible = false
				battle.terrain.set_fog_texture(null)
				battle.signal_view.set_overlay_visible(false)
				var smap: SimMap = battle.world.map
				var want: int = SimMap.Terrain.WATER
				if _script_name == "scenery_forest":
					want = SimMap.Terrain.FOREST
				elif _script_name == "scenery_rock":
					want = SimMap.Terrain.ROCK
				var mid: Vector2 = smap.world_size() * 0.5
				var best: Vector2 = mid
				var best_d: float = INF
				if _script_name != "scenery_wide":
					for sy: int in smap.h:
						for sx: int in smap.w:
							if smap.terrain_cell(Vector2i(sx, sy)) == want:
								var sp: Vector2 = smap.cell_center(Vector2i(sx, sy))
								if sp.distance_to(mid) < best_d:
									best_d = sp.distance_to(mid)
									best = sp
				if _script_name == "scenery_edge":
					# A corner of the map, to see how the battlefield ends.
					best = Vector2(14.0, 14.0)
					battle.cam.yaw += PI
				battle.cam.center_on(best)
				battle.cam.set_distance(110.0 if _script_name == "scenery_wide" else 38.0)
