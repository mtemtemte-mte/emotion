@tool
extends Area2D
## 플레이어가 닿으면 말풍선을 띄우는 하늘색 NPC.
## 닿으면 꼬리 끝에서 팝 하고 커지고, 대사가 한 글자씩 타이핑되며 언더테일식 소리가 남.
## 글자는 물결치듯 흔들림. 플레이어가 멀어지면 다시 꼬리 끝으로 쏙 들어감. (에디터에서 직접 배치)

const RADIUS := 26.0

@export_multiline var dialogue := "분노로 해결할려하지마":
	set(v):
		dialogue = v
		_apply_text()
		_fit_bubble()
		queue_redraw()

# 밝은 하늘색
@export var color := Color(0.55, 0.80, 1.0):
	set(v):
		color = v
		queue_redraw()

# 말풍선 배치 (NPC 중심 기준) — 왼쪽 위. 크기는 텍스트를 재서 자동으로 딱 맞춤(_fit_bubble).
const BUBBLE_OFFSET := Vector2(-165, -140)
var BUBBLE_SIZE := Vector2(290, 120)  # 측정 전 기본값 -> 텍스트에 맞게 갱신됨
const TIP := Vector2(-2.0, -RADIUS - 2.0)   # 꼬리 끝점(= 커지는 기준점, NPC 머리 위)

# 꼬리가 타원에 붙는 입구(NPC 방향, 우하단) 각도 범위
const MOUTH_A := PI * 0.12
const MOUTH_B := PI * 0.30

const TYPE_INTERVAL := 0.045  # 글자 하나가 나오는 간격(초)
const POP_TIME := 0.28        # 말풍선 등장 시간
const CLOSE_TIME := 0.18      # 사라짐 시간

var rt: RichTextLabel
var _scale := 0.0             # 말풍선 크기 0~1 (꼬리 끝 기준)
var _type_t := 0.0
var _shown := 0               # 지금까지 드러난 글자 수
var _talking := false
var _pop_tween: Tween


func _ready() -> void:
	z_index = 5
	_build_bubble_text()
	if Engine.is_editor_hint():
		return
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _build_bubble_text() -> void:
	# 꼬리 끝을 원점으로 하는 피벗 노드 -> 스케일하면 꼬리 끝에서 커짐
	var pivot := Node2D.new()
	pivot.name = "BubblePivot"
	pivot.position = TIP
	add_child(pivot)

	rt = RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.scroll_active = false
	rt.clip_contents = false          # 물결칠 때 글자 안 잘리게
	rt.fit_content = false
	rt.autowrap_mode = TextServer.AUTOWRAP_OFF   # 짧은 대사는 한 줄로 (크기 측정용)
	rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rt.add_theme_font_size_override("normal_font_size", 25)
	rt.add_theme_color_override("default_color", Color(0.12, 0.12, 0.14))
	rt.visible_characters = 0
	pivot.add_child(rt)
	_apply_text()
	_fit_bubble()   # 텍스트 크기 측정 -> 말풍선 딱 맞게 + 정중앙


func _apply_text() -> void:
	if rt:
		# [wave]로 글자마다 위아래 물결 + [center] 가운데 정렬
		rt.text = "[center][wave amp=18.0 freq=4.0]%s[/wave][/center]" % dialogue


## 텍스트 실제 크기를 재서 말풍선을 딱 맞게 하고, 텍스트를 정중앙에 둔다.
func _fit_bubble() -> void:
	if rt == null:
		return
	await get_tree().process_frame   # 콘텐츠 크기 계산에 한 프레임 필요
	if rt == null:
		return
	var cw := rt.get_content_width()
	var ch := rt.get_content_height()
	if cw <= 0 or ch <= 0:
		await get_tree().process_frame
		cw = rt.get_content_width()
		ch = rt.get_content_height()
	rt.size = Vector2(cw, ch)
	rt.position = BUBBLE_OFFSET - Vector2(cw, ch) * 0.5 - TIP   # 말풍선 정중앙
	BUBBLE_SIZE = Vector2(cw * 1.34 + 34.0, ch * 1.7 + 30.0)    # 타원이 텍스트를 넉넉히 감싸게
	queue_redraw()


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_talking = true
	_shown = 0
	_type_t = 0.0
	if rt:
		rt.visible_characters = 0
	_pop(1.0, POP_TIME, Tween.TRANS_BACK)   # 살짝 오버슈트하며 팝


func _on_body_exited(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_talking = false
	_pop(0.0, CLOSE_TIME, Tween.TRANS_CUBIC)  # 꼬리 끝으로 쏙


func _pop(target: float, time: float, trans: Tween.TransitionType) -> void:
	if _pop_tween and _pop_tween.is_valid():
		_pop_tween.kill()
	_pop_tween = create_tween()
	_pop_tween.set_trans(trans).set_ease(Tween.EASE_OUT)
	_pop_tween.tween_method(_set_scale, _scale, target, time)


func _set_scale(s: float) -> void:
	_scale = s
	var pivot := get_node_or_null("BubblePivot") as Node2D
	if pivot:
		pivot.scale = Vector2(s, s)
	queue_redraw()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	# 다 커진 뒤에 한 글자씩 드러내며 글자마다 블립 (공백/줄바꿈은 소리 없이)
	if _talking and _scale > 0.9 and _shown < dialogue.length():
		_type_t += delta
		while _type_t >= TYPE_INTERVAL and _shown < dialogue.length():
			_type_t -= TYPE_INTERVAL
			_shown += 1
			rt.visible_characters = _shown
			var ch := dialogue[_shown - 1]
			if ch != " " and ch != "\n":
				Sfx.play("talk")


func _draw() -> void:
	_draw_glow_circle()
	if _scale > 0.001:
		_draw_bubble()


## 플레이어와 같은 빛나는 구슬 스타일 (하늘색). 안쪽 밝게(HDR) -> 글로우.
func _draw_glow_circle() -> void:
	var steps := 20
	for i in steps:
		var t := 1.0 - float(i) / float(steps - 1)
		var r := lerpf(3.0, RADIUS, t)
		var b := lerpf(2.3, 0.95, t)
		draw_circle(Vector2.ZERO, r, Color(color.r * b, color.g * b, color.b * b))


## 흰 타원 말풍선 + 꼬리. 꼬리 끝(TIP)에서 _scale 만큼 커진 상태로 그림.
## 외곽선은 타원 호 + 꼬리를 하나로 이어 그려 이음새가 없음.
func _draw_bubble() -> void:
	var c := BUBBLE_OFFSET
	var hw := BUBBLE_SIZE.x * 0.5
	var hh := BUBBLE_SIZE.y * 0.5
	var fill := Color(1, 1, 1, 1)
	var line := Color(0.13, 0.13, 0.16, 1)

	# 꼬리 입구 두 점(타원 위)
	var ea := _ellipse(c, hw, hh, MOUTH_A)
	var eb := _ellipse(c, hw, hh, MOUTH_B)

	# --- 채우기: 타원 본체 + 꼬리 삼각형 ---
	var body := PackedVector2Array()
	var n := 72
	for i in n:
		body.append(_ellipse(c, hw, hh, TAU * float(i) / float(n)))
	draw_colored_polygon(_scaled(body), fill)
	draw_colored_polygon(_scaled(PackedVector2Array([ea, eb, TIP])), fill)

	# --- 외곽선: 입구(MOUTH_A~MOUTH_B) 짧은 호는 빼고 긴 호를 그린 뒤 꼬리로 닫음 ---
	var outline := PackedVector2Array()
	var span := TAU - (MOUTH_B - MOUTH_A)     # 긴 호 각도
	var seg := 72
	for i in seg + 1:
		var a: float = MOUTH_B + span * float(i) / float(seg)  # eb -> (긴 호) -> ea
		outline.append(_ellipse(c, hw, hh, a))
	outline.append(TIP)                        # ea -> 꼬리 끝
	outline.append(outline[0])                 # 꼬리 끝 -> eb (닫기)
	draw_polyline(_scaled(outline), line, 2.0, true)


func _ellipse(c: Vector2, hw: float, hh: float, a: float) -> Vector2:
	return c + Vector2(cos(a) * hw, sin(a) * hh)


## 꼬리 끝(TIP)을 기준으로 _scale 만큼 축소/확대한 점들
func _scaled(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(TIP + (p - TIP) * _scale)
	return out
