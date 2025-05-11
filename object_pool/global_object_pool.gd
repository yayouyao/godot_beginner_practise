extends Node

# 内部变量
var pools = {}  # 存储对象池的字典，键为场景资源路径，值为对象数组
const MAX_POOL_SIZE: int = 50  # 每个对象池的最大对象数量

# 初始化对象池
# @param scene: 要初始化的 PackedScene（对象场景）
func initialize_pool(scene: PackedScene) -> void:
	var scene_path = scene.resource_path  # 获取场景的资源路径
	if pools.has(scene_path):
		return  # 如果对象池已存在，直接返回
	pools[scene_path] = []  # 创建新的对象池数组
	var pool = pools[scene_path]  # 获取对象池引用
	for _i in range(MAX_POOL_SIZE):
		var obj = scene.instantiate()  # 实例化对象
		obj.visible = false  # 初始隐藏对象
		pool.append(obj)  # 添加到对象池
		get_tree().current_scene.add_child(obj)  # 添加到当前场景
		if obj.has_method("reset"):
			obj.reset()  # 如果对象有 reset 方法，调用以初始化状态

# 获取对象实例
# @param scene: 要获取对象的 PackedScene
# @param turret: 炮塔引用（可选，用于初始化）
# @param target: 目标位置（可选，用于初始化）
# @return: 可用的对象实例
func get_object(scene: PackedScene, turret: Node = null, target: Vector2 = Vector2.ZERO) -> Node:
	var scene_path = scene.resource_path  # 获取场景的资源路径
	if not pools.has(scene_path):
		initialize_pool(scene)  # 如果对象池不存在，初始化
	var pool = pools[scene_path]  # 获取对象池

	# 查找可用的对象
	for obj in pool:
		if is_instance_valid(obj) and not obj.visible:
			obj.visible = true  # 显示对象
			obj.set_process(true)  # 启用逻辑处理
			obj.set_physics_process(true)  # 启用物理处理
			if obj.has_method("reset"):
				obj.reset()  # 重置对象状态
			if obj.has_method("initialize"):
				obj.initialize(turret, target, self)  # 调用初始化方法，传递炮塔和目标位置
			return obj

	# 如果没有可用对象，创建新实例
	var new_obj = scene.instantiate()  # 实例化新对象
	new_obj.visible = false  # 初始隐藏
	pool.append(new_obj)  # 添加到对象池
	get_tree().current_scene.add_child(new_obj)  # 添加到当前场景
	if new_obj.has_method("reset"):
		new_obj.reset()  # 重置对象状态
	if new_obj.has_method("initialize"):
		new_obj.initialize(turret, target, self)  # 调用初始化方法
	new_obj.visible = true  # 显示对象
	new_obj.set_process(true)  # 启用逻辑处理
	new_obj.set_physics_process(true)  # 启用物理处理
	new_obj.collision_layer = 0  # 禁用碰撞层
	new_obj.collision_mask = 0  # 禁用碰撞掩码
	return new_obj

# 将对象归还到对象池
# @param obj: 要归还的对象实例
func return_object(obj: Node) -> void:
	if not obj:
		return  # 如果对象无效，直接返回
	obj.visible = false  # 隐藏对象
	obj.global_position = Vector2(-1000, -1000)  # 移到屏幕外，避免干扰
	obj.set_process(false)  # 禁用逻辑处理
	obj.set_physics_process(false)  # 禁用物理处理
