extends Node2D

# 可配置属性
@export var base_scene: PackedScene  # 基地场景，需在编辑器中指定
@export var enemy_spawner_scene: PackedScene  # 敌人生成器场景，需在编辑器中指定
@export var turret_placer_scene: PackedScene  # 炮塔放置器场景，需在编辑器中指定
@export var button_handler_scene: PackedScene  # 按钮处理器场景，需在编辑器中指定
@export var ui_scene: PackedScene  # UI 场景，需在编辑器中指定
@export var damage_number: PackedScene  # 伤害数字场景，需在编辑器中指定
@export var tutorial_dialog_scene: PackedScene  # 教程对话框场景，需在编辑器中指定

# 菜单相关节点引用
@onready var pause_layer: CanvasLayer = $PauseLayer  # 暂停层
@onready var pause_menu: Control = $PauseLayer/PauseMenu  # 暂停菜单
@onready var pause_buttons: VBoxContainer = $PauseLayer/PauseMenu/PauseButtons  # 暂停菜单按钮容器
@onready var restart_button: Button = $PauseLayer/PauseMenu/PauseButtons/RestartButton  # 重启按钮
@onready var main_menu_button: Button = $PauseLayer/PauseMenu/PauseButtons/MainMenuButton  # 主菜单按钮

# 内部变量
var is_menu_visible: bool = false  # 暂停菜单是否可见
var ui: UI  # UI 实例
var base  # 基地实例
var camera: Camera2D  # 摄像机引用
var screen_width: float  # 屏幕宽度
var screen_height: float  # 屏幕高度
var wave_timer: float = 0.0  # 波次计时器
var wave_times: Array[float] = [5.0, 120.0, 360.0]  # 各波次开始时间（秒）
var spawner  # 敌人生成器实例
var tutorial_dialog  # 教程对话框实例
var mini_map  # 小地图实例
var button_handler  # 按钮处理器实例

# 教程状态枚举
enum TutorialState {
	START,              # 教程开始
	MOUSE_CLICK,        # 等待鼠标点击
	MINI_MAP_HIGHLIGHT, # 高亮小地图
	MINI_MAP_MOVED,     # 等待小地图移动
	BUILDING_HIGHLIGHT, # 高亮建筑
	ENEMY_SPAWN,        # 等待敌人生成
	WAVE_PROGRESS_HIGHLIGHT, # 高亮波次进度条
	BUTTON_CLICK,       # 等待按钮点击
	BASE_ATTACKED,      # 等待基地受攻击
	COMPLETE            # 教程完成
}
var tutorial_state: TutorialState = TutorialState.START  # 当前教程状态
var is_tutorial_active: bool = false  # 教程是否激活

# 节点初始化时调用
func _ready():
	# 获取 Global 单例并重置游戏状态
	var global = get_node("/root/Global")
	if global:
		global.reset_game()  # 重置全局状态
	else:
		printerr("错误：未找到 Global 单例！")  # 如果 Global 缺失，打印错误

	# 获取屏幕尺寸
	var viewport = get_viewport()
	if viewport:
		screen_width = viewport.size.x  # 设置屏幕宽度
		screen_height = viewport.size.y  # 设置屏幕高度
	else:
		screen_width = 1920  # 默认宽度
		screen_height = 1080  # 默认高度

	# 设置摄像机
	camera = get_viewport().get_camera_2d()
	if not camera:
		printerr("错误：未找到 Camera2D！")  # 如果摄像机缺失，打印错误
	else:
		# 设置摄像机边界和位置
		camera.limit_left = -0.5 * screen_width
		camera.limit_right = 2.0 * screen_width
		camera.limit_top = 0
		camera.limit_bottom = screen_height
		var map_width = camera.limit_right - camera.limit_left
		camera.position = Vector2(camera.limit_left + map_width / 2, screen_height / 2.0)

	# 初始化暂停菜单
	if pause_layer and pause_menu and pause_buttons:
		pause_layer.visible = false  # 隐藏暂停层
		pause_menu.visible = false  # 隐藏暂停菜单
		pause_buttons.visible = false  # 隐藏暂停按钮
		adapt_pause_buttons()  # 调整按钮布局

	# 连接暂停菜单按钮信号
	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)  # 连接重启按钮
	if main_menu_button:
		main_menu_button.pressed.connect(_on_main_menu_pressed)  # 连接主菜单按钮

	# 实例化 UI
	ui = ui_scene.instantiate()
	if ui:
		add_child(ui)  # 添加 UI 到节点树

	# 实例化基地
	base = base_scene.instantiate()
	if base and is_instance_valid(base):
		add_child(base)  # 添加基地到节点树
		base.health_changed.connect(_on_base_health_changed)  # 连接基地血量变化信号
		base.destroyed.connect(_on_base_destroyed)  # 连接基地销毁信号
		if global:
			global.player_health = base.health if "health" in base else 100  # 设置全局基地血量

	# 实例化敌人生成器
	spawner = enemy_spawner_scene.instantiate()
	if spawner:
		add_child(spawner)  # 添加生成器到节点树
		if ui:
			var connection_result = spawner.show_wave_message.connect(ui.show_message)  # 连接波次消息信号

	# 实例化炮塔放置器
	var placer = turret_placer_scene.instantiate()
	if placer:
		add_child(placer)  # 添加放置器到节点树
		if ui:
			placer.score_changed.connect(_on_score_changed)  # 连接分数变化信号
			placer.set_ui(ui)  # 设置 UI 引用

	# 实例化按钮处理器
	button_handler = button_handler_scene.instantiate()
	if button_handler:
		add_child(button_handler)  # 添加按钮处理器到节点树
		if ui:
			button_handler.set_ui(ui)  # 设置 UI 引用
			placer.set_button_handler(button_handler)  # 设置按钮处理器引用
			button_handler.turret_selected.connect(_on_turret_selected)  # 连接炮塔选择信号

	# 实例化教程对话框
	if tutorial_dialog_scene:
		tutorial_dialog = tutorial_dialog_scene.instantiate()
		add_child(tutorial_dialog)  # 添加对话框到节点树
		tutorial_dialog.tutorial_completed.connect(_on_tutorial_completed)  # 连接教程完成信号

	# 获取小地图
	mini_map = get_tree().get_first_node_in_group("mini_map")
	if not mini_map:
		printerr("错误：未找到 MiniMap 节点！请确保 MiniMap 节点已加入 'mini_map' 组。")  # 如果小地图缺失，打印错误

	# 为所有建筑设置 UI
	for building in get_tree().get_nodes_in_group("buildings"):
		if ui:
			building.set_ui(ui)  # 设置建筑的 UI 引用

	# 为已有敌人连接信号
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy:
			enemy.enemy_killed.connect(add_score)  # 连接敌人击杀信号
			enemy.damaged.connect(_on_enemy_damaged)  # 连接敌人受损信号

	get_tree().node_added.connect(_on_node_added)  # 连接节点添加信号

	# 检查是否需要显示教程
	if global and not global.is_tutorial_completed():
		start_tutorial()  # 启动教程
	else:
		get_tree().paused = false  # 取消暂停
		Engine.time_scale = 1.0  # 设置正常游戏速度

	# 连接 Global 的胜利信号
	if global:
		global.game_victory.connect(_on_game_victory)  # 连接游戏胜利信号

# 启动教程
func start_tutorial():
	is_tutorial_active = true  # 标记教程激活
	Engine.time_scale = 0.1  # 减慢游戏速度
	get_tree().paused = false  # 取消暂停
	tutorial_state = TutorialState.START  # 设置初始教程状态
	update_tutorial_state()  # 更新教程状态

# 更新教程状态
func update_tutorial_state():
	match tutorial_state:
		TutorialState.START:
			tutorial_dialog.show_message(0)  # 显示第一条教程消息
			tutorial_state = TutorialState.MOUSE_CLICK  # 进入等待鼠标点击状态
		TutorialState.MINI_MAP_HIGHLIGHT:
			tutorial_dialog.show_message(1)  # 显示第二条教程消息（小地图）
			tutorial_state = TutorialState.MINI_MAP_MOVED  # 进入等待小地图移动状态
		TutorialState.BUILDING_HIGHLIGHT:
			tutorial_dialog.show_message(2)  # 显示第三条教程消息（建筑）
			var building = get_tree().get_first_node_in_group("buildings")
			if building and building.sprite:
				highlight_node(building.sprite, 3.0)  # 高亮建筑3秒
			else:
				printerr("错误：未找到 building 或 building.sprite")  # 如果建筑缺失，打印错误
			Engine.time_scale = 1.0  # 恢复正常游戏速度
			tutorial_state = TutorialState.ENEMY_SPAWN  # 进入等待敌人生成状态
		TutorialState.WAVE_PROGRESS_HIGHLIGHT:
			tutorial_dialog.show_message(3)  # 显示第四条教程消息（波次进度）
			if ui and ui.wave_progress:
				highlight_node(ui.wave_progress, 3.0)  # 高亮波次进度条3秒
			else:
				printerr("错误：未找到 ui.wave_progress")  # 如果进度条缺失，打印错误
			tutorial_state = TutorialState.BUTTON_CLICK  # 进入等待按钮点击状态
		TutorialState.BUTTON_CLICK:
			tutorial_dialog.show_message(4)  # 显示第五条教程消息（按钮）
			tutorial_state = TutorialState.BASE_ATTACKED  # 进入等待基地受攻击状态
		TutorialState.BASE_ATTACKED:
			tutorial_dialog.show_message(6)  # 显示最后一条教程消息（基地保护）
			tutorial_state = TutorialState.COMPLETE  # 进入教程完成状态
		TutorialState.COMPLETE:
			is_tutorial_active = false  # 标记教程结束
			var global = get_node("/root/Global")
			if global:
				global.set_tutorial_completed(true)  # 设置全局教程完成状态
			tutorial_dialog.tutorial_completed.emit()  # 发出教程完成信号

# 小地图高亮完成时的回调（未使用）
func _on_mini_map_highlight_finished():
	if tutorial_state == TutorialState.MINI_MAP_HIGHLIGHT:
		tutorial_state = TutorialState.MINI_MAP_MOVED

# 高亮指定节点
# @param node: 要高亮的节点
# @param duration: 高亮持续时间（秒）
func highlight_node(node: Node, duration: float):
	if node:
		var tween = create_tween()  # 创建动画
		tween.set_loops(int(duration / 0.5))  # 设置循环次数
		tween.tween_property(node, "modulate", Color(1, 1, 0, 1), 0.25)  # 变为黄色高亮
		tween.tween_property(node, "modulate", Color(1, 1, 1, 1), 0.25)  # 恢复正常颜色
	else:
		printerr("错误：无法高亮节点，传入的 node 为 null")  # 如果节点无效，打印错误

# 处理输入事件
func _input(event):
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.is_echo():
		if ui and ui.skill_tree_panel and ui.skill_tree_panel.visible:
			return  # 如果技能树面板可见，忽略 ESC
		toggle_menu()  # 切换暂停菜单
	elif is_tutorial_active and tutorial_state == TutorialState.MOUSE_CLICK:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			tutorial_state = TutorialState.MINI_MAP_HIGHLIGHT  # 检测到鼠标点击，进入下一状态
			update_tutorial_state()  # 更新教程状态

# 每帧处理
func _process(delta: float):
	var global = get_node("/root/Global")
	if not global or global.game_over or global.victory:
		return  # 如果游戏结束或胜利，跳过处理

	if is_tutorial_active:
		if tutorial_state == TutorialState.MINI_MAP_MOVED:
			if camera and camera.position.x <= camera.limit_left + screen_width / 2.0 + 10:
				tutorial_state = TutorialState.BUILDING_HIGHLIGHT  # 检测到小地图移动，进入下一状态
				update_tutorial_state()
		elif tutorial_state == TutorialState.ENEMY_SPAWN:
			if get_tree().get_nodes_in_group("enemy").size() > 0:
				tutorial_state = TutorialState.WAVE_PROGRESS_HIGHLIGHT  # 检测到敌人生成，进入下一状态
				update_tutorial_state()

	# 更新波次
	if global.wave_count < wave_times.size():
		wave_timer += delta  # 增加波次计时器
		var next_wave_time = wave_times[global.wave_count]
		if wave_timer >= next_wave_time:
			global.increment_wave()  # 增加波次计数
			if spawner:
				spawner._on_wave_changed(global.wave_count)  # 通知生成器波次变化
			if global.wave_count == wave_times.size():
				wave_timer = 0.0  # 重置计时器

# 调整暂停菜单按钮布局
func adapt_pause_buttons():
	if pause_buttons:
		var button_width = screen_width * 0.3  # 按钮宽度为屏幕宽度的30%
		var button_height = screen_height * 0.1  # 按钮高度为屏幕高度的10%
		pause_buttons.custom_minimum_size = Vector2(button_width, button_height * 3)  # 设置最小尺寸
		pause_buttons.position = Vector2(
			(screen_width - button_width) / 2,
			(screen_height - button_height * 3) / 2
		)  # 居中按钮容器

# 切换暂停菜单显示状态
func toggle_menu():
	is_menu_visible = !is_menu_visible  # 切换菜单可见性
	if pause_layer and pause_menu and pause_buttons:
		pause_layer.visible = is_menu_visible  # 设置暂停层可见性
		pause_menu.visible = is_menu_visible  # 设置菜单可见性
		pause_buttons.visible = is_menu_visible  # 设置按钮可见性
		if is_menu_visible:
			adapt_pause_buttons()  # 调整按钮布局

# 当新节点添加时触发
func _on_node_added(node: Node):
	if node.is_in_group("enemy"):
		if !node.enemy_killed.is_connected(add_score):
			node.enemy_killed.connect(add_score)  # 连接敌人击杀信号
		if !node.damaged.is_connected(_on_enemy_damaged):
			node.damaged.connect(_on_enemy_damaged)  # 连接敌人受损信号

# 当敌人受到伤害时触发
func _on_enemy_damaged(damage: float, position: Vector2):
	if damage_number:
		var damage_text = damage_number.instantiate()  # 实例化伤害数字
		damage_text.position = position  # 设置位置
		add_child(damage_text)  # 添加到节点树
		await get_tree().process_frame  # 等待一帧
		damage_text.setup(damage, Color.RED)  # 设置伤害值和颜色

# 增加分数
func add_score(points: int):
	var global = get_node("/root/Global")
	if global:
		global.score += points  # 更新全局分数

# 当基地血量变化时触发
func _on_base_health_changed(new_health: float):
	var global = get_node("/root/Global")
	if global:
		global.player_health = int(new_health)  # 更新全局基地血量
	if is_tutorial_active and tutorial_state == TutorialState.BASE_ATTACKED and new_health < base.health:
		update_tutorial_state()  # 如果基地受攻击，更新教程状态

# 当基地被销毁时触发
func _on_base_destroyed(instance: Node):
	var global = get_node("/root/Global")
	if global:
		global.set_game_over()  # 设置游戏结束状态
	Engine.time_scale = 0.1  # 减慢游戏速度
	if not is_menu_visible:
		toggle_menu()  # 显示暂停菜单

# 当分数变化时触发
func _on_score_changed(new_score: int):
	var global = get_node("/root/Global")
	if global:
		global.score += new_score  # 更新全局分数
		print("分数更新:", global.score)  # 调试信息

# 当教程完成时触发
func _on_tutorial_completed():
	print("教程已完成")  # 调试信息

# 当游戏胜利时触发
func _on_game_victory():
	if ui:
		ui.show_victory()  # 显示胜利界面

# 当炮塔被选中时触发
func _on_turret_selected(turret_scene: PackedScene):
	if is_tutorial_active and tutorial_state == TutorialState.BUTTON_CLICK and turret_scene != null:
		update_tutorial_state()  # 如果选择炮塔，更新教程状态

# 节点销毁前处理
func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		cleanup()  # 清理资源

# 清理资源
func cleanup():
	for child in get_children():
		if child.is_in_group("damage_number"):
			child.queue_free()  # 销毁所有伤害数字节点

# 重启游戏
func _on_restart_pressed():
	var global = get_node("/root/Global")
	if global:
		global.reset_game()  # 重置全局状态
	is_menu_visible = false  # 隐藏菜单
	if pause_layer and pause_menu and pause_buttons:
		pause_layer.visible = false  # 隐藏暂停层
		pause_menu.visible = false  # 隐藏菜单
		pause_buttons.visible = false  # 隐藏按钮
	Engine.time_scale = 1.0  # 恢复正常游戏速度
	cleanup()  # 清理资源
	get_tree().reload_current_scene()  # 重新加载当前场景

# 返回主菜单
func _on_main_menu_pressed():
	var global = get_node("/root/Global")
	if global:
		global.reset_game()  # 重置全局状态
	is_menu_visible = false  # 隐藏菜单
	if pause_layer and pause_menu and pause_buttons:
		pause_layer.visible = false  # 隐藏暂停层
		pause_menu.visible = false  # 隐藏菜单
		pause_buttons.visible = false  # 隐藏按钮
	Engine.time_scale = 1.0  # 恢复正常游戏速度
	cleanup()  # 清理资源
	var main_menu_path = "res://main_menu/main_menu.tscn"
	if ResourceLoader.exists(main_menu_path):
		get_tree().change_scene_to_file(main_menu_path)  # 切换到主菜单场景

# 退出游戏（未在脚本中使用，但保留以备扩展）
func _on_quit_pressed():
	Engine.time_scale = 1.0  # 恢复正常游戏速度
	cleanup()  # 清理资源
	get_tree().quit()  # 退出游戏
