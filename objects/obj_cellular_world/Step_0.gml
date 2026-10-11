/// obj_cellular_world - Step

if (keyboard_check_pressed(ord("P"))) {
    global.cellular_paused = !global.cellular_paused;
}

if (keyboard_check_pressed(ord("K"))) {
    wipe_life();
    log_action("world", "wipe", "done", "user");
}

if (keyboard_check_pressed(ord("V"))) {
    view_mode += 1;
    if (view_mode > 2) {
        view_mode = 0;
    }
}

if (keyboard_check_pressed(ord("G"))) {
    generate_terrain();
}

if (keyboard_check_pressed(ord("C"))) {
    clear_world();
}

// Purposes drop in every so often.
if (!global.cellular_paused) {
    purpose_timer -= 1;
    if (purpose_timer <= 0) {
        drop_random_purpose();
        purpose_timer = next_purpose_interval();
    }
}

if (mouse_wheel_up()) {
    brush_radius = min(brush_max, brush_radius + 1);
}
if (mouse_wheel_down()) {
    brush_radius = max(brush_min, brush_radius - 1);
}

if (keyboard_check_pressed(vk_f11)) {
    window_set_fullscreen(!window_get_fullscreen());
}

var _px = mouse_cell_x();
var _py = mouse_cell_y();

if (_px >= 0 && _py >= 0) {
    if (keyboard_check_pressed(vk_space)) {
        var _slot = surface_slot(view_mode, _px, _py);
        if (_slot.ok) {
            var _cell = spawn_cell(_slot.vx, _slot.vy, _slot.vz, make_default_genome(), 1.0, 0, 0);
            if (!instance_exists(_cell)) {
                log_action("world", "seed", "refused", "cell cap or occupied");
            }
        }
    }

    if (keyboard_check_pressed(ord("O"))) {
        var _drop = surface_slot(view_mode, _px, _py);
        if (_drop.ok) {
            var _purpose = spawn_purpose(_drop.vx, _drop.vy, _drop.vz, irandom(array_length(purpose_kinds) - 1));
            if (!instance_exists(_purpose)) {
                log_action("world", "purpose", "refused", "purpose cap or occupied");
            }
        }
    }

    if (mouse_check_button(mb_left)) {
        sculpt_at(view_mode, _px, _py, true);
    }
    if (mouse_check_button(mb_right)) {
        sculpt_at(view_mode, _px, _py, false);
    }
}
