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
// How "chunky" the pixels are
uniform float dither_pixel_size : hint_range(1.0, 8.0) = 2.0;
// How dense the grid is (Higher = smaller dots)
uniform float dither_density = 2048.0;
// Smoothness of the gradient (0.01 = Hard Cut, 0.5 = Smooth Fade)
uniform float dither_spread : hint_range(0.01, 1.0) = 0.5;

group_uniforms Lighting;
uniform float light_boost : hint_range(1.0, 100.0) = 2.0;

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

void vertex() {
    v_local_pos = VERTEX;
}

// --- DITHER MAPPING ---
float get_uv_dither(vec2 uv, float density, float pixel_size) {
    // Quantize the UVs (The "Pixel" Look)
    vec2 raw_grid_pos = uv * density;
    vec2 stepped_pos = floor(raw_grid_pos / pixel_size);

    // Bayer Matrix Lookup
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
    float total_ambient_lum = ambient_brightness * texture_brightness;

    // 2. Dither Calculation (UV Mapped)
    float noise_val = get_uv_dither(UV, dither_density, dither_pixel_size);

    // 3. Apply Threshold with Spread
    float dithered_val = total_ambient_lum + (noise_val - 0.5) * dither_spread;
    float dither_bit = step(0.5, dithered_val);

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
    float dither_bit = step(0.5, dithered_val);

    // 4. Add Light (White only)
    vec3 add_light = mix(vec3(0.0), lit_color, dither_bit);

    SPECULAR_LIGHT += add_light;
}