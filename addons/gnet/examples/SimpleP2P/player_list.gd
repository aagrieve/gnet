extends Control
class_name PlayerList

@onready var players_container = $VBox/PlayersContainer
@onready var title_label = $VBox/TitleLabel

func _ready():
	title_label.text = "Connected Players:"
	set_players([])  # Start with empty list

func set_players(player_ids: Array[int]):
	"""Main method to update the player list display."""
	update_display(player_ids)

func update_display(player_ids: Array[int]):
	# Clear existing labels
	for child in players_container.get_children():
		child.queue_free()
	
	if player_ids.is_empty():
		var label = Label.new()
		label.text = "No players connected"
		players_container.add_child(label)
		return
	
	# Sort with host first
	var sorted_players = player_ids.duplicate()
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

func clear_players():
	set_players([])
