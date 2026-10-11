/// obj_cellular_world - Draw GUI

draw_set_colour(c_white);
draw_set_halign(fa_left);
draw_set_valign(fa_top);

var _status = "RUNNING";
if (global.cellular_paused) {
    _status = "PAUSED";
}

draw_text(8, ui_top + 4, "CELLULAR  [" + _status + "]   view: " + view_names[view_mode]);

draw_text(8, ui_top + 22, "cells " + string(instance_number(obj_cell)) + "/" + string(limits.max_cells)
    + "   lanterns " + string(instance_number(obj_lantern)) + "/" + string(limits.max_lanterns)
    + "   clones " + string(action_counts.clone)
    + "   lantern choices " + string(action_counts.become_lantern)
    + "   brush " + string(brush_radius));

draw_text(8, ui_top + 40, "Space seed   LMB add   RMB remove   Wheel brush   V view   G terrain   C clear   P pause   K wipe life");

var _count = array_length(action_log);
if (_count > 0) {
    var _last = action_log[_count - 1];
    draw_text(8, ui_top + 58, "last: " + _last.who + "  " + _last.action + "  " + _last.result + "  " + _last.reason);
}
