extends SceneTree
## Runs a whole AI-vs-AI skirmish at full speed with no rendering and reports
## the winner. This is the main regression test for the simulation and AI.
##
## Usage: godot --headless --path . -s res://tools/headless_match.gd -- \
##          [--seed=N] [--max-minutes=M] [--levels=1,1] [--quiet]
## Prints "MATCH RESULT: ..." on a win and "MATCH FAILED: ..." otherwise.


func _init() -> void:
	var seed_value: int = 1
	var max_minutes: float = 45.0
	var levels: Array[int] = [1, 1]
	var quiet: bool = false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			seed_value = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--max-minutes="):
			max_minutes = float(arg.trim_prefix("--max-minutes="))
		elif arg.begins_with("--levels="):
			var parts: PackedStringArray = arg.trim_prefix("--levels=").split(",")
			if parts.size() == 2:
				levels = [int(parts[0]), int(parts[1])]
		elif arg == "--quiet":
			quiet = true

	var config: MatchConfig = MatchConfig.ai_vs_ai(seed_value)
	config.ai_levels = levels
	var w: SimWorld = SimSetup.create_match(config)
	w.collect_events = false
	var started: int = Time.get_ticks_msec()
	var max_ticks: int = int(max_minutes * 60.0 * float(SimWorld.TICK_RATE))
	var peak_entities: int = 0
	while not w.game_over and w.tick_count < max_ticks:
		w.tick()
		peak_entities = maxi(peak_entities, w.entities.size())
		if not quiet and w.tick_count % (SimWorld.TICK_RATE * 60) == 0:
			print(_status_line(w))
	var wall: float = float(Time.get_ticks_msec() - started) / 1000.0
	var game_time: String = _clock(w)
	if w.game_over and w.winner >= 0:
		var win: SimPlayer = w.players[w.winner]
		print("MATCH RESULT: seed %d, winner %s (player %d) at %s, %d ticks in %.1fs wall, peak %d entities" % [
			seed_value, win.name, w.winner, game_time, w.tick_count, wall, peak_entities,
		])
		for p: SimPlayer in w.players:
			print("  %s: built %d units / %d buildings, lost %d / %d, kills %d, collected %d" % [
				p.name, p.stat_units_built, p.stat_buildings_built, p.stat_units_lost, p.stat_buildings_lost,
				p.stat_kills, p.stat_salvage_collected,
			])
		quit(0)
	else:
		print("MATCH FAILED: seed %d, no winner after %s (%d ticks, %.1fs wall)" % [seed_value, game_time, w.tick_count, wall])
		print(_status_line(w))
		quit(1)


func _clock(w: SimWorld) -> String:
	var secs: int = int(w.seconds())
	return "%d:%02d" % [secs / 60, secs % 60]


func _status_line(w: SimWorld) -> String:
	var parts: Array[String] = [_clock(w)]
	for p: SimPlayer in w.players:
		var units: int = 0
		var army: int = 0
		var buildings: int = 0
		var relays: int = 0
		for e: SimEntity in w.entities:
			if e.alive and e.owner == p.id:
				if e.kind == SimEntity.Kind.UNIT:
					units += 1
					if e.def.is_armed():
						army += 1
				else:
					buildings += 1
					if e.def.id == "relay":
						relays += 1
		var wave: String = ""
		for ai: SimAI in w.ais:
			if ai.player_id == p.id:
				wave = " wave%d:%d/%d" % [ai.waves_sent, ai.wave_ids.size(), ai.wave_size]
		parts.append("%s $%d bw %d/%d units %d army %d bld %d relays %d%s" % [
			p.name.left(5), p.salvage, p.bandwidth_used, p.bandwidth_cap, units, army, buildings, relays, wave,
		])
	return " | ".join(parts)
