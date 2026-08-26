extends Node
class_name HitReceiver

## 총알, 근접 공격, 폭발 등으로 피해를 받을 수 있는 대상의 공통 부품입니다.
## 이 노드는 '무엇을 맞았는가'를 판단하지 않습니다. HitSurface/Enemy 같은
## 바깥 몸체가 맞은 위치와 피해량을 전달하면, 체력과 생존 상태만 관리합니다.

## 피격 직후 몸체/애니메이션/AI가 반응할 수 있게 전달하는 신호입니다.
signal hit_received(damage: int, hit_position: Vector3, hit_normal: Vector3, incoming_direction: Vector3)
## 체력이 처음 0 이하가 된 정확히 한 번만 전달하는 신호입니다.
signal destroyed(hit_position: Vector3, hit_normal: Vector3, incoming_direction: Vector3)

## Inspector 또는 코드에서 대상별 체력을 설정합니다. 훈련 표적은 4발로 둡니다.
@export var max_health := 1

## 현재 체력입니다. _ready 때 max_health로 초기화합니다.
var health := 1
## 이미 파괴/제압된 대상은 같은 죽음 반응을 반복하지 않게 막습니다.
var is_destroyed := false

func _ready() -> void:
	# Inspector에서 max_health를 바꿔도 시작값과 어긋나지 않게 합니다.
	health = max_health

func receive_hit(damage: int, hit_position: Vector3, hit_normal: Vector3, incoming_direction: Vector3) -> void:
	# 파괴된 뒤에는 체력/사망 신호를 다시 바꾸지 않습니다. 다만 표면의 탄착
	# 효과는 HitSurface가 이 함수와 별개로 만들기 때문에 계속 남길 수 있습니다.
	if is_destroyed:
		return
	# 모든 피해 전달자는 이 신호를 이용해 피격 모션, 경계 상태 등을 시작합니다.
	hit_received.emit(damage, hit_position, hit_normal, incoming_direction)
	health -= damage
	# 아직 체력이 남았다면 사망/파괴 단계로 넘어가지 않습니다.
	if health > 0:
		return
	# 0 아래로 더 내려가도 한 번만 실행되도록 상태를 먼저 고정합니다.
	is_destroyed = true
	destroyed.emit(hit_position, hit_normal, incoming_direction)
