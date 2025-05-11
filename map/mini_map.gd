extends CanvasLayer

# 内部变量
var preview_width: float = 200.0  # 小地图预览图的固定宽度
var preview_height: float  # 小地图预览图的高度（动态计算）
var screen_width: float  # 屏幕宽度
var screen_height: float  # 屏幕高度
var map_width: float  # 地图总宽度（从 map_left 到 map_right）
var map_left: float  # 地图左边界
var map_right: float  # 地图右边界

# 节点引用
@onready var map_texture: TextureRect = $MapTexture  # 小地图的纹理显示节点
@onready var click_area: ColorRect = $ClickArea  # 小地图的点击区域
var camera: Camera2D  # 摄像机引用
var viewport_rect: ColorRect  # 表示当前视野的矩形
var has_initialized_camera: bool = false  # 是否已成功获取摄像机

# 节点初始化时调用
func _ready():
	add_to_group("mini_map")  # 将节点添加到 mini_map 组，方便其他脚本访问

	# 获取屏幕尺寸
	var viewport = get_viewport()
	if viewport:
		screen_width = viewport.size.x  # 设置屏幕宽度
		screen_height = viewport.size.y  # 设置屏幕高度
	else:
		push_error("无法获取 Viewport！使用默认屏幕宽度 1280")  # 如果获取失败，打印错误
		screen_width = 1280.0  # 默认宽度
		screen_height = 720.0  # 默认高度

	# 设置地图范围
	map_left = -1.0 * screen_width  # 地图左边界为屏幕宽度的负一倍
	map_right = 2.0 * screen_width  # 地图右边界为屏幕宽度的两倍
	map_width = map_right - map_left  # 计算地图总宽度（3倍屏幕宽度）

	# 计算小地图高度
	preview_height = preview_width / map_width * screen_width  # 根据比例计算高度

	# 尝试获取摄像机
	camera = get_viewport().get_camera_2d()
	if camera:
		has_initialized_camera = true  # 标记摄像机已获取
	else:
		print("MiniMap: 初始获取 Camera2D 失败，将在 _process 中重试")  # 如果失败，稍后重试

	# 检查关键节点
	if not map_texture:
		push_error("未找到 MapTexture 节点！请检查 MiniMap 场景中是否存在 MapTexture 节点。")  # 如果纹理缺失，打印错误
		return
	if not click_area:
		push_error("未找到 ClickArea 节点！")  # 如果点击区域缺失，打印错误
		return

	# 设置小地图尺寸
	map_texture.size = Vector2(preview_width, preview_height)  # 设置纹理尺寸
	click_area.size = Vector2(preview_width, preview_height)  # 设置点击区域尺寸
	click_area.color = Color(1, 1, 1, 0.2)  # 设置点击区域为半透明
	click_area.mouse_filter = Control.MOUSE_FILTER_STOP  # 确保点击区域捕获鼠标输入
	click_area.gui_input.connect(_on_click_area_gui_input)  # 连接点击区域输入信号
	map_texture.position = Vector2(screen_width - preview_width - 10, 10)  # 设置小地图右上角位置
	click_area.position = map_texture.position  # 同步点击区域位置

	# 添加视野矩形
	viewport_rect = ColorRect.new()  # 创建表示当前视野的矩形
	viewport_rect.color = Color(1, 0, 0, 0.5)  # 设置为半透明红色
	add_child(viewport_rect)  # 添加到节点树

# 每帧处理
func _process(delta: float):
	# 如果还未获取摄像机，继续尝试
	if not has_initialized_camera:
		camera = get_viewport().get_camera_2d()
		if camera:
			has_initialized_camera = true  # 标记摄像机已获取
		else:
			return  # 如果仍未获取，跳过处理

	# 确保摄像机和视野矩形存在
	if not camera or not viewport_rect:
		return

	# 更新视野矩形位置
	var t = (camera.position.x - map_left) / map_width  # 计算摄像机位置在地图中的归一化比例
	var view_width = screen_width / map_width * preview_width  # 计算视野矩形宽度
	viewport_rect.position = Vector2(t * preview_width - view_width / 2.0, 0) + map_texture.position  # 设置矩形位置
	viewport_rect.size = Vector2(view_width, preview_height)  # 设置矩形尺寸

# 处理点击区域的输入事件
# @param event: 输入事件
func _on_click_area_gui_input(event: InputEvent):
	if not camera:
		return  # 如果摄像机未获取，跳过处理
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var click_pos = click_area.get_local_mouse_position()  # 获取点击位置
		var t = clamp(click_pos.x / preview_width, 0.0, 1.0)  # 归一化点击位置到 [0, 1]
		var map_x = t * map_width + map_left  # 映射到地图坐标 [map_left, map_right]
		var camera_x = clamp(map_x, map_left + screen_width / 2.0, map_right - screen_width / 2.0)  # 限制摄像机 X 坐标
		var camera_y = clamp(camera.position.y, 0, screen_height)  # 限制摄像机 Y 坐标
		var target_camera_pos = Vector2(camera_x, camera_y)  # 目标摄像机位置
		var tween = create_tween()  # 创建动画
		tween.tween_property(camera, "position", target_camera_pos, 0.5).set_ease(Tween.EASE_IN_OUT)  # 平滑移动摄像机
