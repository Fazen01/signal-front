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

var _salvage: Label = null
var _bandwidth: Label = null
var _clock: Label = null
var _sel_title: Label = null
var _sel_detail: Label = null
var _queue_row: HBoxContainer = null
var _queue_bar: ProgressBar = null
var _info: Label = null
var _card: GridContainer = null
var _buttons: Array[Button] = []
var _entries: Array[CardEntry] = []
var _alerts: VBoxContainer = null
var _alert_age: Array[float] = []
var _refresh_in: float = 0.0
var _queue_sig: String = ""
var minimap_slot: Control = null


func setup(scene: BattleScene) -> void:
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
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.07, 0.09, 0.88)
	sb.border_color = accent
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(8.0)
	return sb


static func make_label(text: String, font_px: int, color: Color) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_px)
	l.add_theme_color_override("font_color", color)
	return l


func _build_top_bar() -> void:
	var bar: PanelContainer = PanelContainer.new()
	bar.name = "TopBar"
	bar.add_theme_stylebox_override("panel", panel_style())
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = 40.0
	add_child(bar)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	bar.add_child(row)
	_salvage = make_label("SALVAGE 0", 18, GOLD)
	row.add_child(_salvage)
	_bandwidth = make_label("BANDWIDTH 0 / 0", 18, CYAN)
	row.add_child(_bandwidth)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	_clock = make_label("0:00", 18, TEXT)
	row.add_child(_clock)
	var menu: Button = Button.new()
	menu.text = "Menu (Esc)"
	menu.focus_mode = Control.FOCUS_NONE
	menu.pressed.connect(func() -> void: battle.toggle_pause_menu())
	row.add_child(menu)


func _build_bottom_bar() -> void:
	var bar: PanelContainer = PanelContainer.new()
	bar.name = "BottomBar"
	bar.add_theme_stylebox_override("panel", panel_style())
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -190.0
	add_child(bar)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	bar.add_child(row)

	minimap_slot = Control.new()
	minimap_slot.name = "MinimapSlot"
	minimap_slot.custom_minimum_size = Vector2(160.0, 160.0)
	row.add_child(minimap_slot)

	var sel: VBoxContainer = VBoxContainer.new()
	sel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sel.add_theme_constant_override("separation", 4)
	row.add_child(sel)
	_sel_title = make_label("", 20, TEXT)
	sel.add_child(_sel_title)
	_sel_detail = make_label("", 14, DIM)
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
	_info = make_label("", 13, GOLD)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_info.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	sel.add_child(_info)

	_card = GridContainer.new()
	_card.columns = CARD_COLUMNS
	_card.add_theme_constant_override("h_separation", 4)
	_card.add_theme_constant_override("v_separation", 4)
	row.add_child(_card)
	for i: int in CARD_SLOTS:
		var b: Button = Button.new()
		b.custom_minimum_size = Vector2(118.0, 50.0)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 13)
		b.clip_text = true
		b.pressed.connect(_on_card_pressed.bind(i))
		b.mouse_entered.connect(_on_card_hover.bind(i))
		b.mouse_exited.connect(_on_card_hover.bind(-1))
		_card.add_child(b)
		_buttons.append(b)


func _build_alerts() -> void:
	_alerts = VBoxContainer.new()
	_alerts.name = "Alerts"
	_alerts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_alerts.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_alerts.offset_left = 14.0
	_alerts.offset_top = 52.0
	add_child(_alerts)


# ----------------------------------------------------------------- alerts

func push_alert(text: String, color: Color = TEXT) -> void:
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
			_add_entry("train", def, "", def.hotkey, def.name, "%s\nCost %d   Bandwidth %d   %s" % [def.name, def.cost, def.bandwidth, def.desc])
		if any_unfinished:
			_add_entry("cancel", null, "", "X", "Cancel", "Cancel construction for a full refund.")
	for i: int in CARD_SLOTS:
		var b: Button = _buttons[i]
		if i < _entries.size():
			var entry: CardEntry = _entries[i]
			b.visible = true
			if entry.def != null:
				b.text = "[%s] %s\n%d" % [entry.hotkey, entry.title, entry.def.cost]
			else:
				b.text = "[%s] %s" % [entry.hotkey, entry.title]
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
		_buttons[i].disabled = _entry_blocked(_entries[i]) != ""


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
	if index >= 0 and index < _entries.size():
		activate(_entries[index])


## Runs a card entry. Returns false when it is not available right now.
func activate(entry: CardEntry) -> bool:
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
				world.push_command(SimCommand.train(player, producer.id, entry.def.id))
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
			activate(entry)
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
	_salvage.text = "SALVAGE  %d" % p.salvage
	_bandwidth.text = "BANDWIDTH  %d / %d" % [p.bandwidth_used, p.bandwidth_cap]
	_bandwidth.add_theme_color_override("font_color", RED if p.bandwidth_used >= p.bandwidth_cap else CYAN)
	var secs: int = int(world.seconds())
	_clock.text = "%d:%02d" % [secs / 60, secs % 60]
	_update_card_state()
	_refresh_selection()


func _refresh_selection() -> void:
	var sel: Array[SimEntity] = battle.controller.selected_entities()
	var queue_owner: SimEntity = null
	if sel.is_empty():
		_sel_title.text = ""
		_sel_detail.text = "Left-drag to select. Right-click to order. Select a Field Engineer to build."
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
			return "Neutral uplink. Pays salvage to whoever covers it with signal."
		return "Salvage remaining: %d. Send a Hauler to collect it." % e.salvage
	var lines: Array[String] = []
	lines.append("Health %d / %d" % [int(ceilf(e.hp)), int(e.max_hp)])
	if e.owner >= 0 and e.owner != player:
		lines[0] += "   (%s)" % world.players[e.owner].name
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
	world.push_command(SimCommand.cancel_train(player, building_id, index))
