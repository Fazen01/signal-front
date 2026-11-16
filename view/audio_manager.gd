class_name AudioManager
extends Node
## Plays the synthesised sounds: a small pool of voices for effects, quieter
## with distance from where the camera is looking, and a looping ambient bed.

const VOICES: int = 14
const HEARING_RANGE: float = 95.0

var listener: Vector2 = Vector2.ZERO  ## world x, z the camera looks at
var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
var _last_played: Dictionary[String, int] = {}  ## sound -> msec, to thin out bursts
var _ambient: AudioStreamPlayer = null
var played_count: int = 0


func _ready() -> void:
	GameSettings.ensure_loaded()
	for i: int in VOICES:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	_ambient = AudioStreamPlayer.new()
	_ambient.bus = "Ambient"
	_ambient.stream = SoundBank.stream("ambient")
	_ambient.volume_db = -6.0
	add_child(_ambient)
	_ambient.play()


## A sound at a world position; fades with distance from the listener.
func play_at(sound: String, at: Vector2, gap_ms: int = 45, gain_db: float = 0.0) -> void:
	var d: float = at.distance_to(listener)
	if d > HEARING_RANGE:
		return
	_play(sound, gain_db - 26.0 * (d / HEARING_RANGE), gap_ms)


## An interface sound at full volume.
func play_ui(sound: String, gain_db: float = -4.0) -> void:
	_play(sound, gain_db, 30)


func _play(sound: String, volume_db: float, gap_ms: int) -> void:
	var now: int = Time.get_ticks_msec()
	if now - _last_played.get(sound, -100000) < gap_ms:
		return
	_last_played[sound] = now
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = SoundBank.stream(sound)
	p.volume_db = volume_db
	p.pitch_scale = 0.94 + 0.12 * fposmod(float(now) * 0.0137, 1.0)
	p.play()
	played_count += 1
