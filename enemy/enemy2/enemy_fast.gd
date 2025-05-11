extends "res://enemy/enemy_base/enemy_base.gd"

func _ready():
	super._ready()
	speed = 200
	max_health = 120
	base_damage = 10.0
	health = max_health
