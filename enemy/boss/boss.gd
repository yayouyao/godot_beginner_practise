extends "res://enemy/enemy_base/enemy_base.gd"

# 信号
signal boss_health_changed(health: float, max_health: float)
signal summon_enemies(enemies: Array[Node])

# 配置属性
@export var summon_interval: float = 5.0  # 召唤间隔
@export var summon_count_min: int = 4    # 最小召唤数量
@export var summon_count_max: int = 7    # 最大召唤数量

# 敌人场景
@export var enemy_normal_scene: PackedScene
@export var enemy_fast_scene: PackedScene
@export var enemy_stronger_scene: PackedScene

# 内部变量
var summon_timer: float = 0.0
 # 是否进入强化状态
var formation_phase: int = 0   # 阵型召唤阶段（0: 重型兵, 1: 骑兵）

func _ready():
	super._ready()
	kill_score = 100
	speed = 0.0  # Boss 不移动
	max_health = 10000.0
	base_damage = 20.0
	health = max_health
	global_position = Vector2(550, 700)
	
	# 禁用攻击区域，Boss 不直接攻击
	if attack_area:
		attack_area.queue_free()
		attack_area = null
	
	# 发出初始血量信号
	boss_health_changed.emit(health, max_health)
	
	# 播放待机动画（假设有 idle 动画）
	if animated_sprite:
		animated_sprite.play("idle")

func _process(delta: float):
	if is_dead:
		return
	
	# 处理召唤计时器
	summon_timer -= delta
	if summon_timer <= 0:
		summon_enemies_logic()
		summon_timer = summon_interval
	
	# 检查是否需要进入强化状态
	if health <= max_health * 0.5 and not is_enhanced:
		enhance_enemies()
		is_enhanced = true

func summon_enemies_logic():
	var enemies: Array[Node] = []
	if is_enhanced:
		# 阵型召唤：先重型兵，后骑兵
		if formation_phase == 0:
			enemies = spawn_enemies(enemy_stronger_scene, get_summon_count())
			formation_phase = 1
		else:
			enemies = spawn_enemies(enemy_fast_scene, get_summon_count())
			formation_phase = 0
	else:
		# 随机召唤一种敌人
		var enemy_type = select_enemy_type()
		enemies = spawn_enemies(enemy_type, get_summon_count())
	
	summon_enemies.emit(enemies)
	print("Boss 召唤敌人: 类型=", enemies[0].get_script().resource_path.get_file() if enemies else "无", ", 数量=", enemies.size())

func spawn_enemies(enemy_scene: PackedScene, count: int) -> Array[Node]:
	var enemies: Array[Node] = []
	if not enemy_scene:
		push_error("敌人场景未设置！")
		return enemies
	
	for i in range(count):
		var enemy = enemy_scene.instantiate()
		# 设置敌人位置，围绕 Boss 附近
		var angle = randf() * 2 * PI
		var radius = randf_range(50, 100)
		enemy.global_position = global_position + Vector2(cos(angle) * radius, sin(angle) * radius)
		get_parent().add_child(enemy)
		enemies.append(enemy)
		# 应用强化效果（如果已触发）
		if is_enhanced:
			enemy.apply_enhancement()
	return enemies

func select_enemy_type() -> PackedScene:
	var rand = randf()
	if rand < 0.33:
		return enemy_normal_scene
	elif rand < 0.66:
		return enemy_fast_scene
	else:
		return enemy_stronger_scene

func get_summon_count() -> int:
	return randi_range(summon_count_min, summon_count_max)

func enhance_enemies():
	# 强化所有现有敌人
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy != self:  # 排除 Boss 自身
			enemy.apply_enhancement()
	is_enhanced = true
	print("Boss 触发强化：所有敌人速度和伤害翻倍")

func take_damage(damage: float):
	if is_dead:
		return
	super.take_damage(damage)
	boss_health_changed.emit(health, max_health)
	if health <= 0:
		# 触发游戏胜利
		var global = get_node("/root/Global")
		if global:
			global.set_game_victory()

func apply_enhancement():
	# Boss 自身不需要强化
	pass
