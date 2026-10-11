/// obj_cellular_world - Create
/// CELLULAR: a 256 x 256 x 256 voxel room. Static pixels are matter; cells are living pixels.

global.cellular_paused = false;
global.cellular_world  = id;

depth         = 50;
world_size    = 256;
world_volume  = world_size * world_size * world_size;
display_scale = 3;
ui_top        = world_size * display_scale;
brush_radius  = 3;
brush_min     = 1;
brush_max     = 12;

// Voxel values
voxel_empty   = 0;
voxel_static  = 1;
voxel_cell    = 2;
voxel_lantern = 3;

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
    allowed              : ["move", "dig", "place", "clone", "become_lantern"]
};

action_counts = {
    move           : 0,
    dig            : 0,
    place          : 0,
    clone          : 0,
    become_lantern : 0
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
    buffer_fill(voxels, 0, buffer_u8, voxel_empty, world_volume);
    ds_grid_clear(top_cache, -1);
    ds_grid_clear(front_cache, world_size);
    ds_grid_clear(side_cache, world_size);
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

spawn_lantern = function(_x, _y, _z) {
    if (instance_number(obj_lantern) >= limits.max_lanterns) {
        return noone;
    }
    if (get_voxel(_x, _y, _z) != voxel_empty) {
        return noone;
    }
    return instance_create_depth(0, 0, 10, obj_lantern, {
        spawn_x : _x,
        spawn_y : _y,
        spawn_z : _z
    });
};

log_action = function(_who, _action, _result, _reason) {
    array_push(action_log, { who : string(_who), action : _action, result : _result, reason : _reason });
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

draw_marker = function(_vx, _vy, _vz, _is_lantern, _halo_radius) {
    var _sx    = 0;
    var _sy    = 0;
    var _value = 0;
    if (view_mode == 0) {
        _sx    = _vx;
        _sy    = _vy;
        _value = _vz;
    } else if (view_mode == 1) {
        _sx    = _vx;
        _sy    = world_size - 1 - _vz;
        _value = world_size - 1 - _vy;
    } else {
        _sx    = _vy;
        _sy    = world_size - 1 - _vz;
        _value = world_size - 1 - _vx;
    }

    var _s     = display_scale;
    var _left  = _sx * _s;
    var _top   = _sy * _s;
    var _shade = shade_for(_value);

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

    draw_set_colour(c_white);
};

generate_terrain();
