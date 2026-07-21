shader_type canvas_item;
// Draws a single bubble-wrap dome per MultiMesh instance, matching the look of the
// old CPU BubbleView._draw(): translucent base/rim, top-lit dome, two speculars, and
// an optional health bar. Pop is a per-instance expand + fade driven by u_time.
//
// Per-instance inputs:
//   COLOR            = bubble fill (already darkened by Board on partial hits)
//   INSTANCE_CUSTOM  = (hp_ratio, has_health_bar, pop_start, unused)
// u_time is an accumulated-delta clock pushed by BubbleField, shared with the CPU-side
// slot reclaim so (u_time - pop_start) is the pop's elapsed seconds.

uniform float u_time;

const float POP_DURATION = 0.16;

varying vec4 v_color;
varying vec4 v_custom;

float pop_amount(float pop_start) {
	if (pop_start < 0.0) {
		return 0.0;
	}
	return clamp((u_time - pop_start) / POP_DURATION, 0.0, 1.0);
}

void vertex() {
	v_color = COLOR;
	v_custom = INSTANCE_CUSTOM;
	// Expand the quad about its center as it pops (1.0 -> 1.5), like the old tween.
	float pop_t = pop_amount(INSTANCE_CUSTOM.z);
	VERTEX *= 1.0 + 0.5 * pop_t;
}

// Coverage of a disc of radius `rad` centered at `c`, with edge antialiasing.
float disc(vec2 p, vec2 c, float rad) {
	float d = distance(p, c);
	float aa = fwidth(d) * 1.0;
	return 1.0 - smoothstep(rad - aa, rad + aa, d);
}

void fragment() {
	// UV 0..1 -> centered p in [-1,1]; the dome lives in the unit circle.
	// QuadMesh UVs render y-flipped through MultiMeshInstance2D, so negate to put
	// the top-lit dome + speculars back up top (180 turn).
	vec2 p = (0.5 - UV) * 2.0;

	vec3 base = v_color.rgb;
	vec4 col = vec4(0.0);

	// Base + rim: slightly darker, translucent plastic (darkened 0.18, a 0.92).
	float a_base = disc(p, vec2(0.0), 1.0) * 0.92;
	col = mix(col, vec4(base * 0.82, 1.0), a_base);

	// Top-lit dome.
	float a_dome = disc(p, vec2(0.0, -0.12), 0.82);
	col = mix(col, vec4(base, 1.0), a_dome);

	// Specular highlight + sparkle.
	float a_spec1 = disc(p, vec2(-0.30, -0.34), 0.22) * 0.60;
	col = mix(col, vec4(1.0), a_spec1);
	float a_spec2 = disc(p, vec2(-0.16, -0.18), 0.09) * 0.45;
	col = mix(col, vec4(1.0), a_spec2);

	// Health bar: only when has_health_bar flag set (multi-hit bubbles). Geometry
	// mirrors BubbleView._draw(): band under the dome, green->red as hp depletes.
	if (v_custom.y > 0.5) {
		float ratio = clamp(v_custom.x, 0.0, 1.0);
		float bw = 1.3;              // total bar width in p-space
		float y0 = 0.72;            // top of the bar
		float y1 = y0 + 0.14;      // bottom of the bar
		if (p.y >= y0 && p.y <= y1 && abs(p.x) <= bw * 0.5) {
			// Background track.
			col = mix(col, vec4(0.0, 0.0, 0.0, 1.0), 0.55);
			// Fill from the left edge up to ratio.
			float fill_edge = -bw * 0.5 + bw * ratio;
			if (p.x <= fill_edge) {
				vec3 fill = mix(vec3(0.30, 0.85, 0.40), vec3(0.95, 0.30, 0.30), 1.0 - ratio);
				col = vec4(fill, 1.0);
			}
		}
	}

	// Fade the whole bubble out as it pops.
	col.a *= 1.0 - pop_amount(v_custom.z);
	COLOR = col;
}
