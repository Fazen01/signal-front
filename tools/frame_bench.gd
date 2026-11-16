extends Node
## View-side benchmark: the real battle scene with a few hundred units on
## screen, run headless. Reports how long the scripts take per frame
## (simulation ticks, view sync, HUD and overlay drawing). Rendering itself
## is not measured: there is no GPU here.
##
## Usage: godot --headless --path . res://tools/frame_bench.tscn -- [--units=300]

var _battle: BattleScene = null
var _frame: int = 0
var _units: int = 300
var _total: float = 0.0
var _worst: float = 0.0
var _samples: int = 0
var _off: PackedStringArray = PackedStringArray()
var _last_usec: int = 0


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--units="):
			_units = int(arg.trim_prefix("--units="))
		elif arg.begins_with("--off="):
			# Switch parts of the scene off to see what each one costs.
			_off = arg.trim_prefix("--off=").split(",")
	var packed: PackedScene = load("res://scenes/battle.tscn") as PackedScene
	_battle = packed.instantiate() as BattleScene
	add_child(_battle)


func _process(_delta: float) -> void:
	_frame += 1
	if _frame == 3:
		var w: SimWorld = _battle.world
		w.victory_enabled = false
		var centre: Vector2 = w.map.world_size() * 0.5
		var mix: Array[String] = ["trooper", "lancer", "warden", "bulwark", "tempest", "kestrel"]
		var selection: Array[int] = []
		for side: int in 2:
			var ids: PackedInt32Array = PackedInt32Array()
			for i: int in _units / 2:
				var at: Vector2 = centre + Vector2((-22.0 if side == 0 else 22.0) + float(i % 10) * 2.2 - 10.0, float(i / 10) * 2.2 - 16.0)
				var u: SimEntity = w.spawn_unit(mix[i % mix.size()], side, w.map.nearest_free_pos(w.map.clamp_to_map(at)))
				u.max_hp *= 6.0
				u.hp = u.max_hp
				ids.append(u.id)
				if side == _battle.local_player:
					selection.append(u.id)
			w.players[side].bandwidth_cap = 9999
			w.push_command(SimCommand.attack_move(side, ids, centre))
		w.add_reveal(centre, 60.0, 0, -1)
		w.add_reveal(centre, 60.0, 1, -1)
		# Worst case for the interface: everything selected and on screen.
		_battle.controller.set_selection(selection)
		_battle.cam.set_distance(80.0)
		_battle.cam.center_on(centre)
		if _off.has("overlay"):
			_battle.overlay.set_process(false)
			_battle.overlay.visible = false
		if _off.has("minimap"):
			_battle.hud.minimap.set_process(false)
			_battle.hud.minimap.visible = false
		if _off.has("hud"):
			_battle.hud.set_process(false)
		if _off.has("fog"):
			_battle.fog_view.set_process(false)
		if _off.has("signal"):
			_battle.signal_view.set_process(false)
		if _off.has("fx"):
			_battle.world_view.fx.set_process(false)
			_battle.world_view.fx.visible = false
		if _off.has("audio"):
			_battle.world_view.audio = null
		if _off.has("select"):
			_battle.controller.clear_selection()
	if _frame == 60:
		_battle.perf_enabled = true
	if _frame > 60:
		# Wall-clock time between frames. Headless there is no vsync and no
		# real rendering, so this is the cost of everything the scripts and
		# the engine's scene processing do in a frame.
		var now: int = Time.get_ticks_usec()
		if _last_usec > 0:
			var spent: float = float(now - _last_usec) / 1000.0
			_total += spent
			_worst = maxf(_worst, spent)
			_samples += 1
		_last_usec = now
	if _frame == 420:
		print("FRAME: %d entities, %d effect nodes" % [_battle.world.entities.size(), _battle.world_view.fx.get_child_count()])
		print("FRAME: frame time average %.2f ms, worst %.2f ms over %d frames (budget at 60 fps: 16.7 ms)" % [
			_total / float(_samples), _worst, _samples,
		])
		var frames: float = float(maxi(_battle.perf.get("frames", 1), 1))
		print("FRAME: battle scene per frame: simulation %.2f ms, event effects %.2f ms, view sync %.2f ms" % [
			float(_battle.perf.get("sim", 0)) / frames / 1000.0,
			float(_battle.perf.get("events", 0)) / frames / 1000.0,
			float(_battle.perf.get("sync", 0)) / frames / 1000.0,
		])
		get_tree().quit(0)
