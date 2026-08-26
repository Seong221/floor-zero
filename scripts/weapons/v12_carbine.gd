extends Node3D
class_name V12Carbine

## 1인칭 화면에서 보이는 V-12 카빈 Scene의 제어기입니다.
## WeaponController는 '쏠 수 있는가'만 판단하고, 이 스크립트는 총 모델,
## 카메라 중앙 RayCast, 반동, 흔들림, 총구 화염을 담당합니다.

## Camera3D 기준의 일반 자세 위치입니다. 오른손에 들린 총처럼 우측에 둡니다.
const HIP_POSITION := Vector3(0.42, -0.31, -0.90)
## 정조준 자세 위치입니다. 가늠쇠가 화면 중앙으로 가까워집니다.
const AIM_POSITION := Vector3(0.08, -0.17, -0.72)

## 반동 시 Model/Muzzle를 한꺼번에 뒤로 움직일 기준점입니다.
@onready var recoil_pivot: Node3D = $RecoilPivot
## 임시 박스 메시들을 담는 노드입니다. 나중에 Blender GLB로 교체됩니다.
@onready var model: Node3D = $RecoilPivot/Model
## 실제 탄구 위치입니다. 현재는 표시용이고, 명중 판정은 카메라 중심에서 합니다.
@onready var muzzle: Marker3D = $RecoilPivot/Muzzle
## 탄피가 시작할 리시버 오른쪽 배출구입니다. 총구와 의도적으로 분리합니다.
@onready var ejection_port: Marker3D = $RecoilPivot/EjectionPort
## 발사 순간만 아주 짧게 밝아지는 조명입니다.
@onready var muzzle_flash: OmniLight3D = $RecoilPivot/MuzzleFlash
## 조명과 별개로 플레이어가 총구에서 직접 보게 되는 십자형 화염 메시입니다.
@onready var muzzle_visual: Node3D = $RecoilPivot/MuzzleVisual
## 총구 화염이 사라진 직후 잠깐 남는 연기 메시의 기준 노드입니다.
@onready var muzzle_smoke: Node3D = $RecoilPivot/MuzzleSmoke
## 탄약/발사 간격의 공통 규칙을 가진 자식 노드입니다.
@onready var controller: WeaponController = $WeaponController
## 플레이어 바로 앞에서 들리는 1인칭 총성입니다. 공간 좌표로 감쇠시키지 않고
## AudioStreamPlayer를 사용해 어느 방향을 보아도 총 자체의 압력은 일정하게 들립니다.
@onready var fire_audio: AudioStreamPlayer = $FireAudio
## 총성 아래에 작게 겹치는 노리쇠·총몸 작동음입니다. 총성 파일과 분리했기 때문에
## 나중에 소음기나 다른 총열을 써도 같은 기계 작동의 정체성을 유지할 수 있습니다.
@onready var mechanical_audio: AudioStreamPlayer = $MechanicalAudio

## 탄피가 처음 단단한 표면에 닿을 때 재생할 짧은 금속 낙하음입니다.
const CASING_DROP_STREAM: AudioStream = preload("res://assets/audio/props/casing_drop_01.ogg")

## 이 총을 들고 있는 Player. 달리기/속도 정보를 읽기 위해 전달받습니다.
var player: PlayerController
## 누적 반동값입니다. 발사 때 증가하고 매 프레임 0으로 돌아갑니다.
var recoil := 0.0
## 이동 중 총의 좌우/상하 흔들림입니다.
var sway := Vector2.ZERO
## 빛과 별개로 총구에서 보이는 화염의 남은 시간입니다.
var muzzle_visual_time := 0.0
## 화염 뒤에 잠깐 남는 회색 연기의 남은 시간입니다.
var muzzle_smoke_time := 0.0
## 과도한 물리 객체 생성을 막기 위해 동시에 보이는 탄피를 제한합니다.
const MAX_ACTIVE_CASINGS := 12
## 월드에 떨어진 탄피 RigidBody 목록입니다.
var active_casings: Array[RigidBody3D] = []
## 모든 탄피가 공유하는 작은 원통 Mesh/Material/CollisionShape입니다.
var casing_mesh: CylinderMesh
var casing_material: StandardMaterial3D
var casing_shape: CylinderShape3D
## 화염/연기 투명도를 매 프레임 조절하기 위해 Material 참조를 유지합니다.
var muzzle_smoke_material: StandardMaterial3D

func _ready() -> void:
	# 실제 최종 모델 전까지 사용할 저비용 박스 총기 모델을 조립합니다.
	_build_blockout_model()
	# 성공 사격 신호만 받으므로 빈 탄창 클릭에는 반동이 생기지 않습니다.
	controller.fired.connect(_on_fired)
	# OmniLight는 평소 켜 두면 비용이 있으므로 발사 외에는 완전히 끕니다.
	muzzle_flash.light_energy = 0.0
	# 화염과 연기는 텍스처 없이도 보이는 저비용 메시로 만듭니다.
	_build_muzzle_feedback_meshes()
	# 탄피 Mesh/Shape는 매 발 새로 만들지 않고 모든 RigidBody가 공유합니다.
	_build_casing_resources()

func set_player(new_player: PlayerController) -> void:
	# Player Scene의 _ready에서 호출됩니다.
	player = new_player

func _process(delta: float) -> void:
	# 발사 간격은 프레임률과 관계없이 감소합니다.
	controller.tick(delta)
	# Player가 아직 연결되기 전에는 시각/입력 처리를 하지 않습니다.
	if player == null:
		return
	# 총의 자세는 사격 여부와 무관하게 계속 보정합니다.
	_update_pose(delta)
	# 연사 대응: 버튼을 누르고 있으면 WeaponController가 발사 간격을 제한합니다.
	if Input.is_action_pressed("shoot"):
		_fire()

func _fire() -> void:
	# 탄약 부족 또는 쿨다운이면 여기서 끝나며 시각 효과도 재생되지 않습니다.
	if not controller.try_fire():
		return
	# V12Carbine은 Camera3D의 자식입니다. 부모가 바뀌면 안전하게 중단합니다.
	var camera := get_parent() as Camera3D
	if camera == null:
		return
	# FPS의 명중 판정은 화면 가운데에서 시작합니다. 총구 Mesh에서 시작하면
	# 가까운 벽에 총구가 막히거나 크로스헤어와 탄착점이 어긋날 수 있습니다.
	var origin := camera.global_position
	var direction := -camera.global_transform.basis.z
	# 80m는 ROOM 01/복도 데모에 충분한 최대 명중 거리입니다.
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 80.0)
	# 플레이어 자신의 CollisionShape를 맞히지 않도록 제외합니다.
	query.exclude = [player.get_rid()]
	# 벽/문은 PhysicsBody, EnemyBase의 부위별 Hitbox는 Area3D입니다. 둘을 같은
	# 화면 중앙 RayCast로 맞힐 수 있도록 Area 충돌도 명시적으로 포함합니다.
	query.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	# 미래 EnemyController가 take_hit()을 구현하면, 총 시스템은 적 종류를
	# 알 필요 없이 이 공통 함수만 호출합니다.
	if not hit.is_empty() and hit.collider.has_method("take_hit"):
		# damage/명중점/표면 법선/입사 방향을 함께 보냅니다. HitSurface는 이 정보로
		# 표면별 효과를 만들고, 나중의 적은 입사 방향으로 피격 자세도 고를 수 있습니다.
		hit.collider.take_hit(1, hit.position, hit.normal, direction)

func _update_pose(delta: float) -> void:
	# 우클릭 중에는 총의 위치를 조준 위치로 보간합니다.
	var is_aiming := Input.is_action_pressed("aim")
	var target := AIM_POSITION if is_aiming else HIP_POSITION
	# 실제 이동 속도로 흔들림 강도를 계산합니다.
	var movement := Vector2(player.velocity.x, player.velocity.z).length()
	var time := Time.get_ticks_msec() * 0.001
	var bob_multiplier := 1.0
	# Shift 달리기 중에는 흔들림을 키웁니다. 정조준 달리기는 가능하지만,
	# 일반 달리기보다 덜 흔들려 조준 자세가 읽히도록 합니다.
	if player.is_sprinting:
		bob_multiplier = 1.9 if is_aiming else 2.5
	# sin/cos를 서로 다른 속도로 섞어 기계적 반복감을 줄입니다.
	sway = Vector2(sin(time * 8.0), cos(time * 12.0)) * minf(movement * 0.0035 * bob_multiplier, 0.035)
	# lerp로 자세 전환을 부드럽게 하되 조준 반응은 빠르게 유지합니다.
	position = position.lerp(target + Vector3(sway.x, sway.y, 0), 1.0 - exp(-delta * 16.0))
	# 누적 반동은 발사 후 점차 복귀합니다.
	recoil = move_toward(recoil, 0.0, delta * 9.0)
	# 반동은 총 전체의 뒤쪽 이동(+Z)과 아주 작은 상향 이동으로 표현합니다.
	recoil_pivot.position = Vector3(0, 0.012 * recoil, 0.13 * recoil)
	recoil_pivot.rotation.x = -0.13 * recoil + sway.y * 0.7
	recoil_pivot.rotation.y = sway.x * 0.9
	# 총구 섬광 조명은 빠르게 감쇠해야 연사 중에도 지속 조명처럼 보이지 않습니다.
	# 바닥/천장 문제는 감쇠가 아니라 Compatibility의 메시별 조명 수 제한에서 해결합니다.
	muzzle_flash.light_energy = move_toward(muzzle_flash.light_energy, 0.0, delta * 25.0)
	_update_muzzle_visuals(delta)

func _on_fired() -> void:
	# 연속 사격에는 누적감이 있으나 1.7 이상으로 과도하게 튀지 않게 제한합니다.
	recoil = minf(recoil + 1.0, 1.7)
	# 7m OmniLight를 짧게 켜 실내 바닥과 천장에도 주황빛이 닿게 합니다.
	# 이 조명은 발사 외에는 energy=0이므로 고정등보다 훨씬 저렴합니다.
	muzzle_flash.light_energy = 7.5
	# 화면에 보이는 불꽃/연기는 조명과 따로 시간을 관리합니다. 따라서 벽이 밝지
	# 않은 아주 넓은 장소에서도 플레이어는 격발 순간을 확실히 읽을 수 있습니다.
	muzzle_visual_time = 0.055
	muzzle_smoke_time = 0.28
	muzzle_visual.rotation.z = randf_range(-0.35, 0.35)
	muzzle_visual.scale = Vector3.ONE * randf_range(0.82, 1.18)
	# 카메라 반동은 모델 반동보다 작고 예측 가능한 5발 패턴을 사용합니다. 정조준은
	# 더 안정적으로 남기되, 완전히 무반동처럼 보이지 않게 65% 강도를 유지합니다.
	var recoil_pattern := [0.10, -0.08, 0.15, -0.06, 0.03]
	var pattern_index := int(controller.shot_index % recoil_pattern.size())
	var aim_multiplier := 0.65 if Input.is_action_pressed("aim") else 1.0
	player.apply_weapon_recoil(0.58 * aim_multiplier, float(recoil_pattern[pattern_index]) * aim_multiplier)
	_spawn_casing()
	# _update_pose는 이번 프레임의 _fire보다 먼저 호출됩니다. 따라서 다음 프레임을
	# 기다리지 않고 이번 격발 프레임부터 화염과 연기가 보이도록 즉시 갱신합니다.
	_update_muzzle_visuals(0.0)
	# 같은 녹음이 연사에서 기계적으로 반복되어 들리지 않도록 1.5% 안에서만
	# 피치를 바꿉니다. 폭을 크게 잡으면 총기 종류와 무게가 매 발 달라져 들립니다.
	fire_audio.pitch_scale = randf_range(0.985, 1.015)
	# Scene의 max_polyphony=6 덕분에 이전 총성을 끊지 않고 다음 총성이 겹칩니다.
	# OGG 파일은 사전 디코딩되는 일반 AudioStream이어서 Web Export에서도 사용할 수 있습니다.
	fire_audio.play()
	# 현재 샘플은 하나뿐이므로 총성보다 더 좁은 피치 변화와 낮은 음량으로 겹칩니다.
	# 총성의 충격을 덮지 않으면서 발사 장치가 실제로 움직였다는 층을 추가합니다.
	mechanical_audio.pitch_scale = randf_range(0.98, 1.02)
	mechanical_audio.play()

func _build_muzzle_feedback_meshes() -> void:
	# 서로 직각인 두 QuadMesh가 짧은 별 모양 화염을 만듭니다. 복잡한 파티클이나
	# 텍스처를 쓰지 않아 Compatibility/WebGL에서도 비용이 작습니다.
	var flame_material := StandardMaterial3D.new()
	flame_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flame_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	flame_material.albedo_color = Color(1.0, 0.55, 0.12, 0.95)
	flame_material.emission_enabled = true
	flame_material.emission = Color(1.0, 0.27, 0.035, 1.0)
	flame_material.emission_energy_multiplier = 4.2
	for cross_index in 2:
		var flame := MeshInstance3D.new()
		flame.name = "MuzzleFlame%d" % cross_index
		var mesh := QuadMesh.new()
		mesh.size = Vector2(0.26, 0.62)
		flame.mesh = mesh
		flame.material_override = flame_material
		flame.rotation.z = deg_to_rad(90.0 * cross_index)
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		muzzle_visual.add_child(flame)
	# 연기는 작은 반투명 구체 하나만 확장/소멸시킵니다. 실제 연기 파티클은 나중에
	# 텍스처를 확보한 뒤 교체할 수 있고, 이 노드 구조는 그대로 재사용합니다.
	var smoke := MeshInstance3D.new()
	smoke.name = "MuzzleSmokePuff"
	var smoke_mesh := SphereMesh.new()
	# 이전에는 실제 반지름이 0.02m까지 작아져 눈에 거의 보이지 않았습니다.
	# 시작부터 읽을 수 있는 크기로 두고, 짧게 퍼지는 얇은 연기 덩어리로 만듭니다.
	smoke_mesh.radius = 0.22
	smoke_mesh.height = 0.44
	smoke_mesh.radial_segments = 8
	smoke_mesh.rings = 4
	smoke.mesh = smoke_mesh
	muzzle_smoke_material = StandardMaterial3D.new()
	muzzle_smoke_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	muzzle_smoke_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	muzzle_smoke_material.albedo_color = Color(0.60, 0.64, 0.68, 0.0)
	smoke.material_override = muzzle_smoke_material
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	muzzle_smoke.add_child(smoke)
	muzzle_visual.visible = false
	muzzle_smoke.visible = false

func _update_muzzle_visuals(delta: float) -> void:
	# 0.055초 화염은 실제 발광체처럼 짧고 선명하게 끊깁니다.
	muzzle_visual_time = maxf(0.0, muzzle_visual_time - delta)
	muzzle_visual.visible = muzzle_visual_time > 0.0
	# 0.28초 연기는 크기가 조금 커지며 옅어집니다. 총과 함께 움직이는 화면 효과라
	# 전용 파티클 노드보다 예측 가능하고, 첫 피드백 단계에 충분히 가볍습니다.
	muzzle_smoke_time = maxf(0.0, muzzle_smoke_time - delta)
	muzzle_smoke.visible = muzzle_smoke_time > 0.0
	if muzzle_smoke_time > 0.0:
		var smoke_ratio := muzzle_smoke_time / 0.28
		muzzle_smoke.scale = Vector3.ONE * lerpf(0.48, 1.45, 1.0 - smoke_ratio)
		var smoke_color := muzzle_smoke_material.albedo_color
		smoke_color.a = smoke_ratio * 0.38
		muzzle_smoke_material.albedo_color = smoke_color

func _build_casing_resources() -> void:
	# 원통의 길이 축은 Y입니다. 탄피 몸체가 약간 두껍게 보이도록 8면만 써서
	# 실루엣은 유지하면서도 WebGL에서 불필요한 폴리곤을 늘리지 않습니다.
	casing_mesh = CylinderMesh.new()
	casing_mesh.top_radius = 0.026
	casing_mesh.bottom_radius = 0.023
	casing_mesh.height = 0.082
	casing_mesh.radial_segments = 8
	casing_mesh.rings = 1
	casing_material = StandardMaterial3D.new()
	casing_material.albedo_color = Color("b98b35")
	casing_material.metallic = 0.76
	casing_material.roughness = 0.30
	casing_shape = CylinderShape3D.new()
	casing_shape.radius = 0.027
	casing_shape.height = 0.085

func _spawn_casing() -> void:
	# 현재 살아 있는 탄피만 남깁니다. 이미 Timer로 삭제된 노드를 배열에 보관하지
	# 않도록 먼저 청소합니다.
	for index in range(active_casings.size() - 1, -1, -1):
		if not is_instance_valid(active_casings[index]):
			active_casings.remove_at(index)
	# 열세 번째 탄피는 가장 오래된 것을 치웁니다. 이 상한 덕분에 무한 탄약 실험도
	# 물리 객체가 끝없이 쌓이지 않습니다.
	while active_casings.size() >= MAX_ACTIVE_CASINGS:
		var old_casing: RigidBody3D = active_casings.pop_front()
		if is_instance_valid(old_casing):
			old_casing.queue_free()
	var camera := get_parent() as Camera3D
	if camera == null:
		return
	var casing := RigidBody3D.new()
	casing.name = "SpentCasing"
	casing.mass = 0.012
	casing.gravity_scale = 0.9
	casing.linear_damp = 0.25
	casing.angular_damp = 0.08
	# RigidBody가 실제 바닥/벽과 접촉한 순간에만 탄피음을 울리기 위한 설정입니다.
	# 최대 접촉 수를 작게 제한하고 첫 충돌 후에는 다시 재생하지 않습니다.
	casing.contact_monitor = true
	casing.max_contacts_reported = 2
	# 탄피는 플레이어를 밀거나 길을 막으면 안 됩니다. StaticBody3D(기본 layer 1)와
	# 바닥 충돌만 하고, Player 본체와는 월드에 들어온 뒤 별도 예외 처리합니다.
	casing.collision_layer = 0
	casing.collision_mask = 1
	var visual := MeshInstance3D.new()
	visual.mesh = casing_mesh
	visual.material_override = casing_material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	casing.add_child(visual)
	var collision := CollisionShape3D.new()
	collision.shape = casing_shape
	casing.add_child(collision)
	# 탄피마다 하나의 3D 재생기만 붙입니다. 탄피 자체가 최대 12개, 수명 2.4초로
	# 제한되어 있으므로 별도 전역 오디오 풀 없이도 노드 수가 확실하게 제한됩니다.
	var drop_audio := AudioStreamPlayer3D.new()
	drop_audio.name = "DropAudio"
	drop_audio.stream = CASING_DROP_STREAM
	drop_audio.unit_size = 1.4
	drop_audio.max_distance = 14.0
	drop_audio.volume_db = -7.0
	casing.add_child(drop_audio)
	# 탄피는 총구가 아닌 리시버 오른쪽 배출구에서 생성합니다. 중요한 점은 월드
	# Scene에 먼저 추가한 뒤 전역 변환을 설정하는 것입니다. Tree 밖 RigidBody의
	# 전역 좌표를 먼저 설정하면 물리 등록 순간 바닥 원점으로 보정될 수 있습니다.
	var right := camera.global_transform.basis.x.normalized()
	var up := camera.global_transform.basis.y.normalized()
	var forward := -camera.global_transform.basis.z.normalized()
	get_tree().current_scene.add_child(casing)
	casing.global_position = ejection_port.global_position + right * 0.08 + up * 0.025
	casing.global_basis = camera.global_transform.basis.rotated(right, deg_to_rad(90.0))
	casing.add_collision_exception_with(player)
	casing.linear_velocity = right * randf_range(1.35, 1.80) + up * randf_range(0.62, 0.92) + forward * randf_range(0.06, 0.18)
	casing.angular_velocity = Vector3(randf_range(-12.0, 12.0), randf_range(-18.0, 18.0), randf_range(-10.0, 10.0))
	# body_entered의 충돌 상대 뒤에 bind 인수가 전달됩니다. 첫 유효 충돌만
	# _on_casing_body_entered에서 받아 같은 탄피가 바닥에서 튈 때 반복되지 않게 합니다.
	casing.body_entered.connect(_on_casing_body_entered.bind(casing, drop_audio))
	active_casings.append(casing)
	# 정지한 탄피도 2.4초 후 지워 다음 전투에 남지 않게 합니다.
	var retire_timer := Timer.new()
	retire_timer.one_shot = true
	retire_timer.wait_time = 2.4
	retire_timer.timeout.connect(_retire_casing.bind(casing))
	casing.add_child(retire_timer)
	retire_timer.start()

func _on_casing_body_entered(_body: Node, casing: RigidBody3D, drop_audio: AudioStreamPlayer3D) -> void:
	if not is_instance_valid(casing) or not is_instance_valid(drop_audio):
		return
	# 생성 직후 총기/플레이어 주변의 미세 접촉이나 이미 울린 반동은 제외합니다.
	if bool(casing.get_meta("drop_sound_played", false)) or casing.linear_velocity.length() < 0.35:
		return
	casing.set_meta("drop_sound_played", true)
	# 같은 낙하 샘플도 약간씩 다른 작은 금속 물체처럼 들리게 만듭니다.
	drop_audio.pitch_scale = randf_range(0.94, 1.07)
	drop_audio.volume_db = randf_range(-8.5, -6.0)
	drop_audio.play()

func _retire_casing(casing: RigidBody3D) -> void:
	# Timer와 최대 개수 제한이 같은 탄피를 동시에 정리해도 안전하도록 유효성을 확인합니다.
	active_casings.erase(casing)
	if is_instance_valid(casing):
		casing.queue_free()

func _build_blockout_model() -> void:
	# 이 블록아웃은 기능 검증용입니다. 이름과 부품 분할은 최종 GLB 교체 때
	# 유지하여 스크립트의 반동/총구 구조를 바꾸지 않게 합니다.
	var polymer := _material(Color("11171d"), 0.18)
	var steel := _material(Color("303b47"), 0.88)
	var dark_steel := _material(Color("1b222b"), 0.78)
	var accent := _material(Color("b88136"), 0.68)
	_box("Receiver", Vector3(0, 0.0, -0.08), Vector3(0.30, 0.23, 0.52), steel)
	_box("UpperRail", Vector3(0, 0.145, -0.08), Vector3(0.12, 0.04, 0.70), dark_steel)
	_box("Handguard", Vector3(0, -0.01, -0.60), Vector3(0.25, 0.19, 0.58), polymer)
	_box("Barrel", Vector3(0, 0.0, -1.00), Vector3(0.10, 0.10, 0.35), dark_steel)
	_box("MuzzleDevice", Vector3(0, 0.0, -1.20), Vector3(0.14, 0.13, 0.13), steel)
	_box("Stock", Vector3(0, -0.05, 0.50), Vector3(0.25, 0.16, 0.58), polymer)
	_box("Magazine", Vector3(0, -0.30, -0.08), Vector3(0.17, 0.38, 0.24), dark_steel, Vector3(-12.0, 0, 0))
	_box("Grip", Vector3(0, -0.25, 0.13), Vector3(0.16, 0.34, 0.20), polymer, Vector3(-16.0, 0, 0))
	_box("Selector", Vector3(0.16, -0.03, 0.05), Vector3(0.035, 0.07, 0.07), accent)

func _box(part_name: String, local_position: Vector3, size: Vector3, material: Material, rotation := Vector3.ZERO) -> void:
	# 각 총기 부품을 독립 MeshInstance3D로 만듭니다. 이후 노리쇠·탄창처럼
	# 특정 부품만 애니메이션해야 할 때도 이름으로 찾아 교체할 수 있습니다.
	var part := MeshInstance3D.new()
	part.name = part_name
	var mesh := BoxMesh.new()
	mesh.size = size
	part.mesh = mesh
	part.material_override = material
	part.position = local_position
	part.rotation_degrees = rotation
	model.add_child(part)

func _material(color: Color, metallic: float) -> StandardMaterial3D:
	# Compatibility 렌더러에서도 작동하는 가벼운 StandardMaterial3D를 만듭니다.
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = 0.42
	return material
