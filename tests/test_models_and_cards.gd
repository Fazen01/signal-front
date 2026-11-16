extends TestCase
## Every definition has a model that actually builds, and no command card
## offers two things on the same key.


func test_every_model_builds() -> void:
	var data: GameData = GameData.shared()
	var count: int = 0
	for def: EntityDef in data.entities.values():
		var model: Node3D = ModelFactory.build(def.model, MatchConfig.TEAM_COLORS[count % MatchConfig.TEAM_COLORS.size()])
		count += 1
		var body: MeshInstance3D = model.get_node_or_null("Body") as MeshInstance3D
		check(body != null and body.mesh != null, "%s: the model has a body" % def.id)
		if body != null and body.mesh != null:
			var box: AABB = body.mesh.get_aabb()
			check(box.size.x > 0.2 and box.size.y > 0.1 and box.size.z > 0.2, "%s: the body has a size (%s)" % [def.id, str(box.size)])
			# A model is roughly as big as the thing it stands for. Aircraft and
			# masts may stick out; nothing should be several times too large.
			var reach: float = maxf(box.size.x, box.size.z) * 0.5
			check(reach < def.radius * 3.2 + 1.2, "%s: the model (reach %.1f) fits its radius %.1f" % [def.id, reach, def.radius])
			check(box.position.y > -1.0, "%s: the model does not hang far below the ground (%.1f)" % [def.id, box.position.y])
		if def.turret and not def.is_building and def.is_vehicle():
			check(model.get_node_or_null("Turret") != null, "%s: a turreted vehicle has a turret to turn" % def.id)
		if def.harvester:
			check(model.get_node_or_null("Cargo") != null, "%s: a hauler shows its load" % def.id)
		model.free()
		if not def.is_building and def.is_vehicle():
			var wreck: Node3D = ModelFactory.build_wreck(def.model, count)
			check(wreck.get_node_or_null("Body") != null, "%s: its wreck builds" % def.id)
			wreck.free()
	check(count >= 100, "every definition was tried (%d)" % count)


func test_no_command_card_repeats_a_key() -> void:
	var data: GameData = GameData.shared()
	var taken_by_orders: Array[String] = ["A", "S", "H"]
	for def: EntityDef in data.entities.values():
		var offered: Array[String] = []
		offered.append_array(def.produces)
		offered.append_array(def.builds)
		if offered.is_empty():
			continue
		var keys: Dictionary[String, String] = {}
		for id: String in offered:
			var item: EntityDef = data.entity(id)
			check(item.hotkey != "", "%s offers %s, which has a hotkey" % [def.id, id])
			check(not keys.has(item.hotkey), "%s: %s and %s do not share the key %s" % [def.id, id, keys.get(item.hotkey, ""), item.hotkey])
			keys[item.hotkey] = id
			if not def.is_building:
				# A builder's card also carries Attack-move, Stop and Hold.
				check(not taken_by_orders.has(item.hotkey), "%s: %s does not take the order key %s" % [def.id, id, item.hotkey])
		if def.deploys_to != "" or def.packs_to != "":
			check(not keys.has("Y"), "%s: nothing it offers takes Y, the deploy key" % def.id)


func test_every_faction_can_reach_every_tier() -> void:
	var data: GameData = GameData.shared()
	for f: FactionDef in data.factions.values():
		# Starting from the headquarters and the start units, everything the
		# faction owns must be reachable by building and training.
		var have: Dictionary[String, bool] = {f.hq: true}
		for id: String in f.start_units:
			have[id] = true
		var grew: bool = true
		while grew:
			grew = false
			for id: String in have.keys():
				var def: EntityDef = data.entity(id)
				var next: Array[String] = []
				next.append_array(def.produces)
				next.append_array(def.builds)
				if def.deploys_to != "":
					next.append(def.deploys_to)
				if def.packs_to != "":
					next.append(def.packs_to)
				for n: String in next:
					if have.has(n):
						continue
					var ok: bool = true
					for need: String in data.entity(n).requires:
						if not have.has(need):
							ok = false
					if ok:
						have[n] = true
						grew = true
		for def: EntityDef in data.entities.values():
			if def.faction == f.id:
				check(have.has(def.id), "%s can get to %s" % [f.name, def.name])
