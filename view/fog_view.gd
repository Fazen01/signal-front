class_name FogView
extends Node3D
## Fog of war drawn over the terrain: unexplored ground is nearly black,
## explored ground that is not currently seen is dimmed.

const UNEXPLORED_ALPHA: int = 215
const EXPLORED_ALPHA: int = 105

var world: SimWorld = null
var player: int = 0
var terrain: TerrainView = null  ## its trees and boulders read the fog texture and darken too
var _texture: ImageTexture = null
var _version: int = -1


func setup(sim_world: SimWorld, local_player: int) -> void:
	world = sim_world
	player = local_player
	var map: SimMap = world.map
	_texture = ImageTexture.create_from_image(Image.create(map.w, map.h, false, Image.FORMAT_RGBA8))
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = _texture
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.render_priority = 2
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Fog"
	mi.mesh = SignalView.build_overlay_mesh(map, 0.3)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	if terrain != null:
		terrain.set_fog_texture(_texture)
	refresh()


func _process(_delta: float) -> void:
	if world != null and world.vision_version != _version:
		refresh()


func refresh() -> void:
	_version = world.vision_version
	var map: SimMap = world.map
	var vis: PackedByteArray = world.visible[player]
	var seen: PackedByteArray = world.explored[player]
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(map.w * map.h * 4)
	var n: int = map.w * map.h
	for i: int in n:
		var o: int = i * 4
		bytes[o] = 4
		bytes[o + 1] = 7
		bytes[o + 2] = 10
		if vis[i] != 0:
			bytes[o + 3] = 0
		elif seen[i] != 0:
			bytes[o + 3] = EXPLORED_ALPHA
		else:
			bytes[o + 3] = UNEXPLORED_ALPHA
	_texture.update(Image.create_from_data(map.w, map.h, false, Image.FORMAT_RGBA8, bytes))
