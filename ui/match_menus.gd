class_name MatchMenus
extends Control
## The pause menu and the victory / defeat summary shown over a match.

const FIELD_CENTRE: float = 0.415  ## the middle of the view between the HUD's bars, as a share of the screen height
const FIELD_TOP: float = 56.0  ## where the battlefield begins under the top bar, in the layout's own height

var battle: BattleScene = null
var skin: UiSkin = null
var _pause: PanelContainer = null
var _result: PanelContainer = null
var _dim: ColorRect = null
var _settings: SettingsPanel = null
var _saves: PanelContainer = null  ## the save-slot chooser, while it is open
var _save_buttons: Array[Button] = []
var result_shown: bool = false


func setup(scene: BattleScene) -> void:
	# Set here as well as on the root window: themes do not pass down
	# through a CanvasLayer.
	skin = scene.skin if scene.skin != null else UiSkin.of("")
	theme = skin.theme()
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
	p.add_theme_stylebox_override("panel", skin.panel(18.0))
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_lift(p)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.visible = false
	add_child(p)
	return p


## Centres a panel in the battlefield, between the top bar and the bottom
## bar, instead of in the whole screen: a tall panel then stays clear of
## the HUD at the bottom.
func _lift(p: Control) -> void:
	p.anchor_top = FIELD_CENTRE
	p.anchor_bottom = FIELD_CENTRE


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
	var title: Label = skin.title("PAUSED", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	box.add_child(_button("Resume", func() -> void: battle.toggle_pause_menu()))
	box.add_child(_button("Save Game", func() -> void: open_saves(false)))
	box.add_child(_button("Save and Quit to Menu", func() -> void: open_saves(true)))
	box.add_child(_button("Settings", open_settings))
	if not battle.watching:
		box.add_child(_button("Surrender", func() -> void: battle.surrender()))
	box.add_child(_button("Quit to Main Menu", func() -> void: battle.quit_to_menu()))


## The panels built so far that are too big to sit between the HUD's bars,
## each with the size it needs (for the checks).
func panels_too_big() -> Array[String]:
	var width: float = float(ProjectSettings.get_setting("display/window/size/viewport_width", 1600))
	var height: float = float(ProjectSettings.get_setting("display/window/size/viewport_height", 900))
	# A panel is centred on the middle of the battlefield, so it may be as
	# tall as twice the distance from there up to the top bar.
	var room: float = 2.0 * (FIELD_CENTRE * height - FIELD_TOP)
	var out: Array[String] = []
	var panels: Dictionary[String, Control] = {"pause menu": _pause, "settings": _settings, "save slots": _saves, "result": _result}
	for id: String in panels:
		var panel: Control = panels[id]
		if panel == null:
			continue
		var need: Vector2 = panel.get_combined_minimum_size()
		if need.x > width or need.y > room:
			out.append("%s needs %d x %d of %d x %d" % [id, int(need.x), int(need.y), int(width), int(room)])
	return out


func is_pause_open() -> bool:
	return _pause.visible or (_settings != null and _settings.visible) or (_saves != null and _saves.visible)


## The save slots, reached from the pause menu: pick one to write the match
## to. With `then_quit` the match is left for the main menu afterwards.
func open_saves(then_quit: bool) -> void:
	if _saves != null:
		_saves.queue_free()
	_saves = _centre_panel()
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_saves.add_child(box)
	var title: Label = skin.title("SAVE AND QUIT" if then_quit else "SAVE GAME", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	box.add_child(Hud.make_label("Pick a slot. Saving over a slot replaces what is in it.", 15, skin.dim))
	_save_buttons.clear()
	for slot: String in SimSave.MANUAL_SLOTS:
		var b: Button = _button(slot_caption(slot), save_to.bind(slot, then_quit))
		b.custom_minimum_size = Vector2(560.0, 46.0)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		if slot == battle.save_slot:
			b.add_theme_color_override("font_color", skin.accent)
		box.add_child(b)
		_save_buttons.append(b)
	var auto: Dictionary = SimSave.slot_info(SimSave.AUTO)
	var note: String = "Autosave is off (Settings)."
	if GameSettings.autosave_minutes > 0:
		note = "The game also saves itself every %d minutes." % GameSettings.autosave_minutes
		if not auto.is_empty():
			note += " Latest: %s." % SimSave.describe(auto)
	box.add_child(Hud.make_label(note, 14, skin.dim))
	box.add_child(_button("Back", close_saves))
	_pause.visible = false
	_saves.visible = true


## "Slot 2: Twin Fords, 12:34 in, saved 17 Nov 00:58", or "Slot 2: empty".
static func slot_caption(slot: String) -> String:
	return "%s:  %s" % [str(SimSave.SLOT_NAMES.get(slot, slot)), SimSave.describe(SimSave.slot_info(slot))]


func save_to(slot: String, then_quit: bool) -> void:
	if then_quit:
		battle.save_and_quit(slot)
		return
	battle.save_game(slot)
	close_saves()


func close_saves() -> void:
	if _saves != null:
		_saves.queue_free()
		_saves = null
	_pause.visible = battle.paused


## Volume sliders, reached from the pause menu.
func open_settings() -> void:
	if _settings == null:
		_settings = SettingsPanel.new()
		_settings.skin = skin
		_settings.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		_lift(_settings)
		_settings.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_settings.grow_vertical = Control.GROW_DIRECTION_BOTH
		add_child(_settings)
		_settings.closed.connect(close_settings)
	_pause.visible = false
	_settings.visible = true


## Back from the settings to the pause menu, with the settings applied.
func close_settings() -> void:
	if _settings != null:
		_settings.visible = false
	_pause.visible = true
	battle.apply_settings()


func set_pause_open(open: bool) -> void:
	if result_shown:
		return
	_pause.visible = open
	_dim.visible = open
	if _settings != null and not open:
		_settings.visible = false
	if _saves != null and not open:
		_saves.queue_free()
		_saves = null


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
	var sub: Label = Hud.make_label(SimTutorial.TITLES.get(tutorial_id, ""), 18, skin.dim)
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
	var won: bool = world.has_won(local_player)
	var headline: String = "VICTORY" if won else "DEFEAT"
	if world.winner < 0:
		headline = "DRAW"
	var headline_color: Color = Color(0.5, 1.0, 0.6) if won else Color(1.0, 0.45, 0.4)
	if watching:
		# A spectator neither wins nor loses.
		headline = "MATCH OVER"
		headline_color = skin.second
	var title: Label = Hud.make_label(headline, 56, headline_color)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var secs: int = int(world.seconds())
	var sub: String = "Match length %d:%02d" % [secs / 60, secs % 60]
	if world.winner >= 0:
		var holders: Array[String] = []
		for wp: SimPlayer in world.winners():
			holders.append(wp.name)
		sub = "%s %s the field.   %s" % [" and ".join(holders), "holds" if holders.size() == 1 else "hold", sub]
	var subtitle: Label = Hud.make_label(sub, 16, skin.dim)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)
	# Now that it is over, say how each AI had been playing.
	var styles: Array[String] = []
	for ai: SimAI in world.ais:
		if ai.level > 0:
			styles.append("%s played as %s" % [world.players[ai.player_id].name, "an aggressor" if ai.doctrine == "aggressor" else "a " + ai.doctrine if ai.doctrine != "balanced" else "an all-rounder"])
	if not styles.is_empty():
		var manner: Label = Hud.make_label(".   ".join(styles) + ".", 14, skin.dim)
		manner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		manner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		manner.custom_minimum_size = Vector2(560.0, 0.0)
		box.add_child(manner)

	var grid: GridContainer = GridContainer.new()
	grid.columns = world.players.size() + 1
	grid.add_theme_constant_override("h_separation", 36)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	grid.add_child(Hud.make_label("", 16, skin.dim))
	for p: SimPlayer in world.players:
		grid.add_child(Hud.make_label(p.name, 18, p.color.lightened(0.3)))
	# With allies in the match, say who was on which side and how it ended.
	var allied: bool = false
	for a: SimPlayer in world.players:
		for b: SimPlayer in world.players:
			allied = allied or world.are_allies(a.id, b.id)
	if allied:
		var side_of: Dictionary[int, int] = {}
		grid.add_child(Hud.make_label("Side", 16, skin.dim))
		for p: SimPlayer in world.players:
			if not side_of.has(p.team):
				side_of[p.team] = side_of.size() + 1
			var word: String = "Team %d" % side_of[p.team]
			if world.winner >= 0:
				word += "  won" if world.has_won(p.id) else "  lost"
			var side: Label = Hud.make_label(word, 16, skin.text if world.has_won(p.id) else skin.dim)
			side.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			grid.add_child(side)
	var rows: Array[String] = ["Units built", "Units lost", "Buildings built", "Buildings lost", "Kills", "Value destroyed", "Salvage collected"]
	for r: int in rows.size():
		grid.add_child(Hud.make_label(rows[r], 16, skin.dim))
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
			var cell: Label = Hud.make_label(str(v), 16, skin.text)
			cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			grid.add_child(cell)

	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	buttons.add_child(_button("Play Again", func() -> void: battle.play_again()))
	buttons.add_child(_button("Main Menu", func() -> void: battle.quit_to_menu()))
	box.add_child(buttons)
