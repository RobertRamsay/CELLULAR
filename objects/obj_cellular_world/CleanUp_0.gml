/// obj_cellular_world - Clean Up

buffer_delete(voxels);
ds_grid_destroy(top_cache);
ds_grid_destroy(front_cache);
ds_grid_destroy(side_cache);

for (var i = 0; i < 3; i++) {
    buffer_delete(view_buffers[i]);
    if (surface_exists(view_surfaces[i])) {
        surface_free(view_surfaces[i]);
    }
}
