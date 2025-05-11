extends Control

func _ready():
	# 确保根节点的锚点铺满屏幕
	self.set_anchors_and_offsets_preset(LayoutPreset.PRESET_FULL_RECT)  # 屏幕铺满
	
	# 创建居中容器并添加到根节点
	var center_container = CenterContainer.new()
	center_container.set_anchors_and_offsets_preset(LayoutPreset.PRESET_FULL_RECT)  # 居中容器铺满屏幕
	add_child(center_container)
	
	# 创建垂直排列的按钮容器
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER # 子控件水平居中
	#vbox.add_constant_override("separation", 20)  # 按钮间距为20像素
	center_container.add_child(vbox)
	
	# 创建按钮
	var start_button = Button.new()
	start_button.text = "开始游戏"
	start_button.custom_minimum_size = Vector2(200, 50)  # 按钮最小尺寸
	start_button.pressed.connect(_on_start_pressed)
	vbox.add_child(start_button)
	
	var settings_button = Button.new()
	settings_button.text = "设置"
	settings_button.custom_minimum_size = Vector2(200, 50)
	vbox.add_child(settings_button)
	
	var credits_button = Button.new()
	credits_button.text = "致谢名单"
	credits_button.custom_minimum_size = Vector2(200, 50)
	vbox.add_child(credits_button)
	
	var quit_button = Button.new()
	quit_button.text = "退出游戏"
	quit_button.custom_minimum_size = Vector2(200, 50)
	quit_button.pressed.connect(_on_quit_pressed)
	vbox.add_child(quit_button)

# 按钮信号处理函数
func _on_start_pressed():
	get_tree().change_scene_to_file("res://Main/main.tscn")


func _on_quit_pressed():
	get_tree().quit()
