shader_type spatial;
render_mode cull_front, unshaded, skip_vertex_transform;

uniform vec4 color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float width : hint_range(0.0, 100.0) = 2.0;
uniform bool use_smooth_normals = true;
uniform float depth_bias : hint_range(-10.0, 10.0) = 0.0;

void vertex() {
	// 1. Calculate the clip-space position of the original vertex
	// We use MODELVIEW_MATRIX and PROJECTION_MATRIX manually because of skip_vertex_transform
	vec4 clip_position = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);

	// 2. Select the normal to use for extrusion
	vec3 normal_model = NORMAL;
	if (use_smooth_normals) {
		// Decode the smooth normal from the Vertex Color (0..1 -> -1..1)
		// We assume the baker stored it as (normal * 0.5 + 0.5)
		normal_model = COLOR.rgb * 2.0 - 1.0;
	}

	// 3. Convert the normal to Clip Space
	// First convert to View Space
	vec3 normal_view = mat3(MODELVIEW_MATRIX) * normal_model;
	
	// Then project to Clip Space (as a vector, so w=0)
	vec4 normal_clip = PROJECTION_MATRIX * vec4(normal_view, 0.0);

	// 4. Calculate the screen-space offset
	// We only care about the XY direction in screen space
	vec2 normal_screen = normalize(normal_clip.xy);
	
	// Calculate the offset size in NDC (Normalized Device Coordinates)
	// NDC range is [-1, 1], so the total size is 2.0.
	// width is in pixels.
	vec2 offset_ndc = normal_screen * (width * 2.0 / VIEWPORT_SIZE);
	
	// 5. Apply Perspective Compensation
	// We are adding to the Clip Space position (pre-w-divide).
	// To maintain constant screen size, we multiply by w.
	vec2 offset_clip = offset_ndc * clip_position.w;
	
	// Apply the offset
	clip_position.xy += offset_clip;
	
	// 6. Apply Depth Bias
	// Bias the depth slightly to prevent Z-fighting with the main mesh
	// We adjust the Z coordinate in Clip Space (or View Space)
	// A small negative bias in View Space Z pulls it closer?
	// Or we can just subtract from clip_position.z if we know the depth range.
	// Let's modify the final Z slightly.
	// Note: Clip Space Z is non-linear.
	// A safe way is to push the z slightly towards the near plane.
	// But `depth_bias` is a float. Let's assume it's a small offset in View Space roughly
	// or just a raw offset to clip Z.
	// Let's try subtracting a small amount scaled by w to keep it relative.
	// A standard "slope scale bias" approach is hard here.
	// We'll interpret depth_bias as a generic "pull forward" factor.
	// In Godot (Vulkan), Z is 0 (near) to 1 (far) in NDC usually, but Clip Z depends on projection.
	// Let's just use a simple constant offset to w-scaled Z, or modifying view position before projection.
	// Let's modify the View Space position before projection for the bias.
	
	// Re-calculating with bias in View Space for better control:
	vec4 view_position = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	view_position.z += depth_bias * 0.001; // Scale down for usability
	// Re-project
	clip_position = PROJECTION_MATRIX * view_position;
	// Re-apply offset
	clip_position.xy += offset_ndc * clip_position.w;

	POSITION = clip_position;
}

void fragment() {
	ALBEDO = color.rgb;
	ALPHA = color.a;
}
