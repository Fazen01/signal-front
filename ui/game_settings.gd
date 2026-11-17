class_name GameSettings
extends RefCounted
## Player settings kept in user://settings.cfg: audio volumes, video options
## and whether hotkey hints are shown.

const PATH: String = "user://settings.cfg"
const BUSES: Array[String] = ["Master", "SFX", "Ambient"]
const MSAA_NAMES: Array[String] = ["Off", "2x", "4x"]
const AUTOSAVE_MINUTES: Array[int] = [0, 2, 5, 10]
const AUTOSAVE_NAMES: Array[String] = ["Off", "Every 2 minutes", "Every 5 minutes", "Every 10 minutes"]

static var volumes: Dictionary[String, float] = {"Master": 0.8, "SFX": 0.8, "Ambient": 0.5}
static var fullscreen: bool = false
static var vsync: bool = true
static var msaa: int = 1  ## index into MSAA_NAMES
static var shadows: bool = true
static var key_hints: bool = true
static var autosave_minutes: int = 5  ## 0 switches autosave off
static var _loaded: bool = false


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(PATH) == OK:
		for bus: String in BUSES:
			volumes[bus] = clampf(float(cfg.get_value("audio", bus, volumes[bus])), 0.0, 1.0)
		fullscreen = bool(cfg.get_value("video", "fullscreen", fullscreen))
		vsync = bool(cfg.get_value("video", "vsync", vsync))
		msaa = clampi(int(cfg.get_value("video", "msaa", msaa)), 0, MSAA_NAMES.size() - 1)
		shadows = bool(cfg.get_value("video", "shadows", shadows))
		key_hints = bool(cfg.get_value("interface", "key_hints", key_hints))
		var minutes: int = int(cfg.get_value("game", "autosave_minutes", autosave_minutes))
		autosave_minutes = minutes if AUTOSAVE_MINUTES.has(minutes) else 5
	apply()
	apply_video()


static func set_volume(bus: String, value: float) -> void:
	volumes[bus] = clampf(value, 0.0, 1.0)
	apply()


static func save() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	for bus: String in BUSES:
		cfg.set_value("audio", bus, volumes[bus])
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("video", "vsync", vsync)
	cfg.set_value("video", "msaa", msaa)
	cfg.set_value("video", "shadows", shadows)
	cfg.set_value("interface", "key_hints", key_hints)
	cfg.set_value("game", "autosave_minutes", autosave_minutes)
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


## Applies window mode, vsync and anti-aliasing. Shadows are read by the
## battle scene when it builds or refreshes its sun.
static func apply_video() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		var levels: Array[int] = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X]
		tree.root.msaa_3d = levels[msaa] as Viewport.MSAA
	if DisplayServer.get_name() == "headless":
		return
	var mode: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
