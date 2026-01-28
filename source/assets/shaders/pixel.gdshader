shader_type canvas_item;

// How big each "pixel" should be. 
// 1 = Native resolution. 4 = 1/4th resolution (Gameboy style).
uniform int pixel_factor : hint_range(1, 16) = 4;

// We need the screen texture to read the scene behind this shader.
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;

void fragment() {
    // 1. Get the current screen resolution
    vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;
    
    // 2. Calculate the "virtual" low-res grid size
    vec2 grid_size = screen_size / float(pixel_factor);
    
    // 3. Snap the current UV to that grid
    // We floor() to snap to the nearest grid line, then divide to get back to 0-1 UV space
    vec2 snapped_uv = floor(UV * grid_size) / grid_size;
    
    // 4. Sample the screen at the snapped position
    // We strictly use the snapped UV to get that blocky look
    COLOR = texture(screen_texture, snapped_uv);
}