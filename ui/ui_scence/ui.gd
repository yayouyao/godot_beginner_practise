extends CanvasLayer
class_name UI

# 节点引用
@onready var score_label: Label = %ScoreLabel  # 分数显示标签
@onready var message_label: Label = %MessageLabel  # 消息显示标签
@onready var wave_progress: ProgressBar = %WaveProgress  # 波次进度条
var skill_tree_panel: Panel = null  # 技能树面板
var selected_turret: Node2D = null  # 选中的 turret1 炮塔
var selected_turret2: Node2D = null  # 选中的 turret2 炮塔
var selected_building: Node2D = null  # 选中的建筑

# 常量
const MESSAGE_DURATION: float = 2.0  # 消息显示持续时间（秒）
var message_timer: float = 0.0  # 消息计时器
const PANEL_ANIMATION_DURATION: float = 0.3  # 技能树面板动画持续时间（秒）
const WAVE_DURATIONS: Array[float] = [60.0, 120.0, 150.0]  # 各波次持续时间（秒）
var current_wave_duration: float = 0.0  # 当前波次持续时间
var wave_elapsed_time: float = 0.0  # 当前波次已过去时间
var is_wave_active: bool = false  # 当前是否为活跃波次

# 节点初始化时调用
func _ready():
	update_score_label()  # 初始化分数显示
	if message_label:
		message_label.text = ""  # 清空消息标签
	else:
		push_error("未找到 MessageLabel 节点！")  # 如果消息标签缺失，打印错误
	if wave_progress:
		print("UI: wave_progress 初始化完成")  # 调试信息
	else:
		push_error("未找到 WaveProgress 节点！")  # 如果进度条缺失，打印错误
	create_skill_tree_panel()  # 创建技能树面板
	add_to_group("ui")  # 添加到 ui 组
	var global = get_node("/root/Global")  # 获取 Global 单例
	if global and global.has_signal("score_changed"):
		global.score_changed.connect(_on_global_score_changed)  # 连接分数变化信号
	
	# 延迟连接敌人生成器
	call_deferred("_connect_enemy_spawner")

# 连接敌人生成器信号
func _connect_enemy_spawner():
	var enemy_spawner = get_tree().get_first_node_in_group("enemy_spawner")  # 获取敌人生成器
	if enemy_spawner:
		enemy_spawner.show_wave_message.connect(_on_show_wave_message)  # 连接波次消息信号
		enemy_spawner.game_won.connect(_on_game_won)  # 连接游戏胜利信号
		print("UI: 成功连接 enemy_spawner 节点")  # 调试信息
	else:
		push_error("未找到 enemy_spawner 节点")  # 如果生成器缺失，打印错误

# 每帧处理
func _process(delta: float):
	# 处理消息显示
	if message_label and message_label.text != "":
		message_timer -= delta
		if message_timer <= 0:
			clear_message()  # 清空消息
	
	# 更新波次进度条
	if is_wave_active and wave_progress:
		wave_elapsed_time += delta  # 增加波次时间
		var progress_value = ((current_wave_duration - wave_elapsed_time) / current_wave_duration) * 100.0  # 计算进度百分比
		wave_progress.value = clamp(progress_value, 0.0, 100.0)  # 更新进度条
		if wave_elapsed_time >= current_wave_duration:
			wave_progress.value = 0.0  # 波次结束，重置进度条
			is_wave_active = false  # 标记波次结束

# 处理波次消息
# @param message: 波次消息内容
func _on_show_wave_message(message: String):
	show_message(message)  # 显示消息
	var wave_index = -1
	if message.begins_with("第一波"):
		wave_index = 0
		current_wave_duration = WAVE_DURATIONS[0]  # 设置第一波持续时间
	elif message.begins_with("第二波"):
		wave_index = 1
		current_wave_duration = WAVE_DURATIONS[1]  # 设置第二波持续时间
	elif message.begins_with("第三波"):
		wave_index = 2
		current_wave_duration = WAVE_DURATIONS[2]  # 设置第三波持续时间
	elif message.begins_with("最后一波"):
		is_wave_active = false
		wave_progress.value = 0.0  # 最后一波，重置进度条
		return
	
	if wave_index >= 0 and wave_progress:
		wave_elapsed_time = 0.0  # 重置波次时间
		wave_progress.value = 100.0  # 设置进度条为满
		is_wave_active = true  # 标记波次开始

# 显示消息
# @param message: 要显示的消息内容
func show_message(message: String):
	if message_label:
		message_label.text = message  # 设置消息内容
		message_timer = MESSAGE_DURATION  # 重置消息计时器

# 处理游戏胜利
func _on_game_won():
	var game_won_label = Label.new()  # 创建胜利标签
	game_won_label.text = "胜利！"
	game_won_label.position = Vector2(get_viewport().size / 2)  # 居中显示
	add_child(game_won_label)  # 添加到节点树
	if wave_progress:
		wave_progress.value = 0.0  # 重置进度条

# 返回主菜单
func _on_return_to_main_menu():
	var global = get_node("/root/Global")  # 获取 Global 单例
	if global:
		global.reset_game()  # 重置游戏状态
	var main_menu_path = "res://main_menu/main_menu.tscn"
	if ResourceLoader.exists(main_menu_path):
		get_tree().change_scene_to_file(main_menu_path)  # 切换到主菜单
	else:
		printerr("错误：主菜单场景 ", main_menu_path, " 不存在！")  # 如果主菜单缺失，打印错误

# 处理输入事件
func _input(event):
	if event is InputEventKey and event.is_action_pressed("ui_cancel") and skill_tree_panel.visible:
		hide_skill_tree()  # 如果按下取消键且技能树可见，隐藏技能树
		get_viewport().set_input_as_handled()  # 标记输入已处理

# 创建技能树面板
func create_skill_tree_panel():
	skill_tree_panel = Panel.new()  # 创建技能树面板
	skill_tree_panel.size = Vector2(200, 400)  # 设置面板尺寸
	var viewport_size = get_viewport().size
	var panel_pos = Vector2(
		viewport_size.x,
		(viewport_size.y - skill_tree_panel.size.y) / 2
	)  # 设置初始位置（屏幕右侧）
	skill_tree_panel.position = panel_pos
	skill_tree_panel.visible = false  # 初始隐藏
	add_child(skill_tree_panel)  # 添加到节点树

# 显示技能树
# @param node: 选中的节点（炮塔或建筑）
func show_skill_tree(node: Node2D):
	hide_skill_tree()  # 隐藏现有技能树
	for child in skill_tree_panel.get_children():
		child.queue_free()  # 清空面板子节点

	if node.is_in_group("turrets"):
		var script_path = node.get_script().resource_path.get_file() if node.get_script() else ""
		if script_path == "turret2.gd":
			selected_turret = null
			selected_turret2 = node
			selected_building = null
			create_turret2_skill_tree()  # 创建 turret2 技能树
		elif script_path == "turret1.gd":
			selected_turret = node
			selected_turret2 = null
			selected_building = null
			create_turret1_skill_tree()  # 创建 turret1 技能树
		else:
			selected_turret = node
			selected_turret2 = null
			selected_building = null
			create_turret_skill_tree()  # 创建通用炮塔技能树
	elif node.is_in_group("buildings"):
		selected_turret = null
		selected_turret2 = null
		selected_building = node
		create_building_skill_tree()  # 创建建筑技能树
	else:
		push_error("未知节点类型，无法显示技能树！")  # 如果节点类型未知，打印错误
		return

	skill_tree_panel.visible = true  # 显示面板
	var viewport_size = get_viewport().size
	var open_pos = Vector2(
		viewport_size.x - skill_tree_panel.size.x - 20,
		(viewport_size.y - skill_tree_panel.size.y) / 2
	)  # 计算打开位置
	var tween = create_tween()  # 创建动画
	tween.tween_property(skill_tree_panel, "position:x", open_pos.x, PANEL_ANIMATION_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)  # 平滑打开

	update_skill_tree_ui()  # 更新技能树 UI

# 创建通用炮塔技能树
func create_turret_skill_tree():
	var branch1_label = Label.new()
	branch1_label.text = "攻击范围"  # 分支1：攻击范围
	branch1_label.position = Vector2(10, 10)
	skill_tree_panel.add_child(branch1_label)

	var branch1_button = Button.new()
	branch1_button.text = "升级 (%d/3)" % (selected_turret.branch1_level if selected_turret else 0)
	branch1_button.position = Vector2(10, 40)
	skill_tree_panel.add_child(branch1_button)

	var branch2_label = Label.new()
	branch2_label.text = "攻击伤害"  # 分支2：攻击伤害
	branch2_label.position = Vector2(10, 80)
	skill_tree_panel.add_child(branch2_label)

	var branch2_button = Button.new()
	branch2_button.text = "升级 (%d/3)" % (selected_turret.branch2_level if selected_turret else 0)
	branch2_button.position = Vector2(10, 110)
	skill_tree_panel.add_child(branch2_button)

	var branch3_label = Label.new()
	branch3_label.text = "冷却减少"  # 分支3：冷却减少
	branch3_label.position = Vector2(10, 150)
	skill_tree_panel.add_child(branch3_label)

	var branch3_button = Button.new()
	branch3_button.text = "升级 (%d/3)" % (selected_turret.branch3_level if selected_turret else 0)
	branch3_button.position = Vector2(10, 180)
	skill_tree_panel.add_child(branch3_button)

	var delete_button = Button.new()
	delete_button.text = "删除炮塔"  # 删除炮塔按钮
	delete_button.position = Vector2(10, 220)
	delete_button.connect("pressed", _on_delete_turret_pressed)
	skill_tree_panel.add_child(delete_button)

# 创建 turret1 技能树
func create_turret1_skill_tree():
	var branch1_label = Label.new()
	branch1_label.text = "子弹伤害"  # 分支1：子弹伤害
	branch1_label.position = Vector2(10, 10)
	skill_tree_panel.add_child(branch1_label)

	var branch1_button = Button.new()
	branch1_button.text = "升级 (%d/3)" % (selected_turret.branch1_level if selected_turret else 0)
	branch1_button.position = Vector2(10, 40)
	branch1_button.connect("pressed", _on_turret1_branch1_upgrade_pressed)  # 连接升级信号
	skill_tree_panel.add_child(branch1_button)

	var branch2_label = Label.new()
	branch2_label.text = "穿透数量"  # 分支2：穿透数量
	branch2_label.position = Vector2(10, 80)
	skill_tree_panel.add_child(branch2_label)

	var branch2_button = Button.new()
	branch2_button.text = "升级 (%d/3)" % (selected_turret.branch2_level if selected_turret else 0)
	branch2_button.position = Vector2(10, 110)
	branch2_button.connect("pressed", _on_turret1_branch2_upgrade_pressed)  # 连接升级信号
	skill_tree_panel.add_child(branch2_button)

	var branch3_label = Label.new()
	branch3_label.text = "冷却减少"  # 分支3：冷却减少
	branch3_label.position = Vector2(10, 150)
	skill_tree_panel.add_child(branch3_label)

	var branch3_button = Button.new()
	branch3_button.text = "升级 (%d/3)" % (selected_turret.branch3_level if selected_turret else 0)
	branch3_button.position = Vector2(10, 180)
	branch3_button.connect("pressed", _on_turret1_branch3_upgrade_pressed)  # 连接升级信号
	skill_tree_panel.add_child(branch3_button)

	var delete_button = Button.new()
	delete_button.text = "删除炮塔"  # 删除炮塔按钮
	delete_button.position = Vector2(10, 220)
	delete_button.connect("pressed", _on_delete_turret_pressed)
	skill_tree_panel.add_child(delete_button)

# 创建 turret2 技能树
func create_turret2_skill_tree():
	var branch1_label = Label.new()
	branch1_label.text = "子弹数量"  # 分支1：子弹数量
	branch1_label.position = Vector2(10, 10)
	skill_tree_panel.add_child(branch1_label)

	var branch1_button = Button.new()
	branch1_button.text = "升级 (%d/3)" % (selected_turret2.branch1_level if selected_turret2 else 0)
	branch1_button.position = Vector2(10, 40)
	branch1_button.connect("pressed", _on_turret2_branch1_upgrade_pressed)  # 连接升级信号
	skill_tree_panel.add_child(branch1_button)

	var branch2_label = Label.new()
	branch2_label.text = "攻击伤害"  # 分支2：攻击伤害
	branch2_label.position = Vector2(10, 80)
	skill_tree_panel.add_child(branch2_label)

	var branch2_button = Button.new()
	branch2_button.text = "升级 (%d/3)" % (selected_turret2.branch2_level if selected_turret2 else 0)
	branch2_button.position = Vector2(10, 110)
	branch2_button.connect("pressed", _on_turret2_branch2_upgrade_pressed)  # 连接升级信号
	skill_tree_panel.add_child(branch2_button)

	var branch3_label = Label.new()
	branch3_label.text = "冷却减少"  # 分支3：冷却减少
	branch3_label.position = Vector2(10, 150)
	skill_tree_panel.add_child(branch3_label)

	var branch3_button = Button.new()
	branch3_button.text = "升级 (%d/3)" % (selected_turret2.branch3_level if selected_turret2 else 0)
	branch3_button.position = Vector2(10, 180)
	branch3_button.connect("pressed", _on_turret2_branch3_upgrade_pressed)  # 连接升级信号
	skill_tree_panel.add_child(branch3_button)

	var delete_button = Button.new()
	delete_button.text = "删除炮塔"  # 删除炮塔按钮
	delete_button.position = Vector2(10, 220)
	delete_button.connect("pressed", _on_delete_turret2_pressed)
	skill_tree_panel.add_child(delete_button)

# 创建建筑技能树
func create_building_skill_tree():
	var branch1_label = Label.new()
	branch1_label.text = "每秒加钱"  # 分支1：每秒加钱
	branch1_label.position = Vector2(10, 10)
	skill_tree_panel.add_child(branch1_label)

	var branch1_button = Button.new()
	branch1_button.text = "升级 (%d/3)" % (selected_building.branch1_level if selected_building else 0)
	branch1_button.position = Vector2(10, 40)
	branch1_button.connect("pressed", _on_building_branch1_upgrade_pressed)  # 连接升级信号
	skill_tree_panel.add_child(branch1_button)

	var branch2_label = Label.new()
	branch2_label.text = "基地血量提升"  # 分支2：基地血量提升
	branch2_label.position = Vector2(10, 80)
	skill_tree_panel.add_child(branch2_label)

	var branch2_button = Button.new()
	branch2_button.text = "升级 (%d/3)" % (selected_building.branch2_level if selected_building else 0)
	branch2_button.position = Vector2(10, 110)
	branch2_button.connect("pressed", _on_building_branch2_upgrade_pressed)  # 连接升级信号
	skill_tree_panel.add_child(branch2_button)

	var branch3_label = Label.new()
	branch3_label.text = "加钱冷却减少"  # 分支3：加钱冷却减少
	branch3_label.position = Vector2(10, 150)
	skill_tree_panel.add_child(branch3_label)

	var branch3_button = Button.new()
	branch3_button.text = "升级 (%d/3)" % (selected_building.branch3_level if selected_building else 0)
	branch3_button.position = Vector2(10, 180)
	branch3_button.connect("pressed", _on_building_branch3_upgrade_pressed)  # 连接升级信号
	skill_tree_panel.add_child(branch3_button)

# 隐藏技能树
func hide_skill_tree():
	if skill_tree_panel.visible:
		var viewport_size = get_viewport().size
		var closed_pos = Vector2(
			viewport_size.x,
			(viewport_size.y - skill_tree_panel.size.y) / 2
		)  # 计算关闭位置
		var tween = create_tween()  # 创建动画
		tween.tween_property(skill_tree_panel, "position:x", closed_pos.x, PANEL_ANIMATION_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)  # 平滑关闭
		tween.tween_callback(func(): skill_tree_panel.visible = false)  # 动画完成后隐藏

# 更新技能树 UI
func update_skill_tree_ui():
	var global = get_node("/root/Global")
	if not global:
		push_error("未找到全局节点！")  # 如果 Global 缺失，打印错误
		return
	var current_score = global.score  # 获取当前分数

	# 更新 turret1 技能树按钮
	if selected_turret and selected_turret.get_script().resource_path.get_file() == "turret1.gd":
		var branch1_button = skill_tree_panel.get_child(1)
		var branch2_button = skill_tree_panel.get_child(3)
		var branch3_button = skill_tree_panel.get_child(5)
		branch1_button.text = "升级 (%d/3)%s" % [selected_turret.branch1_level, " - %d" % Global.UPGRADE_COST if current_score >= Global.UPGRADE_COST and selected_turret.branch1_level < 3 else ""]
		branch2_button.text = "升级 (%d/3)%s" % [selected_turret.branch2_level, " - %d" % Global.UPGRADE_COST if current_score >= Global.UPGRADE_COST and selected_turret.branch2_level < 3 else ""]
		branch3_button.text = "升级 (%d/3)%s" % [selected_turret.branch3_level, " - %d" % Global.UPGRADE_COST if current_score >= Global.UPGRADE_COST and selected_turret.branch3_level < 3 else ""]
	# 更新 turret2 技能树按钮
	elif selected_turret2:
		var branch1_button = skill_tree_panel.get_child(1)
		var branch2_button = skill_tree_panel.get_child(3)
		var branch3_button = skill_tree_panel.get_child(5)
		branch1_button.text = "升级 (%d/3)%s" % [selected_turret2.branch1_level, " - %d" % Global.UPGRADE_COST if current_score >= Global.UPGRADE_COST and selected_turret2.branch1_level < 3 else ""]
		branch2_button.text = "升级 (%d/3)%s" % [selected_turret2.branch2_level, " - %d" % Global.UPGRADE_COST if current_score >= Global.UPGRADE_COST and selected_turret2.branch2_level < 3 else ""]
		branch3_button.text = "升级 (%d/3)%s" % [selected_turret2.branch3_level, " - %d" % Global.UPGRADE_COST if current_score >= Global.UPGRADE_COST and selected_turret2.branch3_level < 3 else ""]
	# 更新建筑技能树按钮
	elif selected_building:
		var branch1_button = skill_tree_panel.get_child(1)
		var branch2_button = skill_tree_panel.get_child(3)
		var branch3_button = skill_tree_panel.get_child(5)
		branch1_button.text = "升级 (%d/3)%s" % [selected_building.branch1_level, " - %d" % Global.UPGRADE_COST if current_score >= Global.UPGRADE_COST and selected_building.branch1_level < 3 else ""]
		branch2_button.text = "升级 (%d/3)%s" % [selected_building.branch2_level, " - %d" % Global.UPGRADE_COST if current_score >= Global.UPGRADE_COST and selected_building.branch2_level < 3 else ""]
		branch3_button.text = "升级 (%d/3)%s" % [selected_building.branch3_level, " - %d" % Global.UPGRADE_COST if current_score >= Global.UPGRADE_COST and selected_building.branch3_level < 3 else ""]
	else:
		push_warning("未选择任何对象，跳过技能树更新")  # 如果未选择对象，打印警告

# 升级 turret1 分支1（子弹伤害）
func _on_turret1_branch1_upgrade_pressed():
	var global = get_node("/root/Global")
	if selected_turret and selected_turret.get_script().resource_path.get_file() == "turret1.gd" and global and global.score >= Global.UPGRADE_COST and selected_turret.branch1_level < 3:
		selected_turret.upgrade_branch1()  # 升级分支1
		global.score -= Global.UPGRADE_COST  # 扣除升级费用
		update_skill_tree_ui()  # 更新 UI

# 升级 turret1 分支2（穿透数量）
func _on_turret1_branch2_upgrade_pressed():
	var global = get_node("/root/Global")
	if selected_turret and selected_turret.get_script().resource_path.get_file() == "turret1.gd" and global and global.score >= Global.UPGRADE_COST and selected_turret.branch2_level < 3:
		selected_turret.upgrade_branch2()  # 升级分支2
		global.score -= Global.UPGRADE_COST  # 扣除升级费用
		update_skill_tree_ui()  # 更新 UI

# 升级 turret1 分支3（冷却减少）
func _on_turret1_branch3_upgrade_pressed():
	var global = get_node("/root/Global")
	if selected_turret and selected_turret.get_script().resource_path.get_file() == "turret1.gd" and global and global.score >= Global.UPGRADE_COST and selected_turret.branch3_level < 3:
		selected_turret.upgrade_branch3()  # 升级分支3
		global.score -= Global.UPGRADE_COST  # 扣除升级费用
		update_skill_tree_ui()  # 更新 UI

# 升级 turret2 分支1（子弹数量）
func _on_turret2_branch1_upgrade_pressed():
	var global = get_node("/root/Global")
	if selected_turret2 and global and global.score >= Global.UPGRADE_COST and selected_turret2.branch1_level < 3:
		selected_turret2.upgrade_branch1()  # 升级分支1
		global.score -= Global.UPGRADE_COST  # 扣除升级费用
		update_skill_tree_ui()  # 更新 UI

# 升级 turret2 分支2（攻击伤害）
func _on_turret2_branch2_upgrade_pressed():
	var global = get_node("/root/Global")
	if selected_turret2 and global and global.score >= Global.UPGRADE_COST and selected_turret2.branch2_level < 3:
		selected_turret2.upgrade_branch2()  # 升级分支2
		global.score -= Global.UPGRADE_COST  # 扣除升级费用
		update_skill_tree_ui()  # 更新 UI

# 升级 turret2 分支3（冷却减少）
func _on_turret2_branch3_upgrade_pressed():
	var global = get_node("/root/Global")
	if selected_turret2 and global and global.score >= Global.UPGRADE_COST and selected_turret2.branch3_level < 3:
		selected_turret2.upgrade_branch3()  # 升级分支3
		global.score -= Global.UPGRADE_COST  # 扣除升级费用
		update_skill_tree_ui()  # 更新 UI

# 删除 turret1 炮塔
func _on_delete_turret_pressed():
	if selected_turret:
		var turret_placer = get_tree().get_first_node_in_group("turret_placer")  # 获取炮塔放置器
		if turret_placer:
			turret_placer.free_turret_zone(selected_turret.global_position)  # 释放区域
		selected_turret.queue_free()  # 删除炮塔
		hide_skill_tree()  # 隐藏技能树
		var global = get_node("/root/Global")
		if global:
			global.score += 5  # 返还部分分数

# 删除 turret2 炮塔
func _on_delete_turret2_pressed():
	if selected_turret2:
		var turret_placer = get_tree().get_first_node_in_group("turret_placer")  # 获取炮塔放置器
		if turret_placer:
			turret_placer.free_turret_zone(selected_turret2.global_position)  # 释放区域
		selected_turret2.queue_free()  # 删除炮塔
		hide_skill_tree()  # 隐藏技能树
		var global = get_node("/root/Global")
		if global:
			global.score += 5  # 返还部分分数

# 升级建筑分支1（每秒加钱）
func _on_building_branch1_upgrade_pressed():
	var global = get_node("/root/Global")
	if selected_building and global and global.score >= Global.UPGRADE_COST and selected_building.branch1_level < 3:
		selected_building.upgrade_branch1()  # 升级分支1
		global.score -= Global.UPGRADE_COST  # 扣除升级费用
		update_skill_tree_ui()  # 更新 UI

# 升级建筑分支2（基地血量提升）
func _on_building_branch2_upgrade_pressed():
	var global = get_node("/root/Global")
	if selected_building and global and global.score >= Global.UPGRADE_COST and selected_building.branch2_level < 3:
		selected_building.upgrade_branch2()  # 升级分支2
		global.score -= Global.UPGRADE_COST  # 扣除升级费用
		update_skill_tree_ui()  # 更新 UI

# 升级建筑分支3（加钱冷却减少）
func _on_building_branch3_upgrade_pressed():
	var global = get_node("/root/Global")
	if selected_building and global and global.score >= Global.UPGRADE_COST and selected_building.branch3_level < 3:
		selected_building.upgrade_branch3()  # 升级分支3
		global.score -= Global.UPGRADE_COST  # 扣除升级费用
		update_skill_tree_ui()  # 更新 UI

# 处理全局分数变化
# @param new_score: 新分数（未使用）
func _on_global_score_changed(new_score):
	update_score_label()  # 更新分数显示

# 更新分数标签
func update_score_label():
	var global = get_node("/root/Global")
	if global and score_label:
		score_label.text = "金钱: %d" % global.score  # 更新分数文本
	else:
		push_error("未找到全局节点或 ScoreLabel 节点！")  # 如果缺失节点，打印错误

# 清空消息
func clear_message():
	if message_label:
		message_label.text = ""  # 清空消息文本
	message_timer = 0.0  # 重置计时器
