extends Node2D
## 씬에 배치된 맵(Environment)은 에디터에서 직접 편집.
## 이 스크립트는 UI/감정 휠/도착 처리 같은 로직만 담당.

const WheelScript := preload("res://scripts/emotion_wheel.gd")
const BgShader := preload("res://scripts/bg_height.gdshader")
const WallShader := preload("res://scripts/wall.gdshader")

const WALL_BASE := Color(0.30, 0.33, 0.40)  # 일반 벽 회색
const WALL_MIX := 0.5                          # 감정 색 섞는 정도

# 레벨(월드) 세로 범위 — 배경 높이 그라데이션에 사용. wall 높이에 맞춤.
const LEVEL_BOTTOM_Y := 640.0   # 맨 아래(진함)
const LEVEL_TOP_Y := -4915.0    # 맨 위(연함)

var emotion_label: Label
var win_label: Label
var wheel: Control
var bg_mat: ShaderMaterial      # 배경 그라데이션 + 감정 틴트
var wall_mat: ShaderMaterial    # 일반 벽 radial 색 전환 (공유)
var wall_current := Color(0.5, 0.5, 0.5)
var _wall_tween: Tween          # 원형 퍼짐 트윈 (겹침 방지)
var _bg_tween: Tween            # 배경 색 트윈


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

	var help := Label.new()
	help.position = Vector2(16, 12)
	help.text = "이동: A/D 또는 ←/→   점프: Space\n감정 휠: G 누른 채 방향 조합 → 방향키 떼면 적용 (↖기쁨 ↗슬픔 ↙분노 ↘공포)\n빠른전환: 1기본 2분노 3공포 4기쁨 5슬픔"
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
	if body.is_in_group("player") and win_label:
		win_label.visible = true


## 스크린샷 캡처 후 종료 (godot ... -- --capture 로 실행 시)
func _capture_screenshot() -> void:
	var cam := Camera2D.new()
	cam.position = Vector2(576, 250)
	cam.zoom = Vector2(0.6, 0.6)
	add_child(cam)
	cam.make_current()
	await get_tree().create_timer(0.6).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png("D:/10인준완/Godot/emotion/emotion/_preview.png")
	get_tree().quit()
