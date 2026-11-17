class_name SceneLight
extends RefCounted
## The sun, sky light and tone mapping shared by the battle scene and the
## model gallery, so both show models under the same light.


## The hours a battle can be fought at. Like the region, the hour changes
## how the field looks and nothing about how it plays. A match is lit for
## midday unless another hour is picked in the skirmish setup.
const TIMES: Array[String] = ["morning", "noon", "evening", "overcast"]
const TIME_NAMES: Dictionary[String, String] = {
	"morning": "Morning", "noon": "Midday", "evening": "Evening", "overcast": "Overcast",
}


## The colour the sky gives to open water at an hour.
static func sky_over(time: String) -> Color:
	match time:
		"morning":
			return Color(0.80, 0.76, 0.74)
		"evening":
			return Color(0.90, 0.60, 0.46)
		"overcast":
			return Color(0.66, 0.68, 0.71)
		_:
			return Color(0.58, 0.70, 0.86)


## Adds a "Sun" and an "Environment" node to `parent`.
static func add_to(parent: Node, shadows: bool, region: String = "temperate", time: String = "noon") -> void:
	var look: RegionLook = RegionLook.of(region)
	# Where the sun stands, what it does to the region's own light, and the
	# colours of the sky that lights everything from above.
	var aim: Vector3 = Vector3(-52.0, -38.0, 0.0)
	var tint: Color = Color.WHITE
	var sun_gain: float = 1.0
	var sky_gain: float = 1.0
	var sky_top: Color = Color(0.34, 0.50, 0.74)
	var sky_horizon: Color = Color(0.74, 0.80, 0.86)
	var shade: float = 1.0
	match time:
		"morning":
			# A low sun out of the east: long shadows, pale gold light.
			aim = Vector3(-31.0, -112.0, 0.0)
			tint = Color(1.0, 0.90, 0.74)
			sun_gain = 0.98
			sky_gain = 0.95
			sky_top = Color(0.38, 0.52, 0.74)
			sky_horizon = Color(0.94, 0.82, 0.68)
		"evening":
			# A low sun out of the west: longer shadows still, and everything orange.
			aim = Vector3(-27.0, 58.0, 0.0)
			tint = Color(1.0, 0.74, 0.52)
			sun_gain = 1.08
			sky_gain = 1.1
			sky_top = Color(0.30, 0.34, 0.60)
			sky_horizon = Color(0.98, 0.62, 0.42)
		"overcast":
			# No sun to speak of: flat grey light from the whole sky, faint shadows.
			aim = Vector3(-66.0, -20.0, 0.0)
			tint = Color(0.86, 0.90, 0.95)
			sun_gain = 0.55
			sky_gain = 1.5
			sky_top = Color(0.56, 0.59, 0.63)
			sky_horizon = Color(0.74, 0.76, 0.78)
			shade = 0.5
		_:
			pass
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = aim
	sun.light_energy = look.sun_energy * sun_gain
	sun.light_color = Color(look.sun_color.r * tint.r, look.sun_color.g * tint.g, look.sun_color.b * tint.b)
	sun.shadow_enabled = shadows
	sun.shadow_opacity = shade
	sun.shadow_blur = 1.4
	sun.shadow_bias = 0.06
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 150.0
	parent.add_child(sun)

	# The sky is never looked at directly (the camera looks down and the
	# backdrop stays dark); it is there to light the scene: blue from above,
	# pale from the horizon, dim earth from below, and reflections on metal.
	var sky_mat: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = sky_top
	sky_mat.sky_horizon_color = sky_horizon
	sky_mat.ground_horizon_color = Color(0.56, 0.58, 0.52)
	sky_mat.ground_bottom_color = Color(0.22, 0.24, 0.18)
	sky_mat.sun_angle_max = 12.0
	var sky: Sky = Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.04, 0.05)
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = look.ambient * sky_gain
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we: WorldEnvironment = WorldEnvironment.new()
	we.name = "Environment"
	we.environment = env
	parent.add_child(we)
