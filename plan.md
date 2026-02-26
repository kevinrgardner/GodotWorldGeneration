# Procedural World Generation - Game Plan

## Project Overview
A procedurally generated game world built in Godot Engine using Compatibility mode rendering. The project focuses on generating a city-like environment with streets, sidewalks, buildings, pedestrians, and cars, using minimal placeholder graphics.

## Visual Style (Placeholder Graphics)
- **People**: Capsule meshes (moving pedestrians on sidewalks)
- **Cars**: Box body + cylinder wheels (moving vehicles on roads)
- **Buildings**: Box/rectangle meshes with varying heights
- **Streets**: Flat plane meshes (dark gray roads)
- **Sidewalks**: Raised plane meshes (light gray, curb effect)
- **Ground**: Base plane mesh

---

## Development Phases

### Phase 1: Project Setup & Basic Scene [COMPLETE]
- [x] Create new Godot project with Compatibility renderer
- [x] Set up main scene structure
- [x] Add basic ground plane (200x200 units)
- [x] Implement player-controlled camera (WASD + Q/E + mouse look)
- [x] Add basic directional light (sun) and ambient lighting

### Phase 2: Street System Generation [COMPLETE]
- [x] Design street grid algorithm (5x5 grid, configurable)
- [x] Generate street meshes as flat planes
- [x] Implement street width and intersection handling
- [x] Add visual distinction between streets and ground (dark gray vs green)

### Phase 3: Building Placement [COMPLETE]
- [x] Create building generator (box meshes with random heights)
- [x] Place buildings adjacent to streets (along all 4 edges of each block)
- [x] Implement lot subdivision along street segments (variable width buildings)
- [x] Add variety: building width, depth, height ranges

### Phase 4: Procedural Enhancements [COMPLETE]
- [x] Add randomized building colors/materials (8 base colors + HSV variation)
- [x] Implement seed-based generation for reproducibility
- [x] Add generation parameters (density, color variation)
- [x] Runtime controls: R = new random world, T = regenerate same seed

### Phase 5: People/Entities [COMPLETE]
- [x] Add capsule-based people placeholders
- [x] Basic spawning on streets (configurable count)
- [x] Varied heights and colors (skin tones + clothing colors)

### Phase 6: Sidewalks, Navigation & Cars [COMPLETE]
- [x] Add sidewalk geometry (1.5 unit width on each side of roads)
- [x] Reduce road width to 5 units (8 - 1.5 - 1.5)
- [x] Sidewalks at y=0.05 for curb effect, roads at y=0.01
- [x] Light gray sidewalk material distinct from dark roads
- [x] Corner sidewalk pieces at all intersections (fills gaps at map edges)
- [x] Set up NavigationRegion3D nodes with separate layers (sidewalks=1, roads=2)
- [x] Build navigation meshes programmatically from geometry
- [x] Convert people to moving pedestrians with NavigationAgent3D
- [x] Pedestrians walk on sidewalks, pause randomly, pick new destinations
- [x] Add car entities with box body and 4 cylinder wheels
- [x] Cars navigate on roads using NavigationAgent3D
- [x] Cars rotate to face movement direction
- [x] Varied car colors (red, blue, white, black, silver)

### Phase 7: Selection System [COMPLETE]
- [x] Add collision shapes to buildings, pedestrians, and cars for raycasting
- [x] Use dedicated collision layer (layer 2) for selection-only detection
- [x] Set collision_mask = 0 to prevent physical collisions between entities
- [x] Implement SelectionManager with mouse click raycasting
- [x] Selection indicator (torus ring) with color coding:
  - Blue for buildings
  - Green for pedestrians
  - Red for cars
- [x] Path visualization for selected pedestrians and cars
- [x] Selection persists and updates as entities move
- [x] Click empty space to deselect

---

## Scene Structure
```
Main (Node3D)
├── WorldGenerator (Node3D) [world_generator.gd]
│   ├── Ground (MeshInstance3D) - 200x200 plane
│   ├── Streets (Node3D)
│   │   └── [Generated road segments + intersections]
│   ├── Sidewalks (Node3D)
│   │   └── [Generated sidewalk segments + corner pieces]
│   ├── Buildings (Node3D)
│   │   └── [Generated box meshes with StaticBody3D for selection]
│   ├── NavigationSidewalks (NavigationRegion3D) - layer 1
│   ├── NavigationRoads (NavigationRegion3D) - layer 2
│   ├── People (Node3D)
│   │   └── [CharacterBody3D pedestrians with NavigationAgent3D]
│   └── Cars (Node3D)
│       └── [CharacterBody3D cars with NavigationAgent3D]
├── PlayerCamera (Camera3D) [player_camera.gd]
├── SelectionManager (Node3D) [selection_manager.gd]
│   ├── [Selection indicator - torus mesh]
│   └── [Path visualizer - immediate mesh]
└── Lighting (Node3D)
    ├── Sun (DirectionalLight3D) - with shadows
    └── WorldEnvironment - sky blue background, ambient light
```

---

## Technical Notes
- **Renderer**: Compatibility mode (for broader hardware support)
- **Version Control**: None (local project only)
- **Language**: GDScript
- **Navigation**: Two-layer system separating pedestrians (sidewalks) from cars (roads)
- **Collision Layers**: Layer 2 dedicated to selection raycasting (mask=0 prevents physical collisions)

---

## Current Status
**Phase**: All Phases Complete (1-7) + Bug Fixes
**Last Updated**: Building overlap fix applied

### Files Created
- `project.godot` - Project configuration with Compatibility renderer
- `main.tscn` - Main scene with ground, camera, lighting, navigation, selection, and world generator
- `player_camera.gd` - Camera controller script
- `world_generator.gd` - Full procedural generation system with navigation mesh building
- `pedestrian.gd` - Moving pedestrian AI with NavigationAgent3D
- `car.gd` - Moving car AI with NavigationAgent3D
- `selection_manager.gd` - Entity selection with visual indicators and path visualization

### Generation Parameters (Configurable in Editor)

**Seed Settings:**
- `world_seed`: Specific seed value (when use_random_seed is false)
- `use_random_seed`: true/false - generates new seed each time if true

**Grid Settings:**
- `grid_size`: 5 (creates 5x5 city blocks)
- `block_size`: 30 units (distance between streets)
- `street_width`: 8 units (total width including sidewalks)

**Sidewalk Settings:**
- `sidewalk_width`: 1.5 units (on each side of road)

**Building Settings:**
- `min_building_height`: 5 units
- `max_building_height`: 25 units
- `min_building_width`: 4 units
- `max_building_width`: 10 units
- `building_depth`: 6 units
- `building_spacing`: 1 unit (gap between buildings)
- `setback_from_street`: 1 unit (space between sidewalk and building)
- `building_density`: 0.9 (0.0-1.0, chance to place each building)
- `color_variation`: 0.1 (HSV variation applied to base colors)

**People Settings:**
- `people_count`: 50 (number of pedestrians to spawn)
- `min_person_height`: 1.6 units
- `max_person_height`: 2.0 units
- `person_radius`: 0.3 units (capsule radius)
- `person_speed`: 1.5 units/sec (walking speed)

**Car Settings:**
- `car_count`: 20 (number of cars to spawn)
- `car_speed`: 8.0 units/sec (driving speed)

### Runtime Controls

**World Generation:**
- **R key**: Generate new random world
- **T key**: Regenerate with same seed

**Selection:**
- **Left-click**: Select building, pedestrian, or car
- **Left-click empty space**: Deselect current selection

**Camera Movement:**
- **W/A/S/D**: Move forward/left/backward/right
- **Q/E**: Move down/up
- **Shift**: Move faster
- **Right-click + drag**: Look around
- **Scroll wheel**: Zoom in/out

---

## Future Features
*Planned features for upcoming phases:*

---

## Bug Fixes & Improvements

### Building Overlap [FIXED]
- [x] Track placed building X-Z footprints (`Rect2`) in `_placed_buildings` array
- [x] Added `_footprint_overlaps()` check before placing each building
- [x] Skip buildings whose footprint intersects an existing one (corner overlaps between perpendicular block edges)
- [x] Reset footprint list on each world regeneration via `_clear_world()`

---

### Phase 8: TBD
- [ ] (awaiting requirements)
