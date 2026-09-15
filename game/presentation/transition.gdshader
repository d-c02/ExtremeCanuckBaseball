shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float beat = floor(TIME * 12.0);
	float band = floor(SCREEN_UV.y * 70.0);
	float noise = fract(sin(band * 41.7 + beat * 19.3) * 43758.5453);
	float shift = step(0.87, noise) * (noise - 0.5) * 12.0 * amount;
	vec2 uv = SCREEN_UV + vec2(SCREEN_PIXEL_SIZE.x * shift, 0.0);
	vec3 color = texture(screen_texture, uv).rgb;
	color.r = texture(screen_texture, uv + vec2(SCREEN_PIXEL_SIZE.x * amount, 0.0)).r;
	color.b = texture(screen_texture, uv - vec2(SCREEN_PIXEL_SIZE.x * amount, 0.0)).b;
	float scanline = sin(SCREEN_UV.y / SCREEN_PIXEL_SIZE.y * 1.57) * 0.015 * amount;
	COLOR = vec4(color - vec3(scanline), 1.0);
}
