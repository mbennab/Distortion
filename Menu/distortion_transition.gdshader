shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float speed : hint_range(0.0, 10.0) = 5.0;

void fragment() {
	float row = floor(UV.y * 25.0);
	float offset = sin(row * 3.14159 + TIME * speed) * intensity;
	vec2 uv = UV + vec2(offset * 0.1 * intensity, 0.0);

	float alpha = intensity * (0.7 + 0.3 * sin(UV.y * 40.0 + TIME * 15.0));
	float bar = step(0.92, fract(UV.y * 25.0 + intensity * 3.0));
	float bar_alpha = bar * intensity * 0.9;
	alpha = max(alpha, bar_alpha);

	COLOR = vec4(0.0, 0.0, 0.0, clamp(alpha, 0.0, 1.0));
}
