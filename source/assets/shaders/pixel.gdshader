shader_type spatial;
render_mode unshaded, depth_test_disabled, cull_disabled, skip_vertex_transform;

uniform float resolution_scale : hint_range(0.01, 1.0) = 1.0;
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;

// --- DITHERING ---
group_uniforms Dithering;
uniform int dither_type : hint_enum("Bayer 8x8", "Bayer 4x4", "Blue Noise", "White Noise", "Diffused") = 0;
uniform int dither_mode : hint_enum("Screen Space", "World Space") = 0;
uniform float dither_size : hint_range(1.0, 8.0) = 2.0;
uniform float world_dither_density = 32.0;
uniform sampler2D blue_noise_texture : filter_nearest, repeat_enable;

// --- OVERLAY ---
group_uniforms Overlay;
uniform bool use_dither_overlay = false;
uniform float dither_overlay_strength : hint_range(0.0, 1.0) = 0.5;
uniform vec4 dither_overlay_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

// --- TRANSPARENCY ---
group_uniforms Transparency;
uniform bool use_transparency = false;
uniform float alpha_threshold : hint_range(0.0, 1.0) = 0.5;
uniform bool use_dithered_transparency = false;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

// Outline Uniforms
group_uniforms Outline;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform sampler2D normal_texture : hint_normal_roughness_texture, filter_nearest;

uniform vec4 line_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float line_thickness : hint_range(0.0, 10.0) = 1.0;
uniform float depth_threshold : hint_range(0.0, 5.0) = 0.5;
uniform float normal_threshold : hint_range(0.0, 1.0) = 0.5;
uniform float min_line_width = 0.0;
uniform float max_line_width = 10.0;

// Helper function
vec3 get_view_position_from_depth(vec2 uv, mat4 inv_mat) {
	float depth = texture(depth_texture, uv).x;
	vec3 ndc = vec3(uv * 2.0 - 1.0, depth);
	vec4 view_pos = inv_mat * vec4(ndc, 1.0);
	view_pos.xyz /= view_pos.w;
	return view_pos.xyz;
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

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec2 grid_size = floor(VIEWPORT_SIZE * resolution_scale);
	grid_size = max(grid_size, vec2(1.0));

	vec2 uv = floor(SCREEN_UV * grid_size) / grid_size;
	uv += (1.0 / grid_size) * 0.5;

	// Outline Logic
	vec2 outline_uv = uv;
	vec2 texel_size = vec2(1.0) / VIEWPORT_SIZE; // Use screen pixels for outlines
	float effective_thickness = clamp(line_thickness, min_line_width, max_line_width);
	vec2 offset_size = texel_size * effective_thickness;

	vec3 view_pos_c = get_view_position_from_depth(outline_uv, INV_PROJECTION_MATRIX);
	vec4 normal_sample = texture(normal_texture, outline_uv);
	vec3 normal_c = normal_sample.rgb * 2.0 - 1.0;
	float roughness_c = normal_sample.a;

	vec2 offsets[4] = {
		vec2(0.0, -1.0),
		vec2(0.0, 1.0),
		vec2(-1.0, 0.0),
		vec2(1.0, 0.0)
	};

	float edge_intensity = 0.0;

	// Only calculate outlines if roughness is above threshold (0.0 means no outlines)
	if (roughness_c >= 0.04) {
		for (int i = 0; i < 4; i++) {
			vec2 uv_n = outline_uv + offsets[i] * offset_size;

			// Check bounds to avoid edge artifacts
			if (uv_n.x < 0.0 || uv_n.x > 1.0 || uv_n.y < 0.0 || uv_n.y > 1.0) {
				continue;
			}

			vec3 view_pos_n = get_view_position_from_depth(uv_n, INV_PROJECTION_MATRIX);
			vec3 normal_n = texture(normal_texture, uv_n).rgb * 2.0 - 1.0;

			float dist = distance(view_pos_c, view_pos_n);
			if (dist > depth_threshold) {
				edge_intensity += 1.0;
			}

			float dot_diff = dot(normal_c, normal_n);
			if (dot_diff < normal_threshold) {
				edge_intensity += 1.0;
			}
		}
	}

	edge_intensity = clamp(edge_intensity, 0.0, 1.0);

	vec3 screen_color = texture(screen_texture, uv).rgb;
	vec3 final_color = mix(screen_color, line_color.rgb, edge_intensity * line_color.a);

	float noise = 0.0;
	if (use_dithered_transparency || use_dither_overlay) {
		vec2 dither_coord;
		if (dither_mode == 1) { // World Space
			vec3 world_pos = (INV_VIEW_MATRIX * vec4(view_pos_c, 1.0)).xyz;
			vec3 world_normal = normalize((INV_VIEW_MATRIX * vec4(normal_c, 0.0)).xyz);
			vec3 blend = abs(world_normal);
			blend /= (blend.x + blend.y + blend.z);

			vec2 world_uv;
			if (blend.x > blend.y && blend.x > blend.z) {
				world_uv = world_pos.zy;
			} else if (blend.y > blend.z) {
				world_uv = world_pos.xz;
			} else {
				world_uv = world_pos.xy;
			}
			dither_coord = world_uv * world_dither_density;
		} else { // Screen Space
			// Use the quantized grid coordinates to ensure dither aligns with pixels
			dither_coord = floor(SCREEN_UV * grid_size);
		}

		noise = get_dither_noise(dither_coord);
	}

	if (use_dither_overlay) {
		final_color = mix(final_color, dither_overlay_color.rgb, noise * dither_overlay_strength * dither_overlay_color.a);
	}

	ALBEDO = final_color;

	// --- TRANSPARENCY ---
	if (use_transparency) {
		if (opacity < alpha_threshold) {
			discard;
		}
	}

	if (use_dithered_transparency) {
		if (opacity < noise) {
			discard;
		}
	}

	ALPHA = opacity;
}
