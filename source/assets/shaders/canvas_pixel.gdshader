shader_type canvas_item;

// --- MAIN CONTROLS ---
group_uniforms Main;
uniform float pixel_size : hint_range(1.0, 64.0) = 4.0;
uniform bool use_screen_texture = false;
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;

// --- DITHERING ---
group_uniforms Dithering;
uniform bool use_dithering = true;
uniform int dither_type : hint_enum("Bayer 8x8", "Bayer 4x4", "Blue Noise", "White Noise", "Diffused") = 0;
uniform float dither_size : hint_range(1.0, 8.0) = 2.0;
uniform float dither_amount : hint_range(0.0, 1.0) = 1.0;
uniform sampler2D blue_noise_texture : filter_nearest, repeat_enable;

// --- COLOR & PALETTE ---
group_uniforms Color;
uniform float color_depth : hint_range(1.0, 256.0) = 32.0;
uniform bool use_gradient = false;
uniform sampler2D color_gradient : source_color;
uniform float gradient_mix : hint_range(0.0, 1.0) = 1.0;

// Helper: Convert Color -> Brightness (Luminance)
float get_lum(vec3 color) {
	return dot(color, vec3(0.299, 0.587, 0.114));
}

float get_dither_noise(vec2 uv) {
	// Quantize the UVs (The "Pixel" Look)
	vec2 stepped_pos = floor(uv / dither_size);

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
	float noise_scaled = (noise - 0.5) * dither_amount / (bands - 1.0);
	float val = lum + noise_scaled;
	val = clamp(val, 0.0, 1.0);
	val = floor(val * bands);
	val = clamp(val, 0.0, bands - 1.0);
	val /= (bands - 1.0);
	return val;
}

void fragment() {
	vec2 resolution;
	vec2 base_uv;
	vec4 color;

	if (use_screen_texture) {
		resolution = 1.0 / SCREEN_PIXEL_SIZE;
		base_uv = SCREEN_UV;
	} else {
		resolution = 1.0 / TEXTURE_PIXEL_SIZE;
		base_uv = UV;
	}

	vec2 grid_size = resolution / pixel_size;
	vec2 uv = floor(base_uv * grid_size) / grid_size;
	uv += (1.0 / grid_size) * 0.5;

	if (use_screen_texture) {
		color = texture(screen_texture, uv);
	} else {
		color = texture(TEXTURE, uv);
	}

	if (use_dithering) {
		// Use FRAGCOORD to keep dither pattern screen-aligned
		float noise = get_dither_noise(FRAGCOORD.xy);

		if (use_gradient) {
			float lum = get_lum(color.rgb);
			float val = quantize_value(lum, noise);
			vec3 grad_color = texture(color_gradient, vec2(val, 0.0)).rgb;
			color.rgb = mix(color.rgb, grad_color, gradient_mix);
		} else {
			// Per-channel quantization
			vec3 c = color.rgb;
			float bands = max(2.0, color_depth);
			float noise_scaled = (noise - 0.5) * dither_amount / (bands - 1.0);

			c += noise_scaled;
			c = floor(c * bands) / (bands - 1.0);
			c = clamp(c, 0.0, 1.0);
			color.rgb = c;
		}
	}

	COLOR = color;
}
