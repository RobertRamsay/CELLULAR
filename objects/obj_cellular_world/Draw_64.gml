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
    + "   purposes " + string(instance_number(obj_purpose)) + "/" + string(limits.max_purposes)
    + "   done " + string(completed_purposes)
    + "   brush " + string(brush_radius));

var _purposeless = 0;
var _content     = 0;
var _purposeful  = 0;
var _proud       = 0;
with (obj_cell) {
    if (mood == "purposeless") {
        _purposeless += 1;
    } else if (mood == "content") {
        _content += 1;
    } else if (mood == "purposeful") {
        _purposeful += 1;
    } else {
        _proud += 1;
    }
}
draw_text(8, ui_top + 40, "moods   purposeless " + string(_purposeless) + "   content " + string(_content)
    + "   purposeful " + string(_purposeful) + "   proud " + string(_proud));

draw_text(8, ui_top + 58, "Space seed   O purpose   LMB add   RMB remove   Wheel brush   V view   G terrain   C clear   P pause   K wipe life");

var _count = array_length(action_log);
if (_count > 0) {
    var _last = action_log[_count - 1];
    draw_text(8, ui_top + 76, "last: " + _last.who + "  " + _last.action + "  " + _last.result + "  " + _last.reason);
}
