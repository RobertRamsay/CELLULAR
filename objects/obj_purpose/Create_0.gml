/// obj_purpose - Create
/// A purpose dropped into the cube. A cell must find it, tell the swarm,
/// and enough helpers must be present to work on it. Everyone who worked
/// on it is rewarded equally when it is complete.

var _world = global.cellular_world;

px = spawn_x;
py = spawn_y;
pz = spawn_z;

kind         = _world.purpose_kinds[spawn_kind];
label        = kind.name;
entity_name  = kind.name;
work_needed  = kind.work;
min_helpers  = kind.min_helpers;
want_helpers = kind.want_helpers;
work_done    = 0;
discovered   = false;
scout        = noone;
contributors = [];
completed    = false;

_world.set_voxel(px, py, pz, _world.voxel_purpose);

// Cells currently signed up to this purpose, wherever they are.
assigned_count = function() {
    var _me    = id;
    var _count = 0;
    with (obj_cell) {
        if (purpose_target == _me) {
            if (role != "idle") {
                _count += 1;
            }
        }
    }
    return _count;
};

// Signed-up cells close enough to work.
helpers_present = function() {
    var _me     = id;
    var _x      = px;
    var _y      = py;
    var _z      = pz;
    var _radius = global.cellular_world.limits.work_radius + 1;
    var _count  = 0;
    with (obj_cell) {
        if (purpose_target == _me) {
            if (point_distance_3d(cx, cy, cz, _x, _y, _z) <= _radius) {
                _count += 1;
            }
        }
    }
    return _count;
};

apply_work = function(_cell, _amount) {
    work_done += _amount;
    var _known = false;
    for (var i = 0; i < array_length(contributors); i++) {
        if (contributors[i] == _cell) {
            _known = true;
        }
    }
    if (!_known) {
        array_push(contributors, _cell);
    }
};

// Equal reward for every contributor; anyone still en route is released.
complete = function() {
    var _world  = global.cellular_world;
    var _me     = id;
    var _energy = _world.limits.reward_energy;
    var _pride  = _world.limits.reward_pride;
    var _shared = 0;

    for (var i = 0; i < array_length(contributors); i++) {
        var _cell = contributors[i];
        if (instance_exists(_cell)) {
            with (_cell) {
                energy      = min(1, energy + _energy);
                usage       = min(1, usage + _pride);
                completions += 1;
                var _new_rank = _world.rank_for(completions);
                if (_new_rank > rank) {
                    rank = _new_rank;
                    say("ranked up: " + _world.rank_names[rank] + "!");
                    _world.log_action(id, "rank", "up", _world.rank_names[rank]);
                } else {
                    say("we did it!");
                }
            }
            _shared += 1;
        }
    }

    with (obj_cell) {
        if (purpose_target == _me) {
            purpose_target = noone;
            role           = "idle";
        }
    }

    _world.completed_purposes += 1;
    _world.log_action(id, "purpose", "completed", label + " - shared by " + string(_shared));
    completed = true;
    instance_destroy();
};
