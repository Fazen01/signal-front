class_name SettingsPanel
extends PanelContainer
## Audio, video and interface settings. Used from the main and pause menus.

signal closed


func _ready() -> void:
	GameSettings.ensure_loaded()
	add_theme_stylebox_override("panel", Hud.panel_style())
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	box.add_child(Hud.make_label("SETTINGS", 28, Color(0.55, 0.85, 1.0)))

	box.add_child(Hud.make_label("Audio", 16, Hud.GOLD))
	for bus: String in GameSettings.BUSES:
		var caption: String = "Master volume"
		if bus == "SFX":
			caption = "Effects"
		elif bus == "Ambient":
			caption = "Ambience"
		var slider: HSlider = HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = GameSettings.volumes[bus]
		slider.custom_minimum_size = Vector2(260.0, 24.0)
		slider.focus_mode = Control.FOCUS_NONE
		slider.value_changed.connect(_on_volume.bind(bus))
		_row(box, caption, slider)

	box.add_child(Hud.make_label("Video", 16, Hud.GOLD))
	_toggle(box, "Fullscreen", GameSettings.fullscreen, func(on: bool) -> void:
		GameSettings.fullscreen = on
		GameSettings.apply_video()
	)
	_toggle(box, "Vertical sync", GameSettings.vsync, func(on: bool) -> void:
		GameSettings.vsync = on
		GameSettings.apply_video()
	)
	_toggle(box, "Shadows", GameSettings.shadows, func(on: bool) -> void: GameSettings.shadows = on)
	var aa: OptionButton = OptionButton.new()
	for n: String in GameSettings.MSAA_NAMES:
		aa.add_item(n)
	aa.select(GameSettings.msaa)
	aa.focus_mode = Control.FOCUS_NONE
	aa.item_selected.connect(func(index: int) -> void:
		GameSettings.msaa = index
		GameSettings.apply_video()
	)
	_row(box, "Anti-aliasing", aa)

	box.add_child(Hud.make_label("Interface", 16, Hud.GOLD))
	_toggle(box, "Show hotkey hints", GameSettings.key_hints, func(on: bool) -> void: GameSettings.key_hints = on)

	var done: Button = Button.new()
	done.text = "Done"
	done.custom_minimum_size = Vector2(120.0, 42.0)
	done.size_flags_horizontal = Control.SIZE_SHRINK_END
	done.focus_mode = Control.FOCUS_NONE
	done.pressed.connect(func() -> void:
		GameSettings.save()
		closed.emit()
	)
	box.add_child(done)


func _row(box: VBoxContainer, caption: String, control: Control) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var label: Label = Hud.make_label(caption, 17, Hud.TEXT)
	label.custom_minimum_size = Vector2(170.0, 0.0)
	row.add_child(label)
	row.add_child(control)
	box.add_child(row)


func _toggle(box: VBoxContainer, caption: String, value: bool, on_change: Callable) -> void:
	var check: CheckButton = CheckButton.new()
	check.button_pressed = value
	check.focus_mode = Control.FOCUS_NONE
	check.toggled.connect(on_change)
	_row(box, caption, check)


func _on_volume(value: float, bus: String) -> void:
	GameSettings.set_volume(bus, value)
