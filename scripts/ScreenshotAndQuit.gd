extends Node
## Dev-only helper, no-op unless launched with --screenshot: waits a few frames for
## rendering to settle, saves a PNG of the viewport, then quits. Lives permanently in
## the scene tree but does nothing during normal play.
##
## Optional --tap-test=X,Y additionally simulates a tap at that screen position a few
## frames in, then captures shortly after — lets quiz tap-handling (right/wrong feedback)
## be screenshot-verified from the terminal without a real pointer.
##
## Optional --look-star=NAME snaps the camera to stare directly at a named star before
## capturing — useful for a close, unambiguous look at one star's color/size/halo
## instead of hunting for it in a wide, time-of-day-dependent default view.

@export var frames_to_wait := 30
@export var post_tap_frames := 15
@export var out_path := "res://screenshot.png"

@onready var camera_rig: CameraRig = $"../CameraRig"
@onready var sky_root: Node3D = $"../SkyRoot"
@onready var star_field: StarField = $"../SkyRoot/StarField"
@onready var ground: MeshInstance3D = $"../Ground"

var _frame_count := 0
var _active := false
var _tap_pos := Vector2(-1, -1)
var _tap_frame := 5
var _tapped := false
var _look_star := ""

func _ready() -> void:
	_active = OS.get_cmdline_args().has("--screenshot")
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--tap-test="):
			var parts := arg.trim_prefix("--tap-test=").split(",")
			_tap_pos = Vector2(float(parts[0]), float(parts[1]))
		elif arg.begins_with("--look-star="):
			_look_star = arg.trim_prefix("--look-star=")
	set_process(_active)
	if _active and _look_star != "":
		_aim_at_star(_look_star)

func _aim_at_star(star_name: String) -> void:
	for s in star_field.loaded_stars:
		if s.get("name", "") == star_name:
			var eq_dir := AstroMath.ra_dec_to_vector3(s["ra"], s["dec"]).normalized()
			var world_dir := sky_root.global_transform.basis * eq_dir
			camera_rig.transform.basis = Basis.looking_at(world_dir, Vector3.UP)
			camera_rig.camera.fov = 20.0
			ground.visible = false  # star may be below the horizon at the current sim time
			print("ScreenshotAndQuit: aimed at %s (mag=%s ci=%s)" % [star_name, s["mag"], s.get("ci", "?")])
			var viewport_center := get_viewport().get_visible_rect().size / 2.0
			var recovered := camera_rig.screen_point_to_ra_dec(viewport_center)
			print("ScreenshotAndQuit: tap-math check at screen center -> ra=%.3f dec=%.3f (actual ra=%.3f dec=%.3f, should match closely since camera is centered on the star)" % [recovered.x, recovered.y, s["ra"], s["dec"]])
			return
	push_warning("ScreenshotAndQuit: star '%s' not found" % star_name)

func _process(_delta: float) -> void:
	_frame_count += 1

	if _tap_pos.x >= 0.0 and not _tapped and _frame_count == _tap_frame:
		_tapped = true
		_simulate_tap(_tap_pos)

	var target_frame := (_tap_frame + post_tap_frames) if _tap_pos.x >= 0.0 else frames_to_wait
	if _frame_count >= target_frame:
		var img := get_viewport().get_texture().get_image()
		img.save_png(out_path)
		print("Screenshot saved to %s" % out_path)
		get_tree().quit()

func _simulate_tap(pos: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = pos
	Input.parse_input_event(press)
	var release: InputEventMouseButton = press.duplicate()
	release.pressed = false
	Input.parse_input_event(release)
