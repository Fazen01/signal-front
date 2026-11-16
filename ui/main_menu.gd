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

var _main_box: VBoxContainer = null
var _setup: PanelContainer = null
var _help: PanelContainer = null
var _seed: SpinBox = null
var _faction: OptionButton = null
var _level: OptionButton = null
var _enemy_faction: OptionButton = null
var _faction_blurb: Label = null
var _faction_ids: Array[String] = []
var _time: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_main()
	_build_setup()
	_build_help()
	_show(_main_box)
	print("Main menu ready")


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


## Background: dark field with slow expanding signal rings.
func _draw() -> void:
	var rect: Rect2 = get_viewport_rect()
	draw_rect(rect, Color(0.035, 0.05, 0.065))
	var origin: Vector2 = Vector2(rect.size.x * 0.5, rect.size.y * 0.30)
	for i: int in 7:
		var t: float = fposmod(_time * 0.12 + float(i) / 7.0, 1.0)
		var radius: float = lerpf(40.0, rect.size.x * 0.75, t)
		var alpha: float = (1.0 - t) * 0.22
		draw_arc(origin, radius, 0.0, TAU, 96, Color(0.25, 0.62, 1.0, alpha), 2.0)
	# A faint chain of relay nodes along the bottom.
	var y: float = rect.size.y * 0.86
	var prev: Vector2 = Vector2(rect.size.x * 0.08, y)
	for i: int in 9:
		var p: Vector2 = Vector2(rect.size.x * (0.08 + 0.105 * float(i)), y + sin(float(i) * 1.7) * 26.0)
		var lit: bool = fposmod(_time * 0.6 - float(i) * 0.25, 3.0) < 2.0
		var col: Color = Color(0.25, 0.62, 1.0, 0.55) if lit else Color(0.5, 0.2, 0.15, 0.4)
		if i > 0:
			draw_line(prev, p, Color(col.r, col.g, col.b, col.a * 0.6), 2.0)
		draw_circle(p, 6.0, col)
		prev = p


func _menu_button(text: String, action: Callable) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(340.0, 54.0)
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(action)
	return b


func _build_main() -> void:
	var centre: CenterContainer = CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	_main_box = VBoxContainer.new()
	_main_box.add_theme_constant_override("separation", 14)
	_main_box.alignment = BoxContainer.ALIGNMENT_CENTER
	centre.add_child(_main_box)
	var title: Label = Hud.make_label("SIGNAL FRONT", 84, Color(0.55, 0.85, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_main_box.add_child(title)
	var tag: Label = Hud.make_label("Every army runs on signal. Cut the chain and the front goes dark.", 20, Hud.DIM)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_main_box.add_child(tag)
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0.0, 40.0)
	_main_box.add_child(gap)
	for b: Button in [
		_menu_button("Skirmish", open_skirmish),
		_menu_button("How to Play", func() -> void: _show(_help)),
		_menu_button("Quit", func() -> void: get_tree().quit()),
	]:
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_main_box.add_child(b)


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
	_setup.add_theme_stylebox_override("panel", Hud.panel_style())
	_setup.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_setup.custom_minimum_size = Vector2(560.0, 0.0)
	_setup.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_setup.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_setup)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	_setup.add_child(box)
	box.add_child(Hud.make_label("SKIRMISH", 32, Color(0.55, 0.85, 1.0)))
	box.add_child(Hud.make_label("One opponent on a mirrored 128 x 128 battlefield. Destroy the enemy headquarters.", 15, Hud.DIM))

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

	_level = OptionButton.new()
	for n: String in LEVEL_NAMES:
		_level.add_item(n)
	_level.select(1)
	_row(box, "Opponent", _level)

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
	start.custom_minimum_size = Vector2(180.0, 44.0)
	start.add_theme_font_size_override("font_size", 20)
	start.pressed.connect(start_skirmish)
	buttons.add_child(start)
	box.add_child(buttons)


func _build_help() -> void:
	_help = PanelContainer.new()
	_help.add_theme_stylebox_override("panel", Hud.panel_style())
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


func open_skirmish() -> void:
	_show(_setup)


func is_setup_open() -> bool:
	return _setup.visible


## Builds the MatchConfig from the setup panel and starts the match.
func start_skirmish() -> void:
	var config: MatchConfig = MatchConfig.skirmish(int(_seed.value), _level.selected)
	var faction_id: String = _faction_ids[maxi(_faction.selected, 0)]
	var enemy_id: String = _faction_ids[randi_range(0, _faction_ids.size() - 1)]
	if _enemy_faction.selected > 0:
		enemy_id = _faction_ids[_enemy_faction.selected - 1]
	config.factions = [faction_id, enemy_id]
	config.names = ["Commander", "%s AI" % LEVEL_NAMES[_level.selected]]
	var game: GameState = get_node_or_null("/root/Game") as GameState
	if game != null:
		game.start_match(config)
