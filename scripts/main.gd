extends Node2D
## 씬에 배치된 맵(Environment)은 에디터에서 직접 편집.
## 이 스크립트는 UI/감정 휠/도착 처리 같은 로직만 담당.

const WheelScript := preload("res://scripts/emotion_wheel.gd")
const BgShader := preload("res://scripts/bg_height.gdshader")
const WallShader := preload("res://scripts/wall.gdshader")
const EndingSky := preload("res://scripts/ending_sky.gd")

const WALL_BASE := Color(0.30, 0.33, 0.40)  # 일반 벽 회색
const WALL_MIX := 0.5                          # 감정 색 섞는 정도

# 레벨(월드) 세로 범위 — 배경 높이 그라데이션에 사용. wall 높이에 맞춤.
const LEVEL_BOTTOM_Y := 640.0   # 맨 아래(진함)
const LEVEL_TOP_Y := -4915.0    # 맨 위(연함)

var emotion_label: Label
var win_label: Label
var wheel: Control
var ui_layer: CanvasLayer     # U 키로 껐다 켜는 UI 레이어
var bg_mat: ShaderMaterial      # 배경 그라데이션 + 감정 틴트
var wall_mat: ShaderMaterial    # 일반 벽 radial 색 전환 (공유)
var wall_current := Color(0.5, 0.5, 0.5)
var _wall_tween: Tween          # 원형 퍼짐 트윈 (겹침 방지)
var _bg_tween: Tween            # 배경 색 트윈
var _ended := false             # 도착 엔딩 1회만


func _ready() -> void:
	_build_glow()
	_build_background()
	_build_wheel()
	_build_ui()
	_setup_walls()

	var player := $Player
	player.emotion_changed.connect(_on_emotion_changed)
	player.set_wheel(wheel)

	_align_camera_to_floor()

	var goal := get_node_or_null("Environment/Goal")
	if goal:
		goal.body_entered.connect(_on_goal_body)

	if "--capture" in (OS.get_cmdline_args() + OS.get_cmdline_user_args()):
		_capture_screenshot()


func _process(_delta: float) -> void:
	# 캐릭터를 광원으로: 벽 셰이더에 매 프레임 플레이어 위치 전달
	if wall_mat:
		wall_mat.set_shader_parameter("light_pos", $Player.global_position)


func _unhandled_input(event: InputEvent) -> void:
	# U 키: UI 껐다 켜기 토글
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_U:
		if ui_layer:
			ui_layer.visible = not ui_layer.visible


## 화면 전체 글로우(빛번짐/블룸). 밝은(HDR) 색만 은은하게 빛남.
func _build_glow() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.set_glow_level(1, true)
	env.set_glow_level(2, true)
	env.set_glow_level(3, true)
	env.set_glow_level(4, true)
	env.glow_intensity = 0.9
	env.glow_strength = 1.0
	env.glow_bloom = 0.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_hdr_threshold = 1.2  # 이보다 밝은(HDR) 것만 빛남 -> 배경 제외, 플레이어만
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


## 카메라 바닥 기준을 실제 바닥 블록 밑면에 딱 맞춤 (바닥 아래 빈 공간 안 보이게)
func _align_camera_to_floor() -> void:
	var ground := get_node_or_null("Environment/Ground")
	var cam := $Player.get_node_or_null("Camera2D") as Camera2D
	if ground and cam:
		var bottom: float = ground.global_position.y + ground.size.y * 0.5  # 바닥 블록 밑면 Y
		cam.limit_bottom = int(round(bottom))


func _build_background() -> void:
	# 월드 공간 배경(레벨 전체 높이). z_index -100 이라 모든 것 뒤에 깔림.
	# 아래=진함, 위=연함. 카메라 따라 스크롤되며 높이별 밝기가 드러남.
	var bg := Polygon2D.new()
	bg.z_index = -100
	var x0 := -300.0
	var x1 := 1452.0
	var y_top := LEVEL_TOP_Y - 400.0     # 위 여유
	var y_bot := LEVEL_BOTTOM_Y + 400.0  # 아래 여유
	bg.polygon = PackedVector2Array([
		Vector2(x0, y_top), Vector2(x1, y_top),
		Vector2(x1, y_bot), Vector2(x0, y_bot),
	])
	bg_mat = ShaderMaterial.new()
	bg_mat.shader = BgShader
	bg_mat.set_shader_parameter("emotion_color", Color(0.5, 0.5, 0.5))
	bg_mat.set_shader_parameter("level_bottom", LEVEL_BOTTOM_Y)
	bg_mat.set_shader_parameter("level_top", LEVEL_TOP_Y)
	bg.material = bg_mat
	add_child(bg)


func _build_wheel() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	wheel = Control.new()
	wheel.set_script(WheelScript)
	wheel.set_anchors_preset(Control.PRESET_FULL_RECT)
	wheel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wheel.visible = false
	layer.add_child(wheel)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2  # 채도 오버레이(1) 위 -> UI는 항상 컬러
	add_child(layer)
	ui_layer = layer

	var help := Label.new()
	help.position = Vector2(16, 12)
	help.text = "이동: A/D 또는 ←/→   점프: Space\n감정 휠: G 누른 채 방향 조합 → 방향키 떼면 적용 (↖기쁨 ↗슬픔 ↙분노 ↘공포)\nU: UI 숨기기 / 보이기"
	help.add_theme_color_override("font_color", Color.WHITE)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	help.add_theme_constant_override("outline_size", 4)
	layer.add_child(help)

	emotion_label = Label.new()
	emotion_label.position = Vector2(16, 90)
	emotion_label.add_theme_font_size_override("font_size", 28)
	emotion_label.add_theme_color_override("font_outline_color", Color.BLACK)
	emotion_label.add_theme_constant_override("outline_size", 5)
	layer.add_child(emotion_label)

	win_label = Label.new()
	win_label.set_anchors_preset(Control.PRESET_CENTER)
	win_label.position = Vector2(-90, -40)
	win_label.text = "도착! 🎉"
	win_label.add_theme_font_size_override("font_size", 48)
	win_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	win_label.add_theme_color_override("font_outline_color", Color.BLACK)
	win_label.add_theme_constant_override("outline_size", 6)
	win_label.visible = false
	layer.add_child(win_label)


func _setup_walls() -> void:
	# 일반 벽들에 공유 셰이더 머티리얼을 붙임 (한 번에 색 전환)
	wall_mat = ShaderMaterial.new()
	wall_mat.shader = WallShader
	var start := WALL_BASE.lerp(Color(0.82, 0.82, 0.88), WALL_MIX)  # 기본(회색)
	wall_mat.set_shader_parameter("old_color", start)
	wall_mat.set_shader_parameter("emotion_color", start)
	wall_mat.set_shader_parameter("radius", 100000.0)
	wall_current = start
	for w in get_tree().get_nodes_in_group("recolor_wall"):
		var poly := w.get_node_or_null("Polygon2D") as Polygon2D
		if poly:
			poly.material = wall_mat


func _recolor_walls(color: Color) -> void:
	if not wall_mat:
		return
	var tint := WALL_BASE.lerp(color, WALL_MIX)
	# 원형 전환: 플레이어 위치에서 새 색이 퍼져나감
	wall_mat.set_shader_parameter("old_color", wall_current)
	wall_mat.set_shader_parameter("emotion_color", tint)
	wall_mat.set_shader_parameter("center", $Player.global_position)
	wall_mat.set_shader_parameter("radius", 0.0)
	if _wall_tween and _wall_tween.is_valid():
		_wall_tween.kill()  # 이전 퍼짐 트윈 정리 -> 감정->감정에서도 매번 새로 퍼짐
	_wall_tween = create_tween()
	_wall_tween.tween_property(wall_mat, "shader_parameter/radius", 2200.0, 1.4)
	wall_current = tint


func _on_emotion_changed(display_name: String, color: Color, ability: String) -> void:
	if emotion_label:
		emotion_label.text = "감정: %s\n%s" % [display_name, ability]
		emotion_label.add_theme_color_override("font_color", color)

	# 일반 벽 원형 색 전환
	_recolor_walls(color)
	# 배경 감정 색 부드럽게 전환
	if bg_mat:
		if _bg_tween and _bg_tween.is_valid():
			_bg_tween.kill()
		_bg_tween = create_tween()
		_bg_tween.tween_property(bg_mat, "shader_parameter/emotion_color", color, 1.0)


func _on_goal_body(body: Node) -> void:
	if _ended or not body.is_in_group("player"):
		return
	_ended = true
	_start_ending()


## 도착 엔딩: 조작 잠금 -> 카메라가 플레이어 위치에서 하늘로 상승 -> 걸린 시간 표시
func _start_ending() -> void:
	var player := get_node_or_null("Player") as Node2D
	if player == null:
		return
	var elapsed_ms := Time.get_ticks_msec()  # 게임 실행부터 지금까지(ms)

	# 플레이어 조작/물리 정지 + 게임 UI 숨김
	player.set_physics_process(false)
	if ui_layer:
		ui_layer.visible = false

	var vp := get_viewport_rect().size
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	var px: float = cam.fixed_x if cam else 576.0
	var py := player.global_position.y
	var rise := vp.y * 1.4  # 올라갈 거리

	# 플레이어 위쪽 하늘(월드) — 카메라가 올라가면 드러남. 코드로 그림.
	var sky := Node2D.new()
	sky.set_script(EndingSky)
	sky.z_index = 200  # 그 구역의 벽 위를 덮어 하늘만 보이게
	var sky_w := vp.x * 2.0
	var sky_h := rise + vp.y * 2.0
	var sky_bottom := py - vp.y * 0.5 - 40.0                      # 시작 화면 위쪽 바로 바깥
	sky.position = Vector2(px - sky_w * 0.5, sky_bottom - sky_h)  # 좌상단
	add_child(sky)
	sky.setup(sky_w, sky_h)

	# 카메라를 플레이어 위치에서 하늘로 부드럽게 상승
	if cam:
		cam.position_smoothing_enabled = false
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(cam, "global_position:y", py - rise, 3.0)
		tw.tween_callback(_show_ending_text.bind(elapsed_ms))
	else:
		_show_ending_text(elapsed_ms)


## 상승 후 "당신이 허비한 시간 / N시간 N분 N초" 를 화면에 서서히 표시
func _show_ending_text(elapsed_ms: int) -> void:
	var vp := get_viewport_rect().size
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.modulate.a = 0.0  # 서서히 나타남
	layer.add_child(root)

	var title := Label.new()
	title.text = "당신이 허비한 시간"
	title.size = Vector2(vp.x, 60.0)
	title.position = Vector2(0.0, vp.y * 0.34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(0.12, 0.18, 0.32))
	title.add_theme_color_override("font_outline_color", Color(1, 1, 1))
	title.add_theme_constant_override("outline_size", 6)
	root.add_child(title)

	var total := int(elapsed_ms / 1000)
	var hh := total / 3600
	var mm := (total % 3600) / 60
	var ss := total % 60
	var time_label := Label.new()
	time_label.text = "%d시간 %d분 %d초" % [hh, mm, ss]
	time_label.size = Vector2(vp.x, 90.0)
	time_label.position = Vector2(0.0, vp.y * 0.44)
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	time_label.add_theme_font_size_override("font_size", 56)
	time_label.add_theme_color_override("font_color", Color(0.10, 0.14, 0.28))
	time_label.add_theme_color_override("font_outline_color", Color(1, 1, 1))
	time_label.add_theme_constant_override("outline_size", 7)
	root.add_child(time_label)

	var tw := create_tween()
	tw.tween_property(root, "modulate:a", 1.0, 1.2)


## 스크린샷 캡처 후 종료 (godot ... -- --capture 로 실행 시)
func _capture_screenshot() -> void:
	var cam := Camera2D.new()
	cam.position = Vector2(576, 250)
	cam.zoom = Vector2(0.6, 0.6)
	add_child(cam)
	cam.make_current()
	await get_tree().create_timer(0.6).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://_preview.png")
	get_tree().quit()
