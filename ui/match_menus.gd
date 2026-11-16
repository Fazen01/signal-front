class_name MatchMenus
extends Control
## The pause menu and the victory / defeat summary shown over a match.

var battle: BattleScene = null
var _pause: PanelContainer = null
var _result: PanelContainer = null
var _dim: ColorRect = null
var _settings: SettingsPanel = null
var result_shown: bool = false


func setup(scene: BattleScene) -> void:
	# Set here as well as on the root window: themes do not pass down
	# through a CanvasLayer.
	theme = UiTheme.theme()
	battle = scene
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim = ColorRect.new()
	_dim.color = Color(0.0, 0.0, 0.0, 0.55)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.visible = false
	add_child(_dim)
	_build_pause()


func _centre_panel() -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.add_theme_stylebox_override("panel", Hud.panel_style())
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.visible = false
	add_child(p)
	return p


func _button(text: String, action: Callable) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(280.0, 46.0)
	b.add_theme_font_size_override("font_size", 18)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(action)
	return b


func _build_pause() -> void:
	_pause = _centre_panel()
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_pause.add_child(box)
	var title: Label = UiTheme.title("PAUSED", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	box.add_child(_button("Resume", func() -> void: battle.toggle_pause_menu()))
	box.add_child(_button("Save Game", func() -> void: battle.save_game()))
	box.add_child(_button("Save and Quit to Menu", func() -> void: battle.save_and_quit()))
	box.add_child(_button("Settings", open_settings))
	if not battle.watching:
		box.add_child(_button("Surrender", func() -> void: battle.surrender()))
	box.add_child(_button("Quit to Main Menu", func() -> void: battle.quit_to_menu()))


func is_pause_open() -> bool:
	return _pause.visible or (_settings != null and _settings.visible)


## Volume sliders, reached from the pause menu.
func open_settings() -> void:
	if _settings == null:
		_settings = SettingsPanel.new()
		_settings.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		_settings.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_settings.grow_vertical = Control.GROW_DIRECTION_BOTH
		add_child(_settings)
		_settings.closed.connect(func() -> void:
			_settings.visible = false
			_pause.visible = true
			battle.apply_settings()
		)
	_pause.visible = false
	_settings.visible = true


func set_pause_open(open: bool) -> void:
	if result_shown:
		return
	_pause.visible = open
	_dim.visible = open
	if _settings != null and not open:
		_settings.visible = false


## The end of a tutorial mission: on to the next one, or back to the menu.
func show_tutorial_complete(tutorial_id: String) -> void:
	if result_shown:
		return
	result_shown = true
	_pause.visible = false
	_dim.visible = true
	_result = _centre_panel()
	_result.visible = true
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_result.add_child(box)
	var title: Label = Hud.make_label("MISSION COMPLETE", 44, Color(0.5, 1.0, 0.6))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub: Label = Hud.make_label(SimTutorial.TITLES.get(tutorial_id, ""), 18, Hud.DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	var next: int = SimTutorial.IDS.find(tutorial_id) + 1
	if next > 0 and next < SimTutorial.IDS.size():
		var next_id: String = SimTutorial.IDS[next]
		buttons.add_child(_button("Next Mission", func() -> void: battle.start_tutorial(next_id)))
	else:
		buttons.add_child(_button("Play a Skirmish", func() -> void: battle.quit_to_menu()))
	buttons.add_child(_button("Main Menu", func() -> void: battle.quit_to_menu()))
	box.add_child(buttons)


## Shows the end-of-match summary for the local player.
func show_result(world: SimWorld, local_player: int, watching: bool = false) -> void:
	if result_shown:
		return
	result_shown = true
	_pause.visible = false
	_dim.visible = true
	_result = _centre_panel()
	_result.visible = true
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_result.add_child(box)
	var won: bool = world.winner == local_player
	var headline: String = "VICTORY" if won else "DEFEAT"
	if world.winner < 0:
		headline = "DRAW"
	var headline_color: Color = Color(0.5, 1.0, 0.6) if won else Color(1.0, 0.45, 0.4)
	if watching:
		# A spectator neither wins nor loses.
		headline = "MATCH OVER"
		headline_color = UiTheme.GOLD
	var title: Label = Hud.make_label(headline, 56, headline_color)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var secs: int = int(world.seconds())
	var sub: String = "Match length %d:%02d" % [secs / 60, secs % 60]
	if world.winner >= 0:
		sub = "%s holds the field.   %s" % [world.players[world.winner].name, sub]
	var subtitle: Label = Hud.make_label(sub, 16, Hud.DIM)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)

	var grid: GridContainer = GridContainer.new()
	grid.columns = world.players.size() + 1
	grid.add_theme_constant_override("h_separation", 36)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	grid.add_child(Hud.make_label("", 16, Hud.DIM))
	for p: SimPlayer in world.players:
		grid.add_child(Hud.make_label(p.name, 18, p.color.lightened(0.3)))
	var rows: Array[String] = ["Units built", "Units lost", "Buildings built", "Buildings lost", "Kills", "Value destroyed", "Salvage collected"]
	for r: int in rows.size():
		grid.add_child(Hud.make_label(rows[r], 16, Hud.DIM))
		for p: SimPlayer in world.players:
			var v: int = 0
			match r:
				0:
					v = p.stat_units_built
				1:
					v = p.stat_units_lost
				2:
					v = p.stat_buildings_built
				3:
					v = p.stat_buildings_lost
				4:
					v = p.stat_kills
				5:
					v = p.stat_value_destroyed
				_:
					v = p.stat_salvage_collected
			var cell: Label = Hud.make_label(str(v), 16, Hud.TEXT)
			cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			grid.add_child(cell)

	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	buttons.add_child(_button("Play Again", func() -> void: battle.play_again()))
	buttons.add_child(_button("Main Menu", func() -> void: battle.quit_to_menu()))
	box.add_child(buttons)
