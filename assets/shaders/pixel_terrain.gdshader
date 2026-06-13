shader_type canvas_item;

// Draws the terrain straight from the gameplay solidity mask (sprite TEXTURE,
// L8) + material map. Everything is generated in WORLD pixel coordinates, so
// the dirt fill is seamless across the whole level — no 16px tile repetition —
// and the grass band follows the actual ground contour, slopes included.

uniform sampler2D material_tex : filter_nearest; // 0 dirt, 0.5 wood, 1 steel
// Snapshot of the mask at level load. Grass is computed against THIS, not the
// live mask, so freshly carved passages (basher/miner/digger/bomber) expose
// bare dirt instead of sprouting grass along the cut.
uniform sampler2D orig_mask : filter_linear;

// Palette (tuned to the original game's warm dirt + bright grass).
uniform vec3 dirt_light  : source_color = vec3(0.78, 0.58, 0.32);
uniform vec3 dirt_mid    : source_color = vec3(0.58, 0.40, 0.20);
uniform vec3 dirt_dark   : source_color = vec3(0.38, 0.24, 0.10);
uniform vec3 dirt_deep   : source_color = vec3(0.22, 0.14, 0.06);
uniform vec3 grass_hi    : source_color = vec3(0.55, 0.93, 0.27);
uniform vec3 grass_lo    : source_color = vec3(0.22, 0.62, 0.12);
uniform vec3 wood_light  : source_color = vec3(0.76, 0.55, 0.28);
uniform vec3 wood_dark   : source_color = vec3(0.50, 0.32, 0.13);
uniform vec3 wood_seam   : source_color = vec3(0.30, 0.18, 0.07);
uniform vec3 steel_light : source_color = vec3(0.66, 0.69, 0.74);
uniform vec3 steel_dark  : source_color = vec3(0.42, 0.45, 0.51);
uniform vec3 steel_seam  : source_color = vec3(0.24, 0.26, 0.31);
uniform vec3 oneway_col  : source_color = vec3(0.93, 0.78, 0.20);

// Optional charred-rock overlay (inferno): a tiling basalt + lava-crack texture
// blended over the procedural dirt. rock_mix = 0 (the default) disables it, so
// every other theme keeps the painted-palette look untouched.
uniform sampler2D rock_tex : filter_linear, repeat_enable;
uniform float rock_mix : hint_range(0.0, 1.0) = 0.0;
uniform float rock_scale = 110.0;

const float EPS = 0.47; // must match PixelTerrain.SOLID_EPS

varying vec2 wpos;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	float m = texture(TEXTURE, UV).r;
	float aa = max(fwidth(m), 1e-4);
	float alpha = smoothstep(EPS - aa, EPS + aa, m);
	if (alpha < 0.01) {
		discard;
	}

	float mat = texture(material_tex, UV).r;

	// Distance to the ORIGINAL surface straight above (px of pre-carve air
	// within reach). Drives a chunky grass band that hugs the authored contour
	// — thicker on slopes, like the original — plus a dark soil shadow right
	// beneath it. Sampling the snapshot (not the live mask) keeps carved
	// passages bare: their pixels were deep inside the original ground.
	float air5 = 0.0;
	for (int k = 1; k <= 5; k++) {
		air5 += step(texture(orig_mask, UV - vec2(0.0, float(k) * px.y)).r, EPS);
	}
	float air8 = step(texture(orig_mask, UV - vec2(0.0, 7.0 * px.y)).r, EPS)
	           + step(texture(orig_mask, UV - vec2(0.0, 9.0 * px.y)).r, EPS);
	// Air near the sides/bottom → darker rim, gives the silhouette a drawn
	// outline like the original art.
	float air_rim = 0.0;
	air_rim += step(texture(TEXTURE, UV + vec2( 2.0 * px.x, 0.0)).r, EPS);
	air_rim += step(texture(TEXTURE, UV + vec2(-2.0 * px.x, 0.0)).r, EPS);
	air_rim += step(texture(TEXTURE, UV + vec2(0.0,  2.0 * px.y)).r, EPS);

	// ── Dirt: bold world-space blotches + strata, no grid anywhere ──
	float n_big = vnoise(wpos / 19.0);
	float n_mid = vnoise(wpos / 7.0);
	float strata = vnoise(vec2(wpos.x / 30.0, wpos.y / 6.0)); // stretched horizontal veins
	vec3 col = mix(dirt_mid, dirt_light, smoothstep(0.58, 0.92, n_big) * 0.75);
	col = mix(col, dirt_dark, smoothstep(0.50, 0.82, n_mid) * 0.9);
	col = mix(col, dirt_deep, smoothstep(0.68, 0.95, strata) * 0.75);
	col = mix(col, dirt_light, smoothstep(0.82, 0.98, vnoise(wpos / 4.5)) * 0.35);
	float speck = hash21(floor(wpos));
	if (speck > 0.97) {
		col = dirt_deep;
	} else if (speck < 0.02) {
		col = dirt_light;
	}

	// Charred-rock overlay (inferno only — rock_mix stays 0 elsewhere). The
	// procedural noise rides along as a subtle brightness wobble so the tiling
	// doesn't read as a flat repeat. Surface crust / wood / steel branches below
	// still override this, so only the deep body becomes basalt.
	if (rock_mix > 0.001) {
		vec3 rock = texture(rock_tex, wpos / rock_scale).rgb;
		col = mix(col, rock * (0.9 + 0.45 * (n_big - 0.5)), rock_mix);
	}

	// ── Wood (builder planks): band around 0.5 ──
	if (mat > 0.45 && mat < 0.7) {
		float grain = vnoise(vec2(wpos.x * 0.6, wpos.y * 2.1));
		float row = floor(wpos.y / 8.0);
		float seam_h = step(mod(wpos.y, 8.0), 1.0);
		float seam_v = step(mod(wpos.x + mod(row, 2.0) * 8.0, 16.0), 1.0);
		col = mix(wood_light, wood_dark, grain);
		col = mix(col, wood_seam, max(seam_h, seam_v));
	}
	// ── One-way walls (0.2 right / 0.35 left): dirt base + chevron arrows ──
	else if (mat > 0.12 && mat < 0.45) {
		// '>' points where x ≡ -|dy| (mod period); flip the sign for '<'.
		float ow = (mat < 0.28) ? 1.0 : -1.0;
		float chev = step(mod(wpos.x + ow * abs(mod(wpos.y, 12.0) - 6.0), 16.0), 3.5);
		col = mix(col, dirt_deep, 0.35);
		col = mix(col, oneway_col, chev * 0.9);
	}
	// ── Steel plates ──
	else if (mat >= 0.85) {
		float plate = vnoise(wpos / 11.0);
		float seam = max(step(mod(wpos.x, 16.0), 1.0), step(mod(wpos.y, 16.0), 1.0));
		col = mix(steel_light, steel_dark, plate);
		col = mix(col, steel_seam, seam);
		vec2 cp = mod(wpos, 16.0);
		if (length(cp - vec2(4.0, 4.0)) < 1.4 || length(cp - vec2(12.0, 4.0)) < 1.4) {
			col = steel_light * 1.18;
		}
	}
	// ── Grass on dirt surfaces: solid green band + dark soil line beneath ──
	else {
		// Ragged blade edge: per-column noise nudges how deep the green goes.
		float ragged = hash21(vec2(floor(wpos.x), floor(wpos.y / 64.0)));
		float band = 4.0 + 2.0 * ragged;          // grass depth 4-6px per column
		float depth = 5.0 - air5;                  // ~px below the surface (0..5)
		if (air5 > 0.5 && depth < band) {
			vec3 grass = mix(grass_hi, grass_lo, smoothstep(0.0, band, depth));
			col = grass;
			if (air5 > 4.5) {
				col = mix(col, grass_hi, 0.6);     // bright tips at the very edge
			}
		} else if (air5 > 0.5 || air8 > 0.5) {
			// Soil shadow: dark transition between grass roots and dirt.
			col = mix(col, dirt_deep, 0.65);
		}
	}

	// Rim shading on exposed sides/undersides.
	col = mix(col, col * 0.42, clamp(air_rim, 0.0, 1.0) * 0.85);

	COLOR = vec4(col, alpha);
}
