extends Control
class_name LobbyListItem

signal join_requested(lobby_id: int)

@onready var lobby_name: Label = $HBoxContainer/LobbyInfo/LobbyName
@onready var player_count: Label = $HBoxContainer/LobbyInfo/PlayerCount
@onready var join_button: Button = $HBoxContainer/JoinButton

var lobby_data: Dictionary

func _ready():
	join_button.pressed.connect(_on_join_pressed)

func setup(lobby: Dictionary):
	lobby_data = lobby
	lobby_name.text = lobby.owner_name + "'s Game"
	player_count.text = "%d/%d players" % [lobby.member_count, lobby.max_members]
	join_button.text = "Join"

func _on_join_pressed():
	join_requested.emit(lobby_data.lobby_id)
