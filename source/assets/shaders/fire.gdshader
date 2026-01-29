shader_type spatial;

render_mode cull_disabled, depth_draw_opaque;

// Vertex
uniform float flame_height = 1.8;
uniform float taper_factor: hint_range(0.0, 1.0, 0.1) = 1.0;
uniform vec3 deviation = vec3(0.0, 0.0, 0.0);
uniform float turbulence_speed: hint_range(0.0, 30.0, 1.0) = 3.0;
uniform float turbulence_force: hint_range(0.0, 100.0, 1.0) = 2.0;

// Fragment
uniform vec3 inner_color: source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 outer_color: source_color = vec3(1.0, 0.75, 0.0);
uniform vec3 bottom_color: source_color = vec3(0.0, 0.1, 1.0);
uniform float emission: hint_range(1.0, 50.0, 0.1) = 5.0;
uniform float max_alpha: hint_range(0.0, 1.0, 0.01) = 0.4;
uniform float border_width: hint_range(0.0, 1.0, 0.01) = 0.75;
uniform float bottom_color_fade_y_end: hint_range(0.0, 1.0, 0.01) = 0.2;
uniform float bottom_color_fade_y_start: hint_range(0.0, 1.0, 0.01) = 0.6;

// --- DITHERING STYLE ---
group_uniforms Dithering_Style;
uniform int dither_type : hint_enum("Bayer 8x8", "Bayer 4x4", "Blue Noise", "White Noise", "Diffused") = 0;
// How "chunky" the pixels are
uniform float dither_pixel_size : hint_range(1.0, 8.0) = 2.0;
// How dense the grid is (Higher = smaller dots)
uniform float dither_density = 2048.0;
uniform sampler2D blue_noise_texture : hint_default_white, filter_nearest, repeat_enable;
uniform vec2 dither_motion = vec2(0.0, 0.0);

group_uniforms Fire_Style;
uniform bool should_pixelate_fire = false;


// --- 8x8 BAYER MATRIX ---
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

// --- 4x4 BAYER MATRIX ---
const int bayer4[16] = {
    0, 8, 2, 10,
    12, 4, 14, 6,
    3, 11, 1, 9,
    15, 7, 13, 5
};

// --- DITHER MAPPING ---
float get_uv_dither(vec2 uv, float density, float pixel_size) {
    // Quantize the UVs (The "Pixel" Look)
    vec2 raw_grid_pos = uv * density;
    vec2 stepped_pos = floor(raw_grid_pos / pixel_size);

    if (dither_type == 1) { // Bayer 4x4
        int x = int(mod(stepped_pos.x, 4.0));
        int y = int(mod(stepped_pos.y, 4.0));
        int idx = y * 4 + x;
        return float(bayer4[idx]) / 16.0;
    }
    else if (dither_type == 2) { // Blue Noise
        vec2 tex_size = vec2(textureSize(blue_noise_texture, 0));
        if (tex_size.x <= 1.0) {
            // Fallback to Diffused (IGN) if no texture
            vec3 magic = vec3(0.06711056, 0.00583715, 52.9829189);
            return fract(magic.z * fract(dot(stepped_pos, magic.xy)));
        }
        // Use texture repeat
        vec2 tex_uv = stepped_pos / tex_size;
        return texture(blue_noise_texture, tex_uv).r;
    }
    else if (dither_type == 3) { // White Noise
        return fract(sin(dot(stepped_pos, vec2(12.9898, 78.233))) * 43758.5453);
    }
    else if (dither_type == 4) { // Diffused (IGN)
        vec3 magic = vec3(0.06711056, 0.00583715, 52.9829189);
        return fract(magic.z * fract(dot(stepped_pos, magic.xy)));
    }

    // Default: Bayer 8x8 (dither_type == 0)
    int x = int(mod(stepped_pos.x, 8.0));
    int y = int(mod(stepped_pos.y, 8.0));
    int bayer_idx = y * 8 + x;

    return float(bayer8[bayer_idx]) / 64.0;
}

void vertex() {
	vec3 _deviation = vec3(deviation.x, 0, deviation.z) * 0.2;
	float height = (1.0 - UV.y);

	VERTEX = mix(VERTEX, vec3(0.0, VERTEX.y, 0.0), height * taper_factor) + _deviation * height;
	VERTEX.x += cos(TIME * turbulence_speed + VERTEX.y * PI) * 0.0015 * turbulence_force;
	VERTEX.y *= flame_height;
}

void fragment() {
	vec2 used_uv = UV;
	if (should_pixelate_fire) {
		float pixel_scale = dither_density / dither_pixel_size;
		used_uv = floor(UV * pixel_scale) / pixel_scale;
	}

	float height = 1.0 - used_uv.y;
	float vision_dot = dot(normalize(NORMAL), normalize(VIEW));
	float edge = 1.0 - vision_dot;

	float height_fade = smoothstep(0.0, 0.65, height);
	height_fade = pow(height_fade, 4.0);

	ALPHA = height_fade - pow(vision_dot, 3.0) * 0.1;
	ALPHA = mix(edge, ALPHA, pow(used_uv.y, 0.05));

	ALPHA *= pow(vision_dot, 1.5);
	ALPHA = clamp(ALPHA, 0.0, max_alpha);

	ALBEDO = mix(inner_color, outer_color, pow(edge, 1.0 - border_width) + 0.5 - used_uv.y);

	ALBEDO = mix(ALBEDO, bottom_color, smoothstep(bottom_color_fade_y_start, bottom_color_fade_y_end, height));

	EMISSION = ALBEDO * vision_dot * emission;

	// Dithering Logic
	vec2 dither_uv = UV + dither_motion * TIME;
	float noise_val = get_uv_dither(dither_uv, dither_density, dither_pixel_size);
	if (ALPHA <= noise_val) {
		discard;
	}
	ALPHA = 1.0;
}
