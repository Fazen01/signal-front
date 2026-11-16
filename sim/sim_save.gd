class_name SimSave
extends RefCounted
## Saving and restoring a whole match. The map is rebuilt from the match
## configuration (generation is deterministic); everything else is written
## out as plain values. A restored world continues exactly as the original
## would have.

const VERSION: int = 1
const PATH: String = "user://skirmish.sav"

# Fields that are references or per-tick scratch and are rebuilt on load.
const ENTITY_SKIP: Array[String] = ["def", "orders"]
const PLAYER_SKIP: Array[String] = ["faction"]


# ----------------------------------------------------------------- files

static func has_save() -> bool:
	return FileAccess.file_exists(PATH)


## Writes the match to the single save slot. Returns false on failure.
static func save_to_file(w: SimWorld, config: MatchConfig) -> bool:
	var f: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_var(to_dict(w, config))
	f.close()
	return true


## Reads the save slot. Returns {} if there is none or it cannot be used.
static func read_file() -> Dictionary:
	if not has_save():
		return {}
	var f: FileAccess = FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return {}
	var v: Variant = f.get_var()
	f.close()
	if typeof(v) != TYPE_DICTIONARY:
		return {}
	var d: Dictionary = v
	if int(d.get("version", 0)) != VERSION:
		return {}
	return d


# -------------------------------------------------------------- snapshot

static func config_to_dict(c: MatchConfig) -> Dictionary:
	return {
		"seed_value": c.seed_value, "map_cells": c.map_cells, "map_id": c.map_id,
		"region": c.region, "watch": c.watch,
		"factions": _copy(c.factions), "is_ai": _copy(c.is_ai),
		"ai_levels": _copy(c.ai_levels), "names": _copy(c.names), "teams": _copy(c.teams),
	}


static func config_from_dict(d: Dictionary) -> MatchConfig:
	var c: MatchConfig = MatchConfig.new()
	c.seed_value = int(d.get("seed_value", 1))
	c.map_cells = int(d.get("map_cells", 64))
	c.map_id = str(d.get("map_id", ""))
	c.region = str(d.get("region", ""))
	c.watch = bool(d.get("watch", false))
	c.factions.assign(d.get("factions", []))
	c.is_ai.assign(d.get("is_ai", []))
	c.ai_levels.assign(d.get("ai_levels", []))
	c.names.assign(d.get("names", []))
	c.teams.assign(d.get("teams", []))
	return c


static func to_dict(w: SimWorld, config: MatchConfig) -> Dictionary:
	var entities: Array = []
	for e: SimEntity in w.entities:
		if not e.alive:
			continue
		var ed: Dictionary = _dump(e, ENTITY_SKIP)
		ed["def_id"] = e.def.id if e.def != null else ""
		var orders: Array = []
		for o: SimOrder in e.orders:
			orders.append(_dump(o, []))
		ed["orders"] = orders
		entities.append(ed)
	var players: Array = []
	for p: SimPlayer in w.players:
		players.append(_dump(p, PLAYER_SKIP))
	var projectiles: Array = []
	for p: SimProjectile in w.projectiles:
		var pd: Dictionary = _dump(p, ["weapon"])
		pd["weapon_id"] = p.weapon.id
		projectiles.append(pd)
	var timed: Array = []
	for t: SimDirectives.Timed in w.timed:
		timed.append({"tick": t.tick, "kind": t.kind, "pos": t.pos, "player": t.player, "def_id": t.def.id})
	var ais: Array = []
	for ai: SimAI in w.ais:
		var ad: Dictionary = _dump(ai, ["rng"])
		ad["rng_state"] = ai.rng.state
		ais.append(ad)
	# Commands issued during the last tick are still waiting to be applied.
	var commands: Array = []
	for cmd: SimCommand in w.commands:
		commands.append(_dump(cmd, []))
	return {
		"version": VERSION,
		"config": config_to_dict(config),
		"tick_count": w.tick_count, "next_id": w.next_id, "rng_state": w.rng.state,
		"game_over": w.game_over, "winner": w.winner, "winner_team": w.winner_team, "victory_enabled": w.victory_enabled,
		"entities": entities, "players": players, "projectiles": projectiles, "timed": timed, "ais": ais,
		"commands": commands,
		"explored": _copy(w.explored), "reveals": _copy(w.reveals), "reveal_until": _copy(w.reveal_until),
		"blackouts": _copy(w.blackouts), "blackout_until": _copy(w.blackout_until),
		# Derived grids are stored as they are, so a restored match continues
		# on exactly the same ticks the original would have.
		"coverage": _copy(w.coverage), "visible": _copy(w.visible),
		"signal_links": _copy(w.signal_links), "signal_dirty": w.signal_dirty,
		"signal_next_tick": w.signal_next_tick, "vision_next_tick": w.vision_next_tick,
		"coverage_version": w.coverage_version, "vision_version": w.vision_version,
	}


## Rebuilds a world from a snapshot. Returns null if it cannot be restored.
static func from_dict(d: Dictionary) -> SimWorld:
	if int(d.get("version", 0)) != VERSION:
		return null
	var config: MatchConfig = config_from_dict(d["config"])
	# Start from a fresh match for the same configuration (this rebuilds the
	# map and the players), then replace everything that changes during play.
	var w: SimWorld = SimSetup.create_match(config)
	for e: SimEntity in w.entities:
		if e.kind == SimEntity.Kind.BUILDING and e.def.blocks:
			w.map.set_occupied(Rect2i(e.footprint_cell, e.def.footprint), 0)
	w.entities.clear()
	w.by_id.clear()
	w.events.clear()
	w.commands.clear()

	var saved_players: Array = d["players"]
	for i: int in mini(saved_players.size(), w.players.size()):
		_restore(w.players[i], saved_players[i])

	var saved_entities: Array = d["entities"]
	for raw: Variant in saved_entities:
		var ed: Dictionary = raw
		var e: SimEntity = SimEntity.new()
		_restore(e, ed)
		var def_id: String = str(ed.get("def_id", ""))
		if def_id != "":
			e.def = w.data.entity(def_id)
			if e.def == null:
				return null  # the save refers to something this build does not have
		var orders: Array = ed.get("orders", [])
		for o_raw: Variant in orders:
			var o: SimOrder = SimOrder.new()
			_restore(o, o_raw)
			e.orders.append(o)
		w.entities.append(e)
		w.by_id[e.id] = e
		if e.kind == SimEntity.Kind.BUILDING and e.def.blocks:
			w.map.set_occupied(Rect2i(e.footprint_cell, e.def.footprint), e.id)

	w.projectiles.clear()
	var saved_projectiles: Array = d["projectiles"]
	for raw: Variant in saved_projectiles:
		var pd: Dictionary = raw
		var p: SimProjectile = SimProjectile.new()
		_restore(p, pd)
		p.weapon = w.data.weapon(str(pd["weapon_id"]))
		w.projectiles.append(p)
	w.timed.clear()
	var saved_timed: Array = d["timed"]
	for raw: Variant in saved_timed:
		var td: Dictionary = raw
		var t: SimDirectives.Timed = SimDirectives.Timed.new()
		t.tick = int(td["tick"])
		t.kind = str(td["kind"])
		t.pos = td["pos"]
		t.player = int(td["player"])
		t.def = w.data.directive(str(td["def_id"]))
		w.timed.append(t)
	var saved_ais: Array = d["ais"]
	for i: int in mini(saved_ais.size(), w.ais.size()):
		var ad: Dictionary = saved_ais[i]
		_restore(w.ais[i], ad)
		w.ais[i].rng.state = int(ad["rng_state"])

	var saved_commands: Array = d.get("commands", [])
	for raw: Variant in saved_commands:
		var cmd: SimCommand = SimCommand.new()
		_restore(cmd, raw)
		w.commands.append(cmd)

	w.tick_count = int(d["tick_count"])
	w.next_id = int(d["next_id"])
	w.rng.state = int(d["rng_state"])
	w.game_over = bool(d["game_over"])
	w.winner = int(d["winner"])
	w.winner_team = int(d.get("winner_team", w.players[w.winner].team if w.winner >= 0 else -1))
	w.victory_enabled = bool(d.get("victory_enabled", true))
	w.explored.assign(_copy(d["explored"]))
	w.reveals.assign(_copy(d["reveals"]))
	w.reveal_until = _copy(d["reveal_until"])
	w.blackouts.assign(_copy(d["blackouts"]))
	w.blackout_until = _copy(d["blackout_until"])
	w.coverage.assign(_copy(d["coverage"]))
	w.visible.assign(_copy(d["visible"]))
	w.signal_links.assign(_copy(d["signal_links"]))
	w.signal_dirty = bool(d["signal_dirty"])
	w.signal_next_tick = int(d["signal_next_tick"])
	w.vision_next_tick = int(d["vision_next_tick"])
	w.coverage_version = int(d["coverage_version"])
	w.vision_version = int(d["vision_version"])
	return w


# ------------------------------------------------------------ reflection

## True for values that can be written with FileAccess.store_var and read
## back unchanged: numbers, strings, vectors, colours, packed arrays, and
## arrays or dictionaries made only of those.
static func _plain(v: Variant) -> bool:
	match typeof(v):
		TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_VECTOR3, TYPE_VECTOR4, TYPE_COLOR:
			return true
		TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_VECTOR2_ARRAY:
			return true
		TYPE_ARRAY:
			var arr: Array = v
			if arr.get_typed_builtin() == TYPE_OBJECT:
				return false  # a list of live objects, even when it is empty
			for item: Variant in arr:
				if not _plain(item):
					return false
			return true
		TYPE_DICTIONARY:
			var dict: Dictionary = v
			if dict.get_typed_value_builtin() == TYPE_OBJECT or dict.get_typed_key_builtin() == TYPE_OBJECT:
				return false
			for k: Variant in dict.keys():
				if not _plain(k) or not _plain(dict[k]):
					return false
			return true
		_:
			return false


## A deep copy of a plain value. Packed arrays are shared by reference in
## Godot 4, so without this a snapshot and the live world (or two worlds made
## from one snapshot) would be editing the same arrays.
static func _copy(v: Variant) -> Variant:
	match typeof(v):
		TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_VECTOR2_ARRAY:
			return v.duplicate()
		TYPE_ARRAY:
			var src: Array = v
			var out: Array = []
			for item: Variant in src:
				out.append(_copy(item))
			return out
		TYPE_DICTIONARY:
			var src_d: Dictionary = v
			var out_d: Dictionary = {}
			for k: Variant in src_d.keys():
				out_d[k] = _copy(src_d[k])
			return out_d
		_:
			return v


## Every script variable of `obj` that holds plain data, by name.
static func _dump(obj: Object, skip: Array[String]) -> Dictionary:
	var out: Dictionary = {}
	for prop: Dictionary in obj.get_property_list():
		if int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		var prop_name: String = prop["name"]
		if skip.has(prop_name):
			continue
		var v: Variant = obj.get(prop_name)
		if _plain(v):
			out[prop_name] = _copy(v)
	return out


## Writes saved values back into `obj`. Typed arrays and dictionaries keep
## their element types.
static func _restore(obj: Object, d: Variant) -> void:
	var values: Dictionary = d
	for key: Variant in values.keys():
		var prop_name: String = str(key)
		if prop_name == "orders" or prop_name == "def_id":
			continue  # rebuilt by the caller
		var current: Variant = obj.get(prop_name)
		var v: Variant = _copy(values[key])
		if typeof(current) == TYPE_ARRAY and typeof(v) == TYPE_ARRAY:
			var arr: Array = current
			arr.assign(v)
		elif typeof(current) == TYPE_DICTIONARY and typeof(v) == TYPE_DICTIONARY:
			var dict: Dictionary = current
			dict.assign(v)
		elif typeof(current) == typeof(v):
			obj.set(prop_name, v)
