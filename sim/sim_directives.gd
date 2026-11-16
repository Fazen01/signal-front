class_name SimDirectives
extends RefCounted
## Commander powers: Command Points, unlocking, cooldowns and effects.

class Timed:
	var tick: int = 0
	var kind: String = ""
	var pos: Vector2 = Vector2.ZERO
	var player: int = -1
	var def: DirectiveDef = null


# ------------------------------------------------------------- queries

## Why this Directive cannot be unlocked, or "".
static func unlock_error(w: SimWorld, player_id: int, def: DirectiveDef) -> String:
	var p: SimPlayer = w.player(player_id)
	if p == null or def == null:
		return "Unknown Directive"
	if p.unlocked.has(def.id):
		return "Already unlocked"
	if p.command_points < def.cost:
		return "Needs %d Command Points" % def.cost
	return ""


## Seconds until the Directive can be used again (0 = ready).
static func cooldown_left(w: SimWorld, player_id: int, def: DirectiveDef) -> float:
	var p: SimPlayer = w.players[player_id]
	var ready: int = p.directive_ready.get(def.id, 0)
	return maxf(0.0, float(ready - w.tick_count) * SimWorld.DT)


## Why the target position is not allowed for this Directive, or "".
static func target_error(w: SimWorld, player_id: int, def: DirectiveDef, pos: Vector2) -> String:
	match def.target:
		"coverage":
			if not SimSignal.is_covered(w, player_id, pos):
				return "Must target your own coverage"
		"near_coverage":
			if SimSignal.distance_outside(w, player_id, pos) > w.data.near_coverage_range:
				return "Too far from your coverage"
		"revealed":
			if not SimVision.is_visible(w, player_id, pos):
				return "Must target an area you can see"
		_:
			pass
	return ""


## Why the Directive cannot be used right now at `pos`, or "".
static func use_error(w: SimWorld, player_id: int, def: DirectiveDef, pos: Vector2) -> String:
	var p: SimPlayer = w.player(player_id)
	if p == null or def == null:
		return "Unknown Directive"
	if not p.unlocked.has(def.id):
		return "Not unlocked"
	if cooldown_left(w, player_id, def) > 0.0:
		return "Not ready yet"
	return target_error(w, player_id, def, pos)


# ------------------------------------------------------------ commands

static func apply_command(w: SimWorld, cmd: SimCommand) -> void:
	var def: DirectiveDef = w.data.directive(cmd.def_id)
	var p: SimPlayer = w.players[cmd.player]
	if cmd.type == SimCommand.Type.UNLOCK:
		if unlock_error(w, cmd.player, def) == "":
			p.command_points -= def.cost
			p.unlocked[def.id] = true
		return
	var why: String = use_error(w, cmd.player, def, cmd.pos)
	if why != "":
		w.alert(cmd.player, why, cmd.pos)
		return
	p.directive_ready[def.id] = w.tick_count + int(def.cooldown * float(SimWorld.TICK_RATE))
	p.stat_directives_used += 1
	var ev: SimEvent = w.emit_event(SimEvent.Type.DIRECTIVE, 0, cmd.player, cmd.pos)
	ev.text = def.id
	ev.value = def.radius
	ev.pos2 = Vector2(def.duration, 0.0)
	_start(w, cmd.player, def, w.map.clamp_to_map(cmd.pos))


static func _start(w: SimWorld, player_id: int, def: DirectiveDef, pos: Vector2) -> void:
	var p: SimPlayer = w.players[player_id]
	var ticks: int = int(def.duration * float(SimWorld.TICK_RATE))
	match def.id:
		"recon_sweep":
			w.add_reveal(pos, def.radius, player_id, w.tick_count + ticks)
			SimVision.recompute(w)
		"shell_barrage":
			for i: int in def.shells:
				var t: Timed = Timed.new()
				t.tick = w.tick_count + SimWorld.TICK_RATE + int(float(i) * float(ticks) / float(maxi(def.shells, 1)))
				t.kind = "shell"
				var ang: float = w.rng.range_f(0.0, TAU)
				t.pos = pos + Vector2.from_angle(ang) * w.rng.range_f(0.0, def.radius - def.splash * 0.5)
				t.player = player_id
				t.def = def
				w.timed.append(t)
		"field_repair":
			for n: SimEntity in w.query_radius(pos, def.radius + SimCombat.BIG_RADIUS):
				if n.owner != player_id or n.def == null or not n.constructed:
					continue
				if n.pos.distance_to(pos) - n.radius > def.radius:
					continue
				n.hp = minf(n.max_hp, n.hp + n.max_hp * def.heal_fraction)
		"signal_surge":
			p.signal_radius_mult = def.radius_mult
			p.surge_until = w.tick_count + ticks
			SimSignal.mark_dirty(w)
		"blackout":
			w.blackouts.append(Vector4(pos.x, pos.y, def.radius, float(player_id)))
			w.blackout_until.append(w.tick_count + ticks)
			SimSignal.mark_dirty(w)
			for other: SimPlayer in w.players:
				if w.are_enemies(player_id, other.id) and SimSignal.is_covered(w, other.id, pos):
					w.alert(other.id, "Enemy Blackout! Signal jammed", pos)
		"reinforcement_drop":
			var t: Timed = Timed.new()
			t.tick = w.tick_count + ticks
			t.kind = "drop"
			t.pos = pos
			t.player = player_id
			t.def = def
			w.timed.append(t)


# ------------------------------------------------------------- per tick

static func update(w: SimWorld) -> void:
	if not w.timed.is_empty():
		var later: Array[Timed] = []
		for t: Timed in w.timed:
			if t.tick > w.tick_count:
				later.append(t)
			elif t.kind == "shell":
				_shell(w, t)
			elif t.kind == "drop":
				_drop(w, t)
		w.timed = later
	if w.tick_count % 5 != 0:
		return
	for p: SimPlayer in w.players:
		if p.surge_until > 0 and w.tick_count >= p.surge_until:
			p.surge_until = 0
			p.signal_radius_mult = 1.0
			SimSignal.mark_dirty(w)
	var i: int = w.blackout_until.size() - 1
	while i >= 0:
		if w.tick_count >= w.blackout_until[i]:
			w.blackouts.remove_at(i)
			w.blackout_until.remove_at(i)
			SimSignal.mark_dirty(w)
		i -= 1
	w.expire_reveals()


static func _shell(w: SimWorld, t: Timed) -> void:
	var ev: SimEvent = w.emit_event(SimEvent.Type.IMPACT, 0, t.player, t.pos)
	ev.text = "barrage"
	ev.value = t.def.splash
	var explosive: int = GameData.DAMAGE_TYPES.find("explosive")
	for n: SimEntity in w.query_radius(t.pos, t.def.splash + SimCombat.BIG_RADIUS):
		if n.def == null or not w.are_enemies(t.player, n.owner) or n.def.is_air():
			continue
		var d: float = t.pos.distance_to(n.pos) - n.radius
		if d > t.def.splash:
			continue
		var falloff: float = 1.0 if d <= 0.0 else lerpf(1.0, 0.4, d / t.def.splash)
		SimCombat.apply_damage(w, n, t.def.damage * falloff, explosive, null, t.player)


static func _drop(w: SimWorld, t: Timed) -> void:
	if w.players[t.player].defeated:
		return
	var n: int = t.def.squad.size()
	for i: int in n:
		var ang: float = float(i) * TAU / float(maxi(n, 1))
		var at: Vector2 = w.map.nearest_free_pos(t.pos + Vector2.from_angle(ang) * 1.6)
		w.spawn_unit(t.def.squad[i], t.player, at, ang)
	var ev: SimEvent = w.emit_event(SimEvent.Type.DIRECTIVE, 0, t.player, t.pos)
	ev.text = "drop_arrived"
	ev.value = t.def.radius
	w.players[t.player].stat_units_built += n


## Destroying enemy value earns Command Points.
static func award(w: SimWorld, player_id: int, value: int) -> void:
	var p: SimPlayer = w.players[player_id]
	p.cp_progress += float(value)
	var per: float = float(w.data.command_point_value)
	while p.cp_progress >= per:
		p.cp_progress -= per
		p.command_points += 1
