extends CharacterBody2D
## 감정에 따라 능력이 바뀌는 동그라미 플레이어 (점프킹식 조작)

signal emotion_changed(display_name: String, color: Color, ability: String)

enum Emotion { NEUTRAL, ANGER, FEAR, JOY, SADNESS }

const RADIUS := 24.0
const GRAVITY := 1200.0

# 감정별 스탯 표 (ability = HUD에 보여줄 능력 설명)
const STATS := {
	Emotion.NEUTRAL: {"speed": 220.0, "jump": 520.0, "name": "기본", "color": Color(0.82, 0.82, 0.88), "ability": "기본 이동 · 기본 점프"},
	Emotion.ANGER:   {"speed": 220.0, "jump": 380.0, "name": "분노", "color": Color(0.90, 0.25, 0.20), "ability": "금 간 벽 파괴 · 낮은 점프"},
	Emotion.FEAR:    {"speed": 340.0, "jump": 520.0, "name": "공포", "color": Color(0.55, 0.30, 0.78), "ability": "빠른 이동 · 미끄러짐"},
	Emotion.JOY:     {"speed": 130.0, "jump": 730.0, "name": "기쁨", "color": Color(1.00, 0.84, 0.22), "ability": "높은 점프 · 느린 이동"},
	Emotion.SADNESS: {"speed": 130.0, "jump": 520.0, "name": "슬픔", "color": Color(0.25, 0.55, 0.92), "ability": "벽 붙기 · 느린 이동"},
}

const NORMAL_ACCEL := 4000.0   # 일반 지상 가속(딱딱 멈춤)
const FEAR_ACCEL := 480.0      # 공포: 낮은 가속 -> 미끄러짐 (낮을수록 더 미끄러움)
const SAD_SLIDE_SPEED := 60.0  # 슬픔: 벽에 붙어 천천히 흘러내리는 속도
const STUN_TIME := 2.0         # 넉백 벽에 부딪혔을 때 조작 불가 시간
const KNOCKBACK_FORCE := 420.0

const SAFE_FALL := 320.0       # 낙하 기절: 이보다 적게 떨어지면 기절 안 함(일반 점프)
const FALL_STEP := 180.0       # 이 높이(px)마다 기절 +0.1초
const FALL_STUN_BASE := 0.5    # 기본 낙하 기절 시간
const MAX_FALL_STUN := 2.5     # 최대 낙하 기절 시간

var emotion: Emotion = Emotion.NEUTRAL
var stun_timer := 0.0

var wheel: Control                       # 감정 선택 휠 (레벨에서 주입)
var wheel_open := false
var wheel_prev_pick: Emotion = Emotion.NEUTRAL


var dust: CPUParticles2D
var _was_on_floor := true
var _air_min_y := 0.0  # 공중에서 도달한 가장 높은 지점(최소 y)


func _ready() -> void:
	add_to_group("player")
	_make_dust()
	_air_min_y = global_position.y  # 스폰 시 잘못된 낙하 기절 방지
	set_emotion(Emotion.NEUTRAL)


func _make_dust() -> void:
	# 점프 순간 발밑에 뿜는 먼지 퍼프
	dust = CPUParticles2D.new()
	dust.position = Vector2(0, RADIUS)      # 발밑
	dust.local_coords = false               # 뿜은 뒤 제자리에 남음
	dust.emitting = false
	dust.one_shot = true
	dust.explosiveness = 0.9                # 한 번에 팡
	dust.amount = 14
	dust.lifetime = 0.5
	dust.direction = Vector2(0, -1)
	dust.spread = 85.0                      # 좌우로 퍼짐
	dust.gravity = Vector2(0, 500)          # 살짝 떴다 가라앉음
	dust.initial_velocity_min = 45.0
	dust.initial_velocity_max = 120.0
	dust.scale_amount_min = 4.0
	dust.scale_amount_max = 9.0
	var grad := Gradient.new()
	grad.set_color(0, Color(0.92, 0.92, 0.88, 0.9))
	grad.set_color(1, Color(0.92, 0.92, 0.88, 0.0))  # 서서히 사라짐
	dust.color_ramp = grad
	add_child(dust)


func _emit_dust() -> void:
	if dust:
		var c: Color = STATS[emotion]["color"]  # 감정 색 그대로
		var grad := dust.color_ramp as Gradient
		grad.set_color(0, Color(c.r, c.g, c.b, 0.95))
		grad.set_color(1, Color(c.r, c.g, c.b, 0.0))  # 서서히 사라짐
		dust.restart()


func set_wheel(w: Control) -> void:
	wheel = w


func _physics_process(delta: float) -> void:
	# 중력은 항상 적용
	velocity.y += GRAVITY * delta

	# 기절 상태: 조작 불가, 물리만 진행
	if stun_timer > 0.0:
		stun_timer -= delta
		move_and_slide()
		_resolve_collisions()
		_track_landing(false)
		queue_redraw()  # 기절 별 애니메이션 + 끝나면 지우기
		return

	# 감정 선택 휠 (G 홀드): 여는 동안 이동/점프 입력은 방향 선택으로 사용
	if Input.is_action_just_pressed("emotion_wheel"):
		_open_wheel()
	if wheel_open:
		var pick := _wheel_pick()
		if wheel:
			wheel.set_selection(pick)  # 미리보기 하이라이트
		# 방향키를 떼는 순간(방향 -> 중앙) 그 감정으로 확정
		if wheel_prev_pick != Emotion.NEUTRAL and pick == Emotion.NEUTRAL:
			_commit_wheel(wheel_prev_pick)
		elif Input.is_action_just_released("emotion_wheel"):
			# 방향 없이 G만 떼면 현재 하이라이트(보통 기본) 확정
			_commit_wheel(pick)
		wheel_prev_pick = pick
		# 휠 조작 중엔 지상에서 서서히 정지, 공중은 물리만 진행
		if is_on_floor():
			velocity.x = move_toward(velocity.x, 0.0, NORMAL_ACCEL * delta)
		move_and_slide()
		_resolve_collisions()
		_track_landing(false)
		return

	_handle_emotion_switch()

	var st: Dictionary = STATS[emotion]
	var dir := Input.get_axis("move_left", "move_right")

	if is_on_floor():
		# 지상: 좌우 이동 + 점프 가능
		var target: float = dir * st["speed"]
		var accel: float = FEAR_ACCEL if emotion == Emotion.FEAR else NORMAL_ACCEL
		velocity.x = move_toward(velocity.x, target, accel * delta)

		if Input.is_action_just_pressed("jump"):
			velocity.y = -st["jump"]
			velocity.x = dir * st["speed"]  # 발사 순간 수평속도 확정 (착지까지 고정)
			_emit_dust()
			Sfx.play("jump")
	else:
		# 공중: 점프킹식 -> 좌우 조작 불가 (velocity.x 유지)
		if emotion == Emotion.SADNESS and is_on_wall():
			# 슬픔: 벽에 붙어 천천히 미끄러짐 + 벽점프로 굴뚝 오르기
			if velocity.y > SAD_SLIDE_SPEED:
				velocity.y = SAD_SLIDE_SPEED
			if Input.is_action_just_pressed("jump"):
				var n := get_wall_normal()
				velocity.y = -st["jump"]
				velocity.x = n.x * st["speed"]  # 벽 반대 방향으로 튕겨 오름
				_emit_dust()
				Sfx.play("jump")

	move_and_slide()
	_resolve_collisions()
	_track_landing(true)


## 착지 감지 + 낙하 기절. allow_stun=false면 기절은 안 주고 추적만.
func _track_landing(allow_stun: bool) -> void:
	if is_on_floor():
		if not _was_on_floor:
			var fall := global_position.y - _air_min_y  # 정점에서 착지까지 떨어진 높이
			Sfx.play("land")
			if allow_stun and fall > SAFE_FALL and stun_timer <= 0.0:
				var s := FALL_STUN_BASE + 0.1 * (fall - SAFE_FALL) / FALL_STEP
				stun_timer = minf(s, MAX_FALL_STUN)
				Sfx.play("knockback")  # 무겁게 떨어진 소리
		_air_min_y = global_position.y  # 바닥에선 현재 위치가 기준점
	else:
		_air_min_y = minf(_air_min_y, global_position.y)  # 더 높이 오르면 갱신
	_was_on_floor = is_on_floor()


func _handle_emotion_switch() -> void:
	var e := -1
	if Input.is_action_just_pressed("emo_neutral"):
		e = Emotion.NEUTRAL
	elif Input.is_action_just_pressed("emo_anger"):
		e = Emotion.ANGER
	elif Input.is_action_just_pressed("emo_fear"):
		e = Emotion.FEAR
	elif Input.is_action_just_pressed("emo_joy"):
		e = Emotion.JOY
	elif Input.is_action_just_pressed("emo_sadness"):
		e = Emotion.SADNESS
	if e >= 0 and e != emotion:
		set_emotion(e)
		Sfx.play("switch")


func _open_wheel() -> void:
	wheel_open = true
	wheel_prev_pick = _wheel_pick()
	if wheel:
		wheel.open()
		wheel.set_selection(wheel_prev_pick)


func _commit_wheel(e: Emotion) -> void:
	wheel_open = false
	var changed := e != emotion
	set_emotion(e)
	if wheel:
		wheel.close()
	if changed:
		Sfx.play("switch")


## 방향키 조합 -> 대각선 사분면 감정. 방향 없거나 애매하면 기본(중앙)
func _wheel_pick() -> Emotion:
	var x := Input.get_axis("move_left", "move_right")
	var y := Input.get_axis("aim_up", "aim_down")  # 위=음수(화면 y-down)
	if absf(x) < 0.5 or absf(y) < 0.5:
		return Emotion.NEUTRAL
	if y < 0.0:
		return Emotion.JOY if x < 0.0 else Emotion.SADNESS
	return Emotion.ANGER if x < 0.0 else Emotion.FEAR


## move_and_slide 이후 충돌한 물체별 특수 처리
func _resolve_collisions() -> void:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var col := c.get_collider()
		if col == null:
			continue
		if col.is_in_group("cracked_wall") and emotion == Emotion.ANGER:
			# 분노 상태로 금 간 벽에 닿으면 파괴 (조각나며 사라짐)
			var sz: Vector2 = col.size if col.get("size") != null else Vector2(80, 24)
			_shatter(col.global_position, sz, STATS[emotion]["color"])
			col.queue_free()
			Sfx.play("break")
		elif col.is_in_group("knockback_wall") and stun_timer <= 0.0:
			# 넉백 벽: 항상 옆으로 확 튕겨나감 (위에 안 끼게) + 2초간 기절
			var away := 1.0
			var wall := col as Node2D
			if wall:
				var dx := global_position.x - wall.global_position.x
				away = signf(dx) if absf(dx) > 1.0 else (1.0 if randf() < 0.5 else -1.0)
			velocity = Vector2(away * KNOCKBACK_FORCE, -KNOCKBACK_FORCE * 0.7)
			stun_timer = STUN_TIME
			Sfx.play("knockback")


## 벽이 조각나서 사방으로 튀며 사라지는 파편 이펙트
func _shatter(pos: Vector2, sz: Vector2, color: Color) -> void:
	var p := CPUParticles2D.new()
	p.local_coords = false
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 20
	p.lifetime = 0.7
	p.spread = 180.0
	p.gravity = Vector2(0, 800)          # 파편이 떨어짐
	p.initial_velocity_min = 90.0
	p.initial_velocity_max = 300.0
	p.scale_amount_min = 4.0
	p.scale_amount_max = 10.0
	p.angular_velocity_min = -600.0      # 조각이 빙글빙글
	p.angular_velocity_max = 600.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = sz * 0.5   # 벽 크기만큼 퍼져서 생성
	var g := Gradient.new()
	g.set_color(0, Color(color.r, color.g, color.b, 1.0))
	g.set_color(1, Color(color.r, color.g, color.b, 0.0))  # 서서히 사라짐
	p.color_ramp = g
	get_parent().add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)     # 끝나면 자동 제거


func set_emotion(e: Emotion) -> void:
	emotion = e
	queue_redraw()
	emotion_changed.emit(STATS[e]["name"], STATS[e]["color"], STATS[e]["ability"])


func _draw() -> void:
	# 빛나는 그라데이션 구슬: 바깥=감정색, 안쪽=밝게(HDR -> 글로우)
	var col: Color = STATS[emotion]["color"]
	var steps := 20
	for i in steps:
		var t := 1.0 - float(i) / float(steps - 1)  # 1(바깥) 먼저 -> 0(안쪽) 마지막
		var r := lerpf(3.0, RADIUS, t)
		var b := lerpf(2.3, 0.95, t)  # 안쪽 밝게(HDR), 바깥 살짝 어둡게
		draw_circle(Vector2.ZERO, r, Color(col.r * b, col.g * b, col.b * b))

	if stun_timer > 0.0:
		_draw_stun_stars(col)


## 기절 중 머리 위에서 도는 감정 색 별
func _draw_stun_stars(col: Color) -> void:
	var tm := float(Time.get_ticks_msec()) / 1000.0
	var head := Vector2(0.0, -RADIUS - 16.0)  # 머리 위
	var count := 3
	for i in count:
		var ang := tm * 3.5 + float(i) * TAU / float(count)
		var pos := head + Vector2(cos(ang) * 17.0, sin(ang) * 6.0)  # 납작한 타원 궤도
		_draw_star(pos, 7.0, tm * 4.0 + float(i), col)


## 5각 별을 채워서 그림
func _draw_star(c: Vector2, r: float, rot: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var rr := r if i % 2 == 0 else r * 0.45
		var a := rot + float(i) * PI / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, col)
