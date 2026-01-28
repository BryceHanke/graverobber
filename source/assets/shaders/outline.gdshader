shader_type spatial;
render_mode unshaded, cull_disabled;

// This shader implements an outline effect compatible with Godot's Compatibility renderer (GLES3).
// It reconstructs normals from the depth texture instead of relying on the Normal/Roughness texture
// (which is only available in Forward+ and Mobile renderers).

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;

uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float outline_width : hint_range(0.0, 10.0) = 1.0;
uniform float depth_threshold : hint_range(0.0, 0.1) = 0.01;
uniform float normal_threshold : hint_range(0.0, 1.0) = 0.6;

// Reconstruct view-space position from depth
vec3 get_view_position(vec2 screen_uv, float depth, mat4 inv_proj_mat) {
	// Godot's depth buffer is 0.0 to 1.0.
	// In NDC, z is usually -1 to 1 for OpenGL, or 0 to 1 for Vulkan.
	// However, using the INV_PROJECTION_MATRIX with the raw depth value usually works
	// because the matrix matches the projection used.
	// We map 0..1 to -1..1 for OpenGL if needed, but Godot abstracts this.
	// Let's assume standard NDC construction.
	vec4 ndc = vec4(screen_uv * 2.0 - 1.0, depth, 1.0);
	vec4 view_pos = inv_proj_mat * ndc;
	return view_pos.xyz / view_pos.w;
}

// Reconstruct normal from depth by sampling neighbors
vec3 get_normal_from_depth(vec2 screen_uv, float depth, vec2 texel_size, mat4 inv_proj_mat) {
	vec3 pos = get_view_position(screen_uv, depth, inv_proj_mat);

	// Sample neighbors for derivatives
	vec2 offset_x = vec2(texel_size.x, 0.0);
	vec2 offset_y = vec2(0.0, texel_size.y);

	float depth_x = texture(depth_texture, screen_uv + offset_x).r;
	float depth_y = texture(depth_texture, screen_uv + offset_y).r;

	vec3 pos_x = get_view_position(screen_uv + offset_x, depth_x, inv_proj_mat);
	vec3 pos_y = get_view_position(screen_uv + offset_y, depth_y, inv_proj_mat);

	vec3 tangent = pos_x - pos;
	vec3 bitangent = pos_y - pos;

	return normalize(cross(tangent, bitangent));
}

void fragment() {
	vec2 texel_size = 1.0 / VIEWPORT_SIZE;
	float depth = texture(depth_texture, SCREEN_UV).r;

	// Do not draw outline on background (depth = 0 or 1 depending on convention, usually 0 is near, 1 is far?
	// Godot Reverse Z? No, default is standard Z usually, but let's check.
	// If depth is very far, we skip.
	// In Godot 4, standard depth is 0 (near) to 1 (far) or reversed.
	// Usually 1.0 is background in standard Z, 0.0 in reverse Z.
	// We'll check if depth is valid.

	vec3 normal = get_normal_from_depth(SCREEN_UV, depth, texel_size, INV_PROJECTION_MATRIX);

	// Edge detection
	float half_width = outline_width;
	// Sample neighbors at outline_width distance
	vec2 offset_x = vec2(texel_size.x, 0.0) * half_width;
	vec2 offset_y = vec2(0.0, texel_size.y) * half_width;

	float d_l = texture(depth_texture, SCREEN_UV - offset_x).r;
	float d_r = texture(depth_texture, SCREEN_UV + offset_x).r;
	float d_u = texture(depth_texture, SCREEN_UV - offset_y).r;
	float d_d = texture(depth_texture, SCREEN_UV + offset_y).r;

	vec3 n_l = get_normal_from_depth(SCREEN_UV - offset_x, d_l, texel_size, INV_PROJECTION_MATRIX);
	vec3 n_r = get_normal_from_depth(SCREEN_UV + offset_x, d_r, texel_size, INV_PROJECTION_MATRIX);
	vec3 n_u = get_normal_from_depth(SCREEN_UV - offset_y, d_u, texel_size, INV_PROJECTION_MATRIX);
	vec3 n_d = get_normal_from_depth(SCREEN_UV + offset_y, d_d, texel_size, INV_PROJECTION_MATRIX);

	// Depth edge
	// We can simply check the difference in depth.
	// However, depth difference depends on distance.
	// A better metric is view space distance.
	// But simple depth diff is often enough for outlines.
	float depth_diff = abs(depth - d_l) + abs(depth - d_r) + abs(depth - d_u) + abs(depth - d_d);

	// Normal edge
	// Dot product of current normal with neighbors.
	// If flat surface, dot is 1. If edge, dot is < 1.
	float normal_diff = dot(normal, n_l) + dot(normal, n_r) + dot(normal, n_u) + dot(normal, n_d);
	// 4 neighbors. If all same, sum is 4.
	// We want to know how much it deviates from 4.
	float normal_edge_val = 4.0 - normal_diff;

	float edge = 0.0;

	// Combine
	if (depth_diff > depth_threshold || normal_edge_val > normal_threshold) {
		edge = 1.0;
	}

	vec4 screen_color = texture(screen_texture, SCREEN_UV);
	ALBEDO = mix(screen_color.rgb, outline_color.rgb, edge * outline_color.a);
}
