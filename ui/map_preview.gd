class_name MapPreview
extends Control
## A small picture of the battlefield a match setup would give: the land,
## the salvage fields and uplink sites, and where each seat starts. It is
## drawn from the same generator call the match itself will make.

var caption: String = ""  ## the map's name and region, for a label beside the picture
var _texture: ImageTexture = null
var _map: SimMap = null
var _starts: Array[Vector2] = []
var _colors: Array[Color] = []


func _init() -> void:
	custom_minimum_size = Vector2(196.0, 196.0)
	mouse_filter = Control.MOUSE_FILTER_PASS
	tooltip_text = "The battlefield this setup gives. Squares: where each seat starts. Gold: salvage. White: uplink sites."


## Shows the map `config` would be played on.
func show_config(config: MatchConfig) -> void:
	_map = SimSetup.map_for(config)
	_starts = SimSetup.assign_starts(config, _map.starts)
	_colors.clear()
	for i: int in config.player_count():
		_colors.append(MatchConfig.TEAM_COLORS[i % MatchConfig.TEAM_COLORS.size()])
	var look: RegionLook = RegionLook.of(_map.region)
	var palette: Array[Color] = [look.map_ground, look.map_forest, look.map_rock, look.map_water]
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(_map.w * _map.h * 3)
	for i: int in _map.w * _map.h:
		var c: Color = palette[_map.terrain[i]]
		if _map.high[i] != 0:
			c = c.lightened(0.22)
		bytes[i * 3] = int(c.r * 255.0)
		bytes[i * 3 + 1] = int(c.g * 255.0)
		bytes[i * 3 + 2] = int(c.b * 255.0)
	_texture = ImageTexture.create_from_image(Image.create_from_data(_map.w, _map.h, false, Image.FORMAT_RGB8, bytes))
	caption = "%s, %s" % [_map.name, str(SimMapGen.REGION_NAMES.get(_map.region, _map.region))]
	queue_redraw()


## How many seats are drawn (for tests).
func seats_shown() -> int:
	return _starts.size()


func _draw() -> void:
	if _texture == null or _map == null:
		return
	var side: float = minf(size.x, size.y)
	var origin: Vector2 = (size - Vector2(side, side)) * 0.5
	draw_texture_rect(_texture, Rect2(origin, Vector2(side, side)), false)
	var scale_to: float = side / _map.world_size().x
	for f: Vector3 in _map.field_spots:
		draw_circle(origin + Vector2(f.x, f.y) * scale_to, 2.0 + minf(f.z / 2500.0, 2.0), Color(1.0, 0.82, 0.3))
	for u: Vector2 in _map.uplink_spots:
		var at: Vector2 = origin + u * scale_to
		draw_colored_polygon(PackedVector2Array([at + Vector2(0.0, -4.0), at + Vector2(4.0, 0.0), at + Vector2(0.0, 4.0), at + Vector2(-4.0, 0.0)]), Color(0.95, 0.95, 1.0))
	for i: int in _starts.size():
		var at: Vector2 = origin + _starts[i] * scale_to
		draw_rect(Rect2(at - Vector2(6.0, 6.0), Vector2(12.0, 12.0)), Color(0.0, 0.0, 0.0, 0.7))
		draw_rect(Rect2(at - Vector2(5.0, 5.0), Vector2(10.0, 10.0)), _colors[i])
	draw_rect(Rect2(origin, Vector2(side, side)), Color(1.0, 1.0, 1.0, 0.25), false, 1.0)
