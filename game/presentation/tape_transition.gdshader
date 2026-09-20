shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float strength : hint_range(0.0, 1.0) = 0.65;

void fragment() {
	vec2 uv = SCREEN_UV;
	float band = pow(max(0.0, sin(uv.y * 24.0 - TIME * 13.0)), 18.0);
	float grain = fract(sin(dot(vec2(floor(uv.y * 480.0), floor(TIME * 24.0)), vec2(12.9898, 78.233))) * 43758.5453);
	uv.x += strength * (band * 0.018 + (grain - 0.5) * 0.002);
	float separation = strength * (0.001 + band * 0.004);
	vec3 color;
	color.r = texture(screen_texture, uv + vec2(separation, 0.0)).r;
	color.g = texture(screen_texture, uv).g;
	color.b = texture(screen_texture, uv - vec2(separation, 0.0)).b;
	float scanline = sin(SCREEN_UV.y * 720.0 * 3.14159) * 0.025;
	color += strength * (band * (grain - 0.35) * 0.22 + scanline);
	COLOR = vec4(color, 1.0);
}
