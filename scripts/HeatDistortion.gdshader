shader_type canvas_item;
render_mode unshaded;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform float strength : hint_range(0.0, 0.02) = 0.0015;
uniform float speed : hint_range(0.0, 2.0) = 0.6;
uniform float scale : hint_range(10.0, 200.0) = 80.0;

void fragment() {
	vec2 uv = SCREEN_UV;

	float wave =
		sin((uv.y * scale) + TIME * speed) *
		sin((uv.x * scale * 0.7) + TIME * speed * 1.3);

	uv.x += wave * strength * 0.25;
	uv.y += wave * strength * 0.25;

	COLOR = texture(SCREEN_TEXTURE, uv);
}