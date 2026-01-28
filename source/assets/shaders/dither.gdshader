shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, ambient_light_disabled, specular_disabled, fog_disabled;

// --- UNIFORMS ---
uniform sampler2D texture_albedo : source_color, filter_nearest;
// The color of the "dots" (usually White)
uniform vec3 lit_color : source_color = vec3(1.0, 1.0, 1.0);
// The color of the background (usually Black)
uniform vec3 shadow_color : source_color = vec3(0.0, 0.0, 0.0);
uniform vec3 global_ambient : source_color = vec3(0.1, 0.1, 0.1);

// --- DITHERING STYLE ---
group_uniforms Dithering_Style;
uniform int dither_type : hint_enum("Bayer 8x8", "Bayer 4x4", "Blue Noise", "White Noise", "Diffused") = 0;
// How "chunky" the pixels are
uniform float dither_pixel_size : hint_range(1.0, 8.0) = 2.0;
// How dense the grid is (Higher = smaller dots)
uniform float dither_density = 2048.0;
// Smoothness of the gradient (0.01 = Hard Cut, 0.5 = Smooth Fade)
uniform float dither_spread : hint_range(0.01, 1.0) = 0.5;
uniform float dither_smoothing : hint_range(0.0, 1.0) = 0.05;
uniform sampler2D blue_noise_texture : hint_default_white, filter_nearest, repeat_enable;

group_uniforms Lighting;
uniform float light_boost : hint_range(1.0, 100.0) = 2.0;

group_uniforms Bounce_Lighting;
uniform float bounce_strength : hint_range(0.0, 5.0) = 0.5;

// --- VARYINGS ---
varying vec3 v_local_pos;

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

void vertex() {
    v_local_pos = VERTEX;
}

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

// Helper: Convert Color -> Brightness (Luminance)
float get_lum(vec3 color) {
    return dot(color, vec3(0.299, 0.587, 0.114));
}

void fragment() {
    // 1. Get Texture Brightness (Ignore Texture Color)
    vec4 tex = texture(texture_albedo, UV);
    float texture_brightness = get_lum(tex.rgb);

    // --- AMBIENT PASS ---
    // Combined Brightness = Ambient Light * Texture Dark/Lightness
    float ambient_brightness = get_lum(global_ambient);

    // Bounce Light (Simulating ground bounce, so facing down gets light)
    vec3 world_normal = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
    float bounce_factor = max(0.0, -world_normal.y);
    float bounce_lum = bounce_strength * bounce_factor;

    float total_ambient_lum = (ambient_brightness + bounce_lum) * texture_brightness;

    // 2. Dither Calculation (UV Mapped)
    float noise_val = get_uv_dither(UV, dither_density, dither_pixel_size);

    // 3. Apply Threshold with Spread
    float dithered_val = total_ambient_lum + (noise_val - 0.5) * dither_spread;
    float dither_bit;
    if (dither_smoothing < 0.001) {
        dither_bit = step(0.5, dithered_val);
    } else {
        dither_bit = smoothstep(0.5 - dither_smoothing, 0.5 + dither_smoothing, dithered_val);
    }

    // 4. Output: Mix Black and White based on dither bit
    EMISSION = mix(shadow_color, lit_color, dither_bit);
    ALBEDO = vec3(0.0); // Disable engine lighting
    SPECULAR = 0.0;
}

void light() {
    vec4 tex = texture(texture_albedo, UV);
    float texture_brightness = get_lum(tex.rgb);

    // 1. Calculate Dynamic Light Brightness
    float NdotL = max(0.0, dot(NORMAL, LIGHT));
    vec3 light_intensity = LIGHT_COLOR * NdotL * ATTENUATION * light_boost;
    float light_brightness = get_lum(light_intensity);

    // Combined Brightness
    float total_lum = light_brightness * texture_brightness;

    // 2. Recalculate Dither for Light Pass
    float noise_val = get_uv_dither(UV, dither_density, dither_pixel_size);

    // 3. Apply Threshold
    float dithered_val = total_lum + (noise_val - 0.5) * dither_spread;
    float dither_bit;
    if (dither_smoothing < 0.001) {
        dither_bit = step(0.5, dithered_val);
    } else {
        dither_bit = smoothstep(0.5 - dither_smoothing, 0.5 + dither_smoothing, dithered_val);
    }

    // 4. Add Light (White only)
    vec3 add_light = mix(vec3(0.0), lit_color, dither_bit);

    SPECULAR_LIGHT += add_light;
}