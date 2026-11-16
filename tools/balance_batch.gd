extends SceneTree
## Plays a batch of AI-vs-AI matches and prints win rates, to tune balance.
##
## Usage: godot --headless --path . -s res://tools/balance_batch.gd -- \
##          [--seeds=1,2,3] [--first=aegis] [--levels=1,1] [--max-minutes=40]
## --first limits the batch to matchups where that faction sits in seat one,
## so several processes can share the work.


func _init() -> void:
	var seeds: Array[int] = [1, 2, 3, 4]
	var first_only: String = ""
	var levels: Array[int] = [1, 1]
	var max_minutes: float = 40.0
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="):
			seeds.clear()
			for part: String in arg.trim_prefix("--seeds=").split(","):
				seeds.append(int(part))
		elif arg.begins_with("--first="):
			first_only = arg.trim_prefix("--first=")
		elif arg.begins_with("--levels="):
			var parts: PackedStringArray = arg.trim_prefix("--levels=").split(",")
			levels = [int(parts[0]), int(parts[1])]
		elif arg.begins_with("--max-minutes="):
			max_minutes = float(arg.trim_prefix("--max-minutes="))

	var data: GameData = GameData.shared()
	var factions: Array[String] = []
	for f: FactionDef in data.factions.values():
		if f.playable:
			factions.append(f.id)
	var max_ticks: int = int(max_minutes * 60.0 * float(SimWorld.TICK_RATE))
	for a: String in factions:
		if first_only != "" and a != first_only:
			continue
		for b: String in factions:
			var wins_a: int = 0
			var wins_b: int = 0
			var draws: int = 0
			var minutes: float = 0.0
			for seed_value: int in seeds:
				var config: MatchConfig = MatchConfig.ai_vs_ai(seed_value)
				config.factions = [a, b]
				config.ai_levels = levels
				var w: SimWorld = SimSetup.create_match(config)
				w.collect_events = false
				while not w.game_over and w.tick_count < max_ticks:
					w.tick()
				minutes += w.seconds() / 60.0
				if w.game_over and w.winner == 0:
					wins_a += 1
				elif w.game_over and w.winner == 1:
					wins_b += 1
				else:
					draws += 1
			# One line per matchup: seat one faction, seat two faction, results.
			print("BATCH %s %s %d %d %d %.1f" % [a, b, wins_a, wins_b, draws, minutes / float(seeds.size())])
	quit(0)
