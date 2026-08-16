extends Node
## Quiz-mode game loop: pick quiz_round_total random constellations (no repeats),
## show each name, wait for a tap, check whether it landed close enough to that
## constellation's stars. No-ops (beyond wiring the back button) in explore mode.
##
## v1 hit-test uses angular distance to the nearest line-segment point as a stand-in
## for a real point-in-spherical-polygon test. Swap in constellation boundary data
## (parsed from Stellarium's constellations_boundaries.dat) later for precise hits.

signal round_result(correct: bool, constellation_name: String)

@export var hit_threshold_deg := 6.0
@export var tap_move_tolerance_px := 20.0  ## press-release drift under this counts as a tap, not a pan
@export var quiz_round_total := 10
@export var min_visible_altitude_deg := 10.0  ## constellation center must be at least this high to be quizzed
@export var reveal_pause_sec := 2.0  ## time the pan-to-target + highlight stays up before advancing

@onready var camera_rig: CameraRig = $"../CameraRig"
@onready var constellation_lines: MultiMeshInstance3D = $"../SkyRoot/ConstellationLines"
@onready var target_label: Label = $"../UI/TargetLabel"
@onready var feedback_label: Label = $"../UI/FeedbackLabel"
@onready var back_button: Button = $"../UI/BackButton"
@onready var results_panel: Control = $"../UI/ResultsPanel"
@onready var results_label: Label = $"../UI/ResultsPanel/ResultsLabel"
@onready var play_again_button: Button = $"../UI/ResultsPanel/PlayAgainButton"
@onready var menu_button: Button = $"../UI/ResultsPanel/MenuButton"

var _target: Dictionary = {}
var _press_pos := Vector2.ZERO
var _quiz_pool: Array = []
var _round_index := 0  ## how many rounds have been started
var _correct_count := 0
var _quiz_done := false
var _accepting_input := true  ## false while a wrong-answer message is showing, to block double taps

func _ready() -> void:
	back_button.pressed.connect(_go_to_menu)
	results_panel.visible = false

	if GameState.mode != GameState.Mode.QUIZ:
		target_label.visible = false
		feedback_label.visible = false
		return

	play_again_button.pressed.connect(_restart_quiz)
	menu_button.pressed.connect(_go_to_menu)

	await get_tree().process_frame  # let ConstellationLines finish loading its JSON first
	_quiz_pool = _visible_constellations()
	_quiz_pool.shuffle()
	_quiz_pool = _quiz_pool.slice(0, quiz_round_total)
	_start_round()

## Only constellations currently up (center above min_visible_altitude_deg for this
## observer's location/time) are fair quiz questions — no asking to find something
## that's below the horizon right now.
func _visible_constellations() -> Array:
	var visible: Array = []
	for c in constellation_lines.constellations:
		var center: Vector2 = c["center"]
		if Observer.altitude_deg(center.x, center.y) >= min_visible_altitude_deg:
			visible.append(c)
	return visible

func _go_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _restart_quiz() -> void:
	_round_index = 0
	_correct_count = 0
	_quiz_done = false
	results_panel.visible = false
	target_label.visible = true
	feedback_label.visible = true
	_quiz_pool = _visible_constellations()
	_quiz_pool.shuffle()
	_start_round()

func _start_round() -> void:
	_accepting_input = true
	if _round_index >= _quiz_pool.size():
		_show_results()
		return
	_target = _quiz_pool[_round_index]
	feedback_label.text = ""
	target_label.text = "Find %d/%d: %s" % [_round_index + 1, _quiz_pool.size(), _target["name"]]

func _show_results() -> void:
	_quiz_done = true
	constellation_lines.clear_highlight()
	target_label.visible = false
	feedback_label.visible = false
	results_panel.visible = true
	results_label.text = "You found %d/%d constellations!" % [_correct_count, _quiz_pool.size()]

func _unhandled_input(event: InputEvent) -> void:
	if GameState.mode != GameState.Mode.QUIZ or _quiz_done or not _accepting_input:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_pos = event.position
		elif _press_pos.distance_to(event.position) <= tap_move_tolerance_px:
			_check_tap(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_press_pos = event.position
		elif _press_pos.distance_to(event.position) <= tap_move_tolerance_px:
			_check_tap(event.position)

func _check_tap(screen_pos: Vector2) -> void:
	if _target.is_empty():
		return
	var ra_dec := camera_rig.screen_point_to_ra_dec(screen_pos)
	var correct := _is_within_target(ra_dec.x, ra_dec.y)
	round_result.emit(correct, _target["name"])

	if correct:
		feedback_label.text = "Correct!"
		_correct_count += 1
	else:
		var picked := _find_constellation_at(ra_dec.x, ra_dec.y)
		if picked.is_empty():
			feedback_label.text = "Wrong — that wasn't %s" % _target["name"]
		else:
			feedback_label.text = "Wrong — that's %s, not %s" % [picked["name"], _target["name"]]

	## Whatever they tapped, reveal the actual answer: pan it to center and light up
	## its lines, so a correct guess gets confirmed and a wrong one gets shown where.
	_accepting_input = false
	var center: Vector2 = _target["center"]
	camera_rig.pan_to_ra_dec(center.x, center.y)
	constellation_lines.highlight_constellation(_target["id"])
	_round_index += 1
	await get_tree().create_timer(reveal_pause_sec).timeout
	constellation_lines.clear_highlight()
	_start_round()

func _is_within_target(ra: float, dec: float) -> bool:
	return not _nearest_segment_dist(_target, ra, dec).is_empty()

## Finds whichever constellation (of all 88, not just the quiz pool) has a line
## segment closest to the tapped point, so a wrong answer can tell the player what
## they actually pointed at instead of just "wrong".
func _find_constellation_at(ra: float, dec: float) -> Dictionary:
	var best: Dictionary = {}
	var best_dist := INF
	for c in constellation_lines.constellations:
		var dist_info := _nearest_segment_dist(c, ra, dec)
		if not dist_info.is_empty() and dist_info["dist"] < best_dist:
			best_dist = dist_info["dist"]
			best = c
	return best

## Returns {"dist": float} if any segment endpoint of c is within hit_threshold_deg
## of (ra, dec), with "dist" the closest such distance; {} if none qualify.
func _nearest_segment_dist(c: Dictionary, ra: float, dec: float) -> Dictionary:
	var best_dist := INF
	for seg in c["segments"]:
		var d := AstroMath.angular_dist_to_segment_deg(ra, dec, seg[0], seg[1], seg[2], seg[3])
		best_dist = min(best_dist, d)
	if best_dist <= hit_threshold_deg:
		return {"dist": best_dist}
	return {}
