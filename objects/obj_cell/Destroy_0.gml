/// obj_cell - Destroy

var _world = global.cellular_world;
if (instance_exists(_world)) {
    if (_world.get_voxel(cx, cy, cz) == _world.voxel_cell) {
        _world.set_voxel(cx, cy, cz, _world.voxel_empty);
    }
}

// Followers lose their leader; any pending seek is released.
var _me   = id;
var _name = entity_name;
with (obj_cell) {
    if (leader == _me) {
        leader = noone;
        say("where did " + _name + " go?");
    }
}
release_seek();
