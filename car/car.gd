class_name RaycastVehicle
extends RigidBody3D

@export var engine_power: float = 5.0
@export var steering_angle: float = 0.0
@export var steering_max_angle: float = 30.0
@export var steering_speed: float = 100.0

# Virtual properties
@export var interpolated_position: Vector3
@export var interpolated_rotation: Quaternion
@export var integrated_linear_vel: Vector3
@export var integrated_angular_vel: Vector3

@onready var player := get_parent()
@onready var _multiplayer_synchronizer := $MultiplayerSynchronizer

var _acceleration_input := 0.0
var _steering_input := 0.0
var _current_interp_pos_time := 0.0
var _current_interp_rot_time := 0.0


func _process(delta: float) -> void:
	if is_multiplayer_authority() and player.owner_peer_id == multiplayer.get_unique_id():
		_acceleration_input = Input.get_axis("backward", "forward")
		_steering_input = Input.get_axis("right", "left")
		steering_angle = move_toward(steering_angle, steering_max_angle * _steering_input, steering_speed * delta)

	if not is_multiplayer_authority():
		_current_interp_pos_time = clampf(_current_interp_pos_time + delta, 0.0, _multiplayer_synchronizer.replication_interval)
		_current_interp_rot_time = clampf(_current_interp_rot_time + delta, 0.0, _multiplayer_synchronizer.replication_interval)


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if is_multiplayer_authority():
		interpolated_rotation = Quaternion(basis)
		interpolated_position = position
		integrated_linear_vel = state.linear_velocity
		integrated_angular_vel = state.angular_velocity
	else:
		if not Quaternion(transform.basis).is_equal_approx(interpolated_rotation):
			var current_interp_step := remap(_current_interp_rot_time, 0.0, _multiplayer_synchronizer.replication_interval, 0.1, 0.9)
			var quat_rotation := Quaternion(basis)
			quat_rotation = quat_rotation.slerp(interpolated_rotation, current_interp_step)
			basis = Basis(quat_rotation)
		else:
			basis = Basis(interpolated_rotation)
			
		if not position.is_equal_approx(interpolated_position):
			var current_interp_step := remap(_current_interp_pos_time, 0.0, _multiplayer_synchronizer.replication_interval, 0.1, 0.9)
			position = position.lerp(interpolated_position, current_interp_step)
		else:
			position = interpolated_position
			
		state.linear_velocity = integrated_linear_vel
		state.angular_velocity = integrated_angular_vel


func _on_multiplayer_synchronizer_synchronized() -> void:
	if not Quaternion(transform.basis).is_equal_approx(interpolated_rotation):
		_current_interp_rot_time = 0.0
		
	if not position.is_equal_approx(interpolated_position):
		_current_interp_pos_time = 0.0
	
