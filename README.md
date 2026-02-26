# Godot World Generation

A procedurally generated city simulation built in Godot 4 using GDScript. Generates a living city with streets, sidewalks, buildings, pedestrians, and cars — all from a single seed value.

## Features

- **Procedural city generation** — 5x5 block grid with roads, sidewalks, intersections, and buildings
- **Seed-based reproducibility** — replay any world with the same seed, or generate a new one on the fly
- **AI navigation** — pedestrians walk sidewalks; cars drive roads, using a two-layer NavigationRegion3D system
- **Entity selection** — click any building, pedestrian, or car to select it, with color-coded indicators and path visualization
- **Free-fly camera** — WASD + mouse look to explore the world

## Controls

### Camera
| Key / Input | Action |
|---|---|
| W / A / S / D | Move forward / left / backward / right |
| Q / E | Move down / up |
| Shift | Move faster |
| Right-click + drag | Look around |
| Scroll wheel | Zoom in / out |

### World Generation
| Key | Action |
|---|---|
| R | Generate a new random world |
| T | Regenerate the current world (same seed) |

### Selection
| Input | Action |
|---|---|
| Left-click entity | Select building, pedestrian, or car |
| Left-click empty space | Deselect |

## Getting Started

1. Install [Godot 4](https://godotengine.org/) (4.2 or later, Compatibility renderer)
2. Clone this repo
3. Open `project.godot` in the Godot editor
4. Press **F5** (or the Play button) to run

## Project Structure

```
GodotWorldGeneration/
├── project.godot          # Project configuration
├── main.tscn              # Main scene
├── world_generator.gd     # Procedural city generation + navigation mesh building
├── pedestrian.gd          # Pedestrian AI (NavigationAgent3D on sidewalks)
├── car.gd                 # Car AI (NavigationAgent3D on roads)
├── player_camera.gd       # Free-fly camera controller
└── selection_manager.gd   # Raycasting selection with visual indicators
```

## Configurable Parameters

All parameters are exposed as editor exports on the `WorldGenerator` node.

| Parameter | Default | Description |
|---|---|---|
| `world_seed` | 0 | Seed value (used when `use_random_seed` is false) |
| `use_random_seed` | true | Randomize seed on each generation |
| `grid_size` | 5 | City grid dimensions (N×N blocks) |
| `block_size` | 30 units | Distance between streets |
| `street_width` | 8 units | Total road width including sidewalks |
| `sidewalk_width` | 1.5 units | Width of sidewalk on each side |
| `min/max_building_height` | 5–25 units | Building height range |
| `min/max_building_width` | 4–10 units | Building width range |
| `building_density` | 0.9 | Probability a lot gets a building (0–1) |
| `color_variation` | 0.1 | HSV variation applied to building base colors |
| `people_count` | 50 | Number of pedestrians spawned |
| `person_speed` | 1.5 units/s | Pedestrian walking speed |
| `car_count` | 20 | Number of cars spawned |
| `car_speed` | 8.0 units/s | Car driving speed |

## Technical Notes

- **Renderer**: GL Compatibility mode (broad hardware support)
- **Language**: GDScript
- **Navigation**: Two independent NavigationRegion3D layers — layer 1 for sidewalks (pedestrians), layer 2 for roads (cars)
- **Collision**: Layer 2 used exclusively for selection raycasting; `collision_mask = 0` prevents physical collisions between entities
- **Placeholder graphics**: Capsules for people, box + cylinder wheels for cars, box meshes for buildings
