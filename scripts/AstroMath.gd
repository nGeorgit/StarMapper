class_name AstroMath
extends RefCounted
## Static utility, no autoload needed: equatorial coordinate <-> Cartesian conversion.
## RA/Dec are stored in the data files as decimal degrees.
## Convention: Y-up, star sphere centered at world origin, radius = SKY_RADIUS.

const SKY_RADIUS := 1000.0

static func ra_dec_to_vector3(ra_deg: float, dec_deg: float, radius: float = SKY_RADIUS) -> Vector3:
	var ra := deg_to_rad(ra_deg)
	var dec := deg_to_rad(dec_deg)
	var x := cos(dec) * cos(ra)
	var z := cos(dec) * sin(ra)
	var y := sin(dec)
	return Vector3(x, y, z) * radius

## Inverse of ra_dec_to_vector3, used to test where on the sky a screen click landed.
static func vector3_to_ra_dec(v: Vector3) -> Vector2:
	var n := v.normalized()
	var dec := asin(clamp(n.y, -1.0, 1.0))
	var ra := atan2(n.z, n.x)
	if ra < 0.0:
		ra += TAU
	return Vector2(rad_to_deg(ra), rad_to_deg(dec))

## Angular separation between two RA/Dec points, in degrees. Used for hit-testing
## and for the spherical point-in-polygon check against constellation boundaries.
static func angular_separation_deg(ra1: float, dec1: float, ra2: float, dec2: float) -> float:
	var a := ra_dec_to_vector3(ra1, dec1, 1.0)
	var b := ra_dec_to_vector3(ra2, dec2, 1.0)
	return rad_to_deg(a.angle_to(b))

## Angular distance from (ra, dec) to the nearest point on the great-circle arc between
## (ra1, dec1) and (ra2, dec2), in degrees. Used for hit-testing taps against constellation
## lines: distance to the two endpoints alone under-counts a tap that lands mid-line.
static func angular_dist_to_segment_deg(ra_deg: float, dec_deg: float, ra1_deg: float, dec1_deg: float, ra2_deg: float, dec2_deg: float) -> float:
	var p := ra_dec_to_vector3(ra_deg, dec_deg, 1.0)
	var a := ra_dec_to_vector3(ra1_deg, dec1_deg, 1.0)
	var b := ra_dec_to_vector3(ra2_deg, dec2_deg, 1.0)

	var n := a.cross(b)
	if n.length() < 1e-9:
		return rad_to_deg(p.angle_to(a))  # degenerate (coincident) segment
	n = n.normalized()

	var p_proj_raw := p - n * p.dot(n)
	if p_proj_raw.length() < 1e-9:
		return rad_to_deg(p.angle_to(a))  # p sits exactly on the great circle's pole
	var p_proj := p_proj_raw.normalized()  # closest point on the full great circle to p

	var seg_angle := a.angle_to(b)
	var a_to_proj := a.angle_to(p_proj)
	var proj_to_b := p_proj.angle_to(b)

	if absf(a_to_proj + proj_to_b - seg_angle) < 1e-4:
		return rad_to_deg(p.angle_to(p_proj))  # projection falls within the arc
	return rad_to_deg(minf(p.angle_to(a), p.angle_to(b)))  # falls outside -> nearest endpoint

## Average unit-vector direction of a constellation's line-segment endpoints, converted
## back to RA/Dec. Used as that constellation's "center" for altitude/visibility checks.
static func constellation_center(segments: Array) -> Vector2:
	var center_sum := Vector3.ZERO
	for seg in segments:
		center_sum += ra_dec_to_vector3(seg[0], seg[1], 1.0)
		center_sum += ra_dec_to_vector3(seg[2], seg[3], 1.0)
	return vector3_to_ra_dec(center_sum.normalized())

## Julian Date (UT) from a Unix timestamp. JD is the day-count astronomical formulas
## (GMST, precession, etc.) are built on.
static func julian_date_from_unix(unix_time: float) -> float:
	return unix_time / 86400.0 + 2440587.5

## Greenwich Mean Sidereal Time, in degrees [0, 360), from Julian Date. Meeus' low-precision
## GMST polynomial — plenty accurate for a sky viewer (arcsecond-level terms dropped).
static func gmst_deg(jd: float) -> float:
	var d := jd - 2451545.0
	var t := d / 36525.0
	var gmst := 280.46061837 + 360.98564736629 * d + 0.000387933 * t * t - t * t * t / 38710000.0
	gmst = fmod(gmst, 360.0)
	if gmst < 0.0:
		gmst += 360.0
	return gmst

## Local Sidereal Time, in degrees [0, 360). lon_deg is east-positive, matching
## ordinary lat/lon convention. LST is the RA currently on the observer's meridian —
## the anchor that ties the fixed RA/Dec star catalogue to the current moment.
static func lst_deg(jd: float, lon_deg: float) -> float:
	var lst := fmod(gmst_deg(jd) + lon_deg, 360.0)
	if lst < 0.0:
		lst += 360.0
	return lst

## Rotation that carries the RA/Dec sphere (as built by ra_dec_to_vector3, where world
## Y = north celestial pole) into the observer's local Alt/Az frame, where world Y =
## zenith, -Z = due north, +X = due east. Apply this as a parent Node3D's basis rather
## than transforming every star: same result, one matrix instead of thousands.
##
## Derivation: (1) spin the sphere about the polar axis (Y) by the local sidereal time,
## which brings the meridian (hour angle 0) onto the X axis; (2) tip that frame about
## its now-fixed east-west axis (Z) by (90 - latitude), which brings the zenith (fixed
## at hour-angle 0, declination = latitude) onto Y; (3) swap X/Z, because step 1's
## RA-increases-toward-Z handedness comes out mirrored against the usual compass sense
## (azimuth clockwise from north) — swapping fixes east/west without disturbing the
## already-correct zenith/altitude. Verified numerically against known cases (zenith,
## Polaris altitude ≈ latitude, meridian transit altitude = 90 - lat, due-east/west
## horizon stars) before writing this comment.
static func horizontal_basis(lat_deg: float, lst_deg_val: float) -> Basis:
	var spin := Basis(Vector3.UP, deg_to_rad(lst_deg_val))
	var tip := Basis(Vector3.BACK, deg_to_rad(90.0 - lat_deg))
	var swap := Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(1, 0, 0))
	return swap * tip * spin
