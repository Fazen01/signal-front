class_name UiTheme
extends RefCounted
## The game's interface theme, built in code and set on the root window so
## every menu, panel and HUD element shares one look: dark glass panels with
## a thin cool border, cyan for the signal, gold for salvage and Directives.

const PANEL: Color = Color(0.045, 0.065, 0.09, 0.90)
const PANEL_SOLID: Color = Color(0.05, 0.07, 0.10, 0.97)
const RAISED: Color = Color(0.125, 0.18, 0.24, 0.97)
const RAISED_HOT: Color = Color(0.17, 0.28, 0.38, 0.98)
const PRESSED: Color = Color(0.13, 0.36, 0.52, 1.0)
const SUNK: Color = Color(0.025, 0.035, 0.05, 0.95)
const LINE: Color = Color(0.24, 0.42, 0.58, 0.75)
const LINE_SOFT: Color = Color(0.27, 0.45, 0.60, 0.45)
const ACCENT: Color = Color(0.42, 0.82, 1.0)
const GOLD: Color = Color(1.0, 0.82, 0.35)
const RED: Color = Color(1.0, 0.4, 0.35)
const TEXT: Color = Color(0.88, 0.92, 0.95)
const DIM: Color = Color(0.60, 0.67, 0.72)
const FAINT: Color = Color(0.38, 0.44, 0.50)

static var _theme: Theme = null
static var _heading: FontVariation = null
static var _strong: FontVariation = null


## A flat box with rounded corners, a hairline border and optional shadow.
static func box(fill: Color, border: Color, radius: int = 5, border_px: int = 1, margin: float = 8.0, shadow: int = 0) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(border_px)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	sb.anti_aliasing = true
	if shadow > 0:
		sb.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
		sb.shadow_size = shadow
	return sb


## The standard glass panel. `accent` tints its border.
static func panel(accent: Color = LINE, margin: float = 10.0) -> StyleBoxFlat:
	var sb: StyleBoxFlat = box(PANEL, accent, 6, 1, margin, 6)
	# A brighter top edge, as if lit from above.
	sb.border_width_top = 2
	return sb


## Wide-spaced, heavier lettering for titles.
static func heading_font() -> FontVariation:
	if _heading == null:
		_heading = FontVariation.new()
		_heading.base_font = ThemeDB.fallback_font
		_heading.variation_embolden = 0.9
		_heading.spacing_glyph = 3
	return _heading


## Slightly heavier lettering for values and button captions.
static func strong_font() -> FontVariation:
	if _strong == null:
		_strong = FontVariation.new()
		_strong.base_font = ThemeDB.fallback_font
		_strong.variation_embolden = 0.5
	return _strong


static func label(text: String, font_px: int, color: Color = TEXT) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_px)
	l.add_theme_color_override("font_color", color)
	return l


## A panel title: spaced capitals in the accent colour.
static func title(text: String, font_px: int = 26, color: Color = ACCENT) -> Label:
	var l: Label = label(text, font_px, color)
	l.add_theme_font_override("font", heading_font())
	return l


## A small spaced caption above a value ("SALVAGE", "MAP").
static func caption(text: String, color: Color = DIM) -> Label:
	var l: Label = label(text, 11, color)
	l.add_theme_font_override("font", heading_font())
	return l


## A thin horizontal rule in the accent colour.
static func rule(color: Color = LINE, thickness: float = 2.0) -> ColorRect:
	var r: ColorRect = ColorRect.new()
	r.color = color
	r.custom_minimum_size = Vector2(0.0, thickness)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t: Theme = Theme.new()
	t.default_font_size = 15

	# Buttons, and the things that are buttons underneath.
	for kind: String in ["Button", "OptionButton", "MenuButton"]:
		t.set_stylebox("normal", kind, box(RAISED, LINE_SOFT, 5, 1, 9.0))
		t.set_stylebox("hover", kind, box(RAISED_HOT, ACCENT, 5, 1, 9.0))
		t.set_stylebox("pressed", kind, box(PRESSED, ACCENT, 5, 1, 9.0))
		t.set_stylebox("disabled", kind, box(Color(0.075, 0.10, 0.13, 0.92), Color(0.22, 0.29, 0.36, 0.45), 5, 1, 9.0))
		t.set_stylebox("focus", kind, box(Color(0.0, 0.0, 0.0, 0.0), Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.6), 5, 1, 9.0))
		t.set_color("font_color", kind, TEXT)
		t.set_color("font_hover_color", kind, Color.WHITE)
		t.set_color("font_pressed_color", kind, Color.WHITE)
		t.set_color("font_focus_color", kind, Color.WHITE)
		t.set_color("font_hover_pressed_color", kind, Color.WHITE)
		t.set_color("font_disabled_color", kind, FAINT)
	t.set_color("font_color", "CheckBox", TEXT)
	t.set_color("font_hover_color", "CheckBox", Color.WHITE)
	t.set_color("font_pressed_color", "CheckBox", TEXT)
	t.set_color("font_color", "CheckButton", TEXT)
	t.set_color("font_hover_color", "CheckButton", Color.WHITE)
	t.set_color("font_pressed_color", "CheckButton", TEXT)
	for kind: String in ["CheckBox", "CheckButton"]:
		for state: String in ["normal", "pressed", "hover", "hover_pressed", "disabled", "focus"]:
			t.set_stylebox(state, kind, box(Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0), 4, 0, 5.0))

	# "ChipButton": a small, tight button (production queue entries).
	t.set_type_variation("ChipButton", "Button")
	t.set_stylebox("normal", "ChipButton", box(RAISED, LINE_SOFT, 4, 1, 4.0))
	t.set_stylebox("hover", "ChipButton", box(RAISED_HOT, ACCENT, 4, 1, 4.0))
	t.set_stylebox("pressed", "ChipButton", box(PRESSED, ACCENT, 4, 1, 4.0))
	t.set_font_size("font_size", "ChipButton", 12)
	# "PrimaryButton": the one action a panel is there for.
	t.set_type_variation("PrimaryButton", "Button")
	t.set_stylebox("normal", "PrimaryButton", box(Color(0.10, 0.37, 0.55, 1.0), ACCENT, 5, 1, 9.0))
	t.set_stylebox("hover", "PrimaryButton", box(Color(0.15, 0.48, 0.69, 1.0), Color.WHITE, 5, 1, 9.0))
	t.set_stylebox("pressed", "PrimaryButton", box(Color(0.08, 0.30, 0.45, 1.0), ACCENT, 5, 1, 9.0))
	t.set_color("font_color", "PrimaryButton", Color.WHITE)

	# Panels and popups.
	t.set_stylebox("panel", "PanelContainer", panel())
	t.set_stylebox("panel", "Panel", panel())
	t.set_stylebox("panel", "PopupMenu", box(PANEL_SOLID, LINE, 5, 1, 6.0, 6))
	t.set_stylebox("hover", "PopupMenu", box(RAISED_HOT, Color(0.0, 0.0, 0.0, 0.0), 3, 0, 4.0))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	t.set_color("font_disabled_color", "PopupMenu", FAINT)
	t.set_stylebox("panel", "TooltipPanel", box(PANEL_SOLID, ACCENT, 4, 1, 8.0, 4))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font_size("font_size", "TooltipLabel", 14)

	# Text.
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_shadow_color", "Label", Color(0.0, 0.0, 0.0, 0.0))

	# Entry fields.
	t.set_stylebox("normal", "LineEdit", box(SUNK, LINE_SOFT, 4, 1, 7.0))
	t.set_stylebox("focus", "LineEdit", box(SUNK, ACCENT, 4, 1, 7.0))
	t.set_stylebox("read_only", "LineEdit", box(SUNK, Color(0.2, 0.25, 0.3, 0.3), 4, 1, 7.0))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("caret_color", "LineEdit", ACCENT)
	t.set_color("selection_color", "LineEdit", Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.35))

	# Bars and sliders.
	t.set_stylebox("background", "ProgressBar", box(SUNK, LINE_SOFT, 3, 1, 0.0))
	t.set_stylebox("fill", "ProgressBar", box(ACCENT, Color(0.0, 0.0, 0.0, 0.0), 3, 0, 0.0))
	var groove: StyleBoxFlat = box(SUNK, LINE_SOFT, 3, 1, 0.0)
	groove.content_margin_top = 3.0
	groove.content_margin_bottom = 3.0
	t.set_stylebox("slider", "HSlider", groove)
	var filled: StyleBoxFlat = box(Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.75), Color(0.0, 0.0, 0.0, 0.0), 3, 0, 0.0)
	filled.content_margin_top = 3.0
	filled.content_margin_bottom = 3.0
	t.set_stylebox("grabber_area", "HSlider", filled)
	t.set_stylebox("grabber_area_highlight", "HSlider", filled)

	var line: StyleBoxLine = StyleBoxLine.new()
	line.color = LINE_SOFT
	line.thickness = 1
	t.set_stylebox("separator", "HSeparator", line)
	_theme = t
	return t
