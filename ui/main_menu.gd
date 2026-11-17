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
  5. Kills earn Command Points. Spend them in the Directives panel to unlock
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
  Z                                  stance: aggressive, return fire, hold fire
  Ctrl+A or F2                       select the whole army
  Ctrl+1..9, then 1..9               set and recall control groups (double-tap centres)
  Shift + order                      queue the order
  G                                  toggle the signal coverage overlay
  . (period) or F1                   select the next idle Field Engineer
  Ctrl+F5..F8, then F5..F8           save and recall camera bookmarks
  Minimap                            left click moves the camera, right click orders
  Alt+1..6 or the Directives panel   unlock / use a Directive
  Shift + train                      queue five of a unit
  Space                              look at the latest warning
  + / -                              game speed (x0.5 to x3)
  Esc                                cancel, or open the pause menu

The command card at the bottom right shows what the selection can build or
train, with its hotkey in the corner. Lines show where selected units are
going; a ring shows how far a selected unit or turret can shoot."""

## What each faction does that no other can: the second page of How to Play.
const FACTION_NOTES: Dictionary[String, String] = {
	"aegis": "Linked units shoot further. Marksmen that hide while they stand still, Kestrel gunships, and a turret for every kind of target.",
	"foundry": "Linked vehicles repair themselves. Crawlers are factories that drive to the front; Sappers lay mines; the heaviest tanks.",
	"nomad": "Hidden in forest, and half again as much salvage from wrecks. The headquarters and the relays pack up and move; Splicers steal Dark vehicles.",
	"vesper": "Cheap, quick drones that are faster while Linked. A Tether keeps the swarm Linked wherever it goes.",
	"verdigris": "Linked units shrug off 15% of every hit. Almoners heal infantry, which no other army can; the Lantern is the relay with the longest reach.",
	"zephyr": "Linked units see a quarter further. The only real air force: gunships, strike craft and bombers that fly over anything.",
	"tally": "Paid 15% of the value of everything it destroys. Guns within sight of a Paymaster fire a fifth faster.",
	"veil": "Hidden while standing still inside its own coverage, and anywhere near a Mantle. Sentinel turrets stay hidden until they fire.",
	"bracken": "Everything mends itself once it has been left alone for six seconds. Bursters run in and blow up, once.",
	"lodestone": "Whatever its weapons hit moves a third slower for a moment. A Dragline slows every enemy near it.",
}

const MENU_LEFT: float = 96.0  ## left edge of the main menu column
const LIGHT_ORDER: Array[String] = ["noon", "morning", "evening", "overcast"]  ## the Light setting; midday first, as it is the usual one

var _main_box: VBoxContainer = null
var _setup: PanelContainer = null
var _help: PanelContainer = null
var _settings: SettingsPanel = null
var _tutorials: PanelContainer = null
var _loads: PanelContainer = null  ## the Load Game page
var _load_list: VBoxContainer = null  ## one button a save, filled when the page opens
var _seed: SpinBox = null
# One row for each seat of the match: who plays it, as which faction, on
# which team and (for an AI) how well.
const SEATS: int = 4
var _seat_who: Array[OptionButton] = []
var _seat_faction: Array[OptionButton] = []
var _seat_team: Array[OptionButton] = []
var _seat_level: Array[OptionButton] = []
var _seat_note: Label = null  ## the line-up in words, or why it cannot start
var _start: Button = null
const COMPACT_MAP: String = "@compact"  ## map list entry for the small generated map

var _map: OptionButton = null
var _map_ids: Array[String] = []  ## "" = generated
var _map_players: Array[int] = []
var _map_blurb: Label = null
var _region: OptionButton = null
var _light: OptionButton = null
var _faction_blurb: Label = null
var _faction_ids: Array[String] = []
var _time: float = 0.0
var _backdrop: MenuBackdrop = null
var _shade: GradientTexture2D = null  ## dark on the left, clear on the right
var _live: Label = null  ## says which match is playing in the background
var _preview: MapPreview = null  ## a picture of the battlefield the setup gives
var _preview_caption: Label = null
var _help_text: Label = null
var _help_page: Button = null
var _help_roster: VBoxContainer = null
var _help_factions: bool = false
var _setup_title: Label = null
var _setup_plate: Label = null
var _setup_emblem: HudIcon = null
var setup_skin: UiSkin = null  ## the interface the setup panel is wearing


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
	_build_loads()
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
		_menu_button("Load Game", open_loads),
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
	_setup.custom_minimum_size = Vector2(820.0, 0.0)
	_setup.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_setup.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_setup)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 9)
	_setup.add_child(box)
	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	box.add_child(head)
	_setup_title = UiTheme.title("SKIRMISH", 28)
	_setup_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_setup_title)
	# The chosen faction's mark: the panel wears that faction's interface.
	_setup_plate = UiTheme.caption("")
	_setup_plate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_setup_plate)
	_setup_emblem = HudIcon.new()
	_setup_emblem.custom_minimum_size = Vector2(34.0, 34.0)
	head.add_child(_setup_emblem)
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
	# The map's rows on the left, a picture of it on the right.
	var top: HBoxContainer = HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	box.add_child(top)
	var rows: VBoxContainer = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 9)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(rows)
	var picture: VBoxContainer = VBoxContainer.new()
	picture.add_theme_constant_override("separation", 4)
	top.add_child(picture)
	var frame: PanelContainer = PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.SUNK, UiTheme.LINE, 3, 1, 3.0))
	picture.add_child(frame)
	_preview = MapPreview.new()
	_preview.name = "MapPreview"
	frame.add_child(_preview)
	_preview_caption = UiTheme.label("", 13, UiTheme.DIM)
	_preview_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	picture.add_child(_preview_caption)
	_row(rows, "Map", _map)
	_map_blurb = Hud.make_label("", 14, Hud.DIM)
	_map_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_map_blurb.custom_minimum_size = Vector2(540.0, 62.0)
	rows.add_child(_map_blurb)
	_map.item_selected.connect(func(_i: int) -> void: _update_map())
	# Region and seed share a line.
	var land: HBoxContainer = HBoxContainer.new()
	land.add_theme_constant_override("separation", 10)
	_region = OptionButton.new()
	_region.add_item("From the seed")
	for id: String in SimMapGen.REGIONS:
		_region.add_item(SimMapGen.REGION_NAMES[id])
	_region.tooltip_text = "Where the battlefield lies. It changes the look of the land, not how it plays."
	_region.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	land.add_child(_region)
	land.add_child(Hud.make_label("Seed", 18, Hud.TEXT))
	_seed = SpinBox.new()
	_seed.min_value = 1.0
	_seed.max_value = 999999.0
	_seed.value = float(randi_range(1, 99999))
	_seed.custom_minimum_size = Vector2(130.0, 0.0)
	land.add_child(_seed)
	var dice: Button = Button.new()
	dice.text = "Random"
	dice.pressed.connect(func() -> void: _seed.value = float(randi_range(1, 999999)))
	land.add_child(dice)
	_row(rows, "Region", land)
	_region.item_selected.connect(func(_i: int) -> void: _update_preview())
	_light = OptionButton.new()
	for id: String in LIGHT_ORDER:
		_light.add_item(SceneLight.TIME_NAMES[id])
	_light.tooltip_text = "The hour the battle is fought at: where the sun stands and what colour the light is. It changes nothing about how the match plays."
	_row(rows, "Light", _light)
	_seed.value_changed.connect(func(_v: float) -> void: _update_preview())

	# The seats.
	box.add_child(UiTheme.rule(UiTheme.LINE_SOFT, 1.0))
	var data: GameData = GameData.shared()
	for f: FactionDef in data.factions.values():
		if f.playable:
			_faction_ids.append(f.id)
	var table: GridContainer = GridContainer.new()
	table.columns = 5
	table.add_theme_constant_override("h_separation", 10)
	table.add_theme_constant_override("v_separation", 7)
	box.add_child(table)
	for word: String in ["SEAT", "PLAYED BY", "FACTION", "TEAM", "AI SKILL"]:
		table.add_child(UiTheme.caption(word))
	for seat: int in SEATS:
		var tag: HBoxContainer = HBoxContainer.new()
		tag.add_theme_constant_override("separation", 8)
		tag.custom_minimum_size = Vector2(58.0, 0.0)
		var chip: ColorRect = ColorRect.new()
		chip.color = MatchConfig.TEAM_COLORS[seat]
		chip.custom_minimum_size = Vector2(14.0, 14.0)
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chip.tooltip_text = "The colour this seat's army wears."
		tag.add_child(chip)
		tag.add_child(Hud.make_label(str(seat + 1), 18, Hud.TEXT))
		table.add_child(tag)
		var who: OptionButton = OptionButton.new()
		if seat == 0:
			who.add_item("You")
			who.add_item("AI (you watch)")
			who.tooltip_text = "Give your seat to the AI to watch the match: the whole battlefield, no fog of war, + and - change the speed."
		elif seat == 1:
			who.add_item("AI")
			who.disabled = true
		else:
			who.add_item("Closed")
			who.add_item("AI")
		who.custom_minimum_size = Vector2(160.0, 0.0)
		who.item_selected.connect(func(_i: int) -> void: _update_seats())
		table.add_child(who)
		_seat_who.append(who)
		var faction: OptionButton = OptionButton.new()
		if seat > 0:
			faction.add_item("Random")
		for id: String in _faction_ids:
			faction.add_item(data.faction(id).name)
		faction.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		faction.item_selected.connect(func(_i: int) -> void: _update_blurb())
		table.add_child(faction)
		_seat_faction.append(faction)
		var team: OptionButton = OptionButton.new()
		for t: int in SEATS:
			team.add_item("Team %d" % (t + 1))
		team.select(seat)
		team.tooltip_text = "Seats on the same team are allies: they do not fight each other, share what they see, and win or lose together."
		team.item_selected.connect(func(_i: int) -> void: _update_seats())
		table.add_child(team)
		_seat_team.append(team)
		var level: OptionButton = OptionButton.new()
		for n: String in LEVEL_NAMES:
			level.add_item(n)
		level.select(1)
		level.custom_minimum_size = Vector2(120.0, 0.0)
		table.add_child(level)
		_seat_level.append(level)
	_faction_blurb = Hud.make_label("", 14, Hud.DIM)
	_faction_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_faction_blurb.custom_minimum_size = Vector2(760.0, 44.0)
	box.add_child(_faction_blurb)
	_seat_note = Hud.make_label("", 15, Hud.TEXT)
	_seat_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_seat_note.custom_minimum_size = Vector2(760.0, 22.0)
	box.add_child(_seat_note)

	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	var back: Button = Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(120.0, 44.0)
	back.pressed.connect(func() -> void: _show(_main_box))
	buttons.add_child(back)
	_start = Button.new()
	_start.text = "Start Match"
	_start.theme_type_variation = "PrimaryButton"
	_start.custom_minimum_size = Vector2(180.0, 44.0)
	_start.add_theme_font_size_override("font_size", 20)
	_start.pressed.connect(start_skirmish)
	buttons.add_child(_start)
	box.add_child(buttons)
	_update_blurb()
	_update_map()


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
	box.add_child(Hud.make_label("Three short missions with the Aegis Directorate. Nothing can go wrong in them.\nThe other nine factions each have a rule and a unit of their own: see How to Play, The Factions.", 15, Hud.DIM))
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


func _build_loads() -> void:
	_loads = PanelContainer.new()
	_loads.add_theme_stylebox_override("panel", UiTheme.panel(UiTheme.LINE, 22.0))
	_loads.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_loads.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_loads.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_loads)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_loads.add_child(box)
	box.add_child(UiTheme.title("LOAD GAME", 28))
	box.add_child(Hud.make_label("Three slots you save to from the pause menu, and the autosave the game writes itself.\nThe newest is at the top.", 15, Hud.DIM))
	_load_list = VBoxContainer.new()
	_load_list.add_theme_constant_override("separation", 10)
	box.add_child(_load_list)
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
	_help_text = Hud.make_label(HELP_TEXT, 15, Hud.TEXT)
	_help_text.custom_minimum_size = Vector2(760.0, 0.0)
	box.add_child(_help_text)
	# The second page: every faction with its emblem, in its own colour.
	_help_roster = VBoxContainer.new()
	_help_roster.add_theme_constant_override("separation", 12)
	_help_roster.visible = false
	box.add_child(_help_roster)
	_help_roster.add_child(UiTheme.title("THE FACTIONS", 24))
	_help_roster.add_child(Hud.make_label("What each does that no other can. Select a unit in a match to see a ring at the reach of its guns, or of its aura.", 15, Hud.DIM))
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 12)
	_help_roster.add_child(grid)
	for f: FactionDef in GameData.shared().factions.values():
		if not f.playable:
			continue
		var skin: UiSkin = UiSkin.of(f.id)
		var mark: HudIcon = HudIcon.new()
		mark.kind = skin.emblem
		mark.color = skin.accent
		mark.custom_minimum_size = Vector2(28.0, 28.0)
		mark.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		grid.add_child(mark)
		var who: Label = UiTheme.label(f.name, 17, skin.accent)
		who.add_theme_font_override("font", UiTheme.strong_font())
		who.custom_minimum_size = Vector2(190.0, 0.0)
		who.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		grid.add_child(who)
		var what: Label = Hud.make_label(str(FACTION_NOTES.get(f.id, f.desc)), 15, Hud.TEXT)
		what.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		what.custom_minimum_size = Vector2(620.0, 0.0)
		grid.add_child(what)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(buttons)
	# Two pages: how to play, and what is special about each faction.
	_help_page = Button.new()
	_help_page.text = "The Factions"
	_help_page.custom_minimum_size = Vector2(180.0, 44.0)
	_help_page.pressed.connect(func() -> void: show_help_page(not _help_factions))
	buttons.add_child(_help_page)
	var back: Button = Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(120.0, 44.0)
	back.pressed.connect(func() -> void: _show(_main_box))
	buttons.add_child(back)


## The How to Play panel has two pages: the game, and the factions.
func show_help_page(factions: bool) -> void:
	_help_factions = factions
	_help_text.visible = not factions
	_help_roster.visible = factions
	_help_page.text = "How to Play" if factions else "The Factions"


## Shows the chosen map's description and closes the seats it has no room for.
func _update_map() -> void:
	var index: int = maxi(_map.selected, 0)
	if _map_ids[index] == "":
		_map_blurb.text = "A new battlefield from the seed, in one of four regions with five kinds of country each. 176 x 176 for two seats, 192 x 192 for three or four."
	elif _map_ids[index] == COMPACT_MAP:
		_map_blurb.text = "A small 128 x 128 battlefield from the seed, for two seats. The armies meet early; expect a match of about ten minutes."
	else:
		_map_blurb.text = str(SimMapGen.layout_info(_map_ids[index])["desc"])
	_update_seats()


## How many seats the chosen map has room for.
func _capacity() -> int:
	return _map_players[maxi(_map.selected, 0)]


func _seat_open(seat: int) -> bool:
	if seat >= _capacity():
		return false
	return seat < 2 or _seat_who[seat].selected == 1


func _watching() -> bool:
	return _seat_who[0].selected == 1


## Greys out what does not apply and says what the line-up amounts to.
func _update_seats() -> void:
	var sizes: Dictionary[int, int] = {}
	for seat: int in SEATS:
		var open: bool = _seat_open(seat)
		if seat >= 2:
			_seat_who[seat].disabled = seat >= _capacity()
			if seat >= _capacity():
				_seat_who[seat].select(0)
		_seat_faction[seat].disabled = not open
		_seat_team[seat].disabled = not open
		_seat_level[seat].disabled = not open or (seat == 0 and not _watching())
		if open:
			var team: int = _seat_team[seat].selected
			sizes[team] = int(sizes.get(team, 0)) + 1
	var teams: Array[int] = []
	teams.assign(sizes.keys())
	teams.sort()
	var problem: bool = teams.size() < 2
	_start.disabled = problem
	var note: String = ""
	if problem:
		note = "Every seat is on Team %d. Put at least one seat on another team to have a match." % (teams[0] + 1)
	else:
		var counts: Array[String] = []
		var allied: bool = false
		for team: int in teams:
			counts.append(str(sizes[team]))
			allied = allied or sizes[team] > 1
		if allied:
			note = "%s. Allies do not fight each other, share what they see, and win or lose together." % " against ".join(counts)
			var mine: int = _seat_team[0].selected
			if not _watching() and sizes[mine] > 1:
				note += " The AI on Team %d fights at your side." % (mine + 1)
		elif teams.size() > 2:
			note = "A free-for-all of %d: everyone against everyone." % teams.size()
		else:
			note = "One against one."
		if _watching():
			note += " You watch: the AI plays every seat and nothing is hidden."
	_seat_note.text = note
	_seat_note.add_theme_color_override("font_color", Hud.RED if problem else Hud.TEXT)
	_update_preview()


## Redraws the picture of the battlefield for the setup as it stands. Random
## factions are picked afresh when the match starts; the picture only needs
## the map, the seats and their teams.
func _update_preview() -> void:
	if _preview == null or _start == null:
		return
	_preview.show_config(build_config())
	_preview_caption.text = _preview.caption


## For automated runs: pick a map by id ("" = generated) and opponent count.
func choose_map(map_id: String, opponents: int) -> void:
	_map.select(maxi(_map_ids.find(map_id), 0))
	_update_map()
	for seat: int in range(2, SEATS):
		_seat_who[seat].select(1 if seat <= clampi(opponents, 1, 3) and seat < _capacity() else 0)
	_update_seats()


func _update_blurb() -> void:
	var f: FactionDef = GameData.shared().faction(_faction_ids[maxi(_seat_faction[0].selected, 0)])
	_faction_blurb.text = "%s: %s" % [f.name, f.desc]
	_dress_setup(f.id)


## Dresses the setup panel in the interface of the faction picked: what the
## match's HUD will look like.
func _dress_setup(faction_id: String) -> void:
	var skin: UiSkin = UiSkin.of(faction_id)
	setup_skin = skin
	_setup.theme = skin.theme()
	_setup.add_theme_stylebox_override("panel", skin.panel(22.0))
	_setup_title.add_theme_color_override("font_color", skin.accent)
	_setup_title.add_theme_font_override("font", skin.heading_font())
	_setup_plate.text = skin.plate
	_setup_plate.add_theme_color_override("font_color", skin.accent)
	_setup_plate.add_theme_font_override("font", skin.heading_font())
	_setup_emblem.kind = skin.emblem
	_setup_emblem.color = skin.accent
	_setup_emblem.queue_redraw()
	_faction_blurb.add_theme_color_override("font_color", skin.dim)


## For automated runs: watch the match instead of playing it.
func choose_watch(on: bool) -> void:
	_seat_who[0].select(1 if on else 0)
	_update_seats()


## For automated runs: pick factions by id before starting ("" = random
## for the other seats).
func choose_factions(mine: String, theirs: String) -> void:
	_seat_faction[0].select(maxi(_faction_ids.find(mine), 0))
	for seat: int in range(1, SEATS):
		_seat_faction[seat].select(_faction_ids.find(theirs) + 1)
	_update_blurb()


## For automated runs: put a seat (0-3) on a team (0-3).
func choose_team(seat: int, team: int) -> void:
	_seat_team[seat].select(clampi(team, 0, SEATS - 1))
	_update_seats()


func can_start() -> bool:
	return not _start.disabled


func _show(which: Control) -> void:
	_main_box.visible = which == _main_box
	_setup.visible = which == _setup
	_help.visible = which == _help
	_settings.visible = which == _settings
	_tutorials.visible = which == _tutorials
	_loads.visible = which == _loads


## Continues a saved match: the slot named, or the one saved last.
func load_saved(slot: String = "") -> void:
	var game: GameState = get_node_or_null("/root/Game") as GameState
	if game != null:
		game.load_saved_match(slot)


## The save slots, newest first, each with what it holds.
func open_loads() -> void:
	for child: Node in _load_list.get_children():
		child.queue_free()
	var infos: Array[Dictionary] = []
	for slot: String in SimSave.SLOTS:
		var info: Dictionary = SimSave.slot_info(slot)
		if not info.is_empty():
			infos.append(info)
	infos.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["saved_at"]) > int(b["saved_at"]))
	for info: Dictionary in infos:
		var sides: Array = info.get("sides", [])
		var who: String = "" if sides.is_empty() else "   ·   " + " v ".join(PackedStringArray(sides))
		var b: Button = Button.new()
		b.text = "%s%s\n%s" % [str(info["name"]), who, SimSave.describe(info)]
		b.custom_minimum_size = Vector2(640.0, 64.0)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 17)
		b.clip_text = true
		b.pressed.connect(load_saved.bind(str(info["slot"])))
		_load_list.add_child(b)
	if infos.is_empty():
		_load_list.add_child(UiTheme.label("Nothing has been saved yet.", 17, UiTheme.DIM))
	_show(_loads)


## How many saves the load page is offering (for tests).
func loads_offered() -> int:
	var n: int = 0
	for child: Node in _load_list.get_children():
		if child is Button and not child.is_queued_for_deletion():
			n += 1
	return n


func open_settings() -> void:
	_show(_settings)


func open_skirmish() -> void:
	_show(_setup)


func is_setup_open() -> bool:
	return _setup.visible


## Builds the MatchConfig from the setup panel.
func build_config() -> MatchConfig:
	var data: GameData = GameData.shared()
	var config: MatchConfig = MatchConfig.skirmish(int(_seed.value), 1)
	config.map_id = _map_ids[maxi(_map.selected, 0)]
	if _region.selected > 0:
		config.region = SimMapGen.REGIONS[_region.selected - 1]
	if _light.selected > 0:
		config.time_of_day = LIGHT_ORDER[_light.selected]
	if config.map_id == COMPACT_MAP:
		config.map_id = ""
		config.map_cells = SimMapGen.SMALL_CELLS
	config.factions.clear()
	config.is_ai.clear()
	config.ai_levels.clear()
	config.names.clear()
	config.watch = _watching()
	var used: Dictionary[String, int] = {}
	for seat: int in SEATS:
		if not _seat_open(seat):
			continue
		var faction_id: String = _faction_ids[randi_range(0, _faction_ids.size() - 1)]
		var picked: int = _seat_faction[seat].selected - (0 if seat == 0 else 1)
		if picked >= 0:
			faction_id = _faction_ids[picked]
		var ai: bool = seat > 0 or config.watch
		# An AI goes by the name of its faction; two of a kind are numbered.
		var seat_name: String = "Commander"
		if ai:
			seat_name = data.faction(faction_id).name
			used[seat_name] = int(used.get(seat_name, 0)) + 1
			if used[seat_name] > 1:
				seat_name = "%s %d" % [seat_name, used[seat_name]]
		config.factions.append(faction_id)
		config.is_ai.append(ai)
		config.ai_levels.append(_seat_level[seat].selected if ai else 1)
		config.names.append(seat_name)
		config.set_team(config.player_count() - 1, _seat_team[seat].selected)
	return config


func start_skirmish() -> void:
	if _start.disabled:
		return
	var game: GameState = get_node_or_null("/root/Game") as GameState
	if game != null:
		game.start_match(build_config())
