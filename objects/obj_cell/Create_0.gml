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

// Identity, rank and loyalty
entity_name    = _world.make_cell_name();
completions    = 0;
rank           = 0;
leader         = noone;
seek_target    = noone;
seek_timer     = 0;
sought_by      = noone;
follower_tally = 0;

// Rank-up gains: each rank adds speed (actions per tick) and senses (perception, hearing, seeking reach).
move_speed     = _world.limits.base_speed;
senses         = _world.limits.perception_radius;

// Outreach: proud cells roam to find purposeless ones; those they connect with get a short boost.
roam_tx        = 0;
roam_ty        = 0;
roam_tz        = 0;
roam_target    = noone;
boost_timer    = 0;

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
    cx = _world.wrap(cx + _dx);
    cy = _world.wrap(cy + _dy);
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
                    return true;
                }
                return false;
            }
        }
    }

    return false;
};

// Chose not to clone: a Lantern appears beside the cell instead.
try_become_lantern = function() {
    var _world = global.cellular_world;

    if (instance_number(obj_lantern) >= _world.limits.max_lanterns) {
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
                _world.spawn_lantern(cx + _dx, cy + _dy, cz + _dz, entity_name);
                _world.log_action(id, "become_lantern", "done", "chose not to clone");
                return true;
            }
        }
    }

    return false;
};

// Every 10 seconds: clone, or let a Lantern appear instead.
make_life_choice = function() {
    var _world  = global.cellular_world;
    var _limits = _world.limits;
    // Other cells sharing this cell's 16^3 block.
    var _crowd  = _world.bucket_count(cx, cy, cz) - 1;

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
    if (purpose_target != noone) {
        _used = 1;
    }
    usage = (usage * (1 - _limits.usage_rate)) + (_used * _limits.usage_rate);

    if (usage >= _limits.proud_threshold) {
        mood = "proud";
    } else if (purpose_target != noone) {
        mood = "purposeful";
    } else if (instance_exists(leader)) {
        mood = "loyal";
    } else if (usage < _limits.purposeless_threshold) {
        mood = "purposeless";
    } else {
        mood = "content";
    }
    mood_factor = _world.mood_factors[$ mood];
};

express = function() {
    var _world = global.cellular_world;
    if (_world.speech_cooldown > 0) {
        return false;
    }
    _world.speech_cooldown = _world.limits.speech_gap_steps;
    var _lines = _world.mood_lines[$ mood];
    var _line  = _lines[irandom(array_length(_lines) - 1)];
    if (mood == "loyal") {
        if (instance_exists(leader)) {
            if (random(1) < 0.5) {
                _line = "following " + leader.entity_name;
            }
        }
    }
    say(_line);
    _world.log_action(id, "feels", mood, _line);
};

// ---------------------------------------------------------------- purposes

// Head for a target. When blocked, mood decides how often the cell solves it
// (climb over, tunnel through, or drop cargo) instead of fumbling sideways.
step_toward = function(_tx, _ty, _tz) {
    var _world = global.cellular_world;
    var _dx    = sign(_world.wrap_delta(cx, _tx));
    var _dy    = sign(_world.wrap_delta(cy, _ty));
    var _dz    = sign(_tz - cz);
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
    var _best_dist = senses + 1;
    var _x         = cx;
    var _y         = cy;
    var _z         = cz;

    with (obj_purpose) {
        var _d = global.cellular_world.wrap_dist(px, py, pz, _x, _y, _z);
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

    release_seek();
    purpose_target = _best;
    wait_timer     = 0;
    if (!_best.discovered) {
        _best.scout = id;
        role = "scout";
        say("what's that?");
    } else {
        role = "worker";
        _best.assigned_cache += 1;
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
            if (role == "idle" && !instance_exists(leader)) {
                if (global.cellular_world.wrap_dist(cx, cy, cz, _x, _y, _z) <= _radius) {
                    purpose_target = _p;
                    role           = "worker";
                    wait_timer     = 0;
                    say("coming!");
                    _recruited += 1;
                    _p.assigned_cache += 1;
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
// X and Y use a circular mean so a swarm straddling the wrap seam averages correctly.
swarm_centre = function() {
    var _world  = global.cellular_world;
    var _centre = { ok : false, vx : 0, vy : 0, vz : 0 };
    var _k      = (2 * pi) / _world.world_size;
    var _xc     = 0;
    var _xs     = 0;
    var _yc     = 0;
    var _ys     = 0;
    var _sz     = 0;
    var _n      = 0;
    with (obj_cell) {
        if (role == "idle") {
            _xc += cos(cx * _k);
            _xs += sin(cx * _k);
            _yc += cos(cy * _k);
            _ys += sin(cy * _k);
            _sz += cz;
            _n  += 1;
        }
    }
    if (_n > 0) {
        _centre.ok = true;
        _centre.vx = _world.wrap(round(arctan2(_xs, _xc) / _k));
        _centre.vy = _world.wrap(round(arctan2(_ys, _yc) / _k));
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
    var _dist = _world.wrap_dist(cx, cy, cz, _p.px, _p.py, _p.pz);

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
        recruit_nearby(_limits.hearing_radius + sense_bonus());
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

// ---------------------------------------------------------------- ranks and loyalty

count_followers = function() {
    var _me    = id;
    var _count = 0;
    with (obj_cell) {
        if (leader == _me) {
            _count += 1;
        }
    }
    return _count;
};

// Alone means no other cell shares this cell's 16^3 block.
is_alone = function() {
    return (global.cellular_world.bucket_count(cx, cy, cz) <= 1);
};

sense_bonus = function() {
    return senses - global.cellular_world.limits.perception_radius;
};

release_seek = function() {
    if (instance_exists(seek_target)) {
        if (seek_target.sought_by == id) {
            seek_target.sought_by = noone;
        }
    }
    seek_target = noone;
    if (role == "seeking") {
        role = "idle";
    }
};

// Nearest lonely cell: no leader, no purpose, lower rank, not leading anyone,
// not already being sought, and either purposeless or alone.
find_lonely = function() {
    var _limits    = global.cellular_world.limits;
    var _me        = id;
    var _my_rank   = rank;
    var _x         = cx;
    var _y         = cy;
    var _z         = cz;
    var _best      = noone;
    var _best_dist = _limits.seek_radius + sense_bonus() + 1;

    with (obj_cell) {
        if (id != _me && rank < _my_rank && purpose_target == noone) {
            if (!instance_exists(leader) && !instance_exists(sought_by)) {
                var _d = global.cellular_world.wrap_dist(cx, cy, cz, _x, _y, _z);
                if (_d < _best_dist) {
                    if (count_followers() == 0) {
                        if (mood == "purposeless" || is_alone()) {
                            _best      = id;
                            _best_dist = _d;
                        }
                    }
                }
            }
        }
    }
    return _best;
};

// Ranked cells with room in their force go looking for someone lonely.
consider_seeking = function() {
    var _world  = global.cellular_world;
    var _limits = _world.limits;
    if (rank < _limits.leader_rank) {
        return;
    }
    if (random(1) >= _limits.seek_chance) {
        return;
    }
    if (count_followers() >= _world.rank_followers[rank]) {
        return;
    }
    var _target = find_lonely();
    if (!instance_exists(_target)) {
        return;
    }
    seek_target       = _target;
    _target.sought_by = id;
    role              = "seeking";
    seek_timer        = _limits.seek_ticks;
    say("someone looks lonely...");
    _world.log_action(id, "seek", "started", "going to " + _target.entity_name);
};

seek_turn = function() {
    var _world  = global.cellular_world;
    var _limits = _world.limits;
    var _t      = seek_target;

    if (!instance_exists(_t)) {
        release_seek();
        return;
    }
    if (instance_exists(_t.leader) || _t.purpose_target != noone) {
        release_seek();
        return;
    }

    seek_timer -= 1;
    if (seek_timer <= 0) {
        say("couldn't reach " + _t.entity_name);
        release_seek();
        return;
    }

    if (_world.wrap_dist(cx, cy, cz, _t.cx, _t.cy, _t.cz) <= _limits.bond_radius) {
        var _leader_name = entity_name;
        _t.leader    = id;
        _t.sought_by = noone;
        _t.role      = "idle";
        with (_t) {
            say("I'll follow you, " + _leader_name + "!");
        }
        say("welcome, " + _t.entity_name);
        _world.log_action(id, "loyalty", "joined force", _t.entity_name + " now follows");
        seek_target = noone;
        role        = "idle";
        return;
    }

    step_toward(_t.cx, _t.cy, _t.cz);
};

// Loyal followers stay near their leader and take up whatever purpose the leader takes up.
follow_turn = function() {
    var _limits = global.cellular_world.limits;
    var _l      = leader;

    if (_l.purpose_target != noone) {
        if (instance_exists(_l.purpose_target)) {
            purpose_target = _l.purpose_target;
            role           = "worker";
            wait_timer     = 0;
            say("with you, " + _l.entity_name + "!");
            purpose_turn();
            return;
        }
    }

    role = "idle";
    if (global.cellular_world.wrap_dist(cx, cy, cz, _l.cx, _l.cy, _l.cz) > _limits.follow_distance) {
        step_toward(_l.cx, _l.cy, _l.cz);
    } else {
        take_turn();
    }
};

// ---------------------------------------------------------------- outreach

// Proud cells roam while the swarm's purposelessness is high. Loyal followers stay with their leader.
should_roam = function() {
    if (mood != "proud") {
        return false;
    }
    if (instance_exists(leader)) {
        return false;
    }
    return global.cellular_world.outreach_active;
};

// Pick a distance and a direction and head that way.
pick_roam_leg = function() {
    var _world  = global.cellular_world;
    var _limits = _world.limits;
    var _dist   = irandom_range(_limits.roam_min, _limits.roam_max);
    var _dir    = random(360);
    roam_tx = _world.wrap(cx + round(lengthdir_x(_dist, _dir)));
    roam_ty = _world.wrap(cy + round(lengthdir_y(_dist, _dir)));
    roam_tz = cz;
};

start_roaming = function() {
    purpose_target = noone;
    release_seek();
    role        = "roaming";
    roam_target = noone;
    pick_roam_leg();
    say("going to find the lost ones");
};

stop_roaming = function() {
    role        = "idle";
    roam_target = noone;
};

// Nearest purposeless cell without a purpose, within senses.
find_purposeless = function() {
    var _me        = id;
    var _x         = cx;
    var _y         = cy;
    var _z         = cz;
    var _best      = noone;
    var _best_dist = senses + 1;
    with (obj_cell) {
        if (id != _me && mood == "purposeless" && purpose_target == noone) {
            var _d = global.cellular_world.wrap_dist(cx, cy, cz, _x, _y, _z);
            if (_d < _best_dist) {
                _best      = id;
                _best_dist = _d;
            }
        }
    }
    return _best;
};

// Temporary lift for a cell that has been reached: +1 speed, +10 senses for 10 seconds.
apply_boost = function() {
    var _limits = global.cellular_world.limits;
    if (boost_timer <= 0) {
        move_speed += _limits.connect_speed_boost;
        senses     += _limits.connect_sense_boost;
    }
    boost_timer = _limits.connect_boost_steps;
};

end_boost = function() {
    var _limits = global.cellular_world.limits;
    move_speed -= _limits.connect_speed_boost;
    senses     -= _limits.connect_sense_boost;
    boost_timer = 0;
};

// The roamer's pride goes up; the other's purposelessness is halved and it gets the boost.
connect_with = function(_t) {
    var _world  = global.cellular_world;
    var _limits = _world.limits;
    var _name   = entity_name;

    usage = min(1, usage + _limits.connect_pride);

    with (_t) {
        usage = 1 - ((1 - usage) * 0.5);
        apply_boost();
        say("thank you, " + _name + "!");
    }

    say("you're not alone, " + _t.entity_name);
    _world.log_action(id, "outreach", "connected", _t.entity_name + " lifted");
    roam_target = noone;
};

roam_turn = function() {
    var _world  = global.cellular_world;
    var _limits = _world.limits;

    if (role != "roaming") {
        start_roaming();
    }

    if (instance_exists(roam_target)) {
        if (roam_target.mood != "purposeless" || roam_target.purpose_target != noone) {
            roam_target = noone;
        }
    }

    if (!instance_exists(roam_target)) {
        roam_target = find_purposeless();
    }

    if (instance_exists(roam_target)) {
        var _t = roam_target;
        if (_world.wrap_dist(cx, cy, cz, _t.cx, _t.cy, _t.cz) <= _limits.bond_radius) {
            connect_with(_t);
        } else {
            step_toward(_t.cx, _t.cy, _t.cz);
        }
        return;
    }

    if (_world.wrap_dist(cx, cy, cz, roam_tx, roam_ty, roam_tz) <= 3) {
        pick_roam_leg();
    }
    step_toward(roam_tx, roam_ty, roam_tz);
};
