/// obj_cellular_world - Draw
/// 1920 x 1080 layout: world stats on the left, the cube view in the middle at 4x, messages on the right.

gpu_set_texfilter(false);
draw_set_halign(fa_left);
draw_set_valign(fa_top);

// ---------------------------------------------------------------- the cube view

var _surf = view_surfaces[view_mode];
if (!surface_exists(_surf)) {
    _surf = surface_create(world_size, world_size);
    view_surfaces[view_mode] = _surf;
    view_dirty[view_mode] = true;
}

if (view_dirty[view_mode]) {
    buffer_set_surface(view_buffers[view_mode], _surf, 0);
    view_dirty[view_mode] = false;
}

var _world_px = world_size * display_scale;
draw_surface_ext(_surf, world_left, world_top, display_scale, display_scale, 0, c_white, 1);

draw_set_colour(c_gray);
draw_rectangle(world_left - 2, world_top - 2, world_left + _world_px + 1, world_top + _world_px + 1, true);

draw_set_colour(c_white);
draw_set_halign(fa_center);
draw_text(world_left + (_world_px * 0.5), world_top - 24, view_names[view_mode]);
draw_set_halign(fa_left);

if (mouse_cell_x() >= 0 && mouse_cell_y() >= 0) {
    draw_set_colour(c_white);
    draw_set_alpha(0.5);
    draw_circle(mouse_x, mouse_y, brush_radius * display_scale, true);
    draw_set_alpha(1);
}

// ---------------------------------------------------------------- gather stats

var _mood_names  = ["purposeless", "content", "purposeful", "loyal", "proud"];
var _mood_counts = [0, 0, 0, 0, 0];
var _rank_counts = [0, 0, 0, 0, 0];
var _max_gen     = 0;
var _followed    = 0;

with (obj_cell) {
    follower_tally = 0;
}
with (obj_cell) {
    if (instance_exists(leader)) {
        leader.follower_tally += 1;
        _followed += 1;
    }
}

var _leaders = [];
with (obj_cell) {
    for (var i = 0; i < array_length(_mood_names); i++) {
        if (mood == _mood_names[i]) {
            _mood_counts[i] += 1;
        }
    }
    _rank_counts[rank] += 1;
    if (generation > _max_gen) {
        _max_gen = generation;
    }
    if (follower_tally > 0) {
        array_push(_leaders, { name : entity_name, rank : rank, followers : follower_tally, done : completions, spd : move_speed, sense : senses });
    }
}
array_sort(_leaders, function(_a, _b) {
    return _b.followers - _a.followers;
});

var _cell_total = max(1, instance_number(obj_cell));

// ---------------------------------------------------------------- left panel: the world

var _x   = left_panel_x;
var _w   = left_panel_w;
var _y   = 16;
var _row = 18;

draw_set_colour(c_white);
draw_text_transformed(_x, _y, "CELLULAR", 2, 2, 0);
_y += 36;

var _status = "RUNNING";
if (global.cellular_paused) {
    _status = "PAUSED";
}
draw_text(_x, _y, _status + "     time " + format_time((current_time - start_time) div 1000) + "     brush " + string(brush_radius));
_y += _row * 2;

draw_text(_x, _y, "WORLD");
_y += _row;
draw_set_colour(c_ltgray);
draw_text(_x, _y, "matter          " + string(static_count) + " pixels");
_y += _row;
draw_text(_x, _y, "cells           " + string(instance_number(obj_cell)) + " / " + string(limits.max_cells));
_y += _row;
draw_text(_x, _y, "lanterns        " + string(instance_number(obj_lantern)) + " / " + string(limits.max_lanterns));
_y += _row;
draw_text(_x, _y, "purposes        " + string(instance_number(obj_purpose)) + " / " + string(limits.max_purposes) + "     completed " + string(completed_purposes));
_y += _row;
draw_text(_x, _y, "generations     " + string(_max_gen));
_y += _row;
var _outreach = "off";
if (outreach_active) {
    _outreach = "ON";
}
draw_text(_x, _y, "purposelessness " + string(floor(outreach_level * 100)) + "%   outreach " + _outreach + "   roaming " + string(roaming_count));
_y += _row;
draw_text(_x, _y, "clones " + string(action_counts.clone) + "   lantern choices " + string(action_counts.become_lantern) + "   work " + string(action_counts.work));
_y += _row * 2;

draw_set_colour(c_white);
draw_text(_x, _y, "MOODS");
_y += _row;
for (var i = 0; i < array_length(_mood_names); i++) {
    var _bar_w = floor((_w - 170) * (_mood_counts[i] / _cell_total));
    draw_set_colour(c_ltgray);
    draw_text(_x, _y, _mood_names[i]);
    draw_set_colour(c_dkgray);
    draw_rectangle(_x + 110, _y + 4, _x + _w - 50, _y + 12, false);
    draw_set_colour(c_white);
    if (_bar_w > 0) {
        draw_rectangle(_x + 110, _y + 4, _x + 110 + _bar_w, _y + 12, false);
    }
    draw_text(_x + _w - 40, _y, string(_mood_counts[i]));
    _y += _row;
}
_y += _row;

draw_set_colour(c_white);
draw_text(_x, _y, "RANKS");
_y += _row;
draw_set_colour(c_ltgray);
for (var i = 0; i < array_length(rank_names); i++) {
    draw_text(_x, _y, rank_names[i] + " (" + string(rank_thresholds[i]) + "+ done)");
    draw_text(_x + _w - 40, _y, string(_rank_counts[i]));
    _y += _row;
}
_y += _row;

draw_set_colour(c_white);
draw_text(_x, _y, "FORCES   " + string(array_length(_leaders)) + " leaders, " + string(_followed) + " loyal followers");
_y += _row;
draw_set_colour(c_ltgray);
var _shown = min(6, array_length(_leaders));
if (_shown == 0) {
    draw_text(_x, _y, "none yet");
    _y += _row;
}
for (var i = 0; i < _shown; i++) {
    var _l = _leaders[i];
    draw_text(_x, _y, _l.name + "  " + rank_names[_l.rank] + "  followers " + string(_l.followers) + "  done " + string(_l.done) + "  spd " + string(_l.spd) + "  sense " + string(_l.sense));
    _y += _row;
}
_y += _row;

draw_set_colour(c_white);
draw_text(_x, _y, "PURPOSES");
_y += _row;
draw_set_colour(c_ltgray);
if (instance_number(obj_purpose) == 0) {
    draw_text(_x, _y, "none right now");
    _y += _row;
}
var _px0    = _x;
var _py0    = _y;
var _row0   = _row;
var _listed = 0;
var _max_listed = 10;
with (obj_purpose) {
    if (_listed < _max_listed) {
        var _state = "unfound";
        if (discovered) {
            _state = string(helpers_present()) + " here, " + string(assigned_count()) + "/" + string(want_helpers) + " signed up";
        }
        draw_text(_px0, _py0, label + "  " + string(floor(min(1, work_done / work_needed) * 100)) + "%  needs " + string(min_helpers) + "  " + _state);
        _py0 += _row0;
    }
    _listed += 1;
}
if (_listed > _max_listed) {
    draw_text(_px0, _py0, "+ " + string(_listed - _max_listed) + " more");
}

// Controls at the bottom of the left panel
var _controls = [
    "Space  seed a cell",
    "O      drop a purpose",
    "LMB    add pixels      RMB  remove",
    "Wheel  brush size      V    view",
    "G      new terrain     C    clear",
    "P      pause           K    wipe life",
    "F11    fullscreen"
];
var _cy = screen_h - 16 - (array_length(_controls) * _row);
draw_set_colour(c_white);
draw_text(_x, _cy - _row, "CONTROLS");
draw_set_colour(c_gray);
for (var i = 0; i < array_length(_controls); i++) {
    draw_text(_x, _cy + (i * _row), _controls[i]);
}

// ---------------------------------------------------------------- right panel: messages

var _rx = right_panel_x;
var _rw = right_panel_w;
var _ry = 16;

draw_set_colour(c_white);
draw_text_transformed(_rx, _ry, "MESSAGES", 2, 2, 0);
_ry += 44;

var _count = array_length(action_log);
for (var i = _count - 1; i >= 0; i--) {
    var _e    = action_log[i];
    var _line = "";
    if (_e.action == "feels") {
        _line = format_time(_e.time) + "  " + _e.who + " (" + _e.result + "): \"" + _e.reason + "\"";
        draw_set_colour(c_white);
    } else {
        _line = format_time(_e.time) + "  " + _e.who + "  " + _e.action + " " + _e.result;
        if (_e.reason != "") {
            _line += " - " + _e.reason;
        }
        draw_set_colour(c_ltgray);
        if (_e.result == "refused" || _e.result == "failed") {
            draw_set_colour(c_gray);
        }
    }
    var _h = string_height_ext(_line, -1, _rw);
    if (_ry + _h > screen_h - 16) {
        break;
    }
    draw_text_ext(_rx, _ry, _line, -1, _rw);
    _ry += _h + 4;
}

draw_set_colour(c_white);
