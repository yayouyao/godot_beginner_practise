extends Node2D

# 可配置属性
@export var spawn_marker: Marker2D  # 敌人生成位置的标记点
@export var level_scene: PackedScene  # 关卡场景，用于管理波次和敌人类型

# 内部变量
var spawn_timer: float = 0.0  # 敌人生成间隔计时器
var wave_timer: float = 0.0   # 当前波次持续时间计时器
var screen_width: float        # 屏幕宽度
var screen_height: float       # 屏幕高度
var level: LevelBase           # 关卡实例，管理波次逻辑
var is_boss_wave: bool = false  # 是否为 Boss 波次（未使用）

# 游戏状态枚举
enum GameState {
	INITIAL_DELAY,  # 初始5秒延迟
	WAVE_1,        # 第一波
	WAVE_2,        # 第二波
	WAVE_3,        # 第三波
	STOP_SPAWNING  # 停止刷怪
}
var game_state: GameState = GameState.INITIAL_DELAY  # 当前游戏状态

# 信号
signal enemy_spawned(enemy: Node)  # 当敌人生成时发出，传递生成的敌人实例
signal show_wave_message(message: String)  # 当波次变化时发出，传递提示消息
signal game_won()  # 当游戏胜利时发出

# 节点初始化时调用
func _ready():
	add_to_group("enemy_spawner")  # 将节点添加到 enemy_spawner 组
	var viewport = get_viewport()  # 获取视口
	if viewport:
		screen_width = viewport.size.x  # 设置屏幕宽度
		screen_height = viewport.size.y  # 设置屏幕高度

	# 实例化关卡
	if level_scene:
		level = level_scene.instantiate()  # 创建关卡实例
		if level:
			# 设置敌人场景
			level.enemy_normal_scene = preload("res://enemy/enemy1/enemy_normal.tscn")
			level.enemy_fast_scene = preload("res://enemy/enemy2/enemy_fast.tscn")
			level.enemy_stronger_scene = preload("res://enemy/enemy3/enemy_stronger.tscn")
		else:
			push_error("关卡实例化失败！")  # 如果实例化失败，打印错误
		add_child(level)  # 将关卡添加到节点树
		level.wave_changed.connect(_on_wave_changed)  # 连接波次变化信号
	else:
		push_error("未设置 Level Scene！")  # 如果未设置关卡场景，打印错误

	# 设置生成点位置
	if spawn_marker:
		spawn_marker.global_position = Vector2(2.0 * screen_width, screen_height / 2)  # 设置生成点在屏幕右侧
	else:
		push_error("未找到 SpawnMarker 节点！")  # 如果未找到生成标记，打印错误

	# 初始化波次
	level.current_wave_index = -1  # 设置为-1，确保从第一波开始
	emit_signal("show_wave_message", "游戏将在5秒后开始！")  # 显示初始提示

# 每帧物理处理
func _physics_process(delta: float):
	# 更新计时器
	wave_timer += delta  # 增加波次计时器
	spawn_timer -= delta  # 减少生成间隔计时器

	# 根据游戏状态处理逻辑
	match game_state:
		GameState.INITIAL_DELAY:
			if wave_timer >= 5.0:  # 初始5秒延迟
				game_state = GameState.WAVE_1  # 进入第一波
				wave_timer = 0.0  # 重置波次计时器
				spawn_timer = 0.0  # 重置生成计时器
				level.current_wave_index = 0  # 设置波次索引
				emit_signal("show_wave_message", "第一波：敌人来袭！")  # 显示提示
		GameState.WAVE_1:
			if wave_timer >= 60.0:  # 第一波持续1分钟
				game_state = GameState.WAVE_2  # 进入第二波
				wave_timer = 0.0  # 重置波次计时器
				spawn_timer = 0.0  # 重置生成计时器
				level.current_wave_index = 1  # 更新波次索引
				emit_signal("show_wave_message", "第二波：敌军集结！")  # 显示提示
			elif spawn_timer <= 0:
				spawn_enemy()  # 生成敌人
				spawn_timer = 10.0  # 设置生成间隔为10秒
		GameState.WAVE_2:
			if wave_timer >= 120.0:  # 第二波持续2分钟
				game_state = GameState.WAVE_3  # 进入第三波
				wave_timer = 0.0  # 重置波次计时器
				spawn_timer = 0.0  # 重置生成计时器
				level.current_wave_index = 2  # 更新波次索引
				emit_signal("show_wave_message", "第三波：敌军蜂拥！")  # 显示提示
			elif spawn_timer <= 0:
				spawn_enemy()  # 生成敌人
				spawn_timer = 3.0  # 设置生成间隔为3秒
		GameState.WAVE_3:
			if wave_timer >= 150.0:  # 第三波持续2分30秒
				game_state = GameState.STOP_SPAWNING  # 进入停止刷怪状态
				wave_timer = 0.0  # 重置波次计时器
				emit_signal("show_wave_message", "敌人的最后攻势，消灭所有敌人以获胜！")  # 显示提示
			elif spawn_timer <= 0:
				spawn_enemy()  # 生成敌人
				spawn_timer = 1.0  # 设置生成间隔为1秒
		GameState.STOP_SPAWNING:
			# 检测胜利条件：屏幕上没有敌人
			var enemies = get_tree().get_nodes_in_group("enemy")  # 获取所有敌人
			if enemies.size() == 0:
				emit_signal("game_won")  # 发出游戏胜利信号
				set_physics_process(false)  # 停止物理处理

# 生成敌人
func spawn_enemy():
	var enemy_to_spawn = _select_enemy_type()  # 选择敌人类型
	if not enemy_to_spawn:
		push_error("无法选择敌人类型，跳过生成")  # 如果类型无效，打印错误
		return
	var enemy = enemy_to_spawn.instantiate()  # 实例化敌人
	
	# 设置敌人位置
	if spawn_marker:
		enemy.global_position = Vector2(
			spawn_marker.global_position.x,
			randf_range(screen_height / 6, 5 * screen_height / 6)  # 在屏幕高度1/6到5/6之间随机
		)
	else:
		push_error("SpawnMarker 缺失，敌人生成位置可能错误")  # 如果生成标记缺失，打印错误
	
	get_parent().add_child(enemy)  # 将敌人添加到父节点
	enemy_spawned.emit(enemy)  # 发出敌人生成信号
	enemy.enemy_killed.connect(_on_enemy_killed.bind(enemy))  # 连接敌人被杀死信号

# 选择敌人类型
func _select_enemy_type() -> PackedScene:
	if not level:
		push_error("Level 未设置，无法选择敌人类型")  # 如果关卡未设置，打印错误
		return null

	match game_state:
		GameState.WAVE_1:
			# 第一波只生成普通敌人
			if not level.enemy_normal_scene:
				push_error("EnemyNormalScene 未设置！")  # 如果场景未设置，打印错误
				return null
			return level.enemy_normal_scene
		GameState.WAVE_2:
			# 第二波：普通敌人60%，快速敌人40%
			var rand = randf()
			if rand < 0.6:
				if not level.enemy_normal_scene:
					push_error("EnemyNormalScene 未设置！")  # 如果场景未设置，打印错误
					return null
				return level.enemy_normal_scene
			else:
				if not level.enemy_fast_scene:
					push_error("EnemyFastScene 未设置！")  # 如果场景未设置，打印错误
					return null
				return level.enemy_fast_scene
		GameState.WAVE_3:
			# 第三波：普通敌人50%，快速敌人40%，重型敌人10%
			var rand = randf()
			if rand < 0.5:
				if not level.enemy_normal_scene:
					push_error("EnemyNormalScene 未设置！")  # 如果场景未设置，打印错误
					return null
				return level.enemy_normal_scene
			elif rand < 0.9:
				if not level.enemy_fast_scene:
					push_error("EnemyFastScene 未设置！")  # 如果场景未设置，打印错误
					return null
				return level.enemy_fast_scene
			else:
				if not level.enemy_stronger_scene:
					push_error("EnemyStrongerScene 未设置！")  # 如果场景未设置，打印错误
					return null
				return level.enemy_stronger_scene
	return null

# 当敌人被杀死时触发
func _on_enemy_killed(points: int, enemy: Node):
	if not level:
		return  # 如果关卡未设置，忽略
	var enemy_type = "normal"  # 默认敌人类型
	if enemy.get_script().resource_path == "res://enemy/enemy2/enemy_fast.gd":
		enemy_type = "fast"  # 快速敌人
	elif enemy.get_script().resource_path == "res://enemy/enemy3/enemy_stronger.gd":
		enemy_type = "stronger"  # 重型敌人
	level.decrease_enemy_count(enemy_type)  # 减少对应类型的敌人计数

# 当波次变化时触发
func _on_wave_changed(wave_index: int):
	level.current_wave_index = wave_index  # 更新波次索引
	spawn_timer = 0.0  # 重置生成计时器
