class_name MeshBuf
extends RefCounted
## Collects flat-shaded, vertex-coloured triangles and turns them into a mesh.
## Every face is given the point it should face away from, so callers never
## have to think about winding order.

const PHI: float = 1.618034
const ICO_VERTS: Array[Vector3] = [
	Vector3(-1.0, PHI, 0.0), Vector3(1.0, PHI, 0.0), Vector3(-1.0, -PHI, 0.0), Vector3(1.0, -PHI, 0.0),
	Vector3(0.0, -1.0, PHI), Vector3(0.0, 1.0, PHI), Vector3(0.0, -1.0, -PHI), Vector3(0.0, 1.0, -PHI),
	Vector3(PHI, 0.0, -1.0), Vector3(PHI, 0.0, 1.0), Vector3(-PHI, 0.0, -1.0), Vector3(-PHI, 0.0, 1.0),
]
const ICO_FACES: PackedInt32Array = [
	0, 11, 5, 0, 5, 1, 0, 1, 7, 0, 7, 10, 0, 10, 11,
	1, 5, 9, 5, 11, 4, 11, 10, 2, 10, 7, 6, 7, 1, 8,
	3, 9, 4, 3, 4, 2, 3, 2, 6, 3, 6, 8, 3, 8, 9,
	4, 9, 5, 2, 4, 11, 6, 2, 10, 8, 6, 7, 9, 8, 1,
]

var verts: PackedVector3Array = PackedVector3Array()
var normals: PackedVector3Array = PackedVector3Array()
var colors: PackedColorArray = PackedColorArray()
var soften: float = 0.0  ## leans every normal towards straight up; foliage shades more gently that way


## One triangle whose front faces away from `inside`.
func tri(a: Vector3, b: Vector3, c: Vector3, inside: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	var n: Vector3 = (b - a).cross(c - a)
	if n.length_squared() < 0.0000000001:
		return
	n = n.normalized()
	var outward: Vector3 = (a + b + c) / 3.0 - inside
	if n.dot(outward) < 0.0:
		n = -n
		var swap_v: Vector3 = b
		b = c
		c = swap_v
		var swap_c: Color = cb
		cb = cc
		cc = swap_c
	if soften > 0.0:
		n = (n + Vector3.UP * soften).normalized()
	# (a, b, c) now runs counter-clockwise seen from outside; front faces are
	# clockwise, so it is stored as (a, c, b).
	verts.append(a)
	verts.append(c)
	verts.append(b)
	normals.append(n)
	normals.append(n)
	normals.append(n)
	colors.append(ca)
	colors.append(cc)
	colors.append(cb)


## A flat quad a-b-c-d (in order around its edge) in one colour.
func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, inside: Vector3, col: Color) -> void:
	tri(a, b, c, inside, col, col, col)
	tri(a, c, d, inside, col, col, col)


## A quad whose colour runs from `low` on edge a-b to `high` on edge d-c.
func quad_grad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, inside: Vector3, low: Color, high: Color) -> void:
	tri(a, b, c, inside, low, low, high)
	tri(a, c, d, inside, low, high, high)


## An upright cone (or a frustum when `top_radius` > 0) around the y axis.
## `lean` moves the top sideways, for branches and bent trunks.
func cone(base: Vector3, radius: float, top_radius: float, height: float, sides: int, low: Color, high: Color, turn: float = 0.0, lean: Vector3 = Vector3.ZERO) -> void:
	var inside: Vector3 = base + Vector3(0.0, height * 0.4, 0.0) + lean * 0.4
	var top: Vector3 = base + Vector3(0.0, height, 0.0) + lean
	for i: int in sides:
		var a0: float = turn + TAU * float(i) / float(sides)
		var a1: float = turn + TAU * float(i + 1) / float(sides)
		var d0: Vector3 = Vector3(cos(a0), 0.0, sin(a0))
		var d1: Vector3 = Vector3(cos(a1), 0.0, sin(a1))
		var b0: Vector3 = base + d0 * radius
		var b1: Vector3 = base + d1 * radius
		if top_radius <= 0.0:
			tri(b0, b1, top, inside, low, low, high)
		else:
			quad_grad(b0, b1, top + d1 * top_radius, top + d0 * top_radius, inside, low, high)


## A lumpy ball built on an icosahedron: `detail` 0 has 20 faces, 1 has 80.
## Each corner is pushed in or out by up to `jitter`; colour runs from `low`
## at the bottom to `high` at the top.
func blob(center: Vector3, radii: Vector3, detail: int, jitter: float, low: Color, high: Color, rng: SimRng) -> void:
	var pts: Array[Vector3] = []
	for v: Vector3 in ICO_VERTS:
		pts.append(v.normalized())
	var faces: PackedInt32Array = ICO_FACES.duplicate()
	if detail > 0:
		var cache: Dictionary[int, int] = {}
		var finer: PackedInt32Array = PackedInt32Array()
		for f: int in range(0, faces.size(), 3):
			var a: int = faces[f]
			var b: int = faces[f + 1]
			var c: int = faces[f + 2]
			var ab: int = _midpoint(pts, cache, a, b)
			var bc: int = _midpoint(pts, cache, b, c)
			var ca: int = _midpoint(pts, cache, c, a)
			finer.append_array(PackedInt32Array([a, ab, ca, b, bc, ab, c, ca, bc, ab, bc, ca]))
		faces = finer
	var placed: PackedVector3Array = PackedVector3Array()
	var tints: PackedColorArray = PackedColorArray()
	for p: Vector3 in pts:
		var k: float = 1.0 + rng.range_f(-jitter, jitter)
		placed.append(center + Vector3(p.x * radii.x, p.y * radii.y, p.z * radii.z) * k)
		tints.append(low.lerp(high, clampf(p.y * 0.6 + 0.5 + rng.range_f(-0.08, 0.08), 0.0, 1.0)))
	for f: int in range(0, faces.size(), 3):
		tri(placed[faces[f]], placed[faces[f + 1]], placed[faces[f + 2]], center, tints[faces[f]], tints[faces[f + 1]], tints[faces[f + 2]])


static func _midpoint(pts: Array[Vector3], cache: Dictionary[int, int], a: int, b: int) -> int:
	var key: int = mini(a, b) * 4096 + maxi(a, b)
	if cache.has(key):
		return cache[key]
	pts.append(((pts[a] + pts[b]) * 0.5).normalized())
	cache[key] = pts.size() - 1
	return pts.size() - 1


func is_empty() -> bool:
	return verts.is_empty()


func commit() -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
