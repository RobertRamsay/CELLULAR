/// obj_purpose - Step

refresh_counts();

if (global.cellular_paused) {
    exit;
}

if (!completed) {
    if (work_done >= work_needed) {
        complete();
    }
}
