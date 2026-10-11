/// obj_lantern - Create
/// The special pixel. Appears when a cell chooses not to clone.
/// It cannot move or clone. While it lives it settles floating pixels nearby
/// and feeds energy to nearby cells. When its life ends it becomes a static pixel.

var _world = global.cellular_world;

lx = spawn_x;
ly = spawn_y;
lz = spawn_z;

life          = _world.limits.lantern_life;
pulse_timer   = 0;
pulse_steps   = 30;
settle_radius = 6;
share_radius  = 10;
share_amount  = 0.05;

_world.set_voxel(lx, ly, lz, _world.voxel_lantern);

// Floating static pixels inside the radius drop one level per pulse.
// Scanning from low Z upward lets a whole stack fall together.
settle_pass = function() {
    var _world = global.cellular_world;
    var _r     = settle_radius;
    var _r2    = _r * _r;
    for (var _dz = -_r; _dz <= _r; _dz++) {
        for (var _dx = -_r; _dx <= _r; _dx++) {
            for (var _dy = -_r; _dy <= _r; _dy++) {
                if ((_dx * _dx) + (_dy * _dy) + (_dz * _dz) <= _r2) {
                    var _vx = lx + _dx;
                    var _vy = ly + _dy;
                    var _vz = lz + _dz;
                    if (_vz > 0) {
                        if (_world.get_voxel(_vx, _vy, _vz) == _world.voxel_static) {
                            if (_world.get_voxel(_vx, _vy, _vz - 1) == _world.voxel_empty) {
                                _world.set_voxel(_vx, _vy, _vz, _world.voxel_empty);
                                _world.set_voxel(_vx, _vy, _vz - 1, _world.voxel_static);
                            }
                        }
                    }
                }
            }
        }
    }
};

share_energy = function() {
    var _lx     = lx;
    var _ly     = ly;
    var _lz     = lz;
    var _radius = share_radius;
    var _amount = share_amount;
    with (obj_cell) {
        if (point_distance_3d(cx, cy, cz, _lx, _ly, _lz) <= _radius) {
            energy = min(1, energy + _amount);
        }
    }
};
