extends SceneTree
## Bug hunt: plays AI-vs-AI matches and, once a second of game time, checks
## that the world is in a state that makes sense. Anything that should be
## impossible is printed as a "BUG" line with the tick and the entity.
##
## Usage: godot --headless --path . -s res://tools/invariant_check.gd -- \
##          [--seeds=1,2,3] [--factions=aegis,veil] [--minutes=12] [--players=2]
## Without --factions every faction is played against the next one in turn.
## Prints "INVARIANTS OK" or "INVARIANTS FAILED: n" at the end.

var _found: Dictionary[String, int] = {}  ## kind of bug -> times seen
var _shown: Dictionary[String, int] = {}
var _stuck_since: Dictionary[int, int] = {}  ## entity id -> tick it was first seen stuck off the map grid


func _init() -> void:
	var seeds: Array[int] = [1, 2, 3]
	var only: Array[String] = []
	var minutes: float = 12.0
	var players: int = 2
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="):
			seeds.clear()
			for part: String in arg.trim_prefix("--seeds=").split(","):
				seeds.append(int(part))
		elif arg.begins_with("--factions="):
			for part: String in arg.trim_prefix("--factions=").split(","):
				only.append(part)
		elif arg.begins_with("--minutes="):
			minutes = float(arg.trim_prefix("--minutes="))
		elif arg.begins_with("--players="):
			players = int(arg.trim_prefix("--players="))
	var data: GameData = GameData.shared()
	var all: Array[String] = []
	for f: FactionDef in data.factions.values():
		if f.playable:
			all.append(f.id)
	var line_ups: Array[Array] = []
	if not only.is_empty():
		line_ups.append(only)
	else:
		for i: int in all.size():
			var side: Array[String] = []
			for k: int in players:
				side.append(all[(i + k) % all.size()])
			line_ups.append(side)
	var matches: int = 0
	for seed_value: int in seeds:
		for side: Array in line_ups:
			var config: MatchConfig = MatchConfig.ai_vs_ai(seed_value)
			config.factions.clear()
			config.is_ai.clear()
			config.ai_levels.clear()
			config.names.clear()
			for f: Variant in side:
				config.add_ai(str(f), 1, str(f))
			var w: SimWorld = SimSetup.create_match(config)
			w.collect_events = false
			_stuck_since.clear()
			var limit: int = int(minutes * 60.0) * SimWorld.TICK_RATE
			while not w.game_over and w.tick_count < limit:
				w.tick()
				if w.tick_count % SimWorld.TICK_RATE == 0:
					_check(w, "seed %d %s" % [seed_value, "/".join(side)])
			matches += 1
	var total: int = 0
	for kind: String in _found:
		total += _found[kind]
		print("BUG SUMMARY %-34s seen %d times" % [kind, _found[kind]])
	if total == 0:
		print("INVARIANTS OK: %d matches" % matches)
	else:
		print("INVARIANTS FAILED: %d problems of %d kinds in %d matches" % [total, _found.size(), matches])
	quit(0 if total == 0 else 1)


func _bug(kind: String, where: String, w: SimWorld, detail: String) -> void:
	_found[kind] = int(_found.get(kind, 0)) + 1
	_shown[kind] = int(_shown.get(kind, 0)) + 1
	if _shown[kind] <= 3:
		print("BUG %s | %s | %d:%02d | %s" % [kind, where, int(w.seconds()) / 60, int(w.seconds()) % 60, detail])


func _check(w: SimWorld, where: String) -> void:
	var size: Vector2 = w.map.world_size()
	var used: Dictionary[int, int] = {}
	var seen_ids: Dictionary[int, bool] = {}
	for e: SimEntity in w.entities:
		if not e.alive:
			continue
		var label: String = "%s #%d owner %d at %s" % [e.def.id if e.def != null else "kind %d" % e.kind, e.id, e.owner, str(e.pos)]
		if seen_ids.has(e.id):
			_bug("duplicate entity id", where, w, label)
		seen_ids[e.id] = true
		if w.get_entity(e.id) != e:
			_bug("entity missing from the id index", where, w, label)
		if is_nan(e.pos.x) or is_nan(e.pos.y) or is_nan(e.hp):
			_bug("not-a-number in position or health", where, w, label)
			continue
		if e.pos.x < -0.01 or e.pos.y < -0.01 or e.pos.x > size.x + 0.01 or e.pos.y > size.y + 0.01:
			_bug("entity outside the map", where, w, label)
		if e.def == null:
			continue
		if e.hp <= 0.0:
			_bug("alive with no health", where, w, label)
		if e.hp > e.max_hp + 0.01:
			_bug("more health than its maximum", where, w, "%s hp %.1f of %.1f" % [label, e.hp, e.max_hp])
		if e.owner >= 0 and e.owner >= w.players.size():
			_bug("owner that does not exist", where, w, label)
			continue
		if e.kind == SimEntity.Kind.UNIT:
			if e.owner >= 0:
				used[e.owner] = int(used.get(e.owner, 0)) + e.def.bandwidth
			# A ground unit standing in rock or water has been pushed there:
			# allow a moment for the movement code to walk it out again.
			if not e.def.is_air() and not w.map.is_passable(e.pos) and w.map.occupant_at(w.map.cell_of(e.pos)) == 0:
				if not _stuck_since.has(e.id):
					_stuck_since[e.id] = w.tick_count
				elif w.tick_count - _stuck_since[e.id] >= SimWorld.TICK_RATE * 20:
					_bug("ground unit inside rock or water for 20 s", where, w, label)
					_stuck_since[e.id] = w.tick_count
			else:
				_stuck_since.erase(e.id)
			if e.def.harvester and e.cargo > e.def.capacity:
				_bug("hauler carrying more than it can hold", where, w, "%s cargo %d of %d" % [label, e.cargo, e.def.capacity])
			if e.cargo < 0:
				_bug("negative cargo", where, w, label)
			for o: SimOrder in e.orders:
				if is_nan(o.pos.x) or is_nan(o.pos.y):
					_bug("order with not-a-number position", where, w, label)
		elif e.kind == SimEntity.Kind.BUILDING:
			if e.build_progress < 0.0 or e.build_progress > 1.0001:
				_bug("build progress out of range", where, w, "%s %.3f" % [label, e.build_progress])
			for id: String in e.queue:
				if not e.def.produces.has(id):
					_bug("building queued something it cannot make", where, w, "%s queued %s" % [label, id])
			if not e.def.is_mine() and e.def.blocks:
				for dy: int in e.def.footprint.y:
					for dx: int in e.def.footprint.x:
						var c: Vector2i = e.footprint_cell + Vector2i(dx, dy)
						if w.map.occupant_at(c) != e.id:
							_bug("footprint cell not marked as occupied", where, w, "%s cell %s holds %d" % [label, str(c), w.map.occupant_at(c)])
	for p: SimPlayer in w.players:
		if p.salvage < 0:
			_bug("negative salvage", where, w, "%s has %d" % [p.name, p.salvage])
		if p.command_points < 0:
			_bug("negative command points", where, w, p.name)
		if p.bandwidth_used != int(used.get(p.id, 0)):
			_bug("bandwidth count does not match the units", where, w, "%s counts %d, units add up to %d" % [p.name, p.bandwidth_used, int(used.get(p.id, 0))])
		if p.bandwidth_used < 0:
			_bug("negative bandwidth", where, w, p.name)
		if p.defeated:
			for e: SimEntity in w.entities:
				if e.alive and e.owner == p.id and e.kind == SimEntity.Kind.BUILDING and e.def.signal_root:
					_bug("defeated player still has a headquarters", where, w, p.name)
	# Every occupied cell must belong to a living building.
	for i: int in w.map.occupant.size():
		var id: int = w.map.occupant[i]
		if id != 0:
			var b: SimEntity = w.get_entity(id)
			if b == null or not b.alive or b.kind != SimEntity.Kind.BUILDING:
				_bug("cell occupied by something that is gone", where, w, "cell %d holds %d" % [i, id])
				break
	for pr: SimProjectile in w.projectiles:
		if is_nan(pr.pos.x) or is_nan(pr.pos.y):
			_bug("projectile with not-a-number position", where, w, "projectile %d" % pr.id)
