extends Node


func _ready() -> void:
	var test_runner_script: Script = load("res://tests/TestRunner.gd")
	var runner: Node = test_runner_script.new()
	add_child(runner)
