shader_type sky;
// Samples the Milky Way panorama from 4 quadrant tiles instead of one texture, so the
// full 6000x3000 source resolution can be used without exceeding the ~4096px single-
// texture dimension cap common on Android GPUs (each tile is 3000x1500).
//
// eso0932a's internal orientation (which way is "up", where longitude 0 falls, any
// mirroring) isn't documented, so the equatorial-frame view direction needs a fixed
// calibration rotation before it can index the image. IMG_ROW0/1/2 are the rows of
// that rotation matrix, found by clicking 3 widely-spread real stars (Antares, Vega,
// Sirius) in the rendered photo, pairing each click's image pixel against that star's
// real catalog RA/Dec, and solving the best-fit rotation via SVD (Kabsch/Wahba).
// image_dir(px,py) convention: colatitude = (py/3000)*PI from image row 0, azimuth =
// (px/6000)*2*PI from image column 0; IMG_ROW* maps an equatorial direction into that
// same frame, so the inverse (colatitude/azimuth of IMG_ROW*.dir) gives back px,py.
//
// EYEDIR arrives here in plain WORLD space -- Environment.sky_rotation does NOT drive
// a custom shader_type sky material's EYEDIR (confirmed empirically: with sky_rotation
// set, the rendered background matched the *un-rotated* world ray, not the rotated
// one). So equatorial_from_world is supplied explicitly as a uniform instead, kept in
// sync with SkyRoot's basis every tick from SkyRoot.gd -- the same un-rotation
// CameraRig.gd's screen_point_to_ra_dec does for tap hit-testing.

// Uniforms (not consts) with defaults so MilkywayTuner.gd can drive live adjustments
// during manual calibration without a shader recompile; scripts/DebugClickLogger.gd's
// hardcoded copy and these defaults must both be updated together when a tuning
// session finalizes new values.
uniform vec3 IMG_ROW0 = vec3(0.002808, 0.455148, 0.890415);
uniform vec3 IMG_ROW1 = vec3(-0.876924, 0.429086, -0.216565);
uniform vec3 IMG_ROW2 = vec3(-0.480632, -0.780211, 0.400337);

// A reflection (mirrored source photo) can never be reached by IMG_ROW alone -- that's
// a pure rotation (det=+1) by construction (Kabsch/Wahba fit, or MilkywayTuner.gd's
// live adjustments, both only ever compose rotations). If the photo is actually
// mirrored relative to the star catalog, no amount of rotation-only tuning converges;
// MIRROR flips image longitude first so the rest of the fit is searching the right
// (proper, non-reflected) space.
uniform bool MIRROR = true;

uniform mat3 equatorial_from_world;
uniform sampler2D tile_c0_r0 : source_color, filter_linear, repeat_disable;
uniform sampler2D tile_c1_r0 : source_color, filter_linear, repeat_disable;
uniform sampler2D tile_c0_r1 : source_color, filter_linear, repeat_disable;
uniform sampler2D tile_c1_r1 : source_color, filter_linear, repeat_disable;

void sky() {
	vec3 dir = normalize(equatorial_from_world * EYEDIR);
	vec3 img = vec3(dot(dir, IMG_ROW0), dot(dir, IMG_ROW1), dot(dir, IMG_ROW2));

	float v = clamp(acos(clamp(img.y, -1.0, 1.0)) / PI, 0.0, 1.0);
	float u = fract(atan(img.z, img.x) / (2.0 * PI));
	if (MIRROR) {
		u = fract(1.0 - u);
	}

	vec2 local_uv = vec2(fract(u * 2.0), fract(v * 2.0));

	vec3 color;
	if (u < 0.5 && v < 0.5) {
		color = texture(tile_c0_r0, local_uv).rgb;
	} else if (u >= 0.5 && v < 0.5) {
		color = texture(tile_c1_r0, local_uv).rgb;
	} else if (u < 0.5 && v >= 0.5) {
		color = texture(tile_c0_r1, local_uv).rgb;
	} else {
		color = texture(tile_c1_r1, local_uv).rgb;
	}

	COLOR = color;
}
