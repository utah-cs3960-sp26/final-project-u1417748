extends Node2D
class_name GameRootView

@onready var ball_handler: PlayerPresentation = $Entities/HomeHandler
@onready var ball: BallPresentation = $Entities/Ball
@onready var hud: HudPresentation = $CanvasLayer/HUD
@onready var pause_overlay: PauseOverlayPresentation = $CanvasLayer/PauseOverlay
@onready var game_over_overlay: GameOverOverlayPresentation = $CanvasLayer/GameOverOverlay
@onready var debug_overlay: DebugOverlayView = $CanvasLayer/DebugOverlay

var demo_time: float = 0.0

func _ready() -> void:
	hud.pause_pressed.connect(_toggle_pause)
	pause_overlay.resume_requested.connect(_hide_pause)
	pause_overlay.restart_requested.connect(_restart_scene)
	pause_overlay.menu_requested.connect(_return_to_menu)
	game_over_overlay.restart_requested.connect(_restart_scene)
	game_over_overlay.menu_requested.connect(_return_to_menu)
	debug_overlay.visible = true
	pause_overlay.visible = false
	game_over_overlay.visible = false

func _process(delta: float) -> void:
	if pause_overlay.visible or game_over_overlay.visible:
		return
	demo_time += delta
	var dribble_wave := sin(demo_time * 7.0)
	ball.position = ball_handler.position + Vector2(28.0 + dribble_wave * 10.0, -46.0)
	ball.set_ball_height(22.0 + abs(dribble_wave) * 18.0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_toggle_pause()
		elif event.keycode == KEY_F3:
			debug_overlay.visible = not debug_overlay.visible

func _toggle_pause() -> void:
	pause_overlay.visible = not pause_overlay.visible

func _hide_pause() -> void:
	pause_overlay.visible = false

func _restart_scene() -> void:
	get_tree().reload_current_scene()

func _return_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
