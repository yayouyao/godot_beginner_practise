extends Area2D

# 可配置属性
@export var speed: float = 200.0             # 子弹移动速度（像素/秒）
@export var lifetime: float = 5.0            # 子弹存活时间（秒）
@export var knockback_strength: float = 5.0  # 击退力度
@export var max_travel_distance: float = 1000.0  # 子弹最大移动距离（像素）

# 内部变量
const ENEMY_GROUP: String = "enemy"          # 敌人组的名称，用于识别敌人
var direction: Vector2 = Vector2.ZERO        # 子弹移动方向（归一化向量）
var is_destroyed: bool = false               # 子弹是否已被销毁
var lifetime_timer: float = 0.0              # 子弹剩余存活时间计时器
var traveled_distance: float = 0.0           # 子弹已移动的距离
var initial_position: Vector2 = Vector2.ZERO  # 子弹初始位置

@onready var sprite: Sprite2D = $Sprite2D                  # 引用子弹的 Sprite2D 节点
@onready var collision_shape: CollisionShape2D = $CollisionShape2D  # 引用子弹的碰撞形状节点

# 节点初始化时调用
func _ready():
	# 验证节点是否存在
	if not sprite:
		printerr("错误: 未找到 Sprite2D 节点！")  # 如果未找到 Sprite2D，打印错误
		return
	
	if not collision_shape:
		printerr("错误: 未找到 CollisionShape2D 节点！")  # 如果未找到 CollisionShape2D，打印错误
		return
	
	# 连接 area_entered 信号
	if not is_connected("area_entered", _on_area_entered):
		var error = connect("area_entered", _on_area_entered)  # 连接区域进入信号
	
	# 记录初始位置并初始化存活时间
	initial_position = global_position  # 记录子弹的起始位置
	lifetime_timer = lifetime          # 设置存活时间计时器

# 设置子弹方向
func set_direction(dir: Vector2):
	direction = dir.normalized()  # 归一化方向向量
	if sprite and direction != Vector2.ZERO:
		sprite.rotation = direction.angle()  # 旋转 Sprite2D 以匹配方向

# 每帧物理处理
func _physics_process(delta: float):
	if is_destroyed:
		return  # 如果子弹已销毁，跳过处理
	
	lifetime_timer -= delta  # 减少存活时间
	if lifetime_timer <= 0:
		queue_free()  # 如果存活时间耗尽，销毁子弹
		return
	
	var viewport_rect = get_viewport_rect()  # 获取视口矩形
	if !viewport_rect.has_point(global_position):
		queue_free()  # 如果子弹超出视口，销毁子弹
		return
	
	# 径直移动
	var movement = direction * speed * delta  # 计算本帧移动向量
	global_position += movement  # 更新子弹位置
	traveled_distance += movement.length()  # 累加移动距离
	
	# 检查最大移动距离
	if traveled_distance >= max_travel_distance:
		queue_free()  # 如果达到最大移动距离，销毁子弹
		return

# 当子弹进入某个区域时触发
func _on_area_entered(area: Area2D):
	if is_destroyed:
		return  # 如果子弹已销毁，跳过处理
	if area.is_in_group(ENEMY_GROUP) and is_instance_valid(area):
		apply_effects(area)  # 对有效敌人应用效果

# 对敌人应用效果
func apply_effects(enemy: Node2D):
	if knockback_strength > 0:
		enemy.apply_knockback()  # 调用敌人的击退函数，应用击退效果

# 设置子弹属性（从字典中获取）
func set_properties(props: Dictionary):
	knockback_strength = props.get("knockback_strength", knockback_strength)  # 设置击退力度，保留默认值
	max_travel_distance = props.get("max_travel_distance", max_travel_distance)  # 设置最大移动距离，保留默认值
