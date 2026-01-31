shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

// --- COLOR & PALETTE ---
group_uniforms Color_Style;
uniform int color_mode : hint_enum("Bit-Depth", "Monochrome", "Original", "Posterized") = 0;
uniform sampler2D texture_albedo : source_color, filter_nearest;
uniform vec3 lit_color : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 shadow_color : source_color = vec3(0.0, 0.0, 0.0);
uniform sampler2D color_gradient : source_color;
uniform bool use_gradient = false;
uniform float palette_size : hint_range(1.0, 16.0) = 4.0;
uniform bool use_bit_depth = false;
uniform float color_depth : hint_range(1.0, 32.0) = 8.0;

// --- TRANSPARENCY ---
group_uniforms Transparency;
uniform bool use_transparency = false;
uniform float alpha_threshold : hint_range(0.0, 1.0) = 0.5;

// --- DITHERING STYLE ---
group_uniforms Dithering_Style;
uniform int dither_type : hint_enum("Bayer 8x8", "Bayer 4x4", "Blue Noise", "White Noise", "Diffused") = 0;
uniform int dither_mode : hint_enum("Object UV", "Screen Space", "World Space") = 2;
// How "chunky" the pixels are
uniform float dither_pixel_size : hint_range(1.0, 8.0) = 2.0;
// How dense the grid is (Higher = smaller dots)
uniform float dither_density = 2048.0;
uniform float world_dither_density = 32.0;
// Smoothness of the gradient (0.01 = Hard Cut, 0.5 = Smooth Fade)
uniform float dither_spread : hint_range(0.01, 2.0) = 0.5;
uniform float dither_smoothing : hint_range(0.0, 2.0) = 0.05;
uniform float shadow_bias : hint_range(-1.0, 1.0) = 0.0;
uniform sampler2D blue_noise_texture : hint_default_white, filter_nearest, repeat_enable;

group_uniforms Texture_Controls;
uniform vec2 uv_scale = vec2(1.0, 1.0);
uniform vec2 uv_offset = vec2(0.0, 0.0);

group_uniforms Lighting;
uniform vec3 global_ambient : source_color = vec3(0.1, 0.1, 0.1);
uniform float light_boost : hint_range(1.0, 100.0) = 2.0;

group_uniforms Bounce_Lighting;
uniform float bounce_strength : hint_range(0.0, 5.0) = 0.5;

// --- VARYINGS ---
varying vec3 v_local_pos;
varying vec3 v_world_pos;

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
    v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
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
    // 0. Texture Read with Scale/Offset
    vec2 uv = UV * uv_scale + uv_offset;
    vec4 tex = texture(texture_albedo, uv);
    vec3 base_color = tex.rgb;

    if (use_transparency && tex.a < alpha_threshold) {
        discard;
    }

    // 1. Get Brightness
    float texture_brightness = get_lum(base_color);

    // --- AMBIENT PASS ---
    // Combined Brightness = Ambient Light * Texture Dark/Lightness
    float ambient_brightness = get_lum(global_ambient);

    // Bounce Light (Simulating ground bounce, so facing down gets light)
    vec3 world_normal = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
    float bounce_factor = -world_normal.y * 0.5 + 0.5;
    bounce_factor = clamp(bounce_factor, 0.0, 1.0);
    bounce_factor = pow(bounce_factor, 2.0);
    float bounce_lum = bounce_strength * bounce_factor;

    float total_ambient_lum = (ambient_brightness + bounce_lum) * texture_brightness;

    // 2. Dither Calculation
    vec2 dither_uv;
    if (dither_mode == 0) { // Object UV
        dither_uv = uv;
    } else if (dither_mode == 1) { // Screen Space
        dither_uv = SCREEN_UV;
    } else { // World Space
        // Triplanar Mapping
        vec3 world_norm = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
        vec3 blend = abs(world_norm);
        blend /= (blend.x + blend.y + blend.z);
        if (blend.x > blend.y && blend.x > blend.z) {
             dither_uv = v_world_pos.zy;
        } else if (blend.y > blend.z) {
             dither_uv = v_world_pos.xz;
        } else {
             dither_uv = v_world_pos.xy;
        }
    }
    float density = (dither_mode == 2) ? world_dither_density : dither_density;
    float noise_val = get_uv_dither(dither_uv, density, dither_pixel_size);

    // 3. Apply Threshold with Spread and Bias
    float dithered_val = total_ambient_lum + (noise_val - 0.5) * dither_spread + shadow_bias;
    float dither_bit;
    if (dither_smoothing < 0.001) {
        dither_bit = step(0.5, dithered_val);
    } else {
        dither_bit = smoothstep(0.5 - dither_smoothing, 0.5 + dither_smoothing, dithered_val);
    }

    // 4. Output Logic

    vec3 final_albedo;

    // Determine Palette Size
    float p_size = palette_size;
    if (use_bit_depth) {
        if (color_mode == 0 || color_mode == 1) {
            p_size = pow(2.0, color_depth);
        } else {
            p_size = pow(2.0, color_depth / 3.0);
        }
    }

    if (color_mode == 0) { // Bit-Depth
         float bands = max(2.0, p_size);
         float val = clamp(dithered_val, 0.0, 1.0);
         val = floor(val * bands);
         val = clamp(val, 0.0, bands - 1.0);
         val /= (bands - 1.0);

         if (use_gradient) {
             final_albedo = texture(color_gradient, vec2(val, 0.0)).rgb;
         } else {
             final_albedo = mix(shadow_color, lit_color, val);
         }
    }
    else if (color_mode == 1) { // Monochrome
         float val = clamp(dithered_val, 0.0, 1.0);
         if (use_bit_depth) {
             float bands = max(2.0, p_size);
             val = floor(val * bands) / (bands - 1.0);
         }

         if (use_gradient) {
             final_albedo = texture(color_gradient, vec2(val, 0.0)).rgb;
         } else {
             final_albedo = mix(shadow_color, lit_color, val);
         }
    }
    else if (color_mode == 2) { // Original
         final_albedo = base_color;
    }
    else if (color_mode == 3) { // Posterized
         if (use_gradient) {
             float lum = get_lum(base_color);
             float q_lum = floor(lum * p_size) / p_size;
             final_albedo = texture(color_gradient, vec2(q_lum, 0.0)).rgb;
         } else {
             // Quantize the base color
             final_albedo = floor(base_color * p_size) / p_size;
         }
    }

    ALBEDO = final_albedo;

    // Disable Emission so we don't double-light.
    EMISSION = vec3(0.0);

    // Pass dither noise in Roughness for potential post-processing effects
    ROUGHNESS = noise_val;
    METALLIC = 0.0;
    SPECULAR = 0.0;
}

void light() {
    // 0. Texture Read
    vec2 uv = UV * uv_scale + uv_offset;
    vec4 tex = texture(texture_albedo, uv);
    vec3 base_color = tex.rgb;
    float texture_brightness = get_lum(base_color);

    // 1. Calculate Dynamic Light Brightness
    float NdotL = max(0.0, dot(NORMAL, LIGHT));
    vec3 light_intensity = LIGHT_COLOR * NdotL * ATTENUATION * light_boost;
    float light_brightness = get_lum(light_intensity);

    // Combined Brightness
    float total_lum = light_brightness * texture_brightness;

    // 2. Recalculate Dither for Light Pass
    vec2 dither_uv;
    if (dither_mode == 0) { // Object UV
        dither_uv = uv;
    } else if (dither_mode == 1) { // Screen Space
        dither_uv = SCREEN_UV;
    } else { // World Space
        vec3 world_norm = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
        vec3 blend = abs(world_norm);
        blend /= (blend.x + blend.y + blend.z);
        if (blend.x > blend.y && blend.x > blend.z) {
             dither_uv = v_world_pos.zy;
        } else if (blend.y > blend.z) {
             dither_uv = v_world_pos.xz;
        } else {
             dither_uv = v_world_pos.xy;
        }
    }
    float density = (dither_mode == 2) ? world_dither_density : dither_density;
    float noise_val = get_uv_dither(dither_uv, density, dither_pixel_size);

    // 3. Apply Threshold
    float dithered_val = total_lum + (noise_val - 0.5) * dither_spread + shadow_bias;
    float dither_bit;
    if (dither_smoothing < 0.001) {
        dither_bit = step(0.5, dithered_val);
    } else {
        dither_bit = smoothstep(0.5 - dither_smoothing, 0.5 + dither_smoothing, dithered_val);
    }

    // Determine Palette Size for Light Pass consistency
    float p_size = palette_size;
    if (use_bit_depth) {
        if (color_mode == 0 || color_mode == 1) {
            p_size = pow(2.0, color_depth);
        } else {
            p_size = pow(2.0, color_depth / 3.0);
        }
    }

    // 4. Add Light

    if (color_mode == 0) { // Bit-Depth
         float bands = max(2.0, p_size);
         float val = clamp(dithered_val, 0.0, 1.0);
         val = floor(val * bands);
         val = clamp(val, 0.0, bands - 1.0);
         val /= (bands - 1.0);

         if (use_gradient) {
             vec3 lit_c = texture(color_gradient, vec2(1.0, 0.0)).rgb;
             SPECULAR_LIGHT += mix(vec3(0.0), lit_c, val);
         } else {
             SPECULAR_LIGHT += mix(vec3(0.0), lit_color, val);
         }
    }
    else if (color_mode == 1) { // Monochrome
         float val = clamp(dithered_val, 0.0, 1.0);
         if (use_bit_depth) {
             float bands = max(2.0, p_size);
             val = floor(val * bands) / (bands - 1.0);
         }

         if (use_gradient) {
             // Sample gradient at full light intensity
             vec3 lit_c = texture(color_gradient, vec2(1.0, 0.0)).rgb;
             SPECULAR_LIGHT += mix(vec3(0.0), lit_c, val);
         } else {
             SPECULAR_LIGHT += mix(vec3(0.0), lit_color, val);
         }
    }
    else {
         // Original / Posterized
         vec3 effective_albedo = base_color;
         if (color_mode == 3 && use_gradient) {
             float lum = get_lum(base_color);
             float q_lum = floor(lum * p_size) / p_size;
             effective_albedo = texture(color_gradient, vec2(q_lum, 0.0)).rgb;
         } else if (color_mode == 3) {
             effective_albedo = floor(base_color * p_size) / p_size;
         }

         DIFFUSE_LIGHT += LIGHT_COLOR * NdotL * ATTENUATION * effective_albedo;
    }
}
