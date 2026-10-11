/// obj_purpose - Destroy

var _world = global.cellular_world;
if (instance_exists(_world)) {
    if (_world.get_voxel(px, py, pz) == _world.voxel_purpose) {
        _world.set_voxel(px, py, pz, _world.voxel_empty);
    }
}

var _me = id;
with (obj_cell) {
    if (purpose_target == _me) {
        purpose_target = noone;
        role           = "idle";
    }
}
