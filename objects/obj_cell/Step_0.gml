/// obj_cell - Step

if (global.cellular_paused) {
    exit;
}

var _limits = global.cellular_world.limits;

energy = min(1, energy + _limits.energy_regen);
tick_timer     += 1;
decision_timer += 1;

if (tick_timer >= _limits.tick_steps) {
    tick_timer        = 0;
    actions_this_tick = 0;
    update_mood();

    // Loyal followers never freelance; everyone else notices purposes nearby.
    if (purpose_target == noone && !instance_exists(leader)) {
        look_for_purpose();
    }

    if (purpose_target != noone) {
        purpose_turn();
    } else if (instance_exists(leader)) {
        follow_turn();
    } else if (role == "seeking") {
        seek_turn();
    } else {
        consider_seeking();
        if (role == "seeking") {
            seek_turn();
        } else {
            take_turn();
        }
    }
}

express_timer -= 1;
if (express_timer <= 0) {
    express();
    express_timer = irandom_range(_limits.express_min_steps, _limits.express_max_steps);
}

if (bubble_timer > 0) {
    bubble_timer -= 1;
}

if (decision_timer >= _limits.decision_steps) {
    decision_timer    = 0;
    actions_this_tick = 0;
    make_life_choice();
}
