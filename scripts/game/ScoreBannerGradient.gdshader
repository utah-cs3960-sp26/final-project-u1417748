shader_type canvas_item;

uniform vec4 color_low : source_color = vec4(1.00, 0.78, 0.12, 1.0);
uniform vec4 color_high : source_color = vec4(1.00, 0.98, 0.55, 1.0);

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float t = clamp((UV.x + (1.0 - UV.y)) * 0.5, 0.0, 1.0);
	vec3 tinted = mix(color_low.rgb, color_high.rgb, t);
	COLOR = vec4(tinted * source.a, source.a);
}
