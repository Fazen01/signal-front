class_name SimCommand
extends RefCounted
## A player's instruction to the simulation. The UI and the AI both create
## these and hand them to SimWorld.push_command(); they are applied at the
## start of the next tick. This is the only way anything outside sim/ changes
## simulation state.

enum Type {
	MOVE, ATTACK, ATTACK_MOVE, STOP, HOLD, HARVEST, BUILD, REPAIR, TRAIN, CANCEL_TRAIN,
	CANCEL_BUILDING, RALLY, CAPTURE, DIRECTIVE, SURRENDER, UNLOCK, DEPLOY, PACK,
}

var type: int = Type.MOVE
var player: int = 0
var ids: PackedInt32Array = PackedInt32Array()
var pos: Vector2 = Vector2.ZERO
var target_id: int = 0
var def_id: String = ""
var cell: Vector2i = Vector2i.ZERO
var index: int = 0
var queue: bool = false


static func move(p: int, unit_ids: PackedInt32Array, at: Vector2, queued: bool = false) -> SimCommand:
	var c: SimCommand = SimCommand.new()
	c.type = Type.MOVE
	c.player = p
	c.ids = unit_ids
	c.pos = at
	c.queue = queued
	return c


static func attack(p: int, unit_ids: PackedInt32Array, target: int, queued: bool = false) -> SimCommand:
	var c: SimCommand = SimCommand.new()
	c.type = Type.ATTACK
	c.player = p
	c.ids = unit_ids
	c.target_id = target
	c.queue = queued
	return c


static func attack_move(p: int, unit_ids: PackedInt32Array, at: Vector2, queued: bool = false) -> SimCommand:
	var c: SimCommand = SimCommand.new()
	c.type = Type.ATTACK_MOVE
	c.player = p
	c.ids = unit_ids
	c.pos = at
	c.queue = queued
	return c


static func stop(p: int, unit_ids: PackedInt32Array) -> SimCommand:
	var c: SimCommand = SimCommand.new()
	c.type = Type.STOP
	c.player = p
	c.ids = unit_ids
	return c


static func hold(p: int, unit_ids: PackedInt32Array) -> SimCommand:
	var c: SimCommand = SimCommand.new()
	c.type = Type.HOLD
	c.player = p
	c.ids = unit_ids
	return c


static func harvest(p: int, unit_ids: PackedInt32Array, target: int, queued: bool = false) -> SimCommand:
	var c: SimCommand = SimCommand.new()
	c.type = Type.HARVEST
	c.player = p
	c.ids = unit_ids
	c.target_id = target
	c.queue = queued
	return c


## Place a new building with its top-left footprint cell at `at_cell` and send
## the given builders to construct it.
static func build(p: int, unit_ids: PackedInt32Array, building_def: String, at_cell: Vector2i, queued: bool = false) -> SimCommand:
	var c: SimCommand = SimCommand.new()
	c.type = Type.BUILD
	c.player = p
	c.ids = unit_ids
	c.def_id = building_def
	c.cell = at_cell
	c.queue = queued
	return c


## Send builders to help construct or repair an existing building.
static func repair(p: int, unit_ids: PackedInt32Array, target: int, queued: bool = false) -> SimCommand:
	var c: SimCommand = SimCommand.new()
	c.type = Type.REPAIR
	c.player = p
	c.ids = unit_ids
	c.target_id = target
	c.queue = queued
	return c


## Send Field Engineers to capture an uplink site.
static func capture(p: int, unit_ids: PackedInt32Array, target: int, queued: bool = false) -> SimCommand:
	var c: SimCommand = SimCommand.new()
	c.type = Type.CAPTURE
	c.player = p
	c.ids = unit_ids
	c.target_id = target
	c.queue = queued
	return c


## Send deployable units (the Foundry Crawler) to set up with their
## footprint's top-left cell at `at_cell`.
static func deploy(p: int, unit_ids: PackedInt32Array, at_cell: Vector2i, queued: bool = false) -> SimCommand:
	var c: SimCommand = SimCommand.new()
	c.type = Type.DEPLOY
	c.player = p
	c.ids = unit_ids
	c.cell = at_cell
	c.queue = queued
	return c


## Pack a deployed building back up into its unit.
static func pack(p: int, building: int) -> SimCommand:
	var c: SimCommand = SimCommand.new()
	c.type = Type.PACK
	c.player = p
	c.target_id = building
	return c


static func train(p: int, building: int, unit_def: String) -> SimCommand:
	var c: SimCommand = SimCommand.new()
	c.type = Type.TRAIN
	c.player = p
	c.target_id = building
	c.def_id = unit_def
	return c


static func cancel_train(p: int, building: int, queue_index: int) -> SimCommand:
	var c: SimCommand = SimCommand.new()
	c.type = Type.CANCEL_TRAIN
	c.player = p
	c.target_id = building
	c.index = queue_index
	return c


static func cancel_building(p: int, building: int) -> SimCommand:
	var c: SimCommand = SimCommand.new()
	c.type = Type.CANCEL_BUILDING
	c.player = p
	c.target_id = building
	return c


static func rally(p: int, building: int, at: Vector2) -> SimCommand:
	var c: SimCommand = SimCommand.new()
	c.type = Type.RALLY
	c.player = p
	c.target_id = building
	c.pos = at
	return c


## Spend Command Points to unlock a Directive.
static func unlock(p: int, directive_id: String) -> SimCommand:
	var c: SimCommand = SimCommand.new()
	c.type = Type.UNLOCK
	c.player = p
	c.def_id = directive_id
	return c


## Use an unlocked Directive at a position (ignored by untargeted ones).
static func directive(p: int, directive_id: String, at: Vector2) -> SimCommand:
	var c: SimCommand = SimCommand.new()
	c.type = Type.DIRECTIVE
	c.player = p
	c.def_id = directive_id
	c.pos = at
	return c


static func surrender(p: int) -> SimCommand:
	var c: SimCommand = SimCommand.new()
	c.type = Type.SURRENDER
	c.player = p
	return c
