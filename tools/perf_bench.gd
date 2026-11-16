extends SceneTree
## Simulation benchmark: several hundred units fighting at once. Reports the
## cost of a simulation tick, which has to fit comfortably inside a 60 fps
## frame (16.6 ms) because a tick lands on every third frame.
##
## Usage: godot --headless --path . -s res://tools/perf_bench.gd -- [--units=300] [--ticks=600]


func _init() -> void:
	var units: int = 300
	var ticks: int = 600
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--units="):
			units = int(arg.trim_prefix("--units="))
		elif arg.begins_with("--ticks="):
			ticks = int(arg.trim_prefix("--ticks="))

	var config: MatchConfig = MatchConfig.skirmish(4)
	config.is_ai = [false, false]
	config.factions = ["aegis", "foundry"]
	var w: SimWorld = SimSetup.create_match(config)
	w.collect_events = false
	w.victory_enabled = false
	var centre: Vector2 = w.map.world_size() * 0.5
	var mixes: Array[Array] = [
		["trooper", "trooper", "lancer", "warden", "bulwark", "tempest", "marksman", "kestrel"],
		["levy", "levy", "breaker", "tusk", "mauler", "harrow", "anvil", "ratchet"],
	]
	var per_side: int = units / 2
	for side: int in 2:
		var ids: PackedInt32Array = PackedInt32Array()
		var origin: Vector2 = centre + Vector2(-26.0 if side == 0 else 26.0, 0.0)
		for i: int in per_side:
			var def_id: String = mixes[side][i % mixes[side].size()]
			var at: Vector2 = origin + Vector2(float(i % 10) * 2.2 - 10.0, float(i / 10) * 2.2 - 16.0)
			var u: SimEntity = w.spawn_unit(def_id, side, w.map.nearest_free_pos(w.map.clamp_to_map(at)))
			# Tough enough that the fight lasts for the whole measurement.
			u.max_hp *= 6.0
			u.hp = u.max_hp
			ids.append(u.id)
		w.players[side].bandwidth_cap = 9999
		w.push_command(SimCommand.attack_move(side, ids, centre))
	# Both sides can see the middle, so targeting runs at full cost.
	w.add_reveal(centre, 60.0, 0, -1)
	w.add_reveal(centre, 60.0, 1, -1)

	w.profiling = true
	var worst: int = 0
	var total: int = 0
	var slow: int = 0
	var start_units: int = w.count_units(0) + w.count_units(1)
	for i: int in ticks:
		var t0: int = Time.get_ticks_usec()
		w.tick()
		var dt: int = Time.get_ticks_usec() - t0
		total += dt
		worst = maxi(worst, dt)
		if dt > 8000:
			slow += 1
	var alive: int = w.count_units(0) + w.count_units(1)
	var avg_ms: float = float(total) / float(ticks) / 1000.0
	print("PERF: %d units at start, %d alive after %d ticks, %d projectiles in flight" % [start_units, alive, ticks, w.projectiles.size()])
	print("PERF: tick average %.2f ms, worst %.2f ms, %d ticks over 8 ms" % [avg_ms, float(worst) / 1000.0, slow])
	print("PERF: simulation uses %.0f%% of one core at 20 ticks a second" % (avg_ms * 20.0 / 10.0))
	var stages: Array[String] = []
	for stage: String in w.profile.keys():
		stages.append("%s %.2f" % [stage, float(w.profile[stage]) / float(ticks) / 1000.0])
	print("PERF: per tick by stage (ms): %s" % ", ".join(stages))
	quit(0)
