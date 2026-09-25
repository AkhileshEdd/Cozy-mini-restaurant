shader_type spatial;
// Billboard speech bubble: white disc with an optional tail, a progress ring
// around the edge and an icon in the middle. One quad, one draw call.
render_mode unshaded, cull_disabled, depth_test_disabled, blend_mix, shadows_disabled;

uniform sampler2D icon : source_color, filter_linear_mipmap, repeat_disable;
uniform float progress : hint_range(0.0, 1.0) = 1.0;
uniform vec4 ring_color : source_color = vec4(0.62, 0.85, 0.72, 1.0);
uniform vec4 track_color : source_color = vec4(0.95, 0.90, 0.85, 1.0);
uniform vec4 fill_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 outline_color : source_color = vec4(0.29, 0.21, 0.19, 1.0);
uniform float show_tail = 1.0;
uniform float show_ring = 1.0;
uniform float fade : hint_range(0.0, 1.0) = 1.0;

void vertex() {
	mat4 billboard = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	vec3 s = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	MODELVIEW_MATRIX = VIEW_MATRIX * billboard * mat4(vec4(s.x, 0.0, 0.0, 0.0), vec4(0.0, s.y, 0.0, 0.0), vec4(0.0, 0.0, s.z, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

float sd_diamond(vec2 p, float r) {
	return (abs(p.x) + abs(p.y) - r) * 0.7071;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	vec2 c = vec2(0.0, -0.1);
	float R = 0.74;
	float d = length(p - c) - R;
	if (show_tail > 0.5) {
		d = min(d, sd_diamond(p - vec2(0.0, 0.62), 0.26));
	}
	float aa = fwidth(d) * 1.2;
	float shape = 1.0 - smoothstep(-aa, aa, d);
	float outline = 1.0 - smoothstep(-aa, aa, d - 0.06);

	vec3 col = mix(outline_color.rgb, fill_color.rgb, shape);
	float alpha = outline;

	// progress ring just inside the edge
	vec2 q = p - c;
	float r = length(q);
	float band = abs(r - (R - 0.09)) - 0.055;
	float ring = (1.0 - smoothstep(-aa, aa, band)) * show_ring;
	float ang = atan(q.x, -q.y) / 6.2831853 + 0.5;
	ang = fract(ang + 0.5);
	vec3 ring_col = ang <= progress ? ring_color.rgb : track_color.rgb;
	col = mix(col, ring_col, ring * shape);

	// icon in the middle
	vec2 iuv = q / (R * 1.12) + 0.5;
	if (iuv.x > 0.0 && iuv.x < 1.0 && iuv.y > 0.0 && iuv.y < 1.0) {
		vec4 ic = texture(icon, iuv);
		col = mix(col, ic.rgb, ic.a * shape);
	}

	ALBEDO = col;
	ALPHA = alpha * fade;
}
