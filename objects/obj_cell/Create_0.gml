/// obj_cell - Create
/// A living pixel. Spawned only through obj_cellular_world.spawn_cell, which passes the spawn_* values.

var _world = global.cellular_world;

cx = spawn_x;
cy = spawn_y;
cz = spawn_z;

genome     = spawn_genome;
energy     = spawn_energy;
carried    = spawn_carried;
generation = spawn_generation;

tick_timer        = 0;
decision_timer    = 0;
actions_this_tick = 0;

heading_x = 0;
heading_y = 0;
heading_z = -1;

_world.set_voxel(cx, cy, cz, _world.voxel_cell);

pick_heading = function() {
    heading_x = 0;
    heading_y = 0;
    heading_z = 0;
    while (heading_x == 0 && heading_y == 0 && heading_z == 0) {
        heading_x = irandom_range(-1, 1);
        heading_y = irandom_range(-1, 1);
        heading_z = irandom_range(-1, 1);
    }
};

// Touching matter on any face, or resting on the floor of the cube.
is_attached = function() {
    if (cz == 0) {
        return true;
    }
    var _world = global.cellular_world;
    var _s = _world.voxel_static;
    if (_world.get_voxel(cx + 1, cy, cz) == _s) {
        return true;
    }
    if (_world.get_voxel(cx - 1, cy, cz) == _s) {
        return true;
    }
    if (_world.get_voxel(cx, cy + 1, cz) == _s) {
        return true;
    }
    if (_world.get_voxel(cx, cy - 1, cz) == _s) {
        return true;
    }
    if (_world.get_voxel(cx, cy, cz + 1) == _s) {
        return true;
    }
    if (_world.get_voxel(cx, cy, cz - 1) == _s) {
        return true;
    }
    return false;
};

try_move = function(_dx, _dy, _dz) {
    var _world = global.cellular_world;
    if (_world.get_voxel(cx + _dx, cy + _dy, cz + _dz) != _world.voxel_empty) {
        return false;
    }
    if (energy < _world.limits.move_cost) {
        return false;
    }
    if (!_world.request_action(id, "move")) {
        return false;
    }
    energy -= _world.limits.move_cost;
    _world.set_voxel(cx, cy, cz, _world.voxel_empty);
    cx += _dx;
    cy += _dy;
    cz += _dz;
    _world.set_voxel(cx, cy, cz, _world.voxel_cell);
    return true;
};

// Take one static pixel and carry it.
try_dig = function(_dx, _dy, _dz) {
    var _world = global.cellular_world;
    if (_world.get_voxel(cx + _dx, cy + _dy, cz + _dz) != _world.voxel_static) {
        return false;
    }
    if (carried >= genome.carry_max) {
        return false;
    }
    if (energy < _world.limits.dig_cost) {
        return false;
    }
    if (!_world.request_action(id, "dig")) {
        return false;
    }
    energy -= _world.limits.dig_cost;
    _world.set_voxel(cx + _dx, cy + _dy, cz + _dz, _world.voxel_empty);
    carried += 1;
    return true;
};

// Put a carried pixel down. A cell can only place what it has dug.
try_place = function(_dx, _dy, _dz) {
    var _world = global.cellular_world;
    if (_world.get_voxel(cx + _dx, cy + _dy, cz + _dz) != _world.voxel_empty) {
        return false;
    }
    if (cz + _dz > genome.build_height) {
        return false;
    }
    if (carried <= 0) {
        return false;
    }
    if (energy < _world.limits.place_cost) {
        return false;
    }
    if (!_world.request_action(id, "place")) {
        return false;
    }
    energy -= _world.limits.place_cost;
    _world.set_voxel(cx + _dx, cy + _dy, cz + _dz, _world.voxel_static);
    carried -= 1;
    return true;
};

take_turn = function() {
    if (random(1) > genome.wander_bias) {
        pick_heading();
    }

    // Drift down toward matter when floating free.
    if (!is_attached()) {
        if (random(1) < genome.sink_bias) {
            heading_z = -1;
        }
    }

    var _roll = random(1);
    var _done = false;

    if (carried >= genome.carry_max) {
        _done = try_place(heading_x, heading_y, heading_z);
    } else if (_roll < genome.dig_bias) {
        _done = try_dig(heading_x, heading_y, heading_z);
    } else if (_roll < genome.dig_bias + genome.place_bias) {
        if (carried > 0) {
            _done = try_place(heading_x, heading_y, heading_z);
        }
    }

    if (!_done) {
        if (!try_move(heading_x, heading_y, heading_z)) {
            pick_heading();
        }
    }
};

mutate_genome = function(_g) {
    var _child = {
        sink_bias    : clamp(_g.sink_bias + random_range(-0.1, 0.1), 0.1, 0.95),
        clone_bias   : clamp(_g.clone_bias + random_range(-0.1, 0.1), 0.05, 0.95),
        crowd_limit  : clamp(_g.crowd_limit + irandom_range(-1, 1), 1, 8),
        build_height : clamp(_g.build_height + irandom_range(-16, 16), 8, 255),
        dig_bias     : clamp(_g.dig_bias + random_range(-0.05, 0.05), 0.05, 0.6),
        place_bias   : clamp(_g.place_bias + random_range(-0.05, 0.05), 0.05, 0.6),
        wander_bias  : clamp(_g.wander_bias + random_range(-0.1, 0.1), 0.1, 0.95),
        carry_max    : clamp(_g.carry_max + irandom_range(-2, 2), 4, 32)
    };
    return _child;
};

try_clone = function() {
    var _world = global.cellular_world;

    repeat (12) {
        var _dx = irandom_range(-1, 1);
        var _dy = irandom_range(-1, 1);
        var _dz = irandom_range(-1, 1);
        if (_dx != 0 || _dy != 0 || _dz != 0) {
            if (_world.get_voxel(cx + _dx, cy + _dy, cz + _dz) == _world.voxel_empty) {
                if (!_world.request_action(id, "clone")) {
                    return false;
                }
                var _child_carried = floor(carried / 2);
                var _child = _world.spawn_cell(cx + _dx, cy + _dy, cz + _dz, mutate_genome(genome), _world.limits.clone_cost * 0.8, _child_carried, generation + 1);
                if (instance_exists(_child)) {
                    carried -= _child_carried;
                    energy  -= _world.limits.clone_cost;
                    _world.log_action(id, "clone", "done", "generation " + string(generation + 1));
                    return true;
                }
                _world.log_action(id, "clone", "failed", "cap reached");
                return false;
            }
        }
    }

    _world.log_action(id, "clone", "failed", "no space");
    return false;
};

// Chose not to clone: a Lantern appears beside the cell instead.
try_become_lantern = function() {
    var _world = global.cellular_world;

    if (instance_number(obj_lantern) >= _world.limits.max_lanterns) {
        _world.log_action(id, "become_lantern", "refused", "lantern cap - rested");
        return false;
    }

    repeat (12) {
        var _dx = irandom_range(-1, 1);
        var _dy = irandom_range(-1, 1);
        var _dz = irandom_range(-1, 1);
        if (_dx != 0 || _dy != 0 || _dz != 0) {
            if (_world.get_voxel(cx + _dx, cy + _dy, cz + _dz) == _world.voxel_empty) {
                if (!_world.request_action(id, "become_lantern")) {
                    return false;
                }
                _world.spawn_lantern(cx + _dx, cy + _dy, cz + _dz);
                _world.log_action(id, "become_lantern", "done", "chose not to clone");
                return true;
            }
        }
    }

    _world.log_action(id, "become_lantern", "failed", "no space");
    return false;
};

// Every 10 seconds: clone, or let a Lantern appear instead.
make_life_choice = function() {
    var _world  = global.cellular_world;
    var _limits = _world.limits;
    var _me     = id;
    var _mx     = cx;
    var _my     = cy;
    var _mz     = cz;
    var _radius = _limits.crowd_radius;
    var _crowd  = 0;

    with (obj_cell) {
        if (id != _me) {
            if (point_distance_3d(cx, cy, cz, _mx, _my, _mz) <= _radius) {
                _crowd += 1;
            }
        }
    }

    var _wants_clone = false;
    if (energy >= _limits.clone_cost) {
        if (instance_number(obj_cell) < _limits.max_cells) {
            if (_crowd < genome.crowd_limit) {
                if (random(1) < genome.clone_bias) {
                    _wants_clone = true;
                }
            }
        }
    }

    if (_wants_clone) {
        try_clone();
    } else {
        try_become_lantern();
    }
};
