class_name ModelFactory
extends RefCounted
## Builds every unit, building and prop model from primitive meshes. Models
## face +X, stand on y = 0 and are centred on the origin. A child node named
## "Turret" (if present) is rotated by the view to follow the weapon aim.

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

static var _materials: Dictionary[String, StandardMaterial3D] = {}
static var _meshes: Dictionary[String, Mesh] = {}


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
	return mat(team, 0.55, 0.1, 0.6)


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
	return cyl(parent, radius, radius, width, pos, mat(RUBBER), 8, Vector3(PI * 0.5, 0.0, 0.0))


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
	var t: Node3D = Node3D.new()
	t.name = "Turret"
	t.position = pos
	root.add_child(t)
	return t


# ------------------------------------------------------------------ entry

## Builds the model for an entity definition's `model` key.
static func build(model: String, team: Color) -> Node3D:
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
	return root


## A burnt-out version of a model, for wrecks.
static func build_wreck(model: String, seed_value: int) -> Node3D:
	var root: Node3D = build(model, CHARRED)
	var charred: StandardMaterial3D = mat(CHARRED, 0.0, 0.3, 0.9)
	var scorched: StandardMaterial3D = mat(Color(0.20, 0.17, 0.14), 0.0, 0.3, 0.9)
	var i: int = 0
	for child: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = child as MeshInstance3D
		mi.material_override = charred if (i + seed_value) % 3 != 0 else scorched
		i += 1
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
	var root: Node3D = Node3D.new()
	root.name = "Model"
	var rng: SimRng = SimRng.new(seed_value)
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


## A neutral uplink site: a pad with a dormant mast.
static func build_uplink() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Model"
	cyl(root, 2.2, 2.4, 0.3, Vector3(0.0, 0.15, 0.0), mat(CONCRETE_DARK), 10)
	cyl(root, 0.25, 0.4, 3.0, Vector3(0.0, 1.8, 0.0), mat(METAL, 0.0, 0.6, 0.4), 6)
	ring(root, 0.9, 1.1, Vector3(0.0, 2.6, 0.0), mat(Color(0.9, 0.9, 0.95), 0.6))
	ball(root, 0.35, Vector3(0.0, 3.5, 0.0), mat(Color(0.9, 0.9, 0.95), 0.9))
	return root


# --------------------------------------------------------------- infantry

static func _soldier(root: Node3D, team: Color, helmet: Color) -> void:
	box(root, Vector3(0.26, 0.62, 0.36), Vector3(0.0, 0.31, 0.0), mat(UNIFORM_DARK))
	box(root, Vector3(0.34, 0.52, 0.48), Vector3(0.0, 0.86, 0.0), mat(UNIFORM))
	box(root, Vector3(0.37, 0.16, 0.51), Vector3(0.0, 0.98, 0.0), team_mat(team))
	ball(root, 0.19, Vector3(0.02, 1.3, 0.0), mat(helmet), 6)


# --------------------------------------------------------------- vehicles

static func _hauler(root: Node3D, team: Color) -> void:
	box(root, Vector3(2.2, 0.3, 1.15), Vector3(0.0, 0.48, 0.0), mat(HULL_DARK))
	box(root, Vector3(0.7, 0.72, 1.15), Vector3(0.72, 0.96, 0.0), mat(HULL))
	box(root, Vector3(0.06, 0.3, 0.95), Vector3(1.08, 1.08, 0.0), mat(GLASS, 0.15, 0.3, 0.2))
	box(root, Vector3(1.4, 0.55, 1.25), Vector3(-0.38, 0.9, 0.0), mat(HULL_DARK))
	box(root, Vector3(1.42, 0.14, 1.27), Vector3(-0.38, 1.12, 0.0), team_mat(team))
	box(root, Vector3(1.2, 0.2, 1.0), Vector3(-0.38, 1.24, 0.0), mat(RUST, 0.0, 0.4, 0.7))
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
	box(root, Vector3(2.7, 0.55, 0.45), Vector3(0.0, 0.3, 0.72), mat(RUBBER))
	box(root, Vector3(2.7, 0.55, 0.45), Vector3(0.0, 0.3, -0.72), mat(RUBBER))
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
