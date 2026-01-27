shader_type spatial;
render_mode unshaded, depth_test_disabled, cull_disabled, skip_vertex_transform;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
// Removed normal_texture for compatibility mode
// uniform sampler2D normal_texture : hint_normal_roughness_texture, filter_nearest;

// --- DYNAMIC CUTOUT SETTINGS ---
group_uniforms Sketchy_Style;
uniform float cutout_light : hint_range(0.0, 1.0) = 0.0;
uniform float cutout_dark : hint_range(0.0, 1.0) = 1.0;
uniform float cutout_sensitivity : hint_range(0.1, 5.0) = 1.0;

group_uniforms Sensitivity;
uniform float depth_threshold : hint_range(0.01, 1.0) = 0.05;
uniform float normal_threshold : hint_range(0.0, 1.0) = 0.6;
uniform float depth_fade_dist : hint_range(1.0, 100.0) = 20.0;

group_uniforms Styling;
// Maximum thickness (In the Light)
uniform float line_thickness : hint_range(0.0, 5.0) = 2.0;
// Minimum thickness (In the Dark) - Set lower to make lines thin out!
uniform float thickness_dark : hint_range(0.0, 5.0) = 0.5; 

group_uniforms Smart_Color;
uniform bool use_smart_color = true;
uniform float contrast_threshold : hint_range(0.0, 1.0) = 0.5;
uniform vec4 line_color_on_light : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 line_color_on_dark : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 fixed_line_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

// Reconstruct view-space position from depth
vec3 get_view_position(vec2 screen_uv, float depth, mat4 inv_proj_mat) {
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

float get_depth(vec2 uv, mat4 inv_proj_mat) {
	float depth = texture(depth_texture, uv).r;
	vec3 ndc = vec3(uv * 2.0 - 1.0, depth);
	vec4 view = inv_proj_mat * vec4(ndc, 1.0);
	view.xyz /= view.w;
	return -view.z;
}

float get_luminance(vec3 color) {
	return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

// Simple hash function for noise
float hash(vec3 p) {
    p = fract(p * 0.3183099 + .1);
    p *= 17.0;
    return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void fragment() {
	vec2 texel_size = vec2(1.0) / VIEWPORT_SIZE;

	// 1. Sample Center Data FIRST
	// We need the color immediately to determine thickness
	vec3 color_center = texture(screen_texture, SCREEN_UV).rgb;
	float center_lum = get_luminance(color_center);

	// --- 2. DYNAMIC THICKNESS CALCULATION ---
	// Interpolate between thickness_dark and line_thickness based on brightness
	float current_thickness = mix(thickness_dark, line_thickness, center_lum);
	
	// Apply the calculated thickness to the offset
	vec2 offset = texel_size * current_thickness;
	// ----------------------------------------

	float depth_raw = texture(depth_texture, SCREEN_UV).r;
	float depth_center = get_depth(SCREEN_UV, INV_PROJECTION_MATRIX);

	// Reconstruct normal from depth
	vec3 normal_center = get_normal_from_depth(SCREEN_UV, depth_raw, texel_size, INV_PROJECTION_MATRIX);

	// Generate object noise from world position
	vec3 view_pos = get_view_position(SCREEN_UV, depth_raw, INV_PROJECTION_MATRIX);
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(view_pos, 1.0)).xyz;
	// Scale world pos to get appropriate noise frequency
	float object_noise = hash(world_pos * 10.0);

	// 3. Neighbor Sampling (Using Dynamic Offset)
	vec2 uv_up = SCREEN_UV + vec2(0.0, -offset.y);
	vec2 uv_right = SCREEN_UV + vec2(offset.x, 0.0);

	float d_up = get_depth(uv_up, INV_PROJECTION_MATRIX);
	float d_right = get_depth(uv_right, INV_PROJECTION_MATRIX);

	float d_raw_up = texture(depth_texture, uv_up).r;
	float d_raw_right = texture(depth_texture, uv_right).r;

	vec3 n_up = get_normal_from_depth(uv_up, d_raw_up, texel_size, INV_PROJECTION_MATRIX);
	vec3 n_right = get_normal_from_depth(uv_right, d_raw_right, texel_size, INV_PROJECTION_MATRIX);

	// 4. Edge Detection
	float depth_diff = abs(depth_center - d_up) + abs(depth_center - d_right);
	float is_depth_edge = step(depth_threshold, depth_diff);
	
	float dot_up = clamp(dot(normal_center, n_up), 0.0, 1.0);
	float dot_right = clamp(dot(normal_center, n_right), 0.0, 1.0);
	float is_normal_edge = step(dot_up, normal_threshold) + step(dot_right, normal_threshold);
	is_normal_edge = clamp(is_normal_edge, 0.0, 1.0);

	float edge = max(is_depth_edge, is_normal_edge);

	// 5. Initial Discard
	if (edge < 0.1) discard;
	
	// Borders and Distance
	vec2 border_dist = min(SCREEN_UV, 1.0 - SCREEN_UV);
	if (border_dist.x < 0.002 || border_dist.y < 0.002) discard;
	if (depth_center > depth_fade_dist) discard;

	// --- 6. RE-CALCULATE BRIGHTNESS (Smoothed) ---
	// We re-calculate brightness using neighbors for the CUTOUT logic
	// to prevent flickering, even though we used center pixel for thickness.
	vec2 uv_down = SCREEN_UV + vec2(0.0, offset.y);
	vec2 uv_left = SCREEN_UV + vec2(-offset.x, 0.0);

	vec3 c_up = texture(screen_texture, uv_up).rgb;
	vec3 c_right = texture(screen_texture, uv_right).rgb;
	vec3 c_down = texture(screen_texture, uv_down).rgb;
	vec3 c_left = texture(screen_texture, uv_left).rgb;
	
	vec3 avg_color = (color_center + c_up + c_right + c_down + c_left) / 5.0;
	float avg_brightness = get_luminance(avg_color);
	
	// Apply sensitivity curve (make shadows impact cutoff faster)
	float cutout_brightness = pow(avg_brightness, cutout_sensitivity);

	// --- 7. DYNAMIC CUTOUT LOGIC ---
	float dynamic_threshold = mix(cutout_dark, cutout_light, cutout_brightness);
	
	if (object_noise < dynamic_threshold) {
		discard;
	}

	// 8. Color Logic (Smart Color)
	vec3 final_color = fixed_line_color.rgb;
	if (use_smart_color) {
		if (avg_brightness > contrast_threshold) {
			final_color = line_color_on_light.rgb;
		} else {
			final_color = line_color_on_dark.rgb;
		}
	}

	ALBEDO = final_color;
}
