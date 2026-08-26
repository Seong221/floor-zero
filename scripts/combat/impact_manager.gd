extends Node3D
class_name ImpactManager

## 모든 사격 탄착점을 한 곳에서 관리하는 경량 효과 관리자입니다.
## 각 총/벽/적이 독립적으로 파티클을 끝없이 만들지 않게 하고, 오래된 탄흔을
## 먼저 제거하여 긴 플레이나 웹 빌드에서도 노드 수가 계속 늘지 않게 합니다.

## 동시에 남겨 둘 영구 탄흔의 최대 수입니다. 28개를 넘으면 가장 오래된 것을 지웁니다.
@export var max_bullet_marks := 28
## 탄착 직후 잠깐 날아가는 작은 파편의 최대 수입니다.
@export var max_active_fragments := 56
## 총알이 짧은 시간에 여러 표면을 맞혀도 새 Audio 노드를 계속 만들지 않도록
## 미리 준비해 돌려 쓰는 3D 피격음 재생기의 수입니다.
@export var impact_audio_pool_size := 8

## 현재는 표면별 샘플이 하나씩입니다. 파일 경로를 코드 한곳에 고정해 두면
## 나중에 샘플 배열로 확장하더라도 HitSurface나 총기 코드는 바꿀 필요가 없습니다.
const CONCRETE_IMPACT_STREAM: AudioStream = preload("res://assets/audio/impacts/impact_concrete_01.ogg")
const METAL_IMPACT_STREAM: AudioStream = preload("res://assets/audio/impacts/impact_metal_01.ogg")
const WOOD_IMPACT_STREAM: AudioStream = preload("res://assets/audio/impacts/impact_wood_01.ogg")

## 월드에 남아 있는 탄흔을 생성 순서대로 보관합니다.
var bullet_marks: Array[MeshInstance3D] = []
## 짧게 움직인 뒤 사라질 파편의 노드/속도/수명을 담습니다.
var active_fragments: Array[Dictionary] = []
## 고정 개수만 생성한 뒤 순환하며 사용하는 위치 기반 피격음 재생기입니다.
var impact_audio_players: Array[AudioStreamPlayer3D] = []
## 다음 탄착이 사용할 재생기 번호입니다. 풀 끝에 도달하면 다시 0으로 돌아갑니다.
var next_impact_audio_index := 0

func _ready() -> void:
	# HitSurface가 직접 노드 경로를 알지 않도록 그룹으로 공개합니다.
	add_to_group("impact_manager")
	_build_impact_audio_pool()

func spawn_impact(surface_type: StringName, hit_position: Vector3, hit_normal: Vector3, incoming_direction: Vector3) -> void:
	# 아주 드문 비정상 충돌 결과에도 효과가 뒤집히지 않게 안전한 법선을 준비합니다.
	var normal := hit_normal.normalized() if hit_normal.length_squared() > 0.001 else Vector3.UP
	# 모든 표면에는 작고 오래 남는 탄흔이 생겨 명중 위치를 읽게 합니다.
	_spawn_bullet_mark(surface_type, hit_position, normal)
	# 소리가 총기나 플레이어 위치가 아니라 실제 탄착점에서 나므로, 가까운 벽과
	# 먼 문손잡이가 귀로도 다른 거리에서 맞았다는 것을 전달합니다.
	_play_impact_sound(surface_type, hit_position)
	# 표면에 맞춰 파편 색과 양, 섬광 여부를 가져옵니다.
	var profile := _surface_profile(surface_type)
	var count := int(profile["fragment_count"])
	for fragment_index in count:
		_spawn_fragment(
			hit_position + normal * 0.018,
			normal,
			profile["fragment_color"],
			float(profile["fragment_size"]),
			float(profile["fragment_lifetime"]),
			fragment_index == 0 and bool(profile["has_flash"])
		)
	# incoming_direction은 지금은 파편 회전 확장용으로 남겨 둡니다. 이후
	# 관통탄/도탄을 만들 때 입사각에 따른 효과 강도 계산에도 그대로 사용합니다.
	if incoming_direction.length_squared() > 0.0:
		pass

func _build_impact_audio_pool() -> void:
	# AudioStreamPlayer3D를 매 탄착마다 생성/삭제하면 연사 때 노드 할당이 몰립니다.
	# ROOM 01 규모에는 여덟 개를 순환하는 것으로 겹치는 피격음을 충분히 보존합니다.
	for pool_index in maxi(1, impact_audio_pool_size):
		var player := AudioStreamPlayer3D.new()
		player.name = "ImpactAudio%02d" % pool_index
		# 좁은 실내에서 위치는 읽히되 지나치게 급격히 작아지지 않는 감쇠값입니다.
		player.unit_size = 2.5
		player.max_distance = 28.0
		player.volume_db = -4.0
		add_child(player)
		impact_audio_players.append(player)

func _play_impact_sound(surface_type: StringName, hit_position: Vector3) -> void:
	if impact_audio_players.is_empty():
		return
	var stream := _surface_sound(surface_type)
	# fabric/training처럼 아직 전용 녹음이 없는 표면에는 억지로 콘크리트음을
	# 재사용하지 않습니다. 소리와 보이는 재질이 다르면 공간 신뢰도가 더 떨어집니다.
	if stream == null:
		return
	var player := impact_audio_players[next_impact_audio_index]
	next_impact_audio_index = (next_impact_audio_index + 1) % impact_audio_players.size()
	player.stream = stream
	player.global_position = hit_position
	# 단일 샘플의 완전한 복제를 피하되 재질 정체성이 달라지지 않는 좁은 범위입니다.
	player.pitch_scale = randf_range(0.95, 1.05)
	player.volume_db = randf_range(-5.0, -3.0)
	player.play()

func _surface_sound(surface_type: StringName) -> AudioStream:
	match surface_type:
		&"metal":
			return METAL_IMPACT_STREAM
		&"wood":
			return WOOD_IMPACT_STREAM
		&"concrete":
			return CONCRETE_IMPACT_STREAM
		_:
			return null

func _process(delta: float) -> void:
	# 역순으로 순회하면 배열에서 끝난 파편을 제거해도 인덱스가 안전합니다.
	for index in range(active_fragments.size() - 1, -1, -1):
		var fragment := active_fragments[index]
		var remaining := float(fragment["remaining"]) - delta
		var mesh := fragment["mesh"] as MeshInstance3D
		if remaining <= 0.0 or not is_instance_valid(mesh):
			if is_instance_valid(mesh):
				mesh.queue_free()
			active_fragments.remove_at(index)
			continue
		# 실제 물리 파편을 쓰지 않고 단순한 중력 이동만 계산합니다. 짧은 시각 효과에는
		# 이 편이 훨씬 싸고, 벽을 뚫고 날아가도 플레이 감각에 영향을 주지 않습니다.
		var velocity := fragment["velocity"] as Vector3
		velocity += Vector3.DOWN * 9.8 * delta
		mesh.global_position += velocity * delta
		fragment["velocity"] = velocity
		fragment["remaining"] = remaining
		# 각 파편은 고유 Material을 가지므로 하나만 투명하게 만들어도 다른 효과를 건드리지 않습니다.
		var material := fragment["material"] as StandardMaterial3D
		var alpha := clampf(remaining / float(fragment["lifetime"]), 0.0, 1.0)
		var color := material.albedo_color
		color.a = alpha
		material.albedo_color = color
		# 금속 충돌의 첫 파편에는 짧은 섬광을 붙입니다. 매 프레임 조명을 새로 만들지 않고
		# 파편 노드의 자식 조명 하나만 감쇠시키므로 비용을 제한할 수 있습니다.
		var flash := fragment["flash"] as OmniLight3D
		if is_instance_valid(flash):
			flash.light_energy = 2.8 * alpha
		active_fragments[index] = fragment

func _spawn_bullet_mark(surface_type: StringName, hit_position: Vector3, normal: Vector3) -> void:
	var mark := MeshInstance3D.new()
	mark.name = "BulletMark"
	var mesh := QuadMesh.new()
	# 콘크리트/목재는 조금 크고 흐린 자국, 금속은 작고 검은 자국으로 읽힙니다.
	var size := 0.082 if surface_type == &"concrete" else 0.060
	mesh.size = Vector2(size, size)
	mark.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = _mark_color(surface_type)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mark.material_override = material
	# QuadMesh의 앞면(+Z)을 충돌 법선 쪽으로 회전시키고, Z-fighting을 막기 위해
	# 표면에서 아주 조금만 띄웁니다.
	mark.global_position = hit_position + normal * 0.004
	mark.quaternion = Quaternion(Vector3.FORWARD, normal)
	mark.rotation_degrees.z = randf_range(-180.0, 180.0)
	add_child(mark)
	bullet_marks.append(mark)
	# 오래된 자국부터 제거합니다. floor-zero의 작은 실내 데모에서는 28개면 충분히
	# 최근 전투 흔적은 남고, 장시간 사격에도 드로우콜이 계속 증가하지 않습니다.
	while bullet_marks.size() > max_bullet_marks:
		# pop_front()의 반환형은 엔진 API상 Variant이므로, 프로젝트의 경고=오류
		# 설정에서도 통과하도록 실제 배열 원소 타입을 명시합니다.
		var old_mark: MeshInstance3D = bullet_marks.pop_front()
		if is_instance_valid(old_mark):
			old_mark.queue_free()

func _spawn_fragment(origin: Vector3, normal: Vector3, color: Color, size: float, lifetime: float, has_flash: bool) -> void:
	# 이미 짧은 파편이 충분히 많으면 새 파편 대신 가장 오래된 것을 지워 상한을 유지합니다.
	while active_fragments.size() >= max_active_fragments:
		# Dictionary 배열도 같은 이유로 반환 타입을 명시합니다.
		var oldest: Dictionary = active_fragments.pop_front()
		var old_mesh := oldest["mesh"] as MeshInstance3D
		if is_instance_valid(old_mesh):
			old_mesh.queue_free()
	var fragment := MeshInstance3D.new()
	fragment.name = "ImpactFragment"
	var mesh := SphereMesh.new()
	mesh.radius = size
	mesh.height = size * 2.0
	mesh.radial_segments = 6
	mesh.rings = 3
	fragment.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	fragment.material_override = material
	fragment.global_position = origin
	add_child(fragment)
	# 법선 방향으로 튀되, 접선 방향의 무작위성을 더해 완전히 같은 모양이 반복되지 않게 합니다.
	var tangent := normal.cross(Vector3.UP)
	if tangent.length_squared() < 0.01:
		tangent = normal.cross(Vector3.RIGHT)
	tangent = tangent.normalized()
	var bitangent := normal.cross(tangent).normalized()
	var sideways := tangent * randf_range(-0.9, 0.9) + bitangent * randf_range(-0.9, 0.9)
	var velocity := (normal * randf_range(0.65, 1.25) + sideways) * randf_range(0.65, 1.15)
	var flash: OmniLight3D = null
	if has_flash:
		flash = OmniLight3D.new()
		flash.light_color = color
		flash.light_energy = 2.8
		flash.omni_range = 1.6
		fragment.add_child(flash)
	active_fragments.append({
		"mesh": fragment,
		"velocity": velocity,
		"remaining": lifetime,
		"lifetime": lifetime,
		"material": material,
		"flash": flash,
	})

func _surface_profile(surface_type: StringName) -> Dictionary:
	# 효과 프로필은 데이터로 분리했습니다. 나중에 유리/타일/살 등 표면을 추가해도
	# spawn_impact의 흐름을 건드리지 않고 여기 한 곳만 늘리면 됩니다.
	match surface_type:
		&"metal":
			return {"fragment_color": Color(1.0, 0.74, 0.24, 1.0), "fragment_count": 5, "fragment_size": 0.018, "fragment_lifetime": 0.16, "has_flash": true}
		&"wood":
			return {"fragment_color": Color(0.47, 0.28, 0.13, 1.0), "fragment_count": 4, "fragment_size": 0.024, "fragment_lifetime": 0.25, "has_flash": false}
		&"training":
			return {"fragment_color": Color(0.94, 0.48, 0.18, 1.0), "fragment_count": 3, "fragment_size": 0.020, "fragment_lifetime": 0.20, "has_flash": false}
		&"fabric":
			return {"fragment_color": Color(0.20, 0.25, 0.31, 1.0), "fragment_count": 3, "fragment_size": 0.016, "fragment_lifetime": 0.16, "has_flash": false}
		_:
			return {"fragment_color": Color(0.66, 0.70, 0.72, 1.0), "fragment_count": 4, "fragment_size": 0.022, "fragment_lifetime": 0.22, "has_flash": false}

func _mark_color(surface_type: StringName) -> Color:
	# 탄흔은 조명 영향을 받지 않는 낮은 알파 색으로 두어 어두운 복도에서도 읽힙니다.
	match surface_type:
		&"wood":
			return Color(0.16, 0.08, 0.035, 0.88)
		&"training":
			return Color(0.20, 0.07, 0.025, 0.92)
		&"fabric":
			return Color(0.055, 0.065, 0.075, 0.80)
		_:
			return Color(0.035, 0.040, 0.045, 0.82)
