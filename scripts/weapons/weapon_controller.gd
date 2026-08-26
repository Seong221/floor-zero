extends Node
class_name WeaponController

## 모든 총기가 공유하는 '규칙 전용' 노드입니다.
## 화면에 보이는 총기 모델, 반동 애니메이션, 소리는 V12Carbine 같은 개별
## Weapon Scene이 맡고, 이 스크립트는 탄약/발사 간격만 결정합니다.

## HUD가 즉시 탄약 숫자를 바꾸도록 알리는 신호입니다.
signal ammo_changed(current: int, maximum: int)
## 사격이 실제로 성공했을 때 총구 화염/반동/소리가 반응하도록 알립니다.
signal fired
## 빈 탄창을 쐈을 때 이후 '철컥' 소리를 연결할 자리입니다.
signal dry_fired

## Inspector에서 총마다 바꿀 수 있는 기본 탄창 수입니다.
@export var magazine_size := 30
## 두 발 사이의 최소 시간(초)입니다. 0.09는 초당 약 11발입니다.
@export var fire_interval := 0.09
## 현재는 사격/피격 실험 단계이므로 탄창을 비우지 않습니다. 나중에 실제
## 전투 밸런싱을 시작할 때 Inspector에서 false로 바꾸면 기존 탄창 규칙이 돌아옵니다.
@export var infinite_ammo := true

## 현재 장전된 탄 수입니다. _ready에서 magazine_size와 동기화합니다.
var ammo := 30
## 0보다 큰 동안에는 다음 발을 발사할 수 없습니다.
var cooldown := 0.0
## 성공 사격 횟수입니다. 총기 시각/카메라 반동이 무작위가 아닌 반복 패턴을
## 고를 때만 사용하며, 탄약 수나 발사 간격에는 영향을 주지 않습니다.
var shot_index := 0

func _ready() -> void:
	# 무한 탄약은 -1이라는 내부 표기로 관리합니다. HUD는 이 값을 ∞로 보여 주고,
	# 실제 탄약 모드에서는 기존처럼 magazine_size에서 시작합니다.
	ammo = -1 if infinite_ammo else magazine_size

func tick(delta: float) -> void:
	# 매 프레임 남은 발사 대기 시간을 줄입니다. 음수로 내려가지 않게 고정합니다.
	cooldown = maxf(0.0, cooldown - delta)

func try_fire() -> bool:
	# 아직 총열이 발사 간격을 회복하지 못했으면 아무 것도 하지 않습니다.
	if cooldown > 0.0:
		return false
	# 유한 탄약 모드에서만 빈 탄창을 검사합니다. 실험 모드에서는 이 분기를
	# 건너뛰므로 30발마다 사격이 멈추지 않습니다.
	if not infinite_ammo and ammo <= 0:
		dry_fired.emit()
		return false
	# 여기부터가 '성공한 한 발'입니다.
	if not infinite_ammo:
		ammo -= 1
	cooldown = fire_interval
	shot_index += 1
	# UI와 총기 장면에 각각 결과를 전달합니다.
	ammo_changed.emit(ammo, -1 if infinite_ammo else magazine_size)
	fired.emit()
	return true
