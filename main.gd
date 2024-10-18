extends Node3D

const HOST_ADDRESS = "localhost"
const HOST_PORT = 9862
const MAX_PLAYERS = 32

@onready var _players := $Players
var _player_resource := preload("res://player/player.tscn")
var _spawn_point := 0.0


func _ready() -> void:
	randomize()
	var args := OS.get_cmdline_user_args()
	if "--server" in args:
		_create_server()
		DisplayServer.window_set_title("MultiplayerTesing (DBEUG)(SERVER)")
	else:
		await get_tree().create_timer(randf_range(1.0, 2.0)).timeout
		_create_client()
		DisplayServer.window_set_title("MultiplayerTesing (DBEUG)(CLIENT)")
		

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_home") and multiplayer.is_server():
		for player in _players.get_children():
			player.set_multiplayer_authority(player.owner_peer_id, true)
		
		assign_players_authority.rpc()


func _get_random_color() -> Color:
	return Color.from_hsv((randi() % 20) / 20.0, 0.5, 1.0)
	

func _on_ready_button_toggled(toggled_on: bool) -> void:
	if multiplayer.is_server():
		var player_node := _players.get_node_or_null("1")
		if player_node:
			player_node.ready_to_play = toggled_on
	else:
		set_ready_to_play.rpc_id(1, toggled_on)


func _on_change_color_button_pressed() -> void:
	if multiplayer.is_server():
		var player_node := _players.get_node_or_null("1")
		if player_node:
			player_node.player_color = _get_random_color()
	else:
		set_player_color.rpc_id(1, _get_random_color())


#region Server
var _lobby := {}

func _create_server() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(HOST_PORT, MAX_PLAYERS)
	peer.peer_connected.connect(_on_server_peer_connected)
	peer.peer_disconnected.connect(_on_server_peer_disconnected)
	multiplayer.multiplayer_peer = peer
	_on_server_peer_connected(1)
	_add_player_node(1, "server", _get_random_color())
	
	
func _on_server_peer_connected(peer_id: int) -> void:
	print("[%010d] peer connected %d" % [multiplayer.get_unique_id(), peer_id])
	_lobby[peer_id] = {
		"authenticated": false,
	}
	

func _on_server_peer_disconnected(peer_id: int) -> void:
	print("[%010d] peer disconnected %d" % [multiplayer.get_unique_id(), peer_id])
	_lobby.erase(peer_id)
	var player_node := _players.get_node_or_null(str(peer_id))
	if player_node:
		player_node.queue_free()

	
func _add_player_node(peer_id: int, player_name: String, player_color: Color) -> void:
	var player_node := _player_resource.instantiate()
	player_node.name = str(peer_id)
	player_node.position.z = _spawn_point
	_players.add_child(player_node)
	player_node.player_name = player_name
	player_node.player_color = player_color
	player_node.owner_peer_id = peer_id
	player_node.ready_to_play = false
	_spawn_point -= 5.0


@rpc("any_peer", "reliable")
func request_authenticate(player_name: String, player_color: Color) -> void:
	var peer_id := multiplayer.get_remote_sender_id()
	_lobby[peer_id]["authenticated"] = true
	_add_player_node(peer_id, player_name, player_color)
	

@rpc("any_peer", "reliable")
func set_ready_to_play(value: bool) -> void:
	var peer_id := multiplayer.get_remote_sender_id()
	var player_node := _players.get_node_or_null(str(peer_id))
	if player_node:
		player_node.ready_to_play = value
		

@rpc("any_peer", "reliable")
func set_player_color(new_color: Color) -> void:
	var peer_id := multiplayer.get_remote_sender_id()
	var player_node := _players.get_node_or_null(str(peer_id))
	if player_node:
		player_node.player_color = new_color
#endregion

#region Client
func _create_client() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_client(HOST_ADDRESS, HOST_PORT)
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_client_connected_to_server)
	

func _on_client_connected_to_server() -> void:
	print("[%010d] conencted to server" % [multiplayer.get_unique_id()])
	request_authenticate.rpc_id(1, str(multiplayer.get_unique_id()), _get_random_color())


@rpc("authority", "reliable")
func assign_players_authority() -> void:
	for player in _players.get_children():
		player.set_multiplayer_authority(player.owner_peer_id, true)
#endregion
