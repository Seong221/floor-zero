extends CanvasLayer
class_name MissionHUD

## 3D 월드와 독립된 화면 UI입니다. 해상도가 바뀌어도 총기/방 좌표와
## 섞이지 않게 CanvasLayer를 사용합니다.

@onready var status: Label = $Margin/Panel/Status
@onready var ammo: Label = $Ammo

func set_status(text: String) -> void:
	# 매 프레임 갱신되어도 UI 텍스트 외의 게임 상태는 바꾸지 않습니다.
	status.text = text

func flash_status(text: String) -> void:
	# 현재는 일반 상태 문구와 같지만, 나중에 색/애니메이션을 붙일 진입점입니다.
	status.text = text

func set_ammo(current: int, maximum: int) -> void:
	# -1은 WeaponController의 무한 탄약 표기입니다. 실험 중 남은 탄 수가
	# 줄어드는 것처럼 보이지 않게 ∞로 명확히 표시합니다.
	if current < 0 or maximum < 0:
		ammo.text = "∞ / ∞"
		return
	# 두 자리 정렬로 탄약 숫자가 흔들려 보이지 않게 합니다.
	ammo.text = "%02d / %02d" % [current, maximum]
