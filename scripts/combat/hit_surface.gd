extends StaticBody3D
class_name HitSurface

## 물리 RayCast에 맞는 실제 충돌 몸체입니다. Weapon은 맞은 대상의 종류를
## 몰라도 take_hit() 하나만 호출하고, 이 노드가 표면 효과와 체력 부품에
## 연결합니다. 벽·문·가구·훈련 표적·나중의 적 충돌체가 같은 약속을 씁니다.

## ImpactManager가 어떤 색/파편/섬광을 만들지 결정하는 표면 이름입니다.
@export var surface_type: StringName = &"concrete"
## 보이지 않는 경계 충돌체처럼 탄착 효과가 필요 없는 경우를 위한 스위치입니다.
@export var impact_enabled := true

func take_hit(damage: int, hit_position: Vector3, hit_normal: Vector3, incoming_direction := Vector3.ZERO) -> void:
	# ImpactManager는 root Scene에 한 개만 존재합니다. 그룹으로 찾기 때문에
	# ROOM 01, 이후 ROOM 02, 적 Scene 모두 경로를 직접 알 필요가 없습니다.
	if impact_enabled:
		var impact_manager := get_tree().get_first_node_in_group("impact_manager") as ImpactManager
		if impact_manager != null:
			impact_manager.spawn_impact(surface_type, hit_position, hit_normal, incoming_direction)
	# HitReceiver는 선택 사항입니다. 벽/가구는 효과만 만들고, 체력 있는
	# 표적/적은 같은 이름의 자식 HitReceiver를 추가해 피해까지 받습니다.
	var receiver := get_node_or_null("HitReceiver") as HitReceiver
	if receiver != null:
		receiver.receive_hit(damage, hit_position, hit_normal, incoming_direction)
