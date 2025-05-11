extends Area2D

# 可配置属性
@export var speed: float = 2000              # 子弹移动速度（像素/秒）
@export var lifetime: float = 5.0            # 子弹存活时间（秒）
@export var physical_damage: float = 10.0    # 子弹的物理伤害值
@export var aoe_radius: float = 0.0          # 范围伤害半径（0 表示无范围伤害）
@export var aoe_damage: float = 0.0          # 范围伤害值
@export var knockback_strength: float = 0.0  # 击退力度（0 表示无击退）
@export var penetration_count: int = 0       # 穿透次数（0 表示不穿透，-1 表示无限穿透）

# 内部变量
const ENEMY_GROUP: String = "enemy"          # 敌人组的名称，用于识别敌人
var direction: Vector2 = Vector2.ZERO        # 子弹移动方向（归一化向量）
var is_destroyed: bool = false               # 子弹是否已被销毁
var lifetime_timer: float = 0.0              # 子弹剩余存活时间计时器
var pool: Node = null                        # 对象池引用，用于子弹回收
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D  # 引用子弹的动画精灵

# 节点初始化时调用
func _ready():
	if not animated_sprite:
		printerr("错误: 未找到 AnimatedSprite2D 节点！")  # 检查是否缺少动画精灵节点
	else:
		animated_sprite.play("default")  # 播放默认动画
	
	# 设置碰撞层和掩码
	collision_layer = 1  # 设置子弹在 Layer 1（子弹层）
	collision_mask = 4   # 设置只检测 Layer 3（敌人层）
	
	# 确保信号连接
	if not is_connected("area_entered", _on_area_entered):
		connect("area_entered", _on_area_entered)  # 连接区域进入信号

# 每帧物理处理
func _physics_process(delta: float):
	if is_destroyed:
		return  # 如果子弹已销毁，跳过处理
	
	lifetime_timer -= delta  # 减少存活时间
	if lifetime_timer <= 0:
		return_to_pool()  # 如果存活时间耗尽，回收子弹
		return
	
	var viewport_rect = get_viewport_rect()  # 获取视口矩形
	if !viewport_rect.has_point(global_position):
		return_to_pool()  # 如果子弹超出视口，回收子弹
		return
	
	# 手动移动子弹
	global_position += direction * speed * delta  # 根据方向和速度更新位置

# 当子弹进入某个区域时触发
func _on_area_entered(area: Area2D):
	if is_destroyed:
		return  # 如果子弹已销毁，跳过处理
	if area.is_in_group(ENEMY_GROUP):
		print("击中敌人: ", area.name)  # 打印击中敌人的信息
		apply_effects(area)  # 对敌人应用效果（如伤害、击退）
		if aoe_radius > 0:
			apply_aoe_damage(global_position)  # 如果有范围伤害，应用范围伤害
		if penetration_count == 0 or penetration_count < -1:
			is_destroyed = true  # 如果无穿透或穿透次数耗尽，标记销毁
			return_to_pool()  # 回收子弹
		elif penetration_count > 0:
			penetration_count -= 1  # 减少一次穿透次数
		# penetration_count == -1 表示无限穿透，不销毁

# 对敌人应用效果
func apply_effects(enemy: Node2D):
	if physical_damage > 0:
		enemy.take_damage(physical_damage)  # 对敌人造成物理伤害
	if knockback_strength > 0:
		var knockback_direction = (enemy.global_position - global_position).normalized()  # 计算击退方向
		enemy.apply_knockback(knockback_direction * knockback_strength)  # 应用击退效果

# 应用范围伤害
func apply_aoe_damage(center: Vector2):
	var enemies = get_tree().get_nodes_in_group(ENEMY_GROUP)  # 获取所有敌人
	for enemy in enemies:
		var distance = enemy.global_position.distance_to(center)  # 计算敌人与爆炸中心的距离
		if distance <= aoe_radius and distance > 0:
			enemy.take_damage(aoe_damage)  # 对范围内的敌人造成范围伤害

# 设置子弹方向
func set_direction(dir: Vector2):
	direction = dir.normalized()  # 归一化方向向量
	if animated_sprite and direction != Vector2.ZERO:
		animated_sprite.rotation = direction.angle()  # 旋转动画精灵以匹配方向

# 设置子弹属性（从字典中获取）
func set_properties(props: Dictionary):
	physical_damage = props.get("physical_damage", physical_damage)  # 设置物理伤害，保留默认值
	aoe_radius = props.get("aoe_radius", aoe_radius)                # 设置范围伤害半径
	aoe_damage = props.get("aoe_damage", aoe_damage)                # 设置范围伤害值
	knockback_strength = props.get("knockback_strength", knockback_strength)  # 设置击退力度
	penetration_count = props.get("penetration_count", penetration_count)     # 设置穿透次数

# 将子弹归还到对象池
func return_to_pool():
	if pool and is_instance_valid(pool):
		is_destroyed = true  # 标记为已销毁
		pool.return_object(self)  # 归还到对象池
	else:
		queue_free()  # 如果没有对象池，直接销毁

# 重置子弹状态
func reset():
	is_destroyed = false  # 取消销毁标记
	lifetime_timer = lifetime  # 重置存活时间
	direction = Vector2.ZERO  # 重置方向
	global_position = Vector2.ZERO  # 重置位置
	if animated_sprite:
		animated_sprite.rotation = 0  # 重置动画精灵旋转
		animated_sprite.play("default")  # 播放默认动画
	collision_layer = 1  # 重置碰撞层
	collision_mask = 4   # 重置碰撞掩码
	# 重置属性
	physical_damage = 10.0    # 恢复默认物理伤害
	aoe_radius = 0.0          # 恢复默认范围伤害半径
	aoe_damage = 0.0          # 恢复默认范围伤害值
	penetration_count = 0     # 恢复默认穿透次数
