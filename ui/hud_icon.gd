class_name HudIcon
extends Control
## A small drawn pictogram for the HUD: no image files, just a few shapes.

var kind: String = "salvage"
var color: Color = Color.WHITE


func _init() -> void:
	custom_minimum_size = Vector2(22.0, 22.0)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c: Vector2 = size * 0.5
	var r: float = minf(size.x, size.y) * 0.5
	match kind:
		"salvage":
			# A hexagonal nut: scrap worth hauling home.
			var pts: PackedVector2Array = PackedVector2Array()
			for i: int in 6:
				var a: float = TAU * float(i) / 6.0 + PI / 6.0
				pts.append(c + Vector2(cos(a), sin(a)) * r * 0.95)
			draw_colored_polygon(pts, color)
			draw_circle(c, r * 0.38, Color(0.04, 0.06, 0.08))
		"bandwidth":
			# Signal bars.
			var step: float = size.x / 4.0
			for i: int in 4:
				var tall: float = size.y * (0.3 + 0.23 * float(i))
				draw_rect(Rect2(float(i) * step + 1.0, size.y - tall, step - 2.0, tall), color)
		"clock":
			draw_arc(c, r * 0.84, 0.0, TAU, 28, color, 2.0, true)
			draw_line(c, c + Vector2(0.0, -r * 0.55), color, 2.0, true)
			draw_line(c, c + Vector2(r * 0.42, 0.0), color, 2.0, true)
		"points":
			# A four-pointed star: Command Points.
			var star: PackedVector2Array = PackedVector2Array()
			for i: int in 8:
				var a: float = TAU * float(i) / 8.0 - PI * 0.5
				star.append(c + Vector2(cos(a), sin(a)) * (r * 0.98 if i % 2 == 0 else r * 0.36))
			draw_colored_polygon(star, color)
		_:
			draw_circle(c, r * 0.6, color)
