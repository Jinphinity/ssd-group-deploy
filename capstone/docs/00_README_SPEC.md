# Dizzy’s Disease — Build Canvas

This repo follows the Technical Spec Pack v1. High‑level map:

- Godot 4.4 client with perspective‑agnostic rigs/controllers
- Autoloads: Game, Config, Save, Api, Time, Audio, Analytics
- Core systems scaffolded: Ballistics, DamageModel, Perception, FSM, EventBus
- Scenes: Player, Zombie_Basic, Outpost/HostileZone, Stage_Outpost, Stage_Hostile_01
- UI placeholders: HUD, Menu, Inventory, Market, Results

See `Dizzy's Disease Specification.md` for the source of truth.

## How to run

- Open `capstone/project.godot` in Godot 4.4.
- Press Play. `Stage_Outpost` is the main scene.
- WASD to move. Left click fires a hitscan shot; basic noise events alert NPCs.

## Perspective switching

`Game.set_perspective("FPS"|"TPS"|"Iso"|"Side")` swaps the rig at runtime (dev).

## Next

- Implement NPC FSM (Patrol→Investigate→Chase→Attack→Search→Idle)
- Add Market/Settlement controllers and Events loop
- Wire Save/Api to a real backend
- Seed items/NPC templates and add spawn system

