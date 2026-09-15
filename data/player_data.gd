class_name BaseballPlayerData
extends Resource

enum IdleBehavior { STILL, PACE }

@export var player_name: String = "Player"
@export_range(30.0, 300.0) var speed: float = 125.0
@export_range(50.0, 1000.0) var acceleration: float = 350.0
@export_range(0.0, 1.0) var reaction_time: float = 0.25
@export_range(0.0, 1.0) var hitting: float = 0.65
@export_range(0.0, 1.0) var fielding: float = 0.7
@export_range(0.0, 1.0) var anticipation: float = 0.7
@export var idle_behavior: IdleBehavior = IdleBehavior.STILL
@export_range(100.0, 600.0) var throwing_speed: float = 330.0
@export_range(100.0, 500.0) var batting_power: float = 290.0
