class_name HudIcon
extends Control
## A small drawn pictogram for the HUD: no image files, just a few shapes.

var kind: String = "salvage"
var color: Color = Color.WHITE

const HOLE: Color = Color(0.04, 0.06, 0.08)  ## the dark cut out of a filled shape


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
			draw_circle(c, r * 0.38, HOLE)
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
		"emblem_signal":
			# The game's own mark: a transmitter and its rings.
			draw_circle(c + Vector2(0.0, r * 0.45), r * 0.2, color)
			for i: int in 3:
				draw_arc(c + Vector2(0.0, r * 0.45), r * (0.5 + 0.38 * float(i)), -PI * 0.78, -PI * 0.22, 14, color, 2.0, true)
		"emblem_aegis":
			# A shield.
			var shield: PackedVector2Array = PackedVector2Array([
				c + Vector2(-r * 0.78, -r * 0.82), c + Vector2(r * 0.78, -r * 0.82), c + Vector2(r * 0.78, r * 0.05),
				c + Vector2(0.0, r * 0.98), c + Vector2(-r * 0.78, r * 0.05)])
			draw_colored_polygon(shield, color)
			draw_line(c + Vector2(0.0, -r * 0.55), c + Vector2(0.0, r * 0.55), HOLE, 2.0, true)
			draw_line(c + Vector2(-r * 0.45, -r * 0.2), c + Vector2(r * 0.45, -r * 0.2), HOLE, 2.0, true)
		"emblem_foundry":
			# A cog.
			var cog: PackedVector2Array = PackedVector2Array()
			for i: int in 32:
				var a: float = TAU * float(i) / 32.0
				cog.append(c + Vector2(cos(a), sin(a)) * (r * 0.98 if (i >> 1) % 2 == 0 else r * 0.72))
			draw_colored_polygon(cog, color)
			draw_circle(c, r * 0.32, HOLE)
		"emblem_nomad":
			# A wheel on the road.
			draw_arc(c, r * 0.84, 0.0, TAU, 28, color, 2.5, true)
			for i: int in 6:
				var a: float = TAU * float(i) / 6.0 + 0.3
				draw_line(c, c + Vector2(cos(a), sin(a)) * r * 0.8, color, 1.6, true)
			draw_circle(c, r * 0.24, color)
		"emblem_vesper":
			# A cell of the lattice, with its core lit.
			var hex: PackedVector2Array = PackedVector2Array()
			for i: int in 7:
				var a: float = TAU * float(i) / 6.0
				hex.append(c + Vector2(cos(a), sin(a)) * r * 0.92)
			draw_polyline(hex, color, 2.0, true)
			draw_circle(c, r * 0.34, color)
		"emblem_verdigris":
			# A keep inside an eight-sided wall.
			var wall: PackedVector2Array = PackedVector2Array()
			for i: int in 9:
				var a: float = TAU * float(i) / 8.0 + PI / 8.0
				wall.append(c + Vector2(cos(a), sin(a)) * r * 0.96)
			draw_polyline(wall, color, 2.0, true)
			draw_rect(Rect2(c.x - r * 0.36, c.y - r * 0.2, r * 0.72, r * 0.68), color)
			for i: int in 3:
				draw_rect(Rect2(c.x - r * 0.36 + float(i) * r * 0.27, c.y - r * 0.46, r * 0.18, r * 0.3), color)
		"emblem_zephyr":
			# Wings: two chevrons climbing.
			for i: int in 2:
				var y: float = c.y + r * (0.55 - 0.6 * float(i))
				draw_polyline(PackedVector2Array([
					Vector2(c.x - r * 0.9, y), Vector2(c.x, y - r * 0.62), Vector2(c.x + r * 0.9, y)]), color, 2.6, true)
			draw_circle(c + Vector2(0.0, -r * 0.82), r * 0.14, color)
		"emblem_tally":
			# Four strokes and the one that crosses them out.
			for i: int in 4:
				var x: float = c.x + r * (-0.66 + 0.44 * float(i))
				draw_line(Vector2(x, c.y - r * 0.78), Vector2(x, c.y + r * 0.78), color, 2.4, true)
			draw_line(c + Vector2(-r * 0.98, r * 0.5), c + Vector2(r * 0.98, -r * 0.5), color, 2.4, true)
		"emblem_veil":
			# Half seen: a diamond with one side in shadow.
			var top: Vector2 = c + Vector2(0.0, -r * 0.96)
			var low: Vector2 = c + Vector2(0.0, r * 0.96)
			draw_colored_polygon(PackedVector2Array([top, low, c + Vector2(-r * 0.7, 0.0)]), color)
			draw_polyline(PackedVector2Array([top, c + Vector2(r * 0.7, 0.0), low]), color, 1.6, true)
		"emblem_bracken":
			# A sprout: a stem and two leaves.
			draw_line(c + Vector2(0.0, r * 0.95), c + Vector2(0.0, -r * 0.1), color, 2.2, true)
			for side: float in [-1.0, 1.0]:
				var leaf: PackedVector2Array = PackedVector2Array([
					c + Vector2(0.0, r * 0.05), c + Vector2(side * r * 0.3, -r * 0.62), c + Vector2(side * r * 0.95, -r * 0.9),
					c + Vector2(side * r * 0.82, -r * 0.22), c + Vector2(side * r * 0.36, r * 0.12)])
				draw_colored_polygon(leaf, color)
		"emblem_lodestone":
			# A horseshoe magnet, poles down, with a gap at each tip.
			draw_arc(c + Vector2(0.0, -r * 0.12), r * 0.56, PI, TAU, 16, color, r * 0.4, true)
			for side: float in [-1.0, 1.0]:
				draw_rect(Rect2(c.x + side * r * 0.56 - r * 0.2, c.y - r * 0.14, r * 0.4, r * 0.56), color)
				draw_rect(Rect2(c.x + side * r * 0.56 - r * 0.2, c.y + r * 0.56, r * 0.4, r * 0.34), color)
		_:
			draw_circle(c, r * 0.6, color)
