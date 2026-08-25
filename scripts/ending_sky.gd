extends Node2D
## 엔딩용 하늘 + 흘러가는 구름 (월드 공간). 카메라가 위로 올라가면 드러남. 이미지 없이 코드로 그림.
## 로컬 (0,0)~(w,h) 사각형을 채운다. main이 위치/크기를 지정.

var w := 2000.0
var h := 3000.0
var _clouds: Array = []


func setup(width: float, height: float) -> void:
	w = width
	h = height
	_spawn_clouds()
	queue_redraw()


func _spawn_clouds() -> void:
	_clouds.clear()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var n := int(clampf((w * h) / 200000.0, 8.0, 40.0))
	for i in n:
		_clouds.append({
			# 아래쪽 투명 구간엔 구름 없이 -> 위쪽(불투명한 하늘)에만
			"pos": Vector2(rng.randf_range(0.0, w), rng.randf_range(h * 0.05, h * 0.55)),
			"s": rng.randf_range(0.7, 1.9),
			"spd": rng.randf_range(8.0, 26.0),
		})


func _process(delta: float) -> void:
	for c in _clouds:
		c["pos"].x += c["spd"] * delta
		if c["pos"].x - 160.0 * c["s"] > w:      # 오른쪽으로 나가면 왼쪽에서 다시
			c["pos"].x = -160.0 * c["s"]
	queue_redraw()


func _draw() -> void:
	# 하늘 그라데이션: 위(작은 y)=진한 하늘색, 아래=연함
	# 그리고 아래쪽은 서서히 투명해져 원래 배경색에서 자연스럽게 이어짐(딱 안 끊김)
	var top := Color(0.34, 0.60, 0.94)
	var bot := Color(0.87, 0.94, 1.0)
	var fade_start := 0.60  # 이 지점(위에서부터 비율)부터 아래로 알파가 1 -> 0
	var bands := 72
	for i in bands:
		var t0 := float(i) / float(bands)
		var col := top.lerp(bot, t0)
		if t0 > fade_start:
			col.a = 1.0 - (t0 - fade_start) / (1.0 - fade_start)
		draw_rect(Rect2(0.0, h * t0, w, h / float(bands) + 1.0), col)
	for c in _clouds:
		_draw_cloud(c["pos"], c["s"])


## 뭉게구름: 흰 원을 여러 개 겹쳐 폭신하게
func _draw_cloud(p: Vector2, s: float) -> void:
	var white := Color(1, 1, 1, 0.96)
	var puffs := [
		Vector2(0, 0), Vector2(-42, 8), Vector2(42, 8),
		Vector2(-20, -14), Vector2(24, -12), Vector2(0, 10),
	]
	var radii := [32.0, 22.0, 24.0, 20.0, 18.0, 26.0]
	for i in puffs.size():
		draw_circle(p + puffs[i] * s, radii[i] * s, white)
