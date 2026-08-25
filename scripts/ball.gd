extends RigidBody2D
## 대포에서 발사되어 굴러가는 공. 중력 적용 + 바닥을 구름.
## 플레이어가 닿으면 기절+밀침 (player.gd의 넉백 벽 처리를 그대로 재활용 → "knockback_wall" 그룹).
## Path1보다 아래로 내려가면 가루처럼 위로 흩어지며 소멸.

@export var radius := 16.0
@export var color := Color(0.95, 0.97, 1.0)  # 플레이어처럼 빛나는 밝은 흰빛

var despawn_y := 100000.0   # 이 Y(월드)보다 아래로 내려가면 소멸 — 대포가 Path1 기준으로 지정
const MAX_LIFE := 14.0      # 안전장치: 너무 오래 남은 공은 소멸

var _age := 0.0
var _dead := false


func _ready() -> void:
	# 굴러가도록 마찰 + 살짝 튐
	var mat := PhysicsMaterial.new()
	mat.friction = 1.0
	mat.bounce = 0.15
	physics_material_override = mat
	# 인스턴스마다 독립된 충돌 모양 (공유 리소스 변형 방지)
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs:
		var sh := CircleShape2D.new()
		sh.radius = radius
		cs.shape = sh
	# 플레이어와는 물리 충돌 무시 -> 공은 그대로 굴러가고 플레이어만 튕겨나감
	var player := get_tree().get_first_node_in_group("player")
	if player is PhysicsBody2D:
		add_collision_exception_with(player)
	# 닿음 감지용 Area2D (물리 충돌과 별개로 겹침만 감지 -> 플레이어 기절+넉백)
	var area := Area2D.new()
	var acs := CollisionShape2D.new()
	var ashape := CircleShape2D.new()
	ashape.radius = radius
	acs.shape = ashape
	area.add_child(acs)
	add_child(area)
	area.body_entered.connect(_on_hit_body)
	queue_redraw()


func _on_hit_body(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("hit_knockback"):
		body.hit_knockback(global_position)  # 플레이어만 튕김. 공은 그대로 진행.


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_age += delta
	# 화면 좌표계는 y가 아래로 갈수록 큼 -> despawn_y보다 크면 아래로 내려간 것
	if global_position.y > despawn_y or _age > MAX_LIFE:
		_dissolve()


## 가루처럼 위로 떠오르며 사라지는 소멸 이펙트
func _dissolve() -> void:
	_dead = true
	var p := CPUParticles2D.new()
	p.local_coords = false
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 0.85
	p.amount = 24
	p.lifetime = 0.8
	p.direction = Vector2(0, -1)     # 위로
	p.spread = 45.0
	p.gravity = Vector2(0, -160)     # 떠오르며 사라짐
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 130.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 7.0
	var g := Gradient.new()
	g.set_color(0, Color(color.r, color.g, color.b, 1.0))
	g.set_color(1, Color(color.r, color.g, color.b, 0.0))
	p.color_ramp = g
	get_parent().add_child(p)
	p.global_position = global_position
	p.finished.connect(p.queue_free)
	queue_free()


func _draw() -> void:
	# 플레이어처럼 빛나는 구슬: 안쪽을 밝게(HDR) 그려 글로우가 뜨게
	var steps := 20
	for i in steps:
		var t := 1.0 - float(i) / float(steps - 1)  # 1(바깥) -> 0(안쪽)
		var r := lerpf(3.0, radius, t)
		var b := lerpf(2.3, 0.95, t)  # 안쪽 밝게, 바깥 살짝 어둡게
		draw_circle(Vector2.ZERO, r, Color(color.r * b, color.g * b, color.b * b))
