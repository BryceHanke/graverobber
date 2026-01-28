shader_type spatial;
render_mode unshaded, depth_test_disabled, cull_disabled, skip_vertex_transform;

// How big each "pixel" should be. 
uniform int pixel_factor : hint_range(1, 16) = 4;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform sampler2D normal_roughness_texture : hint_normal_roughness_texture, filter_nearest;

// --- DITHERING UNIFORMS ---
uniform vec3 lit_color : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 shadow_color : source_color = vec3(0.0, 0.0, 0.0);

uniform int dither_type : hint_enum("Bayer 8x8", "Bayer 4x4", "Blue Noise", "White Noise", "Diffused") = 0;
// Relative size of dither dots to the virtual pixels
uniform float dither_pixel_size : hint_range(1.0, 8.0) = 1.0;
uniform float dither_spread : hint_range(0.01, 2.0) = 0.5;
uniform float dither_smoothing : hint_range(0.0, 2.0) = 0.0;
uniform sampler2D blue_noise_texture : hint_default_white, filter_nearest, repeat_enable;

// --- OUTLINE UNIFORMS ---
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


// --- MATRICES ---
const int bayer8[64] = {
    0, 48, 12, 60, 3, 51, 15, 63,
    32, 16, 44, 28, 35, 19, 47, 31,
    8, 56, 4, 52, 11, 59, 7, 55,
    40, 24, 36, 20, 43, 27, 39, 23,
    2, 50, 14, 62, 1, 49, 13, 61,
    34, 18, 46, 30, 33, 17, 45, 29,
    10, 58, 6, 54, 9, 57, 5, 53,
    42, 26, 38, 22, 41, 25, 37, 21
};

const int bayer4[16] = {
    0, 8, 2, 10,
    12, 4, 14, 6,
    3, 11, 1, 9,
    15, 7, 13, 5
};

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float get_lum(vec3 color) {
    return dot(color, vec3(0.299, 0.587, 0.114));
}

// Outline version of luminance (Rec 709)
float get_luminance(vec3 color) {
	return dot(color, vec3(0.2126, 0.7152, 0.0722));
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

float get_dither_value(vec2 pixel_pos) {
    // Quantize dither sampling based on dither_pixel_size
    vec2 scaled_pos = floor(pixel_pos / dither_pixel_size);
    
    if (dither_type == 1) { // Bayer 4x4
        int x = int(mod(scaled_pos.x, 4.0));
        int y = int(mod(scaled_pos.y, 4.0));
        int idx = y * 4 + x;
        return float(bayer4[idx]) / 16.0;
    }
    else if (dither_type == 2) { // Blue Noise
         vec2 tex_size = vec2(textureSize(blue_noise_texture, 0));
        if (tex_size.x <= 1.0) {
            vec3 magic = vec3(0.06711056, 0.00583715, 52.9829189);
            return fract(magic.z * fract(dot(scaled_pos, magic.xy)));
        }
        vec2 tex_uv = scaled_pos / tex_size;
        return texture(blue_noise_texture, tex_uv).r;
    }
    else if (dither_type == 3) { // White Noise
        return fract(sin(dot(scaled_pos, vec2(12.9898, 78.233))) * 43758.5453);
    }
    else if (dither_type == 4) { // Diffused (IGN)
        vec3 magic = vec3(0.06711056, 0.00583715, 52.9829189);
        return fract(magic.z * fract(dot(scaled_pos, magic.xy)));
    }
    
    // Default Bayer 8x8
    int x = int(mod(scaled_pos.x, 8.0));
    int y = int(mod(scaled_pos.y, 8.0));
    int bayer_idx = y * 8 + x;
    return float(bayer8[bayer_idx]) / 64.0;
}

void fragment() {
    vec2 texel_size = vec2(1.0) / VIEWPORT_SIZE;
    vec2 grid_size_pixels = VIEWPORT_SIZE / float(pixel_factor);
    vec2 virtual_texel_size = vec2(1.0) / grid_size_pixels; // Size of one virtual pixel in UV space

    // Calculate snapped UV for pixelation
    vec2 snapped_uv = floor(SCREEN_UV * grid_size_pixels) / grid_size_pixels;
    
    // Sample at center of the virtual pixel to avoid edge artifacts
    vec2 center_uv = snapped_uv + virtual_texel_size * 0.5;

    // Get Base Color
    vec3 col = texture(screen_texture, center_uv).rgb;
    float lum = get_lum(col);

    // --- OUTLINE LOGIC ---
    // 1. Calculate thickness based on center luminance
    float center_lum_outline = get_luminance(col);
    float current_thickness = mix(thickness_dark, line_thickness, center_lum_outline);

    // Offset for neighbor sampling (scaled to virtual pixels)
    vec2 offset = virtual_texel_size * current_thickness;

    vec3 pos_center = get_view_pos(center_uv, INV_PROJECTION_MATRIX);
    float depth_center = -pos_center.z;
    // Note: using center_uv for normal reconstruction to match position
    vec3 normal_center = get_reconstructed_normal(center_uv, virtual_texel_size, INV_PROJECTION_MATRIX);
    float object_noise = texture(normal_roughness_texture, center_uv).a;

    // Neighbor Sampling
    vec2 uv_up = center_uv + vec2(0.0, -offset.y);
    vec2 uv_right = center_uv + vec2(offset.x, 0.0);
    vec2 uv_down = center_uv + vec2(0.0, offset.y); // Used for color avg
    vec2 uv_left = center_uv + vec2(-offset.x, 0.0); // Used for color avg

    float d_up = -get_view_pos(uv_up, INV_PROJECTION_MATRIX).z;
    float d_right = -get_view_pos(uv_right, INV_PROJECTION_MATRIX).z;

    vec3 n_up = get_reconstructed_normal(uv_up, virtual_texel_size, INV_PROJECTION_MATRIX);
    vec3 n_right = get_reconstructed_normal(uv_right, virtual_texel_size, INV_PROJECTION_MATRIX);

    // Edge Detection
    float depth_diff = abs(depth_center - d_up) + abs(depth_center - d_right);
    float is_depth_edge = step(depth_threshold, depth_diff);

    float dot_up = clamp(dot(normal_center, n_up), 0.0, 1.0);
    float dot_right = clamp(dot(normal_center, n_right), 0.0, 1.0);
    float is_normal_edge = step(dot_up, normal_threshold) + step(dot_right, normal_threshold);
    is_normal_edge = clamp(is_normal_edge, 0.0, 1.0);

    float edge = max(is_depth_edge, is_normal_edge);

    // Should we draw outline?
    bool draw_outline = false;
    if (edge >= 0.1) {
        draw_outline = true;

        // Borders check
        vec2 border_dist = min(center_uv, 1.0 - center_uv);
        vec2 margin = virtual_texel_size * (max(line_thickness, thickness_dark) + 1.0);
        if (border_dist.x < margin.x || border_dist.y < margin.y) draw_outline = false;
        if (depth_center > depth_fade_dist) draw_outline = false;

        // Cutout Logic
        if (draw_outline) {
            vec3 c_up = texture(screen_texture, uv_up).rgb;
            vec3 c_right = texture(screen_texture, uv_right).rgb;
            vec3 c_down = texture(screen_texture, uv_down).rgb;
            vec3 c_left = texture(screen_texture, uv_left).rgb;

            vec3 avg_color = (col + c_up + c_right + c_down + c_left) / 5.0;
            float avg_brightness = get_luminance(avg_color);
            float cutout_brightness = pow(avg_brightness, cutout_sensitivity);
            float dynamic_threshold = mix(cutout_dark, cutout_light, cutout_brightness);

            if (object_noise < dynamic_threshold) {
                draw_outline = false;
            }

            // Apply color if outline persists
            if (draw_outline) {
                 vec3 final_outline_color = fixed_line_color.rgb;
                 if (use_smart_color) {
                    if (avg_brightness > contrast_threshold) {
                        final_outline_color = line_color_on_light.rgb;
                    } else {
                        final_outline_color = line_color_on_dark.rgb;
                    }
                 }
                 col = final_outline_color;
                 lum = get_lum(col); // Update lum for dithering
            }
        }
    }


    // --- DITHERING LOGIC (Applied to col) ---

    // Reconstruct World Position and Normal (using center_uv for consistency)
    vec3 view_pos = get_view_pos(center_uv, INV_PROJECTION_MATRIX);
    vec3 world_pos = (INV_VIEW_MATRIX * vec4(view_pos, 1.0)).xyz;
    vec3 view_normal = get_reconstructed_normal(center_uv, virtual_texel_size, INV_PROJECTION_MATRIX);
    vec3 world_normal = normalize((INV_VIEW_MATRIX * vec4(view_normal, 0.0)).xyz);

    // Triplanar / Box Projection for Dither Pattern
    vec3 blend = abs(world_normal);
    blend /= (blend.x + blend.y + blend.z);

    // Determine dominant axis
    vec2 dither_uv;
    if (blend.x > blend.y && blend.x > blend.z) {
        dither_uv = world_pos.zy;
    } else if (blend.y > blend.z) {
        dither_uv = world_pos.xz;
    } else {
        dither_uv = world_pos.xy;
    }

    // Scale world UVs to pixel grid density roughly
    vec2 pixel_coord = floor(dither_uv * 32.0);

    float noise_val = get_dither_value(pixel_coord);

    // Apply Dither Threshold
    float dithered_val = lum + (noise_val - 0.5) * dither_spread;
    float dither_bit;

    if (dither_smoothing < 0.001) {
        dither_bit = step(0.5, dithered_val);
    } else {
        dither_bit = smoothstep(0.5 - dither_smoothing, 0.5 + dither_smoothing, dithered_val);
    }

    ALBEDO = mix(shadow_color, lit_color, dither_bit);
}
