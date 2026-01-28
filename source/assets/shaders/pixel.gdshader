shader_type canvas_item;

// How big each "pixel" should be. 
uniform int pixel_factor : hint_range(1, 16) = 4;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;

// --- DITHERING UNIFORMS ---
uniform vec3 lit_color : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 shadow_color : source_color = vec3(0.0, 0.0, 0.0);

uniform int dither_type : hint_enum("Bayer 8x8", "Bayer 4x4", "Blue Noise", "White Noise", "Diffused") = 0;
// Relative size of dither dots to the virtual pixels
uniform float dither_pixel_size : hint_range(1.0, 8.0) = 1.0;
uniform float dither_spread : hint_range(0.01, 2.0) = 0.5;
uniform float dither_smoothing : hint_range(0.0, 2.0) = 0.0;
uniform sampler2D blue_noise_texture : hint_default_white, filter_nearest, repeat_enable;

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

float get_lum(vec3 color) {
    return dot(color, vec3(0.299, 0.587, 0.114));
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
    vec2 screen_size_pixels = 1.0 / SCREEN_PIXEL_SIZE;
    vec2 grid_size = screen_size_pixels / float(pixel_factor);

    // Calculate snapped UV for pixelation
    vec2 snapped_uv = floor(UV * grid_size) / grid_size;
    
    // Get Color
    vec3 col = texture(screen_texture, snapped_uv).rgb;
    float lum = get_lum(col);

    // Get Dither Value using the integer grid coordinates
    // We use floor(UV * grid_size) which is integer coordinates (0..grid_width, 0..grid_height)
    vec2 pixel_coord = floor(UV * grid_size);
    float noise_val = get_dither_value(pixel_coord);

    // Apply Dither Threshold
    float dithered_val = lum + (noise_val - 0.5) * dither_spread;
    float dither_bit;

    if (dither_smoothing < 0.001) {
        dither_bit = step(0.5, dithered_val);
    } else {
        dither_bit = smoothstep(0.5 - dither_smoothing, 0.5 + dither_smoothing, dithered_val);
    }

    COLOR = vec4(mix(shadow_color, lit_color, dither_bit), 1.0);
}
