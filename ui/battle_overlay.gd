class_name BattleOverlay
extends Control
## Screen-space drawing over the 3D view: health bars, the selection drag
## box and order cursors. Purely visual; ignores the mouse.

var battle: BattleScene = null


func setup(scene: BattleScene) -> void:
	battle = scene
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if battle == null or battle.world == null:
		return
	var ctl: SelectionController = battle.controller
	var cam3d: Camera3D = battle.cam.cam
	var world: SimWorld = battle.world
	var right: Vector3 = cam3d.global_transform.basis.x
	var view_rect: Rect2 = get_viewport_rect().grow(40.0)
	for e: SimEntity in world.entities:
		if not e.alive or e.def == null:
			continue
		var is_selected: bool = ctl.selected.has(e.id)
		var show_bar: bool = is_selected or e.hp < e.max_hp - 0.5 or not e.constructed
		if not show_bar:
			continue
		var top: Vector3 = Vector3(e.pos.x, world.map.height_at(e.pos) + _bar_height(e), e.pos.y)
		if cam3d.is_position_behind(top):
			continue
		var sp: Vector2 = cam3d.unproject_position(top)
		if not view_rect.has_point(sp):
			continue
		var edge: Vector2 = cam3d.unproject_position(top + right * e.radius)
		var half: float = clampf(sp.distance_to(edge), 12.0, 70.0)
		var bar: Rect2 = Rect2(sp.x - half, sp.y - 3.0, half * 2.0, 5.0)
		draw_rect(bar.grow(1.0), Color(0.0, 0.0, 0.0, 0.75))
		var frac: float = e.hp_fraction()
		var col: Color = Color(0.3, 0.9, 0.35)
		if frac < 0.3:
			col = Color(0.95, 0.25, 0.2)
		elif frac < 0.6:
			col = Color(0.95, 0.8, 0.2)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y)), col)
		if not e.constructed:
			var prog: Rect2 = Rect2(bar.position + Vector2(0.0, 7.0), Vector2(bar.size.x * e.build_progress, 3.0))
			draw_rect(Rect2(bar.position + Vector2(-1.0, 6.0), Vector2(bar.size.x + 2.0, 5.0)), Color(0.0, 0.0, 0.0, 0.75))
			draw_rect(prog, Color(0.4, 0.75, 1.0))
		elif e.kind == SimEntity.Kind.BUILDING and not e.queue.is_empty() and e.owner == battle.local_player:
			var total: float = world.data.entity(e.queue[0]).build_time
			var pf: float = clampf(e.prod_progress / maxf(total, 0.01), 0.0, 1.0)
			draw_rect(Rect2(bar.position + Vector2(-1.0, 6.0), Vector2(bar.size.x + 2.0, 5.0)), Color(0.0, 0.0, 0.0, 0.75))
			draw_rect(Rect2(bar.position + Vector2(0.0, 7.0), Vector2(bar.size.x * pf, 3.0)), Color(1.0, 0.85, 0.3))
	if ctl.dragging and ctl.drag_start.distance_to(ctl.drag_now) >= SelectionController.DRAG_THRESHOLD:
		var box: Rect2 = Rect2(ctl.drag_start, ctl.drag_now - ctl.drag_start).abs()
		draw_rect(box, Color(0.4, 1.0, 0.5, 0.12))
		draw_rect(box, Color(0.4, 1.0, 0.5, 0.9), false, 1.5)
	if ctl.mode == SelectionController.Mode.ATTACK_MOVE:
		var m: Vector2 = get_viewport().get_mouse_position()
		draw_arc(m, 14.0, 0.0, TAU, 24, Color(1.0, 0.35, 0.3), 2.0)
		draw_line(m - Vector2(20.0, 0.0), m + Vector2(20.0, 0.0), Color(1.0, 0.35, 0.3), 2.0)
		draw_line(m - Vector2(0.0, 20.0), m + Vector2(0.0, 20.0), Color(1.0, 0.35, 0.3), 2.0)


func _bar_height(e: SimEntity) -> float:
	if e.kind == SimEntity.Kind.BUILDING:
		return 3.2 + e.radius * 0.9
	return 1.9 if e.def.is_infantry() else 2.1
