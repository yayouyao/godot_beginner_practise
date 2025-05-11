extends Area2D

# 信号
signal enemy_killed(points: int)  # 当敌人被杀死时发出，传递获得的分数
signal damaged(damage: float, position: Vector2)  # 当敌人受到伤害时发出，传递伤害值和位置

# 可配置属性
@export var speed: float = 50.0          # 敌人移动速度（像素/秒）
@export var max_health: float = 100.0    # 敌人最大血量
@export var base_damage: float = 10.0    # 敌人对基地的基础伤害
@export var attack_cooldown: float = 1.0  # 攻击冷却时间（秒）
@export var attack_range: float = 75.0   # 攻击范围（像素）

# 击退相关常量
const KNOCKBACK_DISTANCE: float = 500     # 固定击退距离（像素）
const KNOCKBACK_DURATION: float = 0.3     # 击退动画持续时间（秒）
const KNOCKBACK_UP_ANGLE: float = 45.0    # 右上方向角度（度）

# 节点引用
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D  # 敌人动画精灵
var attack_area: Area2D = null  # 攻击范围区域（动态创建或从场景获取）

# 内部变量
var health: float  # 当前血量
var base_speed: float  # 记录基础速度
var base_damage_base: float  # 记录基础伤害
var is_attacking: bool = false  # 是否正在攻击
var is_dead: bool = false  # 是否已死亡
var attack_timer: float = 0.0  # 攻击冷却计时器
var velocity: Vector2 = Vector2.ZERO  # 当前移动速度
var current_target: Node2D = null  # 当前攻击目标
var is_enhanced: bool = false  # 是否被强化（速度和伤害翻倍）
var is_knocked_back: bool = false  # 是否正在被击退

# 节点初始化时调用
func _ready():
	add_to_group("enemy")  # 将敌人添加到 "enemy" 组
	health = max_health  # 初始化血量
	base_speed = speed  # 记录初始速度
	base_damage_base = base_damage  # 记录初始伤害

	# 设置动画精灵
	if animated_sprite:
		if animated_sprite.sprite_frames.has_animation("death"):
			animated_sprite.sprite_frames.set_animation_loop("death", false)  # 死亡动画不循环
		animated_sprite.play("run")  # 默认播放跑动动画
		animated_sprite.animation_finished.connect(_on_animation_finished)  # 连接动画完成信号
	else:
		push_warning("AnimatedSprite2D 节点未找到！")  # 警告缺失动画精灵

	# 添加碰撞体（如果未手动设置）
	if not $CollisionShape2D:
		var collision_shape = CollisionShape2D.new()  # 创建碰撞形状
		var shape = CircleShape2D.new()  # 创建圆形碰撞形状
		shape.radius = 500  # 设置碰撞半径
		collision_shape.shape = shape  # 绑定形状
		add_child(collision_shape)  # 添加到节点树

	# 设置碰撞层和掩码
	collision_layer = 4  # 设置在 Layer 3（敌人层）
	collision_mask = 0   # 不需要检测其他层

	# 初始化攻击范围区域
	attack_area = get_node_or_null("AttackArea")  # 尝试获取 AttackArea 节点
	if not attack_area:
		attack_area = Area2D.new()  # 创建新的攻击范围区域
		attack_area.name = "AttackArea"
		add_child(attack_area)  # 添加到节点树
		var area_shape = CollisionShape2D.new()  # 创建碰撞形状
		var area_rect = RectangleShape2D.new()  # 创建矩形碰撞形状
		area_rect.size = Vector2(attack_range, attack_range * 0.5)  # 设置攻击范围大小
		area_shape.shape = area_rect  # 绑定形状
		area_shape.position = Vector2(-attack_range / 2, 0)  # 调整形状位置
		attack_area.add_child(area_shape)  # 添加到攻击区域
		attack_area.collision_layer = 0  # 不发射碰撞
		attack_area.collision_mask = 2  # 检测 Layer 2（可攻击对象）
		attack_area.connect("body_entered", _on_attack_area_entered)  # 连接进入信号
		attack_area.connect("body_exited", _on_attack_area_exited)  # 连接退出信号
	else:
		var area_shape = attack_area.get_node_or_null("CollisionShape2D")  # 获取现有碰撞形状
		if area_shape:
			var shape = area_shape.shape as RectangleShape2D
			shape.size = Vector2(attack_range, attack_range * 0.5)  # 更新攻击范围大小
			area_shape.position = Vector2(-attack_range / 2, 0)  # 调整形状位置
		attack_area.collision_layer = 0  # 不发射碰撞
		attack_area.collision_mask = 2  # 检测 Layer 2
		attack_area.connect("body_entered", _on_attack_area_entered)  # 连接进入信号
		attack_area.connect("body_exited", _on_attack_area_exited)  # 连接退出信号

# 每帧处理
func _process(delta: float):
	if is_dead or is_knocked_back:
		velocity = Vector2.ZERO  # 死亡或被击退时停止移动
		return

	# 处理攻击冷却
	if attack_timer > 0:
		attack_timer -= delta  # 减少冷却时间

	# 如果有有效目标，持续攻击
	if current_target and is_instance_valid(current_target):
		if not is_attacking and attack_timer <= 0:
			perform_attack(current_target)  # 执行攻击
		velocity = Vector2.ZERO  # 攻击时停止移动
		return

	# 无目标，恢复移动
	var direction = Vector2(-1, 0)  # 默认向左移动
	velocity = direction * speed  # 设置移动速度
	if animated_sprite and animated_sprite.animation != "run":
		animated_sprite.play("run")  # 播放跑动动画
	global_position += velocity * delta  # 更新位置

# 当物体进入攻击范围时触发
func _on_attack_area_entered(body: Node):
	if body.is_in_group("attackable") and not current_target:
		current_target = body  # 设置当前目标
		body.destroyed.connect(_on_target_destroyed.bind(body))  # 连接目标销毁信号
		perform_attack(body)  # 立即执行攻击

# 当物体离开攻击范围时触发
func _on_attack_area_exited(body: Node):
	if body == current_target:
		if body.destroyed.is_connected(_on_target_destroyed):
			body.destroyed.disconnect(_on_target_destroyed)  # 断开销毁信号
		current_target = null  # 清空目标
		is_attacking = false  # 停止攻击
		if animated_sprite and not is_dead:
			animated_sprite.play("run")  # 恢复跑动动画

# 当目标被销毁时触发
func _on_target_destroyed(instance: Node):
	if instance == current_target:
		current_target = null  # 清空目标
		is_attacking = false  # 停止攻击
		if animated_sprite and not is_dead:
			animated_sprite.play("run")  # 恢复跑动动画

# 执行攻击
func perform_attack(target: Node2D):
	is_attacking = true  # 标记为攻击状态
	velocity = Vector2.ZERO  # 停止移动
	if animated_sprite:
		animated_sprite.play("attack")  # 播放攻击动画
		var frames = animated_sprite.sprite_frames.get_frame_count("attack")  # 获取动画帧数
		var fps = animated_sprite.sprite_frames.get_animation_speed("attack")  # 获取动画速度
		var attack_duration = frames / fps if fps > 0 else 0.0  # 计算动画持续时间
		await get_tree().create_timer(attack_duration).timeout  # 等待动画完成
	if is_instance_valid(target) and not is_dead:
		target.perform_attack_from_enemy(self)  # 对目标执行攻击
	attack_timer = attack_cooldown  # 重置攻击冷却
	is_attacking = false  # 结束攻击状态
	if current_target and is_instance_valid(current_target) and attack_timer <= 0:
		perform_attack(current_target)  # 如果目标仍有效，继续攻击

# 受到伤害
func take_damage(damage: float):
	if is_dead:
		return  # 如果已死亡，忽略伤害
	health -= damage  # 扣除血量
	damaged.emit(damage, global_position)  # 发出伤害信号
	if health <= 0:
		is_dead = true  # 标记为死亡
		if animated_sprite:
			animated_sprite.play("death")  # 播放死亡动画
		else:
			queue_free()  # 如果无动画，直接销毁

# 应用击退效果
func apply_knockback():
	if is_dead or is_knocked_back:
		return  # 如果已死亡或正在击退，忽略
	is_knocked_back = true  # 标记为击退状态
	velocity = Vector2.ZERO  # 停止移动
	if animated_sprite:
		animated_sprite.play("run")  # 播放跑动动画（可根据需要调整）

	# 记录初始 Y 坐标
	var original_y = global_position.y

	# 第一阶段：右上移动
	var up_direction = Vector2(cos(deg_to_rad(KNOCKBACK_UP_ANGLE)), -sin(deg_to_rad(KNOCKBACK_UP_ANGLE)))  # 计算右上方向
	var up_distance = KNOCKBACK_DISTANCE / 2.0  # 击退距离的一半
	var up_target = global_position + up_direction * up_distance  # 计算目标位置
	var up_tween = create_tween()  # 创建动画
	up_tween.tween_property(self, "global_position", up_target, KNOCKBACK_DURATION / 2.0)  # 移动到目标位置
	await up_tween.finished  # 等待动画完成

	# 第二阶段：回到接近原始 Y 坐标（仅沿 X 轴移动）
	var return_target = Vector2(global_position.x, original_y)  # 计算返回位置
	var return_tween = create_tween()  # 创建动画
	return_tween.tween_property(self, "global_position", return_target, KNOCKBACK_DURATION / 2.0)  # 移动到返回位置
	await return_tween.finished  # 等待动画完成

	is_knocked_back = false  # 结束击退状态
	if animated_sprite and not is_dead and not current_target:
		animated_sprite.play("run")  # 恢复跑动动画

# 应用强化效果
func apply_enhancement():
	if is_enhanced:
		return  # 如果已强化，忽略
	is_enhanced = true  # 标记为强化状态
	base_speed *= 2.0  # 速度翻倍
	base_damage_base *= 2.0  # 基础伤害翻倍
	base_damage = base_damage_base  # 更新当前伤害
	speed = base_speed  # 更新当前速度

# 当动画完成时触发
func _on_animation_finished():
	if is_dead and animated_sprite.animation == "death":
		queue_free()  # 死亡动画播放完毕后销毁敌人
