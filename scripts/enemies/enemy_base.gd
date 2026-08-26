extends CharacterBody3D
class_name EnemyBase

## RUSHER, FLANKER, ANCHOR가 공통으로 사용할 적 몸체의 첫 단계입니다.
## 지금은 이동/공격 AI를 넣지 않고, 얼굴 방향·부위별 Hitbox·피격 반응·쓰러짐만
## 검증합니다. 이후 역할별 AI는 이 Scene을 상속하거나 구성 요소로 재사용합니다.

@export var gravity := 22.0

## 보이는 몸 전체를 묶는 축입니다. 이동용 CharacterBody는 세워 둔 채 이 축만
## 흔들거나 쓰러뜨리면 물리 충돌과 피격 애니메이션이 서로 간섭하지 않습니다.
@onready var visual_root: Node3D = $VisualRoot
@onready var hit_receiver: HitReceiver = $HitReceiver
@onready var hitboxes: Node3D = $Hitboxes

## 마지막으로 맞은 부위는 HitReceiver의 공통 신호가 반응 자세를 고를 때 사용합니다.
var last_body_part: StringName = &"torso"
## 쓰러진 뒤에는 일반 피격 복귀와 중력 이동을 반복하지 않습니다.
var is_down := false

func _ready() -> void:
	_build_blockout_visual()
	hit_receiver.hit_received.connect(_on_hit_received)
	hit_receiver.destroyed.connect(_on_destroyed)

func _physics_process(delta: float) -> void:
	if is_down:
		return
	# 아직 AI가 없어도 CharacterBody가 ROOM 01 바닥 위에 안정적으로 서게 합니다.
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.1
	velocity.x = 0.0
	velocity.z = 0.0
	move_and_slide()

func _process(delta: float) -> void:
	if is_down:
		return
	# 피격 순간 꺾인 VisualRoot를 빠르되 딱딱하지 않게 원래 자세로 복귀시킵니다.
	# 마우스/AI 회전이 붙을 CharacterBody root는 건드리지 않습니다.
	var recovery_weight := 1.0 - exp(-delta * 9.0)
	visual_root.rotation = visual_root.rotation.lerp(Vector3.ZERO, recovery_weight)
	visual_root.position = visual_root.position.lerp(Vector3.ZERO, recovery_weight)

func receive_hit(damage: int, hit_position: Vector3, hit_normal: Vector3, incoming_direction: Vector3, body_part: StringName) -> void:
	# Hitbox가 부위 정보를 보존한 뒤 공통 체력 부품으로 피해를 전달합니다.
	last_body_part = body_part
	hit_receiver.receive_hit(damage, hit_position, hit_normal, incoming_direction)

func _on_hit_received(_damage: int, _hit_position: Vector3, _hit_normal: Vector3, incoming_direction: Vector3) -> void:
	# 총알 진행 방향을 적의 로컬 좌표로 바꿔 어느 쪽 어깨가 먼저 밀리는지 정합니다.
	var local_direction := global_transform.basis.inverse() * incoming_direction.normalized()
	var body_pitch := 0.075
	var backward_shift := 0.045
	match last_body_part:
		&"head":
			body_pitch = 0.16
			backward_shift = 0.070
		&"legs":
			body_pitch = -0.055
			backward_shift = 0.030
		_:
			pass
	# 좌우 기울기는 입사 방향의 X 성분을 사용하고 상한을 둡니다.
	visual_root.rotation.x = body_pitch
	visual_root.rotation.z = clampf(-local_direction.x * 0.14, -0.14, 0.14)
	visual_root.position = Vector3(local_direction.x * 0.035, 0.0, backward_shift)

func _on_destroyed(_hit_position: Vector3, _hit_normal: Vector3, incoming_direction: Vector3) -> void:
	is_down = true
	# 쓰러진 뒤 RayCast가 보이지 않는 서 있는 Hitbox를 계속 맞히지 않게 끕니다.
	for child in hitboxes.get_children():
		if child is Area3D:
			(child as Area3D).collision_layer = 0
	# 제압된 몸체가 좁은 ROOM 01 진입로를 영구히 막지 않도록 이동 충돌도 끕니다.
	collision_mask = 0
	var local_direction := global_transform.basis.inverse() * incoming_direction.normalized()
	var fall_sign := -1.0 if local_direction.x <= 0.0 else 1.0
	# 짧은 절차형 쓰러짐입니다. 최종 Skeleton/AnimationTree가 들어오면 이 함수의
	# 상태 전환은 유지하고 Tween 부분만 애니메이션 재생으로 교체합니다.
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(visual_root, "rotation:z", deg_to_rad(78.0) * fall_sign, 0.42)
	tween.parallel().tween_property(visual_root, "position:y", -0.55, 0.42)

func _build_blockout_visual() -> void:
	# 전술 장비를 입은 명확한 적 실루엣입니다. 평범한 거주자처럼 보이는 소품은
	# 사용하지 않고, 얼굴 앞의 눈/마스크로 시야 방향을 즉시 읽게 합니다.
	var uniform := _material(Color("222b36"), 0.12, 0.76)
	var vest := _material(Color("111820"), 0.08, 0.88)
	var skin := _material(Color("c59575"), 0.0, 0.82)
	var mask := _material(Color("323a43"), 0.10, 0.72)
	var boot := _material(Color("0b0e12"), 0.18, 0.90)
	var eye := _material(Color("d8edf4"), 0.0, 0.35, true)
	_box_visual("Torso", Vector3(0, 0.34, 0), Vector3(0.58, 0.72, 0.32), uniform)
	_box_visual("Vest", Vector3(0, 0.36, -0.19), Vector3(0.64, 0.56, 0.12), vest)
	_box_visual("Pelvis", Vector3(0, -0.11, 0), Vector3(0.48, 0.25, 0.30), uniform)
	_box_visual("LeftArm", Vector3(-0.40, 0.30, 0), Vector3(0.18, 0.72, 0.20), uniform)
	_box_visual("RightArm", Vector3(0.40, 0.30, 0), Vector3(0.18, 0.72, 0.20), uniform)
	_box_visual("LeftLeg", Vector3(-0.16, -0.58, 0), Vector3(0.22, 0.70, 0.25), uniform)
	_box_visual("RightLeg", Vector3(0.16, -0.58, 0), Vector3(0.22, 0.70, 0.25), uniform)
	_box_visual("LeftBoot", Vector3(-0.16, -0.91, -0.07), Vector3(0.24, 0.18, 0.38), boot)
	_box_visual("RightBoot", Vector3(0.16, -0.91, -0.07), Vector3(0.24, 0.18, 0.38), boot)
	_sphere_visual("Head", Vector3(0, 0.94, 0), 0.28, skin)
	# Godot의 전방은 -Z입니다. 마스크·코·두 눈을 -Z 면에 두어 머리 회전 없이도
	# 플레이어가 적이 바라보는 방향을 알 수 있습니다.
	_box_visual("FaceMask", Vector3(0, 0.87, -0.255), Vector3(0.38, 0.21, 0.06), mask)
	_box_visual("NoseDirection", Vector3(0, 0.98, -0.292), Vector3(0.075, 0.10, 0.08), skin)
	_box_visual("LeftEye", Vector3(-0.095, 1.045, -0.292), Vector3(0.055, 0.035, 0.025), eye)
	_box_visual("RightEye", Vector3(0.095, 1.045, -0.292), Vector3(0.055, 0.035, 0.025), eye)

func _box_visual(part_name: String, local_position: Vector3, size: Vector3, material: Material) -> void:
	var part := MeshInstance3D.new()
	part.name = part_name
	var mesh := BoxMesh.new()
	mesh.size = size
	part.mesh = mesh
	part.material_override = material
	part.position = local_position
	visual_root.add_child(part)

func _sphere_visual(part_name: String, local_position: Vector3, radius: float, material: Material) -> void:
	var part := MeshInstance3D.new()
	part.name = part_name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	part.mesh = mesh
	part.material_override = material
	part.position = local_position
	visual_root.add_child(part)

func _material(color: Color, metallic: float, roughness: float, emission := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	if emission:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.8
	return material
