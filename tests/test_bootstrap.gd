extends TestCase
## Sanity checks for the project skeleton.


func test_project_settings() -> void:
	check_eq(str(ProjectSettings.get_setting("application/config/name")), "Signal Front", "project name")
	check_eq(
		str(ProjectSettings.get_setting("rendering/renderer/rendering_method")),
		"gl_compatibility",
		"compatibility renderer"
	)
	check(ResourceLoader.exists(str(ProjectSettings.get_setting("application/run/main_scene"))), "main scene exists")


func test_input_map_declared() -> void:
	for action: String in [
		"cam_forward", "cam_back", "cam_left", "cam_right", "cam_rotate_left", "cam_rotate_right",
		"order_attack_move", "order_stop", "order_hold", "toggle_grid", "pause_menu",
	]:
		check(ProjectSettings.has_setting("input/" + action), "input action %s" % action)
