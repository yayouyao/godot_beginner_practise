extends Node2D

# 可配置属性
@export var speed: float = 500.0          # 子弹的基础速度（像素/秒）
@export var lifetime: float = 5.0         # 子弹存活时间（秒）
@export var aoe_radius: float = 200.0     # 范围伤害半径（像素）
@export var aoe_damage: float = 100.0     # 范围伤害值

# 内部变量
const ENEMY_GROUP: String = "enemy"       # 敌人组的名称，用于识别敌人
var target_position: Vector2 = Vector2.ZERO  # 子弹的目标位置
var original_target: Vector2 = Vector2.ZERO  # 初始目标位置，用于后续检测
var is_destroyed: bool = false            # 子弹是否已被销毁
var turret: Area2D = null                 # 发射子弹的炮塔引用
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D  # 子弹的动画精灵
var screen_width: float = 1280.0          # 屏幕宽度，用于抛物线计算
var last_y: float = 0.0                   # 上一次的 Y 坐标（未使用）
var has_reached_peak: bool = false        # 是否达到抛物线顶点
var velocity: Vector2 = Vector2.ZERO      # 子弹当前速度（包括水平和垂直分量）
var bullet_gravity: float = 980.0         # 子弹受的重力加速度
var aoe_display_timer: float = 0.0        # 范围伤害视觉效果的显示计时器
const AOE_DISPLAY_DURATION: float = 0.5   # 范围伤害视觉效果的持续时间（秒）

# 节点初始化时调用
func _ready():
	var viewport = get_viewport()  # 获取视口
	if viewport:
		screen_width = viewport.size.x  # 设置屏幕宽度
	else:
		screen_width = 1920  # 默认宽度（如果无法获取视口）

# 每帧物理处理
func _physics_process(delta: float):
	if is_destroyed:
		return  # 如果子弹已销毁，跳过处理

	velocity.y += bullet_gravity * delta  # 应用重力，增加垂直速度
	global_position += velocity * delta   # 根据速度更新位置

	# 检测是否达到抛物线顶点（当垂直速度从负变为正）
	if velocity.y > 0 and not has_reached_peak:
		has_reached_peak = true

	# 检查是否接近目标位置（在抛物线下降阶段）
	var current_y = global_position.y
	if has_reached_peak and abs(current_y - original_target.y) < 10.0 and velocity.y > 0:
		apply_aoe_damage()  # 到达目标时应用范围伤害
		return

	lifetime -= delta  # 减少存活时间
	if lifetime <= 0:
		apply_aoe_damage()  # 存活时间耗尽时应用范围伤害
		return

	# 处理范围伤害视觉效果的显示
	if aoe_display_timer > 0:
		aoe_display_timer -= delta
		if aoe_display_timer <= 0:
			if has_node("AOEVisual"):
				get_node("AOEVisual").queue_free()  # 移除视觉效果节点

# 应用范围伤害
func apply_aoe_damage():
	var aoe_area = Area2D.new()  # 创建范围伤害检测区域
	aoe_area.name = "AOEDetectionArea"
	var collision_shape = CollisionShape2D.new()  # 创建碰撞形状
	var circle_shape = CircleShape2D.new()  # 创建圆形碰撞形状
	circle_shape.radius = aoe_radius  # 设置范围半径
	collision_shape.shape = circle_shape  # 绑定形状
	aoe_area.add_child(collision_shape)  # 添加碰撞形状到区域
	
	# 设置碰撞层和掩码
	aoe_area.set_collision_layer_value(1, true)  # 在 Layer 1（子弹层）
	aoe_area.set_collision_mask_value(3, true)   # 检测 Layer 3（敌人层）
	
	aoe_area.global_position = global_position  # 设置区域位置
	get_tree().current_scene.add_child(aoe_area)  # 添加到当前场景
	
	# 等待物理帧以确保碰撞检测
	await get_tree().physics_frame
	
	var enemies = aoe_area.get_overlapping_areas()  # 获取重叠的敌人
	for enemy in enemies:
		if enemy.is_in_group(ENEMY_GROUP) and is_instance_valid(enemy):
			enemy.take_damage(aoe_damage)  # 对有效敌人造成范围伤害
	
	if is_instance_valid(aoe_area):
		aoe_area.queue_free()  # 销毁范围检测区域
	
	show_aoe_visual()  # 显示范围伤害视觉效果
	queue_free()  # 销毁子弹

# 显示范围伤害的视觉效果
func show_aoe_visual():
	if not has_node("AOEVisual"):
		var aoe_visual = ColorRect.new()  # 创建颜色矩形作为视觉效果
		aoe_visual.name = "AOEVisual"
		aoe_visual.color = Color(1.0, 0.0, 0.0, 0.3)  # 红色半透明效果
		var diameter = aoe_radius * 2  # 设置视觉效果直径
		aoe_visual.size = Vector2(diameter, diameter)  # 设置大小
		aoe_visual.position = Vector2(-aoe_radius, -aoe_radius)  # 居中定位
		aoe_visual.z_index = -1  # 放置在底层
		add_child(aoe_visual)  # 添加到子弹节点
	aoe_display_timer = AOE_DISPLAY_DURATION  # 设置视觉效果持续时间

# 初始化子弹
func initialize(turret_ref: Area2D = null, target_pos: Vector2 = Vector2.ZERO):
	turret = turret_ref  # 设置炮塔引用
	target_position = target_pos if target_pos != Vector2.ZERO else global_position + Vector2(100, 0)  # 设置目标位置，默认为右方100像素
	original_target = target_position  # 记录初始目标位置
	
	# 计算抛物线轨迹
	var dx = target_position.x - global_position.x  # 水平距离
	var dy = target_position.y - global_position.y  # 垂直距离
	bullet_gravity = ProjectSettings.get_setting("physics/2d/default_gravity", 980.0)  # 获取默认重力

	var target_height = screen_width / 3.0  # 抛物线顶点高度（屏幕宽度的1/3）
	var t = sqrt(8.0 * target_height / bullet_gravity)  # 计算飞行时间
	if t <= 0.001:
		t = 1.0  # 避免除零

	var vx = dx / t if t > 0 else 1.0  # 水平速度
	var vy = (bullet_gravity * t) / 2.0  # 初始垂直速度（抛物线顶点）
	var vy_adjusted = (dy - (0.5 * bullet_gravity * t * t)) / t if t > 0 else dy  # 调整垂直速度以到达目标

	# 计算速度大小和角度
	var velocity_magnitude = max(1.0, sqrt(vx * vx + vy_adjusted * vy_adjusted))  # 速度大小
	var angle = atan2(vy_adjusted, vx)  # 计算初始角度
	var angle_offset = deg_to_rad(randf_range(-5.0, 5.0))  # 随机角度偏移（-5到5度）
	angle += angle_offset  # 应用偏移
	var velocity_scale = randf_range(0.9, 1.1)  # 随机速度缩放（0.9到1.1倍）
	velocity_magnitude *= velocity_scale  # 应用缩放

	# 计算最终速度分量
	vx = velocity_magnitude * cos(angle)  # 水平速度
	vy_adjusted = velocity_magnitude * sin(angle)  # 垂直速度

	velocity = Vector2(vx, vy_adjusted)  # 设置子弹速度

	# 设置动画精灵方向
	if animated_sprite:
		if velocity != Vector2.ZERO:
			animated_sprite.rotation = velocity.angle()  # 旋转以匹配速度方向
		else:
			animated_sprite.rotation = 0  # 默认无旋转
		animated_sprite.visible = true  # 显示动画精灵

	var final_angle = rad_to_deg(atan2(vy_adjusted, vx))  # 计算最终角度（未使用）

# 设置子弹属性（从字典中获取）
func set_properties(props: Dictionary):
	speed = props.get("speed", speed)  # 设置速度，保留默认值
	lifetime = props.get("lifetime", lifetime)  # 设置存活时间
	aoe_radius = props.get("aoe_radius", aoe_radius)  # 设置范围伤害半径
	aoe_damage = props.get("aoe_damage", aoe_damage)  # 设置范围伤害值
