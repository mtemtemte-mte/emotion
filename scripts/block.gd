@tool
extends StaticBody2D
## 에디터에서 크기/종류를 바로 조절할 수 있는 블록.
## size, kind만 바꾸면 충돌 모양과 색이 자동으로 맞춰짐.

enum Kind { PLATFORM, CRACKED, KNOCKBACK }

const COLORS := {
	Kind.PLATFORM: Color(0.30, 0.33, 0.40),   # 일반 벽(회색, 감정색으로 물듦)
	Kind.CRACKED: Color(0.62, 0.30, 0.26),    # 분노 - 붉은 (닿으면 파괴)
	Kind.KNOCKBACK: Color(0.60, 0.60, 0.64),  # 함정 - 무채색 회색 (부딪히면 기절)
}

@export var kind: Kind = Kind.PLATFORM:
	set(v):
		kind = v
		_apply()

@export var size := Vector2(150, 24):
	set(v):
		size = v
		_apply()


func _ready() -> void:
	_apply()
	if not Engine.is_editor_hint():
		match kind:
			Kind.CRACKED:
				add_to_group("cracked_wall")
				add_to_group("recolor_wall")  # 바탕색은 일반 벽과 동일(감정색), 금 무늬만 위에
			Kind.KNOCKBACK:
				add_to_group("knockback_wall")
				add_to_group("recolor_wall")  # 감정색으로 물듦 + 명암(빛)도 받음
			Kind.PLATFORM:
				add_to_group("recolor_wall")  # 일반 벽 - 감정색으로 물듦


func _apply() -> void:
	if not is_inside_tree():
		return
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	var poly := get_node_or_null("Polygon2D") as Polygon2D
	if cs:
		var rect := RectangleShape2D.new()
		rect.size = size
		cs.shape = rect
	if poly:
		var h := size * 0.5
		if kind == Kind.KNOCKBACK:
			poly.polygon = _spiky_polygon(h, 12.0, 16.0)  # 가시 모양(일반 벽처럼 감정색+명암)
		else:
			poly.polygon = PackedVector2Array([
				Vector2(-h.x, -h.y), Vector2(h.x, -h.y),
				Vector2(h.x, h.y), Vector2(-h.x, h.y),
			])
		poly.color = COLORS[kind]
		poly.show_behind_parent = true  # 균열(_draw)이 색 위에 그려지도록
	queue_redraw()


func _draw() -> void:
	if kind == Kind.CRACKED:
		_draw_cracks()


## 금 간 벽 균열 무늬
func _draw_cracks() -> void:
	var h := size * 0.5
	var col := Color(0.16, 0.09, 0.08, 0.9)  # 어두운 균열 색
	if size.x >= size.y:
		_crack(Vector2(-h.x * 0.95, -h.y * 0.15), Vector2(h.x * 0.95, h.y * 0.25), col, 2.0)
		_crack(Vector2(-h.x * 0.25, 0.0), Vector2(-h.x * 0.12, h.y * 0.9), col, 1.5)
		_crack(Vector2(h.x * 0.35, h.y * 0.05), Vector2(h.x * 0.5, -h.y * 0.9), col, 1.5)
	else:
		_crack(Vector2(-h.x * 0.15, -h.y * 0.95), Vector2(h.x * 0.25, h.y * 0.95), col, 2.0)
		_crack(Vector2(0.0, -h.y * 0.2), Vector2(h.x * 0.9, -h.y * 0.1), col, 1.5)
		_crack(Vector2(h.x * 0.05, h.y * 0.35), Vector2(-h.x * 0.9, h.y * 0.5), col, 1.5)


## 넉백 벽 가시 모양 폴리곤 (사방 삼각 가시). 색/명암은 wall_mat이 처리.
func _spiky_polygon(h: Vector2, tip: float, density: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var corners := [Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)]
	var normals := [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]
	for e in 4:
		var a: Vector2 = corners[e]
		var b: Vector2 = corners[(e + 1) % 4]
		var normal: Vector2 = normals[e]
		var n: int = maxi(2, int(a.distance_to(b) / density))
		for i in n:
			var t0 := float(i) / float(n)
			var tm := (float(i) + 0.5) / float(n)
			pts.append(a.lerp(b, t0))                 # 골(변 위)
			pts.append(a.lerp(b, tm) + normal * tip)  # 봉우리(가시 끝)
	return pts


## a~b 사이를 지그재그(들쭉날쭉) 선으로 그림
func _crack(a: Vector2, b: Vector2, col: Color, w: float) -> void:
	var pts := PackedVector2Array()
	var n := 5
	var dir := b - a
	var perp := Vector2(-dir.y, dir.x).normalized()
	var amp: float = min(size.x, size.y) * 0.12
	for i in n + 1:
		var t := float(i) / float(n)
		var base := a.lerp(b, t)
		var jitter := 0.0
		if i > 0 and i < n:
			jitter = sin(t * 23.3 + a.x * 0.7) * amp
		pts.append(base + perp * jitter)
	draw_polyline(pts, col, w, true)
