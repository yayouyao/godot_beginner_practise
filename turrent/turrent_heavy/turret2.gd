extends Area2D

# 可配置属性
@export var bullet_scene: PackedScene  # 子弹场景，需在编辑器中指定
@export var fire_cooldown: float = 8.0  # 射击冷却时间（秒）

# 内部变量
var current_cooldown: float = 0.0  # 当前射击冷却计时
var is_setting_target: bool = false  # 是否正在设置目标位置
var target_position: Vector2 = Vector2.ZERO  # 目标位置
@onready var cursor_sprite: AnimatedSprite2D = $CursorSprite  # 光标精灵
@onready var marker_sprite: AnimatedSprite2D = $MarkerSprite  # 目标标记精灵
var progress_bar: ProgressBar = null  # 射击冷却进度条
var branch1_level: int = 0  # 分支1等级（影响子弹数量）
var branch2_level: int = 0  # 分支2等级（影响伤害）
var branch3_level: int = 0  # 分支3等级（影响冷却时间）
var effective_cooldown: float = 8.0  # 实际冷却时间（受分支3影响）

# 节点初始化时调用
func _ready():
	if modulate.a >= 1.0:
		add_to_group("turrets")  # 如果可见，添加到 turrets 组
	
	# 检查光标精灵
	if cursor_sprite:
		cursor_sprite.visible = false  # 初始隐藏光标
	else:
		printerr("错误：未找到 CursorSprite 节点！")  # 如果光标精灵缺失，打印错误
	
	# 检查目标标记精灵
	if marker_sprite:
		marker_sprite.visible = false  # 初始隐藏标记
	else:
		printerr("错误：未找到 MarkerSprite 节点！")  # 如果标记精灵缺失，打印错误

	# 创建并配置冷却进度条
	progress_bar = ProgressBar.new()  # 创建进度条
	progress_bar.size = Vector2(50, 10)  # 设置尺寸
	progress_bar.max_value = 100.0  # 设置最大值
	progress_bar.value = 0.0  # 设置初始值
	progress_bar.show_percentage = false  # 隐藏百分比
	progress_bar.visible = false  # 初始隐藏
	add_child(progress_bar)  # 添加到节点树

	# 创建点击区域
	var click_area = Area2D.new()  # 创建用于点击的区域
	var collision_shape = CollisionShape2D.new()  # 创建碰撞形状
	var shape = CircleShape2D.new()  # 创建圆形形状
	shape.radius = 30  # 设置点击区域半径
	collision_shape.shape = shape  # 绑定形状
	click_area.add_child(collision_shape)  # 添加形状到点击区域
	click_area.set_collision_layer_value(2, true)  # 设置碰撞层
	click_area.name = "ClickArea"  # 设置名称
	add_child(click_area)  # 添加到节点树
	click_area.connect("input_event", _on_click_area_input_event)  # 连接输入事件

# 处理点击区域输入事件
# @param _viewport: 视口节点（未使用）
# @param event: 输入事件
# @param _shape_idx: 形状索引（未使用）
func _on_click_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var ui = get_tree().get_first_node_in_group("ui")  # 获取 UI 节点
		if ui:
			ui.show_skill_tree(self)  # 显示技能树界面
		else:
			printerr("错误：未找到 UI 节点！")  # 如果 UI 缺失，打印错误

# 处理输入事件
func _input(event):
	if event is InputEventKey and event.keycode == KEY_SPACE and event.pressed and not event.is_echo():
		if not is_setting_target:
			is_setting_target = true  # 进入目标设置模式
			if cursor_sprite:
				cursor_sprite.visible = true  # 显示光标
			if marker_sprite:
				marker_sprite.visible = false  # 隐藏标记

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and is_setting_target:
		target_position = get_global_mouse_position()  # 设置目标位置
		marker_sprite.global_position = target_position  # 更新标记位置
		marker_sprite.visible = true  # 显示标记
		cursor_sprite.visible = false  # 隐藏光标
		is_setting_target = false  # 退出目标设置模式
		shoot()  # 触发射击

# 每帧处理
func _process(delta: float):
	current_cooldown -= delta  # 减少冷却计时
	if is_setting_target and cursor_sprite:
		cursor_sprite.global_position = get_global_mouse_position()  # 更新光标位置

	if progress_bar:
		var progress = (current_cooldown / effective_cooldown) * 100.0  # 计算冷却进度百分比
		progress_bar.value = clamp(progress, 0.0, 100.0)  # 限制进度值
		progress_bar.global_position = global_position + Vector2(-25, 30)  # 设置进度条位置
		progress_bar.visible = current_cooldown > 0  # 冷却期间显示进度条

# 射击
func shoot():
	if not bullet_scene:
		printerr("错误：未设置子弹场景！")  # 如果子弹场景缺失，打印错误
		return
	if current_cooldown > 0:
		return  # 如果冷却未结束，跳过射击

	var bullet_count = 1 + branch1_level  # 计算子弹数量（基础1 + 分支1等级）

	for _i in range(bullet_count):
		var bullet = bullet_scene.instantiate()  # 实例化子弹
		if not bullet:
			printerr("错误：实例化子弹失败！")  # 如果实例化失败，打印错误
			return

		bullet.global_position = global_position + Vector2(50, 50)  # 设置子弹初始位置
		bullet.initialize(self, target_position)  # 初始化子弹（传递炮塔和目标位置）
		get_tree().current_scene.add_child(bullet)  # 添加子弹到场景

	current_cooldown = effective_cooldown  # 重置冷却计时
	if progress_bar:
		progress_bar.value = 100.0  # 设置进度条为满
		progress_bar.visible = true  # 显示进度条

# 升级分支1（子弹数量）
func upgrade_branch1():
	if branch1_level < 3:
		branch1_level += 1  # 增加分支1等级
	else:
		print("分支1已达最大等级！")  # 已达最大等级

# 升级分支2（伤害）
func upgrade_branch2():
	if branch2_level < 3:
		branch2_level += 1  # 增加分支2等级
		var damage_increase = 0.10 + (0.10 * (branch2_level - 1))  # 计算伤害增量（未实际应用）
	else:
		print("分支2已达最大等级！")  # 已达最大等级

# 升级分支3（冷却）
func upgrade_branch3():
	if branch3_level < 3:
		branch3_level += 1  # 增加分支3等级
		update_cooldown()  # 更新冷却时间
	else:
		print("分支3已达最大等级！")  # 已达最大等级

# 更新冷却时间
func update_cooldown():
	effective_cooldown = fire_cooldown  # 初始化冷却时间
	if branch3_level >= 1:
		effective_cooldown *= 0.9  # 等级1：减少10%冷却
	if branch3_level >= 2:
		effective_cooldown *= 0.7 / 0.9  # 等级2：再减少约22%（累计30%）
	if branch3_level >= 3:
		effective_cooldown *= 0.4 / 0.7  # 等级3：再减少约43%（累计60%）
