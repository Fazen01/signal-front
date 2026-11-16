extends TestCase
## Validates every definition in res://data.


func test_data_loads_without_errors() -> void:
	var data: GameData = GameData.new()
	var ok: bool = data.load_all()
	check(ok, "data errors: %s" % str(data.errors))
	check(data.weapons.size() >= 5, "weapons loaded")
	check(data.entities.size() >= 10, "entities loaded")
	check(data.factions.has("aegis"), "aegis faction present")


func test_damage_table_shape() -> void:
	var data: GameData = GameData.shared()
	check_eq(data.damage_table.size(), GameData.DAMAGE_TYPES.size(), "one row per damage type")
	for row: PackedFloat32Array in data.damage_table:
		check_eq(row.size(), data.armor_classes.size(), "one column per armor class")
		for v: float in row:
			check(v >= 0.0 and v <= 3.0, "multiplier in a sane range")


func test_every_unit_can_be_obtained() -> void:
	var data: GameData = GameData.shared()
	for def: EntityDef in data.entities.values():
		if def.is_building:
			if not def.buildable:
				continue
			var has_builder: bool = false
			for other: EntityDef in data.entities.values():
				if other.builds.has(def.id) and other.faction == def.faction:
					has_builder = true
			check(has_builder, "building %s has a builder" % def.id)
		else:
			var has_source: bool = false
			for other: EntityDef in data.entities.values():
				if other.produces.has(def.id) and other.faction == def.faction:
					has_source = true
			check(has_source, "unit %s is produced somewhere" % def.id)


func test_armed_units_have_usable_weapons() -> void:
	var data: GameData = GameData.shared()
	for def: EntityDef in data.entities.values():
		for wd: WeaponDef in def.weapons:
			check(wd.max_range <= def.sight + 6.0, "%s: weapon %s out-ranges sight by too much" % [def.id, wd.id])
			check(wd.damage / wd.cooldown < 200.0, "%s: weapon %s dps sane" % [def.id, wd.id])
