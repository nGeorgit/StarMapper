extends Node3D
## Parent of everything drawn in RA/Dec space (StarField, ConstellationLines,
## StarLabels, ConstellationNameLabels). Its basis is set to Observer.horizontal_basis()
## so the whole star sphere gets rotated from the fixed catalogue frame into the
## observer's live Alt/Az frame — one matrix update instead of re-transforming every
## star/label each tick.
##
## Recomputed on a timer rather than every frame: sidereal time only drifts ~15
## degrees/hour, so sub-second recomputation would be wasted work.

@export var update_interval_sec := 1.0

var _accum := 0.0

func _ready() -> void:
	_update_basis()

func _process(delta: float) -> void:
	_accum += delta
	if _accum < update_interval_sec:
		return
	_accum = 0.0
	_update_basis()

func _update_basis() -> void:
	basis = Observer.horizontal_basis()
