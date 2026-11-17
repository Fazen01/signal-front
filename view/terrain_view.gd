class_name TerrainView
extends Node3D
## Builds the battlefield visuals from a SimMap: a smooth-shaded ground whose
## grass, forest floor, rock and shore are blended per pixel, water that
## follows the lie of the land, tracks worn along the routes between bases,
## scattered trees, bushes, boulders, grass, flowers and reeds, and a shaded
## border of the same country beyond the playable edge. All geometry and
## textures are generated here; nothing is loaded from disk.

const CHUNK: int = 24  ## scatter is split into chunks of this many cells so off-screen parts are culled
const NOISE_SIZE: int = 256
const BORDER: int = 16  ## cells of dressed, unplayable ground drawn around the map
const MARK_SCALE: int = 2  ## texels per cell in the ground-marks texture

const GROUND_SHADER: String = """
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D mark_tex : filter_linear, repeat_disable, hint_default_black;
uniform sampler2D fog_tex : filter_linear, repeat_disable, hint_default_transparent;
uniform sampler2D high_tex : filter_linear, repeat_disable, hint_default_black;
uniform vec2 map_size = vec2(1.0, 1.0);
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

	// Worn ground: R = vehicle tracks, G = stains under scrap, B = the
	// packed earth of a base. Looked up a little off-position so that tracks
	// wander instead of running ruler-straight.
	vec3 mark = texture(mark_tex, (p + (mid.rg - 0.5) * 3.2 + (fine.rg - 0.5) * 0.5) / map_size).rgb;
	// Terrain weights: UV = (forest, rock), UV2.x = water.
	float forest = smoothstep(0.30, 0.56, UV.x + wob);
	float rock = smoothstep(0.22, 0.46, UV.y + wob * 0.8);
	float shore = smoothstep(0.10, 0.34, UV2.x + wob * 0.25);
	float under = smoothstep(0.40, 0.70, UV2.x);

	vec3 col = mix(grass, litter, forest);
	col = mix(col, sand, shore);
	col = mix(col, bed, under);
	col = mix(col, stone, rock);
	// Steep ground shows what is under the turf: bare stone on the flanks of
	// rock, packed earth on the bank of a hill.
	float steep = smoothstep(0.93, 0.74, up) * (1.0 - under);
	float stony = smoothstep(0.04, 0.30, UV.y);
	vec3 earth = mix(soil * 0.78, soil * 1.08, fine.g) * (0.92 + 0.16 * mid.b);
	col = mix(col, mix(earth, stone * 0.8, stony), steep);
	// High ground: the top of a hill is a little paler and drier than the
	// land below it. The bank itself, lit on one side and shaded on the
	// other, is what shows where the hill is.
	float hi = texture(high_tex, p / map_size).r;
	float top = smoothstep(0.55, 0.9, hi) * (1.0 - under) * (1.0 - rock) * (1.0 - steep);
	col = mix(col, mix(col, dry, 0.35) * 1.12, top);
	float worn = max(smoothstep(0.16, 0.58, mark.r + wob * 0.12), smoothstep(0.25, 0.75, mark.b + wob * 0.35) * 0.8);
	worn *= (1.0 - under) * (1.0 - rock * 0.8);
	vec3 track = soil * mix(0.82, 1.12, fine.b);
	// Twin ruts either side of the middle of a track.
	track *= 1.0 - 0.22 * (1.0 - smoothstep(0.0, 0.07, abs(mark.r - 0.5)));
	col = mix(col, track, worn);
	col *= 1.0 - 0.42 * smoothstep(0.15, 0.8, mark.g + wob * 0.2);
	col *= 0.90 + 0.20 * grit;
	// Fine speckle so the ground still has grain with the camera right down.
	col *= 0.93 + 0.14 * texture(noise_tex, p * 2.3).b;
	// Cloud shadows drifting over the land.
	float cloud = texture(noise_tex, p * 0.0032 + TIME * vec2(0.0042, 0.0023)).g;
	col *= mix(0.78, 1.04, smoothstep(0.38, 0.62, cloud));
	// Ground beyond the edge of the battlefield falls away into shade, and
	// is as dark as the fog of war on the map edge beside it (the fog
	// overlay itself only covers the map).
	if (UV2.y > 0.0) {
		float fog = texture(fog_tex, clamp(p / map_size, vec2(0.0), vec2(1.0))).a;
		col *= (1.0 - UV2.y * 0.88) * clamp(1.0 - fog * 1.08, 0.09, 1.0);
	}
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
uniform float glow = 0.0;
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
	if (glow > 0.0) {
		// Lava: a dark crust broken into slowly drifting plates, glowing in
		// the cracks between them and cooling to black at the shore.
		float plates = texture(noise_tex, p * 0.075 + TIME * vec2(0.0016, 0.0009)).r;
		float small = texture(noise_tex, p * 0.21 - TIME * vec2(0.0022, 0.0013)).g;
		float grain = texture(noise_tex, p * 0.9).b;
		float seam = 1.0 - smoothstep(0.012, 0.075, abs(plates - 0.5) + (small - 0.5) * 0.05);
		float vein = 1.0 - smoothstep(0.006, 0.03, abs(small - 0.5));
		float heat = clamp(seam + vein * 0.45, 0.0, 1.0) * smoothstep(0.03, 0.3, depth);
		vec3 crust = vec3(0.075, 0.06, 0.06) * (0.7 + 0.6 * grain);
		vec3 molten = mix(deep, shallow, heat * heat);
		ALBEDO = mix(crust, molten, heat);
		EMISSION = molten * heat * glow;
		ALPHA = 1.0;
	}
	ROUGHNESS = glow > 0.0 ? 0.9 : 0.12;
	SPECULAR = glow > 0.0 ? 0.1 : 0.7;
	if (glow <= 0.0) {
		vec3 nw = normalize(vec3((n1.r + n2.g - 1.0) * 0.45, 1.0, (n1.b + n2.r - 1.0) * 0.45));
		NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	}
}
"""

## Trees, rocks and grass: vertex colours, a little wind, and darkening from
## the fog-of-war texture so nothing glows out of unexplored ground.
const PROP_SHADER: String = """
shader_type spatial;
render_mode %s;

uniform sampler2D fog_tex : filter_linear, repeat_disable, hint_default_transparent;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec2 map_size = vec2(1.0, 1.0);
uniform float sway = 0.0;
uniform float lift = 0.0;
varying float dim;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float fog = textureLod(fog_tex, origin.xz / map_size, 0.0).a;
	dim = clamp(1.0 - fog * 1.08, 0.09, 1.0);
	// The same drifting cloud shadows as the ground.
	float cloud = textureLod(noise_tex, origin.xz * 0.0032 + TIME * vec2(0.0042, 0.0023), 0.0).g;
	dim *= mix(0.78, 1.04, smoothstep(0.38, 0.62, cloud));
	float k = VERTEX.y * sway;
	VERTEX.x += sin(TIME * 1.3 + origin.x * 0.35 + origin.z * 0.27) * k;
	VERTEX.z += cos(TIME * 1.1 + origin.x * 0.21 - origin.z * 0.33) * k;
}

void fragment() {
	// Vertex colours reach the shader already converted to linear light.
	ALBEDO = COLOR.rgb * dim;
	// Leaves let some light through: the shaded side never goes fully dark.
	EMISSION = ALBEDO * lift;
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
}
"""

static var _noise: ImageTexture = null

var map: SimMap = null
var look: RegionLook = null  ## the palette of the region this map lies in
var _rng: SimRng = null
var _forest: PackedFloat32Array = PackedFloat32Array()  ## per corner: share of the four cells around it that are forest
var _rock: PackedFloat32Array = PackedFloat32Array()
var _water: PackedFloat32Array = PackedFloat32Array()
var _prop_mats: Array[ShaderMaterial] = []
var _marks: PackedByteArray = PackedByteArray()  ## RGB per texel: tracks, stains, clearings
var _mark_w: int = 0
var _mark_h: int = 0
var _mark_tex: ImageTexture = null
var _ground_mat: ShaderMaterial = null


func build(sim_map: SimMap, seed_value: int) -> void:
	map = sim_map
	look = RegionLook.of(map.region)
	_rng = SimRng.new(seed_value + 4711)
	_corner_weights()
	_build_marks()
	_build_ground()
	_build_water()
	_build_trees()
	_build_rocks()
	_build_grass()
	_build_litter()
	_build_apron()


## The fog-of-war texture (one texel per cell); scatter standing in fog is
## darkened to match the ground under it.
func set_fog_texture(tex: Texture2D) -> void:
	for m: ShaderMaterial in _prop_mats:
		m.set_shader_parameter("fog_tex", tex)
	if _ground_mat != null:
		_ground_mat.set_shader_parameter("fog_tex", tex)


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


## Corner height. Past the edge of the map the ground carries on from the
## nearest edge corner and sinks away with distance.
func _height(x: int, y: int) -> float:
	var edge: float = map.heights[clampi(y, 0, map.h) * (map.w + 1) + clampi(x, 0, map.w)]
	var out: float = _outside(x, y)
	if out <= 0.0:
		return edge
	return lerpf(edge, -2.4, out * out)


## 0 on the map, rising to 1 at the far side of the border.
func _outside(x: int, y: int) -> float:
	var d: int = maxi(maxi(-x, x - map.w), maxi(-y, y - map.h))
	return clampf(float(d) / float(BORDER), 0.0, 1.0)


## Ground height at a world position, on the map or in the border.
func _ground_y(p: Vector2) -> float:
	var size: Vector2 = map.world_size()
	if p.x >= 0.0 and p.y >= 0.0 and p.x <= size.x and p.y <= size.y:
		return map.height_at(p)
	return _height(roundi(p.x / SimMap.CELL), roundi(p.y / SimMap.CELL))


## Terrain of a cell; cells in the border take after the nearest map cell.
func _cell_type(x: int, y: int) -> int:
	return map.terrain_cell(Vector2i(clampi(x, 0, map.w - 1), clampi(y, 0, map.h - 1)))


func _in_map(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < map.w and y < map.h


# ------------------------------------------------------------ ground marks

## Paints the texture of worn ground: tracks along the routes vehicles would
## take between the bases, the middle of the map and the uplink sites,
## packed earth where the bases stand, and stains under the salvage fields.
## One byte a cell: 255 where the ground is high. The ground shader reads
## it smoothed, to paint the tops of hills a little drier.
func _high_texture() -> ImageTexture:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(map.w * map.h)
	for i: int in map.w * map.h:
		bytes[i] = 255 if map.high[i] != 0 else 0
	return ImageTexture.create_from_image(Image.create_from_data(map.w, map.h, false, Image.FORMAT_R8, bytes))


func _build_marks() -> void:
	_mark_w = map.w * MARK_SCALE
	_mark_h = map.h * MARK_SCALE
	_marks = PackedByteArray()
	_marks.resize(_mark_w * _mark_h * 3)
	var centre: Vector2 = map.world_size() * 0.5
	for s: Vector2 in map.starts:
		_stamp_path(map.find_path(s, centre, true), 2.6, 215)
		_stamp(s, 17.0, 2, 150)
	for u: Vector2 in map.uplink_spots:
		var home: Vector2 = centre
		for s: Vector2 in map.starts:
			if s.distance_to(u) < home.distance_to(u):
				home = s
		_stamp_path(map.find_path(u, home, true), 2.0, 190)
		_stamp(u, 5.0, 2, 170)
	for f: Vector3 in map.field_spots:
		_stamp(Vector2(f.x, f.y), 3.8, 1, 210)
	var img: Image = Image.create_from_data(_mark_w, _mark_h, false, Image.FORMAT_RGB8, _marks)
	_mark_tex = ImageTexture.create_from_image(img)


## A soft disc of `strength` (0-255) in one channel; keeps the stronger value
## where discs overlap.
func _stamp(at: Vector2, radius: float, channel: int, strength: int) -> void:
	var k: float = float(MARK_SCALE) / SimMap.CELL
	var cx: float = at.x * k
	var cy: float = at.y * k
	var r: float = radius * k
	for y: int in range(maxi(0, int(cy - r)), mini(_mark_h, int(cy + r) + 2)):
		for x: int in range(maxi(0, int(cx - r)), mini(_mark_w, int(cx + r) + 2)):
			var d: float = Vector2(float(x) + 0.5 - cx, float(y) + 0.5 - cy).length() / r
			if d >= 1.0:
				continue
			var v: int = int(float(strength) * (1.0 - d * d))
			var i: int = (y * _mark_w + x) * 3 + channel
			if v > _marks[i]:
				_marks[i] = v


func _stamp_path(points: PackedVector2Array, radius: float, strength: int) -> void:
	for i: int in range(1, points.size()):
		var a: Vector2 = points[i - 1]
		var b: Vector2 = points[i]
		var steps: int = maxi(1, int(a.distance_to(b) / 0.8))
		for k: int in steps + 1:
			_stamp(a.lerp(b, float(k) / float(steps)), radius, 0, strength)


## True if a spot stands on a vehicle track or right beside one. Trees,
## bushes, boulders, stones and logs are kept off the tracks with this; the
## reach covers the way the ground shader lets a track wander.
func _on_trail(at: Vector3) -> bool:
	var k: float = float(MARK_SCALE) / SimMap.CELL
	for off: Vector2 in [Vector2.ZERO, Vector2(2.2, 0.0), Vector2(-2.2, 0.0), Vector2(0.0, 2.2), Vector2(0.0, -2.2), Vector2(1.6, 1.6), Vector2(-1.6, 1.6), Vector2(1.6, -1.6), Vector2(-1.6, -1.6)]:
		var x: int = int((at.x + off.x) * k)
		var y: int = int((at.z + off.y) * k)
		if x >= 0 and y >= 0 and x < _mark_w and y < _mark_h and _marks[(y * _mark_w + x) * 3] > 36:
			return true
	return false


## How worn the ground is at a world position (tracks or base earth), 0-255.
func _worn_at(p: Vector2) -> int:
	var k: float = float(MARK_SCALE) / SimMap.CELL
	var x: int = int(p.x * k)
	var y: int = int(p.y * k)
	if x < 0 or y < 0 or x >= _mark_w or y >= _mark_h:
		return 0
	var i: int = (y * _mark_w + x) * 3
	return maxi(_marks[i], _marks[i + 2])


func _build_ground() -> void:
	# The mesh runs BORDER cells past the map on every side: the same ground,
	# sinking and darkening, so the battlefield does not end in a cliff.
	var row: int = map.w + 1
	var wide: int = map.w + 2 * BORDER + 1
	var verts: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var land: PackedVector2Array = PackedVector2Array()
	var wet: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	for y: int in range(-BORDER, map.h + BORDER + 1):
		for x: int in range(-BORDER, map.w + BORDER + 1):
			var i: int = clampi(y, 0, map.h) * row + clampi(x, 0, map.w)
			var out: float = _outside(x, y)
			verts.append(Vector3(float(x) * SimMap.CELL, _height(x, y), float(y) * SimMap.CELL))
			normals.append(Vector3(_height(x - 1, y) - _height(x + 1, y), 2.0 * SimMap.CELL, _height(x, y - 1) - _height(x, y + 1)).normalized())
			land.append(Vector2(_forest[i], _rock[i]))
			# UV2: water share, and how far outside the map this corner is.
			wet.append(Vector2(_water[i] if out <= 0.0 else 0.0, 0.0 if out <= 0.0 else 0.42 + 0.58 * out))
	for y: int in map.h + 2 * BORDER:
		for x: int in map.w + 2 * BORDER:
			var i: int = y * wide + x
			indices.append_array(PackedInt32Array([i, i + 1, i + wide + 1, i, i + wide + 1, i + wide]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = land
	arrays[Mesh.ARRAY_TEX_UV2] = wet
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var shader: Shader = Shader.new()
	shader.code = GROUND_SHADER
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("noise_tex", noise_texture())
	mat.set_shader_parameter("mark_tex", _mark_tex)
	mat.set_shader_parameter("high_tex", _high_texture())
	mat.set_shader_parameter("map_size", map.world_size())
	for key: String in ["lush", "dry", "soil", "litter_dark", "litter_light", "stone_dark", "stone_light", "sand_dark", "sand_light", "bed"]:
		mat.set_shader_parameter(key, look.get(key))
	_ground_mat = mat
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
	mat.set_shader_parameter("shallow", look.water_shallow)
	mat.set_shader_parameter("deep", look.water_deep)
	mat.set_shader_parameter("foam_color", look.water_foam)
	mat.set_shader_parameter("glow", look.water_glow)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Water"
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## A dark floor far below and around the border, so nothing shows through
## where the border ends.
func _build_apron() -> void:
	var size: Vector2 = map.world_size()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = size * 4.0
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.02, 0.03, 0.035)
	mat.roughness = 1.0
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Skirt"
	mi.mesh = plane
	mi.material_override = mat
	mi.position = Vector3(size.x * 0.5, -2.45, size.y * 0.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# ------------------------------------------------------------ scatter

func _prop_material(sway: float, two_sided: bool, lift: float = 0.0) -> ShaderMaterial:
	var shader: Shader = Shader.new()
	shader.code = PROP_SHADER % ("cull_disabled" if two_sided else "cull_back")
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("map_size", map.world_size())
	mat.set_shader_parameter("noise_tex", noise_texture())
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
	return Transform3D(xf, Vector3(p.x, _ground_y(p) - sink, p.y))


func _conifer(tiers: int, girth: float) -> ArrayMesh:
	var buf: MeshBuf = MeshBuf.new()
	buf.cone(Vector3.ZERO, 0.13, 0.08, 0.95, 5, look.bark_low, look.bark_high)
	buf.soften = 0.9
	var y: float = 0.55
	for t: int in tiers:
		var k: float = 1.0 - float(t) / float(tiers + 1)
		# Higher tiers shade towards the cap colour: lighter green, or snow.
		var up: float = float(t) / float(maxi(1, tiers - 1))
		var low: Color = look.conifer_low.lerp(look.conifer_cap, up * 0.25)
		var high: Color = look.conifer_high.lerp(look.conifer_cap, 0.25 + up * 0.75)
		buf.cone(Vector3(0.0, y, 0.0), 0.80 * k * girth, 0.0, 1.25 * (0.75 + 0.25 * k), 7, low, high, float(t) * 0.5)
		y += 0.62 * (0.8 + 0.2 * k)
	return buf.commit()


## A leafy tree; `flat` squashes the crown into the wide top of a thorn tree.
func _broadleaf(shape_seed: int, flat: float = 1.0) -> ArrayMesh:
	var rng: SimRng = SimRng.new(shape_seed)
	var buf: MeshBuf = MeshBuf.new()
	buf.cone(Vector3.ZERO, 0.16, 0.10, 1.25, 5, look.bark_low, look.bark_high)
	buf.soften = 0.9
	var low: Color = look.leaf_low
	var high: Color = look.leaf_high
	var wide: float = 1.0 + (1.0 - flat) * 0.5
	buf.blob(Vector3(0.0, 1.85 - (1.0 - flat) * 0.25, 0.0), Vector3(0.92 * wide, 0.72 * flat, 0.92 * wide), 1, 0.16, low, high, rng)
	buf.blob(Vector3(0.55 * wide, 1.5, 0.25), Vector3(0.55 * wide, 0.45 * flat, 0.55 * wide), 0, 0.14, low, high, rng)
	buf.blob(Vector3(-0.5 * wide, 1.6, -0.3), Vector3(0.6 * wide, 0.48 * flat, 0.6 * wide), 0, 0.14, low, high, rng)
	buf.blob(Vector3(-0.1, 1.45, 0.6 * wide), Vector3(0.5 * wide, 0.42 * flat, 0.5 * wide), 0, 0.14, low, high, rng)
	return buf.commit()


## A cactus: a ribbed column with an arm or two.
func _cactus(arms: int) -> ArrayMesh:
	var buf: MeshBuf = MeshBuf.new()
	buf.soften = 0.6
	var low: Color = look.conifer_low
	var high: Color = look.conifer_high
	buf.cone(Vector3.ZERO, 0.22, 0.18, 1.7, 7, low, high)
	buf.cone(Vector3(0.0, 1.7, 0.0), 0.18, 0.0, 0.16, 7, high, look.conifer_cap)
	for i: int in arms:
		var side: float = 1.0 if i % 2 == 0 else -1.0
		var at: float = 0.6 + 0.35 * float(i)
		buf.cone(Vector3(side * 0.16, at, 0.0), 0.1, 0.1, 0.12, 6, low, high, 0.0, Vector3(side * 0.34, 0.0, 0.0))
		buf.cone(Vector3(side * 0.5, at + 0.08, 0.0), 0.1, 0.08, 0.55 + 0.15 * float(i % 2), 6, low, high)
	return buf.commit()


## A burnt tree: a bare trunk and a few broken branches.
func _dead_tree(shape_seed: int) -> ArrayMesh:
	var rng: SimRng = SimRng.new(shape_seed)
	var buf: MeshBuf = MeshBuf.new()
	var low: Color = look.bark_low
	var high: Color = look.bark_high
	buf.cone(Vector3.ZERO, 0.17, 0.06, 2.1, 5, low, high, 0.0, Vector3(rng.range_f(-0.2, 0.2), 0.0, rng.range_f(-0.2, 0.2)))
	for i: int in 4:
		var ang: float = rng.range_f(0.0, TAU)
		var reach: float = rng.range_f(0.45, 0.85)
		buf.cone(Vector3(0.0, 0.9 + 0.28 * float(i), 0.0), 0.05, 0.0, rng.range_f(0.45, 0.8), 4, low, high, 0.0, Vector3(cos(ang) * reach, 0.0, sin(ang) * reach))
	return buf.commit()


## The five tree meshes of this region: two that stand in for conifers, two
## for leafy trees, and a bush.
func _tree_meshes() -> Array[ArrayMesh]:
	match look.trees:
		"snow":
			return [_conifer(3, 1.0), _conifer(4, 0.82), _conifer(4, 1.0), _conifer(3, 0.8), _bush(5)]
		"dry":
			return [_cactus(2), _cactus(1), _broadleaf(11, 0.5), _broadleaf(29, 0.45), _bush(5)]
		"dead":
			return [_dead_tree(3), _dead_tree(8), _dead_tree(21), _dead_tree(34), _bush(5)]
	return [_conifer(3, 1.0), _conifer(4, 0.82), _broadleaf(11), _broadleaf(29), _bush(5)]


func _bush(shape_seed: int) -> ArrayMesh:
	var rng: SimRng = SimRng.new(shape_seed)
	var buf: MeshBuf = MeshBuf.new()
	buf.soften = 0.9
	var low: Color = look.bush_low
	var high: Color = look.bush_high
	buf.blob(Vector3(0.0, 0.28, 0.0), Vector3(0.5, 0.36, 0.5), 0, 0.2, low, high, rng)
	buf.blob(Vector3(0.38, 0.2, 0.15), Vector3(0.32, 0.26, 0.32), 0, 0.2, low, high, rng)
	buf.blob(Vector3(-0.3, 0.22, -0.25), Vector3(0.36, 0.28, 0.36), 0, 0.2, low, high, rng)
	return buf.commit()


func _boulder(shape_seed: int, detail: int) -> ArrayMesh:
	var rng: SimRng = SimRng.new(shape_seed)
	var buf: MeshBuf = MeshBuf.new()
	buf.blob(Vector3(0.0, 0.35, 0.0), Vector3(1.0, 0.72, 0.86), detail, 0.24, look.rock_low, look.rock_high, rng)
	return buf.commit()


func _tuft() -> ArrayMesh:
	var buf: MeshBuf = MeshBuf.new()
	# Lit like the ground it stands on, whichever way a blade happens to face.
	buf.soften = 50.0
	var low: Color = look.tuft_low
	var high: Color = look.tuft_high
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


## Scatter in the border is dimmer the further out it stands.
func _border_dim(x: int, y: int) -> float:
	return lerpf(0.5, 0.12, _outside(x, y))


func _build_trees() -> void:
	var s1: float = _rng.range_f(0.0, TAU)
	var s2: float = _rng.range_f(0.0, TAU)
	var kinds: Array[Array] = [[], [], [], [], []]  # conifer, tall conifer, broadleaf, broadleaf 2, bush
	var tints: Array[PackedColorArray] = [PackedColorArray(), PackedColorArray(), PackedColorArray(), PackedColorArray(), PackedColorArray()]
	for y: int in range(-BORDER, map.h + BORDER):
		for x: int in range(-BORDER, map.w + BORDER):
			var t: int = _cell_type(x, y)
			var inside: bool = _in_map(x, y)
			if not inside:
				# The border: woods carry on past the edge, with stray trees
				# on open ground, all in shade.
				if t == SimMap.Terrain.WATER or (t != SimMap.Terrain.FOREST and not _rng.chance(0.16)):
					continue
				var dim: float = _border_dim(x, y)
				for i: int in _rng.range_i(1, 2):
					var bk: int = _rng.range_i(0, 3)
					kinds[bk].append(_spot(x, y, 0.1, 0.8, 1.5, 0.16, 0.0))
					tints[bk].append(Color(dim, dim, dim))
				continue
			if t == SimMap.Terrain.FOREST:
				# Groves lean towards one kind of tree.
				var grove: float = sin(float(x) * 0.19 + s1) + cos(float(y) * 0.23 + s2) + sin(float(x + y) * 0.11)
				var count: int = _rng.range_i(2, 3)
				for i: int in count:
					var leafy: bool = _rng.chance(0.8 if grove > 0.25 else 0.12)
					var k: int = (2 + _rng.range_i(0, 1)) if leafy else _rng.range_i(0, 1)
					var tree: Transform3D = _spot(x, y, 0.1, 0.78, 1.32, 0.16, 0.0)
					if _on_trail(tree.origin):
						continue
					kinds[k].append(tree)
					var shade: float = _rng.range_f(0.78, 1.0)
					tints[k].append(Color(shade * _rng.range_f(0.86, 1.0), shade, shade * _rng.range_f(0.8, 1.0)))
				if _rng.chance(0.3 * look.bushes):
					var shrub: Transform3D = _spot(x, y, 0.1, 0.7, 1.2, 0.2, 0.0)
					if not _on_trail(shrub.origin):
						kinds[4].append(shrub)
						tints[4].append(Color(0.9, 0.95, 0.85) * _rng.range_f(0.8, 1.0))
			elif t == SimMap.Terrain.GROUND:
				# Bushes straggle out of the forest edge; the odd one stands alone.
				var edge: bool = _is(x - 1, y, SimMap.Terrain.FOREST) or _is(x + 1, y, SimMap.Terrain.FOREST) or _is(x, y - 1, SimMap.Terrain.FOREST) or _is(x, y + 1, SimMap.Terrain.FOREST)
				if _rng.chance((0.4 if edge else 0.012) * look.bushes):
					var bush: Transform3D = _spot(x, y, 0.15, 0.6, 1.15, 0.2, 0.0)
					if not _on_trail(bush.origin):
						kinds[4].append(bush)
						tints[4].append(Color(0.95, 1.0, 0.85) * _rng.range_f(0.8, 1.0))
	var foliage: ShaderMaterial = _prop_material(0.022, false, 0.22)
	var meshes: Array[ArrayMesh] = _tree_meshes()
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
	for y: int in range(-BORDER, map.h + BORDER):
		for x: int in range(-BORDER, map.w + BORDER):
			var t: int = _cell_type(x, y)
			if not _in_map(x, y):
				# Crags carry on into the border, and a few stand alone there.
				if t == SimMap.Terrain.ROCK or (t == SimMap.Terrain.GROUND and _rng.chance(0.035)):
					var dim: float = _border_dim(x, y)
					var bk: int = _rng.range_i(0, 2)
					big[bk].append(_spot(x, y, 0.2, 1.0, 2.4, 0.3, 0.1))
					big_tints[bk].append(Color(dim, dim, dim))
				continue
			if t == SimMap.Terrain.ROCK:
				if _rng.chance(0.62):
					var k: int = _rng.range_i(0, 2)
					var xf: Transform3D = _spot(x, y, 0.22, 0.8, 1.7, 0.3, 0.1)
					xf.basis = Basis.from_euler(Vector3(_rng.range_f(-0.25, 0.25), 0.0, _rng.range_f(-0.25, 0.25))) * xf.basis
					if not _on_trail(xf.origin):
						big[k].append(xf)
						big_tints[k].append(Color.WHITE * _rng.range_f(0.78, 1.0))
				for i: int in _rng.range_i(0, 2):
					var chip: Transform3D = _spot(x, y, 0.05, 0.22, 0.5, 0.3, 0.05)
					if not _on_trail(chip.origin):
						small.append(chip)
						small_tints.append(Color.WHITE * _rng.range_f(0.7, 1.0))
			elif t == SimMap.Terrain.GROUND and _rng.chance(0.03):
				# Loose stones out on the grass.
				for i: int in _rng.range_i(1, 3):
					var pebble: Transform3D = _spot(x, y, 0.1, 0.12, 0.3, 0.3, 0.04)
					if not _on_trail(pebble.origin):
						small.append(pebble)
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
			if not _rng.chance(clampf(0.22 + drift * 0.3, 0.04, 0.6) * look.grass):
				continue
			for i: int in _rng.range_i(1, 3):
				var tuft: Transform3D = _spot(x, y, 0.05, 0.8, 1.5, 0.25, 0.0)
				if _worn_at(Vector2(tuft.origin.x, tuft.origin.z)) > 70:
					continue
				spots.append(tuft)
				tints.append(Color(_rng.range_f(0.85, 1.0), 1.0, _rng.range_f(0.75, 1.0)) * _rng.range_f(0.82, 1.0))
	_add_scatter("Grass", _tuft(), _prop_material(0.12, true), spots, tints, false)


func _flower() -> ArrayMesh:
	var rng: SimRng = SimRng.new(77)
	var buf: MeshBuf = MeshBuf.new()
	buf.soften = 50.0
	var white: Color = Color(1.0, 1.0, 1.0)
	for i: int in 5:
		var ang: float = float(i) * 1.257
		var at: Vector3 = Vector3(cos(ang) * 0.16 * float(i % 3), 0.13 + 0.03 * float(i % 2), sin(ang) * 0.16 * float(i % 3))
		buf.cone(Vector3(at.x, 0.0, at.z), 0.012, 0.012, at.y, 3, Color(0.25, 0.4, 0.15), Color(0.3, 0.45, 0.18))
		buf.blob(at, Vector3(0.055, 0.035, 0.055), 0, 0.1, white, white, rng)
	return buf.commit()


func _reed() -> ArrayMesh:
	var buf: MeshBuf = MeshBuf.new()
	buf.soften = 50.0
	var low: Color = Color(0.24, 0.33, 0.14)
	var high: Color = Color(0.55, 0.56, 0.28)
	var above: Vector3 = Vector3(0.0, -5.0, 0.0)
	for i: int in 7:
		var ang: float = float(i) * 0.9 + 0.2
		var out: Vector3 = Vector3(cos(ang), 0.0, sin(ang))
		var side: Vector3 = Vector3(-out.z, 0.0, out.x)
		var foot: Vector3 = out * (0.05 + 0.04 * float(i % 3))
		var tip: Vector3 = foot + out * 0.1 + Vector3(0.0, 0.62 + 0.12 * float(i % 3), 0.0)
		buf.tri(foot - side * 0.03, foot + side * 0.03, tip, above, low, low, high)
	return buf.commit()


func _log() -> ArrayMesh:
	var buf: MeshBuf = MeshBuf.new()
	buf.cone(Vector3(0.0, -0.8, 0.0), 0.17, 0.14, 1.6, 6, Color(0.20, 0.14, 0.10), Color(0.33, 0.24, 0.16))
	return buf.commit()


func _stump() -> ArrayMesh:
	var buf: MeshBuf = MeshBuf.new()
	buf.cone(Vector3.ZERO, 0.24, 0.18, 0.32, 6, Color(0.19, 0.13, 0.09), Color(0.36, 0.27, 0.18))
	buf.cone(Vector3(0.0, 0.32, 0.0), 0.18, 0.0, 0.02, 6, Color(0.55, 0.45, 0.30), Color(0.6, 0.5, 0.34))
	return buf.commit()


## Small things that make the land look lived in: flowers in the meadows,
## reeds along the water, fallen logs and stumps at the edge of the woods.
func _build_litter() -> void:
	var s1: float = _rng.range_f(0.0, TAU)
	var s2: float = _rng.range_f(0.0, TAU)
	var flowers: Array[Transform3D] = []
	var flower_tints: PackedColorArray = PackedColorArray()
	var reeds: Array[Transform3D] = []
	var reed_tints: PackedColorArray = PackedColorArray()
	var logs: Array[Transform3D] = []
	var stumps: Array[Transform3D] = []
	var wood_tints: PackedColorArray = PackedColorArray()
	var stump_tints: PackedColorArray = PackedColorArray()
	var petals: Array[Color] = [Color(1.0, 0.95, 0.75), Color(1.0, 0.82, 0.25), Color(0.85, 0.6, 1.0), Color(1.0, 0.55, 0.5)]
	for y: int in map.h:
		for x: int in map.w:
			if map.terrain_cell(Vector2i(x, y)) != SimMap.Terrain.GROUND:
				continue
			var by_water: bool = _is(x - 1, y, SimMap.Terrain.WATER) or _is(x + 1, y, SimMap.Terrain.WATER) or _is(x, y - 1, SimMap.Terrain.WATER) or _is(x, y + 1, SimMap.Terrain.WATER)
			var by_wood: bool = _is(x - 1, y, SimMap.Terrain.FOREST) or _is(x + 1, y, SimMap.Terrain.FOREST) or _is(x, y - 1, SimMap.Terrain.FOREST) or _is(x, y + 1, SimMap.Terrain.FOREST)
			if by_water:
				if look.reeds:
					for i: int in _rng.range_i(1, 3):
						reeds.append(_spot(x, y, 0.05, 0.8, 1.5, 0.25, 0.0))
						reed_tints.append(Color.WHITE * _rng.range_f(0.8, 1.0))
				continue
			if by_wood and _rng.chance(0.09):
				var lying: Transform3D = _spot(x, y, 0.2, 0.8, 1.3, 0.0, -0.13)
				lying.basis = lying.basis * Basis(Vector3.RIGHT, PI * 0.5)
				if _worn_at(Vector2(lying.origin.x, lying.origin.z)) < 40 and not _on_trail(lying.origin):
					logs.append(lying)
					wood_tints.append(Color.WHITE * _rng.range_f(0.75, 1.0))
			elif by_wood and _rng.chance(0.07):
				var cut: Transform3D = _spot(x, y, 0.2, 0.8, 1.3, 0.1, 0.0)
				if _worn_at(Vector2(cut.origin.x, cut.origin.z)) < 40 and not _on_trail(cut.origin):
					stumps.append(cut)
					stump_tints.append(Color.WHITE * _rng.range_f(0.75, 1.0))
			# Flowers come in patches of one colour.
			var patch: float = sin(float(x) * 0.23 + s1) * cos(float(y) * 0.29 + s2)
			if patch > 0.55 and _rng.chance(0.4 * look.flowers):
				var hue: Color = petals[posmod(int(float(x) * 0.05 + float(y) * 0.07 + s1 * 3.0), petals.size())]
				for i: int in _rng.range_i(1, 3):
					var bloom: Transform3D = _spot(x, y, 0.05, 0.8, 1.4, 0.2, 0.0)
					if _worn_at(Vector2(bloom.origin.x, bloom.origin.z)) > 50:
						continue
					flowers.append(bloom)
					flower_tints.append(hue * _rng.range_f(0.85, 1.0))
	_add_scatter("Flowers", _flower(), _prop_material(0.1, true, 0.06), flowers, flower_tints, false)
	_add_scatter("Reeds", _reed(), _prop_material(0.1, true), reeds, reed_tints, false)
	var wood: ShaderMaterial = _prop_material(0.0, false)
	_add_scatter("Logs", _log(), wood, logs, wood_tints, true)
	_add_scatter("Stumps", _stump(), wood, stumps, stump_tints, false)


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
