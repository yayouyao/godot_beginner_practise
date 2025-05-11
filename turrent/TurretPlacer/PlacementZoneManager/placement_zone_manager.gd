extends Node2D
class_name PlacementZoneManager

# 可配置属性
@export var zone_size: Vector2 = Vector2(100, 100)  # 放置区域的尺寸（宽，高）
@export var zone_position: Vector2 = Vector2(50, 50)  # 放置区域的中心位置

# 内部变量
var zone: Dictionary = {}  # 存储区域信息的字典，包含中心点、矩形区域和 ID
var zone_id: String = str(randi())  # 区域的唯一标识，随机生成

# 信号
signal zone_occupied  # 当区域被占用时发出

# 节点初始化时调用
func _ready():
	update_zone()  # 初始化区域信息
	draw_zone()  # 绘制区域
	add_to_group("placement_zones")  # 添加到 placement_zones 组，方便其他脚本访问

# 更新区域信息
func update_zone():
	zone = {
		"center": zone_position,  # 区域中心点
		"rect": Rect2(zone_position - zone_size / 2, zone_size),  # 区域矩形（左上角位置和尺寸）
		"id": zone_id  # 区域唯一 ID
	}

# 绘制区域
func draw_zone():
	for child in get_children():
		child.queue_free()  # 清空现有子节点（移除旧的绘制）
	var rect = ColorRect.new()  # 创建新的颜色矩形用于绘制区域
	rect.position = zone["rect"].position  # 设置矩形位置
	rect.size = zone["rect"].size  # 设置矩形尺寸
	var global = get_node("/root/Global")  # 获取 Global 单例
	var occupied = false  # 默认区域未占用
	if global and global.has_method("is_zone_occupied"):
		occupied = global.is_zone_occupied(zone_id)  # 检查区域是否被占用
	else:
		push_warning("Global 节点未找到或缺少 is_zone_occupied 方法，假设区域未占用")  # 如果 Global 缺失，打印警告
	rect.color = Color(0, 1, 0, 0.3) if not occupied else Color(1, 0, 0, 0.3)  # 未占用为绿色，占用为红色
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 忽略鼠标输入
	rect.z_index = 0  # 设置绘制层级
	add_child(rect)  # 添加矩形到节点树

# 检查点是否在区域内
# @param pos: 要检查的全局坐标
# @return: 点是否在区域内
func is_point_in_zone(pos: Vector2) -> bool:
	return zone["rect"].has_point(pos)  # 返回点是否在区域矩形内

# 检查是否可以在区域内放置
# @return: 是否可以放置（区域未占用且鼠标在区域内）
func can_place_in_zone() -> bool:
	var global = get_node("/root/Global")
	if not global or not global.has_method("is_zone_occupied"):
		return false  # 如果 Global 缺失或无方法，返回 false
	var occupied = global.is_zone_occupied(zone_id)  # 检查区域是否被占用
	return not occupied and is_point_in_zone(get_global_mouse_position())  # 未占用且鼠标在区域内

# 占用区域
func occupy_zone():
	var global = get_node("/root/Global")
	if global and global.has_method("set_zone_occupied"):
		global.set_zone_occupied(zone_id, true)  # 设置区域为占用状态
		draw_zone()  # 重新绘制区域（更新颜色）
		zone_occupied.emit()  # 发出区域占用信号
	else:
		push_error("Global 节点未找到或缺少 set_zone_occupied 方法")  # 如果 Global 缺失，打印错误

# 获取区域中心点
# @return: 区域中心坐标
func get_zone_center() -> Vector2:
	return zone["center"]

# 释放区域
func free_zone():
	var global = get_node("/root/Global")
	if global and global.has_method("set_zone_occupied"):
		global.set_zone_occupied(zone_id, false)  # 设置区域为未占用状态
		draw_zone()  # 重新绘制区域（更新颜色）
	else:
		push_error("Global 节点未找到或缺少 set_zone_occupied 方法")  # 如果 Global 缺失，打印错误
