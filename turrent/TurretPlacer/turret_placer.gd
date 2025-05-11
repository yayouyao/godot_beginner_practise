extends Node2D

# 可配置属性
@export var normal_turret_scene: PackedScene  # 普通炮塔场景，需在编辑器中指定
@export var heavy_turret_scene: PackedScene  # 重型炮塔场景，需在编辑器中指定
@export var push_turret_scene: PackedScene  # 推力炮塔场景，需在编辑器中指定
@export var ui_scene: PackedScene  # UI 场景，需在编辑器中指定
@export var button_handler_scene: PackedScene  # 按钮处理器场景，需在编辑器中指定
@export var normal_turret_cost: int = 50  # 普通炮塔放置成本
@export var heavy_turret_cost: int = 50  # 重型炮塔放置成本
@export var push_turret_cost: int = 50  # 推力炮塔放置成本
@onready var sound_player = $SoundPlayer  # 放置音效播放器

# 内部变量
var turret_count: int = 0  # 已放置的炮塔数量
var selected_turret: PackedScene = null  # 当前选中的炮塔场景
var preview: Node = null  # 炮塔预览实例
var ui: CanvasLayer = null  # UI 引用
var button_handler: Node = null  # 按钮处理器引用
var _is_initialized: bool = false  # 是否完成初始化
var turret_to_zone: Dictionary = {}  # 炮塔与放置区域的映射

# 信号
signal score_changed(new_score: int)  # 当分数变化时发出，传递变化值

# 节点初始化时调用
func _ready():
	# 实例化按钮处理器
	if button_handler_scene:
		button_handler = button_handler_scene.instantiate()
		add_child(button_handler)  # 添加到节点树
	
	# 检查炮塔场景是否设置
	if not normal_turret_scene:
		printerr("错误: 普通炮塔场景未设置！")  # 如果普通炮塔场景缺失，打印错误
	if not heavy_turret_scene:
		printerr("错误: 重型炮塔场景未设置！")  # 如果重型炮塔场景缺失，打印错误
	if not push_turret_scene:
		printerr("错误: 推力炮塔场景未设置！")  # 如果推力炮塔场景缺失，打印错误
	
	add_to_group("turret_placer")  # 添加到 turret_placer 组
	_is_initialized = true  # 标记初始化完成

# 处理输入事件
func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var mouse_pos = get_global_mouse_position()  # 获取鼠标位置
		var is_over_button = false  # 是否点击在按钮上
		if button_handler:
			# 检查是否点击在炮塔选择按钮上
			var normal_button = button_handler.get_node_or_null("TurretCard")
			var heavy_button = button_handler.get_node_or_null("HeavyTurretCard")
			var push_button = button_handler.get_node_or_null("PushTurretCard")
			if normal_button and normal_button.get_global_rect().has_point(mouse_pos):
				is_over_button = true
			if heavy_button and heavy_button.get_global_rect().has_point(mouse_pos):
				is_over_button = true
			if push_button and push_button.get_global_rect().has_point(mouse_pos):
				is_over_button = true
		
		if not is_over_button:
			var zone_manager = get_zone_manager_at_position(mouse_pos)  # 获取鼠标位置的放置区域
			if selected_turret:
				place_turret(zone_manager)  # 尝试放置炮塔

# 当炮塔被选中时触发
# @param turret_scene: 选中的炮塔场景
func _on_turret_selected(turret_scene: PackedScene):
	print("turret_placer.gd: 收到 turret_selected 信号，turret_scene: ", turret_scene)  # 调试信息
	if not turret_scene:
		if preview:
			preview.queue_free()  # 清除预览
			preview = null
		selected_turret = null  # 重置选中炮塔
		print("turret_placer.gd: 重置 selected_turret: ", selected_turret)  # 调试信息
		return

	if preview:
		preview.queue_free()  # 清除旧预览
		preview = null

	preview = turret_scene.instantiate()  # 创建新预览
	preview.modulate.a = 0.5  # 设置预览半透明
	preview.remove_from_group("turrets")  # 移除预览的 turrets 组
	if turret_scene == push_turret_scene:
		preview.is_preview = true  # 标记推力炮塔预览
		print("turret_placer.gd: 设置 push_turret 预览图 is_preview = true")  # 调试信息
	else:
		print("turret_placer.gd: 非 push_turret，无需设置 is_preview")  # 调试信息
	add_child(preview)  # 添加预览到节点树
	preview.visible = true  # 显示预览

	selected_turret = turret_scene  # 设置选中炮塔
	print("turret_placer.gd: 设置 selected_turret: ", selected_turret)  # 调试信息

# 获取指定位置的放置区域管理器
# @param pos: 全局坐标
# @return: 包含指定点的 PlacementZoneManager 或 null
func get_zone_manager_at_position(pos: Vector2) -> PlacementZoneManager:
	for node in get_tree().get_nodes_in_group("placement_zones"):
		if node is PlacementZoneManager and node.is_point_in_zone(pos):
			return node  # 返回包含该点的区域管理器
	return null

# 放置炮塔
# @param zone_manager: 目标放置区域管理器
func place_turret(zone_manager: PlacementZoneManager):
	sound_player.play()  # 播放放置音效
	if !_is_initialized:
		push_error("turret_placer.gd: 系统未初始化完成！")  # 如果未初始化，打印错误
		return
	if not selected_turret:
		if ui:
			ui.show_message("请先选择炮塔类型！")  # 如果未选择炮塔，显示提示
		return
	if not zone_manager:
		if ui:
			ui.show_message("未找到可放置区域！")  # 如果未找到区域，显示提示
		return
	if not ui:
		printerr("错误: UI 未设置！")  # 如果 UI 缺失，打印错误
		return
	if not button_handler:
		printerr("错误: ButtonHandler 未设置！")  # 如果按钮处理器缺失，打印错误
		return

	if not zone_manager.can_place_in_zone():
		if ui:
			ui.show_message("该区域已被占用或不在可放置区域内！")  # 如果区域不可用，显示提示
		return

	# 确定炮塔类型和成本
	var turret_cost: int
	var turret_type: String
	if selected_turret == normal_turret_scene:
		turret_cost = normal_turret_cost
		turret_type = "普通"
	elif selected_turret == heavy_turret_scene:
		turret_cost = heavy_turret_cost
		turret_type = "重型"
	else:
		turret_cost = push_turret_cost
		turret_type = "推力"

	var global = get_node("/root/Global")  # 获取 Global 单例
	if not global:
		printerr("错误: 未找到 Global 节点！")  # 如果 Global 缺失，打印错误
		return
	
	if global.score < turret_cost:
		if ui:
			ui.show_message("分数不足，无法放置%s炮塔！需要 %d 分，当前 %d 分" % [turret_type, turret_cost, global.score])  # 分数不足时显示提示
		return

	global.score -= turret_cost  # 扣除分数
	score_changed.emit(-turret_cost)  # 发出分数变化信号

	var turret = selected_turret.instantiate()  # 实例化炮塔
	turret.position = zone_manager.get_zone_center()  # 设置炮塔位置
	turret.modulate.a = 1.0  # 设置为完全不透明
	get_tree().current_scene.add_child(turret)  # 添加到场景
	turret_count += 1  # 增加炮塔计数

	# 记录非推力炮塔的区域占用
	if selected_turret != push_turret_scene:
		zone_manager.occupy_zone()  # 标记区域为占用
		turret_to_zone[turret] = {
			"zone_manager": zone_manager,
			"zone_id": zone_manager.zone_id,
			"position": turret.global_position
		}  # 记录炮塔与区域的映射

	if preview:
		preview.queue_free()  # 清除预览
		preview = null
	selected_turret = null  # 重置选中炮塔
	if button_handler:
		button_handler.deselect_button()  # 取消按钮选中状态

# 每帧处理
func _process(_delta):
	if preview:
		var mouse_pos = get_global_mouse_position()  # 获取鼠标位置
		var zone_manager = get_zone_manager_at_position(mouse_pos)  # 获取鼠标位置的区域
		if zone_manager != null and zone_manager.can_place_in_zone():
			preview.global_position = zone_manager.get_zone_center()  # 预览对齐区域中心
			preview.visible = true  # 显示预览
		else:
			preview.global_position = mouse_pos  # 预览跟随鼠标
			preview.visible = true  # 显示预览

# 设置 UI
# @param ui_node: UI 节点
func set_ui(ui_node: CanvasLayer):
	ui = ui_node  # 设置 UI 引用

# 设置按钮处理器
# @param handler: 按钮处理器节点
func set_button_handler(handler: Node2D):
	button_handler = handler
	if button_handler:
		button_handler.turret_selected.connect(_on_turret_selected)  # 连接炮塔选择信号
	else:
		printerr("错误: ButtonHandler 无效，无法连接信号！")  # 如果处理器无效，打印错误

# 释放炮塔占用的区域
# @param turret_position: 炮塔位置
func free_turret_zone(turret_position: Vector2):
	for turret in turret_to_zone.keys():
		var data = turret_to_zone[turret]
		if data["position"].distance_to(turret_position) < 1.0:
			var zone_manager = data["zone_manager"]
			var expected_zone_id = data["zone_id"]
			if zone_manager and is_instance_valid(zone_manager) and zone_manager.zone_id == expected_zone_id:
				zone_manager.free_zone()  # 释放区域
				turret_count -= 1  # 减少炮塔计数
				turret_to_zone.erase(turret)  # 移除映射
				return
