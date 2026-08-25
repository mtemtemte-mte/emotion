extends Control
## G키로 여는 방사형 감정 선택 휠 (그림의 대각선 배치)

const R_OUT := 150.0
const R_IN := 64.0

# 감정 int (player.gd의 Emotion enum과 동일한 값)
const NEUTRAL := 0
const ANGER := 1
const FEAR := 2
const JOY := 3
const SADNESS := 4

# 사분면 배치 (화면 좌표계 y-down 기준 각도)
# JOY=좌상, SADNESS=우상, ANGER=좌하, FEAR=우하
var quads := [
	{"emotion": JOY,     "a0": PI,        "a1": PI * 1.5, "color": Color(1.00, 0.84, 0.22)},
	{"emotion": SADNESS, "a0": PI * 1.5,  "a1": TAU,      "color": Color(0.25, 0.55, 0.92)},
	{"emotion": ANGER,   "a0": PI * 0.5,  "a1": PI,       "color": Color(0.90, 0.25, 0.20)},
	{"emotion": FEAR,    "a0": 0.0,       "a1": PI * 0.5, "color": Color(0.55, 0.30, 0.78)},
]

var selection := NEUTRAL


func open() -> void:
	visible = true
	queue_redraw()


func close() -> void:
	visible = false


func set_selection(e: int) -> void:
	if e != selection:
		selection = e
		queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	# 뒤 배경 살짝 어둡게
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.35))

	# 사분면(파이) — 가운데는 나중에 흰 원으로 덮어 구멍처럼 보이게
	for q in quads:
		var col: Color = q["color"]
		var r := R_OUT
		if selection == q["emotion"]:
			col = col.lightened(0.15)
			r += 12.0
		else:
			col = col.darkened(0.12)
		draw_colored_polygon(_pie(c, r, q["a0"], q["a1"], 28), col)

	# 중앙 = 기본(무감정)
	if selection == NEUTRAL:
		draw_circle(c, R_IN + 7.0, Color(1, 1, 1, 0.35))
		draw_circle(c, R_IN, Color.WHITE)
	else:
		draw_circle(c, R_IN, Color(0.82, 0.82, 0.82))


## 중심 c에서 시작하는 부채꼴(파이) 폴리곤 점들
func _pie(c: Vector2, r: float, a0: float, a1: float, steps: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(c)
	for i in steps + 1:
		var t: float = a0 + (a1 - a0) * float(i) / float(steps)
		pts.append(c + Vector2(cos(t), sin(t)) * r)
	return pts
