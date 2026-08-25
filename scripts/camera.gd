extends Camera2D
## 세로(Y)만 플레이어를 따라가고, 가로(X)는 고정.
## bottom_limit = 이 Y보다 아래는 카메라에 보이지 않음(바닥 밑 빈 공간 가림).

@export var fixed_x := 576.0
@export var bottom_limit := 640  # 바닥 블록 밑면 Y. 필요하면 조절.


func _ready() -> void:
	limit_bottom = bottom_limit


func _process(_delta: float) -> void:
	global_position.x = fixed_x
