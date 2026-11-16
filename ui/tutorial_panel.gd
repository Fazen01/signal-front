class_name TutorialPanel
extends PanelContainer
## Shows the current tutorial objective at the top of the screen.

var world: SimWorld = null
var _title: Label = null
var _progress: Label = null
var _text: Label = null
var _hint: Label = null
var _shown_index: int = -1
var _refresh_in: float = 0.0


func setup(sim_world: SimWorld, skin: UiSkin = null) -> void:
	if skin == null:
		skin = UiSkin.of("")
	# Set here as well as on the root window: themes do not pass down
	# through a CanvasLayer.
	theme = skin.theme()
	world = sim_world
	add_theme_stylebox_override("panel", skin.panel(10.0, Color(skin.second.r, skin.second.g, skin.second.b, 0.8)))
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	offset_top = 48.0
	custom_minimum_size = Vector2(620.0, 0.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var head: HBoxContainer = HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(head)
	_title = Hud.make_label(SimTutorial.TITLES.get(world.tutorial.id, "Tutorial"), 16, skin.second)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	_progress = Hud.make_label("", 14, skin.dim)
	head.add_child(_progress)
	_text = Hud.make_label("", 17, skin.text)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(600.0, 0.0)
	box.add_child(_text)
	_hint = Hud.make_label("", 14, skin.accent)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size = Vector2(600.0, 0.0)
	box.add_child(_hint)
	_refresh()


func _process(delta: float) -> void:
	_refresh_in -= delta
	if _refresh_in <= 0.0:
		_refresh_in = 0.2
		_refresh()


func _refresh() -> void:
	var t: SimTutorial = world.tutorial
	var index: int = t.steps.size() if t.done else t.index
	if index == _shown_index:
		return
	_shown_index = index
	var step: SimTutorial.Step = t.current()
	if step == null:
		_progress.text = "Complete"
		_text.text = "Mission complete."
		_hint.text = ""
		return
	_progress.text = "Objective %d of %d" % [t.index + 1, t.steps.size()]
	_text.text = step.text
	_hint.text = step.hint
