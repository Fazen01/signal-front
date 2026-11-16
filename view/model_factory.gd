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
# Vesper Array palette: pale ceramic shells over dark frames, violet light.
const SHELL: Color = Color(0.56, 0.58, 0.68)
const SHELL_DARK: Color = Color(0.32, 0.34, 0.45)
const FRAME: Color = Color(0.11, 0.12, 0.17)
const VIOLET: Color = Color(0.66, 0.46, 1.0)
# Verdigris Order palette: weathered copper plate, bronze, pale stone, amber light.
const COPPER: Color = Color(0.25, 0.47, 0.43)
const COPPER_DARK: Color = Color(0.13, 0.28, 0.27)
const BRONZE: Color = Color(0.50, 0.36, 0.19)
const BRONZE_DARK: Color = Color(0.25, 0.18, 0.11)
const STONE: Color = Color(0.60, 0.58, 0.52)
const STONE_DARK: Color = Color(0.36, 0.35, 0.33)
const AMBER: Color = Color(1.0, 0.70, 0.22)
# Zephyr Accord palette: pale airframe grey, navy, safety orange.
const CLOUD: Color = Color(0.74, 0.77, 0.80)
const CLOUD_DARK: Color = Color(0.42, 0.46, 0.52)
const NAVY: Color = Color(0.13, 0.17, 0.24)
const FLAME: Color = Color(0.95, 0.47, 0.12)
# Crimson Tally palette: pitch-black armor, oxblood plates, gilt trim.
const PITCH: Color = Color(0.13, 0.13, 0.15)
const SLATE: Color = Color(0.27, 0.27, 0.30)
const OXBLOOD: Color = Color(0.40, 0.09, 0.10)
const GILT: Color = Color(0.85, 0.65, 0.25)
# Umbral Veil palette: matt dusk hulls, faceted, with pale ghost-light.
const UMBRA: Color = Color(0.16, 0.16, 0.22)
const UMBRA_LIGHT: Color = Color(0.29, 0.29, 0.38)
const GHOST: Color = Color(0.55, 1.0, 0.80)
# Brackenfold palette: dark heartwood, worked wood, plates of pale bone,
# leaves the red of autumn, and sap light. Nothing in it is green: it has to
# stand out from the grass and the trees.
const BARK: Color = Color(0.24, 0.14, 0.11)
const BARK_LIGHT: Color = Color(0.60, 0.43, 0.27)
const LEAF: Color = Color(0.80, 0.26, 0.11)
const LEAF_LIGHT: Color = Color(0.97, 0.58, 0.16)
const BONE: Color = Color(0.84, 0.77, 0.62)
const BONE_DARK: Color = Color(0.56, 0.48, 0.36)
const SAP: Color = Color(0.82, 1.0, 0.25)
# Lodestone Circle palette: graphite, porcelain insulators, copper windings, magenta flux.
const GRAPHITE: Color = Color(0.20, 0.21, 0.25)
const GRAPHITE_LIGHT: Color = Color(0.36, 0.38, 0.43)
const PORCELAIN: Color = Color(0.90, 0.90, 0.86)
const COIL: Color = Color(0.82, 0.46, 0.22)
const FLUX: Color = Color(1.0, 0.34, 0.86)
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


## The upper half of a cylinder lying along Z, closed at both ends: an
## arched roof that sits on the ground instead of being half buried in it.
static func arch(parent: Node3D, radius: float, depth: float, pos: Vector3, m: Material, sides: int = 12) -> MeshInstance3D:
	var key: String = "arch|%.3f|%.3f|%d" % [radius, depth, sides]
	if not _meshes.has(key):
		var buf: MeshBuf = MeshBuf.new()
		var inside: Vector3 = Vector3(0.0, radius * 0.3, 0.0)
		var hz: float = depth * 0.5
		for i: int in sides:
			var a0: float = PI * float(i) / float(sides)
			var a1: float = PI * float(i + 1) / float(sides)
			var p0: Vector3 = Vector3(cos(a0) * radius, sin(a0) * radius, 0.0)
			var p1: Vector3 = Vector3(cos(a1) * radius, sin(a1) * radius, 0.0)
			buf.quad(p0 + Vector3(0.0, 0.0, -hz), p0 + Vector3(0.0, 0.0, hz), p1 + Vector3(0.0, 0.0, hz), p1 + Vector3(0.0, 0.0, -hz), inside, Color.WHITE)
			for end: float in [-hz, hz]:
				buf.tri(Vector3(0.0, 0.0, end), p0 + Vector3(0.0, 0.0, end), p1 + Vector3(0.0, 0.0, end), inside, Color.WHITE, Color.WHITE, Color.WHITE)
		_meshes[key] = buf.commit()
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
		"mote":
			_drone(root, team)
			# An arm gun on each side.
			for z: float in [-0.36, 0.36]:
				box(root, Vector3(0.3, 0.12, 0.12), Vector3(0.1, 1.02, z), mat(SHELL_DARK))
				barrel(root, 0.035, 0.42, Vector3(0.22, 1.02, z), mat(FRAME))
				box(root, Vector3(0.05, 0.07, 0.07), Vector3(0.65, 1.02, z), mat(VIOLET, 1.6))
		"shard":
			_drone(root, team)
			# A lance tube over one shoulder, a counterweight on the other.
			barrel(root, 0.11, 1.05, Vector3(-0.42, 1.36, 0.3), mat(SHELL_DARK))
			cyl(root, 0.13, 0.13, 0.1, Vector3(0.63, 1.36, 0.3), mat(VIOLET, 1.5), 8, Vector3(0.0, 0.0, -PI * 0.5))
			cyl(root, 0.13, 0.13, 0.08, Vector3(-0.42, 1.36, 0.3), mat(FRAME), 8, Vector3(0.0, 0.0, -PI * 0.5))
			box(root, Vector3(0.24, 0.22, 0.16), Vector3(-0.05, 1.12, -0.36), mat(SHELL_DARK))
		"weaver":
			_drone(root, team)
			# A fabricator pack and two working arms.
			box(root, Vector3(0.24, 0.46, 0.44), Vector3(-0.3, 1.04, 0.0), mat(HAZARD))
			box(root, Vector3(0.05, 0.3, 0.3), Vector3(-0.43, 1.08, 0.0), mat(VIOLET, 1.2))
			for z: float in [-0.34, 0.34]:
				box(root, Vector3(0.46, 0.06, 0.06), Vector3(0.24, 0.96, z), mat(FRAME), Vector3(0.0, 0.0, -0.3))
				box(root, Vector3(0.12, 0.14, 0.1), Vector3(0.46, 0.88, z), mat(HAZARD))
		"porter":
			_porter(root, team)
		"glint":
			_glint(root, team)
		"lash":
			_lash(root, team)
		"halberd":
			_halberd(root, team)
		"aureole":
			_aureole(root, team)
		"prism":
			_prism(root, team)
		"nexus":
			_nexus(root, team)
		"spire":
			_spire(root, team)
		"cistern":
			_cistern(root, team)
		"cradle":
			_cradle(root, team)
		"assembler":
			_assembler(root, team)
		"ward_node":
			_ward_node(root, team)
		"oracle":
			_oracle(root, team)
		"vigil":
			_knight(root, team, true)
			box(root, Vector3(0.62, 0.09, 0.1), Vector3(0.3, 0.95, 0.36), mat(GUNMETAL))
			box(root, Vector3(0.2, 0.12, 0.08), Vector3(-0.02, 0.93, 0.36), mat(BRONZE_DARK))
		"pike":
			_knight(root, team, true)
			barrel(root, 0.075, 1.35, Vector3(-0.5, 1.3, 0.36), mat(BRONZE))
			cyl(root, 0.1, 0.1, 0.12, Vector3(0.88, 1.3, 0.36), mat(AMBER, 1.5), 8, Vector3(0.0, 0.0, -PI * 0.5))
			box(root, Vector3(0.2, 0.2, 0.2), Vector3(-0.5, 1.3, 0.36), mat(BRONZE_DARK))
		"mason":
			_knight(root, team, false)
			box(root, Vector3(0.22, 0.44, 0.44), Vector3(-0.28, 0.95, 0.0), mat(BRONZE_DARK))
			box(root, Vector3(0.06, 0.7, 0.06), Vector3(0.26, 0.95, 0.38), mat(BRONZE_DARK))
			box(root, Vector3(0.3, 0.16, 0.16), Vector3(0.26, 1.32, 0.38), mat(BRONZE))
			box(root, Vector3(0.24, 0.3, 0.06), Vector3(0.2, 0.9, -0.36), mat(HAZARD))
		"dray":
			_dray(root, team)
		"outrider":
			_outrider(root, team)
		"thresher":
			_thresher(root, team)
		"castellan":
			_castellan(root, team)
		"canopy":
			_canopy(root, team)
		"mangonel":
			_mangonel(root, team)
		"keep":
			_keep(root, team)
		"lantern":
			_lantern(root, team)
		"tithe_barn":
			_tithe_barn(root, team)
		"chapterhouse":
			_chapterhouse(root, team)
		"armoury":
			_armoury(root, team)
		"rampart":
			_rampart(root, team)
		"watchfire":
			_watchfire(root, team)
		"reliquary":
			_reliquary(root, team)
		"ranger":
			_soldier(root, team, CLOUD, CLOUD_DARK, NAVY)
			box(root, Vector3(0.7, 0.07, 0.08), Vector3(0.28, 0.92, 0.2), mat(GUNMETAL))
			box(root, Vector3(0.1, 0.05, 0.3), Vector3(0.1, 1.36, 0.0), mat(FLAME))
		"flare":
			_soldier(root, team, CLOUD, CLOUD_DARK, NAVY)
			barrel(root, 0.09, 1.05, Vector3(-0.4, 1.24, 0.22), mat(CLOUD))
			cyl(root, 0.11, 0.11, 0.1, Vector3(0.66, 1.24, 0.22), mat(FLAME, 1.2), 8, Vector3(0.0, 0.0, -PI * 0.5))
			box(root, Vector3(0.14, 0.16, 0.14), Vector3(0.1, 1.38, 0.22), mat(NAVY))
		"rigger":
			_soldier(root, team, FLAME, CLOUD_DARK, NAVY)
			box(root, Vector3(0.22, 0.44, 0.42), Vector3(-0.27, 0.9, 0.0), mat(FLAME))
			box(root, Vector3(0.1, 0.5, 0.1), Vector3(0.25, 0.75, 0.24), mat(METAL))
		"tender":
			_tender(root, team)
		"lookout":
			_lookout(root, team)
		"squall":
			_squall(root, team)
		"swift":
			_swift(root, team)
		"lanner":
			_lanner(root, team)
		"condor":
			_condor(root, team)
		"aerie":
			_aerie(root, team)
		"mast":
			_mast(root, team)
		"hangar":
			_hangar(root, team)
		"roost":
			_roost(root, team)
		"flight_deck":
			_flight_deck(root, team)
		"gun_pit":
			_gun_pit(root, team)
		"control_tower":
			_control_tower(root, team)
		"gunhand":
			_soldier(root, team, PITCH, SLATE, PITCH)
			box(root, Vector3(0.7, 0.08, 0.09), Vector3(0.28, 0.92, 0.2), mat(GUNMETAL))
			box(root, Vector3(0.36, 0.06, 0.5), Vector3(0.0, 1.2, 0.0), mat(OXBLOOD))
		"petard":
			_soldier(root, team, PITCH, SLATE, PITCH)
			barrel(root, 0.11, 1.0, Vector3(-0.38, 1.24, 0.22), mat(PITCH))
			cyl(root, 0.13, 0.13, 0.1, Vector3(0.62, 1.24, 0.22), mat(GILT, 0.0, 0.7, 0.4), 8, Vector3(0.0, 0.0, -PI * 0.5))
			box(root, Vector3(0.36, 0.06, 0.5), Vector3(0.0, 1.2, 0.0), mat(OXBLOOD))
		"tallyman":
			_soldier(root, team, GILT, SLATE, PITCH)
			box(root, Vector3(0.22, 0.44, 0.42), Vector3(-0.27, 0.9, 0.0), mat(OXBLOOD))
			box(root, Vector3(0.05, 0.2, 0.3), Vector3(-0.39, 0.95, 0.0), mat(GILT, 0.0, 0.7, 0.4))
			box(root, Vector3(0.1, 0.5, 0.1), Vector3(0.25, 0.75, 0.24), mat(METAL))
		"strongbox":
			_strongbox(root, team)
		"jackal":
			_jackal(root, team)
		"brigand":
			_brigand(root, team)
		"ravager":
			_ravager(root, team)
		"flakjack":
			_flakjack(root, team)
		"ransom":
			_ransom(root, team)
		"counting_house":
			_counting_house(root, team)
		"signal_post":
			_signal_post(root, team)
		"vault":
			_vault(root, team)
		"billet":
			_billet(root, team)
		"motor_pool":
			_motor_pool(root, team)
		"gun_nest":
			_gun_nest(root, team)
		"exchange":
			_exchange(root, team)
		"shade":
			_ghost(root, team)
			box(root, Vector3(0.8, 0.06, 0.07), Vector3(0.32, 0.94, 0.2), mat(GUNMETAL))
		"needle":
			_ghost(root, team)
			box(root, Vector3(1.35, 0.05, 0.05), Vector3(0.5, 1.0, 0.2), mat(GUNMETAL))
			box(root, Vector3(0.22, 0.09, 0.09), Vector3(0.2, 1.06, 0.2), mat(UMBRA_LIGHT))
			box(root, Vector3(0.05, 0.05, 0.05), Vector3(1.18, 1.0, 0.2), mat(GHOST, 1.7))
		"veilwright":
			_ghost(root, team)
			box(root, Vector3(0.22, 0.42, 0.4), Vector3(-0.28, 0.92, 0.0), mat(UMBRA_LIGHT))
			box(root, Vector3(0.05, 0.26, 0.26), Vector3(-0.4, 0.95, 0.0), mat(GHOST, 1.3))
			box(root, Vector3(0.1, 0.5, 0.1), Vector3(0.25, 0.75, 0.24), mat(HAZARD))
		"gleaner":
			_gleaner(root, team)
		"wisp":
			_wisp(root, team)
		"mirage":
			_mirage(root, team)
		"stalker":
			_stalker(root, team)
		"pall":
			_pall(root, team)
		"eclipse":
			_eclipse(root, team)
		"sanctum":
			_sanctum(root, team)
		"obelisk":
			_obelisk(root, team)
		"reservoir":
			_reservoir(root, team)
		"hollow":
			_hollow(root, team)
		"shroudworks":
			_shroudworks(root, team)
		"sentinel":
			_sentinel(root, team)
		"occulus":
			_occulus(root, team)
		"thornling":
			_sprout(root, team)
			cyl(root, 0.05, 0.07, 0.6, Vector3(0.34, 0.92, 0.2), mat(BARK), 5, Vector3(0.0, 0.0, -PI * 0.5))
			box(root, Vector3(0.07, 0.07, 0.07), Vector3(0.66, 0.92, 0.2), mat(SAP, 1.6))
		"lasher":
			_sprout(root, team)
			cyl(root, 0.03, 0.1, 1.15, Vector3(0.1, 1.22, 0.22), mat(BONE), 5, Vector3(0.0, 0.0, -PI * 0.5))
			cyl(root, 0.12, 0.12, 0.3, Vector3(-0.3, 1.22, 0.22), mat(BARK), 6, Vector3(0.0, 0.0, -PI * 0.5))
			box(root, Vector3(0.08, 0.08, 0.08), Vector3(0.7, 1.22, 0.22), mat(SAP, 1.7))
		"grafter":
			_sprout(root, team)
			var pod: MeshInstance3D = ball(root, 0.2, Vector3(-0.3, 0.95, 0.0), mat(SAP, 0.9), 6)
			pod.scale = Vector3(0.8, 1.15, 1.0)
			cyl(root, 0.04, 0.04, 0.6, Vector3(0.27, 0.8, 0.24), mat(BONE), 5)
			box(root, Vector3(0.16, 0.1, 0.06), Vector3(0.3, 1.1, 0.24), mat(BONE))
		"forager":
			_forager(root, team)
		"quillhound":
			_quillhound(root, team)
		"quillback":
			_quillback(root, team)
		"barkhide":
			_barkhide(root, team)
		"whipvine":
			_whipvine(root, team)
		"sporemortar":
			_sporemortar(root, team)
		"heartroot":
			_heartroot(root, team)
		"tendril":
			_tendril(root, team)
		"mulch_pit":
			_mulch_pit(root, team)
		"seedbed":
			_seedbed(root, team)
		"bloomworks":
			_bloomworks(root, team)
		"spine_stalk":
			_spine_stalk(root, team)
		"elder_bough":
			_elder_bough(root, team)
		"keeper":
			_lineman(root, team)
			box(root, Vector3(0.72, 0.08, 0.09), Vector3(0.3, 0.92, 0.2), mat(GUNMETAL))
			box(root, Vector3(0.06, 0.06, 0.06), Vector3(0.68, 0.92, 0.2), mat(FLUX, 1.7))
		"railhand":
			_lineman(root, team)
			box(root, Vector3(1.2, 0.07, 0.05), Vector3(0.2, 1.26, 0.17), mat(GUNMETAL))
			box(root, Vector3(1.2, 0.07, 0.05), Vector3(0.2, 1.26, 0.29), mat(GUNMETAL))
			for x: float in [-0.1, 0.25, 0.6]:
				box(root, Vector3(0.07, 0.13, 0.2), Vector3(x, 1.26, 0.23), mat(COIL, 0.0, 0.7, 0.4))
			box(root, Vector3(0.06, 0.05, 0.07), Vector3(0.82, 1.26, 0.23), mat(FLUX, 1.8))
		"coilwright":
			_lineman(root, team)
			cyl(root, 0.17, 0.17, 0.3, Vector3(-0.3, 0.95, 0.0), mat(COIL, 0.0, 0.7, 0.4), 8, Vector3(PI * 0.5, 0.0, 0.0))
			cyl(root, 0.2, 0.2, 0.05, Vector3(-0.3, 0.95, 0.17), mat(GRAPHITE), 8, Vector3(PI * 0.5, 0.0, 0.0))
			cyl(root, 0.2, 0.2, 0.05, Vector3(-0.3, 0.95, -0.17), mat(GRAPHITE), 8, Vector3(PI * 0.5, 0.0, 0.0))
			box(root, Vector3(0.1, 0.5, 0.1), Vector3(0.25, 0.75, 0.24), mat(HAZARD))
		"lodecart":
			_lodecart(root, team)
		"compass":
			_compass(root, team)
		"dynamo":
			_dynamo(root, team)
		"armature":
			_armature(root, team)
		"stator":
			_stator(root, team)
		"solenoid":
			_solenoid(root, team)
		"lode_hall":
			_lode_hall(root, team)
		"conductor":
			_conductor(root, team)
		"magnet_yard":
			_magnet_yard(root, team)
		"ring_hall":
			_ring_hall(root, team)
		"winding_shed":
			_winding_shed(root, team)
		"arc_pole":
			_arc_pole(root, team)
		"resonator":
			_resonator(root, team)
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


# ------------------------------------------------------------ Vesper Array

## A drone frame on two stilt legs: the Array's infantry. A six-sided body
## over jointed legs, shoulder pods, and a visor that glows.
static func _drone(root: Node3D, team: Color) -> void:
	for z: float in [-0.16, 0.16]:
		box(root, Vector3(0.28, 0.07, 0.15), Vector3(0.1, 0.035, z), mat(FRAME))
		box(root, Vector3(0.09, 0.46, 0.09), Vector3(0.07, 0.29, z), mat(SHELL_DARK), Vector3(0.0, 0.0, 0.28))
		box(root, Vector3(0.11, 0.3, 0.11), Vector3(-0.01, 0.6, z), mat(SHELL), Vector3(0.0, 0.0, -0.4))
		box(root, Vector3(0.08, 0.08, 0.12), Vector3(0.0, 0.47, z), mat(FRAME))
		box(root, Vector3(0.22, 0.16, 0.15), Vector3(0.0, 1.14, z * 2.05), mat(SHELL_DARK))
	box(root, Vector3(0.22, 0.14, 0.4), Vector3(0.0, 0.76, 0.0), mat(FRAME))
	cyl(root, 0.24, 0.3, 0.44, Vector3(0.0, 1.02, 0.0), mat(SHELL), 6)
	cyl(root, 0.31, 0.31, 0.1, Vector3(0.0, 0.88, 0.0), team_mat(team), 6)
	box(root, Vector3(0.1, 0.22, 0.3), Vector3(0.22, 1.02, 0.0), team_mat(team))
	cyl(root, 0.16, 0.2, 0.12, Vector3(0.0, 1.3, 0.0), mat(SHELL_DARK), 6)
	var dome: MeshInstance3D = ball(root, 0.15, Vector3(0.03, 1.37, 0.0), mat(SHELL), 6)
	dome.scale = Vector3(1.0, 0.8, 1.0)
	box(root, Vector3(0.06, 0.07, 0.22), Vector3(0.16, 1.37, 0.0), mat(VIOLET, 1.7))
	aerial(root, Vector3(-0.1, 1.42, -0.1), 0.34, VIOLET)


## The Array's hover chassis. A dark keel, a two-step ceramic hull with a
## sloped nose, an engine block with glowing vents at the back, and a lift
## pod along each side instead of wheels. The deck is at 0.32 + `deck`.
static func _skimmer(root: Node3D, team: Color, length: float, width: float, deck: float = 0.5) -> void:
	var body: float = deck - 0.1
	var top: float = 0.42 + body
	# Keel and lower hull.
	box(root, Vector3(length * 0.96, 0.16, width * 0.78), Vector3(0.0, 0.34, 0.0), mat(FRAME))
	box(root, Vector3(length * 0.8, body * 0.6, width), Vector3(-length * 0.08, 0.42 + body * 0.3, 0.0), mat(SHELL_DARK))
	wedge(root, Vector3(length * 0.28, body * 0.6, width), Vector3(length * 0.46, 0.42 + body * 0.3, 0.0), mat(SHELL_DARK), 0.0)
	# Upper hull, stepped in.
	box(root, Vector3(length * 0.66, body * 0.42, width * 0.8), Vector3(-length * 0.1, top - body * 0.21, 0.0), mat(SHELL))
	wedge(root, Vector3(length * 0.3, body * 0.42, width * 0.8), Vector3(length * 0.38, top - body * 0.21, 0.0), mat(SHELL), 0.0)
	# Team colour: a band round the waist and a plate on the nose.
	box(root, Vector3(length * 0.82, 0.07, width + 0.03), Vector3(-length * 0.08, 0.42 + body * 0.6, 0.0), team_mat(team))
	box(root, Vector3(length * 0.16, 0.05, width * 0.5), Vector3(length * 0.4, top - body * 0.2, 0.0), team_mat(team), Vector3(0.0, 0.0, -0.62))
	# Engine block with two glowing vents.
	box(root, Vector3(length * 0.14, body * 0.9, width * 0.72), Vector3(-length * 0.5, 0.42 + body * 0.45, 0.0), mat(FRAME))
	for z: float in [-0.2, 0.2]:
		box(root, Vector3(0.05, body * 0.3, width * 0.22), Vector3(-length * 0.575, 0.42 + body * 0.5, z * width), mat(VIOLET, 1.5))
	# Lift pods.
	for side: float in [-1.0, 1.0]:
		var z: float = side * (width * 0.5 + 0.06)
		cyl(root, 0.19, 0.19, length * 0.74, Vector3(-length * 0.02, 0.32, z), mat(SHELL), 8, Vector3(0.0, 0.0, -PI * 0.5))
		cyl(root, 0.2, 0.2, 0.1, Vector3(length * 0.35, 0.32, z), mat(FRAME), 8, Vector3(0.0, 0.0, -PI * 0.5))
		cyl(root, 0.14, 0.14, 0.06, Vector3(-length * 0.4, 0.32, z), mat(VIOLET, 1.6), 8, Vector3(0.0, 0.0, -PI * 0.5))
		box(root, Vector3(length * 0.62, 0.04, 0.2), Vector3(-length * 0.02, 0.12, z), mat(VIOLET, 1.3))
		box(root, Vector3(length * 0.3, 0.06, 0.1), Vector3(0.0, 0.5, z), mat(FRAME))
	lamp(root, Vector3(length * 0.56, 0.5, width * 0.3), VIOLET, 0.09)
	lamp(root, Vector3(length * 0.56, 0.5, -width * 0.3), VIOLET, 0.09)


## A six-sided turret with a sensor band, for the skimmers.
static func _hex_turret(t: Node3D, team: Color, radius: float, height: float) -> void:
	cyl(t, radius * 0.86, radius, height, Vector3(0.0, height * 0.5, 0.0), mat(SHELL), 6)
	cyl(t, radius * 1.02, radius * 1.02, 0.07, Vector3(0.0, height * 0.35, 0.0), mat(FRAME), 6)
	cyl(t, radius * 0.5, radius * 0.6, 0.08, Vector3(-radius * 0.15, height + 0.04, 0.0), team_mat(team), 6)
	box(t, Vector3(0.07, height * 0.3, radius * 0.9), Vector3(radius * 0.84, height * 0.62, 0.0), mat(VIOLET, 1.5))


static func _porter(root: Node3D, team: Color) -> void:
	_skimmer(root, team, 2.2, 1.15, 0.45)
	box(root, Vector3(0.6, 0.5, 1.0), Vector3(0.62, 1.02, 0.0), mat(SHELL))
	box(root, Vector3(0.05, 0.2, 0.8), Vector3(0.93, 1.08, 0.0), mat(VIOLET, 0.7, 0.3, 0.2))
	box(root, Vector3(1.3, 0.3, 1.2), Vector3(-0.42, 0.92, 0.0), mat(SHELL_DARK))
	box(root, Vector3(1.32, 0.08, 1.22), Vector3(-0.42, 1.06, 0.0), team_mat(team))
	_cargo(root, Vector3(-0.42, 1.1, 0.0), Vector3(1.1, 0.5, 1.0))


static func _glint(root: Node3D, team: Color) -> void:
	_skimmer(root, team, 1.6, 0.85, 0.36)
	wedge(root, Vector3(0.5, 0.3, 0.06), Vector3(-0.62, 0.84, 0.3), mat(SHELL_DARK), 0.0)
	wedge(root, Vector3(0.5, 0.3, 0.06), Vector3(-0.62, 0.84, -0.3), mat(SHELL_DARK), 0.0)
	aerial(root, Vector3(-0.6, 0.7, 0.0), 0.8, VIOLET)
	var t: Node3D = _turret(root, Vector3(0.0, 0.68, 0.0))
	_hex_turret(t, team, 0.22, 0.18)
	barrel(t, 0.03, 0.6, Vector3(0.14, 0.1, 0.0), mat(FRAME))


static func _lash(root: Node3D, team: Color) -> void:
	_skimmer(root, team, 2.1, 1.25, 0.5)
	hatch(root, Vector3(0.62, 0.84, 0.3), 0.15, SHELL_DARK)
	box(root, Vector3(0.4, 0.2, 0.3), Vector3(-0.78, 0.92, -0.32), mat(SHELL_DARK))
	var t: Node3D = _turret(root, Vector3(-0.15, 0.82, 0.0))
	_hex_turret(t, team, 0.5, 0.32)
	for z: float in [-0.17, 0.17]:
		box(t, Vector3(0.36, 0.16, 0.14), Vector3(0.5, 0.2, z), mat(SHELL_DARK))
		barrel(t, 0.05, 0.95, Vector3(0.62, 0.2, z), mat(FRAME))
		cyl(t, 0.07, 0.07, 0.08, Vector3(1.5, 0.2, z), mat(VIOLET, 1.5), 6, Vector3(0.0, 0.0, -PI * 0.5))


static func _halberd(root: Node3D, team: Color) -> void:
	_skimmer(root, team, 2.7, 1.45, 0.55)
	hatch(root, Vector3(0.8, 0.89, 0.42), 0.17, SHELL_DARK)
	for z: float in [-0.5, 0.5]:
		box(root, Vector3(0.5, 0.18, 0.3), Vector3(-1.0, 0.96, z), mat(SHELL_DARK))
	var t: Node3D = _turret(root, Vector3(-0.2, 0.87, 0.0))
	_hex_turret(t, team, 0.68, 0.44)
	# The lance: a long rail in a heavy cradle, ringed with emitters.
	box(t, Vector3(0.5, 0.34, 0.5), Vector3(0.72, 0.24, 0.0), mat(SHELL_DARK))
	barrel(t, 0.09, 2.0, Vector3(0.9, 0.24, 0.0), mat(FRAME))
	box(t, Vector3(1.2, 0.07, 0.07), Vector3(1.6, 0.4, 0.0), mat(SHELL))
	for x: float in [1.4, 1.9, 2.4]:
		cyl(t, 0.14, 0.14, 0.07, Vector3(x, 0.24, 0.0), mat(VIOLET, 1.5), 8, Vector3(0.0, 0.0, -PI * 0.5))
	cyl(t, 0.12, 0.12, 0.2, Vector3(2.92, 0.24, 0.0), mat(SHELL_DARK), 8, Vector3(0.0, 0.0, -PI * 0.5))
	box(t, Vector3(0.36, 0.22, 0.9), Vector3(-0.72, 0.2, 0.0), mat(SHELL_DARK))
	aerial(t, Vector3(-0.5, 0.44, -0.42), 0.9, VIOLET)


static func _aureole(root: Node3D, team: Color) -> void:
	_skimmer(root, team, 2.1, 1.2, 0.48)
	var t: Node3D = _turret(root, Vector3(-0.1, 0.8, 0.0))
	_hex_turret(t, team, 0.5, 0.34)
	# Two racks of emitters angled at the sky, and a tracking dish.
	for side: float in [-1.0, 1.0]:
		box(t, Vector3(0.5, 0.3, 0.26), Vector3(0.15, 0.56, side * 0.5), mat(SHELL_DARK), Vector3(0.0, 0.0, 0.62))
		for k: float in [-0.07, 0.07]:
			cyl(t, 0.035, 0.035, 1.0, Vector3(0.56, 0.86, side * 0.5 + k), mat(FRAME), 5, Vector3(0.0, 0.0, -0.95))
			box(t, Vector3(0.07, 0.07, 0.07), Vector3(0.97, 1.15, side * 0.5 + k), mat(VIOLET, 1.6))
	cyl(t, 0.03, 0.03, 0.4, Vector3(-0.3, 0.54, 0.0), mat(FRAME), 5)
	cyl(t, 0.3, 0.1, 0.12, Vector3(-0.3, 0.8, 0.0), mat(SHELL), 8, Vector3(0.0, 0.0, 0.5))


static func _prism(root: Node3D, team: Color) -> void:
	_skimmer(root, team, 2.5, 1.3, 0.5)
	# Stabiliser legs for firing.
	for z: float in [-0.85, 0.85]:
		box(root, Vector3(0.5, 0.1, 0.16), Vector3(-1.0, 0.3, z), mat(FRAME), Vector3(0.0, 0.0, 0.3))
		box(root, Vector3(0.3, 0.06, 0.3), Vector3(-1.2, 0.2, z), mat(SHELL_DARK))
	var t: Node3D = _turret(root, Vector3(-0.3, 0.82, 0.0))
	_hex_turret(t, team, 0.56, 0.4)
	# The projector: a tapering tube braced by two struts, a crystal at its mouth.
	cyl(t, 0.13, 0.22, 2.2, Vector3(0.82, 1.0, 0.0), mat(SHELL), 8, Vector3(0.0, 0.0, -0.95))
	for z: float in [-0.26, 0.26]:
		box(t, Vector3(1.3, 0.06, 0.06), Vector3(0.55, 0.72, z), mat(FRAME), Vector3(0.0, 0.0, 0.5))
	for d: float in [0.5, 1.0, 1.5]:
		cyl(t, 0.2, 0.2, 0.06, Vector3(0.82 - 0.895 + d * 0.81, 1.0 - 0.64 + d * 0.58, 0.0), mat(VIOLET, 1.3), 8, Vector3(0.0, 0.0, -0.95))
	wedge(t, Vector3(0.42, 0.62, 0.42), Vector3(1.82, 1.74, 0.0), mat(VIOLET, 1.6), 0.5, Vector3(0.0, 0.0, -0.95))


## The six-sided slab the Array's buildings stand on.
static func _hex_base(root: Node3D, radius: float, height: float = 0.4) -> void:
	cyl(root, radius, radius + 0.15, height, Vector3(0.0, 0.0, 0.0), mat(FRAME), 6)
	cyl(root, radius - 0.45, radius - 0.45, 0.05, Vector3(0.0, height * 0.5 + 0.02, 0.0), mat(SHELL_DARK), 6)
	cyl(root, radius - 0.2, radius - 0.2, 0.03, Vector3(0.0, height * 0.5 + 0.01, 0.0), mat(VIOLET, 0.8), 6)
	# A short lit post on every corner.
	for i: int in 6:
		var ang: float = float(i) * TAU / 6.0 + TAU / 12.0
		var at: Vector3 = Vector3(cos(ang) * (radius - 0.25), height * 0.5, sin(ang) * (radius - 0.25))
		cyl(root, 0.1, 0.13, 0.5, at + Vector3(0.0, 0.25, 0.0), mat(SHELL), 6)
		box(root, Vector3(0.12, 0.1, 0.12), at + Vector3(0.0, 0.54, 0.0), mat(VIOLET, 1.6))


static func _nexus(root: Node3D, team: Color) -> void:
	_hex_base(root, 4.0, 0.5)
	cyl(root, 2.7, 3.1, 2.3, Vector3(0.0, 1.4, 0.0), mat(SHELL), 6)
	cyl(root, 3.05, 3.05, 0.3, Vector3(0.0, 1.95, 0.0), team_mat(team), 6)
	cyl(root, 1.7, 2.2, 1.5, Vector3(0.0, 3.3, 0.0), mat(SHELL_DARK), 6)
	cyl(root, 1.9, 1.9, 0.14, Vector3(0.0, 4.1, 0.0), mat(FRAME), 6)
	for i: int in 6:
		var ang: float = float(i) * TAU / 6.0 + TAU / 12.0
		box(root, Vector3(1.0, 0.32, 0.1), Vector3(cos(ang) * 2.56, 1.1, sin(ang) * 2.56), mat(VIOLET, 0.9), Vector3(0.0, -ang + PI * 0.5, 0.0))
		box(root, Vector3(0.6, 0.26, 0.1), Vector3(cos(ang) * 1.7, 3.3, sin(ang) * 1.7), mat(VIOLET, 0.9), Vector3(0.0, -ang + PI * 0.5, 0.0))
		wedge(root, Vector3(1.0, 1.6, 0.3), Vector3(cos(ang + 0.52) * 3.4, 0.95, sin(ang + 0.52) * 3.4), mat(SHELL_DARK), 0.0, Vector3(0.0, -ang - 0.52, 0.0))
	# Command mast: the root of the signal grid.
	cyl(root, 0.16, 0.3, 3.8, Vector3(0.9, 6.0, 0.9), mat(SHELL), 6)
	ring(root, 0.75, 0.9, Vector3(0.9, 6.5, 0.9), team_mat(team))
	ring(root, 0.45, 0.58, Vector3(0.9, 7.2, 0.9), mat(VIOLET, 1.0))
	ball(root, 0.24, Vector3(0.9, 8.0, 0.9), mat(team, 1.4))
	_spin_arms(root, Vector3(0.9, 5.6, 0.9), 0.6, SHELL)
	var t: Node3D = _turret(root, Vector3(-0.9, 4.18, -0.9))
	box(t, Vector3(0.8, 0.4, 0.7), Vector3(0.0, 0.2, 0.0), mat(FRAME))
	barrel(t, 0.06, 0.9, Vector3(0.35, 0.25, 0.14), mat(GUNMETAL))
	barrel(t, 0.06, 0.9, Vector3(0.35, 0.25, -0.14), mat(GUNMETAL))


static func _spire(root: Node3D, team: Color) -> void:
	cyl(root, 0.7, 0.85, 0.4, Vector3(0.0, 0.2, 0.0), mat(FRAME), 6)
	cyl(root, 0.1, 0.42, 4.0, Vector3(0.0, 2.4, 0.0), mat(SHELL), 6)
	for i: int in 3:
		var ang: float = float(i) * TAU / 3.0
		wedge(root, Vector3(0.6, 1.2, 0.12), Vector3(cos(ang) * 0.55, 1.0, sin(ang) * 0.55), mat(SHELL_DARK), 0.0, Vector3(0.0, -ang, 0.0))
	ring(root, 0.5, 0.62, Vector3(0.0, 2.9, 0.0), team_mat(team))
	ring(root, 0.3, 0.4, Vector3(0.0, 3.7, 0.0), mat(VIOLET, 1.0))
	ball(root, 0.2, Vector3(0.0, 4.6, 0.0), mat(team, 1.4))
	_spin_arms(root, Vector3(0.0, 2.2, 0.0), 0.45, SHELL)


static func _cistern(root: Node3D, team: Color) -> void:
	_hex_base(root, 3.0)
	cyl(root, 1.6, 1.8, 1.5, Vector3(-0.5, 0.95, -0.5), mat(SHELL), 8)
	var dome: MeshInstance3D = ball(root, 1.6, Vector3(-0.5, 1.7, -0.5), mat(SHELL_DARK), 8)
	dome.scale = Vector3(1.0, 0.5, 1.0)
	cyl(root, 1.82, 1.82, 0.2, Vector3(-0.5, 1.2, -0.5), team_mat(team), 8)
	barrel(root, 0.1, 1.5, Vector3(1.0, 0.6, -0.5), mat(FRAME))
	box(root, Vector3(1.0, 0.7, 0.9), Vector3(1.5, 0.55, 1.2), mat(SHELL_DARK))
	box(root, Vector3(0.9, 0.6, 0.8), Vector3(0.4, 0.5, 1.7), mat(FRAME))
	box(root, Vector3(0.8, 0.5, 0.7), Vector3(1.0, 1.1, 1.4), mat(SHELL))
	_pole_lamp(root, Vector3(2.0, 0.2, -1.6), 1.6, VIOLET)


static func _cradle(root: Node3D, team: Color) -> void:
	_hex_base(root, 3.0)
	for i: int in 3:
		var ang: float = float(i) * TAU / 3.0 + 0.5
		var at: Vector3 = Vector3(cos(ang) * 1.3, 0.0, sin(ang) * 1.3)
		cyl(root, 0.85, 0.95, 1.5, at + Vector3(0.0, 0.95, 0.0), mat(SHELL), 6)
		var cap: MeshInstance3D = ball(root, 0.85, at + Vector3(0.0, 1.7, 0.0), mat(SHELL_DARK), 6)
		cap.scale = Vector3(1.0, 0.55, 1.0)
		cyl(root, 0.97, 0.97, 0.16, at + Vector3(0.0, 1.3, 0.0), team_mat(team), 6)
		box(root, Vector3(0.1, 0.7, 0.5), Vector3(cos(ang) * 2.22, 0.6, sin(ang) * 2.22), mat(VIOLET, 0.9), Vector3(0.0, -ang, 0.0))
	cyl(root, 0.3, 0.4, 2.6, Vector3(0.0, 1.5, 0.0), mat(FRAME), 6)
	ball(root, 0.22, Vector3(0.0, 2.9, 0.0), mat(VIOLET, 1.4))


static func _assembler(root: Node3D, team: Color) -> void:
	_hex_base(root, 3.0)
	box(root, Vector3(4.0, 1.7, 2.6), Vector3(0.0, 1.05, -0.7), mat(SHELL))
	box(root, Vector3(4.05, 0.22, 2.65), Vector3(0.0, 1.6, -0.7), team_mat(team))
	for x: float in [-1.4, 0.0, 1.4]:
		box(root, Vector3(0.3, 0.3, 2.8), Vector3(x, 2.05, -0.7), mat(FRAME))
	box(root, Vector3(2.2, 1.3, 0.1), Vector3(0.0, 0.85, 0.62), mat(GUNMETAL))
	box(root, Vector3(2.5, 0.12, 0.14), Vector3(0.0, 1.55, 0.66), mat(VIOLET, 1.0))
	cyl(root, 0.1, 0.1, 2.4, Vector3(2.0, 1.4, 1.5), mat(SHELL_DARK), 5)
	box(root, Vector3(1.6, 0.14, 0.14), Vector3(1.3, 2.55, 1.5), mat(SHELL_DARK))
	box(root, Vector3(0.3, 0.3, 0.3), Vector3(0.6, 2.3, 1.5), mat(FRAME))
	box(root, Vector3(1.5, 0.3, 0.85), Vector3(-0.9, 0.55, 1.5), mat(FRAME))
	box(root, Vector3(1.2, 0.25, 0.9), Vector3(-0.95, 0.8, 1.5), mat(SHELL))


static func _ward_node(root: Node3D, team: Color) -> void:
	cyl(root, 0.75, 0.9, 0.4, Vector3(0.0, 0.2, 0.0), mat(FRAME), 6)
	cyl(root, 0.35, 0.5, 0.5, Vector3(0.0, 0.65, 0.0), mat(SHELL_DARK), 6)
	ring(root, 0.78, 0.86, Vector3(0.0, 0.42, 0.0), team_mat(team))
	var t: Node3D = _turret(root, Vector3(0.0, 0.9, 0.0))
	ball(t, 0.42, Vector3(0.0, 0.3, 0.0), mat(SHELL), 8)
	for z: float in [-0.15, 0.15]:
		barrel(t, 0.045, 0.8, Vector3(0.25, 0.32, z), mat(FRAME))
	box(t, Vector3(0.08, 0.1, 0.3), Vector3(0.4, 0.44, 0.0), mat(VIOLET, 1.6))
	box(t, Vector3(0.3, 0.08, 0.3), Vector3(-0.15, 0.7, 0.0), team_mat(team))


static func _oracle(root: Node3D, team: Color) -> void:
	_hex_base(root, 3.0)
	cyl(root, 1.6, 2.0, 0.9, Vector3(0.0, 0.65, 0.0), mat(SHELL), 6)
	cyl(root, 1.65, 1.65, 0.16, Vector3(0.0, 1.0, 0.0), team_mat(team), 6)
	for i: int in 6:
		var ang: float = float(i) * TAU / 6.0
		cyl(root, 0.06, 0.1, 3.0, Vector3(cos(ang) * 1.9, 2.2, sin(ang) * 1.9), mat(SHELL_DARK), 4, Vector3(sin(ang) * 0.25, 0.0, -cos(ang) * 0.25))
	ring(root, 1.2, 1.32, Vector3(0.0, 3.0, 0.0), team_mat(team))
	# A slowly turning crystal hangs in the middle.
	var crystal: Node3D = group(root, "Spin", Vector3(0.0, 3.0, 0.0))
	wedge(crystal, Vector3(0.9, 1.1, 0.9), Vector3(0.0, 0.55, 0.0), mat(VIOLET, 1.4), 0.5)
	wedge(crystal, Vector3(0.9, 1.1, 0.9), Vector3(0.0, -0.55, 0.0), mat(VIOLET, 1.4), 0.5, Vector3(PI, 0.0, 0.0))
	_pole_lamp(root, Vector3(-2.2, 0.2, 1.4), 1.6, VIOLET)


# ---------------------------------------------------------- Verdigris Order

## An armored foot knight: greaves, a broad cuirass with a team tabard,
## bronze pauldrons, a crested helm with a lit visor and, usually, a shield.
static func _knight(root: Node3D, team: Color, shield: bool) -> void:
	for z: float in [-0.12, 0.12]:
		box(root, Vector3(0.27, 0.14, 0.18), Vector3(0.03, 0.07, z), mat(BRONZE_DARK))
		box(root, Vector3(0.19, 0.5, 0.18), Vector3(0.0, 0.38, z), mat(COPPER_DARK))
		box(root, Vector3(0.21, 0.1, 0.2), Vector3(0.02, 0.5, z), mat(BRONZE))
	box(root, Vector3(0.36, 0.08, 0.52), Vector3(0.0, 0.66, 0.0), mat(BRONZE))
	box(root, Vector3(0.34, 0.5, 0.5), Vector3(0.0, 0.93, 0.0), mat(COPPER))
	box(root, Vector3(0.05, 0.56, 0.28), Vector3(0.19, 0.82, 0.0), team_mat(team))
	for z: float in [-0.34, 0.34]:
		box(root, Vector3(0.3, 0.14, 0.22), Vector3(0.0, 1.15, z), mat(BRONZE))
		box(root, Vector3(0.14, 0.36, 0.14), Vector3(0.05, 0.92, z * 0.97), mat(COPPER_DARK), Vector3(0.0, 0.0, 0.3))
	var helm: MeshInstance3D = ball(root, 0.17, Vector3(0.02, 1.34, 0.0), mat(COPPER), 6)
	helm.scale = Vector3(1.0, 0.92, 1.0)
	box(root, Vector3(0.3, 0.12, 0.05), Vector3(-0.02, 1.5, 0.0), team_mat(team))
	box(root, Vector3(0.05, 0.045, 0.2), Vector3(0.17, 1.35, 0.0), mat(AMBER, 1.7))
	if shield:
		box(root, Vector3(0.06, 0.5, 0.36), Vector3(0.2, 0.92, -0.42), team_mat(team))
		box(root, Vector3(0.05, 0.56, 0.42), Vector3(0.18, 0.92, -0.42), mat(BRONZE))
		box(root, Vector3(0.06, 0.12, 0.12), Vector3(0.23, 0.94, -0.42), mat(BRONZE))


## One pair of legs for a walking machine: a hip joint, a thigh raked back,
## a shin raked forward, a knee plate and a broad foot, either side.
static func _legs(root: Node3D, x: float, half_width: float, hip: float) -> void:
	for side: float in [-1.0, 1.0]:
		var z: float = side * half_width
		box(root, Vector3(0.34, 0.3, 0.28), Vector3(x, hip, z), mat(BRONZE_DARK))
		box(root, Vector3(0.24, hip * 0.62, 0.22), Vector3(x - 0.13, hip * 0.72, z), mat(COPPER), Vector3(0.0, 0.0, -0.45))
		box(root, Vector3(0.19, hip * 0.66, 0.19), Vector3(x - 0.04, hip * 0.31, z), mat(BRONZE), Vector3(0.0, 0.0, 0.36))
		box(root, Vector3(0.2, 0.2, 0.26), Vector3(x - 0.24, hip * 0.52, z), mat(COPPER_DARK))
		box(root, Vector3(0.52, 0.1, 0.36), Vector3(x + 0.1, 0.05, z), mat(BRONZE_DARK))
		box(root, Vector3(0.16, 0.08, 0.38), Vector3(x + 0.3, 0.1, z), mat(BRONZE))


## The body of a walker on `pairs` pairs of legs: a bronze keel, a copper
## hull with a raked prow, a team shield hung on each flank and two smoking
## stacks at the back. The deck is at hip + 0.65.
static func _strider(root: Node3D, team: Color, length: float, width: float, hip: float, pairs: int) -> void:
	if pairs >= 2:
		_legs(root, length * 0.3, width * 0.5 + 0.12, hip)
		_legs(root, -length * 0.3, width * 0.5 + 0.12, hip)
	else:
		_legs(root, 0.0, width * 0.5 + 0.12, hip)
	box(root, Vector3(length * 0.96, 0.3, width * 0.8), Vector3(0.0, hip + 0.05, 0.0), mat(BRONZE_DARK))
	box(root, Vector3(length * 0.86, 0.46, width), Vector3(-length * 0.04, hip + 0.42, 0.0), mat(COPPER))
	wedge(root, Vector3(length * 0.26, 0.46, width), Vector3(length * 0.52, hip + 0.42, 0.0), mat(COPPER), 0.0)
	box(root, Vector3(length * 0.9, 0.08, width + 0.05), Vector3(-length * 0.03, hip + 0.22, 0.0), mat(BRONZE))
	box(root, Vector3(length * 0.5, 0.05, width * 0.6), Vector3(-length * 0.1, hip + 0.66, 0.0), mat(COPPER_DARK))
	for side: float in [-1.0, 1.0]:
		var z: float = side * (width * 0.5 + 0.05)
		box(root, Vector3(length * 0.46, 0.44, 0.06), Vector3(-length * 0.06, hip + 0.42, z), team_mat(team))
		box(root, Vector3(length * 0.5, 0.06, 0.08), Vector3(-length * 0.06, hip + 0.66, z), mat(BRONZE))
		box(root, Vector3(0.16, 0.16, 0.08), Vector3(-length * 0.06, hip + 0.42, z + side * 0.02), mat(BRONZE))
		cyl(root, 0.07, 0.09, 0.5, Vector3(-length * 0.42, hip + 0.9, side * width * 0.26), mat(BRONZE_DARK), 6)
		cyl(root, 0.08, 0.08, 0.05, Vector3(-length * 0.42, hip + 1.16, side * width * 0.26), mat(AMBER, 1.3), 6)
		lamp(root, Vector3(length * 0.6, hip + 0.3, side * width * 0.3), AMBER, 0.1)


## A round bronze-banded turret for the walkers.
static func _drum_turret(t: Node3D, team: Color, radius: float, height: float) -> void:
	cyl(t, radius * 0.9, radius, height, Vector3(0.0, height * 0.5, 0.0), mat(COPPER_DARK), 8)
	cyl(t, radius * 1.03, radius * 1.03, 0.08, Vector3(0.0, height * 0.3, 0.0), mat(BRONZE), 8)
	cyl(t, radius * 0.55, radius * 0.62, 0.1, Vector3(-radius * 0.15, height + 0.05, 0.0), team_mat(team), 8)
	box(t, Vector3(0.07, height * 0.26, radius * 0.8), Vector3(radius * 0.86, height * 0.66, 0.0), mat(AMBER, 1.6))


static func _dray(root: Node3D, team: Color) -> void:
	_strider(root, team, 2.3, 1.2, 0.55, 2)
	box(root, Vector3(0.6, 0.46, 1.0), Vector3(0.72, 1.43, 0.0), mat(COPPER_DARK))
	box(root, Vector3(0.05, 0.14, 0.8), Vector3(1.03, 1.47, 0.0), mat(AMBER, 1.2))
	box(root, Vector3(0.64, 0.06, 1.06), Vector3(0.72, 1.68, 0.0), mat(BRONZE))
	box(root, Vector3(1.3, 0.3, 1.24), Vector3(-0.4, 1.33, 0.0), mat(BRONZE_DARK))
	_cargo(root, Vector3(-0.4, 1.42, 0.0), Vector3(1.15, 0.5, 1.05))


static func _outrider(root: Node3D, team: Color) -> void:
	_strider(root, team, 1.4, 0.8, 0.75, 1)
	aerial(root, Vector3(-0.5, 1.4, 0.25), 0.8, AMBER)
	var t: Node3D = _turret(root, Vector3(0.05, 1.4, 0.0))
	_drum_turret(t, team, 0.26, 0.2)
	barrel(t, 0.035, 0.66, Vector3(0.18, 0.11, 0.0), mat(GUNMETAL))


static func _thresher(root: Node3D, team: Color) -> void:
	_strider(root, team, 1.8, 1.1, 0.8, 1)
	var t: Node3D = _turret(root, Vector3(-0.05, 1.45, 0.0))
	_drum_turret(t, team, 0.46, 0.34)
	for z: float in [-0.56, 0.56]:
		box(t, Vector3(0.5, 0.26, 0.24), Vector3(0.1, 0.2, z), mat(COPPER))
		box(t, Vector3(0.52, 0.06, 0.26), Vector3(0.1, 0.35, z), mat(BRONZE))
		for k: float in [-0.06, 0.06]:
			barrel(t, 0.04, 0.9, Vector3(0.3, 0.2 + k, z), mat(GUNMETAL))


static func _castellan(root: Node3D, team: Color) -> void:
	_strider(root, team, 2.8, 1.5, 0.7, 2)
	hatch(root, Vector3(0.9, 1.37, 0.42), 0.17, COPPER_DARK)
	var t: Node3D = _turret(root, Vector3(-0.15, 1.35, 0.0))
	box(t, Vector3(1.25, 0.5, 1.15), Vector3(0.0, 0.25, 0.0), mat(COPPER_DARK))
	wedge(t, Vector3(0.45, 0.5, 1.15), Vector3(0.85, 0.25, 0.0), mat(COPPER_DARK), 0.0)
	box(t, Vector3(1.29, 0.08, 1.19), Vector3(0.0, 0.14, 0.0), mat(BRONZE))
	for z: float in [-0.62, 0.62]:
		box(t, Vector3(0.7, 0.36, 0.08), Vector3(-0.1, 0.3, z), mat(BRONZE))
	box(t, Vector3(0.36, 0.36, 0.5), Vector3(0.95, 0.26, 0.0), mat(BRONZE_DARK))
	barrel(t, 0.11, 1.9, Vector3(1.05, 0.26, 0.0), mat(GUNMETAL))
	cyl(t, 0.16, 0.16, 0.24, Vector3(2.95, 0.26, 0.0), mat(BRONZE), 8, Vector3(0.0, 0.0, -PI * 0.5))
	cyl(t, 0.14, 0.14, 0.08, Vector3(1.6, 0.26, 0.0), mat(BRONZE), 8, Vector3(0.0, 0.0, -PI * 0.5))
	box(t, Vector3(0.6, 0.1, 0.5), Vector3(-0.25, 0.55, 0.0), team_mat(team))
	cyl(t, 0.17, 0.2, 0.14, Vector3(-0.3, 0.57, 0.36), mat(COPPER), 8)
	box(t, Vector3(0.05, 0.05, 0.16), Vector3(-0.12, 0.6, 0.36), mat(AMBER, 1.6))
	aerial(t, Vector3(-0.55, 0.5, -0.45), 0.9, AMBER)


static func _canopy(root: Node3D, team: Color) -> void:
	_strider(root, team, 2.2, 1.25, 0.65, 2)
	var t: Node3D = _turret(root, Vector3(-0.1, 1.3, 0.0))
	_drum_turret(t, team, 0.5, 0.36)
	for side: float in [-1.0, 1.0]:
		box(t, Vector3(0.5, 0.3, 0.26), Vector3(0.15, 0.58, side * 0.52), mat(COPPER), Vector3(0.0, 0.0, 0.62))
		for k: float in [-0.07, 0.07]:
			cyl(t, 0.04, 0.04, 1.05, Vector3(0.58, 0.9, side * 0.52 + k), mat(GUNMETAL), 5, Vector3(0.0, 0.0, -0.95))
	cyl(t, 0.26, 0.12, 0.14, Vector3(-0.32, 0.5, 0.0), mat(BRONZE), 8)
	ball(t, 0.13, Vector3(-0.32, 0.62, 0.0), mat(AMBER, 1.6), 6)


static func _mangonel(root: Node3D, team: Color) -> void:
	_strider(root, team, 2.6, 1.35, 0.65, 2)
	for z: float in [-0.9, 0.9]:
		box(root, Vector3(0.5, 0.1, 0.16), Vector3(-1.1, 0.5, z), mat(BRONZE_DARK), Vector3(0.0, 0.0, 0.5))
	var t: Node3D = _turret(root, Vector3(-0.3, 1.3, 0.0))
	_drum_turret(t, team, 0.56, 0.4)
	cyl(t, 0.14, 0.24, 2.3, Vector3(0.8, 1.02, 0.0), mat(BRONZE), 8, Vector3(0.0, 0.0, -0.95))
	for d: float in [0.5, 1.1, 1.7]:
		cyl(t, 0.23, 0.23, 0.07, Vector3(-0.13 + d * 0.81, 0.36 + d * 0.58, 0.0), mat(COPPER), 8, Vector3(0.0, 0.0, -0.95))
	cyl(t, 0.17, 0.17, 0.1, Vector3(1.76, 1.71, 0.0), mat(AMBER, 1.4), 8, Vector3(0.0, 0.0, -0.95))
	box(t, Vector3(0.5, 0.5, 0.8), Vector3(-0.6, 0.3, 0.0), mat(BRONZE_DARK))
	for z: float in [-0.3, 0.3]:
		box(t, Vector3(1.2, 0.07, 0.07), Vector3(0.5, 0.74, z), mat(COPPER_DARK), Vector3(0.0, 0.0, 0.5))


## The paved stone slab the Order builds on, with a lit bollard at each corner.
static func _stone_base(root: Node3D, w: float, d: float, h: float = 0.4) -> void:
	box(root, Vector3(w, h, d), Vector3(0.0, 0.0, 0.0), mat(STONE_DARK))
	box(root, Vector3(w - 0.8, 0.05, d - 0.8), Vector3(0.0, h * 0.5 + 0.02, 0.0), mat(STONE))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var at: Vector3 = Vector3(sx * (w * 0.5 - 0.24), h * 0.5, sz * (d * 0.5 - 0.24))
			box(root, Vector3(0.3, 0.5, 0.3), at + Vector3(0.0, 0.25, 0.0), mat(STONE))
			box(root, Vector3(0.36, 0.07, 0.36), at + Vector3(0.0, 0.52, 0.0), mat(BRONZE))
			box(root, Vector3(0.16, 0.14, 0.16), at + Vector3(0.0, 0.62, 0.0), mat(AMBER, 1.6))


## Merlons along the top of a square wall, `half` out from (cx, cz).
static func _battlements(root: Node3D, cx: float, cz: float, half: float, y: float) -> void:
	var count: int = maxi(3, int(round(half * 2.0 / 0.72)))
	for i: int in count:
		var along: float = lerpf(-half + 0.18, half - 0.18, float(i) / float(count - 1))
		for side: float in [-1.0, 1.0]:
			box(root, Vector3(0.34, 0.34, 0.26), Vector3(cx + along, y + 0.17, cz + side * (half - 0.13)), mat(STONE))
			box(root, Vector3(0.26, 0.34, 0.34), Vector3(cx + side * (half - 0.13), y + 0.17, cz + along), mat(STONE))


## A copper gable roof with a bronze ridge.
static func _copper_roof(root: Node3D, length: float, height: float, width: float, pos: Vector3) -> void:
	roof(root, length, height, width, pos, mat(COPPER, 0.0, 0.4, 0.6))
	box(root, Vector3(length + 0.1, 0.1, 0.14), pos + Vector3(0.0, height * 0.5, 0.0), mat(BRONZE))


## A banner in the team colour hanging from a bronze pole.
static func _banner(root: Node3D, pos: Vector3, team: Color, height: float = 2.4) -> void:
	cyl(root, 0.045, 0.05, height, pos + Vector3(0.0, height * 0.5, 0.0), mat(BRONZE), 5)
	box(root, Vector3(0.5, 0.05, 0.05), pos + Vector3(0.2, height - 0.1, 0.0), mat(BRONZE))
	box(root, Vector3(0.44, 0.9, 0.04), pos + Vector3(0.24, height - 0.6, 0.0), team_mat(team))
	box(root, Vector3(0.1, 0.1, 0.1), pos + Vector3(0.0, height + 0.05, 0.0), mat(AMBER, 1.4))


static func _keep(root: Node3D, team: Color) -> void:
	_stone_base(root, 7.7, 7.7, 0.5)
	box(root, Vector3(4.8, 2.5, 4.8), Vector3(0.0, 1.5, 0.0), mat(STONE))
	box(root, Vector3(4.9, 0.3, 4.9), Vector3(0.0, 2.2, 0.0), team_mat(team))
	_battlements(root, 0.0, 0.0, 2.4, 2.75)
	box(root, Vector3(2.9, 1.8, 2.9), Vector3(0.0, 3.6, 0.0), mat(STONE))
	box(root, Vector3(3.0, 0.14, 3.0), Vector3(0.0, 3.2, 0.0), mat(BRONZE))
	_battlements(root, 0.0, 0.0, 1.45, 4.5)
	# Round corner towers under copper caps.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var at: Vector3 = Vector3(sx * 2.75, 0.0, sz * 2.75)
			cyl(root, 0.8, 0.9, 3.0, at + Vector3(0.0, 1.7, 0.0), mat(STONE), 8)
			cyl(root, 0.92, 0.92, 0.12, at + Vector3(0.0, 3.2, 0.0), mat(BRONZE), 8)
			cyl(root, 0.05, 0.95, 1.1, at + Vector3(0.0, 3.8, 0.0), mat(COPPER, 0.0, 0.4, 0.6), 8)
			box(root, Vector3(0.1, 0.1, 0.1), at + Vector3(0.0, 4.4, 0.0), mat(AMBER, 1.5))
			box(root, Vector3(0.14, 0.46, 0.14), at + Vector3(sx * 0.86, 2.1, sz * 0.0), mat(AMBER, 1.0))
	var pane: Vector3 = Vector3(0.34, 0.6, 0.06)
	var pane_x: Vector3 = Vector3(0.06, 0.6, 0.34)
	for side: float in [-1.0, 1.0]:
		windows(root, Vector3(-1.2, 1.35, side * 2.42), Vector3(0.8, 0.0, 0.0), 4, pane, WINDOW_WARM)
		windows(root, Vector3(side * 2.42, 1.35, -1.2), Vector3(0.0, 0.0, 0.8), 4, pane_x, WINDOW_WARM)
		windows(root, Vector3(-0.7, 3.75, side * 1.47), Vector3(0.7, 0.0, 0.0), 3, Vector3(0.28, 0.5, 0.06), WINDOW_WARM)
		windows(root, Vector3(side * 1.47, 3.75, -0.7), Vector3(0.0, 0.0, 0.7), 3, Vector3(0.06, 0.5, 0.28), WINDOW_WARM)
	# The gate, with a banner either side.
	box(root, Vector3(0.16, 1.5, 1.5), Vector3(2.46, 1.0, 0.0), mat(GUNMETAL))
	box(root, Vector3(0.2, 0.2, 1.9), Vector3(2.48, 1.85, 0.0), mat(BRONZE))
	box(root, Vector3(0.9, 0.16, 2.2), Vector3(3.2, 0.33, 0.0), mat(STONE))
	_banner(root, Vector3(2.6, 0.25, 1.25), team, 2.6)
	_banner(root, Vector3(2.6, 0.25, -1.25), team, 2.6)
	# Command spire: the root of the signal grid.
	cyl(root, 0.16, 0.3, 3.4, Vector3(0.9, 6.2, 0.9), mat(BRONZE, 0.0, 0.6, 0.4), 6)
	ring(root, 0.75, 0.9, Vector3(0.9, 6.5, 0.9), team_mat(team))
	ring(root, 0.45, 0.58, Vector3(0.9, 7.2, 0.9), mat(AMBER, 1.0))
	ball(root, 0.24, Vector3(0.9, 8.0, 0.9), mat(team, 1.4))
	_spin_arms(root, Vector3(0.9, 5.5, 0.9), 0.6, BRONZE)
	var t: Node3D = _turret(root, Vector3(-0.9, 4.5, -0.9))
	box(t, Vector3(0.8, 0.4, 0.7), Vector3(0.0, 0.2, 0.0), mat(COPPER_DARK))
	barrel(t, 0.06, 0.9, Vector3(0.35, 0.25, 0.14), mat(GUNMETAL))
	barrel(t, 0.06, 0.9, Vector3(0.35, 0.25, -0.14), mat(GUNMETAL))


static func _lantern(root: Node3D, team: Color) -> void:
	cyl(root, 0.75, 0.9, 0.4, Vector3(0.0, 0.2, 0.0), mat(STONE_DARK), 8)
	cyl(root, 0.3, 0.5, 0.7, Vector3(0.0, 0.7, 0.0), mat(STONE), 8)
	cyl(root, 0.2, 0.28, 2.6, Vector3(0.0, 2.3, 0.0), mat(STONE), 8)
	ring(root, 0.5, 0.62, Vector3(0.0, 2.9, 0.0), team_mat(team))
	# The lamp itself: a glowing drum in a bronze cage under a copper cap.
	cyl(root, 0.5, 0.5, 0.08, Vector3(0.0, 3.62, 0.0), mat(BRONZE), 8)
	cyl(root, 0.34, 0.34, 0.6, Vector3(0.0, 3.96, 0.0), mat(AMBER, 1.3), 8)
	for i: int in 4:
		var ang: float = float(i) * TAU / 4.0 + 0.78
		box(root, Vector3(0.06, 0.62, 0.06), Vector3(cos(ang) * 0.42, 3.96, sin(ang) * 0.42), mat(BRONZE))
	cyl(root, 0.5, 0.5, 0.08, Vector3(0.0, 4.3, 0.0), mat(BRONZE), 8)
	cyl(root, 0.04, 0.55, 0.5, Vector3(0.0, 4.6, 0.0), mat(COPPER, 0.0, 0.4, 0.6), 8)
	ball(root, 0.12, Vector3(0.0, 4.92, 0.0), mat(team, 1.4))
	_spin_arms(root, Vector3(0.0, 2.2, 0.0), 0.45, BRONZE)


static func _tithe_barn(root: Node3D, team: Color) -> void:
	_stone_base(root, 5.7, 5.7)
	box(root, Vector3(4.2, 1.6, 2.8), Vector3(0.0, 1.0, -0.9), mat(STONE))
	box(root, Vector3(4.25, 0.22, 2.85), Vector3(0.0, 1.55, -0.9), team_mat(team))
	_copper_roof(root, 4.5, 1.1, 3.1, Vector3(0.0, 2.35, -0.9))
	box(root, Vector3(1.7, 1.25, 0.1), Vector3(0.0, 0.83, 0.52), mat(GUNMETAL))
	box(root, Vector3(2.0, 0.14, 0.16), Vector3(0.0, 1.5, 0.54), mat(BRONZE))
	windows(root, Vector3(-1.6, 1.1, 0.52), Vector3(3.2, 0.0, 0.0), 2, Vector3(0.36, 0.44, 0.06), WINDOW_WARM)
	for i: int in 3:
		cyl(root, 0.28, 0.28, 0.6, Vector3(-1.9 + 0.62 * float(i), 0.5, 1.7), mat(BRONZE), 8)
		cyl(root, 0.29, 0.29, 0.06, Vector3(-1.9 + 0.62 * float(i), 0.6, 1.7), mat(BRONZE_DARK), 8)
	box(root, Vector3(1.3, 0.12, 0.8), Vector3(1.4, 0.62, 1.6), mat(BRONZE_DARK))
	box(root, Vector3(1.1, 0.4, 0.7), Vector3(1.4, 0.88, 1.6), mat(RUST, 0.0, 0.4, 0.7))
	wheel(root, 0.3, 0.14, Vector3(1.4, 0.5, 2.06))
	wheel(root, 0.3, 0.14, Vector3(1.4, 0.5, 1.14))
	_banner(root, Vector3(2.3, 0.2, -2.3), team)


static func _chapterhouse(root: Node3D, team: Color) -> void:
	_stone_base(root, 5.7, 5.7)
	box(root, Vector3(4.2, 1.7, 2.8), Vector3(0.3, 1.05, -0.8), mat(STONE))
	box(root, Vector3(4.25, 0.22, 2.85), Vector3(0.3, 1.6, -0.8), team_mat(team))
	_copper_roof(root, 4.5, 1.1, 3.1, Vector3(0.3, 2.45, -0.8))
	box(root, Vector3(1.0, 1.3, 0.1), Vector3(0.6, 0.85, 0.62), mat(GUNMETAL))
	box(root, Vector3(1.3, 0.14, 0.16), Vector3(0.6, 1.55, 0.64), mat(BRONZE))
	windows(root, Vector3(-0.6, 1.1, 0.62), Vector3(2.4, 0.0, 0.0), 2, Vector3(0.34, 0.5, 0.06), WINDOW_WARM)
	windows(root, Vector3(2.42, 1.1, -1.6), Vector3(0.0, 0.0, 0.8), 3, Vector3(0.06, 0.5, 0.34), WINDOW_WARM)
	# Bell tower.
	box(root, Vector3(1.1, 3.4, 1.1), Vector3(-2.0, 1.9, 1.3), mat(STONE))
	box(root, Vector3(1.2, 0.12, 1.2), Vector3(-2.0, 2.9, 1.3), mat(BRONZE))
	for sx: float in [-1.0, 1.0]:
		box(root, Vector3(0.06, 0.5, 0.5), Vector3(-2.0 + sx * 0.56, 3.25, 1.3), mat(AMBER, 1.0))
		box(root, Vector3(0.5, 0.5, 0.06), Vector3(-2.0, 3.25, 1.3 + sx * 0.56), mat(AMBER, 1.0))
	cyl(root, 0.05, 0.95, 1.0, Vector3(-2.0, 4.1, 1.3), mat(COPPER, 0.0, 0.4, 0.6), 4, Vector3(0.0, PI * 0.25, 0.0))
	_banner(root, Vector3(1.5, 0.2, 1.2), team)
	_banner(root, Vector3(-0.3, 0.2, 1.2), team)


static func _armoury(root: Node3D, team: Color) -> void:
	_stone_base(root, 5.7, 5.7)
	box(root, Vector3(4.6, 2.2, 3.0), Vector3(0.0, 1.3, -0.8), mat(STONE))
	box(root, Vector3(4.65, 0.26, 3.05), Vector3(0.0, 2.0, -0.8), team_mat(team))
	_copper_roof(root, 4.9, 1.0, 3.3, Vector3(0.0, 2.9, -0.8))
	# The great door, framed in bronze.
	box(root, Vector3(2.4, 1.7, 0.1), Vector3(0.0, 1.05, 0.72), mat(GUNMETAL))
	box(root, Vector3(2.8, 0.2, 0.2), Vector3(0.0, 2.0, 0.74), mat(BRONZE))
	for sx: float in [-1.0, 1.0]:
		box(root, Vector3(0.22, 1.8, 0.22), Vector3(sx * 1.32, 1.1, 0.74), mat(BRONZE))
		lamp(root, Vector3(sx * 1.32, 2.2, 0.82), AMBER, 0.14)
	windows(root, Vector3(-2.32, 1.3, -1.7), Vector3(0.0, 0.0, 0.9), 3, Vector3(0.06, 0.5, 0.4), WINDOW_WARM)
	windows(root, Vector3(2.32, 1.3, -1.7), Vector3(0.0, 0.0, 0.9), 3, Vector3(0.06, 0.5, 0.4), WINDOW_WARM)
	# Forge chimney, a hoist and a walker's leg on the bench.
	cyl(root, 0.3, 0.4, 2.4, Vector3(-1.7, 3.2, -1.7), mat(STONE_DARK), 6)
	cyl(root, 0.32, 0.32, 0.08, Vector3(-1.7, 4.42, -1.7), mat(AMBER, 1.4), 6)
	cyl(root, 0.1, 0.1, 2.5, Vector3(2.2, 1.45, 1.8), mat(BRONZE), 5)
	box(root, Vector3(1.5, 0.14, 0.14), Vector3(1.55, 2.65, 1.8), mat(BRONZE))
	box(root, Vector3(0.3, 0.3, 0.3), Vector3(0.9, 2.4, 1.8), mat(BRONZE_DARK))
	box(root, Vector3(1.3, 0.3, 0.8), Vector3(-1.4, 0.55, 1.8), mat(BRONZE_DARK))
	box(root, Vector3(0.24, 0.7, 0.22), Vector3(-1.5, 0.95, 1.8), mat(COPPER), Vector3(0.0, 0.0, 0.9))


static func _rampart(root: Node3D, team: Color) -> void:
	cyl(root, 0.85, 0.95, 0.5, Vector3(0.0, 0.25, 0.0), mat(STONE_DARK), 8)
	cyl(root, 0.62, 0.72, 0.9, Vector3(0.0, 0.95, 0.0), mat(STONE), 8)
	ring(root, 0.82, 0.9, Vector3(0.0, 0.5, 0.0), team_mat(team))
	for i: int in 6:
		var ang: float = float(i) * TAU / 6.0
		box(root, Vector3(0.24, 0.24, 0.24), Vector3(cos(ang) * 0.58, 1.5, sin(ang) * 0.58), mat(STONE), Vector3(0.0, -ang, 0.0))
	var t: Node3D = _turret(root, Vector3(0.0, 1.42, 0.0))
	_drum_turret(t, team, 0.4, 0.36)
	box(t, Vector3(0.3, 0.26, 0.36), Vector3(0.4, 0.2, 0.0), mat(BRONZE_DARK))
	barrel(t, 0.09, 1.0, Vector3(0.45, 0.2, 0.0), mat(GUNMETAL))
	cyl(t, 0.13, 0.13, 0.16, Vector3(1.45, 0.2, 0.0), mat(BRONZE), 8, Vector3(0.0, 0.0, -PI * 0.5))


static func _watchfire(root: Node3D, team: Color) -> void:
	cyl(root, 0.85, 0.95, 0.5, Vector3(0.0, 0.25, 0.0), mat(STONE_DARK), 8)
	cyl(root, 0.45, 0.6, 1.3, Vector3(0.0, 1.15, 0.0), mat(STONE), 8)
	ring(root, 0.82, 0.9, Vector3(0.0, 0.5, 0.0), team_mat(team))
	cyl(root, 0.62, 0.5, 0.14, Vector3(0.0, 1.85, 0.0), mat(BRONZE), 8)
	# The fire that gives it its name.
	cyl(root, 0.22, 0.12, 0.16, Vector3(0.0, 0.62, 0.72), mat(BRONZE), 8)
	ball(root, 0.13, Vector3(0.0, 0.76, 0.72), mat(AMBER, 1.7), 6)
	var t: Node3D = _turret(root, Vector3(0.0, 1.92, 0.0))
	_drum_turret(t, team, 0.36, 0.3)
	for z: float in [-0.24, -0.08, 0.08, 0.24]:
		cyl(t, 0.04, 0.04, 1.2, Vector3(0.42, 0.66, z), mat(GUNMETAL), 5, Vector3(0.0, 0.0, -0.8))


static func _reliquary(root: Node3D, team: Color) -> void:
	_stone_base(root, 5.7, 5.7)
	cyl(root, 2.1, 2.2, 0.3, Vector3(0.0, 0.35, 0.0), mat(STONE), 8)
	cyl(root, 1.5, 1.6, 1.3, Vector3(0.0, 1.1, 0.0), mat(STONE), 8)
	cyl(root, 1.62, 1.62, 0.16, Vector3(0.0, 1.5, 0.0), team_mat(team), 8)
	for i: int in 8:
		var ang: float = float(i) * TAU / 8.0 + 0.39
		cyl(root, 0.1, 0.12, 1.5, Vector3(cos(ang) * 1.95, 1.25, sin(ang) * 1.95), mat(STONE), 6)
		box(root, Vector3(0.1, 0.5, 0.3), Vector3(cos(ang + 0.39) * 1.52, 1.0, sin(ang + 0.39) * 1.52), mat(AMBER, 0.9), Vector3(0.0, -ang - 0.39, 0.0))
	cyl(root, 2.15, 2.15, 0.14, Vector3(0.0, 2.05, 0.0), mat(BRONZE), 8)
	var dome: MeshInstance3D = ball(root, 1.7, Vector3(0.0, 2.1, 0.0), mat(COPPER, 0.0, 0.4, 0.6), 8)
	dome.scale = Vector3(1.0, 0.6, 1.0)
	# An armillary turning slowly above the dome.
	var sphere: Node3D = group(root, "Spin", Vector3(0.0, 3.7, 0.0))
	ball(sphere, 0.34, Vector3.ZERO, mat(AMBER, 1.5), 8)
	ring(sphere, 0.62, 0.7, Vector3.ZERO, mat(BRONZE, 0.0, 0.6, 0.4))
	var hoop: MeshInstance3D = ring(sphere, 0.78, 0.86, Vector3.ZERO, mat(BRONZE, 0.0, 0.6, 0.4))
	hoop.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	cyl(root, 0.06, 0.08, 0.6, Vector3(0.0, 3.2, 0.0), mat(BRONZE), 5)
	_banner(root, Vector3(2.2, 0.2, 2.2), team)
	_banner(root, Vector3(-2.2, 0.2, 2.2), team)


# ------------------------------------------------------------ Zephyr Accord

## The Accord's ground chassis: a navy frame on fat wheels under a pale body
## with a sloped nose, an orange stripe and lamps front and back.
static func _field_car(root: Node3D, team: Color, length: float, width: float, axles: int, height: float = 0.4) -> void:
	box(root, Vector3(length, 0.22, width * 0.86), Vector3(0.0, 0.46, 0.0), mat(NAVY))
	box(root, Vector3(length * 0.8, height, width), Vector3(-length * 0.08, 0.57 + height * 0.5, 0.0), mat(CLOUD))
	wedge(root, Vector3(length * 0.24, height, width), Vector3(length * 0.44, 0.57 + height * 0.5, 0.0), mat(CLOUD), 0.0)
	box(root, Vector3(length * 0.82, 0.09, width + 0.03), Vector3(-length * 0.07, 0.62, 0.0), team_mat(team))
	box(root, Vector3(length * 0.5, 0.05, width + 0.04), Vector3(-length * 0.12, 0.57 + height * 0.82, 0.0), mat(FLAME))
	for i: int in axles:
		var x: float = lerpf(-length * 0.36, length * 0.36, float(i) / float(maxi(1, axles - 1)))
		wheel(root, 0.32, 0.24, Vector3(x, 0.32, width * 0.5))
		wheel(root, 0.32, 0.24, Vector3(x, 0.32, -width * 0.5))
	_front(root, length * 0.5 + 0.02, 0.62, width * 0.32)
	_tail(root, -length * 0.5 - 0.01, 0.6, width * 0.34)


static func _tender(root: Node3D, team: Color) -> void:
	_field_car(root, team, 2.2, 1.15, 3, 0.3)
	box(root, Vector3(0.66, 0.6, 1.1), Vector3(0.66, 1.17, 0.0), mat(CLOUD))
	box(root, Vector3(0.05, 0.26, 0.9), Vector3(1.0, 1.24, 0.0), mat(GLASS, 0.15, 0.3, 0.2))
	box(root, Vector3(0.36, 0.24, 0.03), Vector3(0.68, 1.24, 0.56), mat(GLASS, 0.15, 0.3, 0.2))
	box(root, Vector3(0.36, 0.24, 0.03), Vector3(0.68, 1.24, -0.56), mat(GLASS, 0.15, 0.3, 0.2))
	box(root, Vector3(0.16, 0.08, 0.3), Vector3(0.66, 1.51, 0.0), mat(FLAME, 1.3))
	box(root, Vector3(1.36, 0.3, 1.22), Vector3(-0.42, 1.02, 0.0), mat(CLOUD_DARK))
	_cargo(root, Vector3(-0.42, 1.17, 0.0), Vector3(1.2, 0.5, 1.0))


static func _lookout(root: Node3D, team: Color) -> void:
	_field_car(root, team, 1.7, 0.95, 2, 0.34)
	cyl(root, 0.03, 0.04, 1.1, Vector3(-0.6, 1.5, 0.3), mat(GUNMETAL), 5)
	radar(root, Vector3(-0.6, 1.6, 0.3), 0.5, "Spin", CLOUD)
	var t: Node3D = _turret(root, Vector3(0.05, 0.93, 0.0))
	cyl(t, 0.2, 0.24, 0.2, Vector3(0.0, 0.1, 0.0), mat(CLOUD_DARK), 8)
	barrel(t, 0.035, 0.7, Vector3(0.12, 0.12, 0.0), mat(GUNMETAL))


static func _squall(root: Node3D, team: Color) -> void:
	_field_car(root, team, 2.2, 1.2, 3, 0.36)
	box(root, Vector3(0.6, 0.4, 1.0), Vector3(0.72, 1.13, 0.0), mat(CLOUD))
	box(root, Vector3(0.05, 0.2, 0.8), Vector3(1.03, 1.18, 0.0), mat(GLASS, 0.15, 0.3, 0.2))
	var t: Node3D = _turret(root, Vector3(-0.4, 0.95, 0.0))
	cyl(t, 0.46, 0.52, 0.28, Vector3(0.0, 0.14, 0.0), mat(CLOUD_DARK), 8)
	box(t, Vector3(0.5, 0.44, 0.7), Vector3(-0.08, 0.5, 0.0), mat(CLOUD))
	for z: float in [-0.26, -0.09, 0.09, 0.26]:
		cyl(t, 0.04, 0.04, 1.3, Vector3(0.52, 0.86, z), mat(GUNMETAL), 5, Vector3(0.0, 0.0, -0.9))
	box(t, Vector3(0.3, 0.08, 0.72), Vector3(-0.15, 0.76, 0.0), team_mat(team))


## The body of an aircraft: fuselage with a glazed nose, a tail boom and fin,
## a team stripe down the spine and running lights on the wingtips.
static func _airframe(root: Node3D, team: Color, length: float, girth: float, span: float, chord: float) -> void:
	box(root, Vector3(length * 0.55, girth, girth * 1.15), Vector3(length * 0.08, 0.5, 0.0), mat(CLOUD))
	wedge(root, Vector3(length * 0.26, girth, girth * 1.15), Vector3(length * 0.48, 0.5, 0.0), mat(CLOUD), 0.0)
	box(root, Vector3(length * 0.18, girth * 0.46, girth * 0.9), Vector3(length * 0.4, 0.5 + girth * 0.34, 0.0), mat(GLASS, 0.2, 0.3, 0.2), Vector3(0.0, 0.0, -0.3))
	box(root, Vector3(length * 0.42, girth * 0.5, girth * 0.5), Vector3(-length * 0.38, 0.5 + girth * 0.1, 0.0), mat(CLOUD_DARK))
	wedge(root, Vector3(length * 0.2, girth * 1.1, 0.08), Vector3(-length * 0.5, 0.5 + girth * 0.85, 0.0), mat(CLOUD), 0.0)
	box(root, Vector3(length * 0.16, 0.05, girth * 1.9), Vector3(-length * 0.52, 0.5 + girth * 0.4, 0.0), mat(CLOUD_DARK))
	box(root, Vector3(length * 0.1, girth * 0.5, 0.1), Vector3(-length * 0.54, 0.5 + girth * 1.1, 0.0), team_mat(team))
	box(root, Vector3(chord, 0.08, span), Vector3(0.0, 0.5 + girth * 0.3, 0.0), mat(CLOUD))
	box(root, Vector3(chord * 0.5, 0.09, span * 0.6), Vector3(0.0, 0.5 + girth * 0.31, 0.0), team_mat(team))
	box(root, Vector3(length * 0.5, 0.05, girth * 0.4), Vector3(length * 0.05, 0.5 + girth * 0.52, 0.0), mat(FLAME))
	lamp(root, Vector3(0.0, 0.5 + girth * 0.3, span * 0.5), Color(0.3, 1.0, 0.4), 0.08)
	lamp(root, Vector3(0.0, 0.5 + girth * 0.3, -span * 0.5), LAMP_RED, 0.08)


## An engine pod under a wing with a spinning rotor above it.
static func _lift_engine(root: Node3D, at: Vector3, radius: float, node_name: String) -> void:
	cyl(root, 0.15, 0.18, 0.36, at, mat(NAVY), 8)
	_rotor(root, at + Vector3(0.0, 0.26, 0.0), radius, node_name)


static func _swift(root: Node3D, team: Color) -> void:
	_airframe(root, team, 2.2, 0.5, 2.4, 0.5)
	_lift_engine(root, Vector3(0.0, 0.72, 1.2), 0.75, "Rotor0")
	_lift_engine(root, Vector3(0.0, 0.72, -1.2), 0.75, "Rotor1")
	for z: float in [-0.36, 0.36]:
		box(root, Vector3(1.2, 0.05, 0.06), Vector3(0.15, 0.08, z), mat(GUNMETAL))
		box(root, Vector3(0.05, 0.2, 0.05), Vector3(0.5, 0.18, z), mat(GUNMETAL))
		box(root, Vector3(0.05, 0.2, 0.05), Vector3(-0.2, 0.18, z), mat(GUNMETAL))
	var t: Node3D = _turret(root, Vector3(0.75, 0.2, 0.0))
	box(t, Vector3(0.26, 0.14, 0.26), Vector3.ZERO, mat(NAVY))
	barrel(t, 0.035, 0.55, Vector3(0.1, -0.02, 0.07), mat(GUNMETAL))
	barrel(t, 0.035, 0.55, Vector3(0.1, -0.02, -0.07), mat(GUNMETAL))


static func _lanner(root: Node3D, team: Color) -> void:
	_airframe(root, team, 2.8, 0.46, 2.0, 0.9)
	# Swept outer wings, a jet at the back and a missile under each wing.
	for side: float in [-1.0, 1.0]:
		box(root, Vector3(0.7, 0.07, 1.0), Vector3(-0.45, 0.64, side * 1.35), mat(CLOUD), Vector3(0.0, side * 0.5, 0.0))
		barrel(root, 0.07, 0.9, Vector3(-0.3, 0.48, side * 0.75), mat(CLOUD_DARK))
		cyl(root, 0.075, 0.0, 0.2, Vector3(0.7, 0.48, side * 0.75), mat(FLAME), 6, Vector3(0.0, 0.0, -PI * 0.5))
		cyl(root, 0.17, 0.2, 0.7, Vector3(-1.0, 0.56, side * 0.32), mat(NAVY), 8, Vector3(0.0, 0.0, -PI * 0.5))
		cyl(root, 0.13, 0.13, 0.06, Vector3(-1.37, 0.56, side * 0.32), mat(FLAME, 1.7), 8, Vector3(0.0, 0.0, -PI * 0.5))
	_rotor(root, Vector3(0.1, 0.98, 0.0), 0.0, "Rotor")


static func _condor(root: Node3D, team: Color) -> void:
	_airframe(root, team, 3.4, 0.7, 5.0, 0.9)
	box(root, Vector3(1.3, 0.2, 0.6), Vector3(0.1, 0.14, 0.0), mat(NAVY))
	box(root, Vector3(0.9, 0.06, 0.4), Vector3(0.1, 0.03, 0.0), mat(HAZARD))
	var i: int = 0
	for z: float in [-1.9, -0.95, 0.95, 1.9]:
		_lift_engine(root, Vector3(0.05, 0.84, z), 0.6, "Rotor%d" % i)
		i += 1
	for z: float in [-0.5, 0.5]:
		wedge(root, Vector3(0.5, 0.6, 0.07), Vector3(-1.75, 1.2, z), mat(CLOUD), 0.0)


## The pale concrete apron the Accord builds on: orange corner chevrons and
## a row of edge lamps in the team colour.
static func _apron(root: Node3D, w: float, d: float, team: Color, h: float = 0.4) -> void:
	box(root, Vector3(w, h, d), Vector3(0.0, 0.0, 0.0), mat(CONCRETE_DARK))
	box(root, Vector3(w - 0.5, 0.05, d - 0.5), Vector3(0.0, h * 0.5 + 0.02, 0.0), mat(CONCRETE))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var at: Vector3 = Vector3(sx * (w * 0.5 - 0.5), h * 0.5 + 0.06, sz * (d * 0.5 - 0.5))
			box(root, Vector3(0.7, 0.03, 0.16), at + Vector3(-sx * 0.2, 0.0, 0.0), mat(FLAME))
			box(root, Vector3(0.16, 0.03, 0.7), at + Vector3(0.0, 0.0, -sz * 0.2), mat(FLAME))
			lamp(root, at + Vector3(sx * 0.18, 0.06, sz * 0.18), team, 0.12)


## A landing circle painted on the apron.
static func _helipad(root: Node3D, at: Vector3, radius: float, team: Color) -> void:
	cyl(root, radius, radius, 0.05, at, mat(CONCRETE_DARK), 16)
	ring(root, radius - 0.14, radius, at + Vector3(0.0, 0.05, 0.0), team_mat(team))
	box(root, Vector3(0.2, 0.03, radius * 0.9), at + Vector3(-radius * 0.28, 0.05, 0.0), mat(HAZARD))
	box(root, Vector3(0.2, 0.03, radius * 0.9), at + Vector3(radius * 0.28, 0.05, 0.0), mat(HAZARD))
	box(root, Vector3(radius * 0.56, 0.03, 0.2), at + Vector3(0.0, 0.05, 0.0), mat(HAZARD))


## An arched hangar with its door facing +Z.
static func _arch(root: Node3D, at: Vector3, radius: float, depth: float, team: Color) -> void:
	arch(root, radius, depth, at, mat(CLOUD))
	for k: float in [-0.4, 0.0, 0.4]:
		arch(root, radius + 0.04, 0.12, at + Vector3(0.0, 0.0, depth * k), mat(CLOUD_DARK))
	arch(root, radius + 0.05, 0.22, at + Vector3(0.0, 0.0, depth * 0.5 - 0.14), team_mat(team))
	arch(root, radius - 0.22, 0.06, at + Vector3(0.0, 0.0, depth * 0.5 + 0.01), mat(GUNMETAL))
	box(root, Vector3(radius * 1.2, 0.1, 0.08), at + Vector3(0.0, radius * 0.72, depth * 0.5 + 0.04), mat(FLAME))


static func _aerie(root: Node3D, team: Color) -> void:
	_apron(root, 7.7, 7.7, team, 0.5)
	# Terminal block with a glazed upper floor.
	box(root, Vector3(4.6, 1.6, 3.2), Vector3(-0.9, 1.05, -1.3), mat(CLOUD))
	box(root, Vector3(4.65, 0.26, 3.25), Vector3(-0.9, 1.55, -1.3), team_mat(team))
	box(root, Vector3(4.2, 0.7, 2.8), Vector3(-0.9, 2.2, -1.3), mat(GLASS, 0.35, 0.3, 0.2))
	box(root, Vector3(4.7, 0.16, 3.3), Vector3(-0.9, 2.63, -1.3), mat(CLOUD_DARK))
	windows(root, Vector3(-2.7, 0.9, 0.31), Vector3(0.9, 0.0, 0.0), 5, Vector3(0.5, 0.4, 0.06))
	box(root, Vector3(1.2, 1.0, 0.1), Vector3(-0.9, 0.75, 0.33), mat(GUNMETAL))
	var dome: MeshInstance3D = ball(root, 0.9, Vector3(-2.3, 2.9, -1.6), mat(CLOUD, 0.0, 0.2, 0.5), 10)
	dome.scale = Vector3(1.0, 0.9, 1.0)
	# Control tower.
	cyl(root, 0.55, 0.75, 3.6, Vector3(2.4, 2.05, -2.3), mat(CLOUD), 8)
	cyl(root, 0.78, 0.78, 0.16, Vector3(2.4, 1.4, -2.3), team_mat(team), 8)
	cyl(root, 1.0, 0.8, 0.7, Vector3(2.4, 4.15, -2.3), mat(GLASS, 0.5, 0.3, 0.2), 8)
	cyl(root, 1.05, 1.05, 0.12, Vector3(2.4, 4.55, -2.3), mat(CLOUD_DARK), 8)
	radar(root, Vector3(2.4, 4.6, -2.3), 1.0, "Spin", CLOUD)
	_helipad(root, Vector3(1.5, 0.28, 1.7), 1.7, team)
	# Command mast: the root of the signal grid.
	cyl(root, 0.16, 0.28, 3.6, Vector3(0.9, 4.5, 0.9), mat(METAL, 0.0, 0.6, 0.4), 6)
	ring(root, 0.75, 0.9, Vector3(0.9, 5.2, 0.9), team_mat(team))
	ring(root, 0.45, 0.58, Vector3(0.9, 5.9, 0.9), mat(FLAME, 0.9))
	ball(root, 0.24, Vector3(0.9, 6.5, 0.9), mat(team, 1.4))
	box(root, Vector3(0.9, 1.6, 0.9), Vector3(0.9, 1.05, 0.9), mat(CLOUD_DARK))
	cyl(root, 0.05, 0.05, 2.0, Vector3(-3.2, 1.25, 3.0), mat(METAL), 5)
	cyl(root, 0.16, 0.06, 0.7, Vector3(-2.85, 2.2, 3.0), mat(FLAME), 6, Vector3(0.0, 0.0, -PI * 0.5))
	var t: Node3D = _turret(root, Vector3(-0.2, 2.72, -0.4))
	box(t, Vector3(0.8, 0.4, 0.7), Vector3(0.0, 0.2, 0.0), mat(CLOUD_DARK))
	barrel(t, 0.06, 0.9, Vector3(0.35, 0.25, 0.14), mat(GUNMETAL))
	barrel(t, 0.06, 0.9, Vector3(0.35, 0.25, -0.14), mat(GUNMETAL))


static func _mast(root: Node3D, team: Color) -> void:
	cyl(root, 0.75, 0.9, 0.35, Vector3(0.0, 0.17, 0.0), mat(CONCRETE_DARK), 8)
	# A lattice tower in warning bands.
	for i: int in 4:
		var ang: float = float(i) * TAU / 4.0 + 0.78
		cyl(root, 0.035, 0.05, 3.6, Vector3(cos(ang) * 0.3, 2.1, sin(ang) * 0.3), mat(CLOUD), 4, Vector3(sin(ang) * 0.14, 0.0, -cos(ang) * 0.14))
	for k: int in 5:
		var y: float = 0.7 + 0.75 * float(k)
		var wide: float = lerpf(0.86, 0.3, float(k) / 4.0)
		box(root, Vector3(wide, 0.07, wide), Vector3(0.0, y, 0.0), mat(FLAME if k % 2 == 0 else CLOUD))
	cyl(root, 0.05, 0.08, 1.4, Vector3(0.0, 4.4, 0.0), mat(METAL, 0.0, 0.6, 0.4), 6)
	ring(root, 0.6, 0.72, Vector3(0.0, 3.3, 0.0), team_mat(team))
	ring(root, 0.38, 0.48, Vector3(0.0, 4.1, 0.0), team_mat(team))
	ball(root, 0.2, Vector3(0.0, 5.15, 0.0), mat(team, 1.4))
	_spin_arms(root, Vector3(0.0, 2.75, 0.0), 0.5, CLOUD)


static func _hangar(root: Node3D, team: Color) -> void:
	_apron(root, 5.7, 5.7, team)
	_arch(root, Vector3(-0.5, 0.2, -0.9), 1.8, 3.4, team)
	for i: int in 2:
		cyl(root, 0.42, 0.42, 1.3, Vector3(2.0, 0.62, -1.6 + 1.0 * float(i)), mat(CLOUD), 10, Vector3(PI * 0.5, 0.0, 0.0))
		cyl(root, 0.44, 0.44, 0.14, Vector3(2.0, 0.62, -1.6 + 1.0 * float(i)), mat(FLAME), 10, Vector3(PI * 0.5, 0.0, 0.0))
	box(root, Vector3(1.0, 0.7, 0.9), Vector3(1.6, 0.55, 1.6), mat(CLOUD_DARK))
	box(root, Vector3(0.9, 0.6, 0.8), Vector3(0.5, 0.5, 2.0), mat(RUST, 0.0, 0.4, 0.7))
	box(root, Vector3(0.8, 0.5, 0.7), Vector3(1.1, 1.12, 1.75), mat(NAVY))
	cyl(root, 0.05, 0.05, 2.0, Vector3(-2.4, 1.2, 2.3), mat(METAL), 5)
	cyl(root, 0.16, 0.06, 0.7, Vector3(-2.05, 2.15, 2.3), mat(FLAME), 6, Vector3(0.0, 0.0, -PI * 0.5))


static func _roost(root: Node3D, team: Color) -> void:
	_apron(root, 5.7, 5.7, team)
	box(root, Vector3(4.6, 1.5, 2.8), Vector3(0.0, 0.95, -0.9), mat(CLOUD))
	box(root, Vector3(4.65, 0.22, 2.85), Vector3(0.0, 1.45, -0.9), team_mat(team))
	box(root, Vector3(4.8, 0.14, 3.0), Vector3(0.0, 1.77, -0.9), mat(CLOUD_DARK))
	windows(root, Vector3(-1.8, 1.0, 0.51), Vector3(0.9, 0.0, 0.0), 2, Vector3(0.5, 0.4, 0.06))
	windows(root, Vector3(0.9, 1.0, 0.51), Vector3(0.9, 0.0, 0.0), 2, Vector3(0.5, 0.4, 0.06))
	box(root, Vector3(0.9, 1.1, 0.1), Vector3(0.0, 0.75, 0.52), mat(GUNMETAL))
	box(root, Vector3(1.2, 0.08, 0.5), Vector3(0.0, 1.36, 0.76), mat(FLAME))
	for x: float in [-1.4, 1.4]:
		box(root, Vector3(0.7, 0.3, 0.7), Vector3(x, 2.0, -0.9), mat(METAL, 0.0, 0.6, 0.45))
	aerial(root, Vector3(2.0, 1.84, -2.0), 1.3)
	# A drill square with a flag.
	box(root, Vector3(2.4, 0.03, 1.4), Vector3(-0.9, 0.24, 1.8), mat(CONCRETE_DARK))
	cyl(root, 0.05, 0.05, 2.8, Vector3(2.2, 1.6, 2.0), mat(METAL), 5)
	box(root, Vector3(0.9, 0.5, 0.05), Vector3(2.66, 2.7, 2.0), team_mat(team))


static func _flight_deck(root: Node3D, team: Color) -> void:
	_apron(root, 7.7, 5.7, team)
	_arch(root, Vector3(-2.2, 0.2, -0.8), 1.5, 3.2, team)
	_helipad(root, Vector3(1.5, 0.24, 0.3), 1.9, team)
	# Flight control cabin on stilts.
	for x: float in [2.5, 3.3]:
		cyl(root, 0.06, 0.06, 1.4, Vector3(x, 0.9, -2.2), mat(METAL), 5)
	box(root, Vector3(1.3, 0.7, 0.9), Vector3(2.9, 1.9, -2.2), mat(CLOUD))
	box(root, Vector3(1.34, 0.3, 0.94), Vector3(2.9, 1.98, -2.2), mat(GLASS, 0.5, 0.3, 0.2))
	box(root, Vector3(1.4, 0.08, 1.0), Vector3(2.9, 2.3, -2.2), mat(FLAME))
	aerial(root, Vector3(3.3, 2.34, -2.5), 0.9)
	for i: int in 5:
		lamp(root, Vector3(-0.6 + 1.05 * float(i), 0.26, 2.6), FLAME, 0.1)
	box(root, Vector3(0.9, 0.5, 0.6), Vector3(-0.5, 0.48, -2.3), mat(NAVY))
	cyl(root, 0.3, 0.3, 0.8, Vector3(0.4, 0.6, -2.35), mat(FLAME), 8)


static func _gun_pit(root: Node3D, team: Color) -> void:
	cyl(root, 0.85, 0.95, 0.45, Vector3(0.0, 0.22, 0.0), mat(CONCRETE_DARK), 8)
	ring(root, 0.8, 0.9, Vector3(0.0, 0.46, 0.0), team_mat(team))
	cyl(root, 0.4, 0.5, 0.45, Vector3(0.0, 0.66, 0.0), mat(CLOUD_DARK), 8)
	var t: Node3D = _turret(root, Vector3(0.0, 0.88, 0.0))
	ball(t, 0.4, Vector3(0.0, 0.22, 0.0), mat(CLOUD), 8)
	barrel(t, 0.05, 0.85, Vector3(0.25, 0.26, 0.14), mat(GUNMETAL))
	barrel(t, 0.05, 0.85, Vector3(0.25, 0.26, -0.14), mat(GUNMETAL))
	box(t, Vector3(0.3, 0.07, 0.3), Vector3(-0.12, 0.62, 0.0), mat(FLAME))


static func _control_tower(root: Node3D, team: Color) -> void:
	_apron(root, 5.7, 5.7, team)
	box(root, Vector3(3.0, 1.2, 2.4), Vector3(-0.8, 0.8, 0.8), mat(CLOUD))
	box(root, Vector3(3.05, 0.2, 2.45), Vector3(-0.8, 1.2, 0.8), team_mat(team))
	windows(root, Vector3(-1.8, 0.85, 2.02), Vector3(0.7, 0.0, 0.0), 4, Vector3(0.44, 0.36, 0.06))
	cyl(root, 0.6, 0.85, 4.4, Vector3(0.9, 2.4, -0.9), mat(CLOUD), 8)
	for y: float in [1.2, 2.4, 3.6]:
		cyl(root, 0.9 - y * 0.06, 0.9 - y * 0.06, 0.14, Vector3(0.9, y, -0.9), mat(FLAME), 8)
	cyl(root, 1.25, 0.95, 0.8, Vector3(0.9, 4.95, -0.9), mat(GLASS, 0.6, 0.3, 0.2), 8)
	cyl(root, 1.3, 1.3, 0.14, Vector3(0.9, 5.4, -0.9), mat(CLOUD_DARK), 8)
	ring(root, 1.05, 1.18, Vector3(0.9, 4.5, -0.9), team_mat(team))
	radar(root, Vector3(0.9, 5.45, -0.9), 1.3, "Spin", CLOUD)
	aerial(root, Vector3(-1.9, 1.4, 0.0), 1.4)
	_pole_lamp(root, Vector3(2.3, 0.2, 2.3), 1.7, FLAME)


# ------------------------------------------------------------ Crimson Tally

## The Tally's armored truck: a black frame on big wheels, a slab-sided body
## with a raked prow and a spiked ram, oxblood side plates edged in gilt.
static func _war_rig(root: Node3D, team: Color, length: float, width: float, axles: int, height: float = 0.5) -> void:
	box(root, Vector3(length, 0.24, width * 0.84), Vector3(0.0, 0.5, 0.0), mat(PITCH))
	box(root, Vector3(length * 0.78, height, width), Vector3(-length * 0.08, 0.62 + height * 0.5, 0.0), mat(SLATE))
	wedge(root, Vector3(length * 0.24, height, width), Vector3(length * 0.43, 0.62 + height * 0.5, 0.0), mat(SLATE), 0.0)
	box(root, Vector3(length * 0.8, 0.1, width + 0.04), Vector3(-length * 0.07, 0.68, 0.0), team_mat(team))
	for side: float in [-1.0, 1.0]:
		var z: float = side * (width * 0.5 + 0.03)
		box(root, Vector3(length * 0.56, height * 0.6, 0.06), Vector3(-length * 0.1, 0.72 + height * 0.42, z), mat(OXBLOOD))
		box(root, Vector3(length * 0.6, 0.05, 0.08), Vector3(-length * 0.1, 0.72 + height * 0.75, z), mat(GILT, 0.0, 0.7, 0.4))
	for i: int in axles:
		var x: float = lerpf(-length * 0.36, length * 0.36, float(i) / float(maxi(1, axles - 1)))
		wheel(root, 0.36, 0.28, Vector3(x, 0.36, width * 0.5))
		wheel(root, 0.36, 0.28, Vector3(x, 0.36, -width * 0.5))
	# Ram bar with three spikes.
	box(root, Vector3(0.12, 0.2, width + 0.3), Vector3(length * 0.5 + 0.08, 0.46, 0.0), mat(PITCH))
	for z: float in [-width * 0.4, 0.0, width * 0.4]:
		cyl(root, 0.0, 0.08, 0.3, Vector3(length * 0.5 + 0.28, 0.46, z), mat(GILT, 0.0, 0.7, 0.4), 4, Vector3(0.0, 0.0, -PI * 0.5))
	lamp(root, Vector3(length * 0.5 - 0.02, 0.78, width * 0.34), WINDOW_WARM)
	lamp(root, Vector3(length * 0.5 - 0.02, 0.78, -width * 0.34), WINDOW_WARM)
	_tail(root, -length * 0.5 - 0.01, 0.66, width * 0.36)


static func _strongbox(root: Node3D, team: Color) -> void:
	_war_rig(root, team, 2.3, 1.2, 3, 0.34)
	box(root, Vector3(0.66, 0.6, 1.12), Vector3(0.68, 1.26, 0.0), mat(SLATE))
	box(root, Vector3(0.05, 0.16, 0.9), Vector3(1.02, 1.36, 0.0), mat(WINDOW_WARM, 0.9, 0.2, 0.3))
	box(root, Vector3(0.7, 0.06, 1.16), Vector3(0.68, 1.58, 0.0), mat(GILT, 0.0, 0.7, 0.4))
	box(root, Vector3(1.4, 0.34, 1.26), Vector3(-0.42, 1.13, 0.0), mat(PITCH))
	for x: float in [-0.95, 0.1]:
		box(root, Vector3(0.1, 0.38, 1.3), Vector3(x, 1.13, 0.0), mat(GILT, 0.0, 0.7, 0.4))
	_cargo(root, Vector3(-0.42, 1.3, 0.0), Vector3(1.2, 0.5, 1.05))


static func _jackal(root: Node3D, team: Color) -> void:
	_war_rig(root, team, 1.7, 0.95, 2, 0.28)
	for z: float in [-0.42, 0.42]:
		box(root, Vector3(0.9, 0.05, 0.05), Vector3(-0.3, 1.34, z), mat(PITCH))
		box(root, Vector3(0.05, 0.42, 0.05), Vector3(-0.74, 1.13, z), mat(PITCH))
		box(root, Vector3(0.05, 0.42, 0.05), Vector3(0.14, 1.13, z), mat(PITCH))
	box(root, Vector3(0.05, 0.05, 0.9), Vector3(-0.74, 1.34, 0.0), mat(PITCH))
	var t: Node3D = _turret(root, Vector3(-0.3, 0.93, 0.0))
	box(t, Vector3(0.3, 0.2, 0.3), Vector3(0.0, 0.1, 0.0), mat(PITCH))
	barrel(t, 0.04, 0.75, Vector3(0.1, 0.16, 0.0), mat(GUNMETAL))
	box(t, Vector3(0.05, 0.3, 0.5), Vector3(0.22, 0.2, 0.0), mat(OXBLOOD))


static func _brigand(root: Node3D, team: Color) -> void:
	_war_rig(root, team, 2.2, 1.25, 3, 0.44)
	box(root, Vector3(0.56, 0.36, 1.05), Vector3(0.72, 1.24, 0.0), mat(SLATE))
	box(root, Vector3(0.05, 0.12, 0.84), Vector3(1.01, 1.28, 0.0), mat(WINDOW_WARM, 0.9, 0.2, 0.3))
	var t: Node3D = _turret(root, Vector3(-0.35, 1.07, 0.0))
	cyl(t, 0.5, 0.56, 0.3, Vector3(0.0, 0.15, 0.0), mat(PITCH), 8)
	box(t, Vector3(0.08, 0.5, 0.9), Vector3(0.34, 0.4, 0.0), mat(OXBLOOD))
	box(t, Vector3(0.1, 0.06, 0.94), Vector3(0.34, 0.67, 0.0), mat(GILT, 0.0, 0.7, 0.4))
	barrel(t, 0.07, 1.25, Vector3(0.2, 0.36, 0.0), mat(GUNMETAL))
	box(t, Vector3(0.4, 0.3, 0.3), Vector3(-0.1, 0.4, 0.3), mat(SLATE))
	box(t, Vector3(0.3, 0.08, 0.3), Vector3(-0.2, 0.34, -0.2), team_mat(team))


static func _ravager(root: Node3D, team: Color) -> void:
	track(root, 2.8, 0.74, 0.6)
	track(root, 2.8, -0.74, 0.6)
	box(root, Vector3(2.4, 0.5, 1.3), Vector3(-0.05, 0.7, 0.0), mat(SLATE))
	wedge(root, Vector3(0.6, 0.5, 1.3), Vector3(1.4, 0.7, 0.0), mat(SLATE), 0.0)
	for side: float in [-1.0, 1.0]:
		box(root, Vector3(2.5, 0.36, 0.06), Vector3(0.0, 0.5, side * 0.99), mat(OXBLOOD))
		box(root, Vector3(2.5, 0.05, 0.08), Vector3(0.0, 0.7, side * 0.99), mat(GILT, 0.0, 0.7, 0.4))
		box(root, Vector3(2.74, 0.1, 0.47), Vector3(0.0, 0.63, side * 0.74), team_mat(team))
		lamp(root, Vector3(1.12, 0.92, side * 0.5), WINDOW_WARM)
	# Dozer ram with spikes.
	box(root, Vector3(0.14, 0.4, 1.8), Vector3(1.6, 0.36, 0.0), mat(PITCH))
	for z: float in [-0.6, 0.0, 0.6]:
		cyl(root, 0.0, 0.1, 0.34, Vector3(1.82, 0.4, z), mat(GILT, 0.0, 0.7, 0.4), 4, Vector3(0.0, 0.0, -PI * 0.5))
	barrel(root, 0.07, 0.3, Vector3(-1.5, 0.8, 0.4), mat(GUNMETAL))
	var t: Node3D = _turret(root, Vector3(-0.15, 0.96, 0.0))
	box(t, Vector3(1.2, 0.46, 1.1), Vector3(0.0, 0.23, 0.0), mat(PITCH))
	wedge(t, Vector3(0.4, 0.46, 1.1), Vector3(0.8, 0.23, 0.0), mat(PITCH), 0.0)
	box(t, Vector3(1.24, 0.06, 1.14), Vector3(0.0, 0.47, 0.0), mat(GILT, 0.0, 0.7, 0.4))
	barrel(t, 0.11, 1.35, Vector3(0.85, 0.24, 0.0), mat(GUNMETAL))
	cyl(t, 0.16, 0.16, 0.3, Vector3(2.25, 0.24, 0.0), mat(PITCH), 8, Vector3(0.0, 0.0, -PI * 0.5))
	box(t, Vector3(0.5, 0.1, 0.6), Vector3(-0.2, 0.53, 0.0), team_mat(team))
	hatch(t, Vector3(-0.3, 0.6, 0.3), 0.18, OXBLOOD)
	aerial(t, Vector3(-0.5, 0.48, -0.42), 0.9, GILT)


static func _flakjack(root: Node3D, team: Color) -> void:
	_war_rig(root, team, 2.2, 1.25, 3, 0.4)
	box(root, Vector3(0.56, 0.36, 1.05), Vector3(0.72, 1.2, 0.0), mat(SLATE))
	var t: Node3D = _turret(root, Vector3(-0.4, 1.03, 0.0))
	cyl(t, 0.5, 0.56, 0.28, Vector3(0.0, 0.14, 0.0), mat(PITCH), 8)
	box(t, Vector3(0.5, 0.4, 0.5), Vector3(-0.1, 0.48, 0.0), mat(SLATE))
	for z: float in [-0.36, 0.36]:
		box(t, Vector3(0.4, 0.2, 0.16), Vector3(0.1, 0.56, z), mat(OXBLOOD))
		for k: float in [-0.05, 0.05]:
			cyl(t, 0.04, 0.04, 1.3, Vector3(0.52, 0.92, z + k), mat(GUNMETAL), 5, Vector3(0.0, 0.0, -0.9))
	box(t, Vector3(0.3, 0.08, 0.5), Vector3(-0.2, 0.72, 0.0), team_mat(team))


static func _ransom(root: Node3D, team: Color) -> void:
	_war_rig(root, team, 2.5, 1.3, 3, 0.36)
	box(root, Vector3(0.6, 0.4, 1.1), Vector3(0.85, 1.18, 0.0), mat(SLATE))
	box(root, Vector3(0.05, 0.14, 0.88), Vector3(1.16, 1.22, 0.0), mat(WINDOW_WARM, 0.9, 0.2, 0.3))
	for z: float in [-0.85, 0.85]:
		box(root, Vector3(0.4, 0.1, 0.16), Vector3(-1.1, 0.3, z), mat(PITCH), Vector3(0.0, 0.0, 0.4))
	var t: Node3D = _turret(root, Vector3(-0.45, 1.0, 0.0))
	box(t, Vector3(0.5, 0.3, 0.6), Vector3(0.0, 0.15, 0.0), mat(PITCH))
	# A rack of twelve tubes, raised.
	box(t, Vector3(1.5, 0.56, 1.1), Vector3(0.1, 0.72, 0.0), mat(OXBLOOD), Vector3(0.0, 0.0, 0.42))
	box(t, Vector3(1.54, 0.06, 1.14), Vector3(-0.02, 1.0, 0.0), mat(GILT, 0.0, 0.7, 0.4), Vector3(0.0, 0.0, 0.42))
	for row: int in 3:
		for col: int in 4:
			var z: float = -0.39 + 0.26 * float(col)
			var up: float = -0.17 + 0.17 * float(row)
			cyl(t, 0.07, 0.07, 0.06, Vector3(0.8 - up * 0.41, 1.03 + up * 0.91, z), mat(PITCH), 6, Vector3(0.0, 0.0, -PI * 0.5 + 0.42))
	box(t, Vector3(0.3, 0.08, 0.5), Vector3(-0.3, 0.34, 0.0), team_mat(team))


## The walled yard the Tally builds in: a black slab, a low wall round it
## broken by a gate, and a gilt-capped post with a lamp at every corner.
static func _compound(root: Node3D, w: float, d: float, h: float = 0.4) -> void:
	box(root, Vector3(w, h, d), Vector3(0.0, 0.0, 0.0), mat(PITCH))
	box(root, Vector3(w - 0.9, 0.05, d - 0.9), Vector3(0.0, h * 0.5 + 0.02, 0.0), mat(SLATE))
	var top: float = h * 0.5
	for side: float in [-1.0, 1.0]:
		box(root, Vector3(0.18, 0.5, d - 0.8), Vector3(side * (w * 0.5 - 0.14), top + 0.25, 0.0), mat(SLATE))
		box(root, Vector3(w - 0.8, 0.5, 0.18), Vector3(0.0, top + 0.25, -(d * 0.5 - 0.14)), mat(SLATE))
		box(root, Vector3((w - 2.6) * 0.5, 0.5, 0.18), Vector3(side * (w * 0.25 + 0.5), top + 0.25, d * 0.5 - 0.14), mat(SLATE))
		for other: float in [-1.0, 1.0]:
			var at: Vector3 = Vector3(side * (w * 0.5 - 0.2), top, other * (d * 0.5 - 0.2))
			box(root, Vector3(0.36, 0.8, 0.36), at + Vector3(0.0, 0.4, 0.0), mat(PITCH))
			box(root, Vector3(0.42, 0.08, 0.42), at + Vector3(0.0, 0.84, 0.0), mat(GILT, 0.0, 0.7, 0.4))
			box(root, Vector3(0.16, 0.14, 0.16), at + Vector3(0.0, 0.95, 0.0), mat(WINDOW_WARM, 1.6))


## A blockhouse: a slab-sided hall whose walls lean in, with a gilt cornice.
static func _blockhouse(root: Node3D, at: Vector3, size: Vector3, team: Color) -> void:
	box(root, size, at + Vector3(0.0, size.y * 0.5, 0.0), mat(SLATE))
	for side: float in [-1.0, 1.0]:
		wedge(root, Vector3(0.5, size.y, size.z), at + Vector3(side * (size.x * 0.5 + 0.25), size.y * 0.5, 0.0), mat(SLATE), 0.0 if side > 0.0 else 1.0)
	box(root, Vector3(size.x + 0.06, 0.24, size.z + 0.06), at + Vector3(0.0, size.y * 0.62, 0.0), team_mat(team))
	box(root, Vector3(size.x + 0.2, 0.12, size.z + 0.2), at + Vector3(0.0, size.y + 0.06, 0.0), mat(GILT, 0.0, 0.7, 0.4))
	box(root, Vector3(size.x - 0.4, 0.2, size.z - 0.4), at + Vector3(0.0, size.y + 0.2, 0.0), mat(PITCH))


## A long oxblood banner with a team stripe, hung from a gilt pole.
static func _pennant(root: Node3D, pos: Vector3, team: Color, height: float = 2.6) -> void:
	cyl(root, 0.045, 0.05, height, pos + Vector3(0.0, height * 0.5, 0.0), mat(GILT, 0.0, 0.7, 0.4), 5)
	box(root, Vector3(0.5, 1.0, 0.04), pos + Vector3(0.28, height - 0.6, 0.0), mat(OXBLOOD))
	box(root, Vector3(0.52, 0.22, 0.05), pos + Vector3(0.28, height - 0.5, 0.0), team_mat(team))


static func _counting_house(root: Node3D, team: Color) -> void:
	_compound(root, 7.7, 7.7, 0.5)
	_blockhouse(root, Vector3(0.0, 0.25, -0.4), Vector3(4.6, 2.3, 4.2), team)
	_blockhouse(root, Vector3(0.0, 2.75, -0.4), Vector3(2.8, 1.5, 2.6), team)
	var warm: Vector3 = Vector3(0.4, 0.5, 0.06)
	windows(root, Vector3(-1.7, 1.25, 1.71), Vector3(0.75, 0.0, 0.0), 2, warm, WINDOW_WARM)
	windows(root, Vector3(0.95, 1.25, 1.71), Vector3(0.75, 0.0, 0.0), 2, warm, WINDOW_WARM)
	windows(root, Vector3(-0.8, 3.45, 0.91), Vector3(0.8, 0.0, 0.0), 3, Vector3(0.36, 0.4, 0.06), WINDOW_WARM)
	windows(root, Vector3(-1.7, 1.25, -2.51), Vector3(0.85, 0.0, 0.0), 5, warm, WINDOW_WARM)
	# The great door under the Tally's coin.
	box(root, Vector3(1.3, 1.4, 0.12), Vector3(0.0, 0.95, 1.72), mat(GUNMETAL))
	box(root, Vector3(1.6, 0.14, 0.2), Vector3(0.0, 1.7, 1.74), mat(GILT, 0.0, 0.7, 0.4))
	cyl(root, 0.62, 0.62, 0.12, Vector3(0.0, 2.25, 1.76), mat(GILT, 0.3, 0.8, 0.3), 12, Vector3(PI * 0.5, 0.0, 0.0))
	cyl(root, 0.4, 0.4, 0.14, Vector3(0.0, 2.25, 1.78), mat(OXBLOOD), 12, Vector3(PI * 0.5, 0.0, 0.0))
	_pennant(root, Vector3(1.5, 0.25, 2.2), team, 3.0)
	_pennant(root, Vector3(-1.9, 0.25, 2.2), team, 3.0)
	box(root, Vector3(1.0, 0.7, 0.9), Vector3(2.9, 0.6, -2.6), mat(RUST, 0.0, 0.4, 0.7))
	box(root, Vector3(0.9, 0.6, 0.8), Vector3(-2.9, 0.55, -2.4), mat(OXBLOOD))
	# Command mast: the root of the signal grid.
	cyl(root, 0.16, 0.3, 3.4, Vector3(0.9, 6.1, 0.3), mat(PITCH, 0.0, 0.5, 0.5), 6)
	ring(root, 0.75, 0.9, Vector3(0.9, 6.3, 0.3), team_mat(team))
	ring(root, 0.45, 0.58, Vector3(0.9, 7.0, 0.3), mat(GILT, 0.6, 0.7, 0.4))
	ball(root, 0.24, Vector3(0.9, 7.9, 0.3), mat(team, 1.4))
	_spin_arms(root, Vector3(0.9, 5.4, 0.3), 0.6, GILT)
	var t: Node3D = _turret(root, Vector3(-0.8, 4.57, -0.8))
	box(t, Vector3(0.8, 0.4, 0.7), Vector3(0.0, 0.2, 0.0), mat(PITCH))
	barrel(t, 0.06, 0.9, Vector3(0.35, 0.25, 0.14), mat(GUNMETAL))
	barrel(t, 0.06, 0.9, Vector3(0.35, 0.25, -0.14), mat(GUNMETAL))


static func _signal_post(root: Node3D, team: Color) -> void:
	cyl(root, 0.8, 0.92, 0.4, Vector3(0.0, 0.2, 0.0), mat(PITCH), 6)
	box(root, Vector3(0.9, 0.6, 0.9), Vector3(0.0, 0.7, 0.0), mat(SLATE))
	box(root, Vector3(0.96, 0.08, 0.96), Vector3(0.0, 1.02, 0.0), mat(GILT, 0.0, 0.7, 0.4))
	for i: int in 3:
		var ang: float = float(i) * TAU / 3.0
		cyl(root, 0.04, 0.06, 3.0, Vector3(cos(ang) * 0.24, 2.5, sin(ang) * 0.24), mat(PITCH), 4, Vector3(sin(ang) * 0.12, 0.0, -cos(ang) * 0.12))
	for y: float in [1.7, 2.5, 3.3]:
		cyl(root, 0.3 - y * 0.05, 0.3 - y * 0.05, 0.07, Vector3(0.0, y, 0.0), mat(GILT, 0.0, 0.7, 0.4), 6)
	cyl(root, 0.05, 0.08, 1.2, Vector3(0.0, 4.4, 0.0), mat(PITCH, 0.0, 0.5, 0.5), 6)
	ring(root, 0.6, 0.72, Vector3(0.0, 3.3, 0.0), team_mat(team))
	ring(root, 0.38, 0.48, Vector3(0.0, 4.1, 0.0), team_mat(team))
	ball(root, 0.2, Vector3(0.0, 5.05, 0.0), mat(team, 1.4))
	_spin_arms(root, Vector3(0.0, 2.75, 0.0), 0.5, GILT)


static func _vault(root: Node3D, team: Color) -> void:
	_compound(root, 5.7, 5.7)
	# A round strongroom with a great wheel-locked door.
	cyl(root, 1.9, 2.0, 1.9, Vector3(-0.3, 1.15, -0.6), mat(SLATE), 10)
	cyl(root, 2.03, 2.03, 0.24, Vector3(-0.3, 1.5, -0.6), team_mat(team), 10)
	cyl(root, 2.05, 2.05, 0.12, Vector3(-0.3, 2.14, -0.6), mat(GILT, 0.0, 0.7, 0.4), 10)
	var cap: MeshInstance3D = ball(root, 1.9, Vector3(-0.3, 2.15, -0.6), mat(PITCH), 10)
	cap.scale = Vector3(1.0, 0.3, 1.0)
	var turn: Vector3 = Vector3(PI * 0.5, 0.0, 0.0)
	cyl(root, 0.85, 0.85, 0.16, Vector3(-0.3, 1.1, 1.38), mat(PITCH), 12, turn)
	cyl(root, 0.7, 0.7, 0.18, Vector3(-0.3, 1.1, 1.42), mat(GILT, 0.2, 0.8, 0.3), 12, turn)
	for k: int in 3:
		box(root, Vector3(1.1, 0.08, 0.08), Vector3(-0.3, 1.1, 1.54), mat(PITCH), Vector3(0.0, 0.0, float(k) * PI / 3.0))
	cyl(root, 0.16, 0.16, 0.14, Vector3(-0.3, 1.1, 1.56), mat(PITCH), 8, turn)
	box(root, Vector3(1.0, 0.7, 0.9), Vector3(1.9, 0.55, 1.4), mat(OXBLOOD))
	box(root, Vector3(0.9, 0.6, 0.8), Vector3(1.9, 1.2, 1.4), mat(RUST, 0.0, 0.4, 0.7))
	box(root, Vector3(0.8, 0.5, 0.7), Vector3(2.0, 0.45, 0.3), mat(SLATE))
	_pennant(root, Vector3(2.2, 0.2, -2.2), team)


static func _billet(root: Node3D, team: Color) -> void:
	_compound(root, 5.7, 5.7)
	_blockhouse(root, Vector3(0.0, 0.2, -0.8), Vector3(4.0, 1.5, 2.6), team)
	roof(root, 4.2, 0.8, 2.9, Vector3(0.0, 2.3, -0.8), mat(OXBLOOD))
	box(root, Vector3(4.3, 0.1, 0.14), Vector3(0.0, 2.7, -0.8), mat(GILT, 0.0, 0.7, 0.4))
	box(root, Vector3(0.9, 1.1, 0.1), Vector3(0.0, 0.75, 0.52), mat(GUNMETAL))
	windows(root, Vector3(-1.4, 1.0, 0.51), Vector3(2.8, 0.0, 0.0), 2, Vector3(0.44, 0.4, 0.06), WINDOW_WARM)
	# Sandbags, a brazier and the colours.
	for i: int in 4:
		box(root, Vector3(0.7, 0.26, 0.32), Vector3(-1.9 + 0.75 * float(i), 0.33, 1.5), mat(SAND_DARK, 0.0, 0.0, 1.0))
	for i: int in 3:
		box(root, Vector3(0.7, 0.26, 0.32), Vector3(-1.5 + 0.75 * float(i), 0.58, 1.5), mat(SAND_DARK, 0.0, 0.0, 1.0))
	cyl(root, 0.26, 0.2, 0.4, Vector3(1.9, 0.4, 1.6), mat(PITCH), 6)
	cyl(root, 0.2, 0.05, 0.3, Vector3(1.9, 0.7, 1.6), mat(FURNACE, 1.6), 5)
	_pennant(root, Vector3(-2.2, 0.2, -2.2), team, 3.0)
	_stack(root, Vector3(1.4, 2.0, -1.4), 0.9, 0.16)


static func _motor_pool(root: Node3D, team: Color) -> void:
	_compound(root, 7.7, 5.7)
	_blockhouse(root, Vector3(-0.4, 0.2, -0.8), Vector3(5.4, 2.1, 3.0), team)
	# Two bays.
	for x: float in [-1.7, 0.9]:
		box(root, Vector3(2.1, 1.6, 0.1), Vector3(x, 1.0, 0.72), mat(GUNMETAL))
		box(root, Vector3(2.3, 0.14, 0.16), Vector3(x, 1.86, 0.74), mat(GILT, 0.0, 0.7, 0.4))
		box(root, Vector3(2.0, 0.03, 1.2), Vector3(x, 0.24, 1.5), mat(HAZARD))
	lamp(root, Vector3(-0.4, 2.0, 0.78), WINDOW_WARM, 0.16)
	# A hoist, tyres and fuel.
	cyl(root, 0.1, 0.1, 2.8, Vector3(3.2, 1.6, -1.9), mat(PITCH), 5)
	box(root, Vector3(0.2, 0.2, 3.0), Vector3(3.2, 3.0, -0.5), mat(PITCH))
	box(root, Vector3(0.4, 0.4, 0.4), Vector3(3.2, 2.6, 0.6), mat(GILT, 0.0, 0.7, 0.4))
	for y: float in [0.34, 0.6, 0.86]:
		cyl(root, 0.36, 0.36, 0.26, Vector3(3.1, y, 2.0), mat(RUBBER), 10)
	for z: float in [1.3, 1.9]:
		cyl(root, 0.28, 0.28, 0.7, Vector3(-3.3, 0.55, z), mat(OXBLOOD), 8)
		cyl(root, 0.29, 0.29, 0.08, Vector3(-3.3, 0.7, z), mat(GILT, 0.0, 0.7, 0.4), 8)
	_stack(root, Vector3(-2.6, 2.6, -1.8), 1.3, 0.22)
	_stack(root, Vector3(-1.9, 2.6, -1.8), 1.0, 0.18)
	_pennant(root, Vector3(3.3, 0.2, 2.4), team)


static func _gun_nest(root: Node3D, team: Color) -> void:
	cyl(root, 0.85, 0.95, 0.4, Vector3(0.0, 0.2, 0.0), mat(PITCH), 6)
	for i: int in 6:
		var ang: float = float(i) * TAU / 6.0
		box(root, Vector3(0.74, 0.28, 0.34), Vector3(cos(ang) * 0.72, 0.54, sin(ang) * 0.72), mat(SAND_DARK, 0.0, 0.0, 1.0), Vector3(0.0, -ang + PI * 0.5, 0.0))
	ring(root, 0.8, 0.88, Vector3(0.0, 0.42, 0.0), team_mat(team))
	var t: Node3D = _turret(root, Vector3(0.0, 0.7, 0.0))
	cyl(t, 0.34, 0.4, 0.4, Vector3(0.0, 0.2, 0.0), mat(SLATE), 8)
	box(t, Vector3(0.08, 0.44, 0.7), Vector3(0.3, 0.4, 0.0), mat(OXBLOOD))
	box(t, Vector3(0.1, 0.06, 0.74), Vector3(0.3, 0.64, 0.0), mat(GILT, 0.0, 0.7, 0.4))
	barrel(t, 0.05, 0.85, Vector3(0.3, 0.34, 0.13), mat(GUNMETAL))
	barrel(t, 0.05, 0.85, Vector3(0.3, 0.34, -0.13), mat(GUNMETAL))


static func _exchange(root: Node3D, team: Color) -> void:
	_compound(root, 5.7, 5.7)
	cyl(root, 1.9, 2.1, 1.4, Vector3(0.0, 0.9, 0.0), mat(SLATE), 8)
	cyl(root, 2.12, 2.12, 0.22, Vector3(0.0, 1.2, 0.0), team_mat(team), 8)
	cyl(root, 1.3, 1.6, 1.6, Vector3(0.0, 2.4, 0.0), mat(PITCH), 8)
	cyl(root, 1.66, 1.66, 0.12, Vector3(0.0, 1.66, 0.0), mat(GILT, 0.0, 0.7, 0.4), 8)
	for i: int in 8:
		var ang: float = float(i) * TAU / 8.0 + 0.39
		box(root, Vector3(0.1, 0.6, 0.36), Vector3(cos(ang) * 1.42, 2.4, sin(ang) * 1.42), mat(WINDOW_WARM, 0.9), Vector3(0.0, -ang, 0.0))
	var dome: MeshInstance3D = ball(root, 1.3, Vector3(0.0, 3.2, 0.0), mat(GILT, 0.15, 0.8, 0.3), 10)
	dome.scale = Vector3(1.0, 0.6, 1.0)
	# The Tally's coin turns above the dome.
	cyl(root, 0.05, 0.07, 0.7, Vector3(0.0, 4.2, 0.0), mat(PITCH), 5)
	var coin: Node3D = group(root, "Spin", Vector3(0.0, 5.0, 0.0))
	cyl(coin, 0.6, 0.6, 0.1, Vector3.ZERO, mat(GILT, 0.5, 0.8, 0.3), 12, Vector3(PI * 0.5, 0.0, 0.0))
	cyl(coin, 0.36, 0.36, 0.12, Vector3.ZERO, mat(OXBLOOD), 12, Vector3(PI * 0.5, 0.0, 0.0))
	_pennant(root, Vector3(2.2, 0.2, 2.2), team)
	_pennant(root, Vector3(-2.2, 0.2, 2.2), team)


# -------------------------------------------------------------- Umbral Veil

## A Veil foot soldier: slim, dark, hooded, with a cloak behind and a strip
## of ghost-light for a visor.
static func _ghost(root: Node3D, team: Color) -> void:
	for z: float in [-0.1, 0.1]:
		box(root, Vector3(0.22, 0.1, 0.14), Vector3(0.03, 0.05, z), mat(UMBRA))
		box(root, Vector3(0.14, 0.56, 0.14), Vector3(0.0, 0.36, z), mat(UMBRA))
	box(root, Vector3(0.26, 0.5, 0.4), Vector3(0.0, 0.88, 0.0), mat(UMBRA_LIGHT))
	box(root, Vector3(0.28, 0.12, 0.42), Vector3(0.0, 1.0, 0.0), team_mat(team))
	for z: float in [-0.25, 0.25]:
		box(root, Vector3(0.1, 0.34, 0.1), Vector3(0.05, 0.9, z), mat(UMBRA), Vector3(0.0, 0.0, 0.35))
		box(root, Vector3(0.24, 0.09, 0.09), Vector3(0.19, 0.8, z * 0.8), mat(UMBRA))
	wedge(root, Vector3(0.5, 0.95, 0.5), Vector3(-0.2, 0.72, 0.0), mat(UMBRA), 0.75)
	var hood: MeshInstance3D = ball(root, 0.19, Vector3(0.0, 1.3, 0.0), mat(UMBRA), 6)
	hood.scale = Vector3(1.1, 1.0, 0.95)
	wedge(root, Vector3(0.3, 0.2, 0.3), Vector3(-0.06, 1.48, 0.0), mat(UMBRA), 0.3)
	box(root, Vector3(0.05, 0.05, 0.2), Vector3(0.18, 1.3, 0.0), mat(GHOST, 1.8))


## The Veil's low, faceted car: a hull that rises to a ridge and falls away
## again, skirts over the wheels, and a line of ghost-light down each side.
static func _facet_car(root: Node3D, team: Color, length: float, width: float, height: float = 0.42) -> void:
	box(root, Vector3(length * 0.96, 0.2, width * 0.9), Vector3(0.0, 0.4, 0.0), mat(UMBRA))
	wedge(root, Vector3(length * 0.48, height, width), Vector3(length * 0.26, 0.5 + height * 0.5, 0.0), mat(UMBRA_LIGHT), 0.0)
	wedge(root, Vector3(length * 0.48, height, width), Vector3(-length * 0.22, 0.5 + height * 0.5, 0.0), mat(UMBRA_LIGHT), 1.0)
	box(root, Vector3(length * 0.06, height * 0.96, width * 0.96), Vector3(length * 0.02, 0.5 + height * 0.5, 0.0), mat(UMBRA_LIGHT))
	box(root, Vector3(length * 0.5, 0.05, width * 0.34), Vector3(length * 0.02, 0.5 + height * 0.55, 0.0), team_mat(team), Vector3(0.0, 0.0, 0.0))
	for side: float in [-1.0, 1.0]:
		var z: float = side * width * 0.5
		box(root, Vector3(length * 0.9, 0.3, 0.08), Vector3(0.0, 0.4, z + side * 0.02), mat(UMBRA))
		box(root, Vector3(length * 0.7, 0.04, 0.05), Vector3(0.0, 0.53, z + side * 0.07), mat(GHOST, 1.5))
		box(root, Vector3(length * 0.84, 0.07, 0.1), Vector3(0.0, 0.3, z + side * 0.03), team_mat(team))
		for x: float in [-length * 0.32, length * 0.32]:
			wheel(root, 0.26, 0.2, Vector3(x, 0.26, z - side * 0.08))
	box(root, Vector3(0.05, 0.06, width * 0.5), Vector3(length * 0.49, 0.48, 0.0), mat(GHOST, 1.6))
	box(root, Vector3(0.05, 0.05, width * 0.4), Vector3(-length * 0.46, 0.48, 0.0), mat(LAMP_RED, 1.4))


static func _gleaner(root: Node3D, team: Color) -> void:
	_facet_car(root, team, 2.1, 1.15, 0.36)
	box(root, Vector3(1.2, 0.26, 1.16), Vector3(-0.45, 0.96, 0.0), mat(UMBRA))
	box(root, Vector3(0.5, 0.3, 0.9), Vector3(0.55, 0.98, 0.0), mat(UMBRA_LIGHT))
	box(root, Vector3(0.05, 0.1, 0.7), Vector3(0.81, 1.0, 0.0), mat(GHOST, 1.2))
	_cargo(root, Vector3(-0.45, 1.09, 0.0), Vector3(1.05, 0.48, 0.98))


static func _wisp(root: Node3D, team: Color) -> void:
	# A three-wheeler: one wheel in front, two behind, the rider under a canopy.
	wheel(root, 0.3, 0.16, Vector3(0.62, 0.3, 0.0))
	wheel(root, 0.28, 0.18, Vector3(-0.55, 0.28, 0.36))
	wheel(root, 0.28, 0.18, Vector3(-0.55, 0.28, -0.36))
	wedge(root, Vector3(1.1, 0.4, 0.5), Vector3(0.2, 0.62, 0.0), mat(UMBRA_LIGHT), 0.0)
	wedge(root, Vector3(0.7, 0.4, 0.7), Vector3(-0.5, 0.62, 0.0), mat(UMBRA_LIGHT), 1.0)
	box(root, Vector3(1.5, 0.12, 0.44), Vector3(0.0, 0.42, 0.0), mat(UMBRA))
	box(root, Vector3(0.5, 0.06, 0.3), Vector3(-0.2, 0.84, 0.0), team_mat(team))
	for z: float in [-0.27, 0.27]:
		box(root, Vector3(1.0, 0.04, 0.04), Vector3(-0.1, 0.5, z), mat(GHOST, 1.5))
	box(root, Vector3(0.05, 0.06, 0.2), Vector3(0.78, 0.52, 0.0), mat(GHOST, 1.7))
	var t: Node3D = _turret(root, Vector3(0.2, 0.74, 0.0))
	barrel(t, 0.03, 0.55, Vector3(0.1, 0.0, 0.1), mat(GUNMETAL))
	barrel(t, 0.03, 0.55, Vector3(0.1, 0.0, -0.1), mat(GUNMETAL))


## A flat, wedge-fronted turret with a ghost-light slit.
static func _slab_turret(t: Node3D, team: Color, length: float, width: float, height: float = 0.26) -> void:
	box(t, Vector3(length, height, width), Vector3(-length * 0.1, height * 0.5, 0.0), mat(UMBRA))
	wedge(t, Vector3(length * 0.5, height, width), Vector3(length * 0.65, height * 0.5, 0.0), mat(UMBRA), 0.0)
	box(t, Vector3(length * 0.6, 0.05, width * 0.5), Vector3(-length * 0.15, height + 0.02, 0.0), team_mat(team))
	box(t, Vector3(0.05, 0.05, width * 0.6), Vector3(length * 0.42, height * 0.6, 0.0), mat(GHOST, 1.7))


static func _mirage(root: Node3D, team: Color) -> void:
	_facet_car(root, team, 2.1, 1.2, 0.4)
	var t: Node3D = _turret(root, Vector3(-0.1, 0.92, 0.0))
	_slab_turret(t, team, 0.8, 0.8)
	barrel(t, 0.06, 1.1, Vector3(0.5, 0.13, 0.0), mat(GUNMETAL))
	box(t, Vector3(0.36, 0.14, 0.14), Vector3(0.6, 0.13, 0.0), mat(UMBRA_LIGHT))


static func _stalker(root: Node3D, team: Color) -> void:
	_facet_car(root, team, 2.7, 1.35, 0.44)
	var t: Node3D = _turret(root, Vector3(-0.3, 0.96, 0.0))
	_slab_turret(t, team, 1.1, 0.95)
	# The lance: a rail longer than the car, ringed with ghost-light.
	box(t, Vector3(0.5, 0.2, 0.3), Vector3(0.75, 0.13, 0.0), mat(UMBRA_LIGHT))
	barrel(t, 0.06, 2.5, Vector3(0.9, 0.13, 0.0), mat(GUNMETAL))
	box(t, Vector3(2.2, 0.05, 0.05), Vector3(2.0, 0.24, 0.0), mat(UMBRA_LIGHT))
	for x: float in [1.4, 2.0, 2.6, 3.2]:
		cyl(t, 0.1, 0.1, 0.05, Vector3(x, 0.13, 0.0), mat(GHOST, 1.6), 8, Vector3(0.0, 0.0, -PI * 0.5))
	aerial(t, Vector3(-0.6, 0.28, -0.36), 0.8, GHOST)


static func _pall(root: Node3D, team: Color) -> void:
	_facet_car(root, team, 2.1, 1.2, 0.4)
	var t: Node3D = _turret(root, Vector3(-0.2, 0.92, 0.0))
	_slab_turret(t, team, 0.7, 0.9)
	for z: float in [-0.3, -0.1, 0.1, 0.3]:
		cyl(t, 0.035, 0.035, 1.25, Vector3(0.45, 0.62, z), mat(GUNMETAL), 5, Vector3(0.0, 0.0, -0.9))
		box(t, Vector3(0.06, 0.06, 0.06), Vector3(0.95, 1.0, z), mat(GHOST, 1.6))


static func _eclipse(root: Node3D, team: Color) -> void:
	_facet_car(root, team, 2.5, 1.3, 0.4)
	for z: float in [-0.85, 0.85]:
		box(root, Vector3(0.5, 0.08, 0.14), Vector3(-1.0, 0.28, z), mat(UMBRA), Vector3(0.0, 0.0, 0.4))
	var t: Node3D = _turret(root, Vector3(-0.4, 0.92, 0.0))
	_slab_turret(t, team, 0.8, 0.9)
	cyl(t, 0.14, 0.22, 2.2, Vector3(0.7, 0.92, 0.0), mat(UMBRA_LIGHT), 6, Vector3(0.0, 0.0, -0.95))
	for d: float in [0.4, 1.0, 1.6]:
		cyl(t, 0.21, 0.21, 0.06, Vector3(-0.19 + d * 0.81, 0.28 + d * 0.58, 0.0), mat(GHOST, 1.4), 6, Vector3(0.0, 0.0, -0.95))
	ball(t, 0.16, Vector3(1.66, 1.6, 0.0), mat(GHOST, 1.7), 6)


## The dark slab the Veil builds on, with a line of ghost-light let into
## its edge and a leaning fin at each corner.
static func _dusk_base(root: Node3D, w: float, d: float, h: float = 0.4) -> void:
	box(root, Vector3(w, h, d), Vector3(0.0, 0.0, 0.0), mat(UMBRA))
	box(root, Vector3(w - 0.7, 0.05, d - 0.7), Vector3(0.0, h * 0.5 + 0.02, 0.0), mat(UMBRA_LIGHT))
	for side: float in [-1.0, 1.0]:
		box(root, Vector3(w - 1.2, 0.04, 0.08), Vector3(0.0, h * 0.5 + 0.04, side * (d * 0.5 - 0.22)), mat(GHOST, 1.3))
		box(root, Vector3(0.08, 0.04, d - 1.2), Vector3(side * (w * 0.5 - 0.22), h * 0.5 + 0.04, 0.0), mat(GHOST, 1.3))
		for other: float in [-1.0, 1.0]:
			var at: Vector3 = Vector3(side * (w * 0.5 - 0.3), h * 0.5, other * (d * 0.5 - 0.3))
			cyl(root, 0.0, 0.2, 0.9, at + Vector3(0.0, 0.45, 0.0), mat(UMBRA_LIGHT), 4, Vector3(other * 0.2, PI * 0.25, -side * 0.2))


## A hall with a roof that slopes down to the ground on one side.
static func _shard_hall(root: Node3D, at: Vector3, size: Vector3, team: Color) -> void:
	box(root, Vector3(size.x, size.y * 0.55, size.z), at + Vector3(0.0, size.y * 0.275, 0.0), mat(UMBRA_LIGHT))
	wedge(root, Vector3(size.z + 0.3, size.y * 0.6, size.x + 0.2), at + Vector3(0.0, size.y * 0.85, 0.0), mat(UMBRA), 0.25, Vector3(0.0, PI * 0.5, 0.0))
	box(root, Vector3(size.x + 0.05, 0.16, size.z + 0.05), at + Vector3(0.0, size.y * 0.5, 0.0), team_mat(team))
	box(root, Vector3(size.x * 0.7, 0.05, 0.08), at + Vector3(0.0, size.y * 0.3, size.z * 0.5 + 0.03), mat(GHOST, 1.3))


static func _sanctum(root: Node3D, team: Color) -> void:
	_dusk_base(root, 7.7, 7.7, 0.5)
	# A stepped pyramid.
	var widths: Array[float] = [5.6, 4.2, 2.8]
	for i: int in 3:
		var y: float = 0.25 + 1.1 * float(i)
		box(root, Vector3(widths[i], 1.1, widths[i]), Vector3(0.0, y + 0.55, 0.0), mat(UMBRA_LIGHT if i % 2 == 0 else UMBRA))
		box(root, Vector3(widths[i] + 0.06, 0.08, widths[i] + 0.06), Vector3(0.0, y + 1.1, 0.0), mat(UMBRA))
		for side: float in [-1.0, 1.0]:
			box(root, Vector3(widths[i] * 0.7, 0.07, 0.06), Vector3(0.0, y + 0.6, side * (widths[i] * 0.5 + 0.01)), mat(GHOST, 1.2))
			box(root, Vector3(0.06, 0.07, widths[i] * 0.7), Vector3(side * (widths[i] * 0.5 + 0.01), y + 0.6, 0.0), mat(GHOST, 1.2))
	box(root, Vector3(5.66, 0.3, 5.66), Vector3(0.0, 1.0, 0.0), team_mat(team))
	box(root, Vector3(0.14, 1.0, 1.2), Vector3(2.82, 0.8, 0.0), mat(GUNMETAL))
	# Four pylons lean in over a crystal that turns above the summit.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			cyl(root, 0.05, 0.14, 2.4, Vector3(sx * 0.95, 4.6, sz * 0.95), mat(UMBRA), 4, Vector3(-sz * 0.3, 0.0, sx * 0.3))
	var crystal: Node3D = group(root, "Spin", Vector3(0.0, 5.3, 0.0))
	wedge(crystal, Vector3(0.9, 1.0, 0.9), Vector3(0.0, 0.5, 0.0), mat(GHOST, 1.5), 0.5)
	wedge(crystal, Vector3(0.9, 1.0, 0.9), Vector3(0.0, -0.5, 0.0), mat(GHOST, 1.5), 0.5, Vector3(PI, 0.0, 0.0))
	# Command mast: the root of the signal grid.
	cyl(root, 0.1, 0.2, 2.6, Vector3(2.0, 3.6, 2.0), mat(UMBRA_LIGHT), 4)
	ring(root, 0.75, 0.9, Vector3(2.0, 3.3, 2.0), team_mat(team))
	ring(root, 0.45, 0.58, Vector3(2.0, 4.0, 2.0), mat(GHOST, 1.0))
	ball(root, 0.22, Vector3(2.0, 5.0, 2.0), mat(team, 1.4))
	var t: Node3D = _turret(root, Vector3(-1.7, 2.45, -1.7))
	_slab_turret(t, team, 0.7, 0.7)
	barrel(t, 0.05, 0.9, Vector3(0.4, 0.13, 0.13), mat(GUNMETAL))
	barrel(t, 0.05, 0.9, Vector3(0.4, 0.13, -0.13), mat(GUNMETAL))


static func _obelisk(root: Node3D, team: Color) -> void:
	cyl(root, 0.7, 0.9, 0.4, Vector3(0.0, 0.2, 0.0), mat(UMBRA), 4, Vector3(0.0, PI * 0.25, 0.0))
	cyl(root, 0.12, 0.5, 4.2, Vector3(0.0, 2.5, 0.0), mat(UMBRA_LIGHT), 4, Vector3(0.0, PI * 0.25, 0.0))
	for y: float in [1.2, 2.0, 2.8, 3.6]:
		var wide: float = 0.5 - (y - 0.4) * 0.09
		box(root, Vector3(wide * 1.5, 0.06, wide * 1.5), Vector3(0.0, y, 0.0), mat(GHOST, 1.4))
	ring(root, 0.55, 0.67, Vector3(0.0, 3.0, 0.0), team_mat(team))
	ring(root, 0.34, 0.44, Vector3(0.0, 3.9, 0.0), team_mat(team))
	# A shard hangs above the tip.
	var tip: Node3D = group(root, "Spin", Vector3(0.0, 5.1, 0.0))
	wedge(tip, Vector3(0.34, 0.4, 0.34), Vector3(0.0, 0.2, 0.0), mat(GHOST, 1.7), 0.5)
	wedge(tip, Vector3(0.34, 0.4, 0.34), Vector3(0.0, -0.2, 0.0), mat(GHOST, 1.7), 0.5, Vector3(PI, 0.0, 0.0))
	ball(root, 0.12, Vector3(0.0, 4.68, 0.0), mat(team, 1.4))


static func _reservoir(root: Node3D, team: Color) -> void:
	_dusk_base(root, 5.7, 5.7)
	cyl(root, 1.9, 2.1, 1.1, Vector3(-0.4, 0.75, -0.5), mat(UMBRA_LIGHT), 8)
	cyl(root, 2.12, 2.12, 0.18, Vector3(-0.4, 0.9, -0.5), team_mat(team), 8)
	cyl(root, 1.95, 1.95, 0.1, Vector3(-0.4, 1.32, -0.5), mat(UMBRA), 8)
	cyl(root, 1.6, 1.6, 0.06, Vector3(-0.4, 1.36, -0.5), mat(GHOST, 1.0), 8)
	for i: int in 4:
		var ang: float = float(i) * TAU / 4.0 + 0.78
		cyl(root, 0.0, 0.26, 1.5, Vector3(-0.4 + cos(ang) * 2.0, 1.2, -0.5 + sin(ang) * 2.0), mat(UMBRA), 4, Vector3(sin(ang) * 0.3, 0.0, -cos(ang) * 0.3))
	barrel(root, 0.1, 1.3, Vector3(1.5, 0.5, -0.5), mat(UMBRA))
	box(root, Vector3(1.0, 0.7, 0.9), Vector3(1.8, 0.55, 1.4), mat(UMBRA_LIGHT))
	box(root, Vector3(0.9, 0.6, 0.8), Vector3(0.7, 0.5, 1.9), mat(RUST, 0.0, 0.4, 0.7))
	box(root, Vector3(0.8, 0.5, 0.7), Vector3(1.3, 1.1, 1.6), mat(UMBRA))


static func _hollow(root: Node3D, team: Color) -> void:
	_dusk_base(root, 5.7, 5.7)
	_shard_hall(root, Vector3(-0.2, 0.2, -1.0), Vector3(4.4, 1.9, 2.2), team)
	_shard_hall(root, Vector3(0.6, 0.2, 1.4), Vector3(2.6, 1.4, 1.6), team)
	box(root, Vector3(0.9, 1.0, 0.1), Vector3(-0.2, 0.7, 0.12), mat(GUNMETAL))
	box(root, Vector3(1.1, 0.06, 0.12), Vector3(-0.2, 1.24, 0.14), mat(GHOST, 1.4))
	cyl(root, 0.0, 0.3, 2.6, Vector3(-2.2, 1.5, 1.9), mat(UMBRA_LIGHT), 4, Vector3(0.0, PI * 0.25, 0.0))
	box(root, Vector3(0.3, 0.05, 0.3), Vector3(-2.2, 1.6, 1.9), mat(GHOST, 1.4), Vector3(0.0, PI * 0.25, 0.0))
	box(root, Vector3(0.5, 0.9, 0.04), Vector3(-1.9, 2.0, 1.9), team_mat(team))


static func _shroudworks(root: Node3D, team: Color) -> void:
	_dusk_base(root, 5.7, 5.7)
	_shard_hall(root, Vector3(0.0, 0.2, -0.7), Vector3(4.6, 2.8, 3.0), team)
	# A wide door framed in ghost-light.
	box(root, Vector3(2.6, 1.4, 0.1), Vector3(0.0, 0.9, 0.82), mat(GUNMETAL))
	box(root, Vector3(2.8, 0.07, 0.12), Vector3(0.0, 1.64, 0.84), mat(GHOST, 1.5))
	for sx: float in [-1.0, 1.0]:
		box(root, Vector3(0.07, 1.4, 0.12), Vector3(sx * 1.36, 0.9, 0.84), mat(GHOST, 1.5))
	# A gantry arm and a half-built hull on the apron.
	cyl(root, 0.08, 0.1, 2.4, Vector3(2.2, 1.4, 1.9), mat(UMBRA), 4)
	box(root, Vector3(1.8, 0.1, 0.1), Vector3(1.4, 2.6, 1.9), mat(UMBRA))
	box(root, Vector3(0.24, 0.3, 0.24), Vector3(0.6, 2.4, 1.9), mat(GHOST, 1.2))
	wedge(root, Vector3(1.0, 0.36, 0.9), Vector3(-1.2, 0.5, 1.9), mat(UMBRA_LIGHT), 0.0)
	box(root, Vector3(1.4, 0.1, 0.8), Vector3(-1.4, 0.3, 1.9), mat(UMBRA))


static func _sentinel(root: Node3D, team: Color) -> void:
	cyl(root, 0.35, 0.95, 0.7, Vector3(0.0, 0.35, 0.0), mat(UMBRA), 4, Vector3(0.0, PI * 0.25, 0.0))
	ring(root, 0.7, 0.78, Vector3(0.0, 0.3, 0.0), team_mat(team))
	for i: int in 4:
		var ang: float = float(i) * TAU / 4.0
		box(root, Vector3(0.4, 0.04, 0.05), Vector3(cos(ang) * 0.42, 0.42, sin(ang) * 0.42), mat(GHOST, 1.4), Vector3(0.0, -ang + PI * 0.5, 0.0))
	var t: Node3D = _turret(root, Vector3(0.0, 0.72, 0.0))
	_slab_turret(t, team, 0.6, 0.6, 0.3)
	barrel(t, 0.045, 0.85, Vector3(0.35, 0.15, 0.12), mat(GUNMETAL))
	barrel(t, 0.045, 0.85, Vector3(0.35, 0.15, -0.12), mat(GUNMETAL))
	ball(t, 0.1, Vector3(-0.1, 0.4, 0.0), mat(GHOST, 1.7), 6)


static func _occulus(root: Node3D, team: Color) -> void:
	_dusk_base(root, 5.7, 5.7)
	cyl(root, 1.5, 2.0, 0.8, Vector3(0.0, 0.6, 0.0), mat(UMBRA_LIGHT), 6)
	cyl(root, 1.56, 1.56, 0.14, Vector3(0.0, 0.92, 0.0), team_mat(team), 6)
	# Six fins stand round a great eye of ghost-light.
	for i: int in 6:
		var ang: float = float(i) * TAU / 6.0
		wedge(root, Vector3(0.8, 3.0, 0.14), Vector3(cos(ang) * 1.7, 2.3, sin(ang) * 1.7), mat(UMBRA), 1.0, Vector3(0.0, -ang, 0.0))
		box(root, Vector3(0.06, 1.6, 0.05), Vector3(cos(ang) * 1.36, 2.0, sin(ang) * 1.36), mat(GHOST, 1.2))
	ball(root, 0.8, Vector3(0.0, 2.6, 0.0), mat(GHOST, 1.2), 10)
	ball(root, 0.36, Vector3(0.0, 2.6, 0.0), mat(UMBRA), 8)
	var halo: Node3D = group(root, "Spin", Vector3(0.0, 2.6, 0.0))
	var hoop: MeshInstance3D = ring(halo, 1.02, 1.1, Vector3.ZERO, mat(UMBRA_LIGHT, 0.0, 0.6, 0.4))
	hoop.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	box(halo, Vector3(0.14, 0.14, 0.14), Vector3(1.06, 0.0, 0.0), mat(GHOST, 1.8))
	box(halo, Vector3(0.14, 0.14, 0.14), Vector3(-1.06, 0.0, 0.0), mat(GHOST, 1.8))


# -------------------------------------------------------------- Brackenfold

## A Brackenfold foot soldier: wood-brown limbs, a mask of bone with one
## sap-bright slit, a red leaf for a crest and a thorn on each shoulder.
static func _sprout(root: Node3D, team: Color) -> void:
	_soldier(root, team, BONE, BARK_LIGHT, BARK)
	wedge(root, Vector3(0.52, 0.3, 0.1), Vector3(-0.16, 1.5, 0.0), mat(LEAF), 0.9)
	box(root, Vector3(0.05, 0.06, 0.24), Vector3(0.17, 1.3, 0.0), mat(SAP, 1.8))
	for z: float in [-0.3, 0.3]:
		cyl(root, 0.0, 0.06, 0.26, Vector3(-0.02, 1.2, z), mat(BONE), 4, Vector3(signf(z) * 0.5, 0.0, 0.3))


## One jointed leg: a thick thigh that rises away from the body to a knob
## of a knee, and a shin that comes down to a clawed foot.
static func _beast_leg(root: Node3D, x: float, z: float, side: float, hip: float) -> void:
	box(root, Vector3(0.2, 0.2, 0.62), Vector3(x, hip + 0.16, z + side * 0.24), mat(BARK), Vector3(-side * 0.55, 0.0, 0.0))
	box(root, Vector3(0.2, 0.2, 0.2), Vector3(x, hip + 0.33, z + side * 0.5), mat(BONE_DARK))
	box(root, Vector3(0.15, hip + 0.3, 0.15), Vector3(x, (hip + 0.3) * 0.5, z + side * 0.58), mat(BARK), Vector3(-side * 0.2, 0.0, 0.0))
	box(root, Vector3(0.3, 0.08, 0.24), Vector3(x + 0.05, 0.04, z + side * 0.66), mat(BONE_DARK))


## The body of a Brackenfold beast: a dark belly under three overlapping
## plates of horn that arch like a woodlouse, sap glowing in the seams, a
## low head with horns and bright eyes, a crest of red fins down the back
## and jointed legs. A turret sits at about 0.5 + height * 1.3.
static func _beast(root: Node3D, team: Color, length: float, width: float, pairs: int, height: float = 0.5) -> void:
	var hip: float = 0.3
	box(root, Vector3(length * 0.92, 0.3, width * 0.7), Vector3(0.0, hip + 0.14, 0.0), mat(BARK))
	for i: int in 3:
		var f: float = float(i) / 2.0
		var x: float = lerpf(-length * 0.31, length * 0.24, f)
		var h: float = height * (0.8 + 0.5 * sin(f * PI))
		var wide: float = width * (0.86 + 0.16 * sin(f * PI))
		var lean: float = lerpf(0.26, -0.26, f)
		box(root, Vector3(length * 0.36, h, wide), Vector3(x, hip + 0.22 + h * 0.5, 0.0), mat(BONE), Vector3(0.0, 0.0, lean))
		# A darker rim where each plate laps the next, and the team's colour
		# across its back and down its flanks.
		box(root, Vector3(0.07, h * 1.02, wide * 1.03), Vector3(x - length * 0.17, hip + 0.22 + h * 0.5, 0.0), mat(BONE_DARK), Vector3(0.0, 0.0, lean))
		box(root, Vector3(length * 0.14, 0.06, wide * 0.7), Vector3(x + length * 0.02, hip + 0.23 + h, 0.0), team_mat(team), Vector3(0.0, 0.0, lean))
		for side: float in [-1.0, 1.0]:
			box(root, Vector3(length * 0.2, h * 0.46, 0.05), Vector3(x + length * 0.02, hip + 0.22 + h * 0.52, side * (wide * 0.5 + 0.01)), team_mat(team), Vector3(0.0, 0.0, lean))
		if i < 2:
			box(root, Vector3(0.07, h * 0.5, wide * 0.6), Vector3(x + length * 0.15, hip + 0.24 + h * 0.4, 0.0), mat(SAP, 1.4))
		# A fin on every plate: the crest.
		wedge(root, Vector3(length * 0.26, height * 0.5, 0.07), Vector3(x - length * 0.04, hip + 0.22 + h + height * 0.2, 0.0), mat(LEAF if i != 1 else LEAF_LIGHT), 0.15, Vector3(0.0, 0.0, lean))
	# Head: a brow plate over a dark jaw, two eyes, two horns swept forward.
	wedge(root, Vector3(length * 0.3, height * 0.8, width * 0.72), Vector3(length * 0.5, hip + 0.2 + height * 0.4, 0.0), mat(BONE), 0.0)
	box(root, Vector3(length * 0.22, 0.16, width * 0.5), Vector3(length * 0.52, hip + 0.08, 0.0), mat(BARK))
	for side: float in [-1.0, 1.0]:
		box(root, Vector3(0.12, 0.1, 0.14), Vector3(length * 0.53, hip + 0.3 + height * 0.3, side * width * 0.22), mat(SAP, 2.0))
		cyl(root, 0.0, 0.09, 0.6, Vector3(length * 0.62, hip + 0.3 + height * 0.5, side * width * 0.3), mat(BONE_DARK), 5, Vector3(0.0, 0.0, -PI * 0.5 + 0.5))
		for i: int in pairs:
			var x: float = lerpf(-length * 0.3, length * 0.3, float(i) / float(maxi(1, pairs - 1))) if pairs > 1 else 0.0
			_beast_leg(root, x, side * width * 0.3, side, hip)
	# Tail: a stub with a fin on it.
	box(root, Vector3(length * 0.2, 0.2, width * 0.3), Vector3(-length * 0.52, hip + 0.22, 0.0), mat(BONE_DARK))
	wedge(root, Vector3(length * 0.34, height * 1.2, 0.08), Vector3(-length * 0.6, hip + 0.3 + height * 0.6, 0.0), mat(LEAF), 1.0)


## A cluster of quills fanned out forwards and up: the Brackenfold's guns.
static func _quills(t: Node3D, count: int, length: float, spread: float) -> void:
	for i: int in count:
		var z: float = (float(i) - float(count - 1) * 0.5) * spread
		var tilt: float = -PI * 0.5 + 0.3 + 0.1 * absf(z) / maxf(spread, 0.01)
		cyl(t, 0.015, 0.055, length, Vector3(length * 0.42, 0.14 + length * 0.13, z), mat(BARK), 5, Vector3(0.0, 0.0, tilt))
		box(t, Vector3(0.06, 0.06, 0.06), Vector3(length * 0.9, 0.14 + length * 0.27, z), mat(SAP, 1.6))


## A ring of petals round a centre, each rising as it goes outward.
static func _petals(root: Node3D, at: Vector3, count: int, reach: float, size: Vector3, color: Color, turn: float = 0.0) -> void:
	for i: int in count:
		var ang: float = float(i) * TAU / float(count) + turn
		wedge(root, size, at + Vector3(cos(ang) * reach, size.y * 0.5, sin(ang) * reach), mat(color), 1.0, Vector3(0.0, -ang, 0.0))


## A bone turret collar with a leaf on each side.
static func _bud(t: Node3D, team: Color, radius: float) -> void:
	cyl(t, radius * 0.8, radius, radius * 0.7, Vector3(0.0, radius * 0.35, 0.0), mat(BONE), 8)
	cyl(t, radius * 0.84, radius * 0.84, 0.06, Vector3(0.0, radius * 0.72, 0.0), team_mat(team), 8)
	for side: float in [-1.0, 1.0]:
		wedge(t, Vector3(radius * 1.5, radius * 0.7, 0.06), Vector3(-radius * 0.5, radius * 0.75, side * radius * 0.7), mat(LEAF), 1.0, Vector3(0.0, side * 0.35 + PI, 0.0))


static func _forager(root: Node3D, team: Color) -> void:
	_beast(root, team, 2.2, 1.2, 3, 0.36)
	# A woven basket on its back holds the load.
	cyl(root, 0.62, 0.52, 0.34, Vector3(-0.3, 1.1, 0.0), mat(BARK_LIGHT), 8)
	cyl(root, 0.66, 0.66, 0.07, Vector3(-0.3, 1.26, 0.0), mat(BARK), 8)
	_cargo(root, Vector3(-0.3, 1.22, 0.0), Vector3(0.86, 0.46, 0.86))


static func _quillhound(root: Node3D, team: Color) -> void:
	_beast(root, team, 1.7, 0.8, 2, 0.3)
	var t: Node3D = _turret(root, Vector3(0.1, 0.92, 0.0))
	_bud(t, team, 0.24)
	_quills(t, 3, 0.6, 0.12)


static func _quillback(root: Node3D, team: Color) -> void:
	_beast(root, team, 2.2, 1.2, 3, 0.44)
	var t: Node3D = _turret(root, Vector3(-0.1, 1.1, 0.0))
	_bud(t, team, 0.4)
	_quills(t, 7, 1.0, 0.12)


static func _barkhide(root: Node3D, team: Color) -> void:
	_beast(root, team, 2.8, 1.5, 3, 0.56)
	# Extra slabs of bone hung along the flanks.
	for side: float in [-1.0, 1.0]:
		for x: float in [-0.75, 0.05, 0.8]:
			box(root, Vector3(0.66, 0.46, 0.1), Vector3(x, 0.72, side * 0.88), mat(BONE_DARK), Vector3(side * 0.22, 0.0, 0.0))
			box(root, Vector3(0.5, 0.06, 0.12), Vector3(x, 0.9, side * 0.92), mat(LEAF))
	var t: Node3D = _turret(root, Vector3(-0.2, 1.26, 0.0))
	_bud(t, team, 0.52)
	# The gall cannon: a trunk bound with bone that swells at the muzzle.
	cyl(t, 0.17, 0.12, 1.6, Vector3(1.1, 0.24, 0.0), mat(BARK_LIGHT), 8, Vector3(0.0, 0.0, -PI * 0.5))
	for x: float in [0.6, 1.1, 1.6]:
		cyl(t, 0.19, 0.19, 0.09, Vector3(x, 0.24, 0.0), mat(BONE), 8, Vector3(0.0, 0.0, -PI * 0.5))
	cyl(t, 0.24, 0.17, 0.2, Vector3(1.96, 0.24, 0.0), mat(BARK), 8, Vector3(0.0, 0.0, -PI * 0.5))
	box(t, Vector3(0.06, 0.2, 0.2), Vector3(2.07, 0.24, 0.0), mat(SAP, 1.6))


static func _whipvine(root: Node3D, team: Color) -> void:
	_beast(root, team, 2.1, 1.15, 3, 0.4)
	var t: Node3D = _turret(root, Vector3(-0.2, 1.04, 0.0))
	_bud(t, team, 0.36)
	# Four whips reach for the sky, each tipped with sap.
	for z: float in [-0.27, -0.09, 0.09, 0.27]:
		cyl(t, 0.02, 0.05, 1.35, Vector3(0.42, 0.72, z), mat(BARK), 5, Vector3(0.0, 0.0, -0.75))
		box(t, Vector3(0.07, 0.07, 0.07), Vector3(0.9, 1.22, z), mat(SAP, 1.7))


static func _sporemortar(root: Node3D, team: Color) -> void:
	_beast(root, team, 2.5, 1.3, 3, 0.4)
	var t: Node3D = _turret(root, Vector3(-0.35, 1.04, 0.0))
	_bud(t, team, 0.46)
	# A trumpet of bound wood, wide at the mouth, with a pod ready in it.
	cyl(t, 0.44, 0.16, 1.6, Vector3(0.6, 0.92, 0.0), mat(BARK_LIGHT), 8, Vector3(0.0, 0.0, -0.9))
	cyl(t, 0.48, 0.48, 0.09, Vector3(1.2, 1.4, 0.0), mat(BONE), 8, Vector3(0.0, 0.0, -0.9))
	cyl(t, 0.3, 0.3, 0.08, Vector3(0.75, 1.04, 0.0), mat(BONE), 8, Vector3(0.0, 0.0, -0.9))
	ball(t, 0.26, Vector3(1.14, 1.36, 0.0), mat(SAP, 1.4), 6)


## The deck the Brackenfold grows its buildings on: dark heartwood with a
## floor of worked wood, a bone thorn leaning out of each corner and a sap
## lantern at its foot.
static func _mound(root: Node3D, w: float, d: float, h: float = 0.4) -> void:
	box(root, Vector3(w, h, d), Vector3(0.0, 0.0, 0.0), mat(BARK))
	box(root, Vector3(w - 0.7, 0.05, d - 0.7), Vector3(0.0, h * 0.5 + 0.02, 0.0), mat(BARK_LIGHT))
	for side: float in [-1.0, 1.0]:
		box(root, Vector3(w - 1.4, 0.05, 0.1), Vector3(0.0, h * 0.5 + 0.04, side * (d * 0.5 - 0.22)), mat(LEAF))
		box(root, Vector3(0.1, 0.05, d - 1.4), Vector3(side * (w * 0.5 - 0.22), h * 0.5 + 0.04, 0.0), mat(LEAF))
		for other: float in [-1.0, 1.0]:
			var at: Vector3 = Vector3(side * (w * 0.5 - 0.32), h * 0.5, other * (d * 0.5 - 0.32))
			cyl(root, 0.0, 0.16, 1.0, at + Vector3(0.0, 0.48, 0.0), mat(BONE), 5, Vector3(other * 0.25, 0.0, -side * 0.25))
			box(root, Vector3(0.16, 0.16, 0.16), at + Vector3(-side * 0.3, 0.1, -other * 0.3), mat(SAP, 1.5))


static func _heartroot(root: Node3D, team: Color) -> void:
	_mound(root, 7.7, 7.7, 0.5)
	# A great flower: a drum of wood, two rings of red petals and a tower of
	# bone rising out of the middle with the sap heart at its top.
	cyl(root, 2.3, 2.6, 1.0, Vector3(0.0, 0.75, 0.0), mat(BARK_LIGHT), 8)
	cyl(root, 2.64, 2.64, 0.26, Vector3(0.0, 0.9, 0.0), team_mat(team), 8)
	_petals(root, Vector3(0.0, 1.2, 0.0), 8, 2.5, Vector3(1.9, 1.3, 1.5), LEAF, PI / 8.0)
	cyl(root, 1.5, 1.9, 1.0, Vector3(0.0, 1.75, 0.0), mat(BARK_LIGHT), 8)
	_petals(root, Vector3(0.0, 2.2, 0.0), 6, 1.55, Vector3(1.4, 1.3, 1.1), LEAF_LIGHT)
	cyl(root, 0.6, 1.0, 2.6, Vector3(0.0, 3.5, 0.0), mat(BONE), 8)
	for y: float in [2.9, 3.6, 4.3]:
		cyl(root, 1.0 - (y - 2.2) * 0.15, 1.0 - (y - 2.2) * 0.15, 0.1, Vector3(0.0, y, 0.0), mat(BARK), 8)
	ball(root, 0.7, Vector3(0.0, 5.2, 0.0), mat(SAP, 1.5), 10)
	var halo: Node3D = group(root, "Spin", Vector3(0.0, 5.2, 0.0))
	for i: int in 4:
		var ang: float = float(i) * TAU / 4.0
		wedge(halo, Vector3(0.6, 0.1, 0.3), Vector3(cos(ang) * 1.15, 0.0, sin(ang) * 1.15), mat(LEAF_LIGHT), 1.0, Vector3(0.0, -ang, 0.0))
	# The way in, under a lintel of sap.
	box(root, Vector3(0.2, 0.8, 1.1), Vector3(2.5, 0.7, 0.0), mat(CHARRED))
	box(root, Vector3(0.1, 0.08, 1.3), Vector3(2.6, 1.14, 0.0), mat(SAP, 1.4))
	# Command mast: a bone spire with the root of the signal grid at its tip.
	cyl(root, 0.06, 0.2, 3.4, Vector3(3.0, 1.95, 3.0), mat(BONE), 5)
	ring(root, 0.75, 0.9, Vector3(3.0, 2.6, 3.0), team_mat(team))
	ring(root, 0.45, 0.58, Vector3(3.0, 3.3, 3.0), mat(SAP, 1.0))
	ball(root, 0.22, Vector3(3.0, 3.8, 3.0), mat(team, 1.4))
	cyl(root, 0.4, 0.5, 0.8, Vector3(-2.9, 0.65, -2.9), mat(BARK_LIGHT), 8)
	var t: Node3D = _turret(root, Vector3(-2.9, 1.05, -2.9))
	_bud(t, team, 0.4)
	_quills(t, 3, 0.9, 0.14)


static func _tendril(root: Node3D, team: Color) -> void:
	cyl(root, 0.55, 0.85, 0.3, Vector3(0.0, 0.15, 0.0), mat(BARK), 8)
	_petals(root, Vector3(0.0, 0.2, 0.0), 5, 0.6, Vector3(0.7, 0.4, 0.5), LEAF)
	# A stalk of bone, jointed like bamboo.
	cyl(root, 0.1, 0.26, 4.2, Vector3(0.0, 2.3, 0.0), mat(BONE), 6)
	for y: float in [1.1, 2.0, 2.9, 3.7]:
		cyl(root, 0.3 - y * 0.04, 0.3 - y * 0.04, 0.08, Vector3(0.0, y, 0.0), mat(BARK), 6)
	ring(root, 0.5, 0.62, Vector3(0.0, 2.4, 0.0), team_mat(team))
	ring(root, 0.32, 0.42, Vector3(0.0, 3.4, 0.0), team_mat(team))
	# A whorl of leaves turns below the bud.
	var whorl: Node3D = group(root, "Spin", Vector3(0.0, 4.4, 0.0))
	for i: int in 4:
		var ang: float = float(i) * TAU / 4.0
		wedge(whorl, Vector3(0.7, 0.2, 0.3), Vector3(cos(ang) * 0.45, 0.0, sin(ang) * 0.45), mat(LEAF_LIGHT), 1.0, Vector3(0.0, -ang, 0.0))
	ball(root, 0.24, Vector3(0.0, 4.75, 0.0), mat(SAP, 1.7), 6)
	ball(root, 0.12, Vector3(0.0, 5.08, 0.0), mat(team, 1.4))


static func _mulch_pit(root: Node3D, team: Color) -> void:
	_mound(root, 5.7, 5.7)
	# An open flower round a dark pit that bubbles with sap.
	cyl(root, 1.7, 2.0, 0.9, Vector3(-0.4, 0.65, -0.4), mat(BARK_LIGHT), 8)
	cyl(root, 2.04, 2.04, 0.16, Vector3(-0.4, 0.62, -0.4), team_mat(team), 8)
	cyl(root, 1.5, 1.5, 0.08, Vector3(-0.4, 1.1, -0.4), mat(CHARRED), 8)
	_petals(root, Vector3(-0.4, 0.9, -0.4), 8, 1.95, Vector3(1.0, 0.9, 1.1), LEAF, PI / 8.0)
	for at: Vector3 in [Vector3(-0.9, 1.14, -0.6), Vector3(0.0, 1.14, 0.1), Vector3(-0.3, 1.14, -1.1), Vector3(0.3, 1.14, -0.7)]:
		ball(root, 0.22, at, mat(SAP, 1.3), 6)
	# What the Foragers brought in, heaped by the gate.
	box(root, Vector3(0.9, 0.6, 0.8), Vector3(1.9, 0.5, 1.6), mat(RUST, 0.0, 0.4, 0.7))
	box(root, Vector3(0.8, 0.5, 0.7), Vector3(1.3, 0.45, 2.1), mat(METAL, 0.0, 0.7, 0.45))
	box(root, Vector3(0.7, 0.5, 0.6), Vector3(1.7, 1.0, 1.8), mat(BARK_LIGHT))


static func _seedbed(root: Node3D, team: Color) -> void:
	_mound(root, 5.7, 5.7)
	# A long pod of wood under ribs of bone, a crest of red leaves down its
	# back, and a row of seeds swelling in front of it.
	box(root, Vector3(4.4, 0.8, 2.3), Vector3(-0.1, 0.6, -1.0), mat(BARK_LIGHT))
	var pod: MeshInstance3D = arch(root, 1.15, 4.4, Vector3(-0.1, 1.0, -1.0), mat(BARK_LIGHT))
	pod.rotation = Vector3(0.0, PI * 0.5, 0.0)
	box(root, Vector3(4.46, 0.16, 2.36), Vector3(-0.1, 0.96, -1.0), team_mat(team))
	for x: float in [-2.0, -1.05, -0.1, 0.85, 1.8]:
		var rib: MeshInstance3D = arch(root, 1.24, 0.14, Vector3(x, 1.0, -1.0), mat(BONE))
		rib.rotation = Vector3(0.0, PI * 0.5, 0.0)
	for x: float in [-1.55, -0.6, 0.35, 1.3]:
		wedge(root, Vector3(0.8, 0.5, 0.1), Vector3(x, 2.4, -1.0), mat(LEAF), 0.2)
	box(root, Vector3(0.9, 0.85, 0.1), Vector3(-0.1, 0.7, 0.18), mat(CHARRED))
	box(root, Vector3(1.1, 0.07, 0.12), Vector3(-0.1, 1.16, 0.2), mat(SAP, 1.4))
	for x: float in [-1.9, -0.9, 0.9, 1.9]:
		cyl(root, 0.2, 0.34, 0.7, Vector3(x, 0.55, 1.5), mat(BONE), 6)
		_petals(root, Vector3(x, 0.2, 1.5), 4, 0.3, Vector3(0.4, 0.3, 0.3), LEAF, 0.4)
		box(root, Vector3(0.14, 0.14, 0.14), Vector3(x, 0.96, 1.5), mat(SAP, 1.6))


static func _bloomworks(root: Node3D, team: Color) -> void:
	_mound(root, 7.7, 5.7)
	# A great bud of bound wood, its petals just opening round the sap.
	cyl(root, 2.2, 2.6, 1.4, Vector3(-0.5, 0.9, -0.5), mat(BARK_LIGHT), 8)
	cyl(root, 2.64, 2.64, 0.24, Vector3(-0.5, 1.0, -0.5), team_mat(team), 8)
	cyl(root, 1.2, 2.2, 1.3, Vector3(-0.5, 2.25, -0.5), mat(BARK_LIGHT), 8)
	for i: int in 8:
		var ang: float = float(i) * TAU / 8.0 + PI / 8.0
		cyl(root, 0.06, 0.1, 2.9, Vector3(-0.5 + cos(ang) * 2.05, 1.7, -0.5 + sin(ang) * 2.05), mat(BONE), 4, Vector3(sin(ang) * 0.4, 0.0, -cos(ang) * 0.4))
	_petals(root, Vector3(-0.5, 2.7, -0.5), 6, 1.1, Vector3(1.3, 1.0, 1.0), LEAF)
	ball(root, 0.62, Vector3(-0.5, 3.1, -0.5), mat(SAP, 1.4), 8)
	box(root, Vector3(2.2, 1.3, 0.3), Vector3(-0.5, 0.85, 1.95), mat(CHARRED))
	box(root, Vector3(2.4, 0.08, 0.34), Vector3(-0.5, 1.54, 1.96), mat(SAP, 1.5))
	# A beast half grown on the apron.
	box(root, Vector3(1.3, 0.34, 0.8), Vector3(2.7, 0.44, 1.6), mat(BARK))
	box(root, Vector3(0.6, 0.4, 0.86), Vector3(2.5, 0.72, 1.6), mat(BONE), Vector3(0.0, 0.0, 0.1))
	_petals(root, Vector3(2.9, 0.2, -1.7), 5, 0.4, Vector3(0.6, 0.5, 0.4), LEAF_LIGHT)
	cyl(root, 0.1, 0.2, 1.6, Vector3(2.9, 1.0, -1.7), mat(BONE), 5)
	box(root, Vector3(0.2, 0.2, 0.2), Vector3(2.9, 1.9, -1.7), mat(SAP, 1.6))


static func _spine_stalk(root: Node3D, team: Color) -> void:
	cyl(root, 0.55, 0.9, 0.36, Vector3(0.0, 0.18, 0.0), mat(BARK), 8)
	_petals(root, Vector3(0.0, 0.3, 0.0), 6, 0.55, Vector3(0.6, 0.4, 0.45), LEAF)
	cyl(root, 0.3, 0.42, 0.8, Vector3(0.0, 0.7, 0.0), mat(BARK_LIGHT), 8)
	ring(root, 0.42, 0.52, Vector3(0.0, 0.8, 0.0), team_mat(team))
	var t: Node3D = _turret(root, Vector3(0.0, 1.1, 0.0))
	_bud(t, team, 0.42)
	_quills(t, 5, 0.95, 0.12)


static func _elder_bough(root: Node3D, team: Color) -> void:
	_mound(root, 5.7, 5.7)
	cyl(root, 1.5, 1.9, 0.6, Vector3(0.0, 0.5, 0.0), mat(BARK_LIGHT), 8)
	cyl(root, 1.56, 1.56, 0.14, Vector3(0.0, 0.76, 0.0), team_mat(team), 8)
	_petals(root, Vector3(0.0, 0.7, 0.0), 8, 1.7, Vector3(1.0, 0.7, 0.9), LEAF, PI / 8.0)
	# Four great tusks of bone lean together over a lantern of sap.
	for i: int in 4:
		var ang: float = float(i) * TAU / 4.0 + PI * 0.25
		cyl(root, 0.06, 0.34, 4.0, Vector3(cos(ang) * 1.0, 2.6, sin(ang) * 1.0), mat(BONE), 6, Vector3(sin(ang) * 0.36, 0.0, -cos(ang) * 0.36))
	ball(root, 0.7, Vector3(0.0, 2.5, 0.0), mat(SAP, 1.5), 10)
	var halo: Node3D = group(root, "Spin", Vector3(0.0, 2.5, 0.0))
	for i: int in 4:
		var ang: float = float(i) * TAU / 4.0
		wedge(halo, Vector3(0.55, 0.12, 0.3), Vector3(cos(ang) * 1.2, 0.0, sin(ang) * 1.2), mat(LEAF_LIGHT), 1.0, Vector3(0.0, -ang, 0.0))
	box(root, Vector3(0.2, 0.2, 0.2), Vector3(0.0, 4.55, 0.0), mat(SAP, 1.7))


# --------------------------------------------------------- Lodestone Circle

## A Circle foot soldier: graphite fatigues, a porcelain helmet with a
## magenta visor and a small coil on the back.
static func _lineman(root: Node3D, team: Color) -> void:
	_soldier(root, team, PORCELAIN, GRAPHITE_LIGHT, GRAPHITE)
	box(root, Vector3(0.05, 0.06, 0.24), Vector3(0.17, 1.3, 0.0), mat(FLUX, 1.7))
	cyl(root, 0.1, 0.1, 0.3, Vector3(-0.32, 0.98, 0.0), mat(COIL, 0.0, 0.7, 0.4), 6)
	cyl(root, 0.03, 0.03, 0.3, Vector3(-0.32, 1.28, 0.0), mat(GUNMETAL), 4)
	box(root, Vector3(0.06, 0.06, 0.06), Vector3(-0.32, 1.45, 0.0), mat(FLUX, 1.6))


## A porcelain insulator: a short stack of ribbed discs.
static func _insulator(root: Node3D, pos: Vector3, height: float, radius: float = 0.12) -> void:
	cyl(root, radius * 0.5, radius * 0.5, height, pos + Vector3(0.0, height * 0.5, 0.0), mat(GUNMETAL), 5)
	var discs: int = maxi(2, int(height / 0.14))
	for i: int in discs:
		cyl(root, radius * 0.75, radius, 0.07, pos + Vector3(0.0, (float(i) + 0.5) * height / float(discs), 0.0), mat(PORCELAIN), 8)


## A copper winding round an axis along X, between two graphite cheeks.
static func _winding(parent: Node3D, pos: Vector3, radius: float, length: float) -> void:
	cyl(parent, radius, radius, length, pos, mat(COIL, 0.0, 0.7, 0.4), 10, Vector3(0.0, 0.0, -PI * 0.5))
	for side: float in [-1.0, 1.0]:
		cyl(parent, radius * 1.2, radius * 1.2, 0.06, pos + Vector3(side * length * 0.5, 0.0, 0.0), mat(GRAPHITE), 10, Vector3(0.0, 0.0, -PI * 0.5))


## A horseshoe magnet lying along X with its poles forward.
static func _horseshoe(parent: Node3D, pos: Vector3, length: float, gap: float, thick: float) -> void:
	for side: float in [-1.0, 1.0]:
		box(parent, Vector3(length, thick, thick), pos + Vector3(0.0, 0.0, side * gap * 0.5), mat(GRAPHITE_LIGHT, 0.0, 0.6, 0.4))
		box(parent, Vector3(length * 0.22, thick * 1.1, thick * 1.1), pos + Vector3(length * 0.42, 0.0, side * gap * 0.5), mat(PORCELAIN))
	box(parent, Vector3(thick, thick, gap + thick), pos + Vector3(-length * 0.5 + thick * 0.5, 0.0, 0.0), mat(GRAPHITE_LIGHT, 0.0, 0.6, 0.4))


## The Circle's car: a graphite hull with rounded shoulders, a copper bus
## bar down each flank on porcelain stand-offs, and a magenta strip in front.
static func _coil_car(root: Node3D, team: Color, length: float, width: float, axles: int, height: float = 0.42) -> void:
	box(root, Vector3(length, 0.24, width * 0.86), Vector3(0.0, 0.46, 0.0), mat(GRAPHITE))
	box(root, Vector3(length * 0.84, height, width * 0.9), Vector3(-length * 0.03, 0.58 + height * 0.5, 0.0), mat(GRAPHITE_LIGHT))
	wedge(root, Vector3(length * 0.2, height, width * 0.9), Vector3(length * 0.49, 0.58 + height * 0.5, 0.0), mat(GRAPHITE_LIGHT), 0.0)
	box(root, Vector3(length * 0.5, 0.06, width * 0.6), Vector3(-length * 0.08, 0.6 + height, 0.0), team_mat(team))
	for side: float in [-1.0, 1.0]:
		var z: float = side * (width * 0.5)
		box(root, Vector3(length * 0.82, 0.1, 0.06), Vector3(-length * 0.02, 0.62, z + side * 0.02), team_mat(team))
		cyl(root, 0.05, 0.05, length * 0.74, Vector3(-length * 0.04, 0.6 + height * 0.72, z + side * 0.08), mat(COIL, 0.0, 0.7, 0.4), 6, Vector3(0.0, 0.0, -PI * 0.5))
		for x: float in [-length * 0.34, length * 0.26]:
			cyl(root, 0.045, 0.06, 0.1, Vector3(x, 0.6 + height * 0.72, z + side * 0.03), mat(PORCELAIN), 6, Vector3(PI * 0.5, 0.0, 0.0))
		for i: int in axles:
			var x: float = lerpf(-length * 0.34, length * 0.34, float(i) / float(maxi(1, axles - 1)))
			wheel(root, 0.3, 0.22, Vector3(x, 0.3, z - side * 0.04))
	box(root, Vector3(0.05, 0.07, width * 0.56), Vector3(length * 0.5 + 0.01, 0.56, 0.0), mat(FLUX, 1.6))
	_tail(root, -length * 0.5 - 0.01, 0.62, width * 0.34)


## A fork of two prongs with flux crackling between the tips.
static func _prongs(t: Node3D, pos: Vector3, length: float, gap: float) -> void:
	for side: float in [-1.0, 1.0]:
		box(t, Vector3(length, 0.07, 0.07), pos + Vector3(length * 0.5, 0.0, side * gap * 0.5), mat(GUNMETAL))
		box(t, Vector3(0.12, 0.1, 0.1), pos + Vector3(length, 0.0, side * gap * 0.5), mat(PORCELAIN))
	ball(t, gap * 0.28, pos + Vector3(length, 0.0, 0.0), mat(FLUX, 1.8), 6)


static func _lodecart(root: Node3D, team: Color) -> void:
	_coil_car(root, team, 2.3, 1.2, 3, 0.3)
	box(root, Vector3(0.6, 0.5, 1.05), Vector3(0.72, 1.14, 0.0), mat(GRAPHITE_LIGHT))
	box(root, Vector3(0.05, 0.16, 0.86), Vector3(1.03, 1.2, 0.0), mat(FLUX, 1.0))
	box(root, Vector3(1.3, 0.2, 1.16), Vector3(-0.4, 0.98, 0.0), mat(GRAPHITE))
	_cargo(root, Vector3(-0.4, 1.08, 0.0), Vector3(1.1, 0.48, 0.98))
	# A jib with a lifting magnet over the bed.
	cyl(root, 0.05, 0.06, 1.0, Vector3(0.36, 1.64, 0.46), mat(GUNMETAL), 5)
	box(root, Vector3(0.9, 0.06, 0.06), Vector3(-0.06, 2.12, 0.46), mat(GUNMETAL))
	cyl(root, 0.2, 0.2, 0.1, Vector3(-0.46, 1.96, 0.46), mat(PORCELAIN), 8)
	cyl(root, 0.15, 0.15, 0.05, Vector3(-0.46, 1.89, 0.46), mat(FLUX, 1.3), 8)


static func _compass(root: Node3D, team: Color) -> void:
	_coil_car(root, team, 1.8, 0.95, 2, 0.3)
	var t: Node3D = _turret(root, Vector3(-0.1, 0.9, 0.0))
	cyl(t, 0.26, 0.3, 0.16, Vector3(0.0, 0.08, 0.0), mat(GRAPHITE), 8)
	barrel(t, 0.035, 0.7, Vector3(0.2, 0.12, 0.0), mat(GUNMETAL))
	# The needle that gives it its name: one half white, one half magenta.
	wedge(t, Vector3(0.5, 0.05, 0.16), Vector3(0.22, 0.26, 0.0), mat(FLUX, 1.2), 1.0)
	wedge(t, Vector3(0.5, 0.05, 0.16), Vector3(-0.28, 0.26, 0.0), mat(PORCELAIN), 0.0)
	aerial(root, Vector3(-0.7, 0.9, 0.3), 0.9, FLUX)


static func _dynamo(root: Node3D, team: Color) -> void:
	_coil_car(root, team, 2.2, 1.2, 3, 0.4)
	var t: Node3D = _turret(root, Vector3(-0.15, 1.04, 0.0))
	box(t, Vector3(0.9, 0.14, 0.9), Vector3(-0.1, 0.07, 0.0), mat(GRAPHITE))
	# A drum wound with copper lies across the turret; two forks reach forward.
	var drum: MeshInstance3D = cyl(t, 0.34, 0.34, 0.7, Vector3(-0.15, 0.46, 0.0), mat(COIL, 0.0, 0.7, 0.4), 10, Vector3(PI * 0.5, 0.0, 0.0))
	drum.name = "Drum"
	for z: float in [-0.39, 0.39]:
		cyl(t, 0.4, 0.4, 0.07, Vector3(-0.15, 0.46, z), mat(GRAPHITE_LIGHT), 10, Vector3(PI * 0.5, 0.0, 0.0))
	box(t, Vector3(0.3, 0.07, 0.5), Vector3(-0.15, 0.84, 0.0), team_mat(team))
	_prongs(t, Vector3(0.2, 0.34, 0.0), 0.75, 0.42)


static func _armature(root: Node3D, team: Color) -> void:
	_tracks(root, 2.8, 0.62)
	box(root, Vector3(2.7, 0.44, 1.0), Vector3(0.0, 0.66, 0.0), mat(GRAPHITE_LIGHT))
	wedge(root, Vector3(0.6, 0.44, 1.0), Vector3(1.55, 0.66, 0.0), mat(GRAPHITE_LIGHT), 0.0)
	box(root, Vector3(2.2, 0.08, 1.5), Vector3(-0.1, 0.9, 0.0), team_mat(team))
	for z: float in [-0.76, 0.76]:
		cyl(root, 0.05, 0.05, 2.2, Vector3(-0.1, 0.98, z), mat(COIL, 0.0, 0.7, 0.4), 6, Vector3(0.0, 0.0, -PI * 0.5))
	box(root, Vector3(0.05, 0.08, 0.7), Vector3(1.86, 0.6, 0.0), mat(FLUX, 1.6))
	var t: Node3D = _turret(root, Vector3(-0.25, 0.94, 0.0))
	cyl(t, 0.62, 0.72, 0.4, Vector3(0.0, 0.2, 0.0), mat(GRAPHITE), 8)
	box(t, Vector3(0.7, 0.06, 0.7), Vector3(-0.05, 0.42, 0.0), team_mat(team))
	# The coilgun: two rails and a row of windings down their length.
	for z: float in [-0.11, 0.11]:
		box(t, Vector3(2.3, 0.08, 0.06), Vector3(1.55, 0.22, z), mat(GUNMETAL))
	for x: float in [0.8, 1.25, 1.7, 2.15]:
		_winding(t, Vector3(x, 0.22, 0.0), 0.17, 0.22)
	box(t, Vector3(0.1, 0.16, 0.34), Vector3(2.72, 0.22, 0.0), mat(PORCELAIN))
	box(t, Vector3(0.05, 0.08, 0.14), Vector3(2.78, 0.22, 0.0), mat(FLUX, 1.9))
	_insulator(t, Vector3(-0.4, 0.4, 0.34), 0.4, 0.09)


static func _stator(root: Node3D, team: Color) -> void:
	_coil_car(root, team, 2.2, 1.2, 3, 0.4)
	var t: Node3D = _turret(root, Vector3(-0.2, 1.04, 0.0))
	cyl(t, 0.42, 0.5, 0.2, Vector3(0.0, 0.1, 0.0), mat(GRAPHITE), 8)
	# Four barrels through an upright ring of windings.
	var hoop: MeshInstance3D = ring(t, 0.3, 0.46, Vector3(0.36, 0.7, 0.0), mat(COIL, 0.0, 0.7, 0.4))
	hoop.rotation = Vector3(0.0, 0.0, PI * 0.5 - 0.85)
	for z: float in [-0.17, 0.17]:
		for y: float in [-0.1, 0.1]:
			cyl(t, 0.03, 0.03, 1.4, Vector3(0.5 - y * 0.75, 0.86 + y * 0.66, z), mat(GUNMETAL), 5, Vector3(0.0, 0.0, -0.85))
	box(t, Vector3(0.08, 0.08, 0.4), Vector3(1.0, 1.42, 0.0), mat(FLUX, 1.6), Vector3(0.0, 0.0, 0.72))
	box(t, Vector3(0.4, 0.06, 0.6), Vector3(-0.2, 0.24, 0.0), team_mat(team))


static func _solenoid(root: Node3D, team: Color) -> void:
	_coil_car(root, team, 2.6, 1.3, 3, 0.38)
	for z: float in [-0.9, 0.9]:
		box(root, Vector3(0.5, 0.08, 0.14), Vector3(-1.05, 0.28, z), mat(GRAPHITE), Vector3(0.0, 0.0, 0.4))
	var t: Node3D = _turret(root, Vector3(-0.4, 1.0, 0.0))
	cyl(t, 0.46, 0.54, 0.22, Vector3(0.0, 0.11, 0.0), mat(GRAPHITE), 8)
	# A long tube wound with copper from breech to muzzle.
	cyl(t, 0.2, 0.2, 2.5, Vector3(0.75, 1.02, 0.0), mat(GRAPHITE_LIGHT), 8, Vector3(0.0, 0.0, -0.95))
	for d: float in [0.3, 0.75, 1.2, 1.65, 2.1]:
		cyl(t, 0.27, 0.27, 0.2, Vector3(-0.27 + d * 0.81, 0.3 + d * 0.58, 0.0), mat(COIL, 0.0, 0.7, 0.4), 8, Vector3(0.0, 0.0, -0.95))
	cyl(t, 0.24, 0.24, 0.08, Vector3(1.78, 1.76, 0.0), mat(PORCELAIN), 8, Vector3(0.0, 0.0, -0.95))
	ball(t, 0.14, Vector3(1.84, 1.8, 0.0), mat(FLUX, 1.8), 6)
	box(t, Vector3(0.4, 0.06, 0.7), Vector3(-0.3, 0.26, 0.0), team_mat(team))


## The slab the Circle builds on: graphite, a copper bus bar let into each
## edge and a porcelain insulator standing at each corner.
static func _plinth(root: Node3D, w: float, d: float, h: float = 0.4) -> void:
	box(root, Vector3(w, h, d), Vector3(0.0, 0.0, 0.0), mat(GRAPHITE))
	box(root, Vector3(w - 0.7, 0.05, d - 0.7), Vector3(0.0, h * 0.5 + 0.02, 0.0), mat(GRAPHITE_LIGHT))
	for side: float in [-1.0, 1.0]:
		box(root, Vector3(w - 1.3, 0.06, 0.1), Vector3(0.0, h * 0.5 + 0.04, side * (d * 0.5 - 0.22)), mat(COIL, 0.0, 0.7, 0.4))
		box(root, Vector3(0.1, 0.06, d - 1.3), Vector3(side * (w * 0.5 - 0.22), h * 0.5 + 0.04, 0.0), mat(COIL, 0.0, 0.7, 0.4))
		for other: float in [-1.0, 1.0]:
			var at: Vector3 = Vector3(side * (w * 0.5 - 0.3), h * 0.5, other * (d * 0.5 - 0.3))
			_insulator(root, at, 0.7, 0.16)
			box(root, Vector3(0.1, 0.1, 0.1), at + Vector3(0.0, 0.76, 0.0), mat(FLUX, 1.5))


## A hall with a rounded roof and a ring let into its front wall.
static func _drum_hall(root: Node3D, at: Vector3, size: Vector3, team: Color) -> void:
	box(root, Vector3(size.x, size.y * 0.6, size.z), at + Vector3(0.0, size.y * 0.3, 0.0), mat(GRAPHITE_LIGHT))
	var vault: MeshInstance3D = arch(root, size.z * 0.5, size.x, at + Vector3(0.0, size.y * 0.6, 0.0), mat(GRAPHITE))
	vault.rotation = Vector3(0.0, PI * 0.5, 0.0)
	vault.scale = Vector3(1.0, (size.y * 0.4) / (size.z * 0.5), 1.0)
	box(root, Vector3(size.x + 0.05, 0.16, size.z + 0.05), at + Vector3(0.0, size.y * 0.56, 0.0), team_mat(team))
	for x: float in [-size.x * 0.3, 0.0, size.x * 0.3]:
		box(root, Vector3(0.14, size.y * 0.42, size.z + 0.08), at + Vector3(x, size.y * 0.8, 0.0), mat(COIL, 0.0, 0.7, 0.4)).scale = Vector3(1.0, 1.0, 0.92)


static func _lode_hall(root: Node3D, team: Color) -> void:
	_plinth(root, 7.7, 7.7, 0.5)
	# A round hall under a great upright ring: the lodestone itself.
	cyl(root, 2.5, 2.7, 1.9, Vector3(0.0, 1.2, 0.0), mat(GRAPHITE_LIGHT), 12)
	cyl(root, 2.74, 2.74, 0.3, Vector3(0.0, 1.5, 0.0), team_mat(team), 12)
	cyl(root, 1.7, 2.5, 0.7, Vector3(0.0, 2.5, 0.0), mat(GRAPHITE), 12)
	var hoop: MeshInstance3D = ring(root, 2.6, 3.2, Vector3(0.0, 2.3, 0.0), mat(GRAPHITE_LIGHT, 0.0, 0.6, 0.4))
	hoop.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	for side: float in [-1.0, 1.0]:
		# Windings where the ring meets the ground, porcelain caps above them.
		cyl(root, 0.5, 0.5, 1.1, Vector3(side * 2.9, 1.2, 0.0), mat(COIL, 0.0, 0.7, 0.4), 10)
		cyl(root, 0.56, 0.56, 0.12, Vector3(side * 2.9, 1.8, 0.0), mat(PORCELAIN), 10)
	ball(root, 0.55, Vector3(0.0, 3.4, 0.0), mat(FLUX, 1.5), 10)
	var halo: Node3D = group(root, "Spin", Vector3(0.0, 3.4, 0.0))
	ring(halo, 0.85, 0.95, Vector3.ZERO, mat(PORCELAIN))
	box(halo, Vector3(0.16, 0.16, 0.16), Vector3(0.9, 0.0, 0.0), mat(FLUX, 1.8))
	box(halo, Vector3(0.16, 0.16, 0.16), Vector3(-0.9, 0.0, 0.0), mat(FLUX, 1.8))
	box(root, Vector3(1.3, 1.1, 0.14), Vector3(0.0, 0.85, 2.64), mat(GUNMETAL))
	box(root, Vector3(1.5, 0.08, 0.16), Vector3(0.0, 1.44, 2.66), mat(FLUX, 1.4))
	# Command mast: the root of the signal grid.
	_insulator(root, Vector3(2.6, 0.25, 2.6), 2.4, 0.2)
	cyl(root, 0.05, 0.08, 1.6, Vector3(2.6, 3.4, 2.6), mat(GUNMETAL), 5)
	ring(root, 0.75, 0.9, Vector3(2.6, 2.9, 2.6), team_mat(team))
	ring(root, 0.45, 0.58, Vector3(2.6, 3.6, 2.6), mat(FLUX, 1.0))
	ball(root, 0.22, Vector3(2.6, 4.3, 2.6), mat(team, 1.4))
	cyl(root, 0.45, 0.55, 0.9, Vector3(-2.5, 0.7, -2.5), mat(GRAPHITE_LIGHT), 8)
	var t: Node3D = _turret(root, Vector3(-2.5, 1.15, -2.5))
	cyl(t, 0.4, 0.46, 0.2, Vector3(0.0, 0.1, 0.0), mat(GRAPHITE), 8)
	_prongs(t, Vector3(0.1, 0.3, 0.0), 0.8, 0.36)


static func _conductor(root: Node3D, team: Color) -> void:
	cyl(root, 0.6, 0.85, 0.3, Vector3(0.0, 0.15, 0.0), mat(GRAPHITE), 8)
	_insulator(root, Vector3(0.0, 0.3, 0.0), 2.2, 0.3)
	cyl(root, 0.08, 0.1, 1.9, Vector3(0.0, 3.4, 0.0), mat(GUNMETAL), 6)
	cyl(root, 0.3, 0.3, 0.5, Vector3(0.0, 2.75, 0.0), mat(COIL, 0.0, 0.7, 0.4), 10)
	ring(root, 0.55, 0.67, Vector3(0.0, 2.2, 0.0), team_mat(team))
	ring(root, 0.34, 0.44, Vector3(0.0, 3.5, 0.0), team_mat(team))
	# Two horns at the top with flux between them.
	for side: float in [-1.0, 1.0]:
		cyl(root, 0.03, 0.05, 0.9, Vector3(side * 0.26, 4.5, 0.0), mat(GUNMETAL), 5, Vector3(0.0, 0.0, -side * 0.36))
		box(root, Vector3(0.1, 0.1, 0.1), Vector3(side * 0.42, 4.92, 0.0), mat(PORCELAIN))
	var spark: Node3D = group(root, "Spin", Vector3(0.0, 4.6, 0.0))
	box(spark, Vector3(0.5, 0.06, 0.06), Vector3.ZERO, mat(FLUX, 1.8))
	box(spark, Vector3(0.06, 0.06, 0.5), Vector3.ZERO, mat(FLUX, 1.8))
	ball(root, 0.12, Vector3(0.0, 5.0, 0.0), mat(team, 1.4))


static func _magnet_yard(root: Node3D, team: Color) -> void:
	_plinth(root, 5.7, 5.7)
	_drum_hall(root, Vector3(-0.9, 0.2, -1.2), Vector3(3.2, 1.8, 2.4), team)
	# A gantry over the scrap heap, with the lifting magnet hanging from it.
	for x: float in [0.2, 2.3]:
		for z: float in [0.5, 2.2]:
			cyl(root, 0.07, 0.09, 2.4, Vector3(x, 1.4, z), mat(GUNMETAL), 5)
	box(root, Vector3(2.4, 0.12, 0.12), Vector3(1.25, 2.6, 0.5), mat(GRAPHITE_LIGHT))
	box(root, Vector3(2.4, 0.12, 0.12), Vector3(1.25, 2.6, 2.2), mat(GRAPHITE_LIGHT))
	box(root, Vector3(0.2, 0.14, 1.9), Vector3(1.25, 2.68, 1.35), team_mat(team))
	cyl(root, 0.02, 0.02, 0.8, Vector3(1.25, 2.2, 1.35), mat(GUNMETAL), 4)
	cyl(root, 0.42, 0.42, 0.16, Vector3(1.25, 1.75, 1.35), mat(PORCELAIN), 10)
	cyl(root, 0.34, 0.34, 0.06, Vector3(1.25, 1.65, 1.35), mat(FLUX, 1.4), 10)
	box(root, Vector3(0.9, 0.6, 0.8), Vector3(1.0, 0.5, 1.3), mat(RUST, 0.0, 0.4, 0.7))
	box(root, Vector3(0.8, 0.5, 0.7), Vector3(1.7, 0.45, 1.6), mat(METAL, 0.0, 0.7, 0.45))
	box(root, Vector3(0.6, 0.4, 0.5), Vector3(1.3, 1.0, 1.4), mat(GRAPHITE_LIGHT), Vector3(0.0, 0.4, 0.2))
	_winding(root, Vector3(-1.9, 0.7, 1.8), 0.5, 0.9)


static func _ring_hall(root: Node3D, team: Color) -> void:
	_plinth(root, 5.7, 5.7)
	_drum_hall(root, Vector3(-0.2, 0.2, -0.9), Vector3(4.4, 2.2, 2.6), team)
	# The door is a ring: recruits walk through the field.
	var gate: MeshInstance3D = ring(root, 0.75, 1.0, Vector3(-0.2, 1.2, 0.46), mat(PORCELAIN))
	gate.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	cyl(root, 0.74, 0.74, 0.06, Vector3(-0.2, 1.2, 0.42), mat(GUNMETAL), 12, Vector3(PI * 0.5, 0.0, 0.0))
	box(root, Vector3(0.12, 0.12, 0.12), Vector3(-0.2, 2.3, 0.5), mat(FLUX, 1.7))
	_insulator(root, Vector3(1.9, 0.2, 1.6), 1.5, 0.22)
	box(root, Vector3(0.5, 0.9, 0.04), Vector3(2.2, 1.6, 1.6), team_mat(team))
	_winding(root, Vector3(-1.9, 0.6, 1.8), 0.4, 0.8)


static func _winding_shed(root: Node3D, team: Color) -> void:
	_plinth(root, 7.7, 5.7)
	# A long shed under a saw-tooth roof.
	box(root, Vector3(6.2, 1.7, 3.0), Vector3(0.0, 1.05, -0.9), mat(GRAPHITE_LIGHT))
	for i: int in 4:
		wedge(root, Vector3(1.55, 0.8, 3.0), Vector3(-2.32 + float(i) * 1.55, 2.3, -0.9), mat(GRAPHITE), 0.0)
		box(root, Vector3(0.06, 0.6, 2.6), Vector3(-3.06 + float(i) * 1.55, 2.24, -0.9), mat(FLUX, 0.7))
	box(root, Vector3(6.26, 0.2, 3.06), Vector3(0.0, 1.8, -0.9), team_mat(team))
	box(root, Vector3(2.8, 1.4, 0.1), Vector3(-0.6, 0.9, 0.62), mat(GUNMETAL))
	box(root, Vector3(3.0, 0.08, 0.12), Vector3(-0.6, 1.64, 0.64), mat(FLUX, 1.5))
	# A great coil waits on the apron beside a half-built hull.
	_winding(root, Vector3(2.5, 0.85, 1.8), 0.62, 1.1)
	box(root, Vector3(1.7, 0.3, 1.0), Vector3(-1.6, 0.4, 1.9), mat(GRAPHITE))
	wedge(root, Vector3(0.9, 0.36, 0.9), Vector3(-1.4, 0.72, 1.9), mat(GRAPHITE_LIGHT), 0.0)
	_insulator(root, Vector3(3.3, 0.2, -2.3), 2.2, 0.2)
	box(root, Vector3(0.12, 0.12, 0.12), Vector3(3.3, 2.5, -2.3), mat(FLUX, 1.7))


static func _arc_pole(root: Node3D, team: Color) -> void:
	cyl(root, 0.55, 0.9, 0.36, Vector3(0.0, 0.18, 0.0), mat(GRAPHITE), 8)
	_insulator(root, Vector3(0.0, 0.36, 0.0), 0.7, 0.3)
	ring(root, 0.62, 0.72, Vector3(0.0, 0.34, 0.0), team_mat(team))
	var t: Node3D = _turret(root, Vector3(0.0, 1.1, 0.0))
	cyl(t, 0.36, 0.42, 0.24, Vector3(0.0, 0.12, 0.0), mat(GRAPHITE_LIGHT), 8)
	box(t, Vector3(0.4, 0.06, 0.4), Vector3(-0.05, 0.27, 0.0), team_mat(team))
	_winding(t, Vector3(-0.1, 0.5, 0.0), 0.2, 0.36)
	_prongs(t, Vector3(0.05, 0.5, 0.0), 0.85, 0.36)


static func _resonator(root: Node3D, team: Color) -> void:
	_plinth(root, 5.7, 5.7)
	cyl(root, 1.3, 1.7, 0.7, Vector3(0.0, 0.55, 0.0), mat(GRAPHITE_LIGHT), 10)
	cyl(root, 1.34, 1.34, 0.14, Vector3(0.0, 0.84, 0.0), team_mat(team), 10)
	cyl(root, 0.5, 0.5, 0.2, Vector3(0.0, 1.1, 0.0), mat(COIL, 0.0, 0.7, 0.4), 10)
	# Three rings stand one inside the other round a ball of flux; the
	# innermost turns.
	var outer: MeshInstance3D = ring(root, 1.75, 1.95, Vector3(0.0, 2.7, 0.0), mat(GRAPHITE_LIGHT, 0.0, 0.6, 0.4))
	outer.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	var middle: MeshInstance3D = ring(root, 1.3, 1.45, Vector3(0.0, 2.7, 0.0), mat(COIL, 0.0, 0.7, 0.4))
	middle.rotation = Vector3(PI * 0.5, PI * 0.5, 0.0)
	var halo: Node3D = group(root, "Spin", Vector3(0.0, 2.7, 0.0))
	var inner: MeshInstance3D = ring(halo, 0.85, 0.97, Vector3.ZERO, mat(PORCELAIN))
	inner.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	box(halo, Vector3(0.14, 0.14, 0.14), Vector3(0.9, 0.0, 0.0), mat(FLUX, 1.8))
	box(halo, Vector3(0.14, 0.14, 0.14), Vector3(-0.9, 0.0, 0.0), mat(FLUX, 1.8))
	ball(root, 0.5, Vector3(0.0, 2.7, 0.0), mat(FLUX, 1.5), 10)
	cyl(root, 0.2, 0.3, 1.2, Vector3(0.0, 1.5, 0.0), mat(GRAPHITE), 8)


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
