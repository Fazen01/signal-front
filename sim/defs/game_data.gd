class_name GameData
extends RefCounted
## Loads and validates every definition in res://data. All tunable numbers
## live in those JSON files; the simulation reads them through this class.

const DAMAGE_TYPES: Array[String] = ["ballistic", "explosive", "piercing", "flak"]
const MOVE_NAMES: Array[String] = ["none", "infantry", "vehicle", "air"]

const WEAPON_KEYS: Array[String] = [
	"name", "damage_type", "damage", "range", "min_range", "cooldown", "projectile_speed",
	"homing", "splash", "scatter", "hits_ground", "hits_air", "fx",
]
const ENTITY_KEYS: Array[String] = [
	"name", "desc", "faction", "tier", "cost", "build_time", "bandwidth", "bandwidth_provided",
	"hp", "armor", "move", "speed", "turn_rate", "radius", "sight", "weapons", "turret", "model",
	"hotkey", "requires", "buildable", "builder", "builds", "harvester", "capacity", "footprint",
	"signal_radius", "signal_root", "depot", "produces", "stealth",
]
const DIRECTIVE_KEYS: Array[String] = [
	"name", "desc", "cost", "cooldown", "radius", "duration", "target", "damage", "shells",
	"splash", "heal_fraction", "radius_mult", "squad",
]
const FACTION_KEYS: Array[String] = [
	"name", "desc", "hq", "start_units", "linked_range_bonus", "dark_rof_mult", "playable",
]

static var _shared: GameData = null

var weapons: Dictionary[String, WeaponDef] = {}
var entities: Dictionary[String, EntityDef] = {}
var factions: Dictionary[String, FactionDef] = {}
var directives: Dictionary[String, DirectiveDef] = {}
var directive_order: Array[String] = []  ## ids in Directive-bar order
var armor_classes: Array[String] = []
var damage_table: Array[PackedFloat32Array] = []  ## [damage_type][armor_class]
var errors: Array[String] = []

# Rules (data/rules.json)
var tick_rate: int = 20
var start_salvage: int = 600
var queue_max: int = 5
var bandwidth_max: int = 200
var wreck_fraction: float = 0.25
var wreck_decay_seconds: float = 240.0
var refund_fraction: float = 1.0
var link_range: float = 30.0
var coverage_cell: float = 2.0
var dark_rof_mult: float = 0.7
var dark_sight_mult: float = 0.7
var dark_turret_rof_mult: float = 0.5
var forest_infantry_damage_mult: float = 0.6
var forest_vehicle_speed_mult: float = 0.5
var harvest_seconds: float = 4.0
var unload_seconds: float = 1.0
var repair_rate: float = 0.04
var uplink_income_per_second: int = 3
var uplink_capture_seconds: float = 8.0
var command_point_value: int = 300
var start_command_points: int = 1
var near_coverage_range: float = 15.0
var rank_thresholds: Array[float] = [2.0, 4.0, 8.0]  ## multiples of the unit's own cost
var rank_damage_bonus: float = 0.15
var rank_health_bonus: float = 0.10
var rank_self_repair: float = 0.01


## Shared instance, loaded once. Definitions are immutable after loading.
static func shared() -> GameData:
	if _shared == null:
		_shared = GameData.new()
		_shared.load_all()
	return _shared


func load_all() -> bool:
	errors.clear()
	_load_rules(_read_json("res://data/rules.json"))
	_load_weapons(_read_json("res://data/weapons.json"))
	_load_entities(_read_json("res://data/units.json"), false)
	_load_entities(_read_json("res://data/buildings.json"), true)
	_load_factions(_read_json("res://data/factions.json"))
	_load_directives(_read_json("res://data/directives.json"))
	_validate()
	for e: String in errors:
		push_error("GameData: " + e)
	return errors.is_empty()


func entity(id: String) -> EntityDef:
	return entities.get(id, null)


func weapon(id: String) -> WeaponDef:
	return weapons.get(id, null)


func faction(id: String) -> FactionDef:
	return factions.get(id, null)


func directive(id: String) -> DirectiveDef:
	return directives.get(id, null)


func damage_multiplier(damage_type: int, armor: int) -> float:
	return damage_table[damage_type][armor]


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		errors.append("missing data file %s" % path)
		return {}
	var text: String = FileAccess.get_file_as_string(path)
	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		errors.append("%s: %s at line %d" % [path, json.get_error_message(), json.get_error_line()])
		return {}
	if typeof(json.data) != TYPE_DICTIONARY:
		errors.append("%s: top level must be an object" % path)
		return {}
	var result: Dictionary = json.data
	return result


func _check_keys(owner_id: String, d: Dictionary, allowed: Array[String]) -> void:
	for k: Variant in d.keys():
		if not allowed.has(str(k)):
			errors.append("%s: unknown key '%s'" % [owner_id, str(k)])


func _strings(d: Dictionary, key: String) -> Array[String]:
	var out: Array[String] = []
	if d.has(key) and typeof(d[key]) == TYPE_ARRAY:
		var arr: Array = d[key]
		for v: Variant in arr:
			out.append(str(v))
	return out


func _load_rules(d: Dictionary) -> void:
	if d.is_empty():
		return
	tick_rate = int(d.get("tick_rate", tick_rate))
	start_salvage = int(d.get("start_salvage", start_salvage))
	queue_max = int(d.get("queue_max", queue_max))
	bandwidth_max = int(d.get("bandwidth_max", bandwidth_max))
	wreck_fraction = float(d.get("wreck_fraction", wreck_fraction))
	wreck_decay_seconds = float(d.get("wreck_decay_seconds", wreck_decay_seconds))
	refund_fraction = float(d.get("refund_fraction", refund_fraction))
	link_range = float(d.get("link_range", link_range))
	coverage_cell = float(d.get("coverage_cell", coverage_cell))
	dark_rof_mult = float(d.get("dark_rof_mult", dark_rof_mult))
	dark_sight_mult = float(d.get("dark_sight_mult", dark_sight_mult))
	dark_turret_rof_mult = float(d.get("dark_turret_rof_mult", dark_turret_rof_mult))
	forest_infantry_damage_mult = float(d.get("forest_infantry_damage_mult", forest_infantry_damage_mult))
	forest_vehicle_speed_mult = float(d.get("forest_vehicle_speed_mult", forest_vehicle_speed_mult))
	harvest_seconds = float(d.get("harvest_seconds", harvest_seconds))
	unload_seconds = float(d.get("unload_seconds", unload_seconds))
	repair_rate = float(d.get("repair_rate", repair_rate))
	uplink_income_per_second = int(d.get("uplink_income_per_second", uplink_income_per_second))
	uplink_capture_seconds = float(d.get("uplink_capture_seconds", uplink_capture_seconds))
	command_point_value = int(d.get("command_point_value", command_point_value))
	start_command_points = int(d.get("start_command_points", start_command_points))
	near_coverage_range = float(d.get("near_coverage_range", near_coverage_range))
	rank_damage_bonus = float(d.get("rank_damage_bonus", rank_damage_bonus))
	rank_health_bonus = float(d.get("rank_health_bonus", rank_health_bonus))
	rank_self_repair = float(d.get("rank_self_repair", rank_self_repair))
	if d.has("rank_thresholds"):
		rank_thresholds.clear()
		var raw_ranks: Array = d["rank_thresholds"]
		for v: Variant in raw_ranks:
			rank_thresholds.append(float(v))
	armor_classes = _strings(d, "armor_classes")
	damage_table.clear()
	var table: Dictionary = d.get("damage_table", {})
	for type_name: String in DAMAGE_TYPES:
		var row: PackedFloat32Array = PackedFloat32Array()
		if not table.has(type_name):
			errors.append("rules: damage_table is missing '%s'" % type_name)
		else:
			var raw: Array = table[type_name]
			for v: Variant in raw:
				row.append(float(v))
		if row.size() != armor_classes.size():
			errors.append("rules: damage_table '%s' needs %d entries" % [type_name, armor_classes.size()])
			row.resize(armor_classes.size())
		damage_table.append(row)


func _load_weapons(d: Dictionary) -> void:
	for key: Variant in d.keys():
		var id: String = str(key)
		var src: Dictionary = d[key]
		_check_keys("weapon " + id, src, WEAPON_KEYS)
		var w: WeaponDef = WeaponDef.new()
		w.id = id
		w.name = str(src.get("name", id))
		w.damage_type = DAMAGE_TYPES.find(str(src.get("damage_type", "")))
		if w.damage_type < 0:
			errors.append("weapon %s: bad damage_type" % id)
			w.damage_type = 0
		w.damage = float(src.get("damage", 0.0))
		w.max_range = float(src.get("range", 0.0))
		w.min_range = float(src.get("min_range", 0.0))
		w.cooldown = float(src.get("cooldown", 1.0))
		w.projectile_speed = float(src.get("projectile_speed", 0.0))
		w.homing = bool(src.get("homing", false))
		w.splash = float(src.get("splash", 0.0))
		w.scatter = float(src.get("scatter", 0.0))
		w.hits_ground = bool(src.get("hits_ground", true))
		w.hits_air = bool(src.get("hits_air", false))
		w.fx = str(src.get("fx", "tracer"))
		weapons[id] = w


func _load_entities(d: Dictionary, building: bool) -> void:
	for key: Variant in d.keys():
		var id: String = str(key)
		var src: Dictionary = d[key]
		_check_keys("entity " + id, src, ENTITY_KEYS)
		if entities.has(id):
			errors.append("entity %s: duplicate id" % id)
		var e: EntityDef = EntityDef.new()
		e.id = id
		e.is_building = building
		e.name = str(src.get("name", id))
		e.desc = str(src.get("desc", ""))
		e.faction = str(src.get("faction", ""))
		e.tier = int(src.get("tier", 1))
		e.cost = int(src.get("cost", 0))
		e.build_time = float(src.get("build_time", 1.0))
		e.bandwidth = int(src.get("bandwidth", 0))
		e.bandwidth_provided = int(src.get("bandwidth_provided", 0))
		e.hp = float(src.get("hp", 1.0))
		e.armor = armor_classes.find(str(src.get("armor", "")))
		if e.armor < 0:
			errors.append("entity %s: bad armor class" % id)
			e.armor = 0
		e.move = MOVE_NAMES.find(str(src.get("move", "none")))
		if e.move < 0:
			errors.append("entity %s: bad move class" % id)
			e.move = 0
		e.speed = float(src.get("speed", 0.0))
		e.turn_rate = float(src.get("turn_rate", 10.0))
		e.sight = float(src.get("sight", 8.0))
		for wid: String in _strings(src, "weapons"):
			if weapons.has(wid):
				e.weapons.append(weapons[wid])
			else:
				errors.append("entity %s: unknown weapon '%s'" % [id, wid])
		e.turret = bool(src.get("turret", false))
		e.model = str(src.get("model", id))
		e.hotkey = str(src.get("hotkey", ""))
		e.requires = _strings(src, "requires")
		e.buildable = bool(src.get("buildable", true))
		e.builder = bool(src.get("builder", false))
		e.builds = _strings(src, "builds")
		e.harvester = bool(src.get("harvester", false))
		e.capacity = int(src.get("capacity", 0))
		e.stealth = bool(src.get("stealth", false))
		if src.has("footprint"):
			var fp: Array = src["footprint"]
			if fp.size() == 2:
				e.footprint = Vector2i(int(fp[0]), int(fp[1]))
			else:
				errors.append("entity %s: footprint needs two numbers" % id)
		e.signal_radius = float(src.get("signal_radius", 0.0))
		e.signal_root = bool(src.get("signal_root", false))
		e.depot = bool(src.get("depot", false))
		e.produces = _strings(src, "produces")
		if building:
			e.radius = float(src.get("radius", float(maxi(e.footprint.x, e.footprint.y)) * coverage_cell * 0.5))
		else:
			e.radius = float(src.get("radius", 0.5))
		entities[id] = e


func _load_factions(d: Dictionary) -> void:
	for key: Variant in d.keys():
		var id: String = str(key)
		var src: Dictionary = d[key]
		_check_keys("faction " + id, src, FACTION_KEYS)
		var f: FactionDef = FactionDef.new()
		f.id = id
		f.name = str(src.get("name", id))
		f.desc = str(src.get("desc", ""))
		f.hq = str(src.get("hq", ""))
		f.start_units = _strings(src, "start_units")
		f.linked_range_bonus = float(src.get("linked_range_bonus", 0.0))
		f.dark_rof_mult = float(src.get("dark_rof_mult", -1.0))
		f.playable = bool(src.get("playable", true))
		factions[id] = f


func _load_directives(d: Dictionary) -> void:
	for key: Variant in d.keys():
		var id: String = str(key)
		var src: Dictionary = d[key]
		_check_keys("directive " + id, src, DIRECTIVE_KEYS)
		var dd: DirectiveDef = DirectiveDef.new()
		dd.id = id
		dd.name = str(src.get("name", id))
		dd.desc = str(src.get("desc", ""))
		dd.cost = int(src.get("cost", 1))
		dd.cooldown = float(src.get("cooldown", 60.0))
		dd.radius = float(src.get("radius", 0.0))
		dd.duration = float(src.get("duration", 0.0))
		dd.target = str(src.get("target", "anywhere"))
		dd.damage = float(src.get("damage", 0.0))
		dd.shells = int(src.get("shells", 0))
		dd.splash = float(src.get("splash", 0.0))
		dd.heal_fraction = float(src.get("heal_fraction", 0.0))
		dd.radius_mult = float(src.get("radius_mult", 1.0))
		dd.squad = _strings(src, "squad")
		dd.slot = directive_order.size()
		if not DirectiveDef.TARGET_MODES.has(dd.target):
			errors.append("directive %s: bad target mode '%s'" % [id, dd.target])
		if dd.cost < 1 or dd.cooldown <= 0.0:
			errors.append("directive %s: bad cost or cooldown" % id)
		for u: String in dd.squad:
			if not entities.has(u):
				errors.append("directive %s: unknown squad unit '%s'" % [id, u])
		directives[id] = dd
		directive_order.append(id)


func _validate() -> void:
	if weapons.is_empty():
		errors.append("no weapons defined")
	if entities.is_empty():
		errors.append("no entities defined")
	if factions.is_empty():
		errors.append("no factions defined")
	for w: WeaponDef in weapons.values():
		if w.damage <= 0.0:
			errors.append("weapon %s: damage must be positive" % w.id)
		if w.max_range <= 0.0:
			errors.append("weapon %s: range must be positive" % w.id)
		if w.cooldown <= 0.0:
			errors.append("weapon %s: cooldown must be positive" % w.id)
		if w.min_range >= w.max_range:
			errors.append("weapon %s: min_range must be below range" % w.id)
		if not w.hits_ground and not w.hits_air:
			errors.append("weapon %s: must hit ground or air" % w.id)
	for e: EntityDef in entities.values():
		if not factions.has(e.faction):
			errors.append("entity %s: unknown faction '%s'" % [e.id, e.faction])
		if e.hp <= 0.0:
			errors.append("entity %s: hp must be positive" % e.id)
		if e.cost < 0 or e.build_time <= 0.0:
			errors.append("entity %s: bad cost or build_time" % e.id)
		if e.is_building:
			if e.move != EntityDef.MOVE_NONE:
				errors.append("building %s: must not move" % e.id)
			if e.footprint.x < 1 or e.footprint.y < 1:
				errors.append("building %s: bad footprint" % e.id)
		else:
			if e.move == EntityDef.MOVE_NONE or e.speed <= 0.0:
				errors.append("unit %s: needs a move class and speed" % e.id)
			if e.bandwidth < 1:
				errors.append("unit %s: bandwidth must be at least 1" % e.id)
			if e.harvester and e.capacity <= 0:
				errors.append("unit %s: harvester needs capacity" % e.id)
		for other: String in e.requires + e.builds + e.produces:
			if not entities.has(other):
				errors.append("entity %s: refers to unknown entity '%s'" % [e.id, other])
		for b: String in e.builds:
			if entities.has(b) and not entities[b].is_building:
				errors.append("entity %s: builds non-building '%s'" % [e.id, b])
		for p: String in e.produces:
			if entities.has(p) and entities[p].is_building:
				errors.append("entity %s: produces building '%s'" % [e.id, p])
	for f: FactionDef in factions.values():
		if not entities.has(f.hq) or not entities[f.hq].signal_root:
			errors.append("faction %s: hq '%s' must be a signal_root building" % [f.id, f.hq])
		for u: String in f.start_units:
			if not entities.has(u):
				errors.append("faction %s: unknown start unit '%s'" % [f.id, u])
