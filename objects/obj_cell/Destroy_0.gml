/// obj_cell - Destroy

var _world = global.cellular_world;
if (instance_exists(_world)) {
    if (_world.get_voxel(cx, cy, cz) == _world.voxel_cell) {
        _world.set_voxel(cx, cy, cz, _world.voxel_empty);
    }
}
