class_name SimMovement
extends RefCounted
## Path following, turning and unit-unit separation.

const MAX_PUSH: float = 0.3  ## separation displacement cap per tick


static func start_move(w: SimWorld, e: SimEntity, goal: Vector2) -> void:
	var path: PackedVector2Array
	if e.def.is_air():
		path = PackedVector2Array([w.map.clamp_to_map(goal)])
	else:
		path = w.map.find_path(e.pos, goal, e.def.is_vehicle())
	if path.is_empty():
		stop(e)
		return
	e.path = path
	e.path_index = 0
	e.move_goal = path[path.size() - 1]
	e.moving = true
	e.stuck_ticks = 0
	e.last_progress = INF


static func stop(e: SimEntity) -> void:
	e.moving = false
	e.path = PackedVector2Array()
	e.path_index = 0


static func update(w: SimWorld) -> void:
	var n: int = w.entities.size()
	for i: int in n:
		var e: SimEntity = w.entities[i]
		if e.alive and e.kind == SimEntity.Kind.UNIT and e.moving:
			_advance(w, e)
	for i: int in n:
		var e: SimEntity = w.entities[i]
		if e.alive and e.kind == SimEntity.Kind.UNIT:
			# Units standing still only need pushing apart every other tick.
			if e.moving or (w.tick_count + e.id) % 2 == 0:
				_separate(w, e)


static func _advance(w: SimWorld, e: SimEntity) -> void:
	var target: Vector2 = e.path[e.path_index]
	var to: Vector2 = target - e.pos
	var dist: float = to.length()
	var speed: float = e.def.speed
	if e.linked and e.owner >= 0:
		speed *= 1.0 + w.players[e.owner].faction.linked_speed_bonus
	if w.tick_count < e.slow_until:
		speed *= 1.0 - e.slow_amount
	if e.def.is_vehicle() and w.map.terrain_at(e.pos) == SimMap.Terrain.FOREST:
		speed *= w.data.forest_vehicle_speed_mult
	var step: float = speed * SimWorld.DT

	if dist <= maxf(step, 0.05):
		if e.path_index >= e.path.size() - 1:
			if e.def.is_air() or w.map.is_passable(target):
				e.pos = target
			stop(e)
			return
		e.path_index += 1
		target = e.path[e.path_index]
		to = target - e.pos
		dist = to.length()
		if dist < 0.0001:
			return

	var dir: Vector2 = to / dist
	var want: float = dir.angle()
	var diff: float = angle_difference(e.facing, want)
	e.facing = rotate_toward(e.facing, want, e.def.turn_rate * SimWorld.DT)
	if not e.def.turret:
		e.aim = e.facing
	var factor: float = 1.0
	if e.def.is_vehicle():
		# Vehicles slow down through turns and pivot in place for sharp ones.
		factor = 0.0 if absf(diff) > 1.1 else clampf(cos(diff), 0.25, 1.0)
	var new_pos: Vector2 = e.pos + dir * minf(step * factor, dist)
	if e.def.is_air() or w.map.is_passable(new_pos):
		e.pos = new_pos
	else:
		# Something now blocks the path (a new building, or we were pushed).
		e.stuck_ticks += 4
		if w.tick_count >= e.repath_tick:
			e.repath_tick = w.tick_count + 10
			var goal: Vector2 = e.move_goal
			var stuck: int = e.stuck_ticks
			start_move(w, e, goal)
			e.stuck_ticks = stuck
			if not e.moving:
				return

	# Stuck detection on path progress.
	var progress: float = float(e.path.size() - e.path_index) * 1000.0 + e.pos.distance_to(e.path[e.path_index])
	if progress < e.last_progress - 0.01:
		e.last_progress = progress
		e.stuck_ticks = 0
	else:
		e.stuck_ticks += 1
	if e.stuck_ticks > 14 and e.pos.distance_to(e.move_goal) < 3.5:
		stop(e)  # crowded destination: close enough
	elif e.stuck_ticks > 60:
		stop(e)


static func _separate(w: SimWorld, e: SimEntity) -> void:
	var push: Vector2 = Vector2.ZERO
	var air: bool = e.def.is_air()
	var bx: int = int(e.pos.x / SimWorld.BUCKET)
	var by: int = int(e.pos.y / SimWorld.BUCKET)
	for oy: int in range(by - 1, by + 2):
		if oy < 0 or oy >= w.bucket_h:
			continue
		for ox: int in range(bx - 1, bx + 2):
			if ox < 0 or ox >= w.bucket_w:
				continue
			var bucket: Array = w.buckets[oy * w.bucket_w + ox]
			for n: SimEntity in bucket:
				# Aircraft only crowd other aircraft; ground units only each other.
				if n == e or not n.alive or n.kind != SimEntity.Kind.UNIT or n.def.is_air() != air:
					continue
				var d: Vector2 = e.pos - n.pos
				var min_d: float = e.radius + n.radius
				var d2: float = d.length_squared()
				if d2 >= min_d * min_d:
					continue
				var dist: float = sqrt(d2)
				var away: Vector2
				if dist < 0.001:
					away = Vector2.from_angle(float((e.id * 97) % 360) * PI / 180.0)
				else:
					away = d / dist
				# Bigger units shove smaller ones more than the reverse.
				var share: float = n.radius / min_d
				# A unit that is standing still yields to one that is moving.
				if e.moving and not n.moving:
					share *= 0.5
				elif n.moving and not e.moving:
					share = minf(1.0, share * 1.5)
				push += away * (min_d - dist) * share
	if push == Vector2.ZERO:
		return
	var moved: Vector2 = e.pos + push.limit_length(MAX_PUSH)
	if air:
		e.pos = w.map.clamp_to_map(moved)
	elif w.map.is_passable(moved):
		e.pos = moved
	else:
		# Slide along whichever axis is free.
		var slide_x: Vector2 = Vector2(moved.x, e.pos.y)
		var slide_y: Vector2 = Vector2(e.pos.x, moved.y)
		if w.map.is_passable(slide_x):
			e.pos = slide_x
		elif w.map.is_passable(slide_y):
			e.pos = slide_y
