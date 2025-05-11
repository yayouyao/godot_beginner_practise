extends CanvasLayer

# 节点引用
@onready var dialog_panel: PanelContainer = $DialogPanel  # 对话面板容器
@onready var message_label: Label = $DialogPanel/MessageLabel  # 显示对话内容的标签

# 对话内容数组
var dialog_lines: Array[String] = [
	"欢迎体验游戏！你需要扮演墨子的弟子放置城守机关来防御敌人(鼠标单击以继续)",  # 欢迎信息
	"屏幕右上是小地图，调整小地图可以让你提前看到敌人(将小地图调整到最左边以继续)",  # 小地图说明
	"点击建筑可以提供经济，尽情点击吧",  # 建筑交互说明
	"屏幕右下是敌人下一次全面进攻的进度条，守住3轮的敌人进攻就是胜利",  # 敌人进攻进度说明
	"单独点击键盘上的1，2，3可以快捷选中机关",  # 快捷键说明
	"点击屏幕上的前排绿色区域可以放置机关。试试看",  # 机关放置说明
	"注意保护你的基地，基地被摧毁游戏就会结束",  # 基地保护提示
]

# 内部变量
var is_dialog_visible: bool = false  # 对话面板是否可见
var message_timer: float = 0.0       # 对话显示的计时器
const MESSAGE_DURATION: float = 5.0  # 默认对话显示持续时间（秒）

# 信号：教程完成时发出
signal tutorial_completed  # 通知教程已完成

# 节点初始化时调用
func _ready():
	hide_dialog()  # 初始隐藏对话面板
	center_dialog()  # 居中对话面板

# 显示指定索引的对话内容
# @param line_index: 要显示的对话行索引
# @param duration: 对话显示的持续时间（默认 MESSAGE_DURATION）
func show_message(line_index: int, duration: float = MESSAGE_DURATION):
	if line_index >= 0 and line_index < dialog_lines.size():
		message_label.text = dialog_lines[line_index]  # 设置对话内容
		dialog_panel.visible = true  # 显示对话面板
		is_dialog_visible = true    # 标记为可见
		message_timer = duration    # 设置显示计时器
		center_dialog()             # 居中对话面板
	else:
		hide_dialog()  # 如果索引无效，隐藏对话面板

# 隐藏对话面板
func hide_dialog():
	if dialog_panel:
		dialog_panel.visible = false  # 隐藏对话面板
	is_dialog_visible = false         # 标记为不可见
	message_label.text = ""           # 清空对话内容
	message_timer = 0.0              # 重置计时器

# 每帧处理
func _process(delta: float):
	if is_dialog_visible and message_timer > 0:
		message_timer -= delta  # 减少显示时间
		if message_timer <= 0:
			hide_dialog()  # 时间耗尽时隐藏对话面板

# 居中对话面板
func center_dialog():
	var viewport = get_viewport()  # 获取视口
	var screen_size = viewport.get_visible_rect().size  # 获取屏幕尺寸
	if dialog_panel:
		var panel_size = dialog_panel.size  # 获取面板尺寸
		dialog_panel.position = (screen_size - panel_size) / 2  # 设置面板位置为屏幕中心
