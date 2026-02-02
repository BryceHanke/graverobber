shader_type spatial;
render_mode unshaded, depth_test_disabled, cull_disabled, skip_vertex_transform;

uniform float resolution_scale : hint_range(0.01, 1.0) = 1.0;
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;

// Outline Uniforms
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform sampler2D normal_texture : hint_normal_roughness_texture, filter_nearest;

uniform vec4 line_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float line_thickness : hint_range(0.0, 10.0) = 1.0;
uniform float depth_threshold : hint_range(0.0, 5.0) = 0.5;
uniform float normal_threshold : hint_range(0.0, 1.0) = 0.5;
uniform float min_line_width = 0.0;
uniform float max_line_width = 10.0;

// Helper function
vec3 get_view_position_from_depth(vec2 uv, mat4 inv_mat) {
	float depth = texture(depth_texture, uv).x;
	vec3 ndc = vec3(uv * 2.0 - 1.0, depth);
	vec4 view_pos = inv_mat * vec4(ndc, 1.0);
	view_pos.xyz /= view_pos.w;
	return view_pos.xyz;
}

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec2 grid_size = floor(VIEWPORT_SIZE * resolution_scale);
	grid_size = max(grid_size, vec2(1.0));

	vec2 uv = floor(SCREEN_UV * grid_size) / grid_size;
	uv += (1.0 / grid_size) * 0.5;

	// Outline Logic
	vec2 outline_uv = uv;
	vec2 texel_size = vec2(1.0) / VIEWPORT_SIZE; // Use screen pixels for outlines
	float effective_thickness = clamp(line_thickness, min_line_width, max_line_width);
	vec2 offset_size = texel_size * effective_thickness;

	vec3 view_pos_c = get_view_position_from_depth(outline_uv, INV_PROJECTION_MATRIX);
	vec4 normal_sample = texture(normal_texture, outline_uv);
	vec3 normal_c = normal_sample.rgb * 2.0 - 1.0;
	float roughness_c = normal_sample.a;

	vec2 offsets[4] = {
		vec2(0.0, -1.0),
		vec2(0.0, 1.0),
		vec2(-1.0, 0.0),
		vec2(1.0, 0.0)
	};

	float edge_intensity = 0.0;

	// Only calculate outlines if roughness is above threshold (0.0 means no outlines)
	if (roughness_c >= 0.04) {
		for (int i = 0; i < 4; i++) {
			vec2 uv_n = outline_uv + offsets[i] * offset_size;

			// Check bounds to avoid edge artifacts
			if (uv_n.x < 0.0 || uv_n.x > 1.0 || uv_n.y < 0.0 || uv_n.y > 1.0) {
				continue;
			}

			vec3 view_pos_n = get_view_position_from_depth(uv_n, INV_PROJECTION_MATRIX);
			vec3 normal_n = texture(normal_texture, uv_n).rgb * 2.0 - 1.0;

			float dist = distance(view_pos_c, view_pos_n);
			if (dist > depth_threshold) {
				edge_intensity += 1.0;
			}

			float dot_diff = dot(normal_c, normal_n);
			if (dot_diff < normal_threshold) {
				edge_intensity += 1.0;
			}
		}
	}

	edge_intensity = clamp(edge_intensity, 0.0, 1.0);

	vec3 screen_color = texture(screen_texture, uv).rgb;
	ALBEDO = mix(screen_color, line_color.rgb, edge_intensity * line_color.a);
}
