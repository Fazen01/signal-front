class_name SettingsPanel
extends PanelContainer
## Volume sliders. Used from the main menu and the pause menu.

signal closed


func _ready() -> void:
	GameSettings.ensure_loaded()
	add_theme_stylebox_override("panel", Hud.panel_style())
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	box.add_child(Hud.make_label("SETTINGS", 28, Color(0.55, 0.85, 1.0)))
	for bus: String in GameSettings.BUSES:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var caption: String = "Master volume"
		if bus == "SFX":
			caption = "Effects"
		elif bus == "Ambient":
			caption = "Ambience"
		var label: Label = Hud.make_label(caption, 17, Hud.TEXT)
		label.custom_minimum_size = Vector2(150.0, 0.0)
		row.add_child(label)
		var slider: HSlider = HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = GameSettings.volumes[bus]
		slider.custom_minimum_size = Vector2(260.0, 24.0)
		slider.focus_mode = Control.FOCUS_NONE
		slider.value_changed.connect(_on_volume.bind(bus))
		row.add_child(slider)
		box.add_child(row)
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


func _on_volume(value: float, bus: String) -> void:
	GameSettings.set_volume(bus, value)
