extends SceneTree
## Plays AI-vs-AI matches with pacing knobs scaled in memory, to find out what
## moves match length without editing the data files first.
##
## Usage: godot --headless --path . -s res://tools/pace_batch.gd -- \
##          [--seeds=1,2,3] [--pairs=aegis:foundry,nomad:aegis] [--max-minutes=60]
##          [--unit-build=1.5] [--bld-build=1.5] [--harvest=6.0]
##          [--hq-hp=2.0] [--bld-hp=1.5] [--turret-dmg=1.5] [--damage=0.8]
##          [--wave-cd=1.5] [--first-wave=10] [--start-salvage=400]
## Prints one "PACE" line per pairing and a "PACE TOTAL" line.


func _init() -> void:
	var seeds: Array[int] = [1, 2, 3]
	var pairs: Array[String] = []
	var max_minutes: float = 60.0
	var knobs: Dictionary[String, float] = {}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="):
			seeds.clear()
			for part: String in arg.trim_prefix("--seeds=").split(","):
				seeds.append(int(part))
		elif arg.begins_with("--pairs="):
			for part: String in arg.trim_prefix("--pairs=").split(","):
				pairs.append(part)
		elif arg.begins_with("--max-minutes="):
			max_minutes = float(arg.trim_prefix("--max-minutes="))
		elif arg.begins_with("--") and arg.contains("="):
			var kv: PackedStringArray = arg.trim_prefix("--").split("=")
			knobs[kv[0]] = float(kv[1])

	var data: GameData = GameData.shared()
	_apply(data, knobs)
	if pairs.is_empty():
		for a: FactionDef in data.factions.values():
			for b: FactionDef in data.factions.values():
				if a.playable and b.playable:
					pairs.append("%s:%s" % [a.id, b.id])

	var max_ticks: int = int(max_minutes * 60.0 * float(SimWorld.TICK_RATE))
	var total_minutes: float = 0.0
	var games: int = 0
	var shortest: float = INF
	var longest: float = 0.0
	var wins: Dictionary[String, int] = {}
	var played: Dictionary[String, int] = {}
	var draws_total: int = 0
	for pair: String in pairs:
		var ab: PackedStringArray = pair.split(":")
		var wins_a: int = 0
		var wins_b: int = 0
		var draws: int = 0
		var minutes: float = 0.0
		var lengths: Array[String] = []
		for seed_value: int in seeds:
			var config: MatchConfig = MatchConfig.ai_vs_ai(seed_value)
			config.factions = [ab[0], ab[1]]
			var w: SimWorld = SimSetup.create_match(config)
			w.collect_events = false
			for ai: SimAI in w.ais:
				if knobs.has("wave-cd"):
					ai.wave_cooldown_ticks = int(float(ai.wave_cooldown_ticks) * knobs["wave-cd"])
				if knobs.has("first-wave"):
					ai.first_wave = int(knobs["first-wave"])
					ai.wave_size = ai.first_wave
			while not w.game_over and w.tick_count < max_ticks:
				w.tick()
			var m: float = w.seconds() / 60.0
			minutes += m
			total_minutes += m
			games += 1
			shortest = minf(shortest, m)
			longest = maxf(longest, m)
			lengths.append("%.1f" % m)
			played[ab[0]] = played.get(ab[0], 0) + 1
			played[ab[1]] = played.get(ab[1], 0) + 1
			if w.game_over and w.winner == 0:
				wins_a += 1
				wins[ab[0]] = wins.get(ab[0], 0) + 1
			elif w.game_over and w.winner == 1:
				wins_b += 1
				wins[ab[1]] = wins.get(ab[1], 0) + 1
			else:
				draws += 1
				draws_total += 1
		print("PACE %s %s %d-%d draws %d avg %.1f [%s]" % [ab[0], ab[1], wins_a, wins_b, draws, minutes / float(seeds.size()), " ".join(lengths)])
	var rates: Array[String] = []
	for f: String in played:
		rates.append("%s %d/%d" % [f, wins.get(f, 0), played[f]])
	print("PACE TOTAL games %d avg %.1f min %.1f max %.1f draws %d | %s" % [
		games, total_minutes / float(maxi(games, 1)), shortest, longest, draws_total, ", ".join(rates),
	])
	quit(0)


func _apply(data: GameData, knobs: Dictionary[String, float]) -> void:
	for e: EntityDef in data.entities.values():
		if e.is_building:
			e.build_time *= knobs.get("bld-build", 1.0)
			e.hp *= knobs.get("hq-hp", 1.0) if e.signal_root else knobs.get("bld-hp", 1.0)
		else:
			e.build_time *= knobs.get("unit-build", 1.0)
	for wd: WeaponDef in data.weapons.values():
		wd.damage *= knobs.get("damage", 1.0)
	if knobs.has("turret-dmg"):
		var done: Dictionary[String, bool] = {}
		for e: EntityDef in data.entities.values():
			if not e.is_building:
				continue
			for wd: WeaponDef in e.weapons:
				if not done.has(wd.id):
					done[wd.id] = true
					wd.damage *= knobs["turret-dmg"]
	if knobs.has("harvest"):
		data.harvest_seconds = knobs["harvest"]
	if knobs.has("start-salvage"):
		data.start_salvage = int(knobs["start-salvage"])
