shader_type spatial;
render_mode unshaded, depth_test_disabled, cull_disabled, skip_vertex_transform;

uniform float resolution_scale : hint_range(0.01, 1.0) = 1.0;
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec2 grid_size = floor(VIEWPORT_SIZE * resolution_scale);
	grid_size = max(grid_size, vec2(1.0));

	vec2 uv = floor(SCREEN_UV * grid_size) / grid_size;
	uv += (1.0 / grid_size) * 0.5;

	ALBEDO = texture(screen_texture, uv).rgb;
}
