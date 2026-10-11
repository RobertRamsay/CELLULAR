/// obj_cellular_world - Draw

gpu_set_texfilter(false);

var _surf = view_surfaces[view_mode];
if (!surface_exists(_surf)) {
    _surf = surface_create(world_size, world_size);
    view_surfaces[view_mode] = _surf;
    view_dirty[view_mode] = true;
}

if (view_dirty[view_mode]) {
    buffer_set_surface(view_buffers[view_mode], _surf, 0);
    view_dirty[view_mode] = false;
}

draw_surface_ext(_surf, 0, 0, display_scale, display_scale, 0, c_white, 1);

if (mouse_y < ui_top) {
    draw_set_colour(c_white);
    draw_set_alpha(0.5);
    draw_circle(mouse_x, mouse_y, brush_radius * display_scale, true);
    draw_set_alpha(1);
}
