extends PanelContainer
## Dev/debug panel (explore mode) for visually assessing star realism against a
## reference (e.g. Stellarium) without recompiling: toggle constellation lines/
## labels and star names, and live-tune StarField's color/size/brightness/density
## curves. Hidden by default; a button in the UI toggles it. Built entirely in code
## so the scene file only needs one extra button + this empty container.

@onready var star_field: StarField = $"../../SkyRoot/StarField"
@onready var constellation_lines: MultiMeshInstance3D = $"../../SkyRoot/ConstellationLines"
@onready var star_labels: Node3D = $"../../SkyRoot/StarLabels"
@onready var constellation_name_labels: Node3D = $"../../SkyRoot/ConstellationNameLabels"
@onready var constellation_art: Node3D = $"../../SkyRoot/ConstellationArt"
@onready var alt_az_grid: MultiMeshInstance3D = $"../../AltAzGrid"
@onready var compass_labels: Node3D = $"../../CompassLabels"
@onready var observer_info_label: Label = $"../ObserverInfoLabel"
@onready var toggle_button: Button = $"../SettingsButton"

func _ready() -> void:
	visible = false
	if GameState.mode == GameState.Mode.QUIZ:
		toggle_button.visible = false  # this is an explore-mode debug panel; nothing here belongs in a quiz
		return
	custom_minimum_size = Vector2(578, 0)
	add_theme_stylebox_override("panel", _panel_style())
	_build_ui()
	toggle_button.pressed.connect(func(): visible = not visible)

func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.08, 0.92)
	sb.set_content_margin_all(16)
	sb.set_corner_radius_all(8)
	return sb

func _build_ui() -> void:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 0)
	add_child(scroll)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	scroll.add_child(root)

	root.add_child(_heading("Constellation Set"))
	root.add_child(_constellation_set_button())
	root.add_child(HSeparator.new())

	root.add_child(_heading("Realism Settings"))

	root.add_child(_checkbox("Rendered stars", star_field.visible, func(v): star_field.visible = v))
	root.add_child(_checkbox("Constellation lines", constellation_lines.visible, func(v): constellation_lines.visible = v))
	root.add_child(_checkbox("Constellation names", constellation_name_labels.visible, func(v): constellation_name_labels.visible = v))
	root.add_child(_checkbox("Star names", star_labels.visible, func(v): star_labels.visible = v))
	root.add_child(_checkbox("Constellation art", constellation_art.visible, func(v): constellation_art.visible = v))
	root.add_child(_checkbox("Azimuth grid", alt_az_grid.visible, func(v): alt_az_grid.visible = v))
	root.add_child(_checkbox("Compass letters", compass_labels.visible, func(v): compass_labels.visible = v))
	root.add_child(_checkbox("Observer info", observer_info_label.visible, func(v): observer_info_label.visible = v))

	if GameState.dev_mode:
		root.add_child(HSeparator.new())
		root.add_child(_heading("Color"))
		root.add_child(_slider("Color saturation", 0.0, 1.0, 1.0 - star_field.desaturate_dim_stars, func(v):
			star_field.desaturate_dim_stars = 1.0 - v
			star_field.refresh_visuals()
		))

		root.add_child(HSeparator.new())
		root.add_child(_heading("Brightness"))
		root.add_child(_slider("Brightness contrast", 0.2, 2.0, star_field.alpha_gamma, func(v):
			star_field.alpha_gamma = v
			star_field.refresh_visuals()
		))
		root.add_child(_slider("Minimum brightness", 0.0, 1.0, star_field.min_visible_alpha, func(v):
			star_field.min_visible_alpha = v
			star_field.refresh_visuals()
		))
		root.add_child(_slider("Brightness boost (bright stars)", 0.0, 2.0, star_field.brightness_boost, func(v):
			star_field.brightness_boost = v
			star_field.refresh_visuals()
		))

		root.add_child(HSeparator.new())
		root.add_child(_heading("Size / Halo"))
		root.add_child(_slider("Halo point size", 3.0, 24.0, star_field.base_point_size, func(v):
			star_field.set_base_point_size(v)
		))
		root.add_child(_slider("Max star size", 1.0, 14.0, star_field.max_scale, func(v):
			star_field.max_scale = v
			star_field.refresh_visuals()
		))
		root.add_child(_slider("Min star size", 0.05, 3.0, star_field.min_visible_scale, func(v):
			star_field.min_visible_scale = v
			star_field.refresh_visuals()
		))
		root.add_child(_slider("Size contrast", 0.5, 5.0, star_field.size_gamma, func(v):
			star_field.size_gamma = v
			star_field.refresh_visuals()
		))

		root.add_child(HSeparator.new())
		root.add_child(_heading("Star density vs. zoom"))
		root.add_child(_slider("Zoomed-out cutoff (mag)", -1.0, 6.5, star_field.zoomed_out_mag_cutoff, func(v):
			star_field.zoomed_out_mag_cutoff = v
			star_field.reapply_mag_cutoff()
		))
		root.add_child(_slider("Naked-eye cap (mag)", 2.0, 8.0, star_field.faintest_mag, func(v):
			star_field.faintest_mag = v
			star_field.reload()
		))

## Sky-culture picker: switches ConstellationLines/StarField/ConstellationNameLabels
## live and persists the choice as the startup default (ConstellationSets.set_active).
## A native OptionButton's dropdown is unusably small with 30+ cultures on a touch
## screen, so this opens a full-screen list of big tappable rows instead.
var _culture_button: Button

func _constellation_set_button() -> Button:
	var btn := Button.new()
	btn.mouse_filter = Control.MOUSE_FILTER_PASS  # let touch-drag bubble to ScrollContainer for scrolling
	btn.custom_minimum_size = Vector2(0, 68)
	btn.add_theme_font_size_override("font_size", 22)
	_culture_button = btn
	_refresh_culture_button_text()
	btn.pressed.connect(_open_culture_picker)
	ConstellationSets.set_changed.connect(_refresh_culture_button_text)
	return btn

func _refresh_culture_button_text() -> void:
	for entry in ConstellationSets.available:
		if entry["id"] == ConstellationSets.active_id:
			_culture_button.text = "%s (%s)" % [entry["name"], entry["region"]]
			return
	_culture_button.text = "Constellation Set"

func _open_culture_picker() -> void:
	get_parent().add_child(_build_culture_overlay())

func _build_culture_overlay() -> Control:
	var overlay := Control.new()
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := ColorRect.new()
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.color = Color(0.0, 0.0, 0.02, 0.98)
	overlay.add_child(bg)

	var root := VBoxContainer.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.offset_left = 40
	root.offset_top = 60
	root.offset_right = -40
	root.offset_bottom = -40
	root.add_theme_constant_override("separation", 20)
	overlay.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	root.add_child(header)

	var title := Label.new()
	title.text = "Constellation Set"
	title.add_theme_font_size_override("font_size", 40)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(120, 68)
	close_btn.add_theme_font_size_override("font_size", 24)
	close_btn.pressed.connect(overlay.queue_free)
	header.add_child(close_btn)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 20)
	scroll.add_child(list)

	for entry in ConstellationSets.available:
		var item := Button.new()
		item.custom_minimum_size = Vector2(0, 90)
		item.add_theme_font_size_override("font_size", 28)
		item.text = "%s (%s)" % [entry["name"], entry["region"]]
		item.mouse_filter = Control.MOUSE_FILTER_PASS  # let touch-drag bubble to ScrollContainer for scrolling
		item.pressed.connect(_on_culture_picked.bind(entry["id"], overlay))
		list.add_child(item)

	return overlay

func _on_culture_picked(id: String, overlay: Control) -> void:
	ConstellationSets.set_active(id)
	overlay.queue_free()

func _heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	return l

func _checkbox(label_text: String, initial: bool, on_toggled: Callable) -> CheckBox:
	var cb := CheckBox.new()
	cb.mouse_filter = Control.MOUSE_FILTER_PASS  # let touch-drag bubble to ScrollContainer for scrolling
	cb.text = label_text
	cb.button_pressed = initial
	cb.toggled.connect(on_toggled)
	return cb

## Builds a "label (value)" + HSlider pair wrapped in a VBoxContainer, calling
## on_changed(value) live as the slider is dragged (not just on release), so the
## sky updates in real time while comparing against a reference image.
func _slider(label_text: String, min_v: float, max_v: float, initial: float, on_changed: Callable) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)

	var label := Label.new()
	label.text = "%s: %.2f" % [label_text, initial]
	box.add_child(label)

	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = (max_v - min_v) / 200.0
	slider.value = initial
	slider.value_changed.connect(func(v):
		label.text = "%s: %.2f" % [label_text, v]
		on_changed.call(v)
	)
	box.add_child(slider)
	return box
