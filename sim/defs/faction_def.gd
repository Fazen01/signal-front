class_name FactionDef
extends RefCounted
## One faction definition, loaded from data/factions.json.

var id: String = ""
var name: String = ""
var desc: String = ""
var hq: String = ""
var start_units: Array[String] = []
var linked_range_bonus: float = 0.0
var dark_rof_mult: float = -1.0  ## -1 = use the global rule
var playable: bool = true
