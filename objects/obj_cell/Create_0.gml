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

// Purpose and mood
purpose_target = noone;
role           = "idle";
rally_timer    = 0;
wait_timer     = 0;
usage          = 0.3;
mood           = "content";
mood_factor    = 0.9;
express_timer  = irandom_range(_world.limits.express_min_steps, _world.limits.express_max_steps);
bubble_text    = "";
bubble_timer   = 0;

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

// ---------------------------------------------------------------- feelings

say = function(_text) {
    bubble_text  = _text;
    bubble_timer = global.cellular_world.limits.bubble_steps;
};

// usage is a rolling measure of how much of its recent life this cell has had a purpose.
update_mood = function() {
    var _world  = global.cellular_world;
    var _limits = _world.limits;
    var _used   = 0;
    if (role != "idle") {
        _used = 1;
    }
    usage = (usage * (1 - _limits.usage_rate)) + (_used * _limits.usage_rate);

    if (usage >= _limits.proud_threshold) {
        mood = "proud";
    } else if (role != "idle") {
        mood = "purposeful";
    } else if (usage < _limits.purposeless_threshold) {
        mood = "purposeless";
    } else {
        mood = "content";
    }
    mood_factor = _world.mood_factors[$ mood];
};

express = function() {
    var _world = global.cellular_world;
    var _lines = _world.mood_lines[$ mood];
    var _line  = _lines[irandom(array_length(_lines) - 1)];
    say(_line);
    _world.log_action(id, "feels", mood, _line);
};

// ---------------------------------------------------------------- purposes

// Head for a target. When blocked, mood decides how often the cell solves it
// (climb over, tunnel through, or drop cargo) instead of fumbling sideways.
step_toward = function(_tx, _ty, _tz) {
    var _dx = sign(_tx - cx);
    var _dy = sign(_ty - cy);
    var _dz = sign(_tz - cz);
    if (_dx == 0 && _dy == 0 && _dz == 0) {
        return true;
    }
    if (try_move(_dx, _dy, _dz)) {
        return true;
    }
    if (random(1) < 0.5 * mood_factor) {
        if (try_move(_dx, _dy, 1)) {
            return true;
        }
        if (try_move(0, 0, 1)) {
            return true;
        }
        if (carried < genome.carry_max) {
            if (try_dig(_dx, _dy, _dz)) {
                return true;
            }
        } else {
            if (try_place(-_dx, -_dy, 0)) {
                return true;
            }
        }
    }
    pick_heading();
    return try_move(heading_x, heading_y, heading_z);
};

// Idle cells notice nearby purposes: undiscovered ones to scout, or discovered ones still short of help.
look_for_purpose = function() {
    var _limits    = global.cellular_world.limits;
    var _best      = noone;
    var _best_dist = _limits.perception_radius + 1;
    var _x         = cx;
    var _y         = cy;
    var _z         = cz;

    with (obj_purpose) {
        var _d = point_distance_3d(px, py, pz, _x, _y, _z);
        if (_d < _best_dist) {
            var _wanted = false;
            if (!discovered) {
                if (!instance_exists(scout)) {
                    _wanted = true;
                }
            } else {
                if (assigned_count() < want_helpers) {
                    _wanted = true;
                }
            }
            if (_wanted) {
                _best      = id;
                _best_dist = _d;
            }
        }
    }

    if (!instance_exists(_best)) {
        return false;
    }

    purpose_target = _best;
    wait_timer     = 0;
    if (!_best.discovered) {
        _best.scout = id;
        role = "scout";
        say("what's that?");
    } else {
        role = "worker";
        say("I'll help!");
    }
    return true;
};

// Tell idle cells within a radius about this cell's purpose, up to the number still wanted.
recruit_nearby = function(_radius) {
    var _p      = purpose_target;
    var _needed = _p.want_helpers - _p.assigned_count();
    if (_needed <= 0) {
        return 0;
    }

    var _x         = cx;
    var _y         = cy;
    var _z         = cz;
    var _recruited = 0;

    with (obj_cell) {
        if (_recruited < _needed) {
            if (role == "idle") {
                if (point_distance_3d(cx, cy, cz, _x, _y, _z) <= _radius) {
                    purpose_target = _p;
                    role           = "worker";
                    wait_timer     = 0;
                    say("coming!");
                    _recruited += 1;
                }
            }
        }
    }

    if (_recruited > 0) {
        global.cellular_world.log_action(id, "inform", "recruited " + string(_recruited), _p.label);
    }
    return _recruited;
};

// Average position of the idle swarm.
swarm_centre = function() {
    var _centre = { ok : false, vx : 0, vy : 0, vz : 0 };
    var _sx     = 0;
    var _sy     = 0;
    var _sz     = 0;
    var _n      = 0;
    with (obj_cell) {
        if (role == "idle") {
            _sx += cx;
            _sy += cy;
            _sz += cz;
            _n  += 1;
        }
    }
    if (_n > 0) {
        _centre.ok = true;
        _centre.vx = round(_sx / _n);
        _centre.vy = round(_sy / _n);
        _centre.vz = round(_sz / _n);
    }
    return _centre;
};

// scout:  go and check the purpose out
// herald: head back to the swarm, telling everyone in earshot
// worker: travel to the purpose (relaying as it goes) and work once enough helpers are there
purpose_turn = function() {
    var _world  = global.cellular_world;
    var _limits = _world.limits;

    if (!instance_exists(purpose_target)) {
        purpose_target = noone;
        role           = "idle";
        return;
    }

    var _p    = purpose_target;
    var _dist = point_distance_3d(cx, cy, cz, _p.px, _p.py, _p.pz);

    if (role == "scout") {
        if (_dist <= _limits.work_radius + 1) {
            _p.discovered = true;
            role          = "herald";
            rally_timer   = _limits.rally_ticks;
            say("a " + _p.label + "! follow me!");
            _world.log_action(id, "purpose", "discovered", _p.label);
        } else {
            step_toward(_p.px, _p.py, _p.pz);
        }
        return;
    }

    if (role == "herald") {
        rally_timer -= 1;
        recruit_nearby(_limits.hearing_radius);
        var _centre = swarm_centre();
        if (!_centre.ok || rally_timer <= 0 || _p.assigned_count() >= _p.want_helpers) {
            role       = "worker";
            wait_timer = 0;
        } else {
            step_toward(_centre.vx, _centre.vy, _centre.vz);
        }
        return;
    }

    if (_dist > _limits.work_radius) {
        recruit_nearby(_limits.relay_radius);
        step_toward(_p.px, _p.py, _p.pz);
        return;
    }

    if (_p.helpers_present() >= _p.min_helpers) {
        wait_timer = 0;
        if (_world.request_action(id, "work")) {
            _p.apply_work(id, _limits.work_rate * mood_factor);
        }
    } else {
        wait_timer += 1;
        if (wait_timer >= _limits.wait_ticks) {
            wait_timer = 0;
            if (_p.assigned_count() < _p.min_helpers) {
                role        = "herald";
                rally_timer = _limits.rally_ticks;
                say("need more help!");
            }
        }
    }
};
