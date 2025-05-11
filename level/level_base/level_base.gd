extends Node
class_name LevelBase

# 信号
signal wave_changed(wave_index: int)
signal level_completed()

# 轮次配置数组，子类需填充
var waves: Array[Dictionary] = []
# 当前轮次索引
var current_wave_index: int = -1  # 初始为 -1，等待第一波触发
# 每种敌人的剩余数量
var enemy_counts: Dictionary = {
	"normal": 0,
	"fast": 0,
	"stronger": 0
}

# 敌人场景引用，由外部设置
var enemy_normal_scene: PackedScene
var enemy_fast_scene: PackedScene
var enemy_stronger_scene: PackedScene

func _ready():
	# 初始化敌人数量
	for wave in waves:
		enemy_counts.normal += wave.get("normal_count", 0)
		enemy_counts.fast += wave.get("fast_count", 0)
		enemy_counts.stronger += wave.get("stronger_count", 0)

# 获取当前轮次配置
func get_current_wave() -> Dictionary:
	if current_wave_index >= 0 and current_wave_index < waves.size():
		return waves[current_wave_index]
	return {}

# 减少敌人数量并检查轮次/关卡完成
func decrease_enemy_count(enemy_type: String):
	if enemy_counts.has(enemy_type):
		enemy_counts[enemy_type] = max(0, enemy_counts[enemy_type] - 1)
		check_wave_completion()

# 检查当前轮次是否完成
func check_wave_completion():
	var current_wave = get_current_wave()
	if current_wave.is_empty():
		return
	
	var wave_normal = current_wave.get("normal_count", 0)
	var wave_fast = current_wave.get("fast_count", 0)
	var wave_stronger = current_wave.get("stronger_count", 0)
	
	# 检查当前轮次的敌人是否全部消灭
	var wave_enemy_sum = wave_normal + wave_fast + wave_stronger
	var remaining_wave_enemy_sum = 0
	for enemy_type in enemy_counts:
		if enemy_type in ["normal", "fast", "stronger"]:
			remaining_wave_enemy_sum += enemy_counts[enemy_type]
	
	if remaining_wave_enemy_sum <= 0 and current_wave_index < waves.size() - 1:
		current_wave_index += 1
		wave_changed.emit(current_wave_index)
		if current_wave_index >= waves.size():
			level_completed.emit()

# 获取当前轮次的生成权重
func get_spawn_weights() -> Array[float]:
	var wave = get_current_wave()
	if wave.is_empty():
		return [0.0, 0.0, 0.0].duplicate() as Array[float]
	var weights = wave.get("spawn_weights", [0.5, 0.3, 0.2])
	var float_weights: Array[float] = []
	for w in weights:
		float_weights.append(float(w))
	return float_weights

# 获取当前轮次的生成间隔
func get_spawn_interval() -> float:
	var wave = get_current_wave()
	if wave.is_empty():
		return 2.0
	# 确保返回值为 float
	return float(wave.get("spawn_interval", 2.0))

# 动态调整生成间隔（根据剩余敌人数量）
func adjust_spawn_interval(base_interval: float) -> float:
	var total_enemies = enemy_counts.normal + enemy_counts.fast + enemy_counts.stronger
	if total_enemies > 0:
		# 剩余敌人越少，生成间隔越短（加快节奏）
		var factor = clamp(float(total_enemies) / 50.0, 0.5, 1.0)
		return base_interval * factor
	return base_interval
