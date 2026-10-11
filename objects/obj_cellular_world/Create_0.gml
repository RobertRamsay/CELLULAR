/// obj_cellular_world - Create
/// CELLULAR: a 256 x 256 x 256 voxel room. Static pixels are matter; cells are living pixels.

global.cellular_paused = false;
global.cellular_world  = id;

depth         = 50;
world_size    = 256;
world_volume  = world_size * world_size * world_size;
display_scale = 4;

// Screen layout (room is 1920 x 1080; the window scales it)
screen_w      = 1920;
screen_h      = 1080;
world_left    = (screen_w - (world_size * display_scale)) div 2;
world_top     = 40;
panel_margin  = 16;
left_panel_x  = panel_margin;
left_panel_w  = world_left - (panel_margin * 2);
right_panel_x = world_left + (world_size * display_scale) + panel_margin;
right_panel_w = screen_w - right_panel_x - panel_margin;
start_time    = current_time;
brush_radius  = 3;
brush_min     = 1;
brush_max     = 12;

// Voxel values
voxel_empty   = 0;
voxel_static  = 1;
voxel_cell    = 2;
voxel_lantern = 3;
voxel_purpose = 4;

// 16 MB voxel store. Index = z + (x * 256) + (y * 65536) so every Z column is contiguous.
voxels = buffer_create(world_volume, buffer_fixed, 1);
buffer_fill(voxels, 0, buffer_u8, voxel_empty, world_volume);

// Projection caches (static pixels only)
// top_cache[x, y]   = highest static Z, or -1
// front_cache[x, z] = nearest static Y, or world_size
// side_cache[y, z]  = nearest static X, or world_size
top_cache   = ds_grid_create(world_size, world_size);
front_cache = ds_grid_create(world_size, world_size);
side_cache  = ds_grid_create(world_size, world_size);
ds_grid_clear(top_cache, -1);
ds_grid_clear(front_cache, world_size);
ds_grid_clear(side_cache, world_size);

// Views: 0 = top, 1 = front, 2 = side
view_mode     = 0;
view_names    = ["TOP - looking down Z, grey = height", "FRONT - looking along Y, grey = nearness", "SIDE - looking along X, grey = nearness"];
view_buffers  = [-1, -1, -1];
view_surfaces = [-1, -1, -1];
view_dirty    = [true, true, true];
for (var i = 0; i < 3; i++) {
    view_buffers[i] = buffer_create(world_size * world_size * 4, buffer_fixed, 1);
    buffer_fill(view_buffers[i], 0, buffer_u32, $FF000000, world_size * world_size * 4);
}

limits = {
    max_cells            : 64,
    max_lanterns         : 24,
    decision_steps       : game_get_speed(gamespeed_fps) * 10,
    tick_steps           : 6,
    max_actions_per_tick : 1,
    clone_cost           : 0.6,
    move_cost            : 0.004,
    dig_cost             : 0.01,
    place_cost           : 0.01,
    energy_regen         : 0.002,
    crowd_radius         : 12,
    lantern_life         : game_get_speed(gamespeed_fps) * 60,

    // Purposes
    max_purposes         : 3,
    purpose_interval_min : game_get_speed(gamespeed_fps) * 20,
    purpose_interval_max : game_get_speed(gamespeed_fps) * 40,
    perception_radius    : 20,
    hearing_radius       : 28,
    relay_radius         : 8,
    work_radius          : 2,
    work_rate            : 1,
    rally_ticks          : 60,
    wait_ticks           : 40,
    reward_energy        : 0.5,
    reward_pride         : 0.25,

    // Mood
    usage_rate           : 0.0017,
    proud_threshold      : 0.6,
    purposeless_threshold: 0.15,
    express_min_steps    : game_get_speed(gamespeed_fps) * 8,
    express_max_steps    : game_get_speed(gamespeed_fps) * 20,
    bubble_steps         : game_get_speed(gamespeed_fps) * 3,

    // Ranks and loyalty
    leader_rank          : 2,
    seek_chance          : 0.05,
    seek_radius          : 96,
    seek_ticks           : 150,
    bond_radius          : 2,
    follow_distance      : 4,
    lonely_radius        : 10,

    allowed              : ["move", "dig", "place", "clone", "become_lantern", "work"]
};

// Purposes take different amounts of work and need different numbers of helpers present.
purpose_kinds = [
    { name : "Spark",    work : 150,  min_helpers : 1, want_helpers : 2  },
    { name : "Knot",     work : 600,  min_helpers : 2, want_helpers : 4  },
    { name : "Riddle",   work : 1800, min_helpers : 4, want_helpers : 6  },
    { name : "Monolith", work : 4800, min_helpers : 6, want_helpers : 10 }
];

// Problem-solving multiplier per mood: applies to work rate and to getting round obstacles.
mood_factors = {
    purposeless : 0.6,
    content     : 0.9,
    purposeful  : 1.15,
    loyal       : 1.0,
    proud       : 1.3
};

mood_lines = {
    purposeless : ["purposeless...", "what am I for?", "drifting", "nothing to do"],
    content     : ["all is fine", "just digging", "hmm"],
    purposeful  : ["I have a purpose!", "on my way!", "this matters"],
    loyal       : ["I belong now", "not lonely any more", "where you go, I go"],
    proud       : ["proud - I'm needed", "we keep going", "useful again"]
};

purpose_timer      = 0;
completed_purposes = 0;
static_count       = 0;

// Ranks earned by completing purposes. From leader_rank up, a cell seeks lonely cells to join its force.
rank_names      = ["Novice", "Helper", "Veteran", "Captain", "Elder"];
rank_thresholds = [0, 1, 3, 6, 10];
rank_followers  = [0, 0, 2, 3, 6];

name_starts   = ["Ka", "Lo", "Mi", "Zu", "Te", "Ra", "No", "Vi", "Sa", "Bo", "Qi", "Fen", "Ul", "Dro", "Pim", "Ash"];
name_ends     = ["ro", "na", "lix", "bo", "ki", "ma", "tor", "el", "uz", "pa", "ni", "sk", "an", "it", "um", "ey"];
names_issued  = 0;

action_counts = {
    move           : 0,
    dig            : 0,
    place          : 0,
    clone          : 0,
    become_lantern : 0,
    work           : 0
};

action_log = [];
log_max    = 200;

// ---------------------------------------------------------------- voxel access

in_bounds = function(_x, _y, _z) {
    if (_x < 0 || _y < 0 || _z < 0) {
        return false;
    }
    if (_x >= world_size || _y >= world_size || _z >= world_size) {
        return false;
    }
    return true;
};

voxel_index = function(_x, _y, _z) {
    return _z + (_x * world_size) + (_y * world_size * world_size);
};

get_voxel = function(_x, _y, _z) {
    if (!in_bounds(_x, _y, _z)) {
        return -1;
    }
    return buffer_peek(voxels, voxel_index(_x, _y, _z), buffer_u8);
};

// Grey for a 0..255 depth value. Empty space stays pure black, so matter starts at 24.
shade_for = function(_value) {
    return 24 + floor(clamp(_value, 0, 255) * 231 / 255);
};

write_view_pixel = function(_view, _px, _py, _shade) {
    var _colour = $FF000000 | (_shade * $010101);
    buffer_poke(view_buffers[_view], ((_py * world_size) + _px) * 4, buffer_u32, _colour);
    view_dirty[_view] = true;
};

refresh_top = function(_x, _y) {
    var _found = -1;
    var _base  = voxel_index(_x, _y, 0);
    for (var _z = world_size - 1; _z >= 0; _z--) {
        if (buffer_peek(voxels, _base + _z, buffer_u8) == voxel_static) {
            _found = _z;
            break;
        }
    }
    top_cache[# _x, _y] = _found;
    var _shade = 0;
    if (_found >= 0) {
        _shade = shade_for(_found);
    }
    write_view_pixel(0, _x, _y, _shade);
};

refresh_front = function(_x, _z) {
    var _found = world_size;
    for (var _y = 0; _y < world_size; _y++) {
        if (buffer_peek(voxels, voxel_index(_x, _y, _z), buffer_u8) == voxel_static) {
            _found = _y;
            break;
        }
    }
    front_cache[# _x, _z] = _found;
    var _shade = 0;
    if (_found < world_size) {
        _shade = shade_for(world_size - 1 - _found);
    }
    write_view_pixel(1, _x, world_size - 1 - _z, _shade);
};

refresh_side = function(_y, _z) {
    var _found = world_size;
    for (var _x = 0; _x < world_size; _x++) {
        if (buffer_peek(voxels, voxel_index(_x, _y, _z), buffer_u8) == voxel_static) {
            _found = _x;
            break;
        }
    }
    side_cache[# _y, _z] = _found;
    var _shade = 0;
    if (_found < world_size) {
        _shade = shade_for(world_size - 1 - _found);
    }
    write_view_pixel(2, _y, world_size - 1 - _z, _shade);
};

set_voxel = function(_x, _y, _z, _value) {
    if (!in_bounds(_x, _y, _z)) {
        return false;
    }
    var _index = voxel_index(_x, _y, _z);
    var _old   = buffer_peek(voxels, _index, buffer_u8);
    if (_old == _value) {
        return true;
    }
    buffer_poke(voxels, _index, buffer_u8, _value);

    if (_value == voxel_static) {
        static_count += 1;
    } else if (_old == voxel_static) {
        static_count -= 1;
    }

    if (_value == voxel_static) {
        if (_z > top_cache[# _x, _y]) {
            top_cache[# _x, _y] = _z;
            write_view_pixel(0, _x, _y, shade_for(_z));
        }
        if (_y < front_cache[# _x, _z]) {
            front_cache[# _x, _z] = _y;
            write_view_pixel(1, _x, world_size - 1 - _z, shade_for(world_size - 1 - _y));
        }
        if (_x < side_cache[# _y, _z]) {
            side_cache[# _y, _z] = _x;
            write_view_pixel(2, _y, world_size - 1 - _z, shade_for(world_size - 1 - _x));
        }
    } else if (_old == voxel_static) {
        if (_z == top_cache[# _x, _y]) {
            refresh_top(_x, _y);
        }
        if (_y == front_cache[# _x, _z]) {
            refresh_front(_x, _z);
        }
        if (_x == side_cache[# _y, _z]) {
            refresh_side(_y, _z);
        }
    }
    return true;
};

rebuild_view_pixels = function() {
    for (var _v = 0; _v < 3; _v++) {
        var _buf = view_buffers[_v];
        buffer_seek(_buf, buffer_seek_start, 0);
        for (var _py = 0; _py < world_size; _py++) {
            for (var _px = 0; _px < world_size; _px++) {
                var _shade = 0;
                if (_v == 0) {
                    var _t = top_cache[# _px, _py];
                    if (_t >= 0) {
                        _shade = shade_for(_t);
                    }
                } else if (_v == 1) {
                    var _f = front_cache[# _px, world_size - 1 - _py];
                    if (_f < world_size) {
                        _shade = shade_for(world_size - 1 - _f);
                    }
                } else {
                    var _s = side_cache[# _px, world_size - 1 - _py];
                    if (_s < world_size) {
                        _shade = shade_for(world_size - 1 - _s);
                    }
                }
                buffer_write(_buf, buffer_u32, $FF000000 | (_shade * $010101));
            }
        }
        view_dirty[_v] = true;
    }
};

// ---------------------------------------------------------------- world control

wipe_life = function() {
    with (obj_cell) {
        instance_destroy();
    }
    with (obj_lantern) {
        instance_destroy();
    }
};

clear_world_data = function() {
    wipe_life();
    with (obj_purpose) {
        instance_destroy();
    }
    buffer_fill(voxels, 0, buffer_u8, voxel_empty, world_volume);
    ds_grid_clear(top_cache, -1);
    ds_grid_clear(front_cache, world_size);
    ds_grid_clear(side_cache, world_size);
    static_count = 0;
};

clear_world = function() {
    clear_world_data();
    rebuild_view_pixels();
    log_action("world", "clear", "done", "empty cube");
};

generate_terrain = function() {
    clear_world_data();

    var _p1 = random(1000);
    var _p2 = random(1000);
    var _p3 = random(1000);

    for (var _x = 0; _x < world_size; _x++) {
        for (var _y = 0; _y < world_size; _y++) {
            var _h = 6 + floor(14 * (1 + sin((_x + _p1) * 0.043)) + 12 * (1 + cos((_y + _p2) * 0.051)) + 9 * (1 + sin((_x + _y + _p3) * 0.029)));
            _h = clamp(_h, 0, world_size - 1);
            buffer_fill(voxels, voxel_index(_x, _y, 0), buffer_u8, voxel_static, _h + 1);
            top_cache[# _x, _y] = _h;
            static_count += _h + 1;
        }
    }

    // Columns are solid from the floor, so front/side caches can be built from heights alone.
    for (var _x = 0; _x < world_size; _x++) {
        var _reach = -1;
        for (var _y = 0; _y < world_size; _y++) {
            var _h = top_cache[# _x, _y];
            if (_h > _reach) {
                for (var _z = _reach + 1; _z <= _h; _z++) {
                    front_cache[# _x, _z] = _y;
                }
                _reach = _h;
            }
        }
    }
    for (var _y = 0; _y < world_size; _y++) {
        var _reach = -1;
        for (var _x = 0; _x < world_size; _x++) {
            var _h = top_cache[# _x, _y];
            if (_h > _reach) {
                for (var _z = _reach + 1; _z <= _h; _z++) {
                    side_cache[# _y, _z] = _x;
                }
                _reach = _h;
            }
        }
    }

    rebuild_view_pixels();
    log_action("world", "generate", "done", "new terrain");
};

// ---------------------------------------------------------------- life

make_default_genome = function() {
    var _genome = {
        sink_bias    : 0.6,
        clone_bias   : 0.5,
        crowd_limit  : 4,
        build_height : 40 + irandom(120),
        dig_bias     : 0.3,
        place_bias   : 0.25,
        wander_bias  : 0.7,
        carry_max    : 16
    };
    return _genome;
};

spawn_cell = function(_x, _y, _z, _genome, _energy, _carried, _generation) {
    if (instance_number(obj_cell) >= limits.max_cells) {
        return noone;
    }
    if (get_voxel(_x, _y, _z) != voxel_empty) {
        return noone;
    }
    return instance_create_depth(0, 0, 0, obj_cell, {
        spawn_x          : _x,
        spawn_y          : _y,
        spawn_z          : _z,
        spawn_genome     : _genome,
        spawn_energy     : _energy,
        spawn_carried    : _carried,
        spawn_generation : _generation
    });
};

spawn_lantern = function(_x, _y, _z, _owner_name) {
    if (instance_number(obj_lantern) >= limits.max_lanterns) {
        return noone;
    }
    if (get_voxel(_x, _y, _z) != voxel_empty) {
        return noone;
    }
    return instance_create_depth(0, 0, 10, obj_lantern, {
        spawn_x     : _x,
        spawn_y     : _y,
        spawn_z     : _z,
        spawn_owner : _owner_name
    });
};

// ---------------------------------------------------------------- purposes

next_purpose_interval = function() {
    return irandom_range(limits.purpose_interval_min, limits.purpose_interval_max);
};

spawn_purpose = function(_x, _y, _z, _kind_index) {
    if (instance_number(obj_purpose) >= limits.max_purposes) {
        return noone;
    }
    if (get_voxel(_x, _y, _z) != voxel_empty) {
        return noone;
    }
    var _purpose = instance_create_depth(0, 0, 5, obj_purpose, {
        spawn_x    : _x,
        spawn_y    : _y,
        spawn_z    : _z,
        spawn_kind : _kind_index
    });
    log_action("world", "purpose", "dropped", purpose_kinds[_kind_index].name);
    return _purpose;
};

// Drop a purpose on the terrain surface somewhere in the cube.
drop_random_purpose = function() {
    repeat (20) {
        var _x = irandom(world_size - 1);
        var _y = irandom(world_size - 1);
        var _z = top_cache[# _x, _y] + 1;
        if (_z < world_size) {
            if (get_voxel(_x, _y, _z) == voxel_empty) {
                return spawn_purpose(_x, _y, _z, irandom(array_length(purpose_kinds) - 1));
            }
        }
    }
    return noone;
};

make_cell_name = function() {
    names_issued += 1;
    var _start = name_starts[irandom(array_length(name_starts) - 1)];
    var _end   = name_ends[irandom(array_length(name_ends) - 1)];
    return _start + _end + "-" + string(names_issued);
};

rank_for = function(_completions) {
    var _rank = 0;
    for (var i = 0; i < array_length(rank_thresholds); i++) {
        if (_completions >= rank_thresholds[i]) {
            _rank = i;
        }
    }
    return _rank;
};

// _who is "world" (a string) or a cell, lantern or purpose instance; all of those define entity_name.
log_action = function(_who, _action, _result, _reason) {
    var _name = "?";
    if (is_string(_who)) {
        _name = _who;
    } else if (instance_exists(_who)) {
        _name = _who.entity_name;
    }
    var _seconds = (current_time - start_time) div 1000;
    array_push(action_log, { who : _name, action : _action, result : _result, reason : _reason, time : _seconds });
    if (array_length(action_log) > log_max) {
        array_delete(action_log, 0, 1);
    }
};

// Every cell action passes through here. Nothing bypasses it.
request_action = function(_cell, _name) {
    if (global.cellular_paused) {
        log_action(_cell, _name, "refused", "paused");
        return false;
    }

    var _allowed = false;
    for (var i = 0; i < array_length(limits.allowed); i++) {
        if (limits.allowed[i] == _name) {
            _allowed = true;
        }
    }
    if (!_allowed) {
        log_action(_cell, _name, "refused", "not registered");
        return false;
    }

    if (_cell.actions_this_tick >= limits.max_actions_per_tick) {
        log_action(_cell, _name, "refused", "tick cap");
        return false;
    }

    _cell.actions_this_tick += 1;
    action_counts[$ _name] += 1;
    return true;
};

// ---------------------------------------------------------------- mouse to voxel

// The empty voxel just in front of the visible surface under the mouse.
surface_slot = function(_view, _px, _py) {
    var _slot = { ok : false, vx : 0, vy : 0, vz : 0 };
    var _z    = 0;
    if (_px < 0 || _py < 0 || _px >= world_size || _py >= world_size) {
        return _slot;
    }
    if (_view == 0) {
        _z = top_cache[# _px, _py] + 1;
        if (_z < world_size) {
            _slot.ok = true;
            _slot.vx = _px;
            _slot.vy = _py;
            _slot.vz = _z;
        }
    } else if (_view == 1) {
        _z = world_size - 1 - _py;
        var _y = front_cache[# _px, _z] - 1;
        if (_y >= 0) {
            _slot.ok = true;
            _slot.vx = _px;
            _slot.vy = _y;
            _slot.vz = _z;
        }
    } else {
        _z = world_size - 1 - _py;
        var _x = side_cache[# _px, _z] - 1;
        if (_x >= 0) {
            _slot.ok = true;
            _slot.vx = _x;
            _slot.vy = _px;
            _slot.vz = _z;
        }
    }
    return _slot;
};

// The visible static voxel under the mouse.
surface_hit = function(_view, _px, _py) {
    var _hit = { ok : false, vx : 0, vy : 0, vz : 0 };
    var _z   = 0;
    if (_px < 0 || _py < 0 || _px >= world_size || _py >= world_size) {
        return _hit;
    }
    if (_view == 0) {
        _z = top_cache[# _px, _py];
        if (_z >= 0) {
            _hit.ok = true;
            _hit.vx = _px;
            _hit.vy = _py;
            _hit.vz = _z;
        }
    } else if (_view == 1) {
        _z = world_size - 1 - _py;
        var _y = front_cache[# _px, _z];
        if (_y < world_size) {
            _hit.ok = true;
            _hit.vx = _px;
            _hit.vy = _y;
            _hit.vz = _z;
        }
    } else {
        _z = world_size - 1 - _py;
        var _x = side_cache[# _px, _z];
        if (_x < world_size) {
            _hit.ok = true;
            _hit.vx = _x;
            _hit.vy = _px;
            _hit.vz = _z;
        }
    }
    return _hit;
};

sculpt_at = function(_view, _px, _py, _add) {
    var _r2 = brush_radius * brush_radius;
    for (var _dx = -brush_radius; _dx <= brush_radius; _dx++) {
        for (var _dy = -brush_radius; _dy <= brush_radius; _dy++) {
            if ((_dx * _dx) + (_dy * _dy) <= _r2) {
                if (_add) {
                    var _slot = surface_slot(_view, _px + _dx, _py + _dy);
                    if (_slot.ok) {
                        if (get_voxel(_slot.vx, _slot.vy, _slot.vz) == voxel_empty) {
                            set_voxel(_slot.vx, _slot.vy, _slot.vz, voxel_static);
                        }
                    }
                } else {
                    var _hit = surface_hit(_view, _px + _dx, _py + _dy);
                    if (_hit.ok) {
                        set_voxel(_hit.vx, _hit.vy, _hit.vz, voxel_empty);
                    }
                }
            }
        }
    }
};

// ---------------------------------------------------------------- drawing living pixels

// Voxel to screen for the current view. px/py is the top-left pixel of the voxel on screen;
// value is the depth used for the grey.
project = function(_vx, _vy, _vz) {
    var _p = { px : 0, py : 0, value : 0 };
    var _sx = 0;
    var _sy = 0;
    if (view_mode == 0) {
        _sx      = _vx;
        _sy      = _vy;
        _p.value = _vz;
    } else if (view_mode == 1) {
        _sx      = _vx;
        _sy      = world_size - 1 - _vz;
        _p.value = world_size - 1 - _vy;
    } else {
        _sx      = _vy;
        _sy      = world_size - 1 - _vz;
        _p.value = world_size - 1 - _vx;
    }
    _p.px = world_left + (_sx * display_scale);
    _p.py = world_top + (_sy * display_scale);
    return _p;
};

draw_marker = function(_vx, _vy, _vz, _is_lantern, _halo_radius, _rank) {
    var _p     = project(_vx, _vy, _vz);
    var _s     = display_scale;
    var _left  = _p.px;
    var _top   = _p.py;
    var _shade = shade_for(_p.value);

    if (_is_lantern) {
        draw_set_colour(c_white);
        draw_set_alpha(0.12 + (0.08 * sin(current_time / 250)));
        draw_circle(_left + (_s * 0.5), _top + (_s * 0.5), _halo_radius * _s, false);
        draw_set_alpha(1);
    }

    draw_set_colour(make_colour_rgb(_shade, _shade, _shade));
    draw_rectangle(_left, _top, _left + _s - 1, _top + _s - 1, false);

    var _edge = c_white;
    if (_shade > 127) {
        _edge = c_black;
    }
    draw_set_colour(_edge);
    draw_rectangle(_left - 1, _top - 1, _left + _s, _top + _s, true);

    if (_is_lantern) {
        draw_set_colour(c_white);
        draw_rectangle(_left - 3, _top - 3, _left + _s + 2, _top + _s + 2, true);
    }

    // Rank pips above the pixel
    for (var i = 0; i < _rank; i++) {
        draw_set_colour(c_white);
        draw_rectangle(_left + (i * 3), _top - 4, _left + (i * 3) + 1, _top - 3, false);
    }

    draw_set_colour(c_white);
};

// Faint line from a loyal follower to its leader.
draw_link = function(_ax, _ay, _az, _bx, _by, _bz) {
    var _a = project(_ax, _ay, _az);
    var _b = project(_bx, _by, _bz);
    var _h = display_scale * 0.5;
    draw_set_colour(c_white);
    draw_set_alpha(0.25);
    draw_line(_a.px + _h, _a.py + _h, _b.px + _h, _b.py + _h);
    draw_set_alpha(1);
};

// A small speech bubble above a living pixel.
draw_bubble = function(_vx, _vy, _vz, _text) {
    var _p  = project(_vx, _vy, _vz);
    var _s  = display_scale;
    var _cx = _p.px + (_s * 0.5);
    var _by = _p.py - 8;
    var _w  = string_width(_text) + 8;
    var _h  = string_height(_text) + 4;

    draw_set_alpha(0.8);
    draw_set_colour(c_black);
    draw_rectangle(_cx - (_w * 0.5), _by - _h, _cx + (_w * 0.5), _by, false);
    draw_set_alpha(1);
    draw_set_colour(c_white);
    draw_rectangle(_cx - (_w * 0.5), _by - _h, _cx + (_w * 0.5), _by, true);
    draw_set_halign(fa_center);
    draw_set_valign(fa_bottom);
    draw_text(_cx, _by - 2, _text);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
};

draw_purpose = function(_vx, _vy, _vz, _label, _progress, _discovered) {
    var _p     = project(_vx, _vy, _vz);
    var _s     = display_scale;
    var _cx    = _p.px + (_s * 0.5);
    var _cy    = _p.py + (_s * 0.5);
    var _pulse = 8 + (3 * sin(current_time / 200));

    draw_set_colour(c_white);
    draw_primitive_begin(pr_linestrip);
    draw_vertex(_cx, _cy - _pulse);
    draw_vertex(_cx + _pulse, _cy);
    draw_vertex(_cx, _cy + _pulse);
    draw_vertex(_cx - _pulse, _cy);
    draw_vertex(_cx, _cy - _pulse);
    draw_primitive_end();

    var _shade = shade_for(_p.value);
    draw_set_colour(make_colour_rgb(_shade, _shade, _shade));
    draw_rectangle(_cx - 2, _cy - 2, _cx + 2, _cy + 2, false);

    // Progress bar
    draw_set_colour(c_dkgray);
    draw_rectangle(_cx - 16, _cy + 13, _cx + 16, _cy + 15, false);
    draw_set_colour(c_white);
    draw_rectangle(_cx - 16, _cy + 13, _cx - 16 + (32 * _progress), _cy + 15, false);

    var _text = "?";
    if (_discovered) {
        _text = _label + " " + string(floor(_progress * 100)) + "%";
    }
    draw_set_halign(fa_center);
    draw_set_valign(fa_top);
    draw_text(_cx, _cy + 18, _text);
    draw_set_halign(fa_left);
};

format_time = function(_seconds) {
    var _m = _seconds div 60;
    var _s = _seconds mod 60;
    var _pad = "";
    if (_s < 10) {
        _pad = "0";
    }
    return string(_m) + ":" + _pad + string(_s);
};

// Mouse position to a voxel column/row on screen, or -1 when outside the square.
mouse_cell_x = function() {
    var _mx = floor((mouse_x - world_left) / display_scale);
    if (_mx < 0 || _mx >= world_size) {
        return -1;
    }
    return _mx;
};

mouse_cell_y = function() {
    var _my = floor((mouse_y - world_top) / display_scale);
    if (_my < 0 || _my >= world_size) {
        return -1;
    }
    return _my;
};

purpose_timer = next_purpose_interval();

window_center();
generate_terrain();
