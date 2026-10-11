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

## Purposes
- Every 10 to 20 seconds a **purpose** drops onto the terrain in a **sparse area**: 24 spots are sampled and the one with the fewest cells around it (and furthest from other purposes) wins. Press O to drop more under the mouse. Up to 32 at once.
- Kinds take different amounts of work and need different numbers of helpers present before any work counts:

| Purpose | Work | Helpers needed | Helpers wanted |
|---|---|---|---|
| Spark | 150 | 1 | 2 |
| Knot | 600 | 2 | 4 |
| Riddle | 1800 | 4 | 6 |
| Monolith | 4800 | 6 | 10 |

- An idle cell that comes within 20 voxels of an undiscovered purpose becomes its **scout** and goes to check it out.
- Having found it, the scout becomes a **herald**: it heads back to the middle of the idle swarm, telling every idle cell within earshot, who become **workers**.
- Workers travel to the purpose and pass the word to idle cells they pass on the way.
- If workers are waiting at a purpose without enough helpers, one of them goes back as a herald to fetch more.
- When the work is done, **every cell that worked on it gets the same reward**: energy and a boost to its sense of being used.

## Moods
- Each cell keeps a rolling measure of how much of its recent life it has had a purpose.
- Moods: **purposeless** (rarely used), **content**, **purposeful** (has a purpose now), **proud** (used most of the time).
- Mood is a problem-solving multiplier: it scales work rate and how often a cell gets round an obstacle (climbing, tunnelling, dropping cargo) instead of fumbling sideways.

| Mood | Multiplier |
|---|---|
| purposeless | 0.6 |
| content | 0.9 |
| purposeful | 1.15 |
| loyal | 1.0 |
| proud | 1.3 |

- Every 8 to 20 seconds each cell says how it feels in a speech bubble, and it's logged.

## Ranks and loyalty
- Every cell has a name. Each completed purpose counts towards its rank:

| Rank | Purposes completed | Followers it may lead |
|---|---|---|
| Novice | 0 | 0 |
| Helper | 1 | 0 |
| Veteran | 3 | 2 |
| Captain | 6 | 3 |
| Elder | 10 | 6 |

- From Veteran up, an idle cell with room in its force goes looking for a **lonely** cell: one with no leader and no purpose, of lower rank, that is purposeless or has no other cell in its 16-voxel block.
- When it reaches it, the lonely cell joins its force and becomes **loyal**. Loyal followers stay near their leader, never answer anyone else's call, and take up whatever purpose their leader takes up.
- Loyal is its own mood (multiplier 1.0). If a leader is lost, its followers are free again.
- Each rank-up adds **+1 speed** (one more action per tick) and **+2 senses** (how far it notices purposes, how far a herald's call carries, and how far it will go to find someone lonely).
- Rank shows as small pips above a cell; a faint line links each follower to its leader.

## Screen
- 1920 x 1080 room in a resizable window; F11 toggles fullscreen. The cube is shown at 4x in the middle.
- Left panel: world stats, moods, ranks, forces, active purposes and controls.
- Right panel: recent messages, newest first, with the name of the entity behind each one.

## Limits
1024 cells, 24 lanterns, 32 purposes. Each cell gets as many actions per tick as its speed. Crowding and loneliness use live per-block cell counts (16 x 16 x 16 blocks), so they stay cheap at 1024 cells. Mood expressions share a global speech budget (about four a second) so the screen and message log stay readable. Clone choices and lantern refusals are not logged. P pauses everything instantly; K wipes all life.

## Controls
| Key | Action |
|---|---|
| Space | Seed a cell at the surface under the mouse |
| O | Drop a purpose at the surface under the mouse |
| F11 | Toggle fullscreen |
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
- `obj_purpose`: a purpose to be found, shared and worked on.
- `rm_cellular`: 1920 x 1080 room (256 x 256 world at 4x, side panels).
