class_name BallSimulator
extends RefCounted

var position_xy: Vector2 = Vector2.ZERO
var previous_position_xy: Vector2 = Vector2.ZERO
var velocity_xy: Vector2 = Vector2.ZERO
var z: float = 0.0
var previous_z: float = 0.0
var vz: float = 0.0
var gravity: float = -920.0
var ball_radius: float = 18.0
var launch_z: float = 0.0
var is_in_flight: bool = false
var already_scored: bool = false
var forced_make: bool = false


func clone_state() -> BallSimulator:
	var clone: BallSimulator = BallSimulator.new()
	clone.position_xy = position_xy
	clone.previous_position_xy = previous_position_xy
	clone.velocity_xy = velocity_xy
	clone.z = z
	clone.previous_z = previous_z
	clone.vz = vz
	clone.gravity = gravity
	clone.ball_radius = ball_radius
	clone.launch_z = launch_z
	clone.is_in_flight = is_in_flight
	clone.already_scored = already_scored
	clone.forced_make = forced_make
	return clone


func reset_to_possession(world_position: Vector2) -> void:
	position_xy = world_position
	previous_position_xy = world_position
	velocity_xy = Vector2.ZERO
	z = 0.0
	previous_z = 0.0
	vz = 0.0
	launch_z = 0.0
	is_in_flight = false
	already_scored = false
	forced_make = false


func launch(world_position: Vector2, velocity_value: Vector2, initial_z: float, z_speed: float, force_make: bool = false) -> void:
	position_xy = world_position
	previous_position_xy = world_position
	velocity_xy = velocity_value
	launch_z = maxf(initial_z, 0.0)
	z = launch_z
	previous_z = launch_z
	vz = z_speed
	is_in_flight = true
	already_scored = false
	forced_make = force_make


func step(delta: float) -> void:
	previous_position_xy = position_xy
	previous_z = z
	position_xy += velocity_xy * delta
	vz += gravity * delta
	z += vz * delta
	if z <= 0.0 and vz < 0.0:
		z = 0.0
		vz = 0.0
		is_in_flight = false


func predict_trajectory(point_count: int, delta: float) -> Array[Dictionary]:
	var probe: BallSimulator = clone_state()
	var points: Array[Dictionary] = []
	for _index in point_count:
		probe.step(delta)
		points.append({
			"position": probe.position_xy,
			"z": probe.z,
		})
		if not probe.is_in_flight:
			break
	return points
