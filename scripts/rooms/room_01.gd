extends Node3D
class_name Room01

## 첫 실제 플레이 공간입니다. 복도, 문, 작은 부속실의 기하/충돌을 만들며,
## 나중의 적 스폰과 전투 상태 역시 Main이 아닌 이 Room Scene에 붙입니다.

## GameDirector가 방의 변화에 반응할 수 있도록 문 상태를 알립니다.
signal door_state_changed(is_open: bool)

## 문이 한 번 열리면 E를 반복해도 Tween을 중복 실행하지 않습니다.
var entry_door_open := false
## 회전 중심입니다. 문짝과 문 충돌체가 이 노드의 자식입니다.
@onready var door_hinge: Node3D = $DoorHinge

## (중심 Z, 길이 Z) 형식의 복도 조명 구간입니다. 이전에는 바닥/천장이 67m
## 단일 Mesh여서 Compatibility 렌더러에서 멀리 있는 모든 OmniLight까지 같은
## 메시의 조명 수에 포함되었습니다. 고정등 사이에서 Mesh를 나누면 각 구간은
## 근처 조명과 총구 섬광만 받아 바닥/천장의 순간 조명이 빠지지 않습니다.
const CORRIDOR_LIGHT_SEGMENTS: Array[Vector2] = [
	Vector2(8.0, 10.0),
	Vector2(-2.5, 11.0),
	Vector2(-13.5, 11.0),
	Vector2(-24.5, 11.0),
	Vector2(-35.5, 11.0),
	Vector2(-47.5, 13.0),
]

## 왼쪽 구조 벽의 실제 범위(-53m~8m)를 고정등 사이에서 나눈 값입니다.
## 바닥/천장만 나누고 벽을 긴 단일 Mesh로 남기면, 같은 조명 제한 문제가
## 벽에서 반복됩니다.
const LEFT_WALL_LIGHT_SEGMENTS: Array[Vector2] = [
	Vector2(5.5, 5.0),
	Vector2(-2.5, 11.0),
	Vector2(-13.5, 11.0),
	Vector2(-24.5, 11.0),
	Vector2(-35.5, 11.0),
	Vector2(-47.0, 12.0),
]

## 오른쪽 벽은 ROOM 01 출입구(5.1m~6.9m)를 비워 두어야 합니다. 그 외의
## 모든 벽 조각도 짧은 Mesh로 만들어 문 옆만 빛나고 먼 벽이 어두워지는
## 현상을 없앱니다.
const RIGHT_WALL_LIGHT_SEGMENTS: Array[Vector2] = [
	Vector2(9.95, 6.1),
	Vector2(3.90, 2.40),
	Vector2(-2.65, 10.70),
	Vector2(-13.5, 11.0),
	Vector2(-24.5, 11.0),
	Vector2(-35.5, 11.0),
	Vector2(-47.5, 13.0),
]

func _ready() -> void:
	# 구조물 → 방 내부 → 문 순서로 조립합니다. 문은 마지막에 만들면 경첩의
	# 지역 좌표가 다른 복도/방 구조에 영향을 받지 않습니다.
	_build_corridor()
	_build_annex()
	_build_entry_door()

func try_interact(actor: Node3D) -> bool:
	# 이미 열린 문은 이 단계에서 닫히지 않습니다.
	if entry_door_open:
		return false
	# 문 앞의 상호작용 기준점입니다. actor의 현재 높이를 사용해 수직 거리로
	# 상호작용이 막히지 않게 합니다.
	var entry_point := Vector3(1.7, actor.global_position.y, 6.0)
	if actor.global_position.distance_to(entry_point) > 2.4:
		return false
	# 상태를 먼저 바꿔 같은 프레임의 중복 입력을 막습니다.
	entry_door_open = true
	# Node3D 전체를 회전시키므로 보이는 문과 CollisionShape가 함께 열립니다.
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(door_hinge, "rotation:y", deg_to_rad(96.0), 0.48)
	door_state_changed.emit(true)
	return true

func get_prompt(actor: Node3D) -> String:
	# HUD는 이 함수의 반환값만 보여 주므로 방 구조 코드와 UI가 분리됩니다.
	if entry_door_open:
		if actor.global_position.x > 2.8:
			return "ROOM 01  //  탄착 반응을 확인하십시오"
		return "ROOM 01  //  진입 가능"
	var entry_point := Vector3(1.7, actor.global_position.y, 6.0)
	if actor.global_position.distance_to(entry_point) < 2.4:
		return "ROOM 01  //  E: 문 열기"
	return "상층 복도  //  첫 번째 오른쪽 문: ROOM 01"

func _build_corridor() -> void:
	# 복도는 왼쪽 구조 벽, 오른쪽의 닫힌 방들, ROOM 01의 실제 틈으로 나뉩니다.
	for segment_index in CORRIDOR_LIGHT_SEGMENTS.size():
		var segment: Vector2 = CORRIDOR_LIGHT_SEGMENTS[segment_index]
		# 이 여섯 조각의 끝점은 정확히 맞닿습니다. 플레이어 이동에는 하나의 긴
		# 바닥과 동일하지만, 렌더러는 각 조각을 독립 메시로 판단합니다.
		_box("CorridorFloor%02d" % segment_index, Vector3(0, -0.25, segment.x), Vector3(5.2, 0.5, segment.y), Color("30353d"), true)
		_box("CorridorCeiling%02d" % segment_index, Vector3(0, 4.55, segment.x), Vector3(5.2, 0.3, segment.y), Color("1b2028"), false)
	# 벽도 바닥/천장과 같은 이유로 조명 구간별로 나눕니다. 모든 조각은 빈틈없이
	# 맞닿아 있으므로 실제 공간은 변하지 않고, 각 조각의 조명 목록만 짧아집니다.
	for segment_index in LEFT_WALL_LIGHT_SEGMENTS.size():
		var left_segment: Vector2 = LEFT_WALL_LIGHT_SEGMENTS[segment_index]
		_box("LeftStructuralWall%02d" % segment_index, Vector3(-2.6, 2.2, left_segment.x), Vector3(0.34, 4.9, left_segment.y), Color("252a32"), true)
	for segment_index in RIGHT_WALL_LIGHT_SEGMENTS.size():
		var right_segment: Vector2 = RIGHT_WALL_LIGHT_SEGMENTS[segment_index]
		_box("RightStructuralWall%02d" % segment_index, Vector3(2.6, 2.2, right_segment.x), Vector3(0.34, 4.9, right_segment.y), Color("252a32"), true)
	_box("LandingBackWall", Vector3(0, 2.2, 12.8), Vector3(5.2, 4.9, 0.34), Color("252a32"), true)
	# 긴 복도에서는 적은 수의 고정등이 웹 렌더링 비용에 더 안전합니다.
	for z in [8.5, -2.5, -13.5, -24.5, -35.5, -46.5]:
		_add_light(Vector3(0, 3.45, z), Color("c7d5ea"), 1.55)
	# ROOM 02~04는 지금은 닫힌 공간의 존재만 보여 줍니다.
	for room_index in 3:
		var z := -7.5 - room_index * 13.5
		_box("ClosedDoor%d" % room_index, Vector3(2.39, 2.0, z), Vector3(0.13, 3.75, 1.34), Color("563d32"), true, self, &"wood")

func _build_entry_door() -> void:
	# 경첩은 문짝의 한쪽 가장자리에 두어, 문이 사라지는 대신 실제로 회전합니다.
	door_hinge.position = Vector3(2.39, 0, 6.67)
	_box("DoorPanel", Vector3(0, 2.0, -0.67), Vector3(0.13, 3.75, 1.34), Color("563d32"), true, door_hinge, &"wood")
	# 손잡이도 실제 충돌체를 갖게 해야 RayCast가 목재 패널보다 먼저 이 부품을
	# 맞힐 수 있습니다. 얇은 실제 크기보다 조금 넓혀 플레이 중 조준하기도 좋게 합니다.
	_box("DoorHandle", Vector3(-0.10, 2.0, -1.05), Vector3(0.11, 0.12, 0.32), Color("c8a45a"), true, door_hinge, &"metal")
	_box("DoorFrameTop", Vector3(2.28, 3.92, 6.0), Vector3(0.34, 0.18, 1.62), Color("15191f"), false)
	_box("DoorFrameNear", Vector3(2.28, 2.0, 6.77), Vector3(0.34, 3.95, 0.16), Color("15191f"), false)
	_box("DoorFrameFar", Vector3(2.28, 2.0, 5.23), Vector3(0.34, 3.95, 0.16), Color("15191f"), false)

func _build_annex() -> void:
	# 전투 경기장처럼 보이지 않는 작은 관리/정비실 블록아웃입니다.
	_box("Room01Floor", Vector3(6.1, -0.25, 6.0), Vector3(7.0, 0.5, 7.0), Color("353c44"), true)
	_box("Room01Ceiling", Vector3(6.1, 4.55, 6.0), Vector3(7.0, 0.3, 7.0), Color("1c222a"), false)
	_box("Room01OuterWall", Vector3(9.6, 2.2, 6.0), Vector3(0.34, 4.9, 7.0), Color("292f37"), true)
	_box("Room01NearWall", Vector3(6.1, 2.2, 9.5), Vector3(7.0, 4.9, 0.34), Color("292f37"), true)
	_box("Room01FarWall", Vector3(6.1, 2.2, 2.5), Vector3(7.0, 4.9, 0.34), Color("292f37"), true)
	_box("WorkBenchBase", Vector3(8.15, 1.12, 3.55), Vector3(1.85, 1.05, 0.72), Color("46515c"), true, self, &"metal")
	_box("WorkBenchTop", Vector3(8.15, 1.70, 3.55), Vector3(2.05, 0.16, 0.86), Color("66727e"), true, self, &"metal")
	_box("Locker", Vector3(8.82, 1.85, 8.25), Vector3(0.72, 3.7, 1.10), Color("3e4954"), true, self, &"metal")
	_box("LowCabinet", Vector3(5.2, 0.78, 8.25), Vector3(1.45, 1.30, 0.70), Color("535e68"), true, self, &"metal")
	_box("RearExit", Vector3(6.15, 2.0, 2.31), Vector3(1.45, 3.75, 0.13), Color("20262d"), true, self, &"metal")
	# 이 표적은 적 AI가 아닌 사격 피드백 검증용입니다. 방에 들어온 직후에
	# 벽·금속 가구·체력 있는 대상의 반응을 짧게 비교할 수 있게 둡니다.
	_build_training_target()
	_add_light(Vector3(6.1, 3.55, 6.0), Color("e5d3af"), 2.0)
	_add_light(Vector3(8.6, 2.6, 3.6), Color("7faad2"), 1.1)

func _build_training_target() -> void:
	# 원형 사람 모델 대신 사각 표적을 써서 폭력 묘사 없이도 '체력이 있는
	# 맞을 대상'과 일반 가구의 차이를 시험할 수 있게 합니다.
	var target_root := Node3D.new()
	target_root.name = "TrainingTarget"
	target_root.position = Vector3(5.85, 0.0, 4.55)
	add_child(target_root)
	# 표적의 보이는 판, 머리 모양 센서, 금속 지지대를 따로 만들어 나중에
	# 적 모델/골격으로 바뀌어도 HitReceiver 구조는 그대로 유지되게 합니다.
	_box("TargetBase", Vector3(0, 0.20, 0), Vector3(0.72, 0.40, 0.55), Color("3d4650"), true, target_root, &"metal")
	_box("TargetPost", Vector3(0, 0.84, 0), Vector3(0.16, 0.88, 0.16), Color("4b5662"), false, target_root)
	_box("TargetTorso", Vector3(0, 1.43, 0), Vector3(0.72, 1.12, 0.16), Color("c26c3d"), false, target_root)
	_box("TargetHead", Vector3(0, 2.16, 0), Vector3(0.36, 0.33, 0.16), Color("e5b570"), false, target_root)
	# 실제 총알 RayCast는 이 몸체만 맞습니다. 시각 메시와 물리 몸체를 분리하면
	# 나중에 적의 팔/머리 히트박스를 바꿔도 보이는 모델을 다시 조립할 필요가 없습니다.
	var target_body := HitSurface.new()
	target_body.name = "TrainingTargetHitbox"
	target_body.surface_type = &"training"
	target_body.position = Vector3(0, 1.48, 0)
	target_root.add_child(target_body)
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.39
	shape.height = 1.68
	collision.shape = shape
	target_body.add_child(collision)
	# 같은 HitReceiver 컴포넌트는 이후 RUSHER/FLANKER/ANCHOR의 충돌 몸체에도
	# 붙습니다. 이 표적은 4발 후 넘어져 사망/파괴 신호를 눈으로 확인시킵니다.
	var receiver := HitReceiver.new()
	receiver.name = "HitReceiver"
	receiver.max_health = 4
	target_body.add_child(receiver)
	receiver.destroyed.connect(_on_training_target_destroyed.bind(target_root, target_body))

func _on_training_target_destroyed(_hit_position: Vector3, _hit_normal: Vector3, incoming_direction: Vector3, target_root: Node3D, target_body: HitSurface) -> void:
	# 표적은 처형/고어가 아닌 기계식 훈련 표적처럼 단순히 쓰러집니다. 맞은 방향과
	# 반대쪽으로 기울여 플레이어가 '체력이 끝났다'는 결과를 즉시 읽게 합니다.
	target_body.collision_layer = 0
	target_body.collision_mask = 0
	var fall_sign := -1.0
	if incoming_direction.x > 0.0:
		fall_sign = 1.0
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(target_root, "rotation:z", deg_to_rad(68.0) * fall_sign, 0.34)

func _box(node_name: String, position: Vector3, size: Vector3, color: Color, with_collision: bool, parent: Node3D = self, surface_type: StringName = &"concrete") -> void:
	# 하나의 이름 있는 박스에 시각 Mesh와 선택적 물리 Collision을 함께 만듭니다.
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.72
	var visual := MeshInstance3D.new()
	visual.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = material
	visual.position = position
	parent.add_child(visual)
	if with_collision:
		# Collision은 눈에 보이지 않는 StaticBody3D입니다. 벽/가구/문이
		# Player CharacterBody를 막도록 할 때만 생성합니다.
		# 일반 StaticBody3D 대신 HitSurface를 씁니다. 충돌 역할은 같지만, 총알이
		# 맞으면 표면별 반응을 만들 수 있는 take_hit() 공통 함수를 추가로 가집니다.
		var body := HitSurface.new()
		body.name = node_name + "Collision"
		body.surface_type = surface_type
		body.position = position
		parent.add_child(body)
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)

func _add_light(position: Vector3, color: Color, energy: float) -> void:
	# 각 방등은 독립 OmniLight입니다. 이후 전원 차단/경보 연출도 개별 제어합니다.
	var light := OmniLight3D.new()
	light.position = position
	light.light_color = color
	light.light_energy = energy
	light.omni_range = 8.0
	add_child(light)
