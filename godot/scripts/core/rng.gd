class_name SeededRng
extends RefCounted
## Deterministic RNG identical to the web prototype (src/rng.js):
## xmur3 string hash -> mulberry32 stream. The same seed produces the same
## deal, cylinder and dealer decisions on web and in Godot.

const MASK32 := 0xFFFFFFFF

var seed_text: String
var _state: int = 0


func _init(seed_value: String) -> void:
	seed_text = seed_value
	_state = _xmur3(seed_value)


static func _imul(a: int, b: int) -> int:
	# 32-bit multiply keeping the low 32 bits (Math.imul). int64 wraps silently,
	# and wrapping preserves the low bits we need.
	return ((a & MASK32) * (b & MASK32)) & MASK32


static func _xmur3(s: String) -> int:
	var h: int = (1779033703 ^ s.length()) & MASK32
	for i in range(s.length()):
		h = _imul(h ^ s.unicode_at(i), 3432918353)
		h = ((h << 13) | (h >> 19)) & MASK32
	# JS: the returned generator is called once to produce the mulberry seed.
	h = _imul(h ^ (h >> 16), 2246822507)
	h = _imul(h ^ (h >> 13), 3266489909)
	h = (h ^ (h >> 16)) & MASK32
	return h


## Next float in [0, 1).
func next() -> float:
	_state = (_state + 0x6D2B79F5) & MASK32
	var t: int = _state
	t = _imul(t ^ (t >> 15), (1 | t) & MASK32)
	t = (t + _imul(t ^ (t >> 7), (61 | t) & MASK32)) ^ t
	t &= MASK32
	return float((t ^ (t >> 14)) & MASK32) / 4294967296.0


func int_below(n: int) -> int:
	return int(floor(next() * n))


func chance(p: float) -> bool:
	return next() < p


func pick(arr: Array) -> Variant:
	return arr[int(floor(next() * arr.size()))]


## In-place Fisher-Yates, same iteration order as the JS version.
func shuffle(arr: Array) -> Array:
	var i := arr.size() - 1
	while i > 0:
		var j := int(floor(next() * (i + 1)))
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
		i -= 1
	return arr


static func random_seed() -> String:
	var alphabet := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var s := ""
	for i in range(6):
		s += alphabet[randi() % alphabet.length()]
	return s
