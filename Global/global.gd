extends Node

# 全局分数
var score: int = 200:
	set(value):
		score = max(0, value)  # 确保分数不低于0
		emit_signal("score_changed", score)  # 发出分数变化信号

# 信号
signal score_changed(new_score)  # 当分数变化时发出，传递新分数
signal game_victory  # 当游戏胜利时发出

# 全局常量
const UPGRADE_COST: int = 50  # 升级技能树的固定成本

# 全局变量
var turret_skill_levels: Dictionary = {}  # 存储炮塔技能树状态，键为 turret_id，值为 {branch1, branch2, branch3}
var placement_zones_occupied: Dictionary = {}  # 存储放置区域占用状态，键为 zone_id，值为 bool
var wave_count: int = 0  # 当前波次计数
var game_over: bool = false  # 游戏是否结束
var victory: bool = false  # 游戏是否胜利
var player_health: int = 100  # 玩家基地血量
var tutorial_completed: bool = false  # 教程是否完成

# 节点初始化时调用
func _ready():
	# 确保节点加入 global 组
	if not get_tree().root.has_node("Global"):
		add_to_group("global")  # 添加到 global 组，方便其他节点访问
	
	# 初始化全局状态
	turret_skill_levels.clear()  # 清空炮塔技能树状态
	placement_zones_occupied.clear()  # 清空放置区域状态

# 重置全局状态
func reset_game():
	score = 200  # 重置分数为初始值
	wave_count = 0  # 重置波次计数
	game_over = false  # 重置游戏结束状态
	victory = false  # 重置胜利状态
	player_health = 100  # 重置基地血量
	turret_skill_levels.clear()  # 清空炮塔技能树状态
	placement_zones_occupied.clear()  # 清空放置区域状态
	emit_signal("score_changed", score)  # 发出分数变化信号

# 增加波次计数
func increment_wave():
	wave_count += 1  # 波次计数加1

# 设置游戏结束状态
func set_game_over():
	game_over = true  # 标记游戏结束

# 设置游戏胜利状态
func set_game_victory():
	victory = true  # 标记游戏胜利
	emit_signal("game_victory")  # 发出游戏胜利信号

# 保存炮塔技能树状态
# @param turret_id: 炮塔的唯一标识
# @param levels: 技能树等级字典，包含 branch1, branch2, branch3
func save_turret_skill_levels(turret_id: String, levels: Dictionary):
	turret_skill_levels[turret_id] = levels  # 保存指定炮塔的技能树状态

# 获取炮塔技能树状态
# @param turret_id: 炮塔的唯一标识
# @return: 技能树等级字典，若不存在返回默认值 {branch1: 0, branch2: 0, branch3: 0}
func get_turret_skill_levels(turret_id: String) -> Dictionary:
	return turret_skill_levels.get(turret_id, {"branch1": 0, "branch2": 0, "branch3": 0})

# 保存放置区域的占用状态
# @param zone_id: 放置区域的唯一标识
# @param occupied: 是否被占用
func set_zone_occupied(zone_id: String, occupied: bool):
	placement_zones_occupied[zone_id] = occupied  # 设置指定区域的占用状态

# 获取放置区域的占用状态
# @param zone_id: 放置区域的唯一标识
# @return: 是否被占用，若不存在返回 false
func is_zone_occupied(zone_id: String) -> bool:
	return placement_zones_occupied.get(zone_id, false)

# 设置教程完成状态
# @param completed: 教程是否完成
func set_tutorial_completed(completed: bool):
	tutorial_completed = completed  # 更新教程完成状态

# 检查教程是否完成
# @return: 教程完成状态
func is_tutorial_completed() -> bool:
	return tutorial_completed
