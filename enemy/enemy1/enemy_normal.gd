extends "res://enemy/enemy_base/enemy_base.gd"

func _ready():
	super._ready()
	speed = 100.0
	max_health = 100.0
	base_damage = 10.0
	health = max_health
