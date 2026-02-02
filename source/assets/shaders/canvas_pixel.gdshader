shader_type canvas_item;

uniform float pixel_size : hint_range(1.0, 64.0) = 4.0;
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;

void fragment() {
	vec2 resolution = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 grid_size = resolution / pixel_size;

	// Snap UV to the grid
	vec2 uv = floor(SCREEN_UV * grid_size) / grid_size;

	// Center the sample
	uv += (1.0 / grid_size) * 0.5;

	COLOR = texture(screen_texture, uv);
}
