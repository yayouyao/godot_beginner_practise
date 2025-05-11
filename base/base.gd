extends StaticBody2D

# 基地血量
@export var max_health: float = 1000  # 基地的最大血量，可在编辑器中调整
var health: float = max_health        # 基地当前血量，初始化为最大血量
@onready var health_label: Label = $HealthLabel  # 引用显示血量的Label节点
@onready var sound_player = $SoundPlayer         # 引用播放音效的节点

# 信号：基地血量变化
signal health_changed(new_health: float)  # 当血量变化时发出，传递新的血量值
# 信号：基地被摧毁，绑定实例
signal destroyed(instance: Node)          # 当基地被摧毁时发出，传递被摧毁的节点实例

# 节点初始化时调用
func _ready():
	add_to_group("attackable")  # 将基地添加到“可被攻击”组，方便敌人识别
	health = max_health        # 初始化血量为最大值
	update_health_label()       # 更新血量显示
	
	# 添加碰撞体（如果未手动设置）
	if not $CollisionShape2D:
		var collision_shape = CollisionShape2D.new()  # 创建新的碰撞形状节点
		var shape = RectangleShape2D.new()           # 创建矩形碰撞形状
		shape.size = Vector2(100, 100)               # 设置碰撞体大小为100x100
		collision_shape.shape = shape                # 绑定形状到碰撞体
		add_child(collision_shape)                   # 将碰撞体添加到节点树
	
	# 设置碰撞层为 Layer 2（attackable）
	collision_layer = 2  # 设置在Layer 2，标记为可被攻击
	collision_mask = 0   # 不检测其他层的碰撞，基地不需要主动检测
	
	# 同步初始血量到 Global 单例
	var global = get_node("/root/Global")  # 获取全局单例节点
	if global:
		global.player_health = health      # 将初始血量同步到全局变量
	else:
		printerr("错误：未找到 Global 单例，无法同步初始血量！")  # 错误提示

# 处理来自敌人的攻击
func perform_attack_from_enemy(enemy: Node):
	var global = get_node("/root/Global")  # 获取全局单例节点
	if health > 0 and global:             # 确保基地未被摧毁且全局单例存在
		health -= enemy.base_damage       # 扣除敌人造成的伤害
		health_changed.emit(health)        # 发出血量变化信号
		global.player_health = int(health) # 同步当前血量到全局变量（转为整数）
		update_health_label()              # 更新血量显示
		if health <= 0:                   # 如果血量归零
			health = 0                    # 确保血量不低于0
			destroyed.emit(self)          # 发出摧毁信号，绑定自身
			print("基地被摧毁！")         # 打印摧毁信息
			sound_player.play()           # 播放摧毁音效
			queue_free()                  # 销毁基地节点
	else:
		if not global:
			printerr("错误：未找到 Global 单例，无法更新血量！")  # 错误提示

# 更新血量标签的文本和颜色
func update_health_label():
	var percent = health / max_health  # 计算当前血量百分比
	health_label.text = "Base HP: %.1f%%" % (percent * 100)  # 更新血量标签，显示百分比
	health_label.modulate = Color(
		1.0,                           # 红色通道始终为1（红色恒定）
		clamp(percent * 2, 0, 1),      # 绿色通道：血量50%时开始变黄
		clamp(percent - 0.5, 0, 1)     # 蓝色通道：血量50%以下逐渐减少
	)  # 根据血量百分比调整颜色，呈现红-黄-绿渐变
