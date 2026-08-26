extends Node3D

## 이 Scene의 '감독'입니다. Player, Room01, HUD를 직접 구현하지 않고
## 서로 연결해 미션 흐름과 공통 입력만 조율합니다.

## main.tscn에 인스턴스된 독립 Scene들입니다.
@onready var player: PlayerController = $Player
@onready var room_01: Room01 = $Room01
@onready var hud: MissionHUD = $HUD

func _ready() -> void:
	# FPS 시작 시 마우스를 게임 창에 가둡니다. ESC로 다시 해제할 수 있습니다.
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# Room01이 문을 열었다고 알리면 HUD가 한 번 강조 문구를 보여 줍니다.
	room_01.door_state_changed.connect(_on_room_door_state_changed)
	# 총기 내부 상태가 바뀔 때마다 HUD의 탄 수를 갱신합니다.
	player.weapon.controller.ammo_changed.connect(hud.set_ammo)
	# 첫 프레임에도 탄 수가 보이도록 현재 값으로 한 번 초기화합니다.
	hud.set_ammo(player.weapon.controller.ammo, player.weapon.controller.magazine_size)
	# 플레이어 시작 위치에 맞는 첫 안내 문구입니다.
	hud.set_status(room_01.get_prompt(player))

func _process(_delta: float) -> void:
	# 방 안/문 앞/복도 위치에 따라 안내 문구만 갱신합니다.
	hud.set_status(room_01.get_prompt(player))

func _unhandled_input(event: InputEvent) -> void:
	# ESC는 게임을 닫지 않고 마우스만 풀어 편집기/창 조작을 가능하게 합니다.
	if event is InputEventKey and event.keycode == KEY_ESCAPE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# 마우스 클릭으로 다시 게임에 포커스를 주고 커서를 캡처합니다.
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# 실제 마우스 회전 계산은 PlayerController에 위임합니다.
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		player.apply_look(event.relative)
	# E(Interact)는 현재 방이 받을 수 있는 상호작용인지 스스로 검사합니다.
	if event.is_action_pressed("interact"):
		room_01.try_interact(player)

func _on_room_door_state_changed(is_open: bool) -> void:
	# 나중에 문 상태가 더 늘어나도 이곳에서 공통 미션 상태를 받습니다.
	if is_open:
		hud.flash_status("ROOM 01  //  ENTRY OPEN")
