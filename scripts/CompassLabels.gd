extends Node3D
## N/E/S/W letters at the horizon, fixed in world space next to Ground/AltAzGrid (world
## space already IS the observer's local Alt/Az frame -- see AstroMath.horizontal_basis).
##
## Explore: always on. Quiz: Easy/Medium (matches every other "how much help" visual);
## Hard hides it, same as the star names/constellation lines it's drawn alongside.

@export var label_color := Color(0.75, 0.9, 0.8, 0.9)
@export var font_size := 64
@export var pixel_size := 1.3
@export var radius := AstroMath.SKY_RADIUS * 0.998
## Ground is alpha-transparent (its horizon fade), so it sorts into the same
## back-to-front transparent pass as these labels -- and at ~1 unit from the camera vs.
## the labels' ~1000, it would normally sort (and draw) after them, painting over the
## letters despite no_depth_test. A large sorting_offset biases these labels to be
## treated as the nearest thing on screen for sort purposes, forcing them to draw last.
@export var sorting_offset := 4096.0

const POINTS := [["N", 0.0], ["E", 90.0], ["S", 180.0], ["W", 270.0]]

func _ready() -> void:
	if GameState.mode == GameState.Mode.QUIZ and GameState.difficulty == GameState.Difficulty.HARD:
		return
	for point in POINTS:
		_add_label(point[0], point[1])

func _add_label(letter: String, az_deg: float) -> void:
	var label := Label3D.new()
	label.text = letter
	label.modulate = label_color
	label.font_size = font_size
	label.pixel_size = pixel_size
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.sorting_offset = sorting_offset
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = AstroMath.alt_az_to_vector3(0.0, az_deg, radius)
	add_child(label)
