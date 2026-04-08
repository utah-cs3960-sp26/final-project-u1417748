extends SceneTree


func _initialize() -> void:
	var runner_script: Script = load("res://tests/TestRunner.gd")
	var runner: Node = runner_script.new()
	root.add_child(runner)
