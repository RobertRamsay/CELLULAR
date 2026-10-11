/// obj_cell - Draw

var _world = global.cellular_world;

if (instance_exists(leader)) {
    _world.draw_link(cx, cy, cz, leader.cx, leader.cy, leader.cz);
}

_world.draw_marker(cx, cy, cz, false, 0, rank);

if (bubble_timer > 0) {
    _world.draw_bubble(cx, cy, cz, bubble_text);
}
