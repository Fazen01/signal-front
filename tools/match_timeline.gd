extends SceneTree
## Plays one AI-vs-AI match and prints what happened when: every attack wave
## (size at launch, survivors at the end), every building lost, and each
## headquarters' health. For working out why matches end when they do.
##
## Usage: godot --headless --path . -s res://tools/match_timeline.gd -- \
##          [--seed=N] [--factions=aegis,foundry] [--levels=1,1] [--max-minutes=45]
##          [--map=twin_fords]


func _init() -> void:
	var seed_value: int = 1
	var max_minutes: float = 45.0
	var levels: Array[int] = [1, 1]
	var factions: Array[String] = ["aegis", "aegis"]
	var map_id: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			seed_value = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--max-minutes="):
			max_minutes = float(arg.trim_prefix("--max-minutes="))
		elif arg.begins_with("--levels="):
			var parts: PackedStringArray = arg.trim_prefix("--levels=").split(",")
			levels = [int(parts[0]), int(parts[1])]
		elif arg.begins_with("--factions="):
			var names: PackedStringArray = arg.trim_prefix("--factions=").split(",")
			factions = [names[0], names[1]]
		elif arg.begins_with("--map="):
			map_id = arg.trim_prefix("--map=")
	var config: MatchConfig = MatchConfig.ai_vs_ai(seed_value)
	config.factions = factions
	config.ai_levels = levels
	config.map_id = map_id
	var w: SimWorld = SimSetup.create_match(config)
	w.collect_events = false
	var max_ticks: int = int(max_minutes * 60.0 * float(SimWorld.TICK_RATE))
	var wave_state: Array[int] = [0, 0]
	var wave_start: Array[int] = [0, 0]
	var buildings: Dictionary[int, String] = {}
	var hq_low: Array[bool] = [false, false]
	while not w.game_over and w.tick_count < max_ticks:
		w.tick()
		for ai: SimAI in w.ais:
			var i: int = ai.player_id
			if ai.wave_state != wave_state[i]:
				if wave_state[i] == 0:
					wave_start[i] = ai.wave_ids.size()
					print("%s  P%d wave %d launches with %d (value %d) at %s" % [
						_clock(w), i + 1, ai.waves_sent, wave_start[i], _value(w, ai.wave_ids), _target(w, ai)])
				elif ai.wave_state == 0:
					print("%s  P%d wave %d over: %d of %d alive" % [
						_clock(w), i + 1, ai.waves_sent, _army(w, i), wave_start[i]])
				else:
					print("%s  P%d wave %d assaults with %d" % [_clock(w), i + 1, ai.waves_sent, ai.wave_ids.size()])
				wave_state[i] = ai.wave_state
		var seen: Dictionary[int, bool] = {}
		for e: SimEntity in w.entities:
			if e.alive and e.def != null and e.kind == SimEntity.Kind.BUILDING and e.owner >= 0:
				seen[e.id] = true
				if not buildings.has(e.id):
					buildings[e.id] = "P%d %s" % [e.owner + 1, e.def.id]
				if e.def.signal_root and not hq_low[e.owner] and e.hp < e.max_hp * 0.5:
					hq_low[e.owner] = true
					print("%s  P%d headquarters below half health" % [_clock(w), e.owner + 1])
		for id: int in buildings.keys():
			if not seen.has(id):
				print("%s  lost: %s" % [_clock(w), buildings[id]])
				buildings.erase(id)
		if w.tick_count % (SimWorld.TICK_RATE * 60) == 0:
			var line: String = _clock(w)
			for p: SimPlayer in w.players:
				line += " | P%d $%d army %d bw %d/%d haulers %d turrets %d hq %d%%" % [
					p.id + 1, p.salvage, _army(w, p.id), p.bandwidth_used, p.bandwidth_cap,
					_haulers(w, p.id), _turrets(w, p.id), _hq_percent(w, p.id)]
			print(line)
	print("END %s winner %d" % [_clock(w), w.winner + 1 if w.game_over else 0])
	quit(0)


func _clock(w: SimWorld) -> String:
	var secs: int = int(w.seconds())
	return "%2d:%02d" % [secs / 60, secs % 60]


func _army(w: SimWorld, owner: int) -> int:
	var n: int = 0
	for e: SimEntity in w.entities:
		if e.alive and e.owner == owner and e.def != null and e.kind == SimEntity.Kind.UNIT and e.def.is_armed():
			n += 1
	return n


func _haulers(w: SimWorld, owner: int) -> int:
	var n: int = 0
	for e: SimEntity in w.entities:
		if e.alive and e.owner == owner and e.def != null and e.def.harvester:
			n += 1
	return n


func _turrets(w: SimWorld, owner: int) -> int:
	var n: int = 0
	for e: SimEntity in w.entities:
		if e.alive and e.owner == owner and e.def != null and e.kind == SimEntity.Kind.BUILDING \
				and e.def.is_armed() and not e.def.signal_root:
			n += 1
	return n


func _hq_percent(w: SimWorld, owner: int) -> int:
	for e: SimEntity in w.entities:
		if e.alive and e.owner == owner and e.def != null and e.def.signal_root:
			return int(100.0 * e.hp / e.max_hp)
	return 0


func _value(w: SimWorld, ids: Array[int]) -> int:
	var total: int = 0
	for id: int in ids:
		var e: SimEntity = w.get_entity(id)
		if e != null:
			total += e.def.cost
	return total


func _target(w: SimWorld, ai: SimAI) -> String:
	var t: SimEntity = w.get_entity(ai.wave_target)
	return t.def.id if t != null else "the enemy start"
