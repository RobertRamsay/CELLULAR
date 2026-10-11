/// obj_cell - Draw

global.cellular_world.draw_marker(cx, cy, cz, false, 0);

if (bubble_timer > 0) {
    global.cellular_world.draw_bubble(cx, cy, cz, bubble_text);
}
