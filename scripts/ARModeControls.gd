extends Control
## Wires the AR ("point the phone at the sky") toggle button: sensor-availability
## gate, GameState persistence, and a one-time calibration hint on first enable.
## Hidden entirely in Quiz mode -- pan_to_ra_dec's reveal-pan is disabled under AR,
## so CameraRig forces AR off there too (see CameraRig._ready).

@onready var camera_rig: CameraRig = $"../../CameraRig"
@onready var button: Button = $ARButton
@onready var message_label: Label = $ARMessageLabel

var _shown_calibration_hint := false
var _message_token := 0

func _ready() -> void:
	if GameState.mode == GameState.Mode.QUIZ:
		visible = false
		return
	message_label.visible = false
	_refresh_button_text()
	button.pressed.connect(_on_button_pressed)

func _on_button_pressed() -> void:
	if camera_rig.ar_mode_enabled:
		camera_rig.set_ar_mode(false)
		GameState.ar_mode_enabled = false
		_refresh_button_text()
		return
	# Turn AR on optimistically rather than gating on an instant sensor check --
	# Android's sensor listeners only start delivering values a few frames after
	# being requested, so a synchronous has_ar_sensors() right on the button press
	# reads a stale zero vector even on hardware with a working compass. Give it a
	# grace window before concluding sensors are genuinely absent (e.g. desktop).
	camera_rig.set_ar_mode(true)
	GameState.ar_mode_enabled = true
	_refresh_button_text()
	if not await _wait_for_sensors():
		camera_rig.set_ar_mode(false)
		GameState.ar_mode_enabled = false
		_refresh_button_text()
		_show_message("Compass not available on this device")
		return
	if not _shown_calibration_hint:
		_shown_calibration_hint = true
		_show_message("Move your phone in a figure-8 to calibrate the compass", 4.0)

func _wait_for_sensors(timeout_sec: float = 1.5) -> bool:
	var elapsed := 0.0
	while elapsed < timeout_sec:
		if camera_rig.has_ar_sensors():
			return true
		await get_tree().create_timer(0.1).timeout
		elapsed += 0.1
	return camera_rig.has_ar_sensors()

func _refresh_button_text() -> void:
	button.text = "AR: On" if camera_rig.ar_mode_enabled else "AR: Off"
	button.button_pressed = camera_rig.ar_mode_enabled

func _show_message(text: String, duration: float = 2.5) -> void:
	message_label.text = text
	message_label.visible = true
	_message_token += 1
	var token := _message_token
	await get_tree().create_timer(duration).timeout
	if token == _message_token:
		message_label.visible = false
