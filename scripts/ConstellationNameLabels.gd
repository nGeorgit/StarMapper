extends Node3D
## Shows each constellation's name centered over its stick figure. Explore-mode only —
## no-op in quiz mode, since the quiz is about finding the shape without being told
## which one it is.

@export var label_color := Color(0.55, 0.75, 0.95, 0.85)
@export var font_size := 26
@export var pixel_size := 0.9

@onready var constellation_lines: MultiMeshInstance3D = $"../ConstellationLines"

func _ready() -> void:
	if GameState.mode != GameState.Mode.EXPLORE:
		return
	ConstellationSets.set_changed.connect(_rebuild)
	await get_tree().process_frame  # let ConstellationLines finish loading its JSON first
	_rebuild()

func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	for c in constellation_lines.constellations:
		_add_label(c)

func _add_label(c: Dictionary) -> void:
	var sum := Vector3.ZERO
	var count := 0
	var seen := {}
	for seg in c["segments"]:
		for pt in [Vector2(seg[0], seg[1]), Vector2(seg[2], seg[3])]:
			var key: String = str(pt)
			if seen.has(key):
				continue
			seen[key] = true
			sum += AstroMath.ra_dec_to_vector3(pt.x, pt.y)
			count += 1
	if count == 0:
		return
	var centroid: Vector3 = sum.normalized() * AstroMath.SKY_RADIUS

	var label := Label3D.new()
	label.text = c["name"]
	label.modulate = label_color
	label.font_size = font_size
	label.pixel_size = pixel_size
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = centroid
	add_child(label)
