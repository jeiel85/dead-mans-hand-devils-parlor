extends Node
## Procedural sound effects (no audio files) — same recipes as the web
## prototype's src/audio.js, rendered once at startup into AudioStreamWAV.

const RATE := 22050
var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0


func _ready() -> void:
	for i in range(8):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	_build_all()


func play(name: String, volume_db: float = 0.0) -> void:
	if not Save.sound:
		return
	if not _streams.has(name):
		return
	var p := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	p.stream = _streams[name]
	p.volume_db = volume_db
	p.play()


# ---------------------------------------------------------------------------
# Synthesis helpers (float buffers, then 16-bit PCM)
# ---------------------------------------------------------------------------

class Buf:
	var data: PackedFloat32Array

	func _init(seconds: float) -> void:
		data = PackedFloat32Array()
		data.resize(int(seconds * 22050))
		data.fill(0.0)

	func tone(freq: float, type: String, dur: float, gain: float, when: float = 0.0, slide_to: float = -1.0, attack: float = 0.005) -> void:
		var start := int(when * 22050)
		var n := int(dur * 22050)
		var phase := 0.0
		for i in range(n):
			var idx := start + i
			if idx >= data.size():
				break
			var t := float(i) / 22050.0
			var f := freq
			if slide_to > 0.0:
				f = freq * pow(slide_to / freq, t / dur)
			phase += f / 22050.0
			var v := 0.0
			match type:
				"sine":
					v = sin(phase * TAU)
				"square":
					v = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
				"triangle":
					v = 4.0 * absf(fmod(phase, 1.0) - 0.5) - 1.0
				"sawtooth":
					v = 2.0 * fmod(phase, 1.0) - 1.0
			var env := 1.0
			if t < attack:
				env = t / attack
			else:
				env = pow(0.0001, (t - attack) / maxf(0.001, dur - attack))
			data[idx] += v * gain * env

	func noise(dur: float, gain: float, cutoff: float, when: float = 0.0, highpass: bool = false) -> void:
		var start := int(when * 22050)
		var n := int(dur * 22050)
		var rng := RandomNumberGenerator.new()
		rng.seed = int(cutoff) + int(dur * 1000)
		var alpha := clampf(cutoff / 22050.0 * TAU, 0.001, 0.999)
		var lp := 0.0
		for i in range(n):
			var idx := start + i
			if idx >= data.size():
				break
			var t := float(i) / 22050.0
			var white := rng.randf_range(-1.0, 1.0)
			lp += alpha * (white - lp)
			var v := (white - lp) if highpass else lp
			var env := pow(0.0001, t / dur)
			data[idx] += v * gain * env

	func to_stream() -> AudioStreamWAV:
		var bytes := PackedByteArray()
		bytes.resize(data.size() * 2)
		for i in range(data.size()):
			var s := clampf(data[i], -1.0, 1.0)
			var v := int(s * 32767.0)
			bytes.encode_s16(i * 2, v)
		var wav := AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate = 22050
		wav.stereo = false
		wav.data = bytes
		return wav


func _build_all() -> void:
	var b: Buf

	b = Buf.new(0.12)
	b.tone(880, "triangle", 0.05, 0.10)
	_streams["select"] = b.to_stream()

	b = Buf.new(0.2)
	b.noise(0.12, 0.35, 3500)
	_streams["card"] = b.to_stream()

	b = Buf.new(0.12)
	b.tone(1600, "square", 0.03, 0.06)
	b.tone(2100, "square", 0.04, 0.06, 0.03)
	_streams["chip"] = b.to_stream()

	b = Buf.new(0.12)
	b.noise(0.05, 0.4, 5000, 0.0, true)
	b.tone(1200, "square", 0.03, 0.14)
	_streams["hammer"] = b.to_stream()

	b = Buf.new(0.25)
	b.noise(0.06, 0.55, 4000, 0.0, true)
	b.tone(900, "square", 0.04, 0.22)
	b.tone(300, "triangle", 0.08, 0.16, 0.01)
	_streams["click"] = b.to_stream()

	b = Buf.new(1.0)
	b.noise(0.5, 1.0, 900)
	b.noise(0.25, 0.7, 6000, 0.0, true)
	b.tone(140, "sine", 0.5, 0.9, 0.0, 40)
	b.tone(60, "sine", 0.8, 0.5, 0.02, 25)
	_streams["bang"] = b.to_stream()

	b = Buf.new(1.0)
	b.tone(220, "sawtooth", 0.9, 0.15, 0.0, 110)
	b.tone(233, "sawtooth", 0.9, 0.15, 0.0, 116)
	b.noise(0.9, 0.15, 600)
	_streams["curse"] = b.to_stream()

	b = Buf.new(0.4)
	b.noise(0.08, 0.45, 3000, 0.0, true)
	b.tone(500, "square", 0.05, 0.16)
	b.tone(700, "sine", 0.25, 0.1, 0.1)
	_streams["misfire"] = b.to_stream()

	b = Buf.new(0.35)
	b.tone(200, "sawtooth", 0.3, 0.22, 0.0, 80)
	_streams["hurt"] = b.to_stream()

	b = Buf.new(0.45)
	b.tone(523, "sine", 0.15, 0.16)
	b.tone(784, "sine", 0.25, 0.16, 0.12)
	_streams["heal"] = b.to_stream()

	b = Buf.new(0.7)
	for i in range(6):
		b.tone(700 + i * 40, "square", 0.03, 0.09, i * 0.07)
	b.noise(0.15, 0.3, 2500, 0.45)
	_streams["reload"] = b.to_stream()

	b = Buf.new(0.5)
	b.tone(660, "square", 0.08, 0.16)
	b.tone(440, "square", 0.12, 0.16, 0.09)
	b.tone(220, "square", 0.25, 0.16, 0.2)
	_streams["caught"] = b.to_stream()

	b = Buf.new(1.0)
	var i := 0
	for f in [523, 659, 784, 1046]:
		b.tone(f, "triangle", 0.35, 0.2, i * 0.13)
		i += 1
	_streams["win"] = b.to_stream()

	b = Buf.new(1.8)
	i = 0
	for f in [392, 349, 311, 233]:
		b.tone(f, "sawtooth", 0.5, 0.13, i * 0.3)
		i += 1
	b.noise(1.5, 0.1, 400, 0.2)
	_streams["lose"] = b.to_stream()

	b = Buf.new(0.05)
	b.tone(1400, "square", 0.02, 0.06)
	_streams["tick"] = b.to_stream()

	b = Buf.new(0.06)
	b.tone(1800, "square", 0.03, 0.1)
	_streams["tickUrgent"] = b.to_stream()
