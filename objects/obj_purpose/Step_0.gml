/// obj_purpose - Step

if (global.cellular_paused) {
    exit;
}

if (!completed) {
    if (work_done >= work_needed) {
        complete();
    }
}
