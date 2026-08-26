extends Area3D
class_name EnemyHitbox

## EnemyBase의 머리·몸통·다리에 붙는 RayCast 전용 충돌 영역입니다.
## CharacterBody의 이동용 Capsule과 총알 판정을 분리해야 부위별 피해와 반응을
## 추가하면서도 적이 벽에 걸리는 이동 충돌을 단순하게 유지할 수 있습니다.

## EnemyBase가 어느 자세로 반응할지 구분하는 부위 이름입니다.
@export var body_part: StringName = &"torso"
## 같은 총알도 머리처럼 중요한 부위에서는 더 큰 피해를 전달합니다.
@export var damage_multiplier := 1.0

## Scene 안에서 이 Hitbox를 소유한 EnemyBase입니다.
var enemy: EnemyBase

func _ready() -> void:
	# Hitbox가 나중에 한 단계 더 깊은 Node 아래로 이동해도 경로 문자열이 깨지지
	# 않도록 부모를 거슬러 올라가 EnemyBase를 찾습니다.
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor is EnemyBase:
			enemy = ancestor as EnemyBase
			break
		ancestor = ancestor.get_parent()

func take_hit(damage: int, hit_position: Vector3, hit_normal: Vector3, incoming_direction := Vector3.ZERO) -> void:
	# 일반 벽의 HitSurface와 마찬가지로 공통 ImpactManager에서 탄착 효과를 만듭니다.
	# 현재는 피나 고어 대신 전술복 섬유/먼지 색의 작은 파편만 사용합니다.
	var impact_manager := get_tree().get_first_node_in_group("impact_manager") as ImpactManager
	if impact_manager != null:
		impact_manager.spawn_impact(&"fabric", hit_position, hit_normal, incoming_direction)
	if enemy == null:
		return
	# 최소 피해는 1로 유지해 다리도 완전히 무효 판정이 되지 않게 합니다.
	var scaled_damage := maxi(1, roundi(float(damage) * damage_multiplier))
	enemy.receive_hit(scaled_damage, hit_position, hit_normal, incoming_direction, body_part)
