extends TestCase
## The procedural sound bank and settings.


func test_every_sound_is_synthesised() -> void:
	for sound: String in SoundBank.names():
		var wav: AudioStreamWAV = SoundBank.stream(sound)
		check(wav != null, "%s exists" % sound)
		if wav == null:
			continue
		check_eq(wav.mix_rate, SoundBank.RATE, "%s sample rate" % sound)
		check(wav.data.size() > 400, "%s has samples (%d bytes)" % [sound, wav.data.size()])
		var peak: int = 0
		var i: int = 0
		while i + 1 < wav.data.size():
			peak = maxi(peak, absi(wav.data.decode_s16(i)))
			i += 2
		check(peak > 1500, "%s is audible (peak %d)" % [sound, peak])
		check(peak <= 32000, "%s does not clip" % sound)


func test_sounds_are_cached_and_deterministic() -> void:
	var a: AudioStreamWAV = SoundBank.stream("explosion")
	var b: AudioStreamWAV = SoundBank.stream("explosion")
	check(a == b, "the same stream is reused")
	check(SoundBank.stream("ambient").loop_mode == AudioStreamWAV.LOOP_FORWARD, "the ambient bed loops")


func test_settings_apply_to_audio_buses() -> void:
	GameSettings.set_volume("SFX", 0.5)
	var index: int = AudioServer.get_bus_index("SFX")
	check(index >= 0, "the SFX bus exists")
	check_near(AudioServer.get_bus_volume_db(index), linear_to_db(0.5), 0.01, "volume applied")
	GameSettings.set_volume("SFX", 0.0)
	check(AudioServer.is_bus_mute(index), "zero volume mutes the bus")
	GameSettings.set_volume("SFX", 0.8)
	check(not AudioServer.is_bus_mute(index), "raising it un-mutes")
	check(AudioServer.get_bus_index("Ambient") >= 0, "the Ambient bus exists")
