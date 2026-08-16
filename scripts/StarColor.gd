class_name StarColor
extends RefCounted
## Approximates a star's true visual color from its B-V color index (blue minus visual
## magnitude — negative/low = hot blue-white, high = cool red). Standard piecewise
## approximation used across amateur star-mapping tools.

static func bv_to_rgb(bv: float) -> Color:
	bv = clamp(bv, -0.4, 2.0)
	var r := 0.0
	var g := 0.0
	var b := 0.0
	if bv < 0.0:
		var t := (bv + 0.4) / 0.4
		r = 0.61 + 0.11 * t + 0.1 * t * t
		g = 0.70 + 0.07 * t - 0.1 * t * t
		b = 1.0
	elif bv < 0.4:
		var t := bv / 0.4
		r = 0.83 + 0.17 * t
		g = 0.87 + 0.11 * t
		b = 1.00 - 0.47 * t + 0.1 * t * t
	elif bv < 1.6:
		var t := (bv - 0.4) / 1.2
		r = 1.0
		g = 0.98 - 0.16 * t
		b = 0.53 - 0.05 * t
	else:
		var t := (bv - 1.6) / 0.4
		r = 1.00 - 0.47 * t + 0.1 * t * t
		g = 0.82 - 0.5 * t + 0.1 * t * t
		b = 0.0
	return Color(r, g, b)
