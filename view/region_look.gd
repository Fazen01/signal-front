class_name RegionLook
extends RefCounted
## How one region of the world looks: its ground, water, plants, rock and
## light. Purely presentation: the simulation only carries the region's name.

var title: String = "Greenwood"
# Ground shader.
var lush: Color = Color(0.26, 0.39, 0.19)
var dry: Color = Color(0.40, 0.44, 0.24)
var soil: Color = Color(0.38, 0.33, 0.24)
var litter_dark: Color = Color(0.13, 0.21, 0.10)
var litter_light: Color = Color(0.26, 0.25, 0.14)
var stone_dark: Color = Color(0.27, 0.27, 0.28)
var stone_light: Color = Color(0.47, 0.46, 0.45)
var sand_dark: Color = Color(0.55, 0.49, 0.35)
var sand_light: Color = Color(0.72, 0.66, 0.49)
var bed: Color = Color(0.22, 0.27, 0.24)
# Water (or whatever fills the low ground).
var water_shallow: Color = Color(0.25, 0.55, 0.58)
var water_deep: Color = Color(0.06, 0.22, 0.38)
var water_foam: Color = Color(0.86, 0.93, 0.92)
var water_glow: float = 0.0  ## above 0 the "water" gives off light: lava
# Plants and rock.
var trees: String = "wood"  ## "wood", "snow" (capped conifers), "dry" (cactus and thorn) or "dead"
var conifer_low: Color = Color(0.07, 0.20, 0.11)
var conifer_high: Color = Color(0.17, 0.37, 0.18)
var conifer_cap: Color = Color(0.22, 0.44, 0.22)
var leaf_low: Color = Color(0.10, 0.24, 0.07)
var leaf_high: Color = Color(0.26, 0.42, 0.13)
var bark_low: Color = Color(0.16, 0.11, 0.08)
var bark_high: Color = Color(0.31, 0.22, 0.14)
var bush_low: Color = Color(0.09, 0.21, 0.07)
var bush_high: Color = Color(0.23, 0.38, 0.13)
var rock_low: Color = Color(0.20, 0.20, 0.22)
var rock_high: Color = Color(0.52, 0.52, 0.50)
var tuft_low: Color = Color(0.21, 0.33, 0.13)
var tuft_high: Color = Color(0.44, 0.54, 0.22)
var grass: float = 1.0  ## how much grass grows, against the Greenwood
var flowers: float = 1.0
var reeds: bool = true
var bushes: float = 1.0
# Light.
var sun_color: Color = Color(1.0, 0.95, 0.86)
var sun_energy: float = 1.2
var ambient: float = 0.45
# Minimap.
var map_ground: Color = Color(0.31, 0.42, 0.21)
var map_forest: Color = Color(0.13, 0.28, 0.13)
var map_rock: Color = Color(0.44, 0.44, 0.45)
var map_water: Color = Color(0.17, 0.42, 0.56)

static var _looks: Dictionary[String, RegionLook] = {}


static func of(region: String) -> RegionLook:
	if _looks.has(region):
		return _looks[region]
	var k: RegionLook = RegionLook.new()
	match region:
		"desert":
			k.title = "Dustlands"
			k.lush = Color(0.66, 0.54, 0.34)
			k.dry = Color(0.77, 0.66, 0.44)
			k.soil = Color(0.52, 0.40, 0.26)
			k.litter_dark = Color(0.42, 0.36, 0.22)
			k.litter_light = Color(0.56, 0.47, 0.30)
			k.stone_dark = Color(0.42, 0.27, 0.20)
			k.stone_light = Color(0.66, 0.45, 0.33)
			k.sand_dark = Color(0.74, 0.66, 0.48)
			k.sand_light = Color(0.86, 0.79, 0.60)
			k.bed = Color(0.30, 0.40, 0.36)
			k.water_shallow = Color(0.22, 0.62, 0.60)
			k.water_deep = Color(0.05, 0.30, 0.40)
			k.water_foam = Color(0.92, 0.95, 0.90)
			k.trees = "dry"
			k.conifer_low = Color(0.22, 0.36, 0.20)
			k.conifer_high = Color(0.38, 0.52, 0.28)
			k.conifer_cap = Color(0.44, 0.58, 0.32)
			k.leaf_low = Color(0.30, 0.36, 0.14)
			k.leaf_high = Color(0.52, 0.56, 0.24)
			k.bark_low = Color(0.30, 0.22, 0.15)
			k.bark_high = Color(0.48, 0.37, 0.25)
			k.bush_low = Color(0.36, 0.36, 0.18)
			k.bush_high = Color(0.58, 0.55, 0.30)
			k.rock_low = Color(0.36, 0.22, 0.16)
			k.rock_high = Color(0.72, 0.50, 0.36)
			k.tuft_low = Color(0.50, 0.46, 0.24)
			k.tuft_high = Color(0.72, 0.66, 0.38)
			k.grass = 0.35
			k.flowers = 0.15
			k.bushes = 0.6
			k.sun_color = Color(1.0, 0.92, 0.76)
			k.sun_energy = 1.3
			k.ambient = 0.5
			k.map_ground = Color(0.62, 0.52, 0.33)
			k.map_forest = Color(0.42, 0.44, 0.22)
			k.map_rock = Color(0.50, 0.33, 0.25)
			k.map_water = Color(0.18, 0.52, 0.56)
		"tundra":
			k.title = "Frostline"
			k.lush = Color(0.70, 0.75, 0.82)
			k.dry = Color(0.82, 0.86, 0.91)
			k.soil = Color(0.42, 0.42, 0.45)
			k.litter_dark = Color(0.52, 0.58, 0.60)
			k.litter_light = Color(0.72, 0.76, 0.78)
			k.stone_dark = Color(0.30, 0.31, 0.34)
			k.stone_light = Color(0.60, 0.62, 0.66)
			k.sand_dark = Color(0.70, 0.78, 0.84)
			k.sand_light = Color(0.88, 0.93, 0.97)
			k.bed = Color(0.40, 0.52, 0.60)
			k.water_shallow = Color(0.62, 0.80, 0.88)
			k.water_deep = Color(0.24, 0.44, 0.60)
			k.water_foam = Color(0.97, 0.99, 1.0)
			k.trees = "snow"
			k.conifer_low = Color(0.07, 0.18, 0.14)
			k.conifer_high = Color(0.16, 0.32, 0.24)
			k.conifer_cap = Color(0.90, 0.93, 0.97)
			k.bark_low = Color(0.16, 0.12, 0.10)
			k.bark_high = Color(0.30, 0.23, 0.18)
			k.bush_low = Color(0.50, 0.58, 0.60)
			k.bush_high = Color(0.82, 0.88, 0.92)
			k.rock_low = Color(0.24, 0.25, 0.28)
			k.rock_high = Color(0.86, 0.89, 0.93)
			k.grass = 0.0
			k.flowers = 0.0
			k.reeds = false
			k.bushes = 0.5
			k.sun_color = Color(0.95, 0.97, 1.0)
			k.sun_energy = 1.05
			k.ambient = 0.55
			k.map_ground = Color(0.78, 0.82, 0.86)
			k.map_forest = Color(0.24, 0.38, 0.34)
			k.map_rock = Color(0.48, 0.50, 0.55)
			k.map_water = Color(0.40, 0.62, 0.76)
		"ashland":
			k.title = "Cinder Wastes"
			k.lush = Color(0.21, 0.20, 0.20)
			k.dry = Color(0.30, 0.28, 0.27)
			k.soil = Color(0.11, 0.10, 0.10)
			k.litter_dark = Color(0.10, 0.09, 0.09)
			k.litter_light = Color(0.19, 0.17, 0.16)
			k.stone_dark = Color(0.10, 0.10, 0.11)
			k.stone_light = Color(0.30, 0.28, 0.28)
			k.sand_dark = Color(0.12, 0.09, 0.08)
			k.sand_light = Color(0.20, 0.13, 0.10)
			k.bed = Color(0.08, 0.06, 0.06)
			k.water_shallow = Color(1.0, 0.62, 0.18)
			k.water_deep = Color(0.80, 0.16, 0.03)
			k.water_foam = Color(0.08, 0.06, 0.06)
			k.water_glow = 1.5
			k.trees = "dead"
			k.bark_low = Color(0.07, 0.06, 0.06)
			k.bark_high = Color(0.20, 0.17, 0.15)
			k.bush_low = Color(0.12, 0.11, 0.10)
			k.bush_high = Color(0.22, 0.19, 0.17)
			k.rock_low = Color(0.07, 0.07, 0.08)
			k.rock_high = Color(0.30, 0.28, 0.28)
			k.grass = 0.0
			k.flowers = 0.0
			k.reeds = false
			k.bushes = 0.25
			k.sun_color = Color(1.0, 0.80, 0.66)
			k.sun_energy = 1.05
			k.ambient = 0.42
			k.map_ground = Color(0.20, 0.19, 0.19)
			k.map_forest = Color(0.11, 0.10, 0.10)
			k.map_rock = Color(0.33, 0.31, 0.31)
			k.map_water = Color(0.70, 0.27, 0.08)
	_looks[region] = k
	return k
