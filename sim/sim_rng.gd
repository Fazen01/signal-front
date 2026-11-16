class_name SimRng
extends RefCounted
## Small seeded generator (Park-Miller MINSTD). The simulation uses only this,
## never the global random functions, so a match replays identically from a seed.

const MODULUS: int = 2147483647
const MULTIPLIER: int = 48271

var state: int = 1


func _init(seed_value: int = 1) -> void:
	reseed(seed_value)


func reseed(seed_value: int) -> void:
	var s: int = absi(seed_value) % 1000000007
	state = (s * 69069 + 12345) % (MODULUS - 1) + 1
	# Discard a few values so nearby seeds diverge quickly.
	for i: int in 4:
		next_int()


## Next raw value in [1, MODULUS - 1].
func next_int() -> int:
	state = (state * MULTIPLIER) % MODULUS
	return state


## Uniform float in [0, 1).
func next_float() -> float:
	return float(next_int() - 1) / float(MODULUS - 1)


func range_f(from: float, to: float) -> float:
	return from + (to - from) * next_float()


## Uniform integer in [from, to], inclusive.
func range_i(from: int, to: int) -> int:
	if to <= from:
		return from
	return from + (next_int() - 1) % (to - from + 1)


func chance(probability: float) -> bool:
	return next_float() < probability
