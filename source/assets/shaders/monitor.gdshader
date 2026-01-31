shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, ambient_light_disabled;

// --- TEXTURE SETTINGS ---
uniform sampler2D texture_albedo : source_color, filter_nearest;
uniform vec3 albedo_color : source_color = vec3(1.0);

// --- BACKLIGHT SETTINGS ---
group_uniforms Backlight;
uniform float backlight_strength : hint_range(0.0, 10.0) = 1.0; 
uniform float backlight_floor : hint_range(0.0, 1.0) = 0.05; 
uniform vec3 backlight_tint : source_color = vec3(1.0);

// --- CRT EFFECT SETTINGS ---
group_uniforms CRT_Effects;
uniform bool crt_enabled = true;
uniform float crt_curve : hint_range(0.0, 0.1) = 0.02; 
uniform float scanline_count : hint_range(50.0, 1000.0) = 300.0;
uniform float scanline_opacity : hint_range(0.0, 1.0) = 0.4;
uniform float static_noise_power : hint_range(0.0, 1.0) = 0.08;
uniform float vignette_strength : hint_range(0.0, 2.0) = 1.0;

// --- RESOLUTION (PIXELATION) ---
group_uniforms Resolution;
uniform bool pixelate = true;
uniform vec2 pixel_resolution = vec2(320.0, 240.0);

// --- HELPER FUNCTIONS ---
float random(vec2 uv) {
    return fract(sin(dot(uv.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

vec2 warp_uv(vec2 uv) {
    vec2 centered_uv = uv * 2.0 - 1.0;
    vec2 offset = abs(centered_uv.yx) / vec2(6.0, 4.0);
    centered_uv = centered_uv + centered_uv * offset * offset * crt_curve * 10.0;
    return centered_uv * 0.5 + 0.5;
}

void fragment() {
    vec2 final_uv = UV;
    float border_mask = 1.0;
    
    // 1. CRT WARP
    if (crt_enabled) {
        final_uv = warp_uv(UV);
        // Calculate Mask: 1.0 if inside screen, 0.0 if outside
        vec2 within_border = step(vec2(0.0), final_uv) * step(final_uv, vec2(1.0));
        border_mask = within_border.x * within_border.y;
    }

    // 2. PIXELATION (Low-Res Camera Filter)
    vec2 sample_uv = final_uv;
    if (pixelate) {
        sample_uv = floor(final_uv * pixel_resolution) / pixel_resolution;
    }

    // 3. SAMPLE TEXTURE
    vec4 tex_color = texture(texture_albedo, sample_uv);
    vec3 base_color = albedo_color * tex_color.rgb;

    // 4. APPLY EFFECTS (Only if inside the border to save perf and avoid bugs)
    if (crt_enabled && border_mask > 0.0) {
        // A. Grayscale
        float lum = dot(base_color, vec3(0.299, 0.587, 0.114));
        base_color = vec3(lum);

        // B. Scanlines
        float s = sin(final_uv.y * scanline_count * 3.14159 * 2.0);
        s = (s * 0.5 + 0.5); 
        base_color *= mix(1.0, s, scanline_opacity);

        // C. Static Noise
        float noise = random(final_uv + vec2(TIME * 10.0, 0.0));
        base_color += (noise - 0.5) * static_noise_power;

        // D. Vignette (FIXED)
        // We use ABS to prevent negative numbers from crashing pow()
        vec2 d = final_uv * (1.0 - final_uv);
        float vig = pow(abs(d.x * d.y) * 15.0, vignette_strength); 
        base_color *= clamp(vig, 0.0, 1.0);
    }

    // 5. APPLY MASK
    // Zeros out everything outside the curved screen
    base_color *= border_mask;

    // 6. FINAL OUTPUT
    ALBEDO = base_color; 

    // Backlight logic
    vec3 image_glow = base_color * backlight_strength;
    // Floor glow ensures the black parts of the screen aren't 100% void
    vec3 floor_glow = vec3(backlight_floor) * backlight_tint * border_mask;

    EMISSION = image_glow + floor_glow;
}