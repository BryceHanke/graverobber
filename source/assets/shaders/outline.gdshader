shader_type spatial;
render_mode unshaded, depth_test_disabled, cull_disabled, skip_vertex_transform;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform sampler2D normal_roughness_texture : hint_normal_roughness_texture, filter_nearest;

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

vec3 get_view_pos(vec2 uv, mat4 inv_proj_mat) {
	float depth = texture(depth_texture, uv).r;
	vec3 ndc = vec3(uv * 2.0 - 1.0, depth);
	vec4 view = inv_proj_mat * vec4(ndc, 1.0);
	return view.xyz / view.w;
}

vec3 get_reconstructed_normal(vec2 uv, vec2 texel_size, mat4 inv_proj) {
	vec3 pos = get_view_pos(uv, inv_proj);
	vec3 pos_right = get_view_pos(uv + vec2(texel_size.x, 0.0), inv_proj);
	vec3 pos_up = get_view_pos(uv + vec2(0.0, -texel_size.y), inv_proj);
	return normalize(cross(pos_right - pos, pos_up - pos));
}

float random(vec2 uv) {
	return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
}

float get_luminance(vec3 color) {
	return dot(color, vec3(0.2126, 0.7152, 0.0722));
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

	vec3 pos_center = get_view_pos(SCREEN_UV, INV_PROJECTION_MATRIX);
	float depth_center = -pos_center.z;
	vec3 normal_center = get_reconstructed_normal(SCREEN_UV, texel_size, INV_PROJECTION_MATRIX);
	float object_noise = texture(normal_roughness_texture, SCREEN_UV).a;

	// 3. Neighbor Sampling (Using Dynamic Offset)
	vec2 uv_up = SCREEN_UV + vec2(0.0, -offset.y);
	vec2 uv_right = SCREEN_UV + vec2(offset.x, 0.0);
	vec2 uv_down = SCREEN_UV + vec2(0.0, offset.y);
	vec2 uv_left = SCREEN_UV + vec2(-offset.x, 0.0);

	float d_up = -get_view_pos(uv_up, INV_PROJECTION_MATRIX).z;
	float d_right = -get_view_pos(uv_right, INV_PROJECTION_MATRIX).z;

	vec3 n_up = get_reconstructed_normal(uv_up, texel_size, INV_PROJECTION_MATRIX);
	vec3 n_right = get_reconstructed_normal(uv_right, texel_size, INV_PROJECTION_MATRIX);

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