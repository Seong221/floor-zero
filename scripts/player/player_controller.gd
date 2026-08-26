extends CharacterBody3D
class_name PlayerController

## 플레이어의 실제 몸/충돌/이동/시점만 담당합니다.
## 총기, 체력, HUD, 미션 진행은 별도 Scene에 있으므로 이 파일은
## WASD와 Shift를 고쳐도 전투 규칙이 깨지지 않게 분리되어 있습니다.

## 일반 이동 속도입니다.
@export var walk_speed := 6.8
## Shift만 누른 일반 달리기 속도입니다.
@export var sprint_speed := 9.4
## 우클릭 정조준 중의 안정적인 이동 속도입니다.
@export var aim_speed := 4.6
## 정조준을 유지한 Shift 달리기 속도입니다.
@export var aim_sprint_speed := 7.25
@export var acceleration := 26.0
@export var gravity := 22.0
@export var look_sensitivity := 0.0027

## Yaw는 좌우 회전, Pitch는 상하 회전입니다. 분리해야 위를 볼 때
## CharacterBody 전체가 넘어가는 문제가 생기지 않습니다.
@onready var yaw: Node3D = $Yaw
@onready var pitch: Node3D = $Yaw/Pitch
## CameraKick은 사격 반동만 담당하는 중간 축입니다. 플레이어 마우스 입력은
## Pitch에, 총의 되돌아오는 반동은 CameraKick에 적용해 서로 덮어쓰지 않습니다.
@onready var camera_kick: Node3D = $Yaw/Pitch/CameraKick
@onready var camera: Camera3D = $Yaw/Pitch/CameraKick/Camera3D
## Camera의 자식이라 화면/시점과 항상 함께 움직이는 Weapon Scene입니다.
@onready var weapon: V12Carbine = $Yaw/Pitch/CameraKick/Camera3D/V12Carbine

## Weapon Scene이 흔들림 강도를 정할 때 읽는 현재 달리기 상태입니다.
var is_sprinting := false

func _ready() -> void:
	# Weapon Scene이 이 플레이어의 속도/충돌 RID를 알도록 연결합니다.
	weapon.set_player(self)

func _physics_process(delta: float) -> void:
	# 중력과 이동은 프레임률이 아니라 물리 프레임에서 처리합니다.
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.1

	# Input Map의 WASD를 -1~1 2D 벡터로 읽습니다.
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	# 로컬 입력을 카메라의 좌우 방향(Yaw) 기준 월드 이동으로 바꿉니다.
	var direction := (yaw.global_transform.basis * Vector3(input_vector.x, 0, input_vector.y)).normalized()
	# 정조준과 Shift는 동시에 허용됩니다.
	var is_aiming := Input.is_action_pressed("aim")
	is_sprinting = Input.is_action_pressed("sprint") and input_vector.length() > 0.05
	# 기본은 걷기이며, 상태 조합에 따라 속도만 바꿉니다.
	var current_speed := walk_speed
	if is_sprinting:
		current_speed = aim_sprint_speed if is_aiming else sprint_speed
	elif is_aiming:
		current_speed = aim_speed
	# 목표 속도로 즉시 점프하지 않고 acceleration만큼 접근해 이동 질량을 만듭니다.
	var desired_velocity := direction * current_speed
	velocity.x = move_toward(velocity.x, desired_velocity.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, desired_velocity.z, acceleration * delta)
	move_and_slide()

	# 조준은 카메라 이동 대신 FOV를 줄여 더 안정적이고 예측 가능한 화면을 만듭니다.
	var desired_fov := 65.0 if is_aiming else 75.0
	camera.fov = lerpf(camera.fov, desired_fov, 1.0 - exp(-delta * 14.0))
	# 총기 반동은 마우스가 조종하는 Pitch가 아니라 CameraKick만 원위치로 되돌립니다.
	# 그래서 반동 복귀 중에도 플레이어의 마우스 조준이 끌려가거나 덮어써지지 않습니다.
	camera_kick.rotation.x = move_toward(camera_kick.rotation.x, 0.0, deg_to_rad(12.0) * delta)
	camera_kick.rotation.y = move_toward(camera_kick.rotation.y, 0.0, deg_to_rad(9.0) * delta)

func apply_look(mouse_delta: Vector2) -> void:
	# 마우스 X는 몸 방향, 마우스 Y는 상하 시점에 각각 적용합니다.
	yaw.rotate_y(-mouse_delta.x * look_sensitivity)
	pitch.rotate_x(-mouse_delta.y * look_sensitivity * 0.82)
	# 사람에게 불가능한 수직 회전과 카메라 뒤집힘을 제한합니다.
	pitch.rotation.x = clampf(pitch.rotation.x, deg_to_rad(-48), deg_to_rad(38))

func apply_weapon_recoil(upward_degrees: float, horizontal_degrees: float) -> void:
	# 상향 반동과 좌우 반동에는 각각 상한을 둡니다. 연사에서 총의 무게는 느껴지되
	# 조준점을 완전히 잃거나 플레이어가 싸우는 느낌이 되지 않게 하는 안전장치입니다.
	camera_kick.rotation.x = clampf(
		camera_kick.rotation.x + deg_to_rad(upward_degrees),
		deg_to_rad(-1.2),
		deg_to_rad(3.4)
	)
	camera_kick.rotation.y = clampf(
		camera_kick.rotation.y + deg_to_rad(horizontal_degrees),
		deg_to_rad(-1.0),
		deg_to_rad(1.0)
	)
