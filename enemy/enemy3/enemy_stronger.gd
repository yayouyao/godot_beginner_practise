extends "res://enemy/enemy_base/enemy_base.gd"

func _ready():
	super._ready()
	speed = 60
	max_health = 1000
	base_damage = 50
	health = max_health
