extends Area2D

# 可配置属性
@export var bullet_scene: PackedScene  # 子弹场景，需在编辑器中指定
@export var fire_cooldown: float = 5.0  # 射击冷却时间（秒，未实际使用）

# 内部变量
var is_preview: bool = false  # 是否为预览模式
var initial_position: Vector2 = Vector2.ZERO  # 初始位置
@onready var sound_player = $SoundPlayer  # 射击音效播放器

# 节点初始化时调用
func _ready():
	initial_position = global_position  # 记录初始位置
	print("turret_push.gd _ready: is_preview = ", is_preview, " position = ", initial_position)  # 调试信息
	
	if not is_preview:
		shoot()  # 如果不是预览模式，立即射击
		destroy_and_free_zone()  # 销毁炮塔并释放区域

# 射击
func shoot():
	sound_player.play()  # 播放射击音效
	
	if not bullet_scene:
		printerr("错误：未设置子弹场景！")  # 如果子弹场景缺失，打印错误
		return
	
	var bullet = bullet_scene.instantiate()  # 实例化子弹
	if not bullet:
		printerr("错误：实例化子弹失败！")  # 如果实例化失败，打印错误
		return
	
	bullet.global_position = global_position  # 设置子弹位置
	var direction = Vector2(cos(rotation), sin(rotation)).normalized()  # 根据炮塔旋转计算子弹方向
	bullet.set_direction(direction)  # 设置子弹方向
	
	# 设置子弹属性
	var bullet_properties = {
		"speed": 200.0,  # 子弹速度
		"lifetime": 5.0,  # 子弹存活时间
		"physical_damage": 30.0,  # 物理伤害
		"aoe_radius": 0.0,  # 范围伤害半径
		"aoe_damage": 0.0,  # 范围伤害
		"fire_damage": 0.0,  # 火焰伤害
		"fire_duration": 0.0,  # 火焰持续时间
		"slow_factor": 1.0,  # 减速因子（1.0 表示无减速）
		"slow_duration": 0.0,  # 减速持续时间
		"knockback_strength": 5.0,  # 击退强度
		"max_travel_distance": 1000.0  # 最大移动距离
	}
	bullet.set_properties(bullet_properties)  # 应用子弹属性
	
	get_tree().current_scene.add_child(bullet)  # 添加子弹到场景

# 销毁炮塔并释放区域
func destroy_and_free_zone():
	call_deferred("queue_free")  # 延迟销毁炮塔
