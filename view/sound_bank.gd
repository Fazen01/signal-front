class_name SoundBank
extends RefCounted
## Every sound in the game, synthesised from noise and sine waves the first
## time it is needed. Nothing is loaded from disk.

const RATE: int = 22050

static var _cache: Dictionary[String, AudioStreamWAV] = {}


static func stream(sound: String) -> AudioStreamWAV:
	if _cache.has(sound):
		return _cache[sound]
	var s: AudioStreamWAV = _build(sound)
	_cache[sound] = s
	return s


static func names() -> Array[String]:
	return [
		"shot", "shot_heavy", "missile", "cannon", "explosion", "explosion_big", "ack", "select",
		"place", "ready", "alert", "error", "deposit", "directive", "rank", "click", "ambient",
	]


static func _build(sound: String) -> AudioStreamWAV:
	var rng: SimRng = SimRng.new(sound.hash())
	match sound:
		"shot":
			return _wav(_mix(_noise(rng, 0.11, 0.55, 42.0, 0.9), _tone(0.05, 900.0, 300.0, 60.0, 0.25)))
		"shot_heavy":
			return _wav(_mix(_noise(rng, 0.24, 0.3, 17.0, 0.95), _tone(0.2, 150.0, 60.0, 18.0, 0.6)))
		"cannon":
			return _wav(_mix(_noise(rng, 0.45, 0.2, 9.0, 0.95), _tone(0.4, 110.0, 40.0, 9.0, 0.8)))
		"missile":
			return _wav(_mix(_noise(rng, 0.55, 0.4, 5.5, 0.6), _tone(0.5, 320.0, 900.0, 5.0, 0.18)))
		"explosion":
			return _wav(_mix(_noise(rng, 0.9, 0.13, 5.0, 1.0), _tone(0.7, 70.0, 35.0, 6.0, 0.8)))
		"explosion_big":
			return _wav(_mix(_noise(rng, 1.5, 0.08, 3.0, 1.0), _tone(1.2, 55.0, 26.0, 3.5, 0.9)))
		"ack":
			return _wav(_tone(0.07, 880.0, 880.0, 30.0, 0.35))
		"select":
			return _wav(_tone(0.05, 660.0, 760.0, 40.0, 0.25))
		"place":
			return _wav(_join(_tone(0.07, 440.0, 440.0, 22.0, 0.4), _tone(0.1, 660.0, 660.0, 18.0, 0.4)))
		"ready":
			return _wav(_join(_tone(0.08, 660.0, 660.0, 20.0, 0.35), _tone(0.14, 990.0, 990.0, 14.0, 0.35)))
		"alert":
			return _wav(_join(_join(_tone(0.11, 520.0, 520.0, 8.0, 0.45), _silence(0.05)), _tone(0.14, 520.0, 520.0, 8.0, 0.45)))
		"error":
			return _wav(_tone(0.16, 170.0, 150.0, 10.0, 0.45))
		"deposit":
			return _wav(_tone(0.05, 1250.0, 1500.0, 45.0, 0.2))
		"directive":
			return _wav(_mix(_tone(0.7, 220.0, 55.0, 4.0, 0.6), _noise(rng, 0.7, 0.1, 4.5, 0.4)))
		"rank":
			return _wav(_join(_join(_tone(0.08, 660.0, 660.0, 16.0, 0.3), _tone(0.08, 880.0, 880.0, 16.0, 0.3)), _tone(0.16, 1100.0, 1100.0, 10.0, 0.3)))
		"click":
			return _wav(_tone(0.03, 1000.0, 700.0, 80.0, 0.25))
		"ambient":
			return _ambient(rng)
		_:
			return _wav(_silence(0.05))


# ---------------------------------------------------------- generators

static func _silence(seconds: float) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(int(seconds * float(RATE)))
	return out


## Low-passed white noise with an exponential decay. `smooth` near 0 is a
## dull rumble, near 1 is bright hiss.
static func _noise(rng: SimRng, seconds: float, smooth: float, decay: float, gain: float) -> PackedFloat32Array:
	var n: int = int(seconds * float(RATE))
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var y: float = 0.0
	for i: int in n:
		var t: float = float(i) / float(RATE)
		y += smooth * ((rng.next_float() * 2.0 - 1.0) - y)
		var attack: float = minf(1.0, t * 400.0)
		out[i] = y * exp(-t * decay) * attack * gain * (1.0 + (1.0 - smooth) * 2.0)
	return out


## A sine that glides from f0 to f1 with an exponential decay.
static func _tone(seconds: float, f0: float, f1: float, decay: float, gain: float) -> PackedFloat32Array:
	var n: int = int(seconds * float(RATE))
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var phase: float = 0.0
	for i: int in n:
		var t: float = float(i) / float(RATE)
		var k: float = float(i) / float(maxi(n - 1, 1))
		phase += TAU * lerpf(f0, f1, k) / float(RATE)
		var edge: float = minf(1.0, t * 300.0) * minf(1.0, (seconds - t) * 300.0)
		out[i] = sin(phase) * exp(-t * decay) * edge * gain
	return out


static func _mix(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var n: int = maxi(a.size(), b.size())
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	for i: int in n:
		var v: float = 0.0
		if i < a.size():
			v += a[i]
		if i < b.size():
			v += b[i]
		out[i] = v
	return out


static func _join(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var out: PackedFloat32Array = a.duplicate()
	out.append_array(b)
	return out


static func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i: int in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	return wav


## A seamless loop of soft air, barely there: slow, low-passed noise that
## swells and falls a little over half a minute. (It used to be a
## six-second loop that pulsed every two seconds over a steady hum, and the
## owner's first words on hearing the game were "annoying constant wind
## noise".) The loudness is set where it is played, not here.
static func _ambient(rng: SimRng) -> AudioStreamWAV:
	var seconds: float = 30.0
	var n: int = int(seconds * float(RATE))
	var fade: int = RATE * 2  # two seconds of cross-fade to hide the loop point
	var raw: PackedFloat32Array = PackedFloat32Array()
	raw.resize(n + fade)
	var y: float = 0.0
	var z: float = 0.0
	for i: int in n + fade:
		var t: float = float(i) / float(RATE)
		y += 0.035 * ((rng.next_float() * 2.0 - 1.0) - y)
		z += 0.06 * (y - z)
		# Whole numbers of cycles in the loop, so that it joins up, and far
		# enough apart that no beat can be heard in it.
		var swell: float = 0.8 + 0.13 * sin(TAU * t / seconds) + 0.07 * sin(TAU * 3.0 * t / seconds + 1.3)
		raw[i] = z * 5.0 * swell
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	for i: int in n:
		var v: float = raw[i]
		if i < fade:
			var k: float = float(i) / float(fade)
			v = raw[i] * k + raw[n + i] * (1.0 - k)
		out[i] = v * 0.5
	var wav: AudioStreamWAV = _wav(out)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n
	return wav
