shader_type spatial;
render_mode unshaded, depth_test_disabled, cull_disabled, skip_vertex_transform;

// Textures
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform sampler2D normal_texture : hint_normal_roughness_texture, filter_nearest;

// Uniforms for artist control
uniform vec4 line_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float line_thickness : hint_range(0.0, 10.0) = 1.0; // Use strict pixel-step offsets
uniform float depth_threshold : hint_range(0.0, 5.0) = 0.5; // Sensitivity for depth cuts (in meters)
uniform float normal_threshold : hint_range(0.0, 1.0) = 0.5; // Sensitivity for normal cuts (0.0 to 1.0)
uniform float depth_cutoff : hint_range(0.0, 100.0) = 20.0;

// Optional clamping for line width
uniform float min_line_width = 0.0;
uniform float max_line_width = 10.0;

// View Space Reconstruction Logic
// We reconstruct the View Space Position (Vector3) from the depth buffer.
// This allows us to calculate Euclidean distances in meters, preventing "ink blot" artifacts on distant objects.
// Math:
// 1. Sample raw depth (0..1).
// 2. Construct NDC (Normalized Device Coordinates) from Screen UV and Depth.
// 3. Multiply by Inverse Projection Matrix to get Clip/View space.
// 4. Divide by W to normalize.
vec3 get_view_position_from_depth(vec2 uv, mat4 inv_mat) {
	float depth = texture(depth_texture, uv).x;

	// Construct NDC
	// UV (0..1) -> XY (-1..1)
	vec3 ndc = vec3(uv * 2.0 - 1.0, depth);

	// Unproject to View Space
	vec4 view_pos = inv_mat * vec4(ndc, 1.0);
	view_pos.xyz /= view_pos.w;

	return view_pos.xyz;
}

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec2 texel_size = vec2(1.0) / VIEWPORT_SIZE;

	// Clamp thickness based on min/max settings
	float effective_thickness = clamp(line_thickness, min_line_width, max_line_width);

	// Pixel-step offset
	vec2 offset_size = texel_size * effective_thickness;

	// Center Pixel
	vec3 view_pos_c = get_view_position_from_depth(SCREEN_UV, INV_PROJECTION_MATRIX);
	vec4 normal_sample = texture(normal_texture, SCREEN_UV);
	vec3 normal_c = normal_sample.rgb * 2.0 - 1.0;
	float roughness_c = normal_sample.a;

	// Neighbors (Up, Down, Left, Right)
	vec2 offsets[4] = {
		vec2(0.0, -1.0),
		vec2(0.0, 1.0),
		vec2(-1.0, 0.0),
		vec2(1.0, 0.0)
	};

	float edge_intensity = 0.0;

	if (roughness_c >= 0.04 && length(view_pos_c) < depth_cutoff) {
		for (int i = 0; i < 4; i++) {
			vec2 uv_n = SCREEN_UV + offsets[i] * offset_size;

			// Neighbor View Position
			vec3 view_pos_n = get_view_position_from_depth(uv_n, INV_PROJECTION_MATRIX);

			// Neighbor Normal
			vec3 normal_n = texture(normal_texture, uv_n).rgb * 2.0 - 1.0;

			// Depth Logic: Euclidean Distance
			// Compare physical distance in meters
			float dist = distance(view_pos_c, view_pos_n);
			if (dist > depth_threshold) {
				edge_intensity += 1.0;
			}

			// Normal Logic: Dot Product
			// Compare angle difference
			float dot_diff = dot(normal_c, normal_n);
			if (dot_diff < normal_threshold) {
				edge_intensity += 1.0;
			}
		}
	}

	// Clamp intensity
	edge_intensity = clamp(edge_intensity, 0.0, 1.0);

	// Mix line color with screen color
	vec4 original_color = texture(screen_texture, SCREEN_UV);
	ALBEDO = mix(original_color.rgb, line_color.rgb, edge_intensity * line_color.a);
}
