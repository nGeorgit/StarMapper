extends Node3D
## Draws proper-name labels (e.g. "Dubhe") next to bright named stars, Stellarium-style.
## Reuses StarField's already-loaded star list rather than re-reading the JSON.
## Explore mode: always on. Quiz mode: Easy only (Medium/Hard hide star names).

@export var label_mag_threshold := 1.8  ## only label the handful of brightest named stars
@export var label_color := Color(0.95, 0.85, 0.55)
@export var font_size := 32
@export var pixel_size := 1.0  ## world units per font pixel; sky radius is 1000, so this is scaled way up from Label3D's 0.01 default
@export var offset_distance := 22.0  ## world units, tangent to the sphere at the star

@onready var star_field: StarField = $"../StarField"

func _ready() -> void:
	if GameState.mode == GameState.Mode.QUIZ and GameState.difficulty != GameState.Difficulty.EASY:
		return
	for s in star_field.loaded_stars:
		if s.has("name") and s["mag"] <= label_mag_threshold:
			_add_label(s)

func _add_label(s: Dictionary) -> void:
	var pos := AstroMath.ra_dec_to_vector3(s["ra"], s["dec"])
	var normal := pos.normalized()
	var tangent := normal.cross(Vector3.UP)
	if tangent.length() < 0.001:
		tangent = Vector3.RIGHT
	tangent = tangent.normalized()

	var label := Label3D.new()
	label.text = s["name"]
	label.modulate = label_color
	label.font_size = font_size
	label.pixel_size = pixel_size
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.position = pos + tangent * offset_distance
	add_child(label)
