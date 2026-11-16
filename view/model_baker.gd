class_name ModelBaker
extends RefCounted
## Turns a model assembled from primitive-mesh nodes into a handful of merged
## meshes: one for everything rigid and one more for each moving group
## (turret, rotors, spinning dishes). Colour, metal, roughness and glow travel
## in the vertices, so a whole unit draws with one shared material instead of
## one draw call per box. Along the way boxes get chamfered, lightly worn
## edges and everything is shaded a little darker towards the ground.

const SHADER: String = """
shader_type spatial;

void fragment() {
	// Vertex colours reach the shader already converted to linear light.
	vec3 c = COLOR.rgb;
	// Alpha is the glow. A part that glows strongly takes little sunlight on
	// top, so lamps and furnace mouths keep their colour instead of burning
	// out to white.
	float glow = COLOR.a * 3.0;
	ALBEDO = c * clamp(1.0 - glow * 0.6, 0.1, 1.0);
	METALLIC = UV.x;
	ROUGHNESS = UV.y;
	EMISSION = c * glow;
}
"""
const EMISSION_SCALE: float = 3.0  ## vertex alpha 1.0 means this much emission energy
const KEEP: StringName = &"keep"  ## meta flag on nodes that must stay separate (they move)
const EDGE_LIGHTEN: float = 1.22
const GROUND_SHADE: float = 0.66  ## brightness right at ground level
const GROUND_REACH: float = 0.6  ## height at which the ground shading has faded out


## One rigid piece of a baked model and the moving pieces attached to it.
class Part extends RefCounted:
	var name: String = ""
	var xform: Transform3D = Transform3D.IDENTITY
	var mesh: ArrayMesh = null
	var parts: Array[Part] = []


class Buf extends RefCounted:
	var verts: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()


static var _material: ShaderMaterial = null
static var _boxes: Dictionary[String, MeshBuf] = {}


static func material() -> ShaderMaterial:
	if _material == null:
		var shader: Shader = Shader.new()
		shader.code = SHADER
		_material = ShaderMaterial.new()
		_material.shader = shader
	return _material


## Marks a node as a moving group: it survives baking as a node of its own.
static func keep(node: Node3D) -> void:
	node.set_meta(KEEP, true)


## Bakes the tree under `root`. `lift` is how far above the ground the root's
## origin sits, for the ground shading.
static func bake(root: Node3D, lift: float = 0.0) -> Part:
	var part: Part = Part.new()
	part.name = root.name
	part.xform = root.transform
	var buf: Buf = Buf.new()
	_collect(root, Transform3D.IDENTITY, buf, part, lift)
	if not buf.verts.is_empty():
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = buf.verts
		arrays[Mesh.ARRAY_NORMAL] = buf.normals
		arrays[Mesh.ARRAY_COLOR] = buf.colors
		arrays[Mesh.ARRAY_TEX_UV] = buf.uvs
		arrays[Mesh.ARRAY_INDEX] = buf.indices
		part.mesh = ArrayMesh.new()
		part.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		part.mesh.surface_set_material(0, material())
	return part


## Builds the node tree for a baked model: each part is a Node3D holding a
## "Body" mesh, with its moving groups as named children.
static func instantiate(part: Part) -> Node3D:
	var node: Node3D = Node3D.new()
	node.name = part.name
	node.transform = part.xform
	if part.mesh != null:
		var body: MeshInstance3D = MeshInstance3D.new()
		body.name = "Body"
		body.mesh = part.mesh
		node.add_child(body)
	for sub: Part in part.parts:
		node.add_child(instantiate(sub))
	return node


static func _collect(node: Node3D, xf: Transform3D, buf: Buf, part: Part, lift: float) -> void:
	for child: Node in node.get_children():
		var n3: Node3D = child as Node3D
		if n3 == null:
			continue
		var child_xf: Transform3D = xf * n3.transform
		if n3.has_meta(KEEP):
			var sub: Part = bake(n3, lift + child_xf.origin.y)
			sub.xform = child_xf
			part.parts.append(sub)
			continue
		var mi: MeshInstance3D = n3 as MeshInstance3D
		if mi != null and mi.mesh != null:
			_append(mi, child_xf, buf, lift)
		_collect(n3, child_xf, buf, part, lift)


static func _append(mi: MeshInstance3D, xf: Transform3D, buf: Buf, lift: float) -> void:
	var col: Color = Color(0.5, 0.5, 0.5)
	var uv: Vector2 = Vector2(0.0, 0.85)
	var glow: float = 0.0
	var m: StandardMaterial3D = mi.material_override as StandardMaterial3D
	if m != null:
		col = m.albedo_color
		uv = Vector2(m.metallic, m.roughness)
		if m.emission_enabled:
			glow = clampf(m.emission_energy_multiplier / EMISSION_SCALE, 0.0, 1.0)
	col.a = glow
	var box_mesh: BoxMesh = mi.mesh as BoxMesh
	if box_mesh != null:
		var shape: MeshBuf = _box(box_mesh.size)
		var no_index: Variant = null
		_append_arrays(buf, shape.verts, shape.normals, shape.colors, no_index, xf, col, uv, lift)
		return
	var arrays: Array = []
	var prim: PrimitiveMesh = mi.mesh as PrimitiveMesh
	if prim != null:
		arrays = prim.get_mesh_arrays()
	else:
		arrays = mi.mesh.surface_get_arrays(0)
	var no_shades: PackedColorArray = PackedColorArray()
	_append_arrays(buf, arrays[Mesh.ARRAY_VERTEX], arrays[Mesh.ARRAY_NORMAL], no_shades, arrays[Mesh.ARRAY_INDEX], xf, col, uv, lift)


static func _append_arrays(buf: Buf, verts: PackedVector3Array, normals: PackedVector3Array, shades: PackedColorArray, index: Variant, xf: Transform3D, col: Color, uv: Vector2, lift: float) -> void:
	var base: int = buf.verts.size()
	var normal_basis: Basis = xf.basis.inverse().transposed()
	var glowing: bool = col.a > 0.0
	for i: int in verts.size():
		var p: Vector3 = xf * verts[i]
		buf.verts.append(p)
		buf.normals.append((normal_basis * normals[i]).normalized())
		var k: float = 1.0
		if not shades.is_empty():
			k = shades[i].r
		if not glowing:
			# Darker towards the ground: cheap, baked-in contact shading.
			k *= lerpf(GROUND_SHADE, 1.0, smoothstep(0.0, GROUND_REACH, p.y + lift))
		buf.colors.append(Color(minf(col.r * k, 1.0), minf(col.g * k, 1.0), minf(col.b * k, 1.0), col.a))
		buf.uvs.append(uv)
	if index == null:
		for i: int in verts.size():
			buf.indices.append(base + i)
	else:
		var list: PackedInt32Array = index
		for i: int in list:
			buf.indices.append(base + i)


## A box with chamfered edges, flat-shaded. The colour of each vertex is a
## brightness factor: 1 on the faces, lighter on the chamfers, which reads as
## worn edges catching the light.
static func _box(size: Vector3) -> MeshBuf:
	var key: String = str(size)
	if _boxes.has(key):
		return _boxes[key]
	var mb: MeshBuf = MeshBuf.new()
	var h: Vector3 = size * 0.5
	var smallest: float = minf(size.x, minf(size.y, size.z))
	var b: float = clampf(smallest * 0.14, 0.0, 0.11)
	if smallest < 0.05:
		b = 0.0
	var face: Color = Color.WHITE
	var edge: Color = Color(EDGE_LIGHTEN, EDGE_LIGHTEN, EDGE_LIGHTEN)
	var mid: Vector3 = Vector3.ZERO
	# Three points near each corner, one on each face that meets there.
	var px: Array[Vector3] = []
	var py: Array[Vector3] = []
	var pz: Array[Vector3] = []
	for c: int in 8:
		var s: Vector3 = Vector3(1.0 if c & 1 else -1.0, 1.0 if c & 2 else -1.0, 1.0 if c & 4 else -1.0)
		px.append(Vector3(s.x * h.x, s.y * (h.y - b), s.z * (h.z - b)))
		py.append(Vector3(s.x * (h.x - b), s.y * h.y, s.z * (h.z - b)))
		pz.append(Vector3(s.x * (h.x - b), s.y * (h.y - b), s.z * h.z))
	# Faces: corners sharing a sign on one axis, walked around the face.
	for side: int in 2:
		var x0: int = side
		mb.quad(px[x0], px[x0 | 2], px[x0 | 6], px[x0 | 4], mid, face)
		var y0: int = side * 2
		mb.quad(py[y0], py[y0 | 1], py[y0 | 5], py[y0 | 4], mid, face)
		var z0: int = side * 4
		mb.quad(pz[z0], pz[z0 | 1], pz[z0 | 3], pz[z0 | 2], mid, face)
	if b > 0.0:
		for c: int in 8:
			# One chamfer per edge: from each corner towards the corner with the
			# next bit set, so every edge is made exactly once.
			if not (c & 1):
				mb.quad(py[c], py[c | 1], pz[c | 1], pz[c], mid, edge)
			if not (c & 2):
				mb.quad(px[c], px[c | 2], pz[c | 2], pz[c], mid, edge)
			if not (c & 4):
				mb.quad(px[c], px[c | 4], py[c | 4], py[c], mid, edge)
			mb.tri(px[c], py[c], pz[c], mid, edge, edge, edge)
	_boxes[key] = mb
	return mb
