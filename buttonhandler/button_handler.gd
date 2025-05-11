extends Node2D

# 可配置属性
@export var normal_turret_scene: PackedScene  # 普通炮塔场景，需在编辑器中指定
@export var heavy_turret_scene: PackedScene   # 重型炮塔场景，需在编辑器中指定
@export var push_turret_scene: PackedScene    # 推力炮塔场景，需在编辑器中指定

# 节点引用
@onready var sound_player = $SoundPlayer  # 引用播放按钮点击音效的节点
@onready var normal_turret_card: Button = %TurretCard  # 普通炮塔按钮，需在场景中设置唯一名称
@onready var heavy_turret_card: Button = %HeavyTurretCard  # 重型炮塔按钮，需在场景中设置唯一名称
@onready var push_turret_card: Button = %PushTurretCard  # 推力炮塔按钮，需在场景中设置唯一名称

# 内部变量
var selected_turret: PackedScene = null  # 当前选中的炮塔类型（普通、重型或推力）
var selected_button: Button = null       # 当前选中的按钮
var ui: CanvasLayer = null               # UI 节点引用，用于与 UI 交互

# 信号：当选中炮塔类型变化时发出
signal turret_selected(turret_scene: PackedScene)  # 发出信号，通知炮塔选择状态变化

# 节点初始化时调用
func _ready():
	# 连接普通炮塔按钮的 pressed 信号
	if normal_turret_card:
		normal_turret_card.pressed.connect(_on_normal_turret_card_pressed)
	else:
		printerr("错误: 未找到普通炮塔按钮")  # 如果按钮缺失，打印错误

	# 连接重型炮塔按钮的 pressed 信号
	if heavy_turret_card:
		heavy_turret_card.pressed.connect(_on_heavy_turret_card_pressed)
	else:
		printerr("错误: 未找到重型炮塔按钮")  # 如果按钮缺失，打印错误

	# 连接推力炮塔按钮的 pressed 信号
	if push_turret_card:
		push_turret_card.pressed.connect(_on_push_turret_card_pressed)
	else:
		printerr("错误: 未找到推力炮塔按钮")  # 如果按钮缺失，打印错误

# 每帧处理输入
func _process(_delta: float):
	# 快捷键选择炮塔
	if Input.is_action_just_pressed("ui_1"):
		_on_normal_turret_card_pressed()  # 按键 1 选择普通炮塔
	elif Input.is_action_just_pressed("ui_2"):
		_on_heavy_turret_card_pressed()  # 按键 2 选择重型炮塔
	elif Input.is_action_just_pressed("ui_3"):
		_on_push_turret_card_pressed()  # 按键 3 选择推力炮塔

# 当普通炮塔按钮被点击时调用
func _on_normal_turret_card_pressed():
	sound_player.play()  # 播放点击音效
	if not ui:
		printerr("错误: UI 未设置！")  # 如果 UI 未设置，打印错误
		return
	
	# 如果当前按钮已被选中，再次点击取消选中
	if selected_button == normal_turret_card:
		deselect_button()  # 取消选中状态
	else:
		deselect_button()  # 取消上一个按钮的选中状态
		selected_button = normal_turret_card  # 设置当前按钮为选中
		selected_turret = normal_turret_scene  # 设置当前炮塔为普通炮塔
		normal_turret_card.modulate = Color(0.5, 1, 0.5)  # 设置按钮为绿色高亮
		emit_signal("turret_selected", selected_turret)  # 发出炮塔选择信号

# 当重型炮塔按钮被点击时调用
func _on_heavy_turret_card_pressed():
	sound_player.play()  # 播放点击音效
	if not ui:
		printerr("错误: UI 未设置！")  # 如果 UI 未设置，打印错误
		return
	
	# 如果当前按钮已被选中，再次点击取消选中
	if selected_button == heavy_turret_card:
		deselect_button()  # 取消选中状态
	else:
		deselect_button()  # 取消上一个按钮的选中状态
		selected_button = heavy_turret_card  # 设置当前按钮为选中
		selected_turret = heavy_turret_scene  # 设置当前炮塔为重型炮塔
		heavy_turret_card.modulate = Color(0.5, 1, 0.5)  # 设置按钮为绿色高亮
		print("重型炮塔已选中，selected_turret: ", selected_turret)  # 调试信息
		emit_signal("turret_selected", selected_turret)  # 发出炮塔选择信号

# 当推力炮塔按钮被点击时调用
func _on_push_turret_card_pressed():
	sound_player.play()  # 播放点击音效
	if not ui:
		printerr("错误: UI 未设置！")  # 如果 UI 未设置，打印错误
		return
	
	# 如果当前按钮已被选中，再次点击取消选中
	if selected_button == push_turret_card:
		deselect_button()  # 取消选中状态
	else:
		deselect_button()  # 取消上一个按钮的选中状态
		selected_button = push_turret_card  # 设置当前按钮为选中
		selected_turret = push_turret_scene  # 设置当前炮塔为推力炮塔
		push_turret_card.modulate = Color(0.5, 1, 0.5)  # 设置按钮为绿色高亮
		print("推力炮塔已选中，selected_turret: ", selected_turret)  # 调试信息
		emit_signal("turret_selected", selected_turret)  # 发出炮塔选择信号

# 取消按钮的选中状态
func deselect_button():
	if selected_button:
		selected_button.modulate = Color.WHITE  # 恢复按钮颜色为默认白色
		selected_button = null  # 清空选中按钮
	selected_turret = null  # 清空选中炮塔
	emit_signal("turret_selected", selected_turret)  # 发出炮塔选择信号（无炮塔）

# 设置 UI 引用
# @param ui_node: 从 Main 场景传递的 UI 节点
func set_ui(ui_node: CanvasLayer):
	ui = ui_node  # 设置 UI 节点引用
