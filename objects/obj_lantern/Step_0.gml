/// obj_lantern - Step

if (global.cellular_paused) {
    exit;
}

var _world = global.cellular_world;

life        -= 1;
pulse_timer += 1;

if (pulse_timer >= pulse_steps) {
    pulse_timer = 0;
    settle_pass();
    share_energy();
}

if (life <= 0) {
    _world.set_voxel(lx, ly, lz, _world.voxel_static);
    _world.log_action(id, "lantern", "settled", "became a static pixel");
    instance_destroy();
}
