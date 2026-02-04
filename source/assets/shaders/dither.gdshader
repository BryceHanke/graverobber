shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

// --- COLOR & PALETTE ---
group_uniforms Color_Style;
uniform sampler2D texture_albedo : source_color, filter_nearest;
uniform vec3 lit_color : source_color = vec3(1.0, 1.0, 1.0);

group_uniforms Normal_Map;
uniform sampler2D texture_normal : hint_normal, filter_nearest;
uniform float normal_scale : hint_range(-16.0, 16.0) = 1.0;
uniform vec3 shadow_color : source_color = vec3(0.0, 0.0, 0.0);
uniform sampler2D color_gradient : source_color;
uniform bool use_gradient = false;
uniform bool use_inverse_gradient = false;
// Amount of colors/bands
uniform float color_depth : hint_range(1.0, 256.0) = 32.0;

group_uniforms Roughness;
uniform sampler2D texture_roughness : hint_roughness_r, filter_nearest;
uniform float roughness_scale : hint_range(0.0, 1.0) = 1.0;

// --- TRANSPARENCY ---
group_uniforms Transparency;
uniform bool use_transparency = false;
uniform float alpha_threshold : hint_range(0.0, 1.0) = 0.5;
uniform int cull_mode : hint_enum("Back", "Front", "Disabled") = 0;
uniform bool use_dithered_transparency = false;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

group_uniforms Outline_Options;
uniform bool no_outlines = false;

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
uniform float shadow_bias : hint_range(-1.0, 1.0) = 0.0;
uniform sampler2D blue_noise_texture : hint_default_white, filter_nearest, repeat_enable;

group_uniforms Texture_Controls;
uniform int albedo_mapping : hint_enum("Object UV", "World Space") = 0;
uniform vec2 uv_scale = vec2(1.0, 1.0);
uniform vec2 uv_offset = vec2(0.0, 0.0);

group_uniforms Lighting;
uniform vec3 global_ambient : source_color = vec3(0.1, 0.1, 0.1);
uniform float light_boost : hint_range(1.0, 100.0) = 2.0;

group_uniforms Bounce_Lighting;
uniform float bounce_strength : hint_range(0.0, 5.0) = 0.5;

// --- VARYINGS ---
varying vec3 v_world_pos;
varying vec3 v_world_norm;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_norm = MODEL_NORMAL_MATRIX * NORMAL;
}

// --- DITHER MAPPING ---

// Helper: Convert Color -> Brightness (Luminance)
float get_lum(vec3 color) {
	return dot(color, vec3(0.299, 0.587, 0.114));
}

float get_dither_noise(vec2 uv) {
	// Quantize the UVs (The "Pixel" Look)
	// We don't apply density here, as it's passed into UV before calling this function
	vec2 stepped_pos = floor(uv / dither_pixel_size);

	if (dither_type == 0) { // Bayer 8x8
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
		int x = int(mod(stepped_pos.x, 8.0));
		int y = int(mod(stepped_pos.y, 8.0));
		int idx = y * 8 + x;
		return float(bayer8[idx]) / 64.0;
	}
	else if (dither_type == 1) { // Bayer 4x4
		const int bayer4[16] = {
			0, 8, 2, 10,
			12, 4, 14, 6,
			3, 11, 1, 9,
			15, 7, 13, 5
		};
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
	else { // Diffused (IGN) - dither_type == 4 or default
		vec3 magic = vec3(0.06711056, 0.00583715, 52.9829189);
		return fract(magic.z * fract(dot(stepped_pos, magic.xy)));
	}
}

float quantize_value(float lum, float noise) {
	float bands = max(2.0, color_depth);
	float noise_scaled = (noise - 0.5) * dither_spread / (bands - 1.0);
	float val = lum + noise_scaled + shadow_bias;
	val = clamp(val, 0.0, 1.0);
	val = floor(val * bands);
	val = clamp(val, 0.0, bands - 1.0);
	val /= (bands - 1.0);
	return val;
}

void fragment() {
	// Culling
	if ((cull_mode == 0 && !FRONT_FACING) || (cull_mode == 1 && FRONT_FACING)) {
		discard;
	}

	// 0. Texture Read with Scale/Offset
	vec2 uv = UV * uv_scale + uv_offset;
	vec4 tex;
	if (albedo_mapping == 1) { // World Space
		vec3 world_norm = normalize(v_world_norm);
		vec3 blend = abs(world_norm);
		blend /= (blend.x + blend.y + blend.z);

		vec4 x_tex = texture(texture_albedo, v_world_pos.zy * uv_scale + uv_offset);
		vec4 y_tex = texture(texture_albedo, v_world_pos.xz * uv_scale + uv_offset);
		vec4 z_tex = texture(texture_albedo, v_world_pos.xy * uv_scale + uv_offset);

		tex = x_tex * blend.x + y_tex * blend.y + z_tex * blend.z;
	} else { // Object UV
		tex = texture(texture_albedo, uv);
	}
	vec3 base_color = tex.rgb;

	NORMAL_MAP = texture(texture_normal, uv).rgb;
	NORMAL_MAP_DEPTH = normal_scale;

	if (use_transparency && tex.a < alpha_threshold) {
		discard;
	}

	// 1. Get Brightness
	float texture_brightness = get_lum(base_color);

	// --- AMBIENT PASS ---
	float ambient_brightness = get_lum(global_ambient);

	// Bounce Light
	vec3 world_normal = normalize(v_world_norm);
	float bounce_factor = clamp(-world_normal.y * 0.5 + 0.5, 0.0, 1.0);
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
		vec3 world_norm = normalize(v_world_norm);
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
	// Pre-scale UV by density before passing to noise function
	float noise_val = get_dither_noise(dither_uv * density);

	if (use_dithered_transparency) {
		float alpha = tex.a * opacity;
		if (alpha <= 0.0 || alpha < noise_val) {
			discard;
		}
	}

	// Pass dither noise in SPECULAR for light().
	SPECULAR = noise_val;
	METALLIC = 0.0;

	float r = texture(texture_roughness, uv).r * roughness_scale;
	ROUGHNESS = r;

	// 4. Output Logic
	vec3 final_albedo;
	float val = quantize_value(total_ambient_lum, noise_val);

	if (use_gradient) {
		float gradient_val = use_inverse_gradient ? 1.0 - val : val;
		final_albedo = texture(color_gradient, vec2(gradient_val, 0.0)).rgb;
	} else {
		final_albedo = mix(shadow_color, base_color * lit_color, val);
	}

	ALBEDO = vec3(0.0);
	EMISSION = final_albedo;
}

void light() {
	// 0. Texture Read
	vec4 tex;
	if (albedo_mapping == 1) { // World Space
		vec3 world_norm = normalize(v_world_norm);
		vec3 blend = abs(world_norm);
		blend /= (blend.x + blend.y + blend.z);

		vec4 x_tex = texture(texture_albedo, v_world_pos.zy * uv_scale + uv_offset);
		vec4 y_tex = texture(texture_albedo, v_world_pos.xz * uv_scale + uv_offset);
		vec4 z_tex = texture(texture_albedo, v_world_pos.xy * uv_scale + uv_offset);

		tex = x_tex * blend.x + y_tex * blend.y + z_tex * blend.z;
	} else { // Object UV
		vec2 uv = UV * uv_scale + uv_offset;
		tex = texture(texture_albedo, uv);
	}
	vec3 base_color = tex.rgb;
	float texture_brightness = get_lum(base_color);

	// 1. Dither Calculation - Reuse from Fragment
	float noise_val = SPECULAR_AMOUNT;

	// 2. Calculate Dynamic Light Brightness
	float NdotL = max(0.0, dot(NORMAL, LIGHT));
	vec3 light_intensity = LIGHT_COLOR * NdotL * ATTENUATION * light_boost;
	float light_brightness = get_lum(light_intensity);

	// 3. Combined Brightness
	float total_lum = light_brightness * texture_brightness;

	// 4. Add Light
	float val = quantize_value(total_lum, noise_val);

	if (use_gradient) {
		float gradient_pos = use_inverse_gradient ? 1.0 - val : val;
		vec3 lit_c = texture(color_gradient, vec2(gradient_pos, 0.0)).rgb;
		SPECULAR_LIGHT += lit_c;
	} else {
		SPECULAR_LIGHT += mix(vec3(0.0), base_color * lit_color, val);
	}
}
