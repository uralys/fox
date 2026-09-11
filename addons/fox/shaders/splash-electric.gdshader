shader_type canvas_item;

// Electric short-circuit crackle for the splash logo. Drive `intensity` 0 -> 1
// to ramp the effect in; all motion is TIME-based so the logo keeps crackling
// while `intensity` is held. Respects the incoming modulate alpha (fade-out).

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 arc_color : source_color = vec4(0.6, 0.95, 1.0, 1.0);
uniform float slice_count = 32.0;
uniform float jitter_strength = 0.14;
uniform float rgb_split = 0.026;
uniform float bloom_radius = 0.05;
uniform float bloom_strength = 0.9;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	float mod_a = COLOR.a;

	// Quantise time into ~28 fps steps so the glitch snaps rather than slides.
	float t = floor(TIME * 28.0);

	// Per-slice horizontal tear: a few horizontal bands jolt sideways, each
	// re-randomised every step. A threshold keeps most slices still so the
	// tear reads as sparse electric jolts, not a uniform blur.
	float slice = floor(UV.y * slice_count);
	float r = hash(vec2(slice, t));
	float band = step(0.5, hash(vec2(slice, t + 1.0)));
	float shift = (r - 0.5) * 2.0 * jitter_strength * band * intensity;

	vec2 uv = UV;
	uv.x += shift;

	// Chromatic RGB split scaled by intensity.
	float split = rgb_split * intensity;
	float cr = texture(TEXTURE, uv + vec2(split, 0.0)).r;
	float cg = texture(TEXTURE, uv).g;
	float cb = texture(TEXTURE, uv - vec2(split, 0.0)).b;
	float a = texture(TEXTURE, uv).a;
	float ar = texture(TEXTURE, uv + vec2(split, 0.0)).a;
	float ab = texture(TEXTURE, uv - vec2(split, 0.0)).a;
	vec3 col = vec3(cr, cg, cb);
	float alpha = max(a, max(ar, ab));

	// Electric brightness jolt + cyan arc tint on the torn bands.
	float flash = hash(vec2(t, 7.3));
	float jolt = 1.0 + intensity * step(0.45, flash) * (1.1 + r * 1.6);
	col *= jolt;
	col = mix(col, arc_color.rgb * max(col.r, max(col.g, col.b)), intensity * 0.6 * band);

	// Electric edge bloom: dilate the silhouette outward so the text edges
	// bleed into a crackling cyan halo and the logo appears to swell as the
	// effect ramps. Sample alpha on a ring scaled by intensity; the ring is
	// jittered per step so the dilated edge looks ragged, not a clean outline.
	float reach = bloom_radius * intensity;
	float bloom = 0.0;
	for (int i = 0; i < 8; i++) {
		float ang = float(i) / 8.0 * 6.2831853;
		float j = 0.5 + 0.5 * hash(vec2(float(i), t));
		vec2 off = vec2(cos(ang), sin(ang)) * reach * j;
		bloom = max(bloom, texture(TEXTURE, uv + off).a);
	}
	float halo = clamp(bloom - alpha, 0.0, 1.0) * bloom_strength * intensity;
	col = mix(col, arc_color.rgb * jolt, halo);
	alpha = max(alpha, halo);

	// Brief scan dropouts: occasional slices short out to transparent.
	float dropout = step(0.82, hash(vec2(slice + 3.0, t))) * intensity;
	alpha *= (1.0 - dropout);

	COLOR.rgb = col;
	COLOR.a = alpha * mod_a;
}
