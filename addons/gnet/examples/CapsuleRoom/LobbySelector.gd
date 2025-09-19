# CapsuleRoom/LobbySelector.gd
extends Control

@onready var enet_button = $VBoxContainer/EnetButton
@onready var steam_button = $VBoxContainer/SteamButton
@onready var lobby_container = $LobbyContainer

var enet_lobby_scene = preload("res://addons/gnet/examples/EnetP2P/LobbyMain.tscn")
var steam_lobby_scene = preload("res://addons/gnet/examples/SteamP2P/SteamLobbyMain.tscn")
var game_scene = preload("res://addons/gnet/examples/CapsuleRoom/Game.tscn")

var current_lobby = null

func _ready():
	enet_button.pressed.connect(_on_enet_selected)
	steam_button.pressed.connect(_on_steam_selected)

func _on_enet_selected():
	_load_lobby(enet_lobby_scene)

func _on_steam_selected():
	_load_lobby(steam_lobby_scene)

func _load_lobby(lobby_scene: PackedScene):
	# Clear existing lobby
	if current_lobby:
		current_lobby.queue_free()
	
	# Hide selector buttons
	enet_button.visible = false
	steam_button.visible = false
	
	# Load new lobby
	current_lobby = lobby_scene.instantiate()
	lobby_container.add_child(current_lobby)
