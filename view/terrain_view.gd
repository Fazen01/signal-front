class_name TerrainView
extends Node3D
## Builds the battlefield visuals from a SimMap: a smooth-shaded ground whose
## grass, forest floor, rock and shore are blended per pixel, water that
## follows the lie of the land, and scattered trees, bushes, boulders and
## grass. All geometry and textures are generated here; nothing is loaded
## from disk.

const CHUNK: int = 24  ## scatter is split into chunks of this many cells so off-screen parts are culled
const NOISE_SIZE: int = 256

const GROUND_SHADER: String = """
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 lush : source_color = vec3(0.26, 0.39, 0.19);
uniform vec3 dry : source_color = vec3(0.40, 0.44, 0.24);
uniform vec3 soil : source_color = vec3(0.38, 0.33, 0.24);
uniform vec3 litter_dark : source_color = vec3(0.13, 0.21, 0.10);
uniform vec3 litter_light : source_color = vec3(0.26, 0.25, 0.14);
uniform vec3 stone_dark : source_color = vec3(0.27, 0.27, 0.28);
uniform vec3 stone_light : source_color = vec3(0.47, 0.46, 0.45);
uniform vec3 sand_dark : source_color = vec3(0.55, 0.49, 0.35);
uniform vec3 sand_light : source_color = vec3(0.72, 0.66, 0.49);
uniform vec3 bed : source_color = vec3(0.22, 0.27, 0.24);
varying vec3 wpos;
varying float up;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	up = NORMAL.y;
}

void fragment() {
	vec2 p = wpos.xz;
	vec3 big = texture(noise_tex, p * 0.0065).rgb;
	vec3 mid = texture(noise_tex, p * 0.031 + vec2(0.37, 0.11)).rgb;
	vec3 fine = texture(noise_tex, p * 0.17).rgb;
	float grit = texture(noise_tex, p * 0.83).g;
	// The terrain weights arrive blended across a whole cell; noise pushes
	// the borders about so they do not follow the grid.
	float wob = (fine.r - 0.5) * 0.5 + (mid.g - 0.5) * 0.3;

	vec3 grass = mix(lush, dry, smoothstep(0.32, 0.68, big.r * 0.65 + mid.r * 0.35));
	float bare = smoothstep(0.50, 0.80, mid.b * 0.45 + fine.g * 0.55);
	grass = mix(grass, soil, bare * 0.5);
	vec3 litter = mix(litter_dark, litter_light, fine.b);
	vec3 stone = mix(stone_dark, stone_light, fine.g);
	stone *= 0.94 + 0.08 * sin(wpos.y * 7.0 + mid.r * 9.0);
	vec3 sand = mix(sand_dark, sand_light, fine.r);

	float forest = smoothstep(0.30, 0.56, COLOR.r + wob);
	float rock = smoothstep(0.22, 0.46, COLOR.g + wob * 0.8);
	float shore = smoothstep(0.10, 0.30, COLOR.b + wob * 0.25);
	float under = smoothstep(0.36, 0.64, COLOR.b);

	vec3 col = mix(grass, litter, forest);
	col = mix(col, sand, shore);
	col = mix(col, bed, under);
	col = mix(col, stone, rock);
	float steep = smoothstep(0.90, 0.72, up) * (1.0 - under);
	col = mix(col, stone * 0.8, steep);
	col *= 0.90 + 0.20 * grit;
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.12;
}
"""

const WATER_SHADER: String = """
shader_type spatial;
render_mode blend_mix, cull_disabled;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 shallow : source_color = vec3(0.25, 0.55, 0.58);
uniform vec3 deep : source_color = vec3(0.06, 0.22, 0.38);
uniform vec3 foam_color : source_color = vec3(0.86, 0.93, 0.92);
varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// UV.x carries the water depth at this point; negative is dry land.
	float depth = UV.x;
	if (depth < 0.0) {
		discard;
	}
	vec2 p = wpos.xz;
	vec3 n1 = texture(noise_tex, p * 0.045 + TIME * vec2(0.011, 0.006)).rgb;
	vec3 n2 = texture(noise_tex, p * 0.083 - TIME * vec2(0.008, 0.012)).rgb;
	float d = clamp(depth / 0.8, 0.0, 1.0);
	vec3 col = mix(shallow, deep, d);
	float glint = smoothstep(0.56, 0.70, n1.r * 0.5 + n2.g * 0.5);
	col += glint * 0.09;
	float edge = 1.0 - smoothstep(0.0, 0.06 + 0.06 * n2.b, depth);
	float band = smoothstep(0.72, 1.0, sin(depth * 24.0 - TIME * 1.2 + n1.g * 5.0)) * (1.0 - smoothstep(0.10, 0.42, depth));
	float foam = clamp(edge + band * 0.4, 0.0, 1.0);
	ALBEDO = mix(col, foam_color, foam);
	ALPHA = mix(mix(0.55, 0.92, d), 0.95, foam);
	ROUGHNESS = 0.12;
	SPECULAR = 0.7;
	vec3 nw = normalize(vec3((n1.r + n2.g - 1.0) * 0.45, 1.0, (n1.b + n2.r - 1.0) * 0.45));
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
}
"""

## Trees, rocks and grass: vertex colours, a little wind, and darkening from
## the fog-of-war texture so nothing glows out of unexplored ground.
const PROP_SHADER: String = """
shader_type spatial;
render_mode %s;

uniform sampler2D fog_tex : filter_linear, repeat_disable, hint_default_transparent;
uniform vec2 map_size = vec2(1.0, 1.0);
uniform float sway = 0.0;
uniform float lift = 0.0;
varying float dim;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float fog = textureLod(fog_tex, origin.xz / map_size, 0.0).a;
	dim = clamp(1.0 - fog * 1.08, 0.09, 1.0);
	float k = VERTEX.y * sway;
	VERTEX.x += sin(TIME * 1.3 + origin.x * 0.35 + origin.z * 0.27) * k;
	VERTEX.z += cos(TIME * 1.1 + origin.x * 0.21 - origin.z * 0.33) * k;
}

void fragment() {
	ALBEDO = pow(COLOR.rgb, vec3(2.2)) * dim;
	// Leaves let some light through: the shaded side never goes fully dark.
	EMISSION = ALBEDO * lift;
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
}
"""

static var _noise: ImageTexture = null

var map: SimMap = null
var _rng: SimRng = null
var _forest: PackedFloat32Array = PackedFloat32Array()  ## per corner: share of the four cells around it that are forest
var _rock: PackedFloat32Array = PackedFloat32Array()
var _water: PackedFloat32Array = PackedFloat32Array()
var _prop_mats: Array[ShaderMaterial] = []


func build(sim_map: SimMap, seed_value: int) -> void:
	map = sim_map
	_rng = SimRng.new(seed_value + 4711)
	_corner_weights()
	_build_ground()
	_build_water()
	_build_trees()
	_build_rocks()
	_build_grass()
	_build_apron()


## The fog-of-war texture (one texel per cell); scatter standing in fog is
## darkened to match the ground under it.
func set_fog_texture(tex: Texture2D) -> void:
	for m: ShaderMaterial in _prop_mats:
		m.set_shader_parameter("fog_tex", tex)


## Three unrelated tiling noise fields packed into the channels of one texture.
static func noise_texture() -> ImageTexture:
	if _noise != null:
		return _noise
	var chans: Array[PackedByteArray] = []
	for i: int in 3:
		var n: FastNoiseLite = FastNoiseLite.new()
		n.seed = 1301 + i * 77
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.frequency = 0.02
		n.fractal_type = FastNoiseLite.FRACTAL_FBM
		n.fractal_octaves = 4
		var img: Image = n.get_seamless_image(NOISE_SIZE, NOISE_SIZE)
		img.convert(Image.FORMAT_L8)
		chans.append(img.get_data())
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(NOISE_SIZE * NOISE_SIZE * 3)
	for p: int in NOISE_SIZE * NOISE_SIZE:
		bytes[p * 3] = chans[0][p]
		bytes[p * 3 + 1] = chans[1][p]
		bytes[p * 3 + 2] = chans[2][p]
	var packed: Image = Image.create_from_data(NOISE_SIZE, NOISE_SIZE, false, Image.FORMAT_RGB8, bytes)
	packed.generate_mipmaps()
	_noise = ImageTexture.create_from_image(packed)
	return _noise


func _corner_weights() -> void:
	var row: int = map.w + 1
	var n: int = row * (map.h + 1)
	_forest.resize(n)
	_rock.resize(n)
	_water.resize(n)
	for y: int in range(0, map.h + 1):
		for x: int in range(0, map.w + 1):
			var f: float = 0.0
			var r: float = 0.0
			var wt: float = 0.0
			for cy: int in [y - 1, y]:
				for cx: int in [x - 1, x]:
					match map.terrain_cell(Vector2i(clampi(cx, 0, map.w - 1), clampi(cy, 0, map.h - 1))):
						SimMap.Terrain.FOREST:
							f += 0.25
						SimMap.Terrain.ROCK:
							r += 0.25
						SimMap.Terrain.WATER:
							wt += 0.25
			var i: int = y * row + x
			_forest[i] = f
			_rock[i] = r
			_water[i] = wt


func _corner(x: int, y: int) -> Vector3:
	return Vector3(float(x) * SimMap.CELL, map.heights[y * (map.w + 1) + x], float(y) * SimMap.CELL)


func _height(x: int, y: int) -> float:
	return map.heights[clampi(y, 0, map.h) * (map.w + 1) + clampi(x, 0, map.w)]


func _build_ground() -> void:
	var row: int = map.w + 1
	var verts: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	var indices: PackedInt32Array = PackedInt32Array()
	for y: int in range(0, map.h + 1):
		for x: int in range(0, map.w + 1):
			var i: int = y * row + x
			verts.append(_corner(x, y))
			normals.append(Vector3(_height(x - 1, y) - _height(x + 1, y), 2.0 * SimMap.CELL, _height(x, y - 1) - _height(x, y + 1)).normalized())
			colors.append(Color(_forest[i], _rock[i], _water[i], 1.0))
	for y: int in map.h:
		for x: int in map.w:
			var i: int = y * row + x
			indices.append_array(PackedInt32Array([i, i + 1, i + row + 1, i, i + row + 1, i + row]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var shader: Shader = Shader.new()
	shader.code = GROUND_SHADER
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("noise_tex", noise_texture())
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Ground"
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## Where the ground would be if no water had been sunk into it: the height
## of dry corners carried inwards across the water, then smoothed. The water
## surface sits a little below this, so rivers follow the lie of the land
## instead of vanishing on high ground.
func _land_level() -> PackedFloat32Array:
	var row: int = map.w + 1
	var n: int = row * (map.h + 1)
	var level: PackedFloat32Array = map.heights.duplicate()
	var known: PackedByteArray = PackedByteArray()
	known.resize(n)
	var wet: PackedInt32Array = PackedInt32Array()
	for i: int in n:
		if _water[i] > 0.0:
			wet.append(i)
		else:
			known[i] = 1
	var todo: PackedInt32Array = wet
	while not todo.is_empty():
		var later: PackedInt32Array = PackedInt32Array()
		var found: PackedInt32Array = PackedInt32Array()
		var values: PackedFloat32Array = PackedFloat32Array()
		for i: int in todo:
			var x: int = i % row
			var y: int = i / row
			var sum: float = 0.0
			var count: int = 0
			if x > 0 and known[i - 1] != 0:
				sum += level[i - 1]
				count += 1
			if x < map.w and known[i + 1] != 0:
				sum += level[i + 1]
				count += 1
			if y > 0 and known[i - row] != 0:
				sum += level[i - row]
				count += 1
			if y < map.h and known[i + row] != 0:
				sum += level[i + row]
				count += 1
			if count > 0:
				found.append(i)
				values.append(sum / float(count))
			else:
				later.append(i)
		if found.is_empty():
			# A map that is all water: nothing to carry in.
			for i: int in later:
				level[i] = 0.0
			break
		for k: int in found.size():
			level[found[k]] = values[k]
			known[found[k]] = 1
		todo = later
	for pass_index: int in 3:
		var smooth: PackedFloat32Array = level.duplicate()
		for i: int in wet:
			var x: int = i % row
			var y: int = i / row
			var sum: float = level[i]
			var count: int = 1
			if x > 0:
				sum += level[i - 1]
				count += 1
			if x < map.w:
				sum += level[i + 1]
				count += 1
			if y > 0:
				sum += level[i - row]
				count += 1
			if y < map.h:
				sum += level[i + row]
				count += 1
			smooth[i] = sum / float(count)
		level = smooth
	return level


func _build_water() -> void:
	var row: int = map.w + 1
	var level: PackedFloat32Array = _land_level()
	# How far a half-water corner has been sunk decides how far below the
	# land the surface sits, so every water cell ends up wet.
	var dip: float = 0.0
	var dips: int = 0
	for i: int in level.size():
		if is_equal_approx(_water[i], 0.5):
			dip += level[i] - map.heights[i]
			dips += 1
	var drop: float = 0.45
	if dips > 0:
		drop = clampf(dip / float(dips) * 0.7, 0.2, 0.9)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any: bool = false
	for y: int in map.h:
		for x: int in map.w:
			var i: int = y * row + x
			if _water[i] + _water[i + 1] + _water[i + row] + _water[i + row + 1] <= 0.0:
				continue
			any = true
			for corner: int in [i, i + 1, i + row + 1, i, i + row + 1, i + row]:
				var surface: float = level[corner] - drop
				st.set_uv(Vector2(surface - map.heights[corner], 0.0))
				st.set_normal(Vector3.UP)
				st.add_vertex(Vector3(float(corner % row) * SimMap.CELL, surface, float(corner / row) * SimMap.CELL))
	if not any:
		return
	var shader: Shader = Shader.new()
	shader.code = WATER_SHADER
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("noise_tex", noise_texture())
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Water"
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## Dark ground sloping away from the map edge, so the battlefield does not
## end in a floating slab.
func _build_apron() -> void:
	var buf: MeshBuf = MeshBuf.new()
	var near: Color = Color(0.10, 0.11, 0.09)
	var far: Color = Color(0.03, 0.04, 0.05)
	var reach: float = 14.0
	var floor_y: float = -2.6
	var below: Vector3 = Vector3(map.world_size().x * 0.5, -40.0, map.world_size().y * 0.5)
	for x: int in map.w:
		var a: Vector3 = _corner(x, 0)
		var b: Vector3 = _corner(x + 1, 0)
		buf.quad_grad(a, b, Vector3(b.x, floor_y, -reach), Vector3(a.x, floor_y, -reach), below, near, far)
		a = _corner(x, map.h)
		b = _corner(x + 1, map.h)
		buf.quad_grad(a, b, Vector3(b.x, floor_y, b.z + reach), Vector3(a.x, floor_y, a.z + reach), below, near, far)
	for y: int in map.h:
		var a: Vector3 = _corner(0, y)
		var b: Vector3 = _corner(0, y + 1)
		buf.quad_grad(a, b, Vector3(-reach, floor_y, b.z), Vector3(-reach, floor_y, a.z), below, near, far)
		a = _corner(map.w, y)
		b = _corner(map.w, y + 1)
		buf.quad_grad(a, b, Vector3(b.x + reach, floor_y, b.z), Vector3(a.x + reach, floor_y, a.z), below, near, far)
	var slope_mat: StandardMaterial3D = StandardMaterial3D.new()
	slope_mat.vertex_color_use_as_albedo = true
	slope_mat.vertex_color_is_srgb = true
	slope_mat.roughness = 1.0
	slope_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var slope: MeshInstance3D = MeshInstance3D.new()
	slope.name = "Apron"
	slope.mesh = buf.commit()
	slope.material_override = slope_mat
	slope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(slope)
	var size: Vector2 = map.world_size()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = size * 4.0
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = far
	mat.roughness = 1.0
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Skirt"
	mi.mesh = plane
	mi.material_override = mat
	mi.position = Vector3(size.x * 0.5, floor_y - 0.05, size.y * 0.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# ------------------------------------------------------------ scatter

func _prop_material(sway: float, two_sided: bool, lift: float = 0.0) -> ShaderMaterial:
	var shader: Shader = Shader.new()
	shader.code = PROP_SHADER % ("cull_disabled" if two_sided else "cull_back")
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("map_size", map.world_size())
	mat.set_shader_parameter("sway", sway)
	mat.set_shader_parameter("lift", lift)
	_prop_mats.append(mat)
	return mat


func _spot(x: int, y: int, margin: float, scale_min: float, scale_max: float, stretch: float, sink: float) -> Transform3D:
	var p: Vector2 = Vector2(
		(float(x) + _rng.range_f(margin, 1.0 - margin)) * SimMap.CELL,
		(float(y) + _rng.range_f(margin, 1.0 - margin)) * SimMap.CELL
	)
	var s: float = _rng.range_f(scale_min, scale_max)
	var xf: Basis = Basis(Vector3.UP, _rng.range_f(0.0, TAU)).scaled(Vector3(s, s * _rng.range_f(1.0 - stretch, 1.0 + stretch), s))
	return Transform3D(xf, Vector3(p.x, map.height_at(p) - sink, p.y))


func _conifer(tiers: int, girth: float) -> ArrayMesh:
	var buf: MeshBuf = MeshBuf.new()
	buf.cone(Vector3.ZERO, 0.13, 0.08, 0.95, 5, Color(0.26, 0.19, 0.14), Color(0.42, 0.31, 0.21))
	buf.soften = 0.9
	var y: float = 0.55
	for t: int in tiers:
		var k: float = 1.0 - float(t) / float(tiers + 1)
		var lift: float = 0.10 * float(t)
		buf.cone(Vector3(0.0, y, 0.0), 0.80 * k * girth, 0.0, 1.25 * (0.75 + 0.25 * k), 7, Color(0.19 + lift * 0.2, 0.35 + lift * 0.3, 0.22), Color(0.33 + lift * 0.3, 0.54 + lift * 0.4, 0.31), float(t) * 0.5)
		y += 0.62 * (0.8 + 0.2 * k)
	return buf.commit()


func _broadleaf(shape_seed: int) -> ArrayMesh:
	var rng: SimRng = SimRng.new(shape_seed)
	var buf: MeshBuf = MeshBuf.new()
	buf.cone(Vector3.ZERO, 0.16, 0.10, 1.25, 5, Color(0.27, 0.20, 0.15), Color(0.44, 0.33, 0.22))
	buf.soften = 0.9
	var low: Color = Color(0.19, 0.36, 0.14)
	var high: Color = Color(0.43, 0.60, 0.25)
	buf.blob(Vector3(0.0, 1.85, 0.0), Vector3(0.92, 0.72, 0.92), 1, 0.16, low, high, rng)
	buf.blob(Vector3(0.55, 1.5, 0.25), Vector3(0.55, 0.45, 0.55), 0, 0.14, low, high, rng)
	buf.blob(Vector3(-0.5, 1.6, -0.3), Vector3(0.6, 0.48, 0.6), 0, 0.14, low, high, rng)
	buf.blob(Vector3(-0.1, 1.45, 0.6), Vector3(0.5, 0.42, 0.5), 0, 0.14, low, high, rng)
	return buf.commit()


func _bush(shape_seed: int) -> ArrayMesh:
	var rng: SimRng = SimRng.new(shape_seed)
	var buf: MeshBuf = MeshBuf.new()
	buf.soften = 0.9
	var low: Color = Color(0.18, 0.34, 0.14)
	var high: Color = Color(0.40, 0.56, 0.24)
	buf.blob(Vector3(0.0, 0.28, 0.0), Vector3(0.5, 0.36, 0.5), 0, 0.2, low, high, rng)
	buf.blob(Vector3(0.38, 0.2, 0.15), Vector3(0.32, 0.26, 0.32), 0, 0.2, low, high, rng)
	buf.blob(Vector3(-0.3, 0.22, -0.25), Vector3(0.36, 0.28, 0.36), 0, 0.2, low, high, rng)
	return buf.commit()


func _boulder(shape_seed: int, detail: int) -> ArrayMesh:
	var rng: SimRng = SimRng.new(shape_seed)
	var buf: MeshBuf = MeshBuf.new()
	buf.blob(Vector3(0.0, 0.35, 0.0), Vector3(1.0, 0.72, 0.86), detail, 0.24, Color(0.30, 0.31, 0.33), Color(0.66, 0.66, 0.65), rng)
	return buf.commit()


func _tuft() -> ArrayMesh:
	var buf: MeshBuf = MeshBuf.new()
	# Lit like the ground it stands on, whichever way a blade happens to face.
	buf.soften = 50.0
	var low: Color = Color(0.36, 0.50, 0.24)
	var high: Color = Color(0.62, 0.72, 0.36)
	var above: Vector3 = Vector3(0.0, -5.0, 0.0)
	for i: int in 5:
		var ang: float = float(i) * 1.257 + 0.3
		var out: Vector3 = Vector3(cos(ang), 0.0, sin(ang))
		var side: Vector3 = Vector3(-out.z, 0.0, out.x)
		var foot: Vector3 = out * 0.04
		var tip: Vector3 = out * (0.11 + 0.03 * float(i % 3)) + Vector3(0.0, 0.17 + 0.04 * float(i % 2), 0.0)
		buf.tri(foot - side * 0.035, foot + side * 0.035, tip, above, low, low, high)
	return buf.commit()


func _is(x: int, y: int, t: int) -> bool:
	if x < 0 or y < 0 or x >= map.w or y >= map.h:
		return false
	return map.terrain_cell(Vector2i(x, y)) == t


func _build_trees() -> void:
	var s1: float = _rng.range_f(0.0, TAU)
	var s2: float = _rng.range_f(0.0, TAU)
	var kinds: Array[Array] = [[], [], [], [], []]  # conifer, tall conifer, broadleaf, broadleaf 2, bush
	var tints: Array[PackedColorArray] = [PackedColorArray(), PackedColorArray(), PackedColorArray(), PackedColorArray(), PackedColorArray()]
	for y: int in map.h:
		for x: int in map.w:
			var t: int = map.terrain_cell(Vector2i(x, y))
			if t == SimMap.Terrain.FOREST:
				# Groves lean towards one kind of tree.
				var grove: float = sin(float(x) * 0.19 + s1) + cos(float(y) * 0.23 + s2) + sin(float(x + y) * 0.11)
				var count: int = _rng.range_i(2, 3)
				for i: int in count:
					var leafy: bool = _rng.chance(0.8 if grove > 0.25 else 0.12)
					var k: int = (2 + _rng.range_i(0, 1)) if leafy else _rng.range_i(0, 1)
					kinds[k].append(_spot(x, y, 0.1, 0.78, 1.32, 0.16, 0.0))
					var shade: float = _rng.range_f(0.78, 1.0)
					tints[k].append(Color(shade * _rng.range_f(0.86, 1.0), shade, shade * _rng.range_f(0.8, 1.0)))
				if _rng.chance(0.3):
					kinds[4].append(_spot(x, y, 0.1, 0.7, 1.2, 0.2, 0.0))
					tints[4].append(Color(0.9, 0.95, 0.85) * _rng.range_f(0.8, 1.0))
			elif t == SimMap.Terrain.GROUND:
				# Bushes straggle out of the forest edge; the odd one stands alone.
				var edge: bool = _is(x - 1, y, SimMap.Terrain.FOREST) or _is(x + 1, y, SimMap.Terrain.FOREST) or _is(x, y - 1, SimMap.Terrain.FOREST) or _is(x, y + 1, SimMap.Terrain.FOREST)
				if _rng.chance(0.4 if edge else 0.012):
					kinds[4].append(_spot(x, y, 0.15, 0.6, 1.15, 0.2, 0.0))
					tints[4].append(Color(0.95, 1.0, 0.85) * _rng.range_f(0.8, 1.0))
	var foliage: ShaderMaterial = _prop_material(0.022, false, 0.22)
	var meshes: Array[ArrayMesh] = [_conifer(3, 1.0), _conifer(4, 0.82), _broadleaf(11), _broadleaf(29), _bush(5)]
	var names: Array[String] = ["Conifers", "TallConifers", "Broadleaf", "BroadleafB", "Bushes"]
	for k: int in kinds.size():
		var spots: Array[Transform3D] = []
		spots.assign(kinds[k])
		_add_scatter(names[k], meshes[k], foliage, spots, tints[k], true)


func _build_rocks() -> void:
	var big: Array[Array] = [[], [], []]
	var big_tints: Array[PackedColorArray] = [PackedColorArray(), PackedColorArray(), PackedColorArray()]
	var small: Array[Transform3D] = []
	var small_tints: PackedColorArray = PackedColorArray()
	for y: int in map.h:
		for x: int in map.w:
			var t: int = map.terrain_cell(Vector2i(x, y))
			if t == SimMap.Terrain.ROCK:
				if _rng.chance(0.62):
					var k: int = _rng.range_i(0, 2)
					var xf: Transform3D = _spot(x, y, 0.22, 0.8, 1.7, 0.3, 0.1)
					xf.basis = Basis.from_euler(Vector3(_rng.range_f(-0.25, 0.25), 0.0, _rng.range_f(-0.25, 0.25))) * xf.basis
					big[k].append(xf)
					big_tints[k].append(Color.WHITE * _rng.range_f(0.78, 1.0))
				for i: int in _rng.range_i(0, 2):
					small.append(_spot(x, y, 0.05, 0.22, 0.5, 0.3, 0.05))
					small_tints.append(Color.WHITE * _rng.range_f(0.7, 1.0))
			elif t == SimMap.Terrain.GROUND and _rng.chance(0.03):
				# Loose stones out on the grass.
				for i: int in _rng.range_i(1, 3):
					small.append(_spot(x, y, 0.1, 0.12, 0.3, 0.3, 0.04))
					small_tints.append(Color.WHITE * _rng.range_f(0.7, 1.0))
	var stone: ShaderMaterial = _prop_material(0.0, false)
	for k: int in big.size():
		var spots: Array[Transform3D] = []
		spots.assign(big[k])
		_add_scatter("Boulders%d" % k, _boulder(101 + k * 37, 1), stone, spots, big_tints[k], true)
	_add_scatter("Stones", _boulder(977, 0), stone, small, small_tints, false)


func _build_grass() -> void:
	var s1: float = _rng.range_f(0.0, TAU)
	var s2: float = _rng.range_f(0.0, TAU)
	var spots: Array[Transform3D] = []
	var tints: PackedColorArray = PackedColorArray()
	for y: int in map.h:
		for x: int in map.w:
			if map.terrain_cell(Vector2i(x, y)) != SimMap.Terrain.GROUND:
				continue
			# Grass grows in drifts rather than evenly.
			var drift: float = sin(float(x) * 0.31 + s1) * cos(float(y) * 0.27 + s2) + 0.4 * sin(float(x - y) * 0.13)
			if not _rng.chance(clampf(0.22 + drift * 0.3, 0.04, 0.6)):
				continue
			for i: int in _rng.range_i(1, 3):
				spots.append(_spot(x, y, 0.05, 0.8, 1.5, 0.25, 0.0))
				tints.append(Color(_rng.range_f(0.85, 1.0), 1.0, _rng.range_f(0.75, 1.0)) * _rng.range_f(0.82, 1.0))
	_add_scatter("Grass", _tuft(), _prop_material(0.12, true), spots, tints, false)


## Adds one MultiMesh per map chunk so scatter outside the view is culled.
func _add_scatter(node_name: String, mesh: Mesh, mat: Material, spots: Array[Transform3D], tints: PackedColorArray, shadows: bool) -> void:
	if spots.is_empty():
		return
	var chunks: Dictionary[int, Array] = {}
	for i: int in spots.size():
		var c: Vector2i = map.cell_of(Vector2(spots[i].origin.x, spots[i].origin.z))
		var key: int = (clampi(c.y, 0, map.h - 1) / CHUNK) * 1024 + clampi(c.x, 0, map.w - 1) / CHUNK
		if not chunks.has(key):
			chunks[key] = []
		chunks[key].append(i)
	for key: int in chunks:
		var members: Array = chunks[key]
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = mesh
		mm.instance_count = members.size()
		for k: int in members.size():
			var i: int = members[k]
			mm.set_instance_transform(k, spots[i])
			mm.set_instance_color(k, tints[i])
		var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
		mmi.name = "%s_%d" % [node_name, key]
		mmi.multimesh = mm
		mmi.material_override = mat
		if not shadows:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
