# CELLULAR

A GameMaker project. A living pixel inside a 256 x 256 x 256 voxel room.

## The world
- 256 x 256 x 256 voxels (16 MB byte buffer). Each voxel is empty, a static pixel, a cell, or a lantern.
- Shown in greyscale from one of three directions (V to switch):
  - **Top**: looking down Z, grey = height of the highest pixel.
  - **Front**: looking along Y, grey = how near the pixel is.
  - **Side**: looking along X, grey = how near the pixel is.
- Black is empty space. Matter starts at a dark grey, so a pixel on the floor is still visible.

## Cells (living pixels)
- Move freely through empty voxels in any of 26 directions. When not touching matter they drift down.
- **Dig** a static pixel and carry it, or **place** a carried pixel. A cell can only place what it has dug, so cells never create matter.
- Every action passes through one gatekeeper (`request_action`) that enforces the pause, the registered action list and a per-tick cap.
- **Every 10 seconds** a cell makes a life choice:
  - **Clone** if it has the energy, isn't crowded, the population is under the cap, and its genome leans that way. The clone costs energy, takes half the cargo, and gets a slightly mutated genome.
  - Otherwise a **Lantern** appears beside it.

## Lanterns (special pixels)
- Can't move or clone.
- Every half second, floating static pixels within 6 voxels drop one level until supported, and cells within 10 voxels gain energy.
- After 60 seconds a lantern settles into a permanent static pixel.

## Limits
64 cells, 24 lanterns, one action per cell per tick. P pauses everything instantly; K wipes all life.

## Controls
| Key | Action |
|---|---|
| Space | Seed a cell at the surface under the mouse |
| Left mouse | Add static pixels to the surface under the mouse |
| Right mouse | Remove static pixels from the surface under the mouse |
| Mouse wheel | Brush size |
| V | Cycle top / front / side view |
| G | Generate new terrain (wipes life) |
| C | Clear to an empty cube (wipes life) |
| P | Pause / resume |
| K | Wipe all cells and lanterns |

## Structure
- `obj_cellular_world`: voxel store, projections, limits, gatekeeper, input.
- `obj_cell`: the living pixel, its genome and life choice.
- `obj_lantern`: the special pixel.
- `rm_cellular`: 768 x 848 room (256 x 256 world at 3x, plus a status bar).
