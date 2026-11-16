class_name SimCombat
extends RefCounted
## Target acquisition, weapons fire, projectiles, damage and death.

const TURRET_RATE: float = 4.5  ## radians per second
const SCAN_INTERVAL: int = 5  ## ticks between target scans
const BIG_RADIUS: float = 4.5  ## padding so large buildings are found by centre queries


static func update(w: SimWorld) -> void:
	var n: int = w.entities.size()
	for i: int in n:
		var e: SimEntity = w.entities[i]
		if not e.alive or e.def == null or e.def.weapons.is_empty():
			continue
		if e.kind == SimEntity.Kind.BUILDING and not e.constructed:
			continue
		_update_combatant(w, e)
	_update_projectiles(w)


# ------------------------------------------------------------- modifiers

## Weapon range multiplier for this entity right now.
static func range_mult(w: SimWorld, e: SimEntity) -> float:
	if e.owner >= 0 and e.linked:
		return 1.0 + w.players[e.owner].faction.linked_range_bonus
	return 1.0


## Rate-of-fire multiplier for this entity right now (1 = normal).
static func rof_mult(w: SimWorld, e: SimEntity) -> float:
	if e.linked or e.owner < 0:
		return 1.0
	if e.kind == SimEntity.Kind.BUILDING:
		return w.data.dark_turret_rof_mult
	var f: FactionDef = w.players[e.owner].faction
	return f.dark_rof_mult if f.dark_rof_mult > 0.0 else w.data.dark_rof_mult


static func sight_range(w: SimWorld, e: SimEntity) -> float:
	if e.linked:
		return e.def.sight
	return e.def.sight * w.data.dark_sight_mult


static func can_hit(wd: WeaponDef, t: SimEntity) -> bool:
	if t.def == null:
		return false
	if t.def.is_air():
		return wd.hits_air
	return wd.hits_ground


## Best damage multiplier any of e's weapons has against t (0 = cannot hurt it).
static func best_multiplier(w: SimWorld, e: SimEntity, t: SimEntity) -> float:
	var best: float = 0.0
	if t.def == null:
		return best
	for wd: WeaponDef in e.def.weapons:
		if can_hit(wd, t):
			best = maxf(best, w.data.damage_multiplier(wd.damage_type, t.def.armor))
	return best


## Longest effective range among e's weapons that can hurt t.
static func reach_against(w: SimWorld, e: SimEntity, t: SimEntity) -> float:
	var best: float = 0.0
	for wd: WeaponDef in e.def.weapons:
		if can_hit(wd, t) and w.data.damage_multiplier(wd.damage_type, t.def.armor) > 0.0:
			best = maxf(best, wd.max_range)
	return best * range_mult(w, e)


## Smallest minimum range among e's weapons that can hit t.
static func _shortest_min_range(e: SimEntity, t: SimEntity) -> float:
	var best: float = INF
	for wd: WeaponDef in e.def.weapons:
		if can_hit(wd, t):
			best = minf(best, wd.min_range)
	return 0.0 if best == INF else best


# --------------------------------------------------------------- per unit

static func _update_combatant(w: SimWorld, e: SimEntity) -> void:
	for i: int in e.cooldowns.size():
		if e.cooldowns[i] > 0:
			e.cooldowns[i] -= 1
	# Top-rank veterans slowly repair themselves when left alone.
	if e.rank >= w.data.rank_thresholds.size() and e.hp < e.max_hp and w.tick_count - e.last_hit_tick > 100:
		e.hp = minf(e.max_hp, e.hp + e.max_hp * w.data.rank_self_repair * SimWorld.DT)

	if w.tick_count >= e.scan_tick:
		e.scan_tick = w.tick_count + SCAN_INTERVAL
		var o: SimOrder = e.current_order()
		var forced: bool = o != null and o.type == SimOrder.Type.ATTACK
		if not forced:
			e.target_id = _acquire(w, e)

	var t: SimEntity = w.get_entity(e.target_id)
	if t == null:
		e.target_id = 0
		if e.def.turret and e.kind == SimEntity.Kind.UNIT:
			e.aim = rotate_toward(e.aim, e.facing, 2.5 * SimWorld.DT)
		return

	var to: Vector2 = t.pos - e.pos
	var dist: float = to.length() - t.radius
	var want: float = to.angle()
	var aimed: bool = false
	if e.def.turret:
		e.aim = rotate_toward(e.aim, want, TURRET_RATE * SimWorld.DT)
		aimed = absf(angle_difference(e.aim, want)) < 0.12
	elif not e.moving:
		e.facing = rotate_toward(e.facing, want, e.def.turn_rate * SimWorld.DT)
		e.aim = e.facing
		aimed = absf(angle_difference(e.facing, want)) < 0.3
	if not aimed:
		return

	var r_mult: float = range_mult(w, e)
	for i: int in e.def.weapons.size():
		if e.cooldowns[i] > 0:
			continue
		var wd: WeaponDef = e.def.weapons[i]
		if not can_hit(wd, t):
			continue
		if dist > wd.max_range * r_mult or dist < wd.min_range:
			continue
		_fire(w, e, t, wd, i)
		if not t.alive:
			break


static func _acquire(w: SimWorld, e: SimEntity) -> int:
	var reach: float = e.def.max_weapon_range() * range_mult(w, e)
	var radius: float = reach
	if e.kind == SimEntity.Kind.UNIT and not e.hold:
		var o: SimOrder = e.current_order()
		# Units on a plain move order only shoot what is already in range.
		if o == null or o.type != SimOrder.Type.MOVE:
			radius = maxf(reach, sight_range(w, e))
	var best_id: int = 0
	var best_score: float = INF
	for n: SimEntity in w.query_radius(e.pos, radius + BIG_RADIUS):
		if n.def == null or not w.are_enemies(e.owner, n.owner):
			continue
		var d: float = e.pos.distance_to(n.pos) - n.radius
		if d > radius:
			continue
		if not SimVision.can_see(w, e.owner, n):
			continue
		var mult: float = best_multiplier(w, e, n)
		if mult <= 0.01:
			continue
		if d < _shortest_min_range(e, n):
			continue  # too close for anything we carry
		var score: float = (maxf(d, 0.0) + 2.0) / mult
		if not n.def.is_armed():
			score *= 1.6
		if n.id == e.target_id:
			score *= 0.75
		if score < best_score:
			best_score = score
			best_id = n.id
	return best_id


static func _fire(w: SimWorld, e: SimEntity, t: SimEntity, wd: WeaponDef, slot: int) -> void:
	var ticks: float = wd.cooldown * float(SimWorld.TICK_RATE) / rof_mult(w, e)
	e.cooldowns[slot] = maxi(1, int(roundf(ticks)))
	e.last_fire_tick = w.tick_count
	var damage: float = wd.damage * (1.0 + w.data.rank_damage_bonus * float(e.rank))
	if wd.projectile_speed <= 0.0:
		var ev: SimEvent = w.emit_event(SimEvent.Type.SHOT, e.id, e.owner, e.pos)
		ev.other_id = t.id
		ev.pos2 = t.pos
		ev.text = wd.fx
		apply_damage(w, t, damage, wd.damage_type, e, e.owner)
		return
	var p: SimProjectile = SimProjectile.new()
	p.id = w.next_id
	w.next_id += 1
	p.weapon = wd
	p.owner = e.owner
	p.source_id = e.id
	p.target_id = t.id
	p.pos = e.pos + Vector2.from_angle(e.aim) * minf(e.radius, 1.2)
	p.prev_pos = p.pos
	p.start_pos = p.pos
	p.target_pos = t.pos
	if wd.scatter > 0.0:
		var ang: float = w.rng.range_f(0.0, TAU)
		p.target_pos += Vector2.from_angle(ang) * w.rng.range_f(0.0, wd.scatter)
	p.damage = damage
	w.projectiles.append(p)
	var pe: SimEvent = w.emit_event(SimEvent.Type.PROJECTILE, e.id, e.owner, p.pos)
	pe.other_id = p.id
	pe.pos2 = p.target_pos
	pe.text = wd.fx


# ------------------------------------------------------------ projectiles

static func _update_projectiles(w: SimWorld) -> void:
	if w.projectiles.is_empty():
		return
	var any_dead: bool = false
	for p: SimProjectile in w.projectiles:
		p.prev_pos = p.pos
		if p.weapon.homing:
			var t: SimEntity = w.get_entity(p.target_id)
			if t != null:
				p.target_pos = t.pos
		var to: Vector2 = p.target_pos - p.pos
		var d: float = to.length()
		var step: float = p.weapon.projectile_speed * SimWorld.DT
		if d <= step:
			p.pos = p.target_pos
			_impact(w, p)
			p.alive = false
			any_dead = true
		else:
			p.pos += to / d * step
	if any_dead:
		var kept: Array[SimProjectile] = []
		for p: SimProjectile in w.projectiles:
			if p.alive:
				kept.append(p)
		w.projectiles = kept


static func _impact(w: SimWorld, p: SimProjectile) -> void:
	var ev: SimEvent = w.emit_event(SimEvent.Type.IMPACT, p.id, p.owner, p.pos)
	ev.text = p.weapon.fx
	ev.value = p.weapon.splash
	var src: SimEntity = w.get_entity(p.source_id)
	if p.weapon.splash > 0.0:
		for n: SimEntity in w.query_radius(p.pos, p.weapon.splash + BIG_RADIUS):
			if n.def == null or not w.are_enemies(p.owner, n.owner) or not can_hit(p.weapon, n):
				continue
			var d: float = p.pos.distance_to(n.pos) - n.radius
			if d > p.weapon.splash:
				continue
			var falloff: float = 1.0 if d <= 0.0 else lerpf(1.0, 0.4, d / p.weapon.splash)
			apply_damage(w, n, p.damage * falloff, p.weapon.damage_type, src, p.owner)
	else:
		var t: SimEntity = w.get_entity(p.target_id)
		if t != null and (p.weapon.homing or p.pos.distance_to(t.pos) <= t.radius + 0.75):
			apply_damage(w, t, p.damage, p.weapon.damage_type, src, p.owner)


# ------------------------------------------------------- damage and death

static func apply_damage(w: SimWorld, t: SimEntity, amount: float, damage_type: int, attacker: SimEntity, attacker_owner: int) -> void:
	if not t.alive or t.def == null:
		return
	var mult: float = w.data.damage_multiplier(damage_type, t.def.armor)
	if t.def.is_infantry() and w.map.terrain_at(t.pos) == SimMap.Terrain.FOREST:
		mult *= w.data.forest_infantry_damage_mult
	var dmg: float = amount * mult
	if dmg <= 0.0:
		return
	t.hp -= dmg
	t.last_hit_tick = w.tick_count
	t.last_attacker = attacker.id if attacker != null else 0
	if t.owner >= 0 and (t.kind == SimEntity.Kind.BUILDING or t.def.harvester):
		var victim: SimPlayer = w.players[t.owner]
		if w.tick_count - victim.last_attack_alert > 300:
			victim.last_attack_alert = w.tick_count
			w.alert(t.owner, "%s under attack" % t.def.name, t.pos)
	if t.hp <= 0.0:
		kill(w, t, attacker, attacker_owner)


## Veterancy: ranks are earned by destroying value worth multiples of the
## unit's own cost. Each rank adds damage and health; the top rank self-repairs.
static func _check_rank(w: SimWorld, e: SimEntity) -> void:
	var base: float = maxf(float(e.def.cost), 100.0)
	while e.rank < w.data.rank_thresholds.size() and e.xp >= base * w.data.rank_thresholds[e.rank]:
		e.rank += 1
		var old_max: float = e.max_hp
		e.max_hp = e.def.hp * (1.0 + w.data.rank_health_bonus * float(e.rank))
		e.hp += e.max_hp - old_max
		var ev: SimEvent = w.emit_event(SimEvent.Type.RANK_UP, e.id, e.owner, e.pos)
		ev.value = float(e.rank)


static func kill(w: SimWorld, t: SimEntity, killer: SimEntity, killer_owner: int) -> void:
	if not t.alive:
		return
	t.hp = 0.0
	var ev: SimEvent = w.emit_event(SimEvent.Type.DIED, t.id, t.owner, t.pos)
	ev.other_id = killer.id if killer != null else 0
	ev.value = t.radius
	ev.text = t.def.model if t.def != null else ""
	w.remove_entity(t)
	if t.def == null:
		return
	var value: int = t.def.cost
	if t.owner >= 0:
		var owner: SimPlayer = w.players[t.owner]
		if t.kind == SimEntity.Kind.UNIT:
			owner.bandwidth_used -= t.def.bandwidth
			owner.stat_units_lost += 1
		else:
			owner.stat_buildings_lost += 1
	if t.kind == SimEntity.Kind.BUILDING:
		value = int(float(value) * t.build_progress)
		w.on_building_removed(t)
	if killer_owner >= 0 and w.are_enemies(killer_owner, t.owner):
		var kp: SimPlayer = w.players[killer_owner]
		kp.stat_kills += 1
		kp.stat_value_destroyed += value
		SimDirectives.award(w, killer_owner, value)
		if killer != null and killer.alive:
			killer.kills += 1
			killer.xp += float(value)
			_check_rank(w, killer)
	# Vehicles and buildings leave salvageable wrecks; infantry do not.
	if (t.kind == SimEntity.Kind.BUILDING and not t.def.is_mine()) or t.def.is_vehicle():
		var amount: int = int(float(value) * w.data.wreck_fraction)
		if amount > 0:
			w.spawn_wreck(t.pos, amount, maxf(0.8, t.radius * 0.8), t.def.model, t.facing)
