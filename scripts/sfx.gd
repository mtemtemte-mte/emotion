extends Node
## 코드로 생성하는 간단한 효과음 (외부 음원 파일 없음). 오토로드로 등록해 Sfx.play("이름") 호출.

const MIX_RATE := 22050.0

var _players: Array[AudioStreamPlayer] = []
var _idx := 0
var _streams := {}


func _ready() -> void:
	# 동시 재생용 플레이어 풀
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)

	# 각 효과음 생성 (t=초, p=0~1 진행도)
	_streams["jump"] = _synth(0.15, func(t, p):
		var freq: float = lerpf(420.0, 780.0, p)
		return sin(TAU * freq * t) * (1.0 - p) * 0.5)

	_streams["land"] = _synth(0.12, func(t, p):
		var freq: float = lerpf(220.0, 90.0, p)
		return sin(TAU * freq * t) * (1.0 - p) * 0.5)

	_streams["break"] = _synth(0.26, func(t, p):
		return (randf() * 2.0 - 1.0) * pow(1.0 - p, 1.5) * 0.6)

	_streams["knockback"] = _synth(0.32, func(t, p):
		var sq := 1.0 if sin(TAU * 110.0 * t) > 0.0 else -1.0
		return sq * (1.0 - p) * 0.4)

	_streams["switch"] = _synth(0.18, func(t, p):
		var freq := 660.0 if p < 0.5 else 990.0
		return sin(TAU * freq * t) * (1.0 - p) * 0.4)


func play(name: String) -> void:
	if not _streams.has(name):
		return
	var p := _players[_idx]
	_idx = (_idx + 1) % _players.size()
	p.stream = _streams[name]
	p.play()


## duration초 동안 gen(t, p) -> [-1,1] 을 16bit PCM으로 만들어 AudioStreamWAV 반환
func _synth(duration: float, gen: Callable) -> AudioStreamWAV:
	var n := int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / MIX_RATE
		var v: float = clampf(gen.call(t, float(i) / float(n)), -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = int(MIX_RATE)
	w.stereo = false
	w.data = data
	return w
