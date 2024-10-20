extends Node3D

@export var player_name := ""
@export var owner_peer_id := 0
@export var ready_to_play := false
@export var player_color := Color.WHITE:
	set(pc):
		player_color = pc
		_update_color()
		
@onready var _tag := $Car/Tag
@onready var _avatar := $Car/Avatar
# @onready var _car := $Car

func _process(delta: float) -> void:
	_tag.text = player_name + ("(ready)" if ready_to_play else "")
	_process_input(delta)


func _process_input(_delta: float) -> void:
	if (multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED 
		and not is_multiplayer_authority() or owner_peer_id != multiplayer.get_unique_id()):
		return

	# _car.steering = move_toward(_car.steering, deg_to_rad(Input.get_axis("right", "left") * 45), 10 * delta)
	# _car.engine_force = Input.get_axis("backward", "forward") * 400


func _update_color() -> void:
	if _avatar:
		var material: Material = _avatar.get_surface_override_material(0)
		var duplicated := material.duplicate()
		duplicated.albedo_color = player_color
		_avatar.set_surface_override_material(0, duplicated)
