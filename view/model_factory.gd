class_name ModelFactory
extends RefCounted
## Builds every unit, building and prop model from primitive meshes. Models
## face +X, stand on y = 0 and are centred on the origin. Each model is
## assembled once from boxes, cylinders and the like, then baked by
## ModelBaker into one merged mesh plus one per moving group, and the baked
## result is reused for every later copy.
##
## Moving groups are named child nodes the view animates: "Turret" follows the
## weapon aim, "Rotor*" spin fast, "Spin*" turn slowly (radar, dishes) and
## "Cargo" is shown while a hauler is carrying salvage.

const HULL: Color = Color(0.40, 0.45, 0.47)
const HULL_DARK: Color = Color(0.24, 0.27, 0.29)
const METAL: Color = Color(0.58, 0.60, 0.63)
const GUNMETAL: Color = Color(0.16, 0.17, 0.19)
const RUBBER: Color = Color(0.07, 0.07, 0.08)
const GLASS: Color = Color(0.30, 0.55, 0.70)
const UNIFORM: Color = Color(0.33, 0.37, 0.30)
const UNIFORM_DARK: Color = Color(0.20, 0.23, 0.20)
const CONCRETE: Color = Color(0.60, 0.60, 0.57)
const CONCRETE_DARK: Color = Color(0.36, 0.37, 0.37)
const HAZARD: Color = Color(0.92, 0.72, 0.10)
const RUST: Color = Color(0.46, 0.30, 0.20)
const CHARRED: Color = Color(0.10, 0.09, 0.08)
# Foundry Pact palette: iron, soot, rust and furnace glow.
const IRON: Color = Color(0.33, 0.30, 0.28)
const IRON_DARK: Color = Color(0.18, 0.17, 0.16)
const BRASS: Color = Color(0.70, 0.52, 0.22)
const FURNACE: Color = Color(1.0, 0.45, 0.10)
const DRAB: Color = Color(0.40, 0.33, 0.25)
const DRAB_DARK: Color = Color(0.24, 0.20, 0.16)
# Nomad Circuit palette: sand, canvas and patched metal.
const SAND: Color = Color(0.70, 0.60, 0.42)
const SAND_DARK: Color = Color(0.44, 0.37, 0.26)
const CANVAS: Color = Color(0.82, 0.76, 0.62)
const PATCH: Color = Color(0.20, 0.50, 0.50)
const SKIN: Color = Color(0.76, 0.58, 0.45)
const LAMP: Color = Color(1.0, 0.93, 0.72)
const LAMP_RED: Color = Color(1.0, 0.25, 0.18)
const WINDOW: Color = Color(0.62, 0.86, 1.0)
const WINDOW_WARM: Color = Color(1.0, 0.72, 0.34)

static var _materials: Dictionary[String, StandardMaterial3D] = {}
static var _meshes: Dictionary[String, Mesh] = {}
static var _baked: Dictionary[String, ModelBaker.Part] = {}


# ------------------------------------------------------------ primitives

static func mat(color: Color, emission: float = 0.0, metallic: float = 0.0, roughness: float = 0.85) -> StandardMaterial3D:
	var key: String = "%s|%.2f|%.2f|%.2f" % [color.to_html(), emission, metallic, roughness]
	if _materials.has(key):
		return _materials[key]
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	_materials[key] = m
	return m


static func team_mat(team: Color) -> StandardMaterial3D:
	return mat(team, 0.3, 0.1, 0.6)


static func _place(parent: Node3D, mesh: Mesh, pos: Vector3, m: Material, rot: Vector3) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func box(parent: Node3D, size: Vector3, pos: Vector3, m: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var key: String = "box|%s" % str(size)
	if not _meshes.has(key):
		var b: BoxMesh = BoxMesh.new()
		b.size = size
		_meshes[key] = b
	return _place(parent, _meshes[key], pos, m, rot)


## Cylinder along Y unless rotated. `sides` keeps the low-poly look.
static func cyl(parent: Node3D, top: float, bottom: float, height: float, pos: Vector3, m: Material, sides: int = 8, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var key: String = "cyl|%.3f|%.3f|%.3f|%d" % [top, bottom, height, sides]
	if not _meshes.has(key):
		var c: CylinderMesh = CylinderMesh.new()
		c.top_radius = top
		c.bottom_radius = bottom
		c.height = height
		c.radial_segments = sides
		c.rings = 1
		_meshes[key] = c
	return _place(parent, _meshes[key], pos, m, rot)


## A barrel or tube pointing along +X, starting at `pos`.
static func barrel(parent: Node3D, radius: float, length: float, pos: Vector3, m: Material) -> MeshInstance3D:
	return cyl(parent, radius, radius, length, pos + Vector3(length * 0.5, 0.0, 0.0), m, 6, Vector3(0.0, 0.0, -PI * 0.5))


## A wheel with its axle along Z.
static func wheel(parent: Node3D, radius: float, width: float, pos: Vector3) -> MeshInstance3D:
	var turn: Vector3 = Vector3(PI * 0.5, 0.0, 0.0)
	cyl(parent, radius * 0.56, radius * 0.56, width + 0.05, pos, mat(HULL_DARK, 0.0, 0.5, 0.5), 8, turn)
	cyl(parent, radius * 0.2, radius * 0.2, width + 0.1, pos, mat(METAL, 0.0, 0.7, 0.4), 6, turn)
	return cyl(parent, radius, radius, width, pos, mat(RUBBER), 10, turn)


## A named child the view animates; it survives baking as its own node.
static func group(parent: Node3D, node_name: String, pos: Vector3) -> Node3D:
	var g: Node3D = Node3D.new()
	g.name = node_name
	g.position = pos
	ModelBaker.keep(g)
	parent.add_child(g)
	return g


## One caterpillar track along X: rounded ends, a row of road wheels and a
## lighter top run.
static func track(parent: Node3D, length: float, z: float, height: float = 0.55, width: float = 0.45) -> void:
	var r: float = height * 0.5
	var turn: Vector3 = Vector3(PI * 0.5, 0.0, 0.0)
	box(parent, Vector3(length - height, height, width), Vector3(0.0, r, z), mat(RUBBER))
	cyl(parent, r, r, width, Vector3(length * 0.5 - r, r, z), mat(RUBBER), 10, turn)
	cyl(parent, r, r, width, Vector3(-length * 0.5 + r, r, z), mat(RUBBER), 10, turn)
	var count: int = maxi(3, int(round((length - height) / 0.5)) + 1)
	var out: float = 0.03 if z > 0.0 else -0.03
	for i: int in count:
		var x: float = lerpf(-length * 0.5 + r, length * 0.5 - r, float(i) / float(count - 1))
		cyl(parent, r * 0.62, r * 0.62, width, Vector3(x, r * 0.86, z + out), mat(GUNMETAL, 0.0, 0.5, 0.5), 8, turn)
		cyl(parent, r * 0.22, r * 0.22, width, Vector3(x, r * 0.86, z + out * 2.0), mat(METAL, 0.0, 0.7, 0.4), 6, turn)


## A small glowing lamp.
static func lamp(parent: Node3D, pos: Vector3, color: Color = LAMP, size: float = 0.12) -> void:
	box(parent, Vector3(size, size, size), pos, mat(color, 1.6))


## A row of lit windows. `step` is the offset from one pane to the next.
static func windows(parent: Node3D, first: Vector3, step: Vector3, count: int, size: Vector3, color: Color = WINDOW) -> void:
	for i: int in count:
		box(parent, size, first + step * float(i), mat(color, 0.6, 0.2, 0.3))


## A whip aerial with a tiny light on top.
static func aerial(parent: Node3D, pos: Vector3, height: float, tip: Color = LAMP_RED) -> void:
	cyl(parent, 0.012, 0.022, height, pos + Vector3(0.0, height * 0.5, 0.0), mat(GUNMETAL), 4)
	box(parent, Vector3(0.05, 0.05, 0.05), pos + Vector3(0.0, height, 0.0), mat(tip, 1.8))


## A round hatch lying flat.
static func hatch(parent: Node3D, pos: Vector3, radius: float, color: Color = HULL_DARK) -> void:
	cyl(parent, radius, radius, 0.06, pos, mat(color), 8)
	box(parent, Vector3(radius * 0.9, 0.05, 0.05), pos + Vector3(0.0, 0.04, 0.0), mat(GUNMETAL))


## A slowly turning radar: a post with a tilted dish, in a "Spin" group.
static func radar(parent: Node3D, pos: Vector3, span: float, node_name: String = "Spin", dish: Color = METAL) -> void:
	cyl(parent, span * 0.07, span * 0.09, span * 0.5, pos + Vector3(0.0, span * 0.25, 0.0), mat(GUNMETAL), 5)
	var g: Node3D = group(parent, node_name, pos + Vector3(0.0, span * 0.5, 0.0))
	box(g, Vector3(span * 0.12, span * 0.42, span), Vector3(0.0, span * 0.22, 0.0), mat(dish, 0.0, 0.6, 0.4), Vector3(0.0, 0.0, 0.25))
	box(g, Vector3(span * 0.3, span * 0.06, span * 0.06), Vector3(span * 0.18, span * 0.2, 0.0), mat(GUNMETAL))
	box(g, Vector3(span * 0.08, span * 0.08, span * 0.08), Vector3(span * 0.34, span * 0.2, 0.0), mat(LAMP_RED, 1.6))


static func ball(parent: Node3D, radius: float, pos: Vector3, m: Material, segments: int = 8) -> MeshInstance3D:
	var key: String = "ball|%.3f|%d" % [radius, segments]
	if not _meshes.has(key):
		var s: SphereMesh = SphereMesh.new()
		s.radius = radius
		s.height = radius * 2.0
		s.radial_segments = segments
		s.rings = maxi(3, segments / 2)
		_meshes[key] = s
	return _place(parent, _meshes[key], pos, m, Vector3.ZERO)


## Wedge with its triangular profile in the XY plane. apex 0 = high at -X,
## 1 = high at +X, 0.5 = gable.
static func wedge(parent: Node3D, size: Vector3, pos: Vector3, m: Material, apex: float = 0.0, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var key: String = "wedge|%s|%.2f" % [str(size), apex]
	if not _meshes.has(key):
		var p: PrismMesh = PrismMesh.new()
		p.size = size
		p.left_to_right = apex
		_meshes[key] = p
	return _place(parent, _meshes[key], pos, m, rot)


## Gable roof with its ridge along X.
static func roof(parent: Node3D, length_x: float, height: float, width_z: float, pos: Vector3, m: Material) -> MeshInstance3D:
	return wedge(parent, Vector3(width_z, height, length_x), pos, m, 0.5, Vector3(0.0, PI * 0.5, 0.0))


static func ring(parent: Node3D, inner: float, outer: float, pos: Vector3, m: Material) -> MeshInstance3D:
	var key: String = "ring|%.3f|%.3f" % [inner, outer]
	if not _meshes.has(key):
		var t: TorusMesh = TorusMesh.new()
		t.inner_radius = inner
		t.outer_radius = outer
		t.rings = 20
		t.ring_segments = 6
		_meshes[key] = t
	return _place(parent, _meshes[key], pos, m, Vector3.ZERO)


static func _turret(root: Node3D, pos: Vector3) -> Node3D:
	return group(root, "Turret", pos)


# ------------------------------------------------------------------ entry

## Builds the model for an entity definition's `model` key.
static func build(model: String, team: Color) -> Node3D:
	var key: String = "%s|%s" % [model, team.to_html()]
	if not _baked.has(key):
		var raw: Node3D = _assemble(model, team)
		_baked[key] = ModelBaker.bake(raw)
		raw.free()
	return ModelBaker.instantiate(_baked[key])


## Puts a model together from primitive-mesh nodes, ready for baking.
static func _assemble(model: String, team: Color) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Model"
	match model:
		"trooper":
			_soldier(root, team, UNIFORM_DARK)
			box(root, Vector3(0.75, 0.07, 0.08), Vector3(0.28, 0.92, 0.2), mat(GUNMETAL))
		"lancer":
			_soldier(root, team, UNIFORM_DARK)
			barrel(root, 0.1, 1.0, Vector3(-0.35, 1.22, 0.22), mat(HULL_DARK))
			box(root, Vector3(0.16, 0.2, 0.2), Vector3(0.68, 1.22, 0.22), mat(HAZARD))
		"engineer":
			_soldier(root, team, HAZARD)
			box(root, Vector3(0.22, 0.44, 0.42), Vector3(-0.27, 0.9, 0.0), mat(HAZARD))
			box(root, Vector3(0.1, 0.5, 0.1), Vector3(0.25, 0.75, 0.24), mat(METAL))
		"marksman":
			_soldier(root, team, UNIFORM)
			box(root, Vector3(1.15, 0.06, 0.06), Vector3(0.4, 0.98, 0.2), mat(GUNMETAL))
			wedge(root, Vector3(0.5, 0.75, 0.55), Vector3(-0.12, 0.72, 0.0), mat(UNIFORM_DARK), 0.5)
		"hauler":
			_hauler(root, team)
		"courser":
			_courser(root, team)
		"warden":
			_warden(root, team)
		"bulwark":
			_bulwark(root, team)
		"tempest":
			_tempest(root, team)
		"longbow":
			_longbow(root, team)
		"kestrel":
			_kestrel(root, team)
		"scout_drone":
			_scout_drone(root, team)
		"flak_post":
			_flak_post(root, team)
		"command_lab":
			_command_lab(root, team)
		"airpad":
			_airpad(root, team)
		"levy":
			_soldier(root, team, IRON_DARK, DRAB, DRAB_DARK)
			box(root, Vector3(0.6, 0.07, 0.08), Vector3(0.25, 0.9, 0.2), mat(GUNMETAL))
		"sapper":
			_soldier(root, team, BRASS, DRAB, DRAB_DARK)
			box(root, Vector3(0.24, 0.5, 0.44), Vector3(-0.28, 0.9, 0.0), mat(RUST))
			cyl(root, 0.2, 0.2, 0.08, Vector3(-0.42, 0.95, 0.0), mat(IRON_DARK), 8, Vector3(0.0, 0.0, PI * 0.5))
		"breaker":
			_soldier(root, team, IRON_DARK, DRAB, DRAB_DARK)
			barrel(root, 0.13, 1.1, Vector3(-0.4, 1.25, 0.22), mat(IRON))
			box(root, Vector3(0.2, 0.3, 0.3), Vector3(-0.42, 1.25, 0.22), mat(RUST))
		"scow":
			_scow(root, team)
		"ratchet":
			_ratchet(root, team)
		"tusk":
			_tusk(root, team)
		"harrow":
			_harrow(root, team)
		"anvil":
			_anvil(root, team)
		"mauler":
			_mauler(root, team)
		"crawler":
			_crawler(root, team, false)
		"crawler_factory":
			_crawler(root, team, true)
		"foundry_core":
			_foundry_core(root, team)
		"pylon":
			_pylon(root, team)
		"scrapyard":
			_scrapyard(root, team)
		"muster_hall":
			_muster_hall(root, team)
		"bastion":
			_bastion(root, team)
		"skyspike":
			_skyspike(root, team)
		"arsenal":
			_arsenal(root, team)
		"mine":
			cyl(root, 0.45, 0.55, 0.14, Vector3(0.0, 0.07, 0.0), mat(IRON_DARK), 8)
			cyl(root, 0.12, 0.12, 0.12, Vector3(0.0, 0.2, 0.0), team_mat(team), 6)
			for i: int in 3:
				var ang: float = float(i) * TAU / 3.0
				cyl(root, 0.02, 0.02, 0.2, Vector3(cos(ang) * 0.3, 0.22, sin(ang) * 0.3), mat(METAL), 4)
		"drifter":
			_soldier(root, team, SAND_DARK, SAND, SAND_DARK)
			box(root, Vector3(0.5, 0.08, 0.1), Vector3(0.25, 0.9, 0.2), mat(GUNMETAL))
			wedge(root, Vector3(0.45, 0.5, 0.5), Vector3(-0.1, 1.05, 0.0), mat(CANVAS), 0.5)
		"tinker":
			_soldier(root, team, PATCH, SAND, SAND_DARK)
			box(root, Vector3(0.22, 0.44, 0.42), Vector3(-0.27, 0.9, 0.0), mat(PATCH))
			box(root, Vector3(0.1, 0.5, 0.1), Vector3(0.25, 0.75, 0.24), mat(METAL))
		"splicer":
			_soldier(root, team, GUNMETAL, SAND_DARK, GUNMETAL)
			cyl(root, 0.02, 0.02, 0.7, Vector3(-0.2, 1.5, 0.15), mat(METAL), 4)
			ball(root, 0.07, Vector3(-0.2, 1.88, 0.15), mat(Color(0.6, 1.0, 0.9), 1.4), 5)
			box(root, Vector3(0.2, 0.3, 0.36), Vector3(-0.26, 0.9, 0.0), mat(PATCH))
		"skiff":
			_skiff(root, team)
		"dart":
			_dart(root, team)
		"sidewinder":
			_sidewinder(root, team)
		"gnat":
			_buggy(root, team)
			var gt: Node3D = _turret(root, Vector3(-0.25, 0.95, 0.0))
			box(gt, Vector3(0.4, 0.3, 0.5), Vector3(0.0, 0.15, 0.0), mat(SAND_DARK))
			for z: float in [-0.14, 0.14]:
				cyl(gt, 0.035, 0.035, 1.1, Vector3(0.4, 0.55, z), mat(GUNMETAL), 5, Vector3(0.0, 0.0, -0.9))
		"jammer_buggy":
			_buggy(root, team)
			cyl(root, 0.04, 0.06, 1.3, Vector3(-0.3, 1.6, 0.0), mat(METAL), 5)
			cyl(root, 0.5, 0.1, 0.2, Vector3(-0.3, 2.2, 0.0), mat(PATCH, 0.3, 0.5, 0.4), 8, Vector3(0.5, 0.0, 0.0))
			ball(root, 0.12, Vector3(-0.3, 2.4, 0.0), mat(Color(0.8, 0.3, 1.0), 1.5), 6)
		"prowler":
			_prowler(root, team)
		"beacon_rig":
			_beacon_rig(root, team)
		"beacon":
			_beacon(root, team)
		"caravan":
			_caravan(root, team, false)
		"caravan_hub":
			_caravan(root, team, true)
		"cache":
			_cache(root, team)
		"camp":
			_camp(root, team)
		"chop_shop":
			_chop_shop(root, team)
		"snare_turret":
			cyl(root, 0.7, 0.85, 0.4, Vector3(0.0, 0.2, 0.0), mat(SAND_DARK), 6)
			for i: int in 3:
				var sa: float = float(i) * TAU / 3.0
				box(root, Vector3(0.9, 0.08, 0.1), Vector3(cos(sa) * 0.5, 0.5, sin(sa) * 0.5), mat(METAL), Vector3(0.0, -sa, 0.5))
			var st: Node3D = _turret(root, Vector3(0.0, 0.9, 0.0))
			box(st, Vector3(0.5, 0.35, 0.5), Vector3(0.0, 0.18, 0.0), mat(SAND))
			barrel(st, 0.045, 0.9, Vector3(0.2, 0.2, 0.0), mat(GUNMETAL))
			box(st, Vector3(0.25, 0.08, 0.52), Vector3(-0.1, 0.38, 0.0), team_mat(team))
		"signal_loom":
			_signal_loom(root, team)
		"hq":
			_hq(root, team)
		"depot":
			_depot(root, team)
		"relay":
			_relay(root, team)
		"barracks":
			_barracks(root, team)
		"vehicle_works":
			_vehicle_works(root, team)
		"sentry_turret":
			_sentry_turret(root, team)
		"lance_battery":
			_lance_battery(root, team)
		_:
			# Unknown model key: a plain marker block so the entity is still visible.
			box(root, Vector3(1.0, 1.0, 1.0), Vector3(0.0, 0.5, 0.0), team_mat(team))
	_detail(model, root, team)
	return root


## A burnt-out version of a model, for wrecks.
static func build_wreck(model: String, seed_value: int) -> Node3D:
	var variant: int = posmod(seed_value, 3)
	var key: String = "wreck|%s|%d" % [model, variant]
	if not _baked.has(key):
		var raw: Node3D = _assemble(model, CHARRED)
		var charred: StandardMaterial3D = mat(CHARRED, 0.0, 0.3, 0.9)
		var scorched: StandardMaterial3D = mat(Color(0.20, 0.17, 0.14), 0.0, 0.3, 0.9)
		var rusted: StandardMaterial3D = mat(Color(0.26, 0.17, 0.12), 0.0, 0.3, 0.9)
		var i: int = 0
		for child: Node in raw.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = child as MeshInstance3D
			var pick: int = (i + variant) % 5
			mi.material_override = scorched if pick == 0 else (rusted if pick == 3 else charred)
			i += 1
		_baked[key] = ModelBaker.bake(raw)
		raw.free()
	var root: Node3D = ModelBaker.instantiate(_baked[key])
	var rng: SimRng = SimRng.new(seed_value)
	root.scale = Vector3(1.0, 0.62, 1.0)
	root.rotation = Vector3(rng.range_f(-0.08, 0.08), 0.0, rng.range_f(-0.12, 0.12))
	var turret: Node3D = root.get_node_or_null("Turret") as Node3D
	if turret != null:
		turret.rotation.y = rng.range_f(-2.0, 2.0)
		turret.rotation.z = rng.range_f(-0.2, 0.2)
	return root


## Scrap heaps for a salvage field.
static func build_field(seed_value: int) -> Node3D:
	# Eight different heaps are plenty; fields share them.
	var variant: int = posmod(seed_value, 8)
	var key: String = "field|%d" % variant
	if not _baked.has(key):
		var raw: Node3D = _assemble_field(variant)
		_baked[key] = ModelBaker.bake(raw)
		raw.free()
	return ModelBaker.instantiate(_baked[key])


static func _assemble_field(seed_value: int) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Model"
	var rng: SimRng = SimRng.new(seed_value + 40)
	var mats: Array[StandardMaterial3D] = [
		mat(RUST, 0.0, 0.4, 0.7), mat(METAL, 0.0, 0.7, 0.45), mat(HULL_DARK, 0.0, 0.4, 0.7),
		mat(Color(0.62, 0.48, 0.22), 0.0, 0.5, 0.6),
	]
	for i: int in 16:
		var ang: float = rng.range_f(0.0, TAU)
		var dist: float = rng.range_f(0.0, 2.3)
		var size: Vector3 = Vector3(rng.range_f(0.3, 1.0), rng.range_f(0.2, 0.7), rng.range_f(0.3, 0.9))
		var pos: Vector3 = Vector3(cos(ang) * dist, size.y * 0.4, sin(ang) * dist)
		var rot: Vector3 = Vector3(rng.range_f(-0.4, 0.4), rng.range_f(0.0, TAU), rng.range_f(-0.4, 0.4))
		box(root, size, pos, mats[rng.range_i(0, mats.size() - 1)], rot)
	# A few glinting shards so fields read as valuable from a distance.
	for i: int in 5:
		var ang: float = rng.range_f(0.0, TAU)
		var dist: float = rng.range_f(0.3, 2.0)
		wedge(root, Vector3(0.3, 0.8, 0.3), Vector3(cos(ang) * dist, 0.4, sin(ang) * dist), mat(Color(0.95, 0.78, 0.30), 0.35, 0.8, 0.3), 0.5, Vector3(0.0, rng.range_f(0.0, TAU), 0.0))
	return root


## Builders' scaffolding around a square footprint: poles, rails, plank
## walkways and a diagonal brace on every side.
static func build_scaffold(half: float, height: float) -> Node3D:
	var key: String = "scaffold|%.1f|%.1f" % [half, height]
	if not _baked.has(key):
		var raw: Node3D = Node3D.new()
		raw.name = "Scaffold"
		var pole: StandardMaterial3D = mat(HAZARD, 0.0, 0.3, 0.6)
		var rail: StandardMaterial3D = mat(METAL, 0.0, 0.6, 0.5)
		var plank: StandardMaterial3D = mat(Color(0.46, 0.34, 0.21), 0.0, 0.0, 1.0)
		var bays: int = maxi(2, int(round(half * 2.0 / 2.0)))
		var levels: int = maxi(1, int(height / 1.4))
		for side: int in 4:
			var face: Node3D = Node3D.new()
			face.rotation.y = float(side) * PI * 0.5
			raw.add_child(face)
			for i: int in bays:
				var x: float = lerpf(-half, half, float(i) / float(bays))
				cyl(face, 0.05, 0.05, height + 0.3, Vector3(x, (height + 0.3) * 0.5, half), pole, 5)
			for level: int in levels:
				var y: float = height * float(level + 1) / float(levels)
				box(face, Vector3(half * 2.0, 0.06, 0.06), Vector3(0.0, y, half), rail)
				box(face, Vector3(half * 2.0 - 0.3, 0.05, 0.5), Vector3(0.0, y - 0.55, half - 0.28), plank)
			var run: float = half * 2.0 / float(bays)
			var slant: float = atan2(height, run)
			box(face, Vector3(sqrt(run * run + height * height), 0.05, 0.05), Vector3(-half + run * 0.5, height * 0.5, half), rail, Vector3(0.0, 0.0, slant))
		_baked[key] = ModelBaker.bake(raw)
		raw.free()
	return ModelBaker.instantiate(_baked[key])


## An uplink site: a pad with a mast that lights up in its owner's colour.
static func build_uplink(light: Color = Color(0.9, 0.9, 0.95)) -> Node3D:
	var key: String = "uplink|%s" % light.to_html()
	if not _baked.has(key):
		var raw: Node3D = Node3D.new()
		raw.name = "Model"
		cyl(raw, 2.2, 2.4, 0.3, Vector3(0.0, 0.15, 0.0), mat(CONCRETE_DARK), 10)
		cyl(raw, 1.5, 1.5, 0.06, Vector3(0.0, 0.32, 0.0), mat(CONCRETE), 10)
		cyl(raw, 0.25, 0.4, 3.0, Vector3(0.0, 1.8, 0.0), mat(METAL, 0.0, 0.6, 0.4), 6)
		cyl(raw, 0.5, 0.6, 0.5, Vector3(0.0, 0.55, 0.0), mat(HULL_DARK), 8)
		ring(raw, 0.9, 1.1, Vector3(0.0, 2.6, 0.0), mat(light, 0.6))
		ball(raw, 0.35, Vector3(0.0, 3.5, 0.0), mat(light, 0.9))
		for i: int in 4:
			var ang: float = float(i) * TAU / 4.0 + 0.4
			box(raw, Vector3(0.5, 0.5, 0.5), Vector3(cos(ang) * 1.7, 0.5, sin(ang) * 1.7), mat(light, 0.5))
			box(raw, Vector3(0.9, 0.08, 0.08), Vector3(cos(ang) * 0.95, 0.36, sin(ang) * 0.95), mat(GUNMETAL), Vector3(0.0, -ang, 0.0))
		radar(raw, Vector3(0.0, 3.6, 0.0), 0.9, "Spin", light)
		_baked[key] = ModelBaker.bake(raw)
		raw.free()
	return ModelBaker.instantiate(_baked[key])


# --------------------------------------------------------------- infantry

static func _soldier(root: Node3D, team: Color, helmet: Color, uniform: Color = UNIFORM, legs: Color = UNIFORM_DARK) -> void:
	for z: float in [-0.11, 0.11]:
		box(root, Vector3(0.25, 0.12, 0.16), Vector3(0.03, 0.06, z), mat(GUNMETAL))
		box(root, Vector3(0.17, 0.52, 0.16), Vector3(0.0, 0.36, z), mat(legs))
	box(root, Vector3(0.30, 0.50, 0.44), Vector3(0.0, 0.86, 0.0), mat(uniform))
	box(root, Vector3(0.32, 0.07, 0.46), Vector3(0.0, 0.64, 0.0), mat(legs))
	# Chest plate and shoulder pads in the team colour.
	box(root, Vector3(0.34, 0.27, 0.40), Vector3(0.01, 0.95, 0.0), team_mat(team))
	for z: float in [-0.27, 0.27]:
		box(root, Vector3(0.17, 0.08, 0.14), Vector3(0.0, 1.09, z), team_mat(team))
		box(root, Vector3(0.12, 0.32, 0.11), Vector3(0.05, 0.9, z), mat(uniform), Vector3(0.0, 0.0, 0.35))
		box(root, Vector3(0.24, 0.1, 0.1), Vector3(0.2, 0.78, z * 0.8), mat(uniform))
	box(root, Vector3(0.16, 0.34, 0.34), Vector3(-0.22, 0.9, 0.0), mat(legs))
	ball(root, 0.13, Vector3(0.03, 1.25, 0.0), mat(SKIN), 6)
	var lid: MeshInstance3D = ball(root, 0.18, Vector3(0.0, 1.32, 0.0), mat(helmet), 6)
	lid.scale = Vector3(1.0, 0.72, 1.0)


# --------------------------------------------------------------- vehicles

## A heap of salvage in a hauler's bed, sitting on `pos`.
static func _cargo(root: Node3D, pos: Vector3, size: Vector3) -> void:
	box(root, Vector3(size.x + 0.04, 0.05, size.z + 0.04), pos + Vector3(0.0, 0.01, 0.0), mat(GUNMETAL))
	var g: Node3D = group(root, "Cargo", pos)
	var rng: SimRng = SimRng.new(int(size.x * 100.0) + 7)
	var mats: Array[StandardMaterial3D] = [
		mat(RUST, 0.0, 0.4, 0.7), mat(METAL, 0.0, 0.7, 0.45), mat(Color(0.62, 0.48, 0.22), 0.0, 0.5, 0.6), mat(HULL_DARK, 0.0, 0.4, 0.7),
	]
	box(g, Vector3(size.x, size.y * 0.35, size.z), Vector3(0.0, size.y * 0.17, 0.0), mats[0])
	for i: int in 7:
		var piece: Vector3 = Vector3(rng.range_f(0.2, 0.45) * size.x, rng.range_f(0.3, 0.6) * size.y, rng.range_f(0.2, 0.45) * size.z)
		var at: Vector3 = Vector3(rng.range_f(-0.3, 0.3) * size.x, size.y * rng.range_f(0.35, 0.6), rng.range_f(-0.3, 0.3) * size.z)
		box(g, piece, at, mats[rng.range_i(0, 3)], Vector3(rng.range_f(-0.4, 0.4), rng.range_f(0.0, 3.0), rng.range_f(-0.4, 0.4)))
	wedge(g, Vector3(0.22, 0.4, 0.22), Vector3(0.1 * size.x, size.y * 0.8, -0.1 * size.z), mat(Color(0.95, 0.78, 0.30), 0.35, 0.8, 0.3), 0.5, Vector3(0.3, 0.8, 0.0))


static func _hauler(root: Node3D, team: Color) -> void:
	box(root, Vector3(2.2, 0.3, 1.15), Vector3(0.0, 0.48, 0.0), mat(HULL_DARK))
	box(root, Vector3(0.7, 0.72, 1.15), Vector3(0.72, 0.96, 0.0), mat(HULL))
	box(root, Vector3(0.06, 0.3, 0.95), Vector3(1.08, 1.08, 0.0), mat(GLASS, 0.15, 0.3, 0.2))
	box(root, Vector3(1.4, 0.55, 1.25), Vector3(-0.38, 0.9, 0.0), mat(HULL_DARK))
	box(root, Vector3(1.42, 0.14, 1.27), Vector3(-0.38, 1.12, 0.0), team_mat(team))
	_cargo(root, Vector3(-0.38, 1.16, 0.0), Vector3(1.2, 0.5, 1.0))
	for x: float in [-0.78, 0.0, 0.78]:
		wheel(root, 0.3, 0.22, Vector3(x, 0.3, 0.6))
		wheel(root, 0.3, 0.22, Vector3(x, 0.3, -0.6))


static func _courser(root: Node3D, team: Color) -> void:
	box(root, Vector3(1.7, 0.36, 0.95), Vector3(0.0, 0.52, 0.0), mat(HULL))
	wedge(root, Vector3(0.6, 0.3, 0.93), Vector3(0.62, 0.84, 0.0), mat(HULL), 0.0)
	box(root, Vector3(0.75, 0.32, 0.86), Vector3(-0.12, 0.85, 0.0), mat(HULL_DARK))
	box(root, Vector3(1.72, 0.1, 0.97), Vector3(0.0, 0.62, 0.0), team_mat(team))
	for x: float in [-0.55, 0.55]:
		wheel(root, 0.3, 0.2, Vector3(x, 0.3, 0.5))
		wheel(root, 0.3, 0.2, Vector3(x, 0.3, -0.5))
	var t: Node3D = _turret(root, Vector3(-0.15, 1.02, 0.0))
	box(t, Vector3(0.34, 0.2, 0.34), Vector3(0.0, 0.1, 0.0), mat(GUNMETAL))
	barrel(t, 0.035, 0.7, Vector3(0.1, 0.12, 0.0), mat(GUNMETAL))


static func _warden(root: Node3D, team: Color) -> void:
	box(root, Vector3(2.1, 0.6, 1.35), Vector3(-0.05, 0.66, 0.0), mat(HULL))
	wedge(root, Vector3(0.5, 0.6, 1.35), Vector3(1.2, 0.66, 0.0), mat(HULL), 0.0)
	box(root, Vector3(2.12, 0.12, 1.37), Vector3(-0.05, 0.8, 0.0), team_mat(team))
	for x: float in [-0.8, -0.27, 0.27, 0.8]:
		wheel(root, 0.3, 0.2, Vector3(x, 0.3, 0.68))
		wheel(root, 0.3, 0.2, Vector3(x, 0.3, -0.68))
	var t: Node3D = _turret(root, Vector3(-0.1, 0.96, 0.0))
	box(t, Vector3(0.85, 0.36, 0.85), Vector3(0.0, 0.18, 0.0), mat(HULL_DARK))
	barrel(t, 0.055, 1.15, Vector3(0.4, 0.2, 0.0), mat(GUNMETAL))
	box(t, Vector3(0.3, 0.1, 0.3), Vector3(-0.15, 0.41, 0.2), team_mat(team))


static func _bulwark(root: Node3D, team: Color) -> void:
	track(root, 2.8, 0.72, 0.6)
	track(root, 2.8, -0.72, 0.6)
	box(root, Vector3(2.3, 0.5, 1.3), Vector3(-0.05, 0.66, 0.0), mat(HULL))
	wedge(root, Vector3(0.55, 0.5, 1.3), Vector3(1.37, 0.66, 0.0), mat(HULL), 0.0)
	box(root, Vector3(2.72, 0.1, 0.47), Vector3(0.0, 0.6, 0.72), team_mat(team))
	box(root, Vector3(2.72, 0.1, 0.47), Vector3(0.0, 0.6, -0.72), team_mat(team))
	var t: Node3D = _turret(root, Vector3(-0.15, 0.92, 0.0))
	box(t, Vector3(1.25, 0.46, 1.1), Vector3(0.0, 0.23, 0.0), mat(HULL_DARK))
	wedge(t, Vector3(0.4, 0.46, 1.1), Vector3(0.82, 0.23, 0.0), mat(HULL_DARK), 0.0)
	barrel(t, 0.09, 1.75, Vector3(0.9, 0.24, 0.0), mat(GUNMETAL))
	box(t, Vector3(0.5, 0.08, 0.6), Vector3(-0.2, 0.5, 0.0), team_mat(team))
	cyl(t, 0.015, 0.015, 0.9, Vector3(-0.5, 0.9, -0.4), mat(GUNMETAL), 4)


static func _tempest(root: Node3D, team: Color) -> void:
	track(root, 2.5, 0.66, 0.54, 0.42)
	track(root, 2.5, -0.66, 0.54, 0.42)
	box(root, Vector3(2.1, 0.45, 1.2), Vector3(0.0, 0.62, 0.0), mat(HULL))
	wedge(root, Vector3(0.45, 0.45, 1.2), Vector3(1.27, 0.62, 0.0), mat(HULL), 0.0)
	box(root, Vector3(2.42, 0.1, 0.44), Vector3(0.0, 0.56, 0.66), team_mat(team))
	box(root, Vector3(2.42, 0.1, 0.44), Vector3(0.0, 0.56, -0.66), team_mat(team))
	var t: Node3D = _turret(root, Vector3(-0.1, 0.86, 0.0))
	box(t, Vector3(0.9, 0.5, 1.0), Vector3(0.0, 0.25, 0.0), mat(HULL_DARK))
	for z: float in [-0.36, -0.14, 0.14, 0.36]:
		cyl(t, 0.04, 0.04, 1.2, Vector3(0.62, 0.62, z), mat(GUNMETAL), 5, Vector3(0.0, 0.0, -1.0))
	cyl(t, 0.3, 0.3, 0.06, Vector3(-0.3, 0.72, 0.0), team_mat(team), 8, Vector3(0.0, 0.0, 0.5))


static func _longbow(root: Node3D, team: Color) -> void:
	track(root, 2.7, 0.7, 0.54)
	track(root, 2.7, -0.7, 0.54)
	box(root, Vector3(2.4, 0.5, 1.25), Vector3(0.0, 0.64, 0.0), mat(HULL))
	box(root, Vector3(0.7, 0.5, 1.1), Vector3(0.75, 1.1, 0.0), mat(HULL_DARK))
	box(root, Vector3(2.62, 0.1, 0.47), Vector3(0.0, 0.58, 0.7), team_mat(team))
	box(root, Vector3(2.62, 0.1, 0.47), Vector3(0.0, 0.58, -0.7), team_mat(team))
	box(root, Vector3(0.5, 0.25, 1.5), Vector3(-1.1, 0.35, 0.0), mat(GUNMETAL))
	var t: Node3D = _turret(root, Vector3(-0.35, 0.95, 0.0))
	box(t, Vector3(0.9, 0.55, 0.9), Vector3(0.0, 0.28, 0.0), mat(HULL_DARK))
	cyl(t, 0.11, 0.13, 2.6, Vector3(0.95, 1.0, 0.0), mat(GUNMETAL), 6, Vector3(0.0, 0.0, -0.95))
	box(t, Vector3(0.4, 0.1, 0.5), Vector3(-0.25, 0.6, 0.0), team_mat(team))


# --------------------------------------------------------------- aircraft

static func _rotor(root: Node3D, pos: Vector3, radius: float, node_name: String) -> void:
	var r: Node3D = group(root, node_name, pos)
	box(r, Vector3(radius * 2.0, 0.03, 0.14), Vector3.ZERO, mat(GUNMETAL))
	box(r, Vector3(0.14, 0.03, radius * 2.0), Vector3.ZERO, mat(GUNMETAL))
	cyl(r, 0.08, 0.08, 0.12, Vector3.ZERO, mat(METAL), 6)


static func _kestrel(root: Node3D, team: Color) -> void:
	box(root, Vector3(1.9, 0.6, 0.75), Vector3(0.15, 0.5, 0.0), mat(HULL))
	wedge(root, Vector3(0.7, 0.6, 0.75), Vector3(1.45, 0.5, 0.0), mat(HULL), 0.0)
	box(root, Vector3(0.6, 0.3, 0.6), Vector3(0.75, 0.86, 0.0), mat(GLASS, 0.15, 0.3, 0.2))
	box(root, Vector3(1.7, 0.2, 0.22), Vector3(-1.5, 0.6, 0.0), mat(HULL_DARK))
	box(root, Vector3(0.1, 0.55, 0.5), Vector3(-2.3, 0.82, 0.0), team_mat(team))
	box(root, Vector3(0.5, 0.1, 2.3), Vector3(0.1, 0.42, 0.0), mat(HULL_DARK))
	for z: float in [-1.05, 1.05]:
		cyl(root, 0.16, 0.16, 0.8, Vector3(0.15, 0.3, z), mat(GUNMETAL), 6, Vector3(0.0, 0.0, -PI * 0.5))
		box(root, Vector3(0.2, 0.06, 0.4), Vector3(0.1, 0.5, z), team_mat(team))
	box(root, Vector3(1.9, 0.08, 0.77), Vector3(0.15, 0.24, 0.0), team_mat(team))
	cyl(root, 0.06, 0.06, 0.3, Vector3(0.1, 0.95, 0.0), mat(METAL), 5)
	_rotor(root, Vector3(0.1, 1.12, 0.0), 1.9, "Rotor")
	var t: Node3D = _turret(root, Vector3(1.1, 0.16, 0.0))
	box(t, Vector3(0.3, 0.16, 0.3), Vector3.ZERO, mat(GUNMETAL))
	barrel(t, 0.04, 0.5, Vector3(0.1, -0.02, 0.0), mat(GUNMETAL))


static func _scout_drone(root: Node3D, team: Color) -> void:
	box(root, Vector3(0.6, 0.18, 0.4), Vector3(0.0, 0.3, 0.0), mat(HULL_DARK))
	ball(root, 0.14, Vector3(0.28, 0.2, 0.0), mat(GLASS, 0.6, 0.3, 0.2), 6)
	box(root, Vector3(0.62, 0.06, 0.42), Vector3(0.0, 0.4, 0.0), team_mat(team))
	var i: int = 0
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			box(root, Vector3(0.5, 0.05, 0.06), Vector3(sx * 0.32, 0.32, sz * 0.3), mat(METAL), Vector3(0.0, -sx * sz * 0.75, 0.0))
			_rotor(root, Vector3(sx * 0.5, 0.42, sz * 0.46), 0.3, "Rotor%d" % i)
			i += 1


# -------------------------------------------------------------- buildings

static func _hq(root: Node3D, team: Color) -> void:
	box(root, Vector3(7.7, 0.5, 7.7), Vector3(0.0, 0.0, 0.0), mat(CONCRETE_DARK))
	box(root, Vector3(5.4, 2.6, 5.4), Vector3(0.0, 1.5, 0.0), mat(CONCRETE))
	box(root, Vector3(5.5, 0.35, 5.5), Vector3(0.0, 2.2, 0.0), team_mat(team))
	box(root, Vector3(3.4, 1.5, 3.4), Vector3(0.0, 3.5, 0.0), mat(HULL))
	box(root, Vector3(3.5, 0.2, 3.5), Vector3(0.0, 4.3, 0.0), mat(HULL_DARK))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			box(root, Vector3(1.0, 1.7, 1.0), Vector3(sx * 3.1, 0.95, sz * 3.1), mat(CONCRETE_DARK))
			box(root, Vector3(0.5, 0.12, 0.5), Vector3(sx * 3.1, 1.86, sz * 3.1), team_mat(team))
	# Command mast: the root of the signal grid.
	cyl(root, 0.18, 0.3, 3.6, Vector3(0.9, 6.1, 0.9), mat(METAL, 0.0, 0.6, 0.4), 6)
	ring(root, 0.75, 0.9, Vector3(0.9, 6.6, 0.9), team_mat(team))
	ring(root, 0.45, 0.58, Vector3(0.9, 7.3, 0.9), team_mat(team))
	ball(root, 0.24, Vector3(0.9, 8.0, 0.9), mat(team, 1.4))
	box(root, Vector3(1.6, 1.1, 0.12), Vector3(2.76, 0.9, 0.0), mat(HULL_DARK))
	var t: Node3D = _turret(root, Vector3(-0.9, 4.4, -0.9))
	box(t, Vector3(0.8, 0.45, 0.7), Vector3(0.0, 0.25, 0.0), mat(HULL_DARK))
	barrel(t, 0.06, 0.9, Vector3(0.35, 0.3, 0.14), mat(GUNMETAL))
	barrel(t, 0.06, 0.9, Vector3(0.35, 0.3, -0.14), mat(GUNMETAL))


static func _depot(root: Node3D, team: Color) -> void:
	box(root, Vector3(5.7, 0.4, 5.7), Vector3(0.0, 0.0, 0.0), mat(CONCRETE_DARK))
	box(root, Vector3(4.4, 1.9, 3.0), Vector3(0.0, 1.15, -1.0), mat(HULL))
	roof(root, 4.4, 0.8, 3.0, Vector3(0.0, 2.5, -1.0), mat(HULL_DARK))
	box(root, Vector3(4.45, 0.25, 3.05), Vector3(0.0, 1.9, -1.0), team_mat(team))
	box(root, Vector3(1.8, 1.3, 0.1), Vector3(0.0, 0.85, 0.52), mat(GUNMETAL))
	# Salvage bins on the loading pad.
	box(root, Vector3(1.2, 0.8, 1.0), Vector3(-1.6, 0.6, 1.7), mat(RUST, 0.0, 0.4, 0.7))
	box(root, Vector3(1.2, 0.8, 1.0), Vector3(-0.2, 0.6, 1.8), mat(HULL_DARK))
	box(root, Vector3(1.2, 0.8, 1.0), Vector3(-0.9, 1.4, 1.75), mat(Color(0.62, 0.48, 0.22)))
	box(root, Vector3(1.3, 0.8, 1.0), Vector3(1.5, 0.6, 1.7), team_mat(team))
	cyl(root, 0.1, 0.1, 2.6, Vector3(2.3, 1.5, -2.2), mat(METAL), 5)
	box(root, Vector3(1.5, 0.12, 0.12), Vector3(1.6, 2.7, -2.2), mat(HAZARD))


static func _relay(root: Node3D, team: Color) -> void:
	cyl(root, 0.75, 0.9, 0.35, Vector3(0.0, 0.17, 0.0), mat(CONCRETE_DARK), 8)
	cyl(root, 0.3, 0.45, 0.8, Vector3(0.0, 0.7, 0.0), mat(HULL), 6)
	cyl(root, 0.09, 0.16, 4.0, Vector3(0.0, 3.0, 0.0), mat(METAL, 0.0, 0.6, 0.4), 6)
	for i: int in 3:
		var ang: float = float(i) * TAU / 3.0
		box(root, Vector3(0.9, 0.06, 0.06), Vector3(cos(ang) * 0.45, 2.2, sin(ang) * 0.45), mat(METAL), Vector3(0.0, -ang, 0.5))
	ring(root, 0.6, 0.72, Vector3(0.0, 3.3, 0.0), team_mat(team))
	ring(root, 0.38, 0.48, Vector3(0.0, 4.1, 0.0), team_mat(team))
	ball(root, 0.2, Vector3(0.0, 5.1, 0.0), mat(team, 1.4))


static func _barracks(root: Node3D, team: Color) -> void:
	box(root, Vector3(5.7, 0.4, 5.7), Vector3(0.0, 0.0, 0.0), mat(CONCRETE_DARK))
	box(root, Vector3(4.8, 1.7, 3.2), Vector3(0.0, 1.05, -0.6), mat(CONCRETE))
	roof(root, 4.8, 0.9, 3.2, Vector3(0.0, 2.35, -0.6), mat(UNIFORM_DARK))
	box(root, Vector3(4.85, 0.22, 3.25), Vector3(0.0, 1.75, -0.6), team_mat(team))
	box(root, Vector3(1.0, 1.2, 0.1), Vector3(0.0, 0.8, 1.02), mat(GUNMETAL))
	box(root, Vector3(1.8, 1.2, 1.6), Vector3(-1.5, 0.8, 1.7), mat(UNIFORM))
	box(root, Vector3(1.85, 0.12, 1.65), Vector3(-1.5, 1.44, 1.7), mat(UNIFORM_DARK))
	# Flag pole and parade markers.
	cyl(root, 0.05, 0.05, 3.2, Vector3(2.2, 1.8, 2.0), mat(METAL), 5)
	box(root, Vector3(0.9, 0.55, 0.05), Vector3(2.66, 3.0, 2.0), team_mat(team))
	for x: float in [0.6, 1.4]:
		box(root, Vector3(0.3, 0.3, 0.3), Vector3(x, 0.35, 2.3), mat(HAZARD))


static func _vehicle_works(root: Node3D, team: Color) -> void:
	box(root, Vector3(7.7, 0.4, 5.7), Vector3(0.0, 0.0, 0.0), mat(CONCRETE_DARK))
	box(root, Vector3(6.2, 2.6, 4.2), Vector3(-0.4, 1.5, -0.4), mat(HULL))
	box(root, Vector3(6.3, 0.3, 4.3), Vector3(-0.4, 2.3, -0.4), team_mat(team))
	for x: float in [-2.6, -1.2, 0.2, 1.6]:
		roof(root, 1.3, 0.6, 4.2, Vector3(x, 3.1, -0.4), mat(HULL_DARK))
	# Assembly door facing the yard.
	box(root, Vector3(3.0, 1.9, 0.12), Vector3(-0.4, 1.15, 1.72), mat(GUNMETAL))
	box(root, Vector3(3.3, 0.18, 0.2), Vector3(-0.4, 2.15, 1.75), mat(HAZARD))
	# Gantry crane.
	cyl(root, 0.12, 0.12, 3.4, Vector3(3.2, 1.9, -2.2), mat(HAZARD), 5)
	cyl(root, 0.12, 0.12, 3.4, Vector3(3.2, 1.9, 2.0), mat(HAZARD), 5)
	box(root, Vector3(0.25, 0.25, 4.5), Vector3(3.2, 3.6, -0.1), mat(HAZARD))
	box(root, Vector3(0.5, 0.5, 0.5), Vector3(3.2, 3.2, 0.6), mat(GUNMETAL))
	cyl(root, 0.3, 0.36, 1.6, Vector3(-3.0, 3.5, -1.8), mat(CONCRETE_DARK), 6)


static func _sentry_turret(root: Node3D, team: Color) -> void:
	cyl(root, 0.8, 0.92, 0.5, Vector3(0.0, 0.25, 0.0), mat(CONCRETE_DARK), 8)
	cyl(root, 0.4, 0.5, 0.5, Vector3(0.0, 0.72, 0.0), mat(HULL), 6)
	ring(root, 0.78, 0.86, Vector3(0.0, 0.5, 0.0), team_mat(team))
	var t: Node3D = _turret(root, Vector3(0.0, 0.95, 0.0))
	box(t, Vector3(0.75, 0.45, 0.65), Vector3(0.0, 0.25, 0.0), mat(HULL_DARK))
	barrel(t, 0.05, 0.85, Vector3(0.3, 0.28, 0.16), mat(GUNMETAL))
	barrel(t, 0.05, 0.85, Vector3(0.3, 0.28, -0.16), mat(GUNMETAL))
	box(t, Vector3(0.3, 0.1, 0.3), Vector3(-0.15, 0.52, 0.0), team_mat(team))


static func _lance_battery(root: Node3D, team: Color) -> void:
	cyl(root, 0.85, 0.95, 0.5, Vector3(0.0, 0.25, 0.0), mat(CONCRETE_DARK), 8)
	cyl(root, 0.35, 0.45, 0.7, Vector3(0.0, 0.8, 0.0), mat(HULL), 6)
	ring(root, 0.82, 0.9, Vector3(0.0, 0.5, 0.0), team_mat(team))
	var t: Node3D = _turret(root, Vector3(0.0, 1.15, 0.0))
	box(t, Vector3(1.1, 0.55, 0.95), Vector3(0.1, 0.35, 0.0), mat(HULL_DARK), Vector3(0.0, 0.0, 0.3))
	for z: float in [-0.25, 0.25]:
		for y: float in [0.38, 0.62]:
			box(t, Vector3(0.1, 0.17, 0.2), Vector3(0.66, y + 0.16, z), mat(HAZARD), Vector3(0.0, 0.0, 0.3))
	box(t, Vector3(0.4, 0.1, 0.5), Vector3(-0.3, 0.6, 0.0), team_mat(team), Vector3(0.0, 0.0, 0.3))


static func _flak_post(root: Node3D, team: Color) -> void:
	cyl(root, 0.85, 0.95, 0.5, Vector3(0.0, 0.25, 0.0), mat(CONCRETE_DARK), 8)
	cyl(root, 0.45, 0.55, 0.6, Vector3(0.0, 0.78, 0.0), mat(HULL), 6)
	ring(root, 0.82, 0.9, Vector3(0.0, 0.5, 0.0), team_mat(team))
	var t: Node3D = _turret(root, Vector3(0.0, 1.1, 0.0))
	box(t, Vector3(0.7, 0.5, 0.9), Vector3(0.0, 0.25, 0.0), mat(HULL_DARK))
	for z: float in [-0.3, -0.1, 0.1, 0.3]:
		cyl(t, 0.045, 0.045, 1.4, Vector3(0.5, 0.75, z), mat(GUNMETAL), 5, Vector3(0.0, 0.0, -0.75))
	box(t, Vector3(0.3, 0.1, 0.92), Vector3(-0.15, 0.52, 0.0), team_mat(team))


static func _command_lab(root: Node3D, team: Color) -> void:
	box(root, Vector3(5.7, 0.4, 5.7), Vector3(0.0, 0.0, 0.0), mat(CONCRETE_DARK))
	box(root, Vector3(4.4, 1.6, 4.4), Vector3(0.0, 1.0, 0.0), mat(CONCRETE))
	box(root, Vector3(4.45, 0.25, 4.45), Vector3(0.0, 1.5, 0.0), team_mat(team))
	ball(root, 1.5, Vector3(0.0, 1.8, 0.0), mat(HULL, 0.0, 0.4, 0.5), 10)
	ring(root, 1.5, 1.62, Vector3(0.0, 1.85, 0.0), team_mat(team))
	for sx: float in [-1.0, 1.0]:
		cyl(root, 0.06, 0.06, 1.6, Vector3(sx * 1.8, 2.6, -1.8), mat(METAL), 5)
		cyl(root, 0.5, 0.1, 0.25, Vector3(sx * 1.8, 3.5, -1.8), mat(METAL, 0.0, 0.6, 0.4), 8, Vector3(0.6, 0.0, sx * 0.4))
	box(root, Vector3(1.2, 1.1, 0.1), Vector3(0.0, 0.75, 2.22), mat(GUNMETAL))
	box(root, Vector3(0.8, 0.5, 0.8), Vector3(1.7, 2.05, 1.7), mat(HULL_DARK))
	ball(root, 0.2, Vector3(1.7, 2.5, 1.7), mat(team, 1.4))


static func _airpad(root: Node3D, team: Color) -> void:
	box(root, Vector3(5.8, 0.4, 5.8), Vector3(0.0, 0.0, 0.0), mat(CONCRETE_DARK))
	cyl(root, 2.1, 2.1, 0.12, Vector3(0.6, 0.26, 0.6), mat(CONCRETE), 16)
	ring(root, 1.9, 2.05, Vector3(0.6, 0.34, 0.6), team_mat(team))
	box(root, Vector3(0.3, 0.04, 1.6), Vector3(0.1, 0.34, 0.6), mat(HAZARD))
	box(root, Vector3(0.3, 0.04, 1.6), Vector3(1.1, 0.34, 0.6), mat(HAZARD))
	box(root, Vector3(1.0, 0.04, 0.3), Vector3(0.6, 0.34, 0.6), mat(HAZARD))
	box(root, Vector3(1.6, 1.5, 5.2), Vector3(-2.0, 0.95, 0.0), mat(HULL))
	roof(root, 1.6, 0.5, 5.2, Vector3(-2.0, 1.95, 0.0), mat(HULL_DARK))
	box(root, Vector3(1.65, 0.2, 5.25), Vector3(-2.0, 1.5, 0.0), team_mat(team))
	box(root, Vector3(0.9, 2.6, 0.9), Vector3(2.2, 1.5, -2.2), mat(CONCRETE))
	box(root, Vector3(1.2, 0.5, 1.2), Vector3(2.2, 3.0, -2.2), mat(GLASS, 0.3, 0.3, 0.2))
	ball(root, 0.16, Vector3(2.2, 3.5, -2.2), mat(team, 1.4))


# ------------------------------------------------------------ Foundry Pact

static func _tracks(root: Node3D, length: float, half_width: float, height: float = 0.55) -> void:
	track(root, length, half_width, height, 0.5)
	track(root, length, -half_width, height, 0.5)
	box(root, Vector3(length * 0.96, 0.08, 0.54), Vector3(0.0, height + 0.02, half_width), mat(IRON_DARK))
	box(root, Vector3(length * 0.96, 0.08, 0.54), Vector3(0.0, height + 0.02, -half_width), mat(IRON_DARK))


static func _stack(root: Node3D, pos: Vector3, height: float, radius: float = 0.14) -> void:
	cyl(root, radius * 0.8, radius, height, pos + Vector3(0.0, height * 0.5, 0.0), mat(IRON_DARK), 6)
	cyl(root, radius * 0.9, radius * 0.9, 0.06, pos + Vector3(0.0, height, 0.0), mat(FURNACE, 1.2), 6)


static func _scow(root: Node3D, team: Color) -> void:
	box(root, Vector3(2.4, 0.35, 1.3), Vector3(0.0, 0.52, 0.0), mat(IRON_DARK))
	box(root, Vector3(0.75, 0.8, 1.3), Vector3(0.8, 1.05, 0.0), mat(IRON))
	box(root, Vector3(0.06, 0.2, 1.0), Vector3(1.19, 1.2, 0.0), mat(GLASS, 0.15, 0.3, 0.2))
	box(root, Vector3(1.55, 0.75, 1.4), Vector3(-0.4, 1.0, 0.0), mat(RUST, 0.0, 0.4, 0.7))
	box(root, Vector3(1.57, 0.16, 1.42), Vector3(-0.4, 1.3, 0.0), team_mat(team))
	_cargo(root, Vector3(-0.4, 1.34, 0.0), Vector3(1.3, 0.5, 1.1))
	for x: float in [-0.85, 0.0, 0.85]:
		wheel(root, 0.36, 0.26, Vector3(x, 0.36, 0.68))
		wheel(root, 0.36, 0.26, Vector3(x, 0.36, -0.68))


static func _ratchet(root: Node3D, team: Color) -> void:
	box(root, Vector3(2.1, 0.3, 1.15), Vector3(0.0, 0.5, 0.0), mat(IRON_DARK))
	box(root, Vector3(0.7, 0.7, 1.15), Vector3(0.7, 0.98, 0.0), mat(IRON))
	box(root, Vector3(1.2, 0.4, 1.1), Vector3(-0.4, 0.85, 0.0), mat(HAZARD))
	box(root, Vector3(1.22, 0.1, 1.12), Vector3(-0.4, 1.08, 0.0), team_mat(team))
	cyl(root, 0.08, 0.1, 1.3, Vector3(-0.6, 1.6, 0.0), mat(IRON), 5)
	box(root, Vector3(1.3, 0.1, 0.1), Vector3(-0.05, 2.2, 0.0), mat(HAZARD), Vector3(0.0, 0.0, 0.25))
	box(root, Vector3(0.2, 0.3, 0.2), Vector3(0.55, 1.95, 0.0), mat(GUNMETAL))
	for x: float in [-0.7, 0.7]:
		wheel(root, 0.32, 0.24, Vector3(x, 0.32, 0.6))
		wheel(root, 0.32, 0.24, Vector3(x, 0.32, -0.6))


static func _tusk(root: Node3D, team: Color) -> void:
	_tracks(root, 2.6, 0.72)
	box(root, Vector3(2.3, 0.6, 1.3), Vector3(-0.05, 0.75, 0.0), mat(IRON))
	wedge(root, Vector3(0.7, 0.6, 1.3), Vector3(1.45, 0.75, 0.0), mat(IRON), 0.0)
	box(root, Vector3(2.32, 0.12, 1.32), Vector3(-0.05, 0.6, 0.0), team_mat(team))
	_stack(root, Vector3(-1.0, 1.05, 0.45), 0.5, 0.1)
	var t: Node3D = _turret(root, Vector3(0.1, 1.05, 0.0))
	box(t, Vector3(1.2, 0.5, 1.15), Vector3(0.0, 0.25, 0.0), mat(IRON_DARK))
	barrel(t, 0.15, 1.1, Vector3(0.5, 0.26, 0.0), mat(GUNMETAL))
	cyl(t, 0.2, 0.2, 0.3, Vector3(1.6, 0.26, 0.0), mat(GUNMETAL), 6, Vector3(0.0, 0.0, -PI * 0.5))


static func _harrow(root: Node3D, team: Color) -> void:
	var half: Node3D = Node3D.new()
	half.position = Vector3(-0.45, 0.0, 0.0)
	root.add_child(half)
	track(half, 1.6, 0.62, 0.54)
	track(half, 1.6, -0.62, 0.54)
	wheel(root, 0.32, 0.24, Vector3(0.85, 0.32, 0.62))
	wheel(root, 0.32, 0.24, Vector3(0.85, 0.32, -0.62))
	box(root, Vector3(2.3, 0.45, 1.15), Vector3(0.0, 0.66, 0.0), mat(IRON))
	box(root, Vector3(0.6, 0.5, 1.1), Vector3(0.75, 1.1, 0.0), mat(IRON_DARK))
	box(root, Vector3(2.32, 0.1, 1.17), Vector3(0.0, 0.5, 0.0), team_mat(team))
	var t: Node3D = _turret(root, Vector3(-0.45, 0.9, 0.0))
	cyl(t, 0.5, 0.55, 0.3, Vector3(0.0, 0.15, 0.0), mat(IRON_DARK), 8)
	for z: float in [-0.22, 0.22]:
		cyl(t, 0.05, 0.05, 1.5, Vector3(0.5, 0.75, z), mat(GUNMETAL), 5, Vector3(0.0, 0.0, -0.85))
	box(t, Vector3(0.5, 0.5, 0.7), Vector3(-0.1, 0.5, 0.0), mat(IRON))
	box(t, Vector3(0.3, 0.08, 0.72), Vector3(-0.2, 0.78, 0.0), team_mat(team))


static func _anvil(root: Node3D, team: Color) -> void:
	_tracks(root, 2.5, 0.7)
	box(root, Vector3(2.3, 0.45, 1.25), Vector3(0.0, 0.72, 0.0), mat(IRON))
	box(root, Vector3(0.6, 0.55, 1.2), Vector3(0.8, 1.2, 0.0), mat(IRON_DARK))
	box(root, Vector3(2.32, 0.1, 1.27), Vector3(0.0, 0.58, 0.0), team_mat(team))
	var t: Node3D = _turret(root, Vector3(-0.45, 0.95, 0.0))
	cyl(t, 0.55, 0.6, 0.25, Vector3(0.0, 0.12, 0.0), mat(IRON_DARK), 8)
	cyl(t, 0.24, 0.28, 1.5, Vector3(0.3, 0.85, 0.0), mat(GUNMETAL), 7, Vector3(0.0, 0.0, -0.5))
	cyl(t, 0.3, 0.3, 0.12, Vector3(0.66, 1.52, 0.0), mat(BRASS, 0.0, 0.6, 0.5), 7, Vector3(0.0, 0.0, -0.5))


static func _mauler(root: Node3D, team: Color) -> void:
	_tracks(root, 3.1, 0.9, 0.7)
	box(root, Vector3(2.8, 0.6, 1.5), Vector3(-0.05, 0.9, 0.0), mat(IRON))
	wedge(root, Vector3(0.7, 0.6, 1.5), Vector3(1.7, 0.9, 0.0), mat(IRON), 0.0)
	box(root, Vector3(3.12, 0.12, 0.56), Vector3(0.0, 0.8, 0.9), team_mat(team))
	box(root, Vector3(3.12, 0.12, 0.56), Vector3(0.0, 0.8, -0.9), team_mat(team))
	_stack(root, Vector3(-1.3, 1.2, 0.5), 0.7)
	_stack(root, Vector3(-1.3, 1.2, -0.5), 0.7)
	var t: Node3D = _turret(root, Vector3(-0.1, 1.2, 0.0))
	box(t, Vector3(1.6, 0.6, 1.4), Vector3(0.0, 0.3, 0.0), mat(IRON_DARK))
	wedge(t, Vector3(0.5, 0.6, 1.4), Vector3(1.05, 0.3, 0.0), mat(IRON_DARK), 0.0)
	barrel(t, 0.14, 2.0, Vector3(1.1, 0.32, 0.0), mat(GUNMETAL))
	cyl(t, 0.2, 0.2, 0.4, Vector3(3.0, 0.32, 0.0), mat(GUNMETAL), 6, Vector3(0.0, 0.0, -PI * 0.5))
	box(t, Vector3(0.7, 0.1, 0.8), Vector3(-0.3, 0.65, 0.0), team_mat(team))
	box(t, Vector3(0.4, 0.3, 0.4), Vector3(-0.4, 0.8, 0.4), mat(IRON))


## The Crawler as a vehicle, or unfolded into its factory when deployed.
static func _crawler(root: Node3D, team: Color, deployed: bool) -> void:
	if not deployed:
		_tracks(root, 3.4, 1.0, 0.7)
		box(root, Vector3(3.2, 0.9, 1.7), Vector3(0.0, 1.05, 0.0), mat(IRON))
		box(root, Vector3(0.8, 0.6, 1.5), Vector3(1.1, 1.8, 0.0), mat(IRON_DARK))
		box(root, Vector3(0.06, 0.25, 1.2), Vector3(1.52, 1.85, 0.0), mat(GLASS, 0.15, 0.3, 0.2))
		box(root, Vector3(3.22, 0.16, 1.72), Vector3(0.0, 0.8, 0.0), team_mat(team))
		box(root, Vector3(1.9, 0.25, 0.25), Vector3(-0.5, 1.7, 0.6), mat(HAZARD))
		box(root, Vector3(1.9, 0.25, 0.25), Vector3(-0.5, 1.7, -0.6), mat(HAZARD))
		_stack(root, Vector3(-1.3, 1.5, 0.0), 0.9, 0.18)
		return
	box(root, Vector3(5.7, 0.4, 5.7), Vector3(0.0, 0.0, 0.0), mat(IRON_DARK))
	box(root, Vector3(4.6, 1.4, 2.2), Vector3(0.0, 0.9, -1.4), mat(IRON))
	box(root, Vector3(4.65, 0.2, 2.25), Vector3(0.0, 1.2, -1.4), team_mat(team))
	box(root, Vector3(1.0, 0.7, 1.6), Vector3(1.6, 1.95, -1.4), mat(IRON_DARK))
	_stack(root, Vector3(-1.7, 1.6, -1.6), 1.6, 0.22)
	_stack(root, Vector3(-1.0, 1.6, -1.6), 1.2, 0.18)
	# Unfolded assembly gantry over the yard.
	for x: float in [-2.1, 2.1]:
		cyl(root, 0.12, 0.12, 2.6, Vector3(x, 1.5, 1.9), mat(HAZARD), 5)
		cyl(root, 0.12, 0.12, 2.6, Vector3(x, 1.5, 0.0), mat(HAZARD), 5)
		box(root, Vector3(0.22, 0.22, 2.1), Vector3(x, 2.8, 0.95), mat(HAZARD))
	box(root, Vector3(4.4, 0.22, 0.3), Vector3(0.0, 2.8, 0.95), mat(HAZARD))
	box(root, Vector3(0.5, 0.6, 0.5), Vector3(0.4, 2.4, 0.95), mat(GUNMETAL))
	box(root, Vector3(3.4, 0.08, 1.8), Vector3(0.0, 0.26, 1.0), mat(CONCRETE_DARK))
	box(root, Vector3(0.8, 0.5, 0.6), Vector3(-1.0, 0.5, 1.2), mat(RUST, 0.0, 0.4, 0.7))


static func _foundry_core(root: Node3D, team: Color) -> void:
	box(root, Vector3(7.7, 0.5, 7.7), Vector3(0.0, 0.0, 0.0), mat(IRON_DARK))
	box(root, Vector3(6.0, 2.4, 6.0), Vector3(0.0, 1.4, 0.0), mat(IRON))
	box(root, Vector3(6.1, 0.4, 6.1), Vector3(0.0, 1.0, 0.0), team_mat(team))
	box(root, Vector3(4.0, 1.4, 4.0), Vector3(0.0, 3.3, 0.0), mat(IRON_DARK))
	for sx: float in [-1.0, 1.0]:
		wedge(root, Vector3(1.2, 2.6, 5.0), Vector3(sx * 3.4, 1.5, 0.0), mat(IRON_DARK), 0.0 if sx > 0.0 else 1.0)
	# Furnace mouth and stacks.
	box(root, Vector3(2.0, 1.2, 0.2), Vector3(0.0, 0.9, 3.02), mat(FURNACE, 1.6))
	box(root, Vector3(2.4, 0.3, 0.3), Vector3(0.0, 1.65, 3.05), mat(IRON_DARK))
	_stack(root, Vector3(-1.4, 4.0, -1.4), 2.6, 0.4)
	_stack(root, Vector3(-0.3, 4.0, -1.5), 1.9, 0.32)
	_stack(root, Vector3(-1.5, 4.0, -0.3), 1.5, 0.28)
	cyl(root, 0.22, 0.34, 3.2, Vector3(1.2, 5.6, 1.2), mat(IRON, 0.0, 0.5, 0.5), 6)
	ring(root, 0.8, 1.0, Vector3(1.2, 6.2, 1.2), team_mat(team))
	ball(root, 0.28, Vector3(1.2, 7.3, 1.2), mat(team, 1.4))
	var t: Node3D = _turret(root, Vector3(1.2, 4.0, -1.2))
	box(t, Vector3(0.9, 0.5, 0.8), Vector3(0.0, 0.25, 0.0), mat(IRON_DARK))
	barrel(t, 0.07, 0.9, Vector3(0.4, 0.3, 0.16), mat(GUNMETAL))
	barrel(t, 0.07, 0.9, Vector3(0.4, 0.3, -0.16), mat(GUNMETAL))


static func _pylon(root: Node3D, team: Color) -> void:
	cyl(root, 0.85, 0.98, 0.5, Vector3(0.0, 0.25, 0.0), mat(IRON_DARK), 6)
	cyl(root, 0.5, 0.75, 1.2, Vector3(0.0, 1.1, 0.0), mat(IRON), 6)
	for i: int in 3:
		var ang: float = float(i) * TAU / 3.0
		wedge(root, Vector3(0.7, 1.3, 0.25), Vector3(cos(ang) * 0.75, 0.9, sin(ang) * 0.75), mat(IRON_DARK), 0.0, Vector3(0.0, -ang, 0.0))
	cyl(root, 0.14, 0.2, 1.3, Vector3(0.0, 2.35, 0.0), mat(BRASS, 0.0, 0.6, 0.5), 6)
	ring(root, 0.5, 0.66, Vector3(0.0, 2.5, 0.0), team_mat(team))
	ball(root, 0.2, Vector3(0.0, 3.15, 0.0), mat(team, 1.4))


static func _scrapyard(root: Node3D, team: Color) -> void:
	box(root, Vector3(5.7, 0.4, 5.7), Vector3(0.0, 0.0, 0.0), mat(IRON_DARK))
	box(root, Vector3(2.6, 1.8, 2.4), Vector3(-1.2, 1.1, -1.3), mat(IRON))
	box(root, Vector3(2.65, 0.22, 2.45), Vector3(-1.2, 1.7, -1.3), team_mat(team))
	_stack(root, Vector3(-2.0, 2.0, -2.0), 1.3, 0.24)
	# Crusher and scrap heaps.
	box(root, Vector3(1.6, 1.0, 1.6), Vector3(1.5, 0.7, -1.4), mat(IRON_DARK))
	box(root, Vector3(1.2, 0.3, 1.2), Vector3(1.5, 1.6, -1.4), mat(HAZARD))
	cyl(root, 0.1, 0.1, 0.7, Vector3(1.5, 1.3, -1.4), mat(METAL), 5)
	for k: int in 6:
		var ang: float = float(k) * 1.1
		box(root, Vector3(0.7, 0.5, 0.6), Vector3(cos(ang) * 1.3 + 0.2, 0.45 + float(k % 2) * 0.3, 1.5 + sin(ang) * 0.7), mat(RUST if k % 2 == 0 else BRASS, 0.0, 0.5, 0.6), Vector3(0.2, ang, 0.3))


static func _muster_hall(root: Node3D, team: Color) -> void:
	box(root, Vector3(5.7, 0.4, 5.7), Vector3(0.0, 0.0, 0.0), mat(IRON_DARK))
	box(root, Vector3(4.8, 1.5, 3.4), Vector3(0.0, 0.95, -0.6), mat(DRAB))
	box(root, Vector3(5.0, 0.3, 3.6), Vector3(0.0, 1.8, -0.6), mat(IRON_DARK))
	box(root, Vector3(4.85, 0.22, 3.45), Vector3(0.0, 1.45, -0.6), team_mat(team))
	for x: float in [-1.8, -0.6, 0.6, 1.8]:
		box(root, Vector3(0.35, 1.5, 0.35), Vector3(x, 0.95, 1.2), mat(IRON))
	box(root, Vector3(1.2, 1.2, 0.1), Vector3(0.0, 0.8, 1.12), mat(GUNMETAL))
	box(root, Vector3(1.4, 0.9, 1.2), Vector3(-1.8, 0.65, 2.0), mat(DRAB_DARK))
	cyl(root, 0.05, 0.05, 3.0, Vector3(2.3, 1.7, 2.1), mat(METAL), 5)
	wedge(root, Vector3(0.9, 0.6, 0.05), Vector3(2.75, 2.85, 2.1), team_mat(team), 0.0)
	_stack(root, Vector3(1.9, 1.95, -1.6), 0.9, 0.2)


static func _bastion(root: Node3D, team: Color) -> void:
	cyl(root, 0.92, 0.98, 0.7, Vector3(0.0, 0.35, 0.0), mat(IRON_DARK), 6)
	ring(root, 0.86, 0.96, Vector3(0.0, 0.7, 0.0), team_mat(team))
	var t: Node3D = _turret(root, Vector3(0.0, 0.75, 0.0))
	cyl(t, 0.6, 0.72, 0.6, Vector3(0.0, 0.3, 0.0), mat(IRON), 6)
	barrel(t, 0.14, 1.3, Vector3(0.4, 0.34, 0.0), mat(GUNMETAL))
	box(t, Vector3(0.4, 0.12, 0.5), Vector3(-0.2, 0.66, 0.0), team_mat(team))


static func _skyspike(root: Node3D, team: Color) -> void:
	cyl(root, 0.88, 0.98, 0.5, Vector3(0.0, 0.25, 0.0), mat(IRON_DARK), 6)
	cyl(root, 0.4, 0.55, 0.7, Vector3(0.0, 0.85, 0.0), mat(IRON), 6)
	ring(root, 0.84, 0.92, Vector3(0.0, 0.5, 0.0), team_mat(team))
	var t: Node3D = _turret(root, Vector3(0.0, 1.2, 0.0))
	box(t, Vector3(0.6, 0.5, 1.0), Vector3(0.0, 0.25, 0.0), mat(IRON_DARK))
	for z: float in [-0.35, 0.0, 0.35]:
		cyl(t, 0.02, 0.06, 1.7, Vector3(0.45, 0.95, z), mat(BRASS, 0.0, 0.6, 0.5), 5, Vector3(0.0, 0.0, -0.6))
	box(t, Vector3(0.3, 0.1, 1.02), Vector3(-0.1, 0.52, 0.0), team_mat(team))


static func _arsenal(root: Node3D, team: Color) -> void:
	box(root, Vector3(5.7, 0.4, 5.7), Vector3(0.0, 0.0, 0.0), mat(IRON_DARK))
	box(root, Vector3(4.6, 2.2, 4.0), Vector3(0.0, 1.3, -0.3), mat(IRON))
	box(root, Vector3(4.65, 0.3, 4.05), Vector3(0.0, 1.9, -0.3), team_mat(team))
	wedge(root, Vector3(4.0, 1.0, 4.6), Vector3(0.0, 2.9, -0.3), mat(IRON_DARK), 0.5, Vector3(0.0, PI * 0.5, 0.0))
	box(root, Vector3(2.2, 1.6, 0.14), Vector3(0.0, 1.0, 1.75), mat(GUNMETAL))
	box(root, Vector3(2.6, 0.2, 0.2), Vector3(0.0, 1.9, 1.8), mat(HAZARD))
	_stack(root, Vector3(-1.8, 2.4, -1.8), 2.0, 0.3)
	_stack(root, Vector3(1.8, 2.4, -1.8), 2.0, 0.3)
	cyl(root, 0.7, 0.7, 0.14, Vector3(0.0, 2.6, 1.72), mat(BRASS, 0.0, 0.7, 0.4), 8, Vector3(PI * 0.5, 0.0, 0.0))
	box(root, Vector3(1.0, 0.6, 0.9), Vector3(2.1, 0.7, 2.1), mat(RUST, 0.0, 0.4, 0.7))


# ------------------------------------------------------------ Nomad Circuit

static func _tent(parent: Node3D, length_x: float, height: float, width_z: float, pos: Vector3, color: Color) -> void:
	roof(parent, length_x, height, width_z, pos + Vector3(0.0, height * 0.5, 0.0), mat(color, 0.0, 0.0, 1.0))


## The shared light buggy chassis (Gnat, Jammer Buggy).
static func _buggy(root: Node3D, team: Color) -> void:
	box(root, Vector3(1.6, 0.25, 0.9), Vector3(0.0, 0.5, 0.0), mat(SAND_DARK))
	wedge(root, Vector3(0.6, 0.3, 0.85), Vector3(0.55, 0.78, 0.0), mat(SAND), 0.0)
	box(root, Vector3(1.62, 0.08, 0.92), Vector3(0.0, 0.62, 0.0), team_mat(team))
	for bar: float in [-0.4, 0.4]:
		box(root, Vector3(1.0, 0.05, 0.05), Vector3(-0.2, 1.0, bar), mat(METAL))
		box(root, Vector3(0.05, 0.4, 0.05), Vector3(-0.68, 0.82, bar), mat(METAL))
		box(root, Vector3(0.05, 0.4, 0.05), Vector3(0.28, 0.82, bar), mat(METAL))
	for x: float in [-0.55, 0.55]:
		wheel(root, 0.34, 0.24, Vector3(x, 0.34, 0.55))
		wheel(root, 0.34, 0.24, Vector3(x, 0.34, -0.55))


static func _skiff(root: Node3D, team: Color) -> void:
	box(root, Vector3(1.9, 0.25, 1.0), Vector3(0.0, 0.48, 0.0), mat(SAND_DARK))
	box(root, Vector3(0.55, 0.5, 0.95), Vector3(0.62, 0.85, 0.0), mat(SAND))
	box(root, Vector3(1.1, 0.4, 1.05), Vector3(-0.35, 0.8, 0.0), mat(PATCH))
	box(root, Vector3(1.12, 0.1, 1.07), Vector3(-0.35, 1.0, 0.0), team_mat(team))
	_cargo(root, Vector3(-0.35, 1.0, 0.0), Vector3(0.9, 0.45, 0.85))
	for x: float in [-0.6, 0.6]:
		wheel(root, 0.32, 0.22, Vector3(x, 0.32, 0.55))
		wheel(root, 0.32, 0.22, Vector3(x, 0.32, -0.55))


static func _dart(root: Node3D, team: Color) -> void:
	wheel(root, 0.34, 0.16, Vector3(0.55, 0.34, 0.0))
	wheel(root, 0.34, 0.16, Vector3(-0.55, 0.34, 0.0))
	box(root, Vector3(1.0, 0.22, 0.26), Vector3(0.0, 0.6, 0.0), mat(SAND))
	wedge(root, Vector3(0.5, 0.3, 0.3), Vector3(0.45, 0.82, 0.0), mat(SAND_DARK), 0.0)
	box(root, Vector3(0.5, 0.08, 0.28), Vector3(-0.2, 0.74, 0.0), team_mat(team))
	box(root, Vector3(0.26, 0.4, 0.3), Vector3(-0.15, 0.98, 0.0), mat(SAND_DARK))
	ball(root, 0.14, Vector3(-0.1, 1.28, 0.0), mat(GUNMETAL), 6)
	var t: Node3D = _turret(root, Vector3(0.35, 0.7, 0.0))
	barrel(t, 0.03, 0.5, Vector3(0.1, 0.0, 0.14), mat(GUNMETAL))
	barrel(t, 0.03, 0.5, Vector3(0.1, 0.0, -0.14), mat(GUNMETAL))


static func _sidewinder(root: Node3D, team: Color) -> void:
	box(root, Vector3(2.0, 0.28, 1.05), Vector3(0.0, 0.5, 0.0), mat(SAND_DARK))
	box(root, Vector3(0.6, 0.55, 1.0), Vector3(0.68, 0.9, 0.0), mat(SAND))
	box(root, Vector3(0.05, 0.2, 0.8), Vector3(1.0, 1.0, 0.0), mat(GLASS, 0.15, 0.3, 0.2))
	box(root, Vector3(2.02, 0.08, 1.07), Vector3(0.0, 0.64, 0.0), team_mat(team))
	for x: float in [-0.65, 0.65]:
		wheel(root, 0.33, 0.24, Vector3(x, 0.33, 0.58))
		wheel(root, 0.33, 0.24, Vector3(x, 0.33, -0.58))
	var t: Node3D = _turret(root, Vector3(-0.45, 0.85, 0.0))
	box(t, Vector3(0.3, 0.3, 0.3), Vector3(0.0, 0.15, 0.0), mat(METAL))
	for z: float in [-0.28, 0.28]:
		box(t, Vector3(1.2, 0.22, 0.22), Vector3(0.1, 0.5, z), mat(PATCH), Vector3(0.0, 0.0, 0.25))
		box(t, Vector3(0.1, 0.16, 0.16), Vector3(0.68, 0.65, z), mat(HAZARD), Vector3(0.0, 0.0, 0.25))


static func _prowler(root: Node3D, team: Color) -> void:
	for x: float in [-0.75, 0.0, 0.75]:
		wheel(root, 0.36, 0.28, Vector3(x, 0.36, 0.68))
		wheel(root, 0.36, 0.28, Vector3(x, 0.36, -0.68))
	box(root, Vector3(2.3, 0.5, 1.2), Vector3(0.0, 0.7, 0.0), mat(SAND))
	wedge(root, Vector3(0.6, 0.5, 1.2), Vector3(1.45, 0.7, 0.0), mat(SAND), 0.0)
	box(root, Vector3(2.32, 0.1, 1.22), Vector3(0.0, 0.56, 0.0), team_mat(team))
	box(root, Vector3(0.6, 0.3, 0.9), Vector3(-0.9, 1.05, 0.0), mat(CANVAS, 0.0, 0.0, 1.0))
	var t: Node3D = _turret(root, Vector3(0.1, 0.95, 0.0))
	box(t, Vector3(0.95, 0.4, 0.9), Vector3(0.0, 0.2, 0.0), mat(SAND_DARK))
	barrel(t, 0.07, 1.3, Vector3(0.45, 0.22, 0.0), mat(GUNMETAL))
	box(t, Vector3(0.3, 0.08, 0.4), Vector3(-0.2, 0.44, 0.0), team_mat(team))


static func _beacon_rig(root: Node3D, team: Color) -> void:
	box(root, Vector3(2.0, 0.28, 1.05), Vector3(0.0, 0.5, 0.0), mat(SAND_DARK))
	box(root, Vector3(0.6, 0.55, 1.0), Vector3(0.68, 0.9, 0.0), mat(SAND))
	box(root, Vector3(2.02, 0.08, 1.07), Vector3(0.0, 0.64, 0.0), team_mat(team))
	for x: float in [-0.65, 0.65]:
		wheel(root, 0.33, 0.24, Vector3(x, 0.33, 0.58))
		wheel(root, 0.33, 0.24, Vector3(x, 0.33, -0.58))
	# Folded mast lying along the bed.
	cyl(root, 0.07, 0.1, 1.6, Vector3(-0.4, 1.0, 0.0), mat(METAL, 0.0, 0.6, 0.4), 6, Vector3(0.0, 0.0, -PI * 0.5 + 0.12))
	ring(root, 0.28, 0.36, Vector3(-1.0, 1.08, 0.0), team_mat(team))


static func _beacon(root: Node3D, team: Color) -> void:
	box(root, Vector3(1.7, 0.3, 1.0), Vector3(0.0, 0.25, 0.0), mat(SAND_DARK))
	for i: int in 4:
		var ang: float = float(i) * TAU / 4.0 + 0.78
		box(root, Vector3(1.3, 0.06, 0.08), Vector3(cos(ang) * 0.6, 0.35, sin(ang) * 0.6), mat(METAL), Vector3(0.0, -ang, 0.3))
	cyl(root, 0.08, 0.14, 3.4, Vector3(0.0, 2.1, 0.0), mat(METAL, 0.0, 0.6, 0.4), 6)
	ring(root, 0.5, 0.62, Vector3(0.0, 2.9, 0.0), team_mat(team))
	ring(root, 0.3, 0.4, Vector3(0.0, 3.5, 0.0), team_mat(team))
	ball(root, 0.18, Vector3(0.0, 3.95, 0.0), mat(team, 1.4))
	wedge(root, Vector3(0.7, 0.45, 0.04), Vector3(0.4, 2.3, 0.0), mat(CANVAS, 0.0, 0.0, 1.0), 0.0)


## The Caravan on the road, or deployed as the Caravan Hub.
static func _caravan(root: Node3D, team: Color, deployed: bool) -> void:
	if not deployed:
		for x: float in [-1.5, -0.5, 0.5, 1.5]:
			wheel(root, 0.5, 0.4, Vector3(x, 0.5, 1.15))
			wheel(root, 0.5, 0.4, Vector3(x, 0.5, -1.15))
		box(root, Vector3(4.2, 0.5, 2.2), Vector3(0.0, 0.85, 0.0), mat(SAND_DARK))
		box(root, Vector3(2.8, 1.3, 2.1), Vector3(-0.5, 1.75, 0.0), mat(SAND))
		_tent(root, 2.8, 0.6, 2.1, Vector3(-0.5, 2.4, 0.0), CANVAS)
		box(root, Vector3(1.0, 0.9, 2.0), Vector3(1.55, 1.55, 0.0), mat(SAND_DARK))
		box(root, Vector3(0.06, 0.35, 1.6), Vector3(2.07, 1.7, 0.0), mat(GLASS, 0.15, 0.3, 0.2))
		box(root, Vector3(4.22, 0.14, 2.22), Vector3(0.0, 1.12, 0.0), team_mat(team))
		cyl(root, 0.1, 0.14, 1.8, Vector3(-1.4, 3.3, 0.6), mat(METAL), 6)
		ball(root, 0.2, Vector3(-1.4, 4.3, 0.6), mat(team, 1.4))
		return
	box(root, Vector3(7.7, 0.4, 7.7), Vector3(0.0, 0.0, 0.0), mat(SAND_DARK))
	# The parked crawler-truck in the middle with tents pitched around it.
	box(root, Vector3(4.2, 1.6, 2.4), Vector3(0.0, 1.1, 0.0), mat(SAND))
	box(root, Vector3(4.25, 0.3, 2.45), Vector3(0.0, 1.5, 0.0), team_mat(team))
	_tent(root, 4.2, 0.9, 2.4, Vector3(0.0, 1.9, 0.0), CANVAS)
	for sz: float in [-1.0, 1.0]:
		_tent(root, 5.0, 1.4, 2.2, Vector3(0.0, 0.2, sz * 2.5), CANVAS.darkened(0.12))
		box(root, Vector3(1.0, 0.7, 0.8), Vector3(-2.6, 0.55, sz * 2.6), mat(PATCH))
	for sx: float in [-1.0, 1.0]:
		box(root, Vector3(0.9, 0.9, 0.9), Vector3(sx * 3.2, 0.65, 0.0), mat(RUST, 0.0, 0.4, 0.7))
	cyl(root, 0.16, 0.26, 4.2, Vector3(1.0, 4.4, 0.6), mat(METAL, 0.0, 0.6, 0.4), 6)
	ring(root, 0.75, 0.9, Vector3(1.0, 5.2, 0.6), team_mat(team))
	ring(root, 0.45, 0.58, Vector3(1.0, 5.9, 0.6), team_mat(team))
	ball(root, 0.24, Vector3(1.0, 6.6, 0.6), mat(team, 1.4))
	var t: Node3D = _turret(root, Vector3(-1.2, 2.9, -0.5))
	box(t, Vector3(0.7, 0.4, 0.6), Vector3(0.0, 0.2, 0.0), mat(SAND_DARK))
	barrel(t, 0.06, 0.9, Vector3(0.3, 0.24, 0.12), mat(GUNMETAL))
	barrel(t, 0.06, 0.9, Vector3(0.3, 0.24, -0.12), mat(GUNMETAL))


static func _cache(root: Node3D, team: Color) -> void:
	box(root, Vector3(3.8, 0.3, 3.8), Vector3(0.0, 0.0, 0.0), mat(SAND_DARK))
	_tent(root, 2.6, 1.2, 2.2, Vector3(-0.3, 0.15, -0.5), CANVAS)
	box(root, Vector3(2.65, 0.14, 0.1), Vector3(-0.3, 0.5, 0.62), team_mat(team))
	box(root, Vector3(0.9, 0.7, 0.8), Vector3(1.2, 0.5, 1.1), mat(RUST, 0.0, 0.4, 0.7))
	box(root, Vector3(0.9, 0.7, 0.8), Vector3(0.2, 0.5, 1.25), mat(PATCH))
	box(root, Vector3(0.8, 0.6, 0.7), Vector3(0.7, 1.15, 1.15), mat(SAND))
	cyl(root, 0.04, 0.04, 2.2, Vector3(1.5, 1.2, -1.5), mat(METAL), 5)
	wedge(root, Vector3(0.7, 0.45, 0.04), Vector3(1.86, 2.0, -1.5), team_mat(team), 0.0)


static func _camp(root: Node3D, team: Color) -> void:
	box(root, Vector3(5.7, 0.3, 5.7), Vector3(0.0, 0.0, 0.0), mat(SAND_DARK))
	_tent(root, 4.4, 1.7, 2.6, Vector3(0.0, 0.15, -1.2), CANVAS)
	box(root, Vector3(4.45, 0.16, 0.1), Vector3(0.0, 0.6, 0.12), team_mat(team))
	_tent(root, 1.8, 1.1, 1.6, Vector3(-1.6, 0.15, 1.6), CANVAS.darkened(0.15))
	_tent(root, 1.8, 1.1, 1.6, Vector3(0.6, 0.15, 1.7), CANVAS.darkened(0.08))
	cyl(root, 0.3, 0.36, 0.3, Vector3(2.1, 0.3, 1.4), mat(GUNMETAL), 6)
	cyl(root, 0.2, 0.05, 0.4, Vector3(2.1, 0.6, 1.4), mat(FURNACE, 1.6), 5)
	cyl(root, 0.05, 0.05, 3.0, Vector3(2.4, 1.6, -2.3), mat(METAL), 5)
	wedge(root, Vector3(0.9, 0.55, 0.04), Vector3(2.86, 2.8, -2.3), team_mat(team), 0.0)


static func _chop_shop(root: Node3D, team: Color) -> void:
	box(root, Vector3(5.7, 0.3, 5.7), Vector3(0.0, 0.0, 0.0), mat(SAND_DARK))
	box(root, Vector3(4.6, 1.8, 2.6), Vector3(0.0, 1.05, -1.2), mat(SAND))
	box(root, Vector3(4.8, 0.2, 3.0), Vector3(0.0, 2.05, -1.1), mat(PATCH), Vector3(0.12, 0.0, 0.0))
	box(root, Vector3(4.65, 0.2, 2.65), Vector3(0.0, 1.5, -1.2), team_mat(team))
	box(root, Vector3(2.4, 1.4, 0.1), Vector3(0.0, 0.85, 0.12), mat(GUNMETAL))
	# Half-built vehicle on stands in the yard.
	box(root, Vector3(1.6, 0.3, 0.9), Vector3(-0.8, 0.75, 1.6), mat(SAND_DARK))
	for x: float in [-1.4, -0.2]:
		box(root, Vector3(0.2, 0.5, 0.2), Vector3(x, 0.4, 1.6), mat(METAL))
	wheel(root, 0.34, 0.24, Vector3(1.2, 0.5, 1.9))
	wheel(root, 0.34, 0.24, Vector3(1.6, 0.34, 1.3))
	box(root, Vector3(0.9, 0.7, 0.8), Vector3(2.1, 0.5, -0.2), mat(RUST, 0.0, 0.4, 0.7))
	cyl(root, 0.1, 0.1, 2.6, Vector3(-2.3, 1.5, 0.6), mat(HAZARD), 5)
	box(root, Vector3(1.4, 0.12, 0.12), Vector3(-1.7, 2.7, 0.6), mat(HAZARD))


static func _signal_loom(root: Node3D, team: Color) -> void:
	box(root, Vector3(5.7, 0.3, 5.7), Vector3(0.0, 0.0, 0.0), mat(SAND_DARK))
	cyl(root, 1.9, 2.2, 1.2, Vector3(0.0, 0.75, 0.0), mat(SAND), 8)
	cyl(root, 1.95, 1.95, 0.2, Vector3(0.0, 1.2, 0.0), team_mat(team), 8)
	for i: int in 6:
		var ang: float = float(i) * TAU / 6.0
		var p: Vector3 = Vector3(cos(ang) * 1.5, 0.0, sin(ang) * 1.5)
		cyl(root, 0.04, 0.06, 3.2, p + Vector3(0.0, 2.9, 0.0), mat(METAL, 0.0, 0.6, 0.4), 4, Vector3(sin(ang) * 0.22, 0.0, -cos(ang) * 0.22))
	ring(root, 1.3, 1.42, Vector3(0.0, 3.2, 0.0), team_mat(team))
	ring(root, 0.85, 0.95, Vector3(0.0, 3.9, 0.0), mat(Color(0.6, 1.0, 0.9), 1.2))
	ball(root, 0.3, Vector3(0.0, 4.5, 0.0), mat(team, 1.5))
	_tent(root, 1.6, 0.9, 1.4, Vector3(2.0, 0.15, 2.0), CANVAS)


# ------------------------------------------------------------------ detail

## Headlamps either side of the nose and, usually, a bumper under them.
static func _front(root: Node3D, x: float, y: float, z: float, bumper: bool = true) -> void:
	lamp(root, Vector3(x, y, z))
	lamp(root, Vector3(x, y, -z))
	if bumper:
		box(root, Vector3(0.1, 0.14, z * 2.0 + 0.4), Vector3(x + 0.03, y - 0.24, 0.0), mat(GUNMETAL))


static func _tail(root: Node3D, x: float, y: float, z: float) -> void:
	lamp(root, Vector3(x, y, z), LAMP_RED, 0.09)
	lamp(root, Vector3(x, y, -z), LAMP_RED, 0.09)


## A lamp on a pole, for yards and camps.
static func _pole_lamp(root: Node3D, pos: Vector3, height: float, color: Color = LAMP) -> void:
	cyl(root, 0.035, 0.05, height, pos + Vector3(0.0, height * 0.5, 0.0), mat(GUNMETAL), 5)
	box(root, Vector3(0.2, 0.12, 0.2), pos + Vector3(0.0, height, 0.0), mat(color, 1.6))


## Arms that circle a mast with a small panel on each end, in a "Spin" group.
static func _spin_arms(root: Node3D, pos: Vector3, reach: float, panel: Color = METAL) -> void:
	var g: Node3D = group(root, "Spin", pos)
	box(g, Vector3(reach * 2.0, 0.05, 0.05), Vector3.ZERO, mat(GUNMETAL))
	for sx: float in [-1.0, 1.0]:
		box(g, Vector3(0.07, 0.32, 0.42), Vector3(sx * reach, 0.0, 0.0), mat(panel, 0.0, 0.6, 0.4))
		box(g, Vector3(0.06, 0.06, 0.06), Vector3(sx * reach, 0.2, 0.0), mat(LAMP_RED, 1.8))


## Small parts added on top of the basic shapes: lamps, hatches, windows,
## aerials, exhausts, radar. Kept apart from the builders so those stay
## readable.
static func _detail(model: String, root: Node3D, team: Color) -> void:
	var t: Node3D = root.get_node_or_null("Turret") as Node3D
	var glass: StandardMaterial3D = mat(GLASS, 0.15, 0.3, 0.2)
	match model:
		# ------------------------------------------------ Aegis Directorate
		"hauler":
			_front(root, 1.09, 0.74, 0.42)
			_tail(root, -1.1, 0.74, 0.5)
			box(root, Vector3(0.36, 0.26, 0.03), Vector3(0.74, 1.1, 0.585), glass)
			box(root, Vector3(0.36, 0.26, 0.03), Vector3(0.74, 1.1, -0.585), glass)
			box(root, Vector3(0.16, 0.08, 0.3), Vector3(0.7, 1.36, 0.0), mat(HAZARD, 1.2))
			cyl(root, 0.05, 0.05, 0.5, Vector3(0.3, 1.5, 0.5), mat(GUNMETAL), 5)
		"courser":
			_front(root, 0.86, 0.62, 0.32)
			_tail(root, -0.86, 0.6, 0.34)
			aerial(root, Vector3(-0.7, 0.7, 0.36), 1.0)
			box(root, Vector3(0.05, 0.2, 0.7), Vector3(0.3, 0.92, 0.0), glass)
		"warden":
			lamp(root, Vector3(1.02, 0.9, 0.5))
			lamp(root, Vector3(1.02, 0.9, -0.5))
			_tail(root, -1.11, 0.62, 0.5)
			hatch(root, Vector3(0.62, 0.98, 0.34), 0.18)
			aerial(root, Vector3(-0.95, 0.96, -0.5), 1.1)
			barrel(root, 0.07, 0.3, Vector3(-1.4, 0.78, 0.42), mat(GUNMETAL))
			box(root, Vector3(0.5, 0.2, 0.3), Vector3(-0.8, 1.05, 0.4), mat(HULL_DARK))
		"bulwark":
			lamp(root, Vector3(1.08, 0.86, 0.52))
			lamp(root, Vector3(1.08, 0.86, -0.52))
			box(root, Vector3(0.7, 0.04, 0.9), Vector3(-0.85, 0.93, 0.0), mat(GUNMETAL))
			for z: float in [-0.4, 0.4]:
				barrel(root, 0.07, 0.25, Vector3(-1.45, 0.72, z), mat(GUNMETAL))
			for z: float in [-0.96, 0.96]:
				box(root, Vector3(2.3, 0.24, 0.04), Vector3(0.0, 0.5, z), mat(HULL_DARK))
			if t != null:
				hatch(t, Vector3(-0.3, 0.49, 0.28), 0.2)
				box(t, Vector3(0.25, 0.3, 0.45), Vector3(0.9, 0.24, 0.0), mat(GUNMETAL))
				cyl(t, 0.13, 0.13, 0.26, Vector3(2.55, 0.24, 0.0), mat(GUNMETAL), 6, Vector3(0.0, 0.0, -PI * 0.5))
				box(t, Vector3(0.3, 0.26, 0.9), Vector3(-0.76, 0.2, 0.0), mat(HULL))
		"tempest":
			lamp(root, Vector3(1.03, 0.8, 0.48))
			lamp(root, Vector3(1.03, 0.8, -0.48))
			if t != null:
				for z: float in [-0.6, 0.6]:
					box(t, Vector3(0.4, 0.3, 0.2), Vector3(-0.15, 0.3, z), mat(HULL))
		"longbow":
			_front(root, 1.21, 0.76, 0.5, false)
			box(root, Vector3(0.04, 0.22, 0.8), Vector3(1.11, 1.16, 0.0), glass)
			for i: int in 3:
				cyl(root, 0.07, 0.07, 0.4, Vector3(-0.95 + 0.2 * float(i), 1.09, 0.42), mat(BRASS, 0.0, 0.6, 0.5), 6)
			aerial(root, Vector3(0.5, 1.35, -0.45), 0.9)
		"kestrel":
			lamp(root, Vector3(0.1, 0.5, 1.22), Color(0.3, 1.0, 0.4), 0.08)
			lamp(root, Vector3(0.1, 0.5, -1.22), LAMP_RED, 0.08)
			lamp(root, Vector3(-2.36, 1.12, 0.0), LAMP, 0.07)
			for z: float in [-0.42, 0.42]:
				box(root, Vector3(1.5, 0.05, 0.07), Vector3(0.2, 0.05, z), mat(GUNMETAL))
				for x: float in [-0.25, 0.65]:
					box(root, Vector3(0.05, 0.2, 0.05), Vector3(x, 0.14, z), mat(GUNMETAL))
			cyl(root, 0.32, 0.32, 0.03, Vector3(-2.3, 0.84, 0.16), mat(GUNMETAL), 8, Vector3(PI * 0.5, 0.0, 0.0))
		"scout_drone":
			lamp(root, Vector3(-0.32, 0.3, 0.0), LAMP_RED, 0.06)
		"hq":
			var pane: Vector3 = Vector3(0.55, 0.4, 0.06)
			var pane_x: Vector3 = Vector3(0.06, 0.4, 0.55)
			for side: float in [-1.0, 1.0]:
				windows(root, Vector3(-2.0, 1.45, side * 2.72), Vector3(1.0, 0.0, 0.0), 5, pane)
				windows(root, Vector3(-1.0, 3.55, side * 1.72), Vector3(1.0, 0.0, 0.0), 3, pane)
				windows(root, Vector3(side * 1.72, 3.55, -1.0), Vector3(0.0, 0.0, 1.0), 3, pane_x)
			windows(root, Vector3(-2.72, 1.45, -2.0), Vector3(0.0, 0.0, 1.0), 5, pane_x)
			windows(root, Vector3(2.72, 1.45, -2.0), Vector3(0.0, 0.0, 0.8), 2, pane_x)
			windows(root, Vector3(2.72, 1.45, 1.2), Vector3(0.0, 0.0, 0.8), 2, pane_x)
			box(root, Vector3(0.9, 0.4, 0.7), Vector3(0.9, 4.6, -0.9), mat(METAL, 0.0, 0.6, 0.45))
			box(root, Vector3(0.6, 0.05, 0.4), Vector3(0.9, 4.82, -0.9), mat(GUNMETAL))
			radar(root, Vector3(-0.9, 4.4, 0.9), 1.2)
			box(root, Vector3(0.5, 0.3, 0.5), Vector3(2.2, 2.95, -1.2), mat(METAL, 0.0, 0.6, 0.45))
			box(root, Vector3(0.3, 0.24, 1.3), Vector3(-2.2, 2.92, 0.6), mat(HULL_DARK))
			box(root, Vector3(0.8, 0.16, 2.2), Vector3(3.35, 0.33, 0.0), mat(CONCRETE))
			lamp(root, Vector3(2.76, 1.6, 0.0), LAMP, 0.16)
			for sx: float in [-1.0, 1.0]:
				for sz: float in [-1.0, 1.0]:
					aerial(root, Vector3(sx * 3.1, 1.92, sz * 3.1), 0.7, team)
		"depot":
			for side: float in [-1.0, 1.0]:
				windows(root, Vector3(side * 2.22, 1.35, -1.9), Vector3(0.0, 0.0, 0.9), 3, Vector3(0.06, 0.35, 0.5))
			lamp(root, Vector3(0.0, 1.66, 0.56), LAMP, 0.14)
			box(root, Vector3(0.4, 0.3, 0.4), Vector3(1.2, 2.95, -1.0), mat(METAL, 0.0, 0.6, 0.45))
			box(root, Vector3(5.0, 0.03, 0.2), Vector3(0.0, 0.21, 2.6), mat(HAZARD))
			for z: float in [0.9, 1.6]:
				cyl(root, 0.28, 0.28, 0.7, Vector3(2.35, 0.55, z), mat(HULL_DARK), 8)
				cyl(root, 0.29, 0.29, 0.1, Vector3(2.35, 0.7, z), team_mat(team), 8)
		"relay":
			_spin_arms(root, Vector3(0.0, 2.75, 0.0), 0.5)
			lamp(root, Vector3(0.0, 1.14, 0.0), LAMP_RED, 0.1)
		"barracks":
			windows(root, Vector3(1.0, 1.2, 1.03), Vector3(0.7, 0.0, 0.0), 2, Vector3(0.4, 0.35, 0.06))
			for side: float in [-1.0, 1.0]:
				windows(root, Vector3(side * 2.42, 1.2, -1.7), Vector3(0.0, 0.0, 0.8), 3, Vector3(0.06, 0.35, 0.45))
			lamp(root, Vector3(0.0, 1.56, 1.06), LAMP, 0.13)
			for i: int in 3:
				box(root, Vector3(0.8, 0.28, 0.32), Vector3(0.2 + 0.85 * float(i), 0.34, 2.65), mat(SAND_DARK, 0.0, 0.0, 1.0))
			box(root, Vector3(0.5, 0.26, 0.3), Vector3(1.05, 0.6, 2.65), mat(SAND_DARK, 0.0, 0.0, 1.0))
		"vehicle_works":
			windows(root, Vector3(-3.0, 1.55, 1.73), Vector3(0.55, 0.0, 0.0), 2, Vector3(0.38, 0.5, 0.06))
			windows(root, Vector3(1.6, 1.55, 1.73), Vector3(0.55, 0.0, 0.0), 2, Vector3(0.38, 0.5, 0.06))
			windows(root, Vector3(-3.52, 1.55, -1.9), Vector3(0.0, 0.0, 1.0), 4, Vector3(0.06, 0.5, 0.5))
			lamp(root, Vector3(-2.2, 2.0, 1.78), LAMP, 0.14)
			lamp(root, Vector3(1.4, 2.0, 1.78), LAMP, 0.14)
			box(root, Vector3(3.0, 0.03, 0.12), Vector3(-0.4, 0.21, 2.6), mat(HAZARD))
			for y: float in [0.35, 0.62]:
				cyl(root, 0.34, 0.34, 0.26, Vector3(-3.3, y, 2.3), mat(RUBBER), 10)
		"sentry_turret", "lance_battery", "flak_post":
			lamp(root, Vector3(0.0, 0.56, 0.84), team, 0.1)
			box(root, Vector3(0.35, 0.22, 0.25), Vector3(-0.6, 0.6, 0.35), mat(HULL_DARK))
		"command_lab":
			radar(root, Vector3(-1.75, 1.8, 1.75), 1.0)
			windows(root, Vector3(-1.7, 1.0, 2.22), Vector3(0.6, 0.0, 0.0), 2, Vector3(0.4, 0.4, 0.06))
			windows(root, Vector3(1.1, 1.0, 2.22), Vector3(0.6, 0.0, 0.0), 2, Vector3(0.4, 0.4, 0.06))
			for side: float in [-1.0, 1.0]:
				windows(root, Vector3(side * 2.22, 1.0, -1.5), Vector3(0.0, 0.0, 1.0), 4, Vector3(0.06, 0.4, 0.5))
			lamp(root, Vector3(0.0, 1.42, 2.26), LAMP, 0.12)
		"airpad":
			for i: int in 8:
				var ang: float = float(i) * TAU / 8.0 + 0.39
				lamp(root, Vector3(0.6 + cos(ang) * 2.2, 0.3, 0.6 + sin(ang) * 2.2), team, 0.12)
			windows(root, Vector3(-1.18, 1.0, -1.8), Vector3(0.0, 0.0, 1.2), 4, Vector3(0.06, 0.4, 0.6))
			aerial(root, Vector3(2.2, 3.25, -2.2), 0.8)
		# ----------------------------------------------------- Foundry Pact
		"scow":
			_front(root, 1.2, 0.8, 0.45)
			_tail(root, -1.2, 0.8, 0.5)
			_stack(root, Vector3(0.35, 1.45, 0.52), 0.5, 0.07)
		"ratchet":
			_front(root, 1.06, 0.76, 0.42)
			box(root, Vector3(0.14, 0.08, 0.3), Vector3(0.7, 1.37, 0.0), mat(HAZARD, 1.2))
			box(root, Vector3(0.05, 0.22, 0.8), Vector3(1.06, 1.1, 0.0), glass)
		"tusk":
			lamp(root, Vector3(1.08, 1.0, 0.5), WINDOW_WARM)
			lamp(root, Vector3(1.08, 1.0, -0.5), WINDOW_WARM)
			if t != null:
				hatch(t, Vector3(-0.25, 0.53, 0.3), 0.2, IRON)
				box(t, Vector3(0.25, 0.36, 0.5), Vector3(0.62, 0.26, 0.0), mat(GUNMETAL))
		"harrow":
			lamp(root, Vector3(1.14, 0.8, 0.45), WINDOW_WARM)
			lamp(root, Vector3(1.14, 0.8, -0.45), WINDOW_WARM)
			box(root, Vector3(0.05, 0.2, 0.8), Vector3(1.06, 1.18, 0.0), glass)
		"anvil":
			lamp(root, Vector3(1.14, 0.86, 0.5), WINDOW_WARM)
			lamp(root, Vector3(1.14, 0.86, -0.5), WINDOW_WARM)
			box(root, Vector3(0.05, 0.22, 0.9), Vector3(1.11, 1.26, 0.0), glass)
			for i: int in 3:
				cyl(root, 0.1, 0.1, 0.36, Vector3(-1.0 + 0.24 * float(i), 1.13, 0.45), mat(BRASS, 0.0, 0.6, 0.5), 6)
		"mauler":
			lamp(root, Vector3(1.33, 1.14, 0.6), WINDOW_WARM)
			lamp(root, Vector3(1.33, 1.14, -0.6), WINDOW_WARM)
			for z: float in [-1.17, 1.17]:
				box(root, Vector3(2.9, 0.3, 0.05), Vector3(0.0, 0.62, z), mat(IRON_DARK))
			if t != null:
				hatch(t, Vector3(-0.3, 0.63, -0.35), 0.22, IRON)
				box(t, Vector3(0.3, 0.42, 0.6), Vector3(1.2, 0.32, 0.0), mat(GUNMETAL))
				box(t, Vector3(0.36, 0.3, 1.1), Vector3(-0.95, 0.25, 0.0), mat(IRON))
		"crawler":
			_front(root, 1.62, 1.15, 0.7, false)
			aerial(root, Vector3(0.9, 2.1, -0.6), 1.0, FURNACE)
			box(root, Vector3(0.5, 0.3, 1.2), Vector3(-0.2, 1.65, 0.0), mat(IRON_DARK))
		"crawler_factory":
			windows(root, Vector3(-1.5, 0.78, -0.28), Vector3(1.0, 0.0, 0.0), 4, Vector3(0.45, 0.3, 0.06), WINDOW_WARM)
			_pole_lamp(root, Vector3(2.5, 0.2, 2.5), 1.8, WINDOW_WARM)
		"foundry_core":
			var warm: Vector3 = Vector3(0.4, 0.32, 0.06)
			windows(root, Vector3(-2.4, 1.85, 3.02), Vector3(0.65, 0.0, 0.0), 2, warm, WINDOW_WARM)
			windows(root, Vector3(1.75, 1.85, 3.02), Vector3(0.65, 0.0, 0.0), 2, warm, WINDOW_WARM)
			windows(root, Vector3(-2.0, 1.85, -3.02), Vector3(1.0, 0.0, 0.0), 5, warm, WINDOW_WARM)
			for side: float in [-1.0, 1.0]:
				windows(root, Vector3(-1.0, 3.4, side * 2.02), Vector3(1.0, 0.0, 0.0), 3, warm, WINDOW_WARM)
				windows(root, Vector3(side * 2.02, 3.4, -1.0), Vector3(0.0, 0.0, 1.0), 3, Vector3(0.06, 0.32, 0.4), WINDOW_WARM)
			barrel(root, 0.13, 3.2, Vector3(-1.6, 2.78, 2.7), mat(BRASS, 0.0, 0.6, 0.5))
			_spin_arms(root, Vector3(1.2, 5.4, 1.2), 0.6, BRASS)
			box(root, Vector3(2.6, 0.2, 0.9), Vector3(0.0, 0.34, 3.5), mat(IRON))
		"pylon":
			lamp(root, Vector3(0.0, 1.75, 0.66), FURNACE, 0.1)
		"scrapyard":
			windows(root, Vector3(-1.8, 1.2, -0.08), Vector3(0.75, 0.0, 0.0), 2, Vector3(0.42, 0.34, 0.06), WINDOW_WARM)
			_pole_lamp(root, Vector3(2.5, 0.2, 2.5), 2.0, WINDOW_WARM)
		"muster_hall":
			windows(root, Vector3(-1.2, 1.05, 1.11), Vector3(2.4, 0.0, 0.0), 2, Vector3(0.5, 0.4, 0.06), WINDOW_WARM)
			for side: float in [-1.0, 1.0]:
				windows(root, Vector3(side * 2.42, 1.0, -1.6), Vector3(0.0, 0.0, 0.9), 3, Vector3(0.06, 0.36, 0.45), WINDOW_WARM)
			lamp(root, Vector3(0.0, 1.55, 1.3), WINDOW_WARM, 0.14)
		"arsenal":
			for side: float in [-1.0, 1.0]:
				windows(root, Vector3(side * 2.32, 1.3, -1.7), Vector3(0.0, 0.0, 0.9), 4, Vector3(0.06, 0.4, 0.45), WINDOW_WARM)
			lamp(root, Vector3(-1.5, 1.6, 1.8), WINDOW_WARM, 0.14)
			lamp(root, Vector3(1.5, 1.6, 1.8), WINDOW_WARM, 0.14)
			barrel(root, 0.11, 2.6, Vector3(-1.3, 2.5, -2.36), mat(BRASS, 0.0, 0.6, 0.5))
		# ---------------------------------------------------- Nomad Circuit
		"skiff":
			_front(root, 0.92, 0.72, 0.36)
			_tail(root, -0.96, 0.66, 0.4)
		"dart":
			lamp(root, Vector3(0.72, 0.74, 0.0), LAMP, 0.1)
		"sidewinder", "beacon_rig":
			_front(root, 1.0, 0.76, 0.4)
			_tail(root, -1.01, 0.56, 0.42)
		"gnat", "jammer_buggy":
			_front(root, 0.82, 0.56, 0.3, false)
			box(root, Vector3(0.05, 0.3, 0.8), Vector3(0.87, 0.62, 0.0), mat(METAL, 0.0, 0.6, 0.4))
			_tail(root, -0.81, 0.5, 0.36)
		"prowler":
			lamp(root, Vector3(1.14, 0.9, 0.48))
			lamp(root, Vector3(1.14, 0.9, -0.48))
			if t != null:
				hatch(t, Vector3(-0.15, 0.43, 0.25), 0.17, SAND_DARK)
				box(t, Vector3(0.2, 0.26, 0.4), Vector3(0.52, 0.22, 0.0), mat(GUNMETAL))
			aerial(root, Vector3(-1.0, 0.95, -0.45), 1.2)
		"caravan":
			_front(root, 2.08, 1.3, 0.8)
			_tail(root, -2.11, 0.9, 0.9)
			for z: float in [-1.07, 1.07]:
				windows(root, Vector3(-1.5, 1.85, z), Vector3(0.7, 0.0, 0.0), 4, Vector3(0.4, 0.3, 0.06), WINDOW_WARM)
		"caravan_hub":
			for sx: float in [-1.0, 1.0]:
				for sz: float in [-1.0, 1.0]:
					_pole_lamp(root, Vector3(sx * 3.4, 0.2, sz * 3.4), 1.7, WINDOW_WARM)
			_spin_arms(root, Vector3(1.0, 4.6, 0.6), 0.55, PATCH)
			windows(root, Vector3(2.12, 1.0, -0.7), Vector3(0.0, 0.0, 0.7), 3, Vector3(0.06, 0.34, 0.4), WINDOW_WARM)
		"beacon":
			_spin_arms(root, Vector3(0.0, 3.2, 0.0), 0.42, PATCH)
		"cache":
			_pole_lamp(root, Vector3(-1.5, 0.15, 1.5), 1.5, WINDOW_WARM)
		"camp":
			_pole_lamp(root, Vector3(-2.4, 0.15, 2.4), 1.7, WINDOW_WARM)
			for i: int in 3:
				box(root, Vector3(0.5, 0.16, 0.2), Vector3(1.55 + 0.4 * float(i % 2), 0.24, 0.75 + 0.5 * float(i)), mat(SAND, 0.0, 0.0, 1.0), Vector3(0.0, 0.5 * float(i), 0.0))
		"chop_shop":
			windows(root, Vector3(-1.85, 1.15, 0.12), Vector3(3.7, 0.0, 0.0), 2, Vector3(0.5, 0.4, 0.06), WINDOW_WARM)
			_pole_lamp(root, Vector3(2.5, 0.15, 2.5), 1.9, WINDOW_WARM)
		"signal_loom":
			var orbit: Node3D = group(root, "Spin", Vector3(0.0, 3.2, 0.0))
			for i: int in 3:
				var ang: float = float(i) * TAU / 3.0
				box(orbit, Vector3(0.1, 0.34, 0.34), Vector3(cos(ang) * 1.36, 0.0, sin(ang) * 1.36), mat(METAL, 0.0, 0.6, 0.4), Vector3(0.0, -ang, 0.0))
				box(orbit, Vector3(0.07, 0.07, 0.07), Vector3(cos(ang) * 1.36, 0.22, sin(ang) * 1.36), mat(Color(0.6, 1.0, 0.9), 1.8))
			_pole_lamp(root, Vector3(-2.4, 0.15, 2.4), 1.7, WINDOW_WARM)
