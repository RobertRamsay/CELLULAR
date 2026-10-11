/// obj_lantern - Destroy

var _world = global.cellular_world;
if (instance_exists(_world)) {
    if (_world.get_voxel(lx, ly, lz) == _world.voxel_lantern) {
        _world.set_voxel(lx, ly, lz, _world.voxel_empty);
    }
}
