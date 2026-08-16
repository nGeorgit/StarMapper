extends Control
## Map-style +/- zoom buttons, wired to CameraRig's FOV zoom.

@onready var camera_rig: CameraRig = $"../../CameraRig"

func _ready() -> void:
	$ZoomInButton.pressed.connect(camera_rig.zoom_in)
	$ZoomOutButton.pressed.connect(camera_rig.zoom_out)
