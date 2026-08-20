extends Control
## Standalone prank easter egg: on a wrong quiz answer, flash a random photo full-screen
## and play a sound, then fade it out. Fully self-contained — to remove, delete this
## script, the PrankJumpscare node in Main.tscn, and resources/prank/.

@export var photos: Array[Texture2D] = []
@export var flash_in_time := 0.08
@export var hold_time := 0.15
@export var fade_out_time := 0.6
@export var sound_start_offset := 0.7  ## skips lead-in silence in the clip

@onready var texture_rect: TextureRect = $TextureRect
@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer

func _ready() -> void:
	texture_rect.modulate.a = 0.0
	var game_manager: Node = get_node("../../GameManager")
	game_manager.round_result.connect(_on_round_result)

func _on_round_result(correct: bool, _constellation_name: String) -> void:
	if correct or photos.is_empty():
		return
	_flash()

func _flash() -> void:
	texture_rect.texture = photos[randi() % photos.size()]
	texture_rect.modulate.a = 0.0
	audio_player.play(sound_start_offset)
	var tween := create_tween()
	tween.tween_property(texture_rect, "modulate:a", 1.0, flash_in_time)
	tween.tween_interval(hold_time)
	tween.tween_property(texture_rect, "modulate:a", 0.0, fade_out_time)
