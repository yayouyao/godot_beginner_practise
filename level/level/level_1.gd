extends LevelBase
class_name Level1

func _ready():
	# 定义三个轮次
	waves = [
		# 第一轮：只有普通敌人
		{
			"normal_count": 10,
			"fast_count": 0,
			"stronger_count": 0,
			"spawn_weights": [1.0, 0.0, 0.0],
			"spawn_interval": 2.0
		},
		# 第二轮：普通敌人 + 快速敌人
		{
			"normal_count": 15,
			"fast_count": 5,
			"stronger_count": 0,
			"spawn_weights": [0.8, 0.2, 0.0],
			"spawn_interval": 1.5
		},
		# 第三轮：普通敌人 + 快速敌人 + 重型敌人
		{
			"normal_count": 20,
			"fast_count": 10,
			"stronger_count": 5,
			"spawn_weights": [0.6, 0.2, 0.2],
			"spawn_interval": 1.0
		}
	]
	super._ready()
