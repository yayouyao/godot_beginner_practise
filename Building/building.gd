extends Node2D

# 引用 Sprite2D、Area2D 和 SoundPlayer 节点
@onready var sprite: Sprite2D = $Sprite2D  # 引用建筑的 Sprite2D 节点，用于显示建筑外观
@onready var area: Area2D = $Area2D        # 引用 Area2D 节点，用于检测鼠标交互
@onready var sound_player = $SoundPlayer   # 引用 SoundPlayer 节点，用于播放交互音效

# UI 节点引用
var ui: CanvasLayer = null  # 引用 UI 节点（CanvasLayer），用于显示技能树和消息

# Q 弹动画参数
const BOUNCE_SCALE: float = 1.2 * 2.5  # 动画放大倍数，控制建筑点击时的弹跳效果
const BOUNCE_DURATION: float = 0.3     # 动画持续时间（秒），控制弹跳动画速度

# 升级参数
const BASE_AUTO_SCORE_INTERVAL: float = 1.0  # 基础自动得分间隔（秒），用于自动加分计时器

# 技能树等级
var branch1_level: int = 0  # 每秒加钱：增加每次加分量（+1 分/秒，累加）
var branch2_level: int = 0  # 基地血量提升：每次增加 5% 最大血量
var branch3_level: int = 0  # 加钱冷却减少：每次减少 10% 自动得分间隔

# 节点初始化时调用
func _ready():
	# 验证节点是否存在
	if not sprite:
		push_error("未找到 Sprite2D 节点！")  # 如果未找到 Sprite2D，打印错误
	if not area:
		push_error("未找到 Area2D 节点！")    # 如果未找到 Area2D，打印错误
	
	# 连接 Area2D 的输入事件
	if area:
		area.input_event.connect(_on_area_input_event)  # 连接 Area2D 的鼠标输入事件
	
	# 创建自动得分计时器
	var timer = Timer.new()                     # 创建新的计时器节点
	timer.wait_time = get_current_auto_score_interval()  # 设置计时器间隔
	timer.autostart = false                    # 初始不自动启动
	timer.one_shot = false                     # 计时器循环触发
	timer.name = "AutoScoreTimer"              # 命名计时器
	timer.timeout.connect(_on_auto_score_timeout)  # 连接计时器超时时的事件
	add_child(timer)                           # 将计时器添加到节点树
	
	add_to_group("buildings")  # 添加到 buildings 组，方便全局管理

# 设置 UI 节点引用
func set_ui(ui_node: CanvasLayer):
	ui = ui_node  # 存储传入的 UI 节点
	if not ui:
		push_error("UI 节点未设置！")  # 如果 UI 节点为空，打印错误

# 获取当前自动得分间隔（仅由 branch3_level 影响）
func get_current_auto_score_interval() -> float:
	var reduction = branch3_level * 0.10  # 每次 branch3 升级减少 10% 间隔
	return max(0.1, BASE_AUTO_SCORE_INTERVAL * (1.0 - reduction))  # 确保间隔不低于 0.1 秒

# 获取当前每次加分量（由 branch1_level 决定）
func get_auto_score_amount() -> int:
	return branch1_level  # 返回 branch1_level 作为每次自动加分量

# 处理 Area2D 的输入事件（鼠标点击）
func _on_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if ui:
			var skill_tree_visible = ui.skill_tree_panel and ui.skill_tree_panel.visible  # 检查技能树是否可见
			var is_selected = ui.selected_building == self  # 检查当前建筑是否被选中

			if skill_tree_visible and is_selected:
				# 如果技能树可见且建筑被选中，点击加 1 分
				var global = get_node("/root/Global")  # 获取全局单例
				if global:
					global.score += 1                 # 增加全局分数
				play_bounce_animation()               # 播放弹跳动画
				sound_player.play()                   # 播放点击音效
			else:
				# 如果技能树不可见或建筑未被选中，打开技能树
				ui.show_skill_tree(self)              # 显示技能树
				play_bounce_animation()               # 播放弹跳动画
				sound_player.play()                   # 播放点击音效
		else:
			push_error("UI 未设置，无法显示技能树！")  # 如果 UI 未设置，打印错误

# 升级技能树分支 1（每秒加钱）
func upgrade_branch1():
	if branch1_level >= 3:  # 检查是否已达最大等级
		if ui:
			ui.show_message("每秒加钱已满级！")  # 显示满级提示
		return
	
	branch1_level += 1  # 增加 branch1 等级
	if ui:
		ui.show_message("每秒加钱升级至第 %d 级！（+%d 分/秒）" % [branch1_level, branch1_level])  # 显示升级提示
	
	# 启动或更新计时器
	var timer = get_node("AutoScoreTimer")  # 获取计时器节点
	if branch1_level == 1:
		timer.start(get_current_auto_score_interval())  # 初次升级时启动计时器
	else:
		timer.wait_time = get_current_auto_score_interval()  # 更新计时器间隔
		if not timer.is_stopped():
			timer.start()  # 如果计时器正在运行，重新启动以应用新间隔

# 升级技能树分支 2（基地血量提升）
func upgrade_branch2():
	if branch2_level >= 3:  # 检查是否已达最大等级
		if ui:
			ui.show_message("基地血量提升已满级！")  # 显示满级提示
		return
	
	branch2_level += 1  # 增加 branch2 等级
	var base = get_tree().get_first_node_in_group("attackable")  # 获取基地节点
	if base:
		var health_increase = 0.05  # 每次增加 5% 血量
		var max_health = base.max_health  # 获取当前最大血量
		base.max_health += max_health * health_increase  # 增加最大血量
		base.health += max_health * health_increase      # 增加当前血量
		base.update_health_label()                       # 更新基地血量显示
		if ui:
			ui.show_message("基地血量提升 %d%%！（共 %d%%）" % [health_increase * 100, branch2_level * 5])  # 显示升级提示
	else:
		push_error("未找到基地，无法提升血量！")  # 如果未找到基地，打印错误

# 升级技能树分支 3（加钱冷却减少）
func upgrade_branch3():
	if branch3_level >= 3:  # 检查是否已达最大等级
		if ui:
			ui.show_message("加钱冷却减少已满级！")  # 显示满级提示
		return
	
	branch3_level += 1  # 增加 branch3 等级
	if ui:
		ui.show_message("加钱冷却减少升级至第 %d 级！（间隔减少 %d%%）" % [branch3_level, (branch3_level * 10)])  # 显示升级提示
	
	var timer = get_node("AutoScoreTimer")  # 获取计时器节点
	if not timer.is_stopped():
		timer.wait_time = get_current_auto_score_interval()  # 更新计时器间隔
		timer.start()  # 启动计时器以触发自动加分

# 自动加分计时器超时处理
func _on_auto_score_timeout():
	# 根据 branch1_level 动态加分
	var score_amount = get_auto_score_amount()  # 获取当前加分量
	if score_amount > 0:  # 只有当加分量大于 0 时才加分
		var global = get_node("/root/Global")  # 获取全局单例
		if global:
			global.score += score_amount  # 增加全局分数
		play_bounce_animation()          # 播放弹跳动画
		sound_player.play()              # 播放加分音效

# 播放建筑点击时的弹跳动画
func play_bounce_animation():
	var tween = create_tween()  # 创建新的 Tween 动画
	tween.set_ease(Tween.EASE_OUT)  # 设置缓动类型为缓出
	tween.set_trans(Tween.TRANS_ELASTIC)  # 设置过渡类型为弹性效果
	tween.tween_property(sprite, "scale", Vector2(BOUNCE_SCALE, BOUNCE_SCALE), BOUNCE_DURATION / 2)  # 放大动画
	tween.tween_property(sprite, "scale", Vector2(2.5, 2.5), BOUNCE_DURATION / 2)  # 缩小回初始大小
