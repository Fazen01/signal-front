class_name MainMenu
extends Control
## Title screen, skirmish setup and the controls reference.

const LEVEL_NAMES: Array[String] = ["Easy", "Normal", "Hard"]
const HELP_TEXT: String = """SIGNAL FRONT - HOW TO PLAY

Your army runs on signal. The Headquarters and every Relay linked back to it
project coverage. Inside it your units are LINKED: full rate of fire, full
sight and (for the Aegis Directorate) extra weapon range. Outside it they are
DARK: they fire and see about a third worse, and Dark buildings stop working.
Cut an enemy relay and everything chained behind it goes Dark.

GETTING STARTED
  1. Your Haulers collect salvage on their own. Train more at the HQ.
  2. Select a Field Engineer and build a Barracks, then Relays towards more
     salvage. Relays also raise your Bandwidth (the unit cap).
  3. Build a Vehicle Works for tanks, then destroy the enemy Headquarters.
  4. Right-click an Uplink Site with a Field Engineer to capture it: it pays
     salvage while it is inside your coverage.
  5. Kills earn Command Points. Spend them on the Directive bar to unlock
     commander powers (Recon Sweep, Shell Barrage, Field Repair, Signal Surge,
     Blackout, Reinforcement Drop), then use them when they are ready.
You only see what your coverage and your units see.

CAMERA
  W / D / arrow keys / screen edge   pan  (A and S also pan with nothing selected)
  Mouse wheel                        zoom
  Q / E or middle-drag               rotate

SELECTION AND ORDERS
  Left click / drag                  select  (Shift adds, double-click selects a type)
  Right click                        move, attack, harvest, repair or set a rally point
  A then left click                  attack-move
  S / H                              stop / hold position
  Ctrl+1..9, then 1..9               set and recall control groups (double-tap centres)
  Shift + order                      queue the order
  G                                  toggle the signal coverage overlay
  . (period) or F1                   select the next idle Field Engineer
  Ctrl+F5..F8, then F5..F8           save and recall camera bookmarks
  Minimap                            left click moves the camera, right click orders
  Alt+1..6 or the Directive bar      unlock / use a Directive
  Esc                                cancel, or open the pause menu

The command card at the bottom right shows what the selection can build or
train; the letter in brackets is its hotkey."""

const MENU_LEFT: float = 96.0  ## left edge of the main menu column

var _main_box: VBoxContainer = null
var _setup: PanelContainer = null
var _help: PanelContainer = null
var _settings: SettingsPanel = null
var _tutorials: PanelContainer = null
var _seed: SpinBox = null
var _faction: OptionButton = null
var _level: OptionButton = null
var _enemy_faction: OptionButton = null
const COMPACT_MAP: String = "@compact"  ## map list entry for the small generated map

var _map: OptionButton = null
var _map_ids: Array[String] = []  ## "" = generated
var _map_players: Array[int] = []
var _map_blurb: Label = null
var _opponents: OptionButton = null
var _region: OptionButton = null
var _faction_blurb: Label = null
var _faction_ids: Array[String] = []
var _time: float = 0.0
var _backdrop: MenuBackdrop = null
var _shade: GradientTexture2D = null  ## dark on the left, clear on the right
var _live: Label = null  ## says which match is playing in the background


func _ready() -> void:
	theme = UiTheme.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# A match between two AIs plays out behind the menu.
	_backdrop = MenuBackdrop.new()
	_backdrop.name = "Backdrop"
	add_child(_backdrop)
	var fade: Gradient = Gradient.new()
	fade.set_color(0, Color(0.02, 0.03, 0.045, 0.95))
	fade.set_color(1, Color(0.02, 0.03, 0.045, 0.0))
	fade.add_point(0.55, Color(0.02, 0.03, 0.045, 0.78))
	_shade = GradientTexture2D.new()
	_shade.gradient = fade
	_shade.width = 256
	_shade.height = 4
	_build_main()
	_build_setup()
	_build_help()
	_build_tutorials()
	GameSettings.ensure_loaded()
	_settings = SettingsPanel.new()
	_settings.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_settings.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_settings.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_settings)
	_settings.closed.connect(func() -> void: _show(_main_box))
	_show(_main_box)
	print("Main menu ready")


func _process(delta: float) -> void:
	_time += delta
	if _live != null and _backdrop != null and _live.text != _backdrop.caption:
		_live.text = _backdrop.caption
	queue_redraw()


## Background: the live match, darkened on the left where the menu sits (or
## all over while a panel is open), with slow signal rings behind the title.
func _draw() -> void:
	var rect: Rect2 = get_viewport_rect()
	if _main_box.visible:
		draw_texture_rect(_shade, Rect2(Vector2.ZERO, Vector2(rect.size.x * 0.66, rect.size.y)), false)
		draw_rect(Rect2(0.0, rect.size.y - 38.0, rect.size.x, 38.0), Color(0.02, 0.03, 0.045, 0.72))
		draw_rect(Rect2(0.0, rect.size.y - 38.0, rect.size.x, 1.0), UiTheme.LINE_SOFT)
		var origin: Vector2 = Vector2(MENU_LEFT + 8.0, 150.0)
		for i: int in 5:
			var t: float = fposmod(_time * 0.1 + float(i) / 5.0, 1.0)
			draw_arc(origin, lerpf(30.0, 560.0, t), -0.9, 0.9, 64, Color(0.3, 0.7, 1.0, (1.0 - t) * 0.16), 2.0, true)
	else:
		draw_rect(rect, Color(0.02, 0.03, 0.045, 0.66))


## A wide menu entry: left-aligned text behind an accent bar that widens and
## lights up under the pointer.
func _menu_button(text: String, action: Callable) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(380.0, 54.0)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 21)
	b.add_theme_font_override("font", UiTheme.strong_font())
	var idle: StyleBoxFlat = UiTheme.box(Color(0.06, 0.09, 0.125, 0.72), UiTheme.LINE_SOFT, 4, 0, 10.0)
	idle.border_width_left = 3
	idle.border_color = Color(UiTheme.ACCENT.r, UiTheme.ACCENT.g, UiTheme.ACCENT.b, 0.45)
	idle.content_margin_left = 24.0
	var hot: StyleBoxFlat = UiTheme.box(UiTheme.RAISED_HOT, UiTheme.ACCENT, 4, 0, 10.0)
	hot.border_width_left = 7
	hot.content_margin_left = 28.0
	var down: StyleBoxFlat = UiTheme.box(UiTheme.PRESSED, UiTheme.ACCENT, 4, 0, 10.0)
	down.border_width_left = 7
	down.content_margin_left = 28.0
	var off: StyleBoxFlat = UiTheme.box(Color(0.05, 0.065, 0.085, 0.6), UiTheme.FAINT, 4, 0, 10.0)
	off.border_width_left = 3
	off.content_margin_left = 24.0
	b.add_theme_stylebox_override("normal", idle)
	b.add_theme_stylebox_override("hover", hot)
	b.add_theme_stylebox_override("pressed", down)
	b.add_theme_stylebox_override("disabled", off)
	b.add_theme_stylebox_override("focus", hot)
	b.pressed.connect(action)
	return b


func _build_main() -> void:
	_main_box = VBoxContainer.new()
	_main_box.name = "Main"
	_main_box.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	_main_box.offset_left = MENU_LEFT
	_main_box.offset_right = MENU_LEFT + 560.0
	_main_box.offset_top = 64.0
	_main_box.offset_bottom = -9.0
	_main_box.add_theme_constant_override("separation", 10)
	add_child(_main_box)
	_main_box.add_child(UiTheme.caption("REAL-TIME STRATEGY", UiTheme.ACCENT))
	var logo: VBoxContainer = VBoxContainer.new()
	logo.add_theme_constant_override("separation", -30)
	_main_box.add_child(logo)
	var word_one: Label = UiTheme.title("SIGNAL", 86, UiTheme.TEXT)
	logo.add_child(word_one)
	var word_two: Label = UiTheme.title("FRONT", 86, UiTheme.ACCENT)
	logo.add_child(word_two)
	for word: Label in [word_one, word_two]:
		word.add_theme_constant_override("line_spacing", -18)
		word.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.55))
		word.add_theme_constant_override("shadow_offset_x", 3)
		word.add_theme_constant_override("shadow_offset_y", 4)
	var bar: ColorRect = UiTheme.rule(UiTheme.ACCENT, 3.0)
	bar.custom_minimum_size = Vector2(150.0, 3.0)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_main_box.add_child(bar)
	var tag: Label = UiTheme.label("Every army runs on signal.\nCut the chain and the front goes dark.", 19, UiTheme.DIM)
	_main_box.add_child(tag)
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0.0, 26.0)
	_main_box.add_child(gap)
	var buttons: Array[Button] = [
		_menu_button("Skirmish", open_skirmish),
		_menu_button("Load Saved Game", load_saved),
		_menu_button("Tutorials", func() -> void: _show(_tutorials)),
		_menu_button("How to Play", func() -> void: _show(_help)),
		_menu_button("Settings", open_settings),
		_menu_button("Quit", func() -> void: get_tree().quit()),
	]
	for b: Button in buttons:
		_main_box.add_child(b)
	# Loading is only offered when there is something to load.
	buttons[1].disabled = not SimSave.has_save()
	var push: Control = Control.new()
	push.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_main_box.add_child(push)
	_main_box.add_child(UiTheme.label("Built with Godot 4.7.2  ·  every model, map, shader and sound is generated in code", 13, UiTheme.FAINT))
	# What the match in the background is.
	_live = UiTheme.label("", 14, UiTheme.DIM)
	_live.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_live.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_live.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_live.offset_right = -22.0
	_live.offset_bottom = -9.0
	_live.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_live)


func _row(parent: VBoxContainer, caption: String, control: Control) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var label: Label = Hud.make_label(caption, 18, Hud.TEXT)
	label.custom_minimum_size = Vector2(170.0, 0.0)
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	parent.add_child(row)


func _build_setup() -> void:
	_setup = PanelContainer.new()
	_setup.add_theme_stylebox_override("panel", UiTheme.panel(UiTheme.LINE, 22.0))
	_setup.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_setup.custom_minimum_size = Vector2(560.0, 0.0)
	_setup.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_setup.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_setup)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	_setup.add_child(box)
	box.add_child(UiTheme.title("SKIRMISH", 28))
	box.add_child(Hud.make_label("Destroy every enemy headquarters. Starts are always symmetric.", 15, Hud.DIM))

	_map = OptionButton.new()
	_map.add_item("Generated from the seed")
	_map_ids.append("")
	_map_players.append(4)
	_map.add_item("Generated, compact (shorter match)")
	_map_ids.append(COMPACT_MAP)
	_map_players.append(2)
	for id: String in SimMapGen.layout_ids():
		var info: Dictionary = SimMapGen.layout_info(id)
		_map.add_item("%s (%d players)" % [str(info["name"]), int(info["players"])])
		_map_ids.append(id)
		_map_players.append(int(info["players"]))
	_row(box, "Map", _map)
	_map_blurb = Hud.make_label("", 14, Hud.DIM)
	_map_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_map_blurb.custom_minimum_size = Vector2(520.0, 22.0)
	box.add_child(_map_blurb)
	_map.item_selected.connect(func(_i: int) -> void: _update_map())
	_region = OptionButton.new()
	_region.add_item("From the seed")
	for id: String in SimMapGen.REGIONS:
		_region.add_item(SimMapGen.REGION_NAMES[id])
	_region.tooltip_text = "Where the battlefield lies. It changes the look of the land, not how it plays."
	_row(box, "Region", _region)
	_opponents = OptionButton.new()
	for n: int in [1, 2, 3]:
		_opponents.add_item("%d opponent%s" % [n, "" if n == 1 else "s (free-for-all, larger map)"])
	_row(box, "Opponents", _opponents)

	var seed_row: HBoxContainer = HBoxContainer.new()
	seed_row.add_theme_constant_override("separation", 8)
	_seed = SpinBox.new()
	_seed.min_value = 1.0
	_seed.max_value = 999999.0
	_seed.value = float(randi_range(1, 99999))
	_seed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_row.add_child(_seed)
	var dice: Button = Button.new()
	dice.text = "Random"
	dice.pressed.connect(func() -> void: _seed.value = float(randi_range(1, 999999)))
	seed_row.add_child(dice)
	_row(box, "Map seed", seed_row)

	_faction = OptionButton.new()
	var data: GameData = GameData.shared()
	for f: FactionDef in data.factions.values():
		if f.playable:
			_faction_ids.append(f.id)
			_faction.add_item(f.name)
	_row(box, "Your faction", _faction)
	_faction_blurb = Hud.make_label("", 14, Hud.DIM)
	_faction_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_faction_blurb.custom_minimum_size = Vector2(520.0, 44.0)
	box.add_child(_faction_blurb)
	_faction.item_selected.connect(func(_i: int) -> void: _update_blurb())
	_enemy_faction = OptionButton.new()
	_enemy_faction.add_item("Random")
	for id: String in _faction_ids:
		_enemy_faction.add_item(data.faction(id).name)
	_row(box, "Enemy faction", _enemy_faction)
	_update_blurb()
	_update_map()

	_level = OptionButton.new()
	for n: String in LEVEL_NAMES:
		_level.add_item(n)
	_level.select(1)
	_row(box, "Difficulty", _level)

	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	var back: Button = Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(120.0, 44.0)
	back.pressed.connect(func() -> void: _show(_main_box))
	buttons.add_child(back)
	var start: Button = Button.new()
	start.text = "Start Match"
	start.theme_type_variation = "PrimaryButton"
	start.custom_minimum_size = Vector2(180.0, 44.0)
	start.add_theme_font_size_override("font_size", 20)
	start.pressed.connect(start_skirmish)
	buttons.add_child(start)
	box.add_child(buttons)


func _build_tutorials() -> void:
	_tutorials = PanelContainer.new()
	_tutorials.add_theme_stylebox_override("panel", UiTheme.panel(UiTheme.LINE, 22.0))
	_tutorials.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_tutorials.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_tutorials.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_tutorials)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_tutorials.add_child(box)
	box.add_child(UiTheme.title("TUTORIALS", 28))
	box.add_child(Hud.make_label("Three short missions with the Aegis Directorate. Nothing can go wrong in them.", 15, Hud.DIM))
	for id: String in SimTutorial.IDS:
		var b: Button = Button.new()
		b.text = "%s\n%s" % [SimTutorial.TITLES[id], SimTutorial.BLURBS[id]]
		b.custom_minimum_size = Vector2(520.0, 64.0)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 17)
		b.pressed.connect(start_tutorial.bind(id))
		box.add_child(b)
	var back: Button = Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(120.0, 44.0)
	back.size_flags_horizontal = Control.SIZE_SHRINK_END
	back.pressed.connect(func() -> void: _show(_main_box))
	box.add_child(back)


func start_tutorial(tutorial_id: String) -> void:
	var game: GameState = get_node_or_null("/root/Game") as GameState
	if game != null:
		game.start_match(SimTutorial.config_for(tutorial_id))


func _build_help() -> void:
	_help = PanelContainer.new()
	_help.add_theme_stylebox_override("panel", UiTheme.panel(UiTheme.LINE, 22.0))
	_help.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_help.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_help.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_help)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_help.add_child(box)
	var text: Label = Hud.make_label(HELP_TEXT, 15, Hud.TEXT)
	box.add_child(text)
	var back: Button = Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(120.0, 44.0)
	back.size_flags_horizontal = Control.SIZE_SHRINK_END
	back.pressed.connect(func() -> void: _show(_main_box))
	box.add_child(back)


## Shows the chosen map's description and limits the opponent count to it.
func _update_map() -> void:
	var index: int = maxi(_map.selected, 0)
	var capacity: int = _map_players[index]
	if _map_ids[index] == "":
		_map_blurb.text = "A new battlefield from the seed: plains, highlands, lakeland or a river valley. 176 x 176 for two players, 192 x 192 for three or four."
	elif _map_ids[index] == COMPACT_MAP:
		_map_blurb.text = "A small 128 x 128 battlefield from the seed. The armies meet early; expect a match of about ten minutes."
	else:
		_map_blurb.text = str(SimMapGen.layout_info(_map_ids[index])["desc"])
	for i: int in 3:
		_opponents.set_item_disabled(i, i + 2 > capacity)
	if _opponents.selected + 2 > capacity:
		_opponents.select(capacity - 2)


## For automated runs: pick a map by id ("" = generated) and opponent count.
func choose_map(map_id: String, opponents: int) -> void:
	_map.select(maxi(_map_ids.find(map_id), 0))
	_update_map()
	_opponents.select(clampi(opponents, 1, 3) - 1)
	_update_map()


func _update_blurb() -> void:
	var f: FactionDef = GameData.shared().faction(_faction_ids[maxi(_faction.selected, 0)])
	_faction_blurb.text = f.desc


## For automated runs: pick factions by id before starting.
func choose_factions(mine: String, theirs: String) -> void:
	_faction.select(maxi(_faction_ids.find(mine), 0))
	_enemy_faction.select(_faction_ids.find(theirs) + 1)
	_update_blurb()


func _show(which: Control) -> void:
	_main_box.visible = which == _main_box
	_setup.visible = which == _setup
	_help.visible = which == _help
	_settings.visible = which == _settings
	_tutorials.visible = which == _tutorials


func load_saved() -> void:
	var game: GameState = get_node_or_null("/root/Game") as GameState
	if game != null:
		game.load_saved_match()


func open_settings() -> void:
	_show(_settings)


func open_skirmish() -> void:
	_show(_setup)


func is_setup_open() -> bool:
	return _setup.visible


## Builds the MatchConfig from the setup panel and starts the match.
func start_skirmish() -> void:
	var config: MatchConfig = MatchConfig.skirmish(int(_seed.value), _level.selected)
	config.map_id = _map_ids[maxi(_map.selected, 0)]
	if _region.selected > 0:
		config.region = SimMapGen.REGIONS[_region.selected - 1]
	if config.map_id == COMPACT_MAP:
		config.map_id = ""
		config.map_cells = SimMapGen.SMALL_CELLS
	config.factions = [_faction_ids[maxi(_faction.selected, 0)]]
	config.is_ai = [false]
	config.ai_levels = [1]
	config.names = ["Commander"]
	var opponents: int = mini(_opponents.selected + 1, _map_players[maxi(_map.selected, 0)] - 1)
	for i: int in opponents:
		var enemy_id: String = _faction_ids[randi_range(0, _faction_ids.size() - 1)]
		if _enemy_faction.selected > 0:
			enemy_id = _faction_ids[_enemy_faction.selected - 1]
		var label: String = "%s AI" % LEVEL_NAMES[_level.selected]
		if opponents > 1:
			label = "%s %d" % [label, i + 1]
		config.add_ai(enemy_id, _level.selected, label)
	var game: GameState = get_node_or_null("/root/Game") as GameState
	if game != null:
		game.start_match(config)
