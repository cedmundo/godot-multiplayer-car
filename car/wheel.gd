class_name RaycastWheel
extends RayCast3D

@export var spring_rest_distance: float = 0.5
@export var spring_stiffness: float = 10.0
@export var spring_damper: float = 1.0
@export var wheel_friction_power: float = 10.0
@export var wheel_radius: float = 0.5
@export var wheel_grip: float = 2.0
@export var use_as_traction: bool = false
@export var use_as_direction: bool = false
@onready var _car: RaycastVehicle = get_parent()

var _previous_spring_length := 0.0
var _wheel_center := Vector3.ZERO
var _wheel_global_velocity := Vector3.ZERO
var _raycast_target := Vector3.ZERO
var _raycast_origin := Vector3.ZERO


func _ready() -> void:
	add_exception(_car)


func _physics_process(delta: float) -> void:
	if not is_colliding():
		return
		
	_raycast_origin = global_position
	_raycast_target = get_collision_point()
	_wheel_center = Vector3(_raycast_target.x, _raycast_target.y + wheel_radius, _raycast_target.z)
	_wheel_global_velocity = _get_point_velocity(_raycast_origin)
	
	_apply_suspension_force(delta)
	if use_as_traction:
		_apply_acceleration()

	if use_as_direction:
		_apply_steering()

	_apply_velicity_loss()
	_apply_lateral_force(delta)


func _apply_suspension_force(delta: float) -> void:
	var suspension_direction := global_basis.y
	var raycast_distance := _raycast_target.distance_to(_raycast_origin)
	
	# var contact_point := get_collision_point() - _car.global_position
	var spring_length := clampf(raycast_distance - wheel_radius, 0, spring_rest_distance)
	var spring_force := spring_stiffness * (spring_rest_distance - spring_length)
	var spring_velocity := (_previous_spring_length - spring_length) / delta
	var spring_damper_force = spring_damper * spring_velocity
	var suspesion_force: Vector3 = basis.y * (spring_force + spring_damper_force)
	# note: there is a difference between basis.y and global_basis.y
	
	_car.apply_force(suspesion_force * suspension_direction, _wheel_center - _car.global_position)
	_previous_spring_length = spring_length


func _apply_acceleration() -> void:
	var acceleration_direction := -global_basis.z
	var torque = _car._acceleration_input * _car.engine_power
	_car.apply_force(torque * acceleration_direction, _wheel_center - _car.global_position)


func _apply_velicity_loss() -> void:
	var force_direction := global_basis.z
	var z_force := force_direction.dot(_wheel_global_velocity) * wheel_friction_power / _car.mass
	_car.apply_force(-force_direction * z_force, _raycast_target - _car.global_position)


func _apply_steering() -> void:
	rotation.y = deg_to_rad(_car.steering_angle)


func _apply_lateral_force(delta: float) -> void:
	var force_direction := global_basis.x
	var lateral_force := force_direction.dot(_wheel_global_velocity)
	var desired_velocity_change := -lateral_force * wheel_grip
	var x_force := desired_velocity_change + delta
	_car.apply_force(force_direction * x_force, _raycast_target - _car.global_position)


func _get_point_velocity(point: Vector3) -> Vector3:
	return _car.linear_velocity + _car.angular_velocity.cross(point - _car.global_position)
