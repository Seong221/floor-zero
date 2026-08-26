# First Room Blockout

This blockout is the authoritative spatial plan for the opening room. The generated perspective render is only a readability check.

## Coordinate convention

- Blender X: left/right
- Blender Y: depth into the residence
- Blender Z: height
- Entry door center: `(0.0, 0.0)`
- Residence: `10.0 m x 9.5 m`
- Corridor: `3.2 m x 9.0 m`
- Door: `1.5 m x 2.44 m`

## Fixed actor positions

| Actor | Position (X, Y) | Spatial purpose |
|---|---:|---|
| Player | `(0.0, -2.7)` | Approaches through a narrow corridor with no interior preview. |
| Rusher | `(-1.42, 0.88)` | Door-side blind pocket, within one stride of the utility knife. |
| Anchor | `(2.25, 7.28)` | Behind the rear-right work counter with a diagonal entry lane. |
| Flanker | `(4.25, 5.15)` | Inside the right partition route, able to withdraw deeper. |

## Design rules

1. The door is opaque and has no observation window.
2. The central entry lane stays clear.
3. The knife is part of ordinary entrance storage, not displayed on a theatrical table.
4. The Rusher never crosses the room to arm himself.
5. Immediate breach catches residents in transition; delayed breach lets them occupy prepared positions.
6. Furniture must have a domestic/work purpose before it has a combat purpose.

## Generated files

- `blender/first_room_blockout.blend`
- `blender/first_room_top.png`
- `blender/first_room_perspective.png`
