class_name UiSkin
extends RefCounted
## The interface of one faction: its colours, the shape of its panels and
## buttons, its lettering and its emblem. The HUD, the in-match menus and
## the skirmish setup ask for the skin of a faction and build themselves
## from it, so playing the Foundry Pact looks and reads differently from
## playing the Vesper Array. `UiSkin.of("")` is the neutral look of the
## main menu.

var id: String = ""
var plate: String = "SIGNAL FRONT"  ## the name shown on the HUD's faction plate
var emblem: String = "emblem_signal"  ## a HudIcon kind
var accent: Color = Color(0.42, 0.82, 1.0)  ## titles, hot borders, the signal
var second: Color = Color(1.0, 0.82, 0.35)  ## salvage, costs, Directives
var text: Color = Color(0.88, 0.92, 0.95)
var dim: Color = Color(0.60, 0.67, 0.72)
var faint: Color = Color(0.38, 0.44, 0.50)
var panel_fill: Color = Color(0.045, 0.065, 0.09, 0.90)
var strip_fill: Color = Color(0.03, 0.045, 0.065, 0.86)
var section_fill: Color = Color(0.06, 0.085, 0.115, 0.9)
var raised: Color = Color(0.125, 0.18, 0.24, 0.97)
var raised_hot: Color = Color(0.17, 0.28, 0.38, 0.98)
var pressed: Color = Color(0.13, 0.36, 0.52, 1.0)
var primary: Color = Color(0.10, 0.37, 0.55, 1.0)
var sunk: Color = Color(0.025, 0.035, 0.05, 0.95)
var line: Color = Color(0.24, 0.42, 0.58, 0.75)
var line_soft: Color = Color(0.27, 0.45, 0.60, 0.45)
# Shape.
var corners: Array[int] = [5, 5, 5, 5]  ## top-left, top-right, bottom-right, bottom-left
var chamfer: bool = false  ## cut the corners straight instead of rounding them
var edges: Array[int] = [1, 1, 1, 1]  ## border width: left, top, right, bottom
var skew: float = 0.0  ## slant of buttons (0.2 leans them like flight strips)
var panel_edge: Array[int] = [1, 2, 1, 1]  ## border widths of panels
# Lettering.
var letter_spacing: int = 3
var embolden: float = 0.9
var caps_titles: bool = true

var _theme: Theme = null
var _heading: FontVariation = null

static var _skins: Dictionary[String, UiSkin] = {}


static func of(faction_id: String) -> UiSkin:
	if _skins.has(faction_id):
		return _skins[faction_id]
	var k: UiSkin = UiSkin.new()
	k.id = faction_id
	match faction_id:
		"aegis":
			# Cool glass and thin lines: an instrument panel.
			k.plate = "AEGIS DIRECTORATE"
			k.emblem = "emblem_aegis"
		"foundry":
			# Riveted iron plate lit by the furnace: square, heavy, warm.
			k.plate = "FOUNDRY PACT"
			k.emblem = "emblem_foundry"
			k.accent = Color(1.0, 0.56, 0.20)
			k.second = Color(0.93, 0.74, 0.38)
			k.text = Color(0.93, 0.89, 0.83)
			k.dim = Color(0.68, 0.62, 0.55)
			k.faint = Color(0.44, 0.40, 0.36)
			k.panel_fill = Color(0.085, 0.075, 0.07, 0.94)
			k.strip_fill = Color(0.065, 0.058, 0.055, 0.92)
			k.section_fill = Color(0.11, 0.098, 0.09, 0.94)
			k.raised = Color(0.20, 0.175, 0.16, 0.98)
			k.raised_hot = Color(0.33, 0.24, 0.17, 0.98)
			k.pressed = Color(0.56, 0.28, 0.10, 1.0)
			k.primary = Color(0.55, 0.27, 0.08, 1.0)
			k.sunk = Color(0.04, 0.035, 0.032, 0.96)
			k.line = Color(0.52, 0.40, 0.28, 0.85)
			k.line_soft = Color(0.42, 0.34, 0.27, 0.6)
			k.corners = [0, 0, 0, 0]
			k.edges = [1, 1, 1, 3]
			k.panel_edge = [2, 2, 2, 4]
			k.letter_spacing = 1
			k.embolden = 1.3
		"nomad":
			# Canvas and painted signs: warm sand, teal, one corner folded.
			k.plate = "NOMAD CIRCUIT"
			k.emblem = "emblem_nomad"
			k.accent = Color(0.30, 0.86, 0.80)
			k.second = Color(0.97, 0.80, 0.45)
			k.text = Color(0.95, 0.91, 0.82)
			k.dim = Color(0.74, 0.68, 0.56)
			k.faint = Color(0.50, 0.45, 0.37)
			k.panel_fill = Color(0.115, 0.095, 0.065, 0.92)
			k.strip_fill = Color(0.09, 0.075, 0.05, 0.9)
			k.section_fill = Color(0.15, 0.125, 0.085, 0.92)
			k.raised = Color(0.25, 0.20, 0.13, 0.97)
			k.raised_hot = Color(0.20, 0.33, 0.32, 0.98)
			k.pressed = Color(0.12, 0.45, 0.43, 1.0)
			k.primary = Color(0.10, 0.42, 0.40, 1.0)
			k.sunk = Color(0.055, 0.045, 0.03, 0.95)
			k.line = Color(0.62, 0.52, 0.34, 0.8)
			k.line_soft = Color(0.55, 0.46, 0.30, 0.5)
			k.corners = [2, 12, 2, 12]
			k.edges = [3, 1, 1, 1]
			k.panel_edge = [4, 1, 1, 1]
			k.letter_spacing = 2
			k.embolden = 0.7
		"vesper":
			# Light on dark: pills and thin glowing rings.
			k.plate = "VESPER ARRAY"
			k.emblem = "emblem_vesper"
			k.accent = Color(0.76, 0.62, 1.0)
			k.second = Color(0.95, 0.86, 1.0)
			k.text = Color(0.92, 0.91, 0.97)
			k.dim = Color(0.66, 0.64, 0.76)
			k.faint = Color(0.42, 0.41, 0.52)
			k.panel_fill = Color(0.06, 0.055, 0.095, 0.90)
			k.strip_fill = Color(0.045, 0.04, 0.075, 0.88)
			k.section_fill = Color(0.08, 0.075, 0.125, 0.9)
			k.raised = Color(0.15, 0.14, 0.23, 0.97)
			k.raised_hot = Color(0.25, 0.21, 0.40, 0.98)
			k.pressed = Color(0.40, 0.30, 0.68, 1.0)
			k.primary = Color(0.36, 0.27, 0.62, 1.0)
			k.sunk = Color(0.03, 0.028, 0.055, 0.95)
			k.line = Color(0.50, 0.42, 0.74, 0.8)
			k.line_soft = Color(0.46, 0.40, 0.66, 0.45)
			k.corners = [14, 14, 14, 14]
			k.panel_edge = [1, 1, 1, 1]
			k.letter_spacing = 5
			k.embolden = 0.3
		"verdigris":
			# Stone and old copper: eight-sided plates with a bronze edge.
			k.plate = "VERDIGRIS ORDER"
			k.emblem = "emblem_verdigris"
			k.accent = Color(0.42, 0.86, 0.74)
			k.second = Color(0.90, 0.68, 0.36)
			k.text = Color(0.90, 0.92, 0.88)
			k.dim = Color(0.64, 0.68, 0.62)
			k.faint = Color(0.42, 0.45, 0.41)
			k.panel_fill = Color(0.07, 0.085, 0.08, 0.93)
			k.strip_fill = Color(0.055, 0.068, 0.064, 0.9)
			k.section_fill = Color(0.09, 0.11, 0.105, 0.93)
			k.raised = Color(0.15, 0.20, 0.19, 0.98)
			k.raised_hot = Color(0.18, 0.31, 0.28, 0.98)
			k.pressed = Color(0.16, 0.45, 0.39, 1.0)
			k.primary = Color(0.14, 0.40, 0.35, 1.0)
			k.sunk = Color(0.035, 0.043, 0.04, 0.96)
			k.line = Color(0.62, 0.47, 0.26, 0.85)
			k.line_soft = Color(0.52, 0.41, 0.25, 0.55)
			k.corners = [9, 9, 9, 9]
			k.chamfer = true
			k.edges = [2, 2, 2, 2]
			k.panel_edge = [2, 2, 2, 2]
			k.letter_spacing = 4
			k.embolden = 1.0
		"zephyr":
			# A flight deck: pale panels, slanted strips, safety orange.
			k.plate = "ZEPHYR ACCORD"
			k.emblem = "emblem_zephyr"
			k.accent = Color(1.0, 0.60, 0.22)
			k.second = Color(1.0, 0.88, 0.55)
			k.text = Color(0.95, 0.96, 0.98)
			k.dim = Color(0.72, 0.76, 0.82)
			k.faint = Color(0.48, 0.52, 0.58)
			k.panel_fill = Color(0.13, 0.155, 0.19, 0.92)
			k.strip_fill = Color(0.11, 0.13, 0.165, 0.9)
			k.section_fill = Color(0.165, 0.195, 0.235, 0.92)
			k.raised = Color(0.26, 0.30, 0.36, 0.98)
			k.raised_hot = Color(0.40, 0.36, 0.30, 0.98)
			k.pressed = Color(0.72, 0.40, 0.12, 1.0)
			k.primary = Color(0.70, 0.38, 0.10, 1.0)
			k.sunk = Color(0.07, 0.085, 0.105, 0.95)
			k.line = Color(0.60, 0.66, 0.74, 0.8)
			k.line_soft = Color(0.52, 0.58, 0.66, 0.5)
			k.corners = [3, 3, 3, 3]
			k.skew = 0.16
			k.edges = [1, 3, 1, 1]
			k.panel_edge = [1, 4, 1, 1]
			k.letter_spacing = 4
			k.embolden = 0.6
		"tally":
			# A ledger: black pages ruled in gold, oxblood where it is pressed.
			k.plate = "CRIMSON TALLY"
			k.emblem = "emblem_tally"
			k.accent = Color(0.96, 0.76, 0.32)
			k.second = Color(1.0, 0.86, 0.50)
			k.text = Color(0.94, 0.91, 0.86)
			k.dim = Color(0.70, 0.65, 0.58)
			k.faint = Color(0.46, 0.42, 0.38)
			k.panel_fill = Color(0.055, 0.05, 0.052, 0.95)
			k.strip_fill = Color(0.04, 0.036, 0.038, 0.93)
			k.section_fill = Color(0.075, 0.068, 0.07, 0.95)
			k.raised = Color(0.15, 0.13, 0.135, 0.98)
			k.raised_hot = Color(0.34, 0.11, 0.12, 0.98)
			k.pressed = Color(0.52, 0.12, 0.13, 1.0)
			k.primary = Color(0.46, 0.10, 0.11, 1.0)
			k.sunk = Color(0.025, 0.022, 0.023, 0.96)
			k.line = Color(0.78, 0.60, 0.24, 0.85)
			k.line_soft = Color(0.62, 0.48, 0.22, 0.5)
			k.corners = [0, 0, 0, 0]
			k.edges = [0, 2, 0, 2]
			k.panel_edge = [0, 3, 0, 3]
			k.letter_spacing = 6
			k.embolden = 1.1
		"veil":
			# Dusk: thin lines of ghost-light and corners cut on the slant.
			k.plate = "UMBRAL VEIL"
			k.emblem = "emblem_veil"
			k.accent = Color(0.62, 1.0, 0.84)
			k.second = Color(0.82, 0.96, 1.0)
			k.text = Color(0.86, 0.92, 0.92)
			k.dim = Color(0.56, 0.66, 0.68)
			k.faint = Color(0.36, 0.44, 0.46)
			k.panel_fill = Color(0.045, 0.05, 0.075, 0.88)
			k.strip_fill = Color(0.035, 0.038, 0.06, 0.86)
			k.section_fill = Color(0.06, 0.066, 0.10, 0.88)
			k.raised = Color(0.105, 0.12, 0.17, 0.96)
			k.raised_hot = Color(0.13, 0.24, 0.24, 0.98)
			k.pressed = Color(0.14, 0.42, 0.36, 1.0)
			k.primary = Color(0.12, 0.38, 0.33, 1.0)
			k.sunk = Color(0.022, 0.025, 0.04, 0.95)
			k.line = Color(0.38, 0.72, 0.62, 0.7)
			k.line_soft = Color(0.34, 0.60, 0.54, 0.4)
			k.corners = [0, 12, 0, 12]
			k.chamfer = true
			k.panel_edge = [1, 1, 1, 1]
			k.letter_spacing = 7
			k.embolden = 0.2
		"ember":
			# A kiln mouth: soot above, a glowing sill below, round at the foot.
			k.plate = "EMBER RITE"
			k.emblem = "emblem_ember"
			k.accent = Color(1.0, 0.36, 0.22)
			k.second = Color(1.0, 0.88, 0.46)
			k.text = Color(0.95, 0.91, 0.87)
			k.dim = Color(0.72, 0.64, 0.58)
			k.faint = Color(0.48, 0.41, 0.37)
			k.panel_fill = Color(0.075, 0.052, 0.048, 0.93)
			k.strip_fill = Color(0.055, 0.038, 0.035, 0.90)
			k.section_fill = Color(0.10, 0.07, 0.062, 0.93)
			k.raised = Color(0.19, 0.125, 0.11, 0.98)
			k.raised_hot = Color(0.36, 0.17, 0.11, 0.98)
			k.pressed = Color(0.62, 0.22, 0.10, 1.0)
			k.primary = Color(0.56, 0.17, 0.09, 1.0)
			k.sunk = Color(0.035, 0.024, 0.022, 0.96)
			k.line = Color(0.86, 0.33, 0.18, 0.8)
			k.line_soft = Color(0.66, 0.30, 0.18, 0.45)
			k.corners = [0, 0, 11, 11]
			k.edges = [1, 1, 1, 3]
			k.panel_edge = [1, 1, 1, 4]
			k.letter_spacing = 4
			k.embolden = 1.0
		_:
			pass
	_skins[faction_id] = k
	return k


## Gives a box this skin's corners, edges and slant.
func shape(sb: StyleBoxFlat, slanted: bool = false, widths: Array[int] = []) -> StyleBoxFlat:
	sb.corner_radius_top_left = corners[0]
	sb.corner_radius_top_right = corners[1]
	sb.corner_radius_bottom_right = corners[2]
	sb.corner_radius_bottom_left = corners[3]
	sb.corner_detail = 1 if chamfer else 8
	var w: Array[int] = widths if not widths.is_empty() else edges
	sb.border_width_left = w[0]
	sb.border_width_top = w[1]
	sb.border_width_right = w[2]
	sb.border_width_bottom = w[3]
	if slanted and skew != 0.0:
		sb.skew = Vector2(skew, 0.0)
		sb.content_margin_left += 6.0
		sb.content_margin_right += 6.0
	sb.anti_aliasing = true
	return sb


func box(fill: Color, border: Color, margin: float = 8.0, slanted: bool = false) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_content_margin_all(margin)
	return shape(sb, slanted)


## A floating panel: this skin's fill and edge, with a soft shadow.
func panel(margin: float = 10.0, edge: Color = Color(0.0, 0.0, 0.0, 0.0)) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = panel_fill
	sb.border_color = edge if edge.a > 0.0 else line
	sb.set_content_margin_all(margin)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	sb.shadow_size = 6
	return shape(sb, false, panel_edge)


## A bar across the top or bottom edge of the screen.
func strip(top_edge: bool) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = strip_fill
	sb.border_color = line
	sb.set_content_margin_all(7.0)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 12.0
	var thick: int = maxi(1, panel_edge[1])
	if top_edge:
		sb.border_width_top = thick
	else:
		sb.border_width_bottom = thick
	return sb


## A framed section inside a bar.
func section() -> StyleBoxFlat:
	return box(section_fill, line_soft, 10.0)


## The sunk frame round the minimap.
func frame() -> StyleBoxFlat:
	return box(sunk, line, 4.0)


func heading_font() -> FontVariation:
	if _heading == null:
		_heading = FontVariation.new()
		_heading.base_font = ThemeDB.fallback_font
		_heading.variation_embolden = embolden
		_heading.spacing_glyph = letter_spacing
	return _heading


func title(text_value: String, font_px: int = 26) -> Label:
	var l: Label = UiTheme.label(text_value, font_px, accent)
	l.add_theme_font_override("font", heading_font())
	return l


func caption(text_value: String, color: Color = Color(0.0, 0.0, 0.0, 0.0)) -> Label:
	var l: Label = UiTheme.label(text_value, 11, color if color.a > 0.0 else dim)
	l.add_theme_font_override("font", heading_font())
	return l


## The whole theme of this skin: every button, panel, field and bar.
func theme() -> Theme:
	if _theme != null:
		return _theme
	var t: Theme = Theme.new()
	t.default_font_size = 15
	var clear: Color = Color(0.0, 0.0, 0.0, 0.0)
	var off_fill: Color = Color(sunk.r * 1.6, sunk.g * 1.6, sunk.b * 1.6, 0.92)
	for kind: String in ["Button", "OptionButton", "MenuButton"]:
		var slant: bool = kind == "Button"
		t.set_stylebox("normal", kind, box(raised, line_soft, 9.0, slant))
		t.set_stylebox("hover", kind, box(raised_hot, accent, 9.0, slant))
		t.set_stylebox("pressed", kind, box(pressed, accent, 9.0, slant))
		t.set_stylebox("disabled", kind, box(off_fill, Color(line_soft.r, line_soft.g, line_soft.b, 0.3), 9.0, slant))
		t.set_stylebox("focus", kind, box(clear, Color(accent.r, accent.g, accent.b, 0.6), 9.0, slant))
		t.set_color("font_color", kind, text)
		t.set_color("font_hover_color", kind, Color.WHITE)
		t.set_color("font_pressed_color", kind, Color.WHITE)
		t.set_color("font_focus_color", kind, Color.WHITE)
		t.set_color("font_hover_pressed_color", kind, Color.WHITE)
		t.set_color("font_disabled_color", kind, faint)
	for kind: String in ["CheckBox", "CheckButton"]:
		t.set_color("font_color", kind, text)
		t.set_color("font_hover_color", kind, Color.WHITE)
		t.set_color("font_pressed_color", kind, text)
		for state: String in ["normal", "pressed", "hover", "hover_pressed", "disabled", "focus"]:
			t.set_stylebox(state, kind, UiTheme.box(clear, clear, 4, 0, 5.0))
	t.set_type_variation("ChipButton", "Button")
	t.set_stylebox("normal", "ChipButton", box(raised, line_soft, 4.0))
	t.set_stylebox("hover", "ChipButton", box(raised_hot, accent, 4.0))
	t.set_stylebox("pressed", "ChipButton", box(pressed, accent, 4.0))
	t.set_font_size("font_size", "ChipButton", 12)
	t.set_type_variation("PrimaryButton", "Button")
	t.set_stylebox("normal", "PrimaryButton", box(primary, accent, 9.0, true))
	t.set_stylebox("hover", "PrimaryButton", box(primary.lightened(0.18), Color.WHITE, 9.0, true))
	t.set_stylebox("pressed", "PrimaryButton", box(primary.darkened(0.2), accent, 9.0, true))
	t.set_color("font_color", "PrimaryButton", Color.WHITE)
	t.set_stylebox("panel", "PanelContainer", panel())
	t.set_stylebox("panel", "Panel", panel())
	var popup: StyleBoxFlat = panel(6.0)
	popup.bg_color = Color(panel_fill.r, panel_fill.g, panel_fill.b, 0.98)
	t.set_stylebox("panel", "PopupMenu", popup)
	t.set_stylebox("hover", "PopupMenu", UiTheme.box(raised_hot, clear, 3, 0, 4.0))
	t.set_color("font_color", "PopupMenu", text)
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	t.set_color("font_disabled_color", "PopupMenu", faint)
	var tip: StyleBoxFlat = box(Color(panel_fill.r, panel_fill.g, panel_fill.b, 0.98), accent, 8.0)
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", text)
	t.set_font_size("font_size", "TooltipLabel", 14)
	t.set_color("font_color", "Label", text)
	t.set_stylebox("normal", "LineEdit", box(sunk, line_soft, 7.0))
	t.set_stylebox("focus", "LineEdit", box(sunk, accent, 7.0))
	t.set_stylebox("read_only", "LineEdit", box(sunk, Color(line_soft.r, line_soft.g, line_soft.b, 0.3), 7.0))
	t.set_color("font_color", "LineEdit", text)
	t.set_color("caret_color", "LineEdit", accent)
	t.set_color("selection_color", "LineEdit", Color(accent.r, accent.g, accent.b, 0.35))
	t.set_stylebox("background", "ProgressBar", UiTheme.box(sunk, line_soft, mini(3, corners[0]), 1, 0.0))
	t.set_stylebox("fill", "ProgressBar", UiTheme.box(accent, clear, mini(3, corners[0]), 0, 0.0))
	var groove: StyleBoxFlat = UiTheme.box(sunk, line_soft, 3, 1, 0.0)
	groove.content_margin_top = 3.0
	groove.content_margin_bottom = 3.0
	t.set_stylebox("slider", "HSlider", groove)
	var filled: StyleBoxFlat = UiTheme.box(Color(accent.r, accent.g, accent.b, 0.75), clear, 3, 0, 0.0)
	filled.content_margin_top = 3.0
	filled.content_margin_bottom = 3.0
	t.set_stylebox("grabber_area", "HSlider", filled)
	t.set_stylebox("grabber_area_highlight", "HSlider", filled)
	var sep: StyleBoxLine = StyleBoxLine.new()
	sep.color = line_soft
	sep.thickness = 1
	t.set_stylebox("separator", "HSeparator", sep)
	_theme = t
	return t
