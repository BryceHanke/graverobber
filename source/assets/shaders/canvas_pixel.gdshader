shader_type canvas_item;

uniform float pixel_size : hint_range(1.0, 64.0) = 4.0;

void fragment() {
	vec2 resolution = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 grid_size = resolution / pixel_size;

	// Snap UV to the grid
	vec2 uv = floor(UV * grid_size) / grid_size;

	// Center the sample
	uv += (1.0 / grid_size) * 0.5;

	COLOR = texture(TEXTURE, uv);
}
