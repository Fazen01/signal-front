extends TestCase
## Every faction has an interface of its own: a skin with its own colours,
## shapes and emblem, from which a whole theme can be built.


func test_every_faction_has_its_own_skin() -> void:
	var data: GameData = GameData.shared()
	var neutral: UiSkin = UiSkin.of("")
	var icon_source: String = FileAccess.get_file_as_string("res://ui/hud_icon.gd")
	var emblems: Dictionary[String, String] = {}
	var looks: Dictionary[String, String] = {}
	var count: int = 0
	for f: FactionDef in data.factions.values():
		if not f.playable:
			continue
		count += 1
		var skin: UiSkin = UiSkin.of(f.id)
		check(skin.plate == f.name.to_upper(), "%s: the plate carries the faction's name (%s)" % [f.id, skin.plate])
		check(skin.emblem != neutral.emblem, "%s: has an emblem of its own" % f.id)
		check(not emblems.has(skin.emblem), "%s: shares no emblem with %s" % [f.id, str(emblems.get(skin.emblem, ""))])
		emblems[skin.emblem] = f.id
		check(icon_source.contains("\"%s\":" % skin.emblem), "%s: the emblem %s is drawn" % [f.id, skin.emblem])
		var look: String = "%s %s %s %s %.2f" % [skin.accent.to_html(), str(skin.corners), str(skin.edges), str(skin.chamfer), skin.skew]
		check(not looks.has(look), "%s: does not look like %s" % [f.id, str(looks.get(look, ""))])
		looks[look] = f.id
		check(UiSkin.of(f.id) == skin, "%s: the skin is made once" % f.id)
	check(count >= 10, "every playable faction was tried (%d)" % count)


func test_a_skin_builds_a_whole_theme() -> void:
	for id: String in ["", "aegis", "foundry", "nomad", "vesper", "verdigris", "zephyr", "tally", "veil", "bracken", "lodestone"]:
		var skin: UiSkin = UiSkin.of(id)
		var t: Theme = skin.theme()
		for kind: String in ["Button", "OptionButton"]:
			for state: String in ["normal", "hover", "pressed", "disabled"]:
				check(t.has_stylebox(state, kind), "%s: %s has a %s look" % [id, kind, state])
		check(t.has_stylebox("panel", "PanelContainer"), "%s: panels are dressed" % id)
		check(t.has_stylebox("panel", "TooltipPanel"), "%s: tooltips are dressed" % id)
		check(t.has_stylebox("normal", "PrimaryButton"), "%s: the main button is dressed" % id)
		check(skin.theme() == t, "%s: the theme is made once" % id)
		# The interface has to be readable whatever the colours.
		check(skin.text.get_luminance() - skin.raised.get_luminance() > 0.45, "%s: text stands out on a button" % id)
		check(skin.text.get_luminance() - skin.panel_fill.get_luminance() > 0.5, "%s: text stands out on a panel" % id)
		check(skin.accent.get_luminance() - skin.strip_fill.get_luminance() > 0.3, "%s: the accent stands out on the bars" % id)
		check(skin.dim.get_luminance() - skin.section_fill.get_luminance() > 0.25, "%s: small print can be read" % id)
		var strip: StyleBoxFlat = skin.strip(true)
		check(strip.border_width_top >= 1 and strip.border_width_bottom == 0, "%s: a bottom bar is ruled along its top" % id)



func test_how_to_play_says_what_is_special_about_every_faction() -> void:
	var data: GameData = GameData.shared()
	for f: FactionDef in data.factions.values():
		if not f.playable:
			continue
		check(MainMenu.FACTION_NOTES.has(f.id), "%s: has a line on the factions page" % f.name)
		check(str(MainMenu.FACTION_NOTES.get(f.id, "")).length() > 40, "%s: and it says something" % f.name)
	for id: String in MainMenu.FACTION_NOTES:
		check(data.factions.has(id), "%s: every line is about a faction that exists" % id)
