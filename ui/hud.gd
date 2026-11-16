class_name Hud
extends Control
## In-match interface: resources, selection panel, command card with
## hotkeys, production queue and the alerts feed. Reads sim state and issues
## SimCommands; never mutates the simulation.

class CardEntry:
	var kind: String = ""  ## build, train, order, cancel
	var def: EntityDef = null
	var order: String = ""
	var hotkey: String = ""
	var title: String = ""
	var tip: String = ""

const CARD_COLUMNS: int = 4
const CARD_SLOTS: int = 12
const GOLD: Color = Color(1.0, 0.82, 0.35)
const CYAN: Color = Color(0.45, 0.85, 1.0)
const RED: Color = Color(1.0, 0.4, 0.35)
const TEXT: Color = Color(0.88, 0.92, 0.95)
const DIM: Color = Color(0.62, 0.68, 0.72)

var battle: BattleScene = null
var world: SimWorld = null
var player: int = 0
var skin: UiSkin = null  ## colours, shapes and lettering of the local player's faction

var _salvage: Label = null
var _bandwidth: Label = null
var _clock: Label = null
var _sel_title: Label = null
var _sel_detail: Label = null
var _health_row: HBoxContainer = null  ## health of what is selected: a bar and the numbers
var _health_bar: ProgressBar = null
var _health_text: Label = null
var _health_fills: Array[StyleBoxFlat] = []  ## green, amber, red
var _health_tone: int = -1
var _queue_row: HBoxContainer = null
var _queue_bar: ProgressBar = null
var _info: Label = null
var _card: GridContainer = null
var _buttons: Array[Button] = []
var _entries: Array[CardEntry] = []
var _alerts: VBoxContainer = null
var _alert_age: Array[float] = []
var _refresh_in: float = 0.0
var _points: Label = null
var _directive_buttons: Array[Button] = []
var _directive_names: Array[Label] = []
var _directive_states: Array[Label] = []
var _key_labels: Array[Label] = []  ## hotkey badge on each command card button
var _cost_labels: Array[Label] = []  ## salvage cost on each command card button
var _bandwidth_bar: ProgressBar = null
var _income: Label = null  ## salvage collected per minute, over the last half minute
var _income_at: PackedFloat32Array = PackedFloat32Array()
var _income_total: PackedInt32Array = PackedInt32Array()
var _speed: Label = null  ## shown when the game is not running at normal speed
var _directive_defs: Array[DirectiveDef] = []
var _queue_sig: String = ""
var minimap_slot: Control = null
var minimap: Minimap = null


func setup(scene: BattleScene) -> void:
	# Set here as well as on the root window: themes do not pass down
	# through a CanvasLayer.
	skin = scene.skin if scene.skin != null else UiSkin.of("")
	theme = skin.theme()
	battle = scene
	world = scene.world
	player = scene.local_player
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_top_bar()
	_build_bottom_bar()
	_build_alerts()
	rebuild_card()
	_refresh()


# ----------------------------------------------------------------- layout

static func panel_style(accent: Color = Color(0.25, 0.55, 0.9, 0.7)) -> StyleBoxFlat:
	return UiTheme.panel(accent)


static func make_label(text: String, font_px: int, color: Color) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_px)
	l.add_theme_color_override("font_color", color)
	return l


## A strip across a screen edge: darker than a panel, with one hairline.
func _strip_style(top_edge: bool) -> StyleBoxFlat:
	return skin.strip(top_edge)


## An icon, a value and a small caption; returns the value label.
func _stat(row: HBoxContainer, kind: String, caption_text: String, color: Color) -> Label:
	var chip: HBoxContainer = HBoxContainer.new()
	chip.add_theme_constant_override("separation", 8)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon: HudIcon = HudIcon.new()
	icon.kind = kind
	icon.color = color
	chip.add_child(icon)
	var value: Label = UiTheme.label("0", 20, color)
	value.add_theme_font_override("font", UiTheme.strong_font())
	chip.add_child(value)
	if caption_text != "":
		var cap: Label = skin.caption(caption_text)
		cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chip.add_child(cap)
	row.add_child(chip)
	return value


func _build_top_bar() -> void:
	var bar: PanelContainer = PanelContainer.new()
	bar.name = "TopBar"
	bar.add_theme_stylebox_override("panel", _strip_style(false))
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = 46.0
	add_child(bar)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	bar.add_child(row)
	# Whose interface this is: the faction's emblem and name.
	var plate: HBoxContainer = HBoxContainer.new()
	plate.name = "FactionPlate"
	plate.add_theme_constant_override("separation", 9)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var emblem: HudIcon = HudIcon.new()
	emblem.kind = skin.emblem
	emblem.color = skin.accent
	emblem.custom_minimum_size = Vector2(28.0, 28.0)
	plate.add_child(emblem)
	var plate_name: Label = skin.caption(skin.plate, skin.accent)
	plate_name.add_theme_font_size_override("font_size", 13)
	plate_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	plate.add_child(plate_name)
	row.add_child(plate)
	var divider: ColorRect = ColorRect.new()
	divider.color = skin.line
	divider.custom_minimum_size = Vector2(maxf(1.0, float(skin.panel_edge[1]) * 0.5), 24.0)
	divider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(divider)
	_salvage = _stat(row, "salvage", "SALVAGE", skin.second)
	_income = UiTheme.label("", 13, Color(skin.second.r, skin.second.g, skin.second.b, 0.75))
	_income.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_income.tooltip_text = "Salvage your haulers brought in per minute, over the last half minute."
	_income.mouse_filter = Control.MOUSE_FILTER_STOP
	_salvage.get_parent().add_child(_income)
	_bandwidth = _stat(row, "bandwidth", "BANDWIDTH", skin.accent)
	_bandwidth_bar = ProgressBar.new()
	_bandwidth_bar.custom_minimum_size = Vector2(96.0, 8.0)
	_bandwidth_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bandwidth_bar.show_percentage = false
	_bandwidth_bar.max_value = 1.0
	_bandwidth_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bandwidth.get_parent().add_child(_bandwidth_bar)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	if battle.watching:
		var sides: Array[String] = []
		for wp: SimPlayer in world.players:
			sides.append(wp.name)
		var banner: Label = skin.caption("WATCHING   " + "  vs  ".join(sides), skin.second)
		banner.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(banner)
	_speed = UiTheme.label("", 15, skin.accent)
	_speed.add_theme_font_override("font", UiTheme.strong_font())
	_speed.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_speed)
	_clock = _stat(row, "clock", "", skin.text)
	var menu: Button = Button.new()
	menu.text = "Menu  Esc"
	menu.custom_minimum_size = Vector2(112.0, 30.0)
	menu.focus_mode = Control.FOCUS_NONE
	menu.pressed.connect(func() -> void: battle.toggle_pause_menu())
	row.add_child(menu)


func _build_bottom_bar() -> void:
	var bar: PanelContainer = PanelContainer.new()
	bar.name = "BottomBar"
	bar.add_theme_stylebox_override("panel", _strip_style(true))
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bar.offset_top = -198.0
	add_child(bar)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	bar.add_child(row)

	# Three framed sections: the map, what is selected, and what it can do.
	var map_frame: PanelContainer = PanelContainer.new()
	map_frame.add_theme_stylebox_override("panel", skin.frame())
	row.add_child(map_frame)
	minimap_slot = Control.new()
	minimap_slot.name = "MinimapSlot"
	minimap_slot.custom_minimum_size = Vector2(172.0, 172.0)
	map_frame.add_child(minimap_slot)
	minimap = Minimap.new()
	minimap.name = "Minimap"
	minimap_slot.add_child(minimap)
	minimap.clip_contents = true
	minimap.setup(battle)

	var section: StyleBoxFlat = skin.section()
	var info_frame: PanelContainer = PanelContainer.new()
	info_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_frame.add_theme_stylebox_override("panel", section)
	info_frame.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(info_frame)
	# The text sits in a plain clipped holder, so a long description can
	# never make the whole bar taller.
	var holder: Control = Control.new()
	holder.clip_contents = true
	holder.mouse_filter = Control.MOUSE_FILTER_PASS
	info_frame.add_child(holder)
	var sel: VBoxContainer = VBoxContainer.new()
	sel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sel.add_theme_constant_override("separation", 3)
	holder.add_child(sel)
	_sel_title = make_label("", 21, skin.text)
	_sel_title.add_theme_font_override("font", UiTheme.strong_font())
	sel.add_child(_sel_title)
	var health_row: HBoxContainer = HBoxContainer.new()
	health_row.add_theme_constant_override("separation", 9)
	sel.add_child(health_row)
	_health_bar = ProgressBar.new()
	_health_bar.custom_minimum_size = Vector2(230.0, 9.0)
	_health_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_health_bar.show_percentage = false
	_health_bar.max_value = 1.0
	_health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_row.add_child(_health_bar)
	_health_text = make_label("", 13, skin.text)
	health_row.add_child(_health_text)
	_health_row = health_row
	for tone: Color in [Color(0.36, 0.86, 0.42), Color(0.98, 0.78, 0.25), RED]:
		_health_fills.append(UiTheme.box(tone, Color(0.0, 0.0, 0.0, 0.0), mini(3, skin.corners[0]), 0, 0.0))
	_sel_detail = make_label("", 14, skin.dim)
	_sel_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sel.add_child(_sel_detail)
	_queue_row = HBoxContainer.new()
	_queue_row.add_theme_constant_override("separation", 4)
	sel.add_child(_queue_row)
	_queue_bar = ProgressBar.new()
	_queue_bar.custom_minimum_size = Vector2(220.0, 10.0)
	_queue_bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_queue_bar.show_percentage = false
	_queue_bar.max_value = 1.0
	_queue_bar.visible = false
	sel.add_child(_queue_bar)
	_info = make_label("", 13, skin.second)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_info.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	sel.add_child(_info)

	_build_directives(row, section)

	var card_frame: PanelContainer = PanelContainer.new()
	card_frame.add_theme_stylebox_override("panel", section)
	row.add_child(card_frame)
	_card = GridContainer.new()
	_card.columns = CARD_COLUMNS
	_card.add_theme_constant_override("h_separation", 5)
	_card.add_theme_constant_override("v_separation", 5)
	_card.custom_minimum_size = Vector2(float(CARD_COLUMNS) * 133.0 - 5.0, 0.0)
	card_frame.add_child(_card)
	for i: int in CARD_SLOTS:
		var b: Button = Button.new()
		b.custom_minimum_size = Vector2(128.0, 50.0)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 14)
		b.clip_text = true
		b.pressed.connect(_on_card_pressed.bind(i))
		b.mouse_entered.connect(_on_card_hover.bind(i))
		b.mouse_exited.connect(_on_card_hover.bind(-1))
		_card.add_child(b)
		_buttons.append(b)
		# Hotkey in the top-left corner, cost in the bottom-right.
		var key: Label = UiTheme.label("", 11, skin.accent)
		key.add_theme_font_override("font", UiTheme.strong_font())
		key.position = Vector2(6.0, 2.0)
		key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(key)
		_key_labels.append(key)
		var cost: Label = UiTheme.label("", 12, skin.second)
		cost.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		cost.offset_left = -70.0
		cost.offset_top = -19.0
		cost.offset_right = -7.0
		cost.offset_bottom = -2.0
		cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(cost)
		_cost_labels.append(cost)


func _build_alerts() -> void:
	_alerts = VBoxContainer.new()
	_alerts.name = "Alerts"
	_alerts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_alerts.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_alerts.offset_left = 14.0
	_alerts.offset_top = 52.0
	add_child(_alerts)


## The Directives sit inside the bottom bar, between the selection and the
## command card, so they cover none of the battlefield.
func _build_directives(row: HBoxContainer, section: StyleBoxFlat) -> void:
	var frame: PanelContainer = PanelContainer.new()
	frame.name = "Directives"
	frame.visible = not battle.watching
	frame.add_theme_stylebox_override("panel", section)
	row.add_child(frame)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	frame.add_child(box)
	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	box.add_child(head)
	var star: HudIcon = HudIcon.new()
	star.kind = "points"
	star.color = skin.second
	star.custom_minimum_size = Vector2(18.0, 18.0)
	head.add_child(star)
	_points = make_label("0", 17, skin.second)
	_points.add_theme_font_override("font", UiTheme.strong_font())
	_points.tooltip_text = "Command Points: earned by destroying enemy units and buildings. Spend them to unlock Directives."
	_points.mouse_filter = Control.MOUSE_FILTER_STOP
	head.add_child(_points)
	var cap: Label = skin.caption("COMMAND POINTS")
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(cap)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	box.add_child(grid)
	for id: String in world.data.directive_order:
		var def: DirectiveDef = world.data.directive(id)
		var b: Button = Button.new()
		b.theme_type_variation = "ChipButton"
		b.custom_minimum_size = Vector2(128.0, 38.0)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(activate_directive.bind(def.slot))
		b.mouse_entered.connect(_on_directive_hover.bind(def.slot))
		b.mouse_exited.connect(_on_directive_hover.bind(-1))
		grid.add_child(b)
		# The name along the top, what it needs or when it is ready below.
		var title: Label = UiTheme.label(def.name, 12, skin.text)
		title.position = Vector2(8.0, 2.0)
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(title)
		var state: Label = UiTheme.label("", 11, skin.dim)
		state.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		state.offset_left = -118.0
		state.offset_top = -18.0
		state.offset_right = -8.0
		state.offset_bottom = -2.0
		state.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		state.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(state)
		_directive_buttons.append(b)
		_directive_names.append(title)
		_directive_states.append(state)
		_directive_defs.append(def)


func _on_directive_hover(index: int) -> void:
	if index < 0:
		_info.text = ""
		return
	var def: DirectiveDef = _directive_defs[index]
	_info.text = "%s  (Alt+%d)
%s
Unlock: %d Command Points.   Cooldown: %d s." % [def.name, index + 1, def.desc, def.cost, int(def.cooldown)]


## Click or Alt+number on a Directive: unlock it, or use it (starting
## targeting when it needs a target).
func activate_directive(index: int) -> bool:
	if battle.watching or index < 0 or index >= _directive_defs.size():
		return false
	var def: DirectiveDef = _directive_defs[index]
	var p: SimPlayer = world.players[player]
	if not p.unlocked.has(def.id):
		var why: String = SimDirectives.unlock_error(world, player, def)
		if why != "":
			push_alert(why, RED)
			return false
		world.push_command(SimCommand.unlock(player, def.id))
		return true
	if SimDirectives.cooldown_left(world, player, def) > 0.0:
		push_alert("%s is not ready yet" % def.name, RED)
		return false
	if def.needs_target():
		battle.begin_directive(def)
	else:
		world.push_command(SimCommand.directive(player, def.id, Vector2.ZERO))
	return true


func _refresh_directives() -> void:
	var p: SimPlayer = world.players[player]
	_points.text = str(p.command_points)
	for i: int in _directive_defs.size():
		var def: DirectiveDef = _directive_defs[i]
		var b: Button = _directive_buttons[i]
		var title: Label = _directive_names[i]
		var state: Label = _directive_states[i]
		var name_color: Color = skin.text
		var state_color: Color = skin.dim
		if not p.unlocked.has(def.id):
			state.text = "Unlock  %d CP" % def.cost
			b.disabled = p.command_points < def.cost
			if b.disabled:
				name_color = skin.faint
				state_color = skin.faint
			else:
				state_color = skin.second
		else:
			var left: float = SimDirectives.cooldown_left(world, player, def)
			if left > 0.0:
				state.text = "%d s" % int(ceilf(left))
				b.disabled = true
				name_color = skin.dim
			else:
				state.text = "Ready  Alt+%d" % (i + 1)
				b.disabled = false
				name_color = Color.WHITE
				state_color = skin.accent
		title.add_theme_color_override("font_color", name_color)
		state.add_theme_color_override("font_color", state_color)


# ----------------------------------------------------------------- alerts

func push_alert(text: String, color: Color = TEXT) -> void:
	if color == RED and battle.audio != null:
		battle.audio.play_ui("error", -8.0)
	# Callers name the plain colours; the faction's interface has its own.
	if color == CYAN:
		color = skin.accent
	elif color == GOLD:
		color = skin.second
	elif color == TEXT:
		color = skin.text
	# Do not stack identical messages.
	for child: Node in _alerts.get_children():
		var existing: Label = child as Label
		if existing != null and existing.text == text:
			return
	var l: Label = make_label(text, 16, color)
	l.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_alerts.add_child(l)
	_alert_age.append(0.0)
	if _alerts.get_child_count() > 6:
		_drop_alert(0)


func _drop_alert(index: int) -> void:
	var node: Node = _alerts.get_child(index)
	_alerts.remove_child(node)
	node.queue_free()
	_alert_age.remove_at(index)


# ---------------------------------------------------------- command card

func _selected_own() -> Array[SimEntity]:
	var out: Array[SimEntity] = []
	for e: SimEntity in battle.controller.selected_entities():
		if e.owner == player:
			out.append(e)
	return out


## Works out which commands the current selection offers.
func rebuild_card() -> void:
	_entries.clear()
	var own: Array[SimEntity] = _selected_own()
	if battle.watching:
		own.clear()
	var units: Array[SimEntity] = []
	var buildings: Array[SimEntity] = []
	for e: SimEntity in own:
		if e.kind == SimEntity.Kind.UNIT:
			units.append(e)
		elif e.kind == SimEntity.Kind.BUILDING:
			buildings.append(e)
	if not units.is_empty():
		var builds: Array[String] = []
		for e: SimEntity in units:
			for id: String in e.def.builds:
				if not builds.has(id):
					builds.append(id)
		for id: String in builds:
			var def: EntityDef = world.data.entity(id)
			_add_entry("build", def, "", def.hotkey, def.name, "%s\nCost %d   %s" % [def.name, def.cost, def.desc])
		for e: SimEntity in units:
			if e.def.deploys_to != "":
				var into: EntityDef = world.data.entity(e.def.deploys_to)
				_add_entry("deploy", null, e.def.deploys_to, "Y", "Deploy", "Deploy: set up as a %s. Must be inside your coverage." % into.name)
				break
		_add_entry("order", null, "attack_move", "A", "Attack-move", "Attack-move: advance and engage anything on the way.")
		_add_entry("order", null, "stop", "S", "Stop", "Stop: drop all orders.")
		_add_entry("order", null, "hold", "H", "Hold", "Hold position: fire only at what comes into range.")
	elif not buildings.is_empty():
		var produces: Array[String] = []
		var any_unfinished: bool = false
		for e: SimEntity in buildings:
			if not e.constructed:
				any_unfinished = true
				continue
			for id: String in e.def.produces:
				if not produces.has(id):
					produces.append(id)
		for id: String in produces:
			var def: EntityDef = world.data.entity(id)
			_add_entry("train", def, "", def.hotkey, def.name, "%s\nCost %d   Bandwidth %d   %s\nHold Shift to queue five." % [def.name, def.cost, def.bandwidth, def.desc])
		for e: SimEntity in buildings:
			if e.constructed and e.def.packs_to != "":
				_add_entry("pack", null, "", "Y", "Pack up", "Pack up into a %s so the factory can move. Queued units are refunded." % world.data.entity(e.def.packs_to).name)
				break
		if any_unfinished:
			_add_entry("cancel", null, "", "X", "Cancel", "Cancel construction for a full refund.")
	for i: int in CARD_SLOTS:
		var b: Button = _buttons[i]
		if i < _entries.size():
			var entry: CardEntry = _entries[i]
			b.visible = true
			b.text = entry.title
			_key_labels[i].text = entry.hotkey if GameSettings.key_hints else ""
			_cost_labels[i].text = str(entry.def.cost) if entry.def != null else ""
		else:
			b.visible = false
	_update_card_state()


func _add_entry(kind: String, def: EntityDef, order: String, hotkey: String, title: String, tip: String) -> void:
	if _entries.size() >= CARD_SLOTS:
		return
	var entry: CardEntry = CardEntry.new()
	entry.kind = kind
	entry.def = def
	entry.order = order
	entry.hotkey = hotkey
	entry.title = title
	entry.tip = tip
	_entries.append(entry)


## Why this card entry cannot be used right now, or "".
func _entry_blocked(entry: CardEntry) -> String:
	if entry.def == null:
		return ""
	var p: SimPlayer = world.players[player]
	if not p.meets_requirements(entry.def):
		return "Requires %s" % world.data.entity(entry.def.requires[0]).name
	if p.salvage < entry.def.cost:
		return "Not enough salvage"
	if entry.kind == "train" and _best_producer(entry.def) == null:
		return "Queue is full"
	return ""


func _update_card_state() -> void:
	for i: int in _entries.size():
		var blocked: bool = _entry_blocked(_entries[i]) != ""
		_buttons[i].disabled = blocked
		_key_labels[i].modulate.a = 0.4 if blocked else 1.0
		_cost_labels[i].modulate.a = 0.4 if blocked else 1.0


func _best_producer(def: EntityDef) -> SimEntity:
	var best: SimEntity = null
	for e: SimEntity in _selected_own():
		if e.kind == SimEntity.Kind.BUILDING and e.constructed and e.def.produces.has(def.id):
			if e.queue.size() >= world.data.queue_max:
				continue
			if best == null or e.queue.size() < best.queue.size():
				best = e
	return best


func _on_card_hover(index: int) -> void:
	if index < 0 or index >= _entries.size():
		_info.text = ""
		return
	var entry: CardEntry = _entries[index]
	var blocked: String = _entry_blocked(entry)
	_info.text = entry.tip if blocked == "" else "%s\n(%s)" % [entry.tip, blocked]


func _on_card_pressed(index: int) -> void:
	battle.audio.play_ui("click")
	if index >= 0 and index < _entries.size():
		activate(_entries[index], 5 if Input.is_key_pressed(KEY_SHIFT) else 1)


## Runs a card entry. Returns false when it is not available right now.
## `times` above one repeats a training order (Shift queues five).
func activate(entry: CardEntry, times: int = 1) -> bool:
	if battle.watching:
		return false
	var blocked: String = _entry_blocked(entry)
	if blocked != "":
		push_alert(blocked, RED)
		return false
	var ctl: SelectionController = battle.controller
	match entry.kind:
		"build":
			battle.begin_placement(entry.def)
		"train":
			var producer: SimEntity = _best_producer(entry.def)
			if producer != null:
				for i: int in maxi(1, times):
					world.push_command(SimCommand.train(player, producer.id, entry.def.id))
		"deploy":
			battle.begin_placement(world.data.entity(entry.order), true)
		"pack":
			for e: SimEntity in _selected_own():
				if e.kind == SimEntity.Kind.BUILDING and e.constructed and e.def.packs_to != "":
					world.push_command(SimCommand.pack(player, e.id))
		"cancel":
			for e: SimEntity in _selected_own():
				if e.kind == SimEntity.Kind.BUILDING and not e.constructed:
					world.push_command(SimCommand.cancel_building(player, e.id))
		"order":
			var ids: PackedInt32Array = ctl.own_unit_ids()
			match entry.order:
				"attack_move":
					ctl.mode = SelectionController.Mode.ATTACK_MOVE
				"stop":
					world.push_command(SimCommand.stop(player, ids))
				"hold":
					world.push_command(SimCommand.hold(player, ids))
	return true


## Card hotkeys. Order keys (A, S, H) are handled by the controller itself.
func handle_hotkey(key: InputEventKey) -> bool:
	var code: int = int(key.physical_keycode)
	if code < int(KEY_A) or code > int(KEY_Z):
		return false
	var letter: String = String.chr(code)
	for entry: CardEntry in _entries:
		if entry.kind != "order" and entry.hotkey == letter:
			activate(entry, 5 if key.shift_pressed else 1)
			return true
	return false


func find_entry(kind: String, def_id: String) -> CardEntry:
	for entry: CardEntry in _entries:
		if entry.kind == kind and entry.def != null and entry.def.id == def_id:
			return entry
	return null


# ---------------------------------------------------------------- refresh

func _process(delta: float) -> void:
	var i: int = _alert_age.size() - 1
	while i >= 0:
		_alert_age[i] += delta
		if _alert_age[i] > 6.0:
			_drop_alert(i)
		elif _alert_age[i] > 5.0:
			(_alerts.get_child(i) as Label).modulate.a = 6.0 - _alert_age[i]
		i -= 1
	_refresh_in -= delta
	if _refresh_in <= 0.0:
		_refresh_in = 0.12
		_refresh()


func _refresh() -> void:
	var p: SimPlayer = world.players[player]
	_salvage.text = "%d" % p.salvage
	_bandwidth.text = "%d / %d" % [p.bandwidth_used, p.bandwidth_cap]
	_bandwidth_bar.value = clampf(float(p.bandwidth_used) / maxf(1.0, float(p.bandwidth_cap)), 0.0, 1.0)
	_bandwidth.add_theme_color_override("font_color", RED if p.bandwidth_used >= p.bandwidth_cap else skin.accent)
	var secs: int = int(world.seconds())
	_clock.text = "%d:%02d" % [secs / 60, secs % 60]
	_speed.text = "" if is_equal_approx(battle.time_scale, 1.0) else "SPEED x%s" % str(battle.time_scale)
	# Income: what came in over the last thirty seconds of game time.
	var now: float = world.seconds()
	if _income_at.is_empty() or now - _income_at[_income_at.size() - 1] >= 1.0:
		_income_at.append(now)
		_income_total.append(p.stat_salvage_collected)
		while _income_at.size() > 2 and now - _income_at[1] >= 30.0:
			_income_at.remove_at(0)
			_income_total.remove_at(0)
	var span: float = now - _income_at[0]
	if span >= 5.0:
		_income.text = "+%d / min" % int(float(p.stat_salvage_collected - _income_total[0]) * 60.0 / span)
	_update_card_state()
	_refresh_directives()
	_refresh_selection()


func _refresh_selection() -> void:
	var sel: Array[SimEntity] = battle.controller.selected_entities()
	var queue_owner: SimEntity = null
	# Health: of the one thing selected, or of the whole group together.
	var hp_now: float = 0.0
	var hp_full: float = 0.0
	for e: SimEntity in sel:
		if e.def != null:
			hp_now += maxf(e.hp, 0.0)
			hp_full += e.max_hp
	_health_row.visible = hp_full > 0.0
	if hp_full > 0.0:
		var part: float = clampf(hp_now / hp_full, 0.0, 1.0)
		_health_bar.value = part
		_health_text.text = "%d / %d" % [int(ceilf(hp_now)), int(hp_full)]
		var tone: int = 0 if part > 0.6 else (1 if part > 0.3 else 2)
		if tone != _health_tone:
			_health_tone = tone
			_health_bar.add_theme_stylebox_override("fill", _health_fills[tone])
	if sel.is_empty():
		_sel_title.text = ""
		_sel_detail.text = "Left-drag to select. Right-click to order. Select a builder to build." if GameSettings.key_hints else ""
		if battle.watching:
			_sel_detail.text = "You are watching. + and - change the speed, Space looks at the latest warning, click anything to inspect it."
	elif sel.size() == 1:
		var e: SimEntity = sel[0]
		_sel_title.text = _entity_name(e)
		_sel_detail.text = _entity_detail(e)
		if e.owner == player and e.kind == SimEntity.Kind.BUILDING and e.constructed and not e.def.produces.is_empty():
			queue_owner = e
	else:
		var counts: Dictionary[String, int] = {}
		for e: SimEntity in sel:
			var n: String = _entity_name(e)
			counts[n] = counts.get(n, 0) + 1
		var parts: Array[String] = []
		for n: String in counts.keys():
			parts.append("%d %s" % [counts[n], n])
		_sel_title.text = "%d selected" % sel.size()
		_sel_detail.text = ", ".join(parts)
	_refresh_queue(queue_owner)


func _entity_name(e: SimEntity) -> String:
	if e.def != null:
		return e.def.name
	match e.kind:
		SimEntity.Kind.FIELD:
			return "Salvage Field"
		SimEntity.Kind.WRECK:
			return "Wreck"
		_:
			return "Uplink Site"


func _entity_detail(e: SimEntity) -> String:
	if e.def == null:
		if e.kind == SimEntity.Kind.UPLINK:
			var rate: int = world.data.uplink_income_per_second
			if e.owner < 0:
				return "Neutral. Capture it with a Field Engineer; it then pays %d salvage a second while it is inside your signal coverage." % rate
			var who: String = "You hold" if e.owner == player else "%s holds" % world.players[e.owner].name
			if e.linked:
				return "%s this site. Paying %d salvage a second." % [who, rate]
			return "%s this site, but it is outside their coverage and pays nothing." % who
		return "Salvage remaining: %d. Send a Hauler to collect it." % e.salvage
	var lines: Array[String] = []
	if e.owner >= 0 and e.owner != player:
		lines.append("Belongs to %s" % world.players[e.owner].name)
	if e.kind == SimEntity.Kind.BUILDING and not e.constructed:
		lines.append("Under construction: %d%%" % int(e.build_progress * 100.0))
	elif e.owner >= 0 and not e.linked:
		lines.append("DARK - outside the signal grid")
	if e.def.harvester:
		lines.append("Cargo %d / %d" % [e.cargo, e.def.capacity])
	if e.def.is_armed():
		var wd: WeaponDef = e.def.weapons[0]
		lines.append("%s: %d %s damage, range %d" % [wd.name, int(wd.damage), GameData.DAMAGE_TYPES[wd.damage_type], int(wd.max_range)])
	if e.def.signal_radius > 0.0:
		lines.append("Signal radius %d%s" % [int(e.def.signal_radius), "" if e.linked else " (unlinked)"])
	var facts: Array[String] = ["%s armour" % world.data.armor_classes[e.def.armor].capitalize()]
	if e.def.speed > 0.0:
		facts.append("speed %s" % str(snappedf(e.def.speed, 0.1)))
	facts.append("sight %d" % int(e.def.sight))
	lines.append(",  ".join(facts))
	if e.rank > 0:
		lines.append("Veteran rank %d" % e.rank)
	lines.append(e.def.desc)
	return "\n".join(lines)


func _refresh_queue(b: SimEntity) -> void:
	var sig: String = ""
	if b != null:
		sig = "%d:%s" % [b.id, ",".join(b.queue)]
	if sig != _queue_sig:
		_queue_sig = sig
		for child: Node in _queue_row.get_children():
			_queue_row.remove_child(child)
			child.queue_free()
		if b != null:
			for i: int in b.queue.size():
				var btn: Button = Button.new()
				btn.text = world.data.entity(b.queue[i]).name
				btn.theme_type_variation = "ChipButton"
				btn.tooltip_text = "Click to cancel"
				btn.focus_mode = Control.FOCUS_NONE
				btn.add_theme_font_size_override("font_size", 12)
				btn.pressed.connect(_on_queue_pressed.bind(b.id, i))
				_queue_row.add_child(btn)
	if b != null and not b.queue.is_empty():
		_queue_bar.visible = true
		_queue_bar.value = clampf(b.prod_progress / maxf(world.data.entity(b.queue[0]).build_time, 0.01), 0.0, 1.0)
	else:
		_queue_bar.visible = false


func _on_queue_pressed(building_id: int, index: int) -> void:
	if battle.watching:
		return
	world.push_command(SimCommand.cancel_train(player, building_id, index))
