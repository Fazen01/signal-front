class_name GameSettings
extends RefCounted
## Player settings kept in user://settings.cfg: volumes for now.

const PATH: String = "user://settings.cfg"
const BUSES: Array[String] = ["Master", "SFX", "Ambient"]

static var volumes: Dictionary[String, float] = {"Master": 0.8, "SFX": 0.8, "Ambient": 0.5}
static var _loaded: bool = false


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(PATH) == OK:
		for bus: String in BUSES:
			volumes[bus] = clampf(float(cfg.get_value("audio", bus, volumes[bus])), 0.0, 1.0)
	apply()


static func set_volume(bus: String, value: float) -> void:
	volumes[bus] = clampf(value, 0.0, 1.0)
	apply()


static func save() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	for bus: String in BUSES:
		cfg.set_value("audio", bus, volumes[bus])
	cfg.save(PATH)


## Creates the SFX and Ambient buses if needed and sets every bus volume.
static func apply() -> void:
	for bus: String in BUSES:
		var index: int = AudioServer.get_bus_index(bus)
		if index < 0:
			AudioServer.add_bus()
			index = AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, "Master")
		var v: float = volumes[bus]
		AudioServer.set_bus_mute(index, v < 0.01)
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(v, 0.01)))
