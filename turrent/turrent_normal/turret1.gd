extends Area2D

# 可配置属性
@export var kaderBullet_scene: PackedScene  # 子弹场景，需在编辑器中指定
@export var fire_cooldown: float = 1.0  # 射击冷却时间（秒）
@export var detection_range: float = 1000  # 检测敌人的范围（像素）
@export var bullet_damage: float = 15  # 子弹基础伤害

# 内部变量
var current_cooldown: float = 0.0  # 当前射击冷却计时
var target: Node2D = null  # 当前目标敌人
var pool: Node = null  # 对象池引用
@onready var detection_area: Area2D = $DetectionArea  # 检测区域节点
@onready var sound_player = $SoundPlayer  # 射击音效播放器
var branch1_level: int = 0  # 分支1等级（影响伤害）
var branch2_level: int = 0  # 分支2等级（影响穿透次数）
var branch3_level: int = 0  # 分支3等级（影响射击冷却）
var effective_cooldown: float = 1.0  # 实际冷却时间（受分支3影响）

# 节点初始化时调用
func _ready():
	if modulate.a >= 1.0:
		add_to_group("turrets")  # 如果可见，添加到 turrets 组
	z_index = 10  # 设置绘制层级
	pool = get_node("/root/GlobalObjectPool")  # 获取全局对象池
	if pool and is_instance_valid(pool):
		if kaderBullet_scene:
			pool.initialize_pool(kaderBullet_scene)  # 初始化子弹对象池
		else:
			printerr("错误：kaderBullet_scene 未赋值！")  # 如果子弹场景缺失，打印错误
	else:
		printerr("错误：未找到 GlobalObjectPool！")  # 如果对象池缺失，打印错误
	
	# 连接检测区域信号
	detection_area.body_entered.connect(_on_body_entered)  # 敌人进入检测范围
	detection_area.body_exited.connect(_on_body_exited)  # 敌人离开检测范围
	
	# 创建点击区域
	var click_area = Area2D.new()  # 创建用于点击的区域
	var collision_shape = CollisionShape2D.new()  # 创建碰撞形状
	var shape = CircleShape2D.new()  # 创建圆形形状
	shape.radius = 30  # 设置点击区域半径
	collision_shape.shape = shape  # 绑定形状
	click_area.add_child(collision_shape)  # 添加形状到点击区域
	click_area.collision_layer = 2  # 设置碰撞层
	click_area.collision_mask = 0  # 不检测其他层
	click_area.name = "ClickArea"  # 设置名称
	add_child(click_area)  # 添加到节点树
	click_area.connect("input_event", _on_click_area_input_event)  # 连接输入事件
	update_cooldown()  # 初始化冷却时间

# 每帧处理
func _process(delta: float):
	current_cooldown -= delta  # 减少冷却计时
	update_target()  # 更新目标
	if target and current_cooldown <= 0:
		shoot()  # 如果有目标且冷却结束，射击

	if target:
		var direction = (target.global_position - global_position).normalized()  # 计算朝向目标的方向
		rotation = direction.angle()  # 旋转炮塔朝向目标

# 更新目标
func update_target():
	var enemies = get_tree().get_nodes_in_group("enemy")  # 获取所有敌人
	target = null  # 重置目标
	var closest_distance: float = detection_range + 1.0  # 初始化最小距离
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue  # 跳过无效敌人
		var distance = global_position.distance_to(enemy.global_position)  # 计算距离
		if distance <= detection_range and distance < closest_distance:
			closest_distance = distance  # 更新最小距离
			target = enemy  # 设置最近敌人为目标

# 射击
func shoot():
	sound_player.play()  # 播放射击音效
	if not kaderBullet_scene:
		printerr("错误：kaderBullet_scene 未设置！")  # 如果子弹场景缺失，打印错误
		return
	if not pool or not is_instance_valid(pool):
		printerr("错误：对象池无效，无法射击！")  # 如果对象池无效，打印错误
		return

	# 固定子弹数量为 1
	var bullet_count = 1
	var penetration_count = 1 + branch2_level  # 计算穿透次数（基础1次 + 分支2等级）
	var base_direction = (target.global_position - global_position).normalized()  # 计算子弹方向
	for i in range(bullet_count):
		var bullet = pool.get_object(kaderBullet_scene)  # 从对象池获取子弹
		if not bullet:
			printerr("错误：从对象池获取子弹失败！")  # 如果获取失败，打印错误
			continue

		bullet.global_position = global_position  # 设置子弹位置
		bullet.set_direction(base_direction)  # 设置子弹方向

		# 设置子弹属性
		var bullet_properties = {
			"speed": 2000.0,  # 子弹速度
			"lifetime": 5.0,  # 子弹存活时间
			"physical_damage": bullet_damage,  # 子弹伤害
			"penetration_count": penetration_count  # 穿透次数
		}
		bullet.set_properties(bullet_properties)  # 应用属性
		bullet.pool = pool  # 设置对象池引用

		if i < bullet_count - 1:
			await get_tree().create_timer(0.05).timeout  # 多子弹时添加间隔

	current_cooldown = effective_cooldown  # 重置冷却计时

# 当物体进入检测区域时触发
func _on_body_entered(body: Node2D):
	if body.is_in_group("enemy"):
		update_target()  # 更新目标

# 当物体离开检测区域时触发
func _on_body_exited(body: Node2D):
	if body == target:
		target = null  # 清空目标
		update_target()  # 重新寻找目标

# 处理点击区域输入事件
func _on_click_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var ui = get_tree().get_first_node_in_group("ui")  # 获取 UI 节点
		if ui:
			ui.show_skill_tree(self)  # 显示技能树界面
		else:
			printerr("错误：未找到 UI 节点！")  # 如果 UI 缺失，打印错误

# 更新冷却时间
func update_cooldown():
	effective_cooldown = fire_cooldown  # 初始化冷却时间
	if branch3_level >= 1:
		effective_cooldown *= 0.9  # 等级1：减少10%冷却
	if branch3_level >= 2:
		effective_cooldown *= 0.8 / 0.9  # 等级2：再减少约11%（累计20%）
	if branch3_level >= 3:
		effective_cooldown *= 0.7 / 0.8  # 等级3：再减少约12.5%（累计30%）

# 升级分支1（伤害）
func upgrade_branch1():
	if branch1_level < 3:
		branch1_level += 1  # 增加分支1等级
		# 根据等级增加伤害
		if branch1_level == 1:
			bullet_damage += 5  # 第一次升级：+5 伤害
		elif branch1_level == 2:
			bullet_damage += 5  # 第二次升级：+5 伤害
		elif branch1_level == 3:
			bullet_damage += 10  # 第三次升级：+10 伤害
		print("turret1.gd: 分支1升级，当前等级 = ", branch1_level, ", 当前伤害 = ", bullet_damage)  # 调试信息
	else:
		print("分支1已达最大等级！")  # 已达最大等级

# 升级分支2（穿透）
func upgrade_branch2():
	if branch2_level < 3:
		branch2_level += 1  # 增加分支2等级
	else:
		print("分支2已达最大等级！")  # 已达最大等级

# 升级分支3（冷却）
func upgrade_branch3():
	if branch3_level < 3:
		branch3_level += 1  # 增加分支3等级
		update_cooldown()  # 更新冷却时间
	else:
		print("分支3已达最大等级！")  # 已达最大等级
