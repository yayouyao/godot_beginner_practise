extends Node2D  # 使用 Node2D 作为基类，适合 2D 场景中的飘字效果（也可使用 Control）

# 节点引用
@onready var label: Label = $TextLabel  # 引用显示伤害数值的 Label 节点

# 内部变量
var velocity: Vector2 = Vector2(0, -50)  # 文字飘动的速度（默认向上，Y 轴负方向）
var fade_time: float = 1.0              # 文字显示和淡出的持续时间（秒）

# 节点初始化时调用
func _ready():
	# 验证 Label 节点是否存在
	if not label:
		printerr("错误：未找到 TextLabel 节点！请检查 damage_number.tscn 的场景树。")  # 如果未找到 Label，打印错误
	else:
		print("TextLabel 节点已找到：", label)  # 调试信息，确认 Label 节点加载成功
	
	# 设置自动销毁计时器
	await get_tree().create_timer(fade_time).timeout  # 等待 fade_time 秒后销毁
	queue_free()  # 销毁节点

# 每帧处理
func _process(delta: float):
	position += velocity * delta  # 根据速度更新文字位置，实现向上飘动效果
	label.modulate.a -= delta / fade_time  # 逐渐减少透明度，实现淡出效果

# 设置显示的数值和颜色
# @param value: 要显示的伤害数值（浮点数）
# @param color: 文字颜色（默认红色）
func setup(value: float, color: Color = Color.RED):
	label.text = str(value)  # 将浮点数值转换为字符串并设置到 Label
	label.modulate = color   # 设置文字颜色
