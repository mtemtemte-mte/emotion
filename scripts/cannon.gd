@tool
extends Node2D
## 회전으로 조준하는 대포. 총구(+X 방향)로 공을 일정 간격 발사한다.
## 몸통은 일반 벽과 똑같이 공유 셰이더(wall_mat)로 감정색에 물들고 명암도 받는다.
##  -> "recolor_wall" 그룹 + 자식 "Polygon2D" 이면 main.gd의 _setup_walls가 자동 적용.
## 총구는 감정색 위에 겹치는 어두운 반투명 타원(구멍). 외곽선 없음.
## 에디터에서 배치하고 회전시켜 조준. 발사 간격/속도/공 색은 인스펙터에서 조절.

const BallScene := preload("res://scenes/ball.tscn")

const BARREL_LEN := 70.0    # 포신 길이 (뒤 x=0 ~ 총구 중심 x=BARREL_LEN, +X가 발사 방향)
const BARREL_H := 46.0      # 포신 지름
const MUZZLE_EW := 13.0     # 총구 타원 반너비 (원근으로 납작하게)

@export var fire_interval := 2.0     # 발사 간격(초)
@export var ball_speed := 300.0      # 발사 속도(px/s)
@export var ball_radius := 16.0
@export var ball_color := Color(0.95, 0.97, 1.0)  # 플레이어처럼 빛나는 밝은 흰빛
@export var despawn_y := -2385.0   # 공이 이 Y보다 아래로 내려가면 소멸 (화면 아래로 갈수록 Y가 큼)

var _t := 0.0
var _solid: StaticBody2D   # 플레이어가 부딪히는 딱딱한 충돌 몸통


func _ready() -> void:
	_build_body()  # 몸통/구멍 폴리곤 (에디터+런타임)
	if Engine.is_editor_hint():
		return
	add_to_group("recolor_wall")  # 다른 벽과 똑같이 감정색으로 물들도록
	_build_collision()            # 플레이어가 부딪히는 딱딱한 몸통
	_t = fire_interval  # 배치 직후 바로 한 발


## 포신 모양의 딱딱한 충돌 몸통 (플레이어가 통과 못 함)
func _build_collision() -> void:
	_solid = StaticBody2D.new()
	_solid.name = "Solid"
	var cs := CollisionShape2D.new()
	var shape := ConvexPolygonShape2D.new()
	shape.points = _body_points()
	cs.shape = shape
	_solid.add_child(cs)
	add_child(_solid)


## 몸통(감정색 물듦) + 총구 구멍(어두운 반투명) 폴리곤을 자식으로 생성.
## 런타임엔 main._setup_walls 가 "Polygon2D" 에 공유 wall_mat 를 입힌다.
func _build_body() -> void:
	var body := get_node_or_null("Polygon2D") as Polygon2D
	if body == null:
		body = Polygon2D.new()
		body.name = "Polygon2D"
		add_child(body)
	body.polygon = _body_points()
	body.color = Color(0.55, 0.57, 0.62)  # 기본 회색 (런타임엔 벽 셰이더가 덮어씀)

	var hole := get_node_or_null("Hole") as Polygon2D
	if hole == null:
		hole = Polygon2D.new()
		hole.name = "Hole"
		add_child(hole)                   # body 뒤에 추가 -> 위에 겹쳐 그려짐
	hole.polygon = _hole_points()
	hole.color = Color(0.0, 0.0, 0.0, 0.42)  # 어두운 구멍(테두리 없음), 감정색 위에 겹침


## 포신 몸통: 뒤 사각 + 총구 타원의 오른쪽 반호
func _body_points() -> PackedVector2Array:
	var hh := BARREL_H * 0.5
	var mc := Vector2(BARREL_LEN, 0.0)
	var pts := PackedVector2Array()
	pts.append(Vector2(0.0, -hh))
	var seg := 24
	for i in seg + 1:
		var a: float = -PI * 0.5 + PI * float(i) / float(seg)
		pts.append(mc + Vector2(cos(a) * MUZZLE_EW, sin(a) * hh))
	pts.append(Vector2(0.0, hh))
	return pts


## 총구 타원(구멍)
func _hole_points() -> PackedVector2Array:
	var hh := BARREL_H * 0.5
	var mc := Vector2(BARREL_LEN, 0.0)
	var pts := PackedVector2Array()
	var n := 44
	for i in n:
		var a: float = TAU * float(i) / float(n)
		pts.append(mc + Vector2(cos(a) * MUZZLE_EW, sin(a) * hh))
	return pts


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta
	if _t >= fire_interval:
		_t = 0.0
		_fire()


func _fire() -> void:
	var dir := Vector2.RIGHT.rotated(global_rotation)  # 총구 방향(회전 반영)
	var b := BallScene.instantiate()
	b.radius = ball_radius
	b.color = ball_color
	b.despawn_y = despawn_y
	get_parent().add_child(b)  # 레벨에 대포의 형제로 추가
	b.global_position = global_position + dir * (BARREL_LEN + MUZZLE_EW + ball_radius + 3.0)
	b.linear_velocity = dir * ball_speed
	b.angular_velocity = (ball_speed / maxf(ball_radius, 1.0)) * signf(dir.x)  # 굴러가는 방향 스핀
	if _solid:
		b.add_collision_exception_with(_solid)  # 자기 대포엔 안 걸리게
