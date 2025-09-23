extends Control
class_name PlayerList

@onready var players_container = $VBox/PlayersContainer
@onready var title_label = $VBox/TitleLabel

var connected_players: Array[int] = []

func _ready():
	title_label.text = "Connected Players:"
	update_display()

func add_player(player_id: int):
	if not connected_players.has(player_id):
		connected_players.append(player_id)
		update_display()

func remove_player(player_id: int):
	connected_players.erase(player_id)
	update_display()

func clear_players():
	connected_players.clear()
	update_display()

func update_display():
	# Clear existing labels
	for child in players_container.get_children():
		child.queue_free()
	
	if connected_players.is_empty():
		var label = Label.new()
		label.text = "No players connected"
		players_container.add_child(label)
		return
	
	# Sort with host first
	var sorted_players = connected_players.duplicate()
	sorted_players.sort()
	
	for player_id in sorted_players:
		var label = Label.new()
		var display_text = "Player %d" % player_id
		
		if player_id == 1:
			display_text += " (Host)"
			label.modulate = Color.GOLD
		
		if player_id == multiplayer.get_unique_id():
			display_text += " (You)"
			label.modulate = Color.CYAN
		
		label.text = display_text
		players_container.add_child(label)
