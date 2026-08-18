extends WorldEnvironment
## Fades the Milky Way background in as the player zooms in: barely-there at a wide,
## cluttered view (min_opacity), fuller richness once zoomed in close enough to
## appreciate it without drowning the star field (max_opacity). Exponential ramp
## (gamma > 1) keeps opacity near min_opacity for most of the zoom range and only
## climbs sharply near max zoom, rather than a flat linear fade.

@export var min_opacity := 0.08  ## at max_fov (zoomed all the way out)
@export var max_opacity := 0.35  ## at min_fov (zoomed all the way in)
@export var gamma := 3.0  ## >1 = ramp concentrated near min_fov (max zoom); 1 = linear

@onready var camera_rig: CameraRig = $"../CameraRig"

func _ready() -> void:
	camera_rig.fov_changed.connect(_on_fov_changed)
	# WorldEnvironment is a CameraRig sibling listed earlier in Main.tscn, so CameraRig's
	# own @onready var camera ($Camera3D) isn't set yet at this point in the tree's
	# ready order -- wait a frame so it's safe to read.
	await get_tree().process_frame
	_on_fov_changed(camera_rig.camera.fov)

func _on_fov_changed(fov: float) -> void:
	var t: float = clamp((camera_rig.max_fov - fov) / (camera_rig.max_fov - camera_rig.min_fov), 0.0, 1.0)
	environment.background_energy_multiplier = lerp(min_opacity, max_opacity, pow(t, gamma))
