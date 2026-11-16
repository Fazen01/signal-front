class_name SceneLight
extends RefCounted
## The sun, sky light and tone mapping shared by the battle scene and the
## model gallery, so both show models under the same light.


## Adds a "Sun" and an "Environment" node to `parent`.
static func add_to(parent: Node, shadows: bool, region: String = "temperate") -> void:
	var look: RegionLook = RegionLook.of(region)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52.0, -38.0, 0.0)
	sun.light_energy = look.sun_energy
	sun.light_color = look.sun_color
	sun.shadow_enabled = shadows
	sun.shadow_blur = 1.4
	sun.shadow_bias = 0.06
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 150.0
	parent.add_child(sun)

	# The sky is never looked at directly (the camera looks down and the
	# backdrop stays dark); it is there to light the scene: blue from above,
	# pale from the horizon, dim earth from below, and reflections on metal.
	var sky_mat: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.34, 0.50, 0.74)
	sky_mat.sky_horizon_color = Color(0.74, 0.80, 0.86)
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
	env.ambient_light_energy = look.ambient
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we: WorldEnvironment = WorldEnvironment.new()
	we.name = "Environment"
	we.environment = env
	parent.add_child(we)
