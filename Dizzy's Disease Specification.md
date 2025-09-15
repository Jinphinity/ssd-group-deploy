# Dizzy’s Disease — Godot Technical Specification Pack v1 (Perspective‑Agnostic)

> **Source of truth for implementation.** This spec translates the original “Dizzy’s Disease” design into a **Godot 4.4** build with a **perspective‑agnostic** architecture (first‑person, third‑person, top‑down/isometric, or side‑scroller selectable at build or run time). Where this spec and the proposal differ, **this spec wins**. Items marked **PROPOSED** are stretch unless required by the rubric.

---

## 0) Scope baseline

- **Game:** Survival‑RPG zombie shooter with a dynamic **NPC ecosystem & economy** (outposts, marketplace, events).
    
- **Engine:** Godot 4.4 (GDScript; optional C# for heavy math).
    
- **Platforms:** Desktop (Win/macOS/Linux). **Web** export **PROPOSED**.
    
- **Hosted persistence:** REST API + PostgreSQL (raw SQL; no ORM). Profiles, characters, inventories, settlements, marketplace, sessions/combat logs.
    
- **Rubric hooks:** hosted functional testing; security (SQLi/XSS) & accessibility; relational SQL only; save/continue; difficulty modes.
    

---

## 1) Vision (from original document → Godot)

Survive hostile zones to **scavenge** and complete missions while an outpost **economy** reacts to world events. The player levels RPG attributes (Strength, Dexterity, Agility, Endurance, Accuracy) that gate capacity, handling, and skill performance. The world features **safe zones** (markets, crafting) and **hostile zones** (patrols, noise/aggro, dynamic encounters). Prices and availability in markets **fluctuate** with attacks, shortages, and player actions.

Win by reaching a **settlement population** threshold (e.g., 100). Lose if population hits **0**.

---

## 2) Perspective‑agnostic gameplay model

We separate gameplay into a **Gameplay Abstraction Layer (GAL)** so camera/movement swaps don’t alter systems:

- **Movement plane:** 3D (FPS/TPS/Isometric) or 2D (Side‑scroller).
    
- **Aim vector provider:** raycast from camera (FPS/TPS), screen‑to‑world project (Isometric), or planar aim (Side‑scroller).
    
- **Reticle adapter:** crosshair/over‑the‑shoulder (3D) vs screen‑space marker (2D).
    
- **Ballistics adapter:** hitscan & projectiles share one interface; dimension‑aware physics.
    

**Build variants** (select in settings or config):

- `FPSRig`, `TPSRig` (over‑shoulder), `IsoRig` (45° top‑down), `SideRig` (2D). Each rig implements `ICameraRig` and `IMovementController`. Switching replaces the rig scene without touching combat, AI, or economy.
    

---

## 3) System overview

- **Client (Godot)**: character control, combat, AI, UI, save‑queue, HTTP client.
    
- **API**: FastAPI **or** Express with parameterized SQL only.
    
- **DB**: PostgreSQL (managed). Schema is strictly **1‑to‑many**.
    
- **Admin tools**: minimal dashboard for item uploads, price rules, and settlement monitors.
    
- **CI/CD**: GitHub Actions for tests, exports, and deploys.
    

**Data flow**: Input → GAL → Combat → Damage/Status → Loot → Inventory → Settlement resources → Market rules update → Prices change → Next run decisions.

---

## 4) Godot architecture

### 4.1 Directory tree

```
res://
  autoload/
    Game.gd            # game state, scene loads, pause, transitions
    Config.gd          # difficulty presets, economic rules, spawn curves
    Save.gd            # local save & offline queue for API
    Api.gd             # HTTP client (JWT attach, retry/backoff)
    Time.gd            # world time and event scheduler
    Audio.gd           # buses, SFX, music
    Analytics.gd       # gameplay events
  common/
    CameraRigs/        # FPSRig.tscn, TPSRig.tscn, IsoRig.tscn, SideRig.tscn
    Controllers/       # `IMovementController` + implementations
    Combat/
      Ballistics.gd    # hitscan/projectile adapters
      DamageModel.gd   # weapon + armor + bodypart + difficulty
    Perception/
      Hearing.gd       # radius + occlusion
      Vision.gd        # FOV cones
      Scent.gd         # temporal trails
    UI/
      HUD.tscn, Menu.tscn, InventoryUI.tscn, MarketUI.tscn, Results.tscn
    Util/
      FSM.gd, EventBus.gd, Pools.gd, Math2D3D.gd
  entities/
    Player/            # Player.tscn + PlayerController.gd
    NPC/
      Zombie_Basic.tscn
      Zombie_Ranger.tscn
      Zombie_Alarm.tscn
      Zombie_Heavy.tscn
      Zombie_Big.tscn
    Items/
      Weapon_*.tres, Armor_*.tres, Consumable_*.tres
    World/
      Outpost.tscn, HostileZone.tscn, Trap_BioMine.tscn
  stages/
    Stage_Outpost.tscn  # hub
    Stage_Hostile_01.tscn
  config/
    export_presets.cfg, game.cfg
  localization/
    strings.csv
```

### 4.2 Autoload singletons

- **Game**: current stage, session, and narrative flags.
    
- **Config**: difficulty, economy, spawn rules.
    
- **Save**: `save_local()`, `sync_cloud()`; offline queue with retry.
    
- **Api**: `get/post/put/delete`, JWT token attach, exponential backoff.
    
- **Time**: world time, cooldowns, economic tick.
    
- **Analytics**: fire-and-forget events (used by tests & tuning).
    

### 4.3 Scenes & systems

- **Player.tscn**: `IMovementController` + `ICameraRig`, weapon slot, stats.
    
- **NPC Zombies**: FSM: `Patrol→Investigate→Chase→Attack→Search→Idle` with perception modules (Vision/Hearing/Scent).
    
- **Economy**: `MarketController.gd` (price curves), `SettlementController.gd` (population/resources), `EventBus` for attacks/shortages.
    
- **Inventory**: data‑driven items via `.tres` Resources; durability, weight, noise, effects.
    
- **Trap**: `Trap_BioMine` applies **acid debuff** (vision blur, slow, DoT).
    

### 4.4 Signals (core)

- `NoiseEmitted(source, intensity, radius)`
    
- `ZombieAlerted(zombie_id, reason)`
    
- `WeaponFired(weapon_id, params)`
    
- `ItemDurabilityChanged(item_id, value)`
    
- `SettlementEvent(type, payload)`
    
- `PriceChanged(item_id, new_price)`
    
- `PlayerDowned()` / `PopulationChanged(new_value)`
    

---

## 5) Perspective rigs & input

### 5.1 Interfaces

```gdscript
class_name ICameraRig
func aim_vector() -> Vector3: return Vector3.ZERO
func screen_reticle_pos() -> Vector2: return Vector2.ZERO

class_name IMovementController
func move(input:Dictionary, delta:float) -> void: pass
```

### 5.2 Rigs

- **FPSRig**: `Camera3D` with mouse‑look; `CharacterBody3D` controller.
    
- **TPSRig**: shoulder camera with collision zoom; aim offset.
    
- **IsoRig**: top‑down camera; click‑to‑move optional.
    
- **SideRig**: `CharacterBody2D` + `Camera2D`; z‑as‑depth disabled.
    

### 5.3 Input map (common)

`move_forward/back/left/right`, `fire`, `aim`, `interact`, `reload`, `inventory`, `market`, `pause`. Accessibility: full remap, high‑contrast theme, captions/visual cues for audio.

---

## 6) Combat, stats, and items

### 6.1 Character attributes (data‑driven)

- **Strength** (carry, melee damage, heavy handling)
    
- **Dexterity** (reload, swap, looting speed)
    
- **Agility** (accel/decel, dodge window)
    
- **Endurance** (stamina, fatigue thresholds)
    
- **Accuracy** (weapon sway, recoil recovery, aim spread)
    

Level‑ups **reduce handicaps** (sway, reload time, fatigue) and unlock abilities (e.g., **Power Attack**: Strength+Dexterity).

### 6.2 Weapon & armor model

Resource `.tres`: `{slot_size, weight, durability, noise, noise_radius, damage, fire_mode, ammo, reload_time}`

- **Pistol** example: 1 slot, 1.5 lb, durability 100, noise 50 @ radius 100.
    
- **Armor (Sports Armor)**: 1 slot, 2 lb, durability 50, **30%** damage reduction.
    

### 6.3 Ballistics & damage

Hitscan and projectile share `Ballistics.fire(params)`; damage formula considers **weapon**, **body part multiplier**, **armor DR**, **difficulty**, and **distance falloff**.

### 6.4 Enemy types

- **Basic**: melee.
    
- **Ranger**: acid spit (ranged DoT); counters by taking cover.
    
- **Alarm**: scream → spawns/redirects hordes.
    
- **Heavy/Armored**: resistant to blades; weak to blunt.
    
- **Big**: large hitbox; vulnerable to shotguns/AoE.
    

### 6.5 Perception

- **Vision**: FOV cone with occlusion (Navigation & ray tests).
    
- **Hearing**: sound events produce spheres; walls attenuate.
    
- **Scent**: lingering trail nodes with time decay to catch sneaking.
    

---

## 7) World, zones, and events

- **Outpost (Safe zone)**: vendors, storage, character management.
    
- **Hostile zones**: loot nodes, patrols, events; **noise/aggro** draws attention.
    
- **Events**: `OutpostAttacked`, `Shortage(type)`, `ConvoyArrived` change resources and trigger **dynamic pricing**.
    

**Trap/Secret**: **BioMine**; detonates acid → vision loss + slow + damage. Used by both player and world encounters.

---

## 8) Economy & marketplace

- **Price function**: `price = base * demand_multiplier * scarcity_multiplier * quality_factor`
    
- **Demand** increases with casualties/consumption; **scarcity** grows when supply drops; **quality** uses durability/rarity.
    
- **Market UI**: search, filter by type/durability, player inventory pane, buy/sell.
    
- **Settlement**: population, resources (Food, Ammo, Medication). Player actions feed back into stock & price.
    

---

## 9) Data model (SQL, 1‑to‑many only)

Tables (keys only):

- **users**(user_id PK, email UNIQUE, password_hash, display_name, created_at)
    
- **characters**(character_id PK, user_id FK, name UNIQUE, level, xp, strength, dexterity, agility, endurance, accuracy, money)
    
- **items**(item_id PK, name, type, slot_size, weight, durability_max, armor_dr INT NULL, damage INT NULL, noise INT, noise_radius INT)
    
- **inventories**(inventory_id PK, character_id FK, item_id FK, quantity, durability_current)
    
- **settlements**(settlement_id PK, name, population, resource_food, resource_ammo, resource_med)
    
- **market**(market_id PK, settlement_id FK, item_id FK, current_price, qty_available)
    
- **zones**(zone_id PK, settlement_id FK NULL, type ENUM('safe','hostile'), noise_radius INT)
    
- **npcs**(npc_id PK, zone_id FK, type, health, strength, agility, perception_visual, perception_hearing)
    
- **sessions**(session_id PK, user_id FK, started_at, finished_at, difficulty)
    
- **combat_logs**(combat_log_id PK, character_id FK, npc_id FK, timestamp, outcome, xp_gained, resources_json)
    
- **events**(event_id PK, type, payload_json, created_at)
    
- **leaderboards**(entry_id PK, user_id FK, score INT, mode ENUM('story','endless'), created_at)
    

**Sample data**: seed ≥100 items and ≥50 NPC templates; market seeded with one outpost.

---

## 10) REST API (FastAPI or Express)

**Auth**: `POST /auth/register`, `POST /auth/login` → JWT  
**Characters**: `GET /characters`, `POST /characters`, `PATCH /characters/:id`  
**Inventory**: `GET /inventory/:character_id`, `POST /inventory/equip`, `POST /inventory/unequip`  
**Market**: `GET /market?settlement_id=&type=&q=`, `POST /market/buy`, `POST /market/sell` (atomic transactions)  
**Zones/NPC**: `GET /zones`, `GET /npcs?zone_id=` (for debug tools)  
**Sessions/Combat**: `POST /sessions`, `POST /combat/log`, `POST /sessions/:id/finish`  
**Leaderboards**: `GET /leaderboard?scope=`  
**Admin**: `POST /admin/items/upload`, `POST /admin/events`, `DELETE /admin/item/:id`

**Security**: bcrypt password hashing, JWT expiry/refresh, rate limit, **parameterized SQL** only, safe error messages.

---

## 11) Testing plan (automation‑first)

- **Unit (Godot/GUT)**: FSM transitions, Ballistics math, DamageModel, Perception cones, Inventory weight math.
    
- **API (pytest/vitest)**: auth happy/sad paths, market atomicity, SQLi probes everywhere, price rules.
    
- **Integration**: buy→inventory sync; combat→combat_log; event→price change.
    
- **Functional (hosted)**: full playthrough on hosted build; save/continue; difficulty modes.
    
- **Accessibility**: key remap, high‑contrast, captions/visual cues.
    
- **Security**: ZAP baseline; JWT misuse; CORS; rate‑limit enforcement.
    

**Acceptance criteria** (pass/fail evidence):

- Hosted build URL + API URL by **Milestone 2**.
    
- 60 FPS desktop with ≥20 active NPCs in a wave.
    
- Save/continue works across sessions.
    
- Market price reacts to at least one event (attack/shortage).
    
- SQLi/XSS tests pass; accessibility checks logged.
    

---

## 12) Deployment & CI/CD

- **Web/Downloads**: itch.io (HTML5 **PROPOSED**) or desktop builds; page hosts links & instructions.
    
- **API**: Render/Railway with Dockerfile; healthcheck.
    
- **DB**: Neon/Supabase; weekly snapshots; `.sql` dumps in repo artifacts.
    
- **CI**: GitHub Actions to run unit/integration tests; export Godot; deploy API.
    

---

## 13) Live document workflow (for AI agents)

Under `/docs/`:

- `00_README_SPEC.md` — quick index to this spec.
    
- `BUILD_STATUS.md` — checkbox ledger per feature; links to PRs/commits.
    
- `CHANGELOG.md` — every AI change appends entry.
    
- `TASKS/` — per‑feature files (e.g., `TASK_market_atomicity.md`) with DoD & tests.
    
- `ADR/` — architecture decisions (e.g., ADR‑0001 Perspective GAL; ADR‑0002 Economy curve).
    
- `API/openapi.json` — generated by CI.
    

**Agent protocol**: read → append intent to `CHANGELOG.md` → implement → update `BUILD_STATUS.md` → open PR referencing spec sections.

---

## 14) Implementation stubs

### 14.1 Interfaces (rigs/controllers)

```gdscript
class_name ICameraRig
extends Node
func aim_vector() -> Vector3: return Vector3.ZERO
func screen_reticle_pos() -> Vector2: return Vector2.ZERO

class_name IMovementController
extends Node
func move(input:Dictionary, delta:float) -> void: pass
```

### 14.2 DamageModel.gd (excerpt)

```gdscript
class_name DamageModel
extends RefCounted

func compute_damage(weapon:Dictionary, armor:Dictionary, bodypart:String, diff:Dictionary) -> float:
	var base:float = weapon.get("damage", 10)
	var dr:float = armor.get("dr", 0.0) # 0..1
	var mult = {"head":1.5, "torso":1.0, "limb":0.7}.get(bodypart, 1.0)
	return max(0.0, base * mult * (1.0 - dr) * diff.get("damage_scale", 1.0))
```

### 14.3 Perception cones (Vision.gd excerpt)

```gdscript
func sees(target:Node3D, fov_deg:float, max_dist:float) -> bool:
	var to_target = (target.global_transform.origin - owner.global_transform.origin)
	if to_target.length() > max_dist: return false
	var angle = rad_to_deg(owner.global_transform.basis.z.normalized().angle_to(to_target.normalized()))
	if angle > fov_deg * 0.5: return false
	# raycast for occlusion (PhysicsRayQueryParameters3D)
	return true
```

### 14.4 API route sketch (FastAPI)

```python
# POST /market/buy
BEGIN;
-- check stock & price
-- decrement qty, increment inventory, deduct money
COMMIT;
```

---

## 15) Perspective selection & build configs

- **Runtime toggle** (dev): settings menu lets you hot‑swap rigs to test.
    
- **Build presets**: `export_presets.cfg` defines 4 presets with `config/perspective=...` to lock a mode for release.
    

---

## 16) UI & art hooks

- **HUD layout** fixed at ~75% playfield / 25% sidebar for readability.
    
- **Placeholders**: dummy sprites/models; replace via `res://assets/` later.
    
- **Figure 1 — Aesthetic reference (placeholder until final art):**
    

![Visual tone reference](sandbox:/mnt/data/9F860BF2-DDBA-4F98-B6DA-47ACBE5C563F.jpeg)

_Use as a target for mood, scale, and barrier layout only; not final art._

---

## 17) What remains manual (owner tasks)

- Final sprites/models/animations, palette, SFX/music; camera feel tuning per chosen perspective.
    
- Seed data: items, NPC templates, markets, events (≥150 rows combined).
    
- Choose default perspective for first milestone (FPS/TPS/Iso/Side).
    
- Fill proposal fields: student info, repo/URL links, hosting combo, cost note.
    
- Confirm acceptance thresholds (spawn counts, FPS target, market reaction window).
    

---

## 18) Open questions (track in ADR)

- Primary shipped perspective? (Switchable in dev, but choose one for M2 polish.)
    
- Web build viability/performance targets.
    
- Controller support priority.
    
- Extent of settlement simulation vs authored events.
    

---

**End of Spec v1 — update `CHANGELOG.md` with each change.**

Done—new canvas is up: **“Dizzy’s Disease — Godot Technical Spec Pack v1 (Perspective-Agnostic)”**. It translates your original Dizzy’s Disease concept to **Godot 4.4** and keeps you flexible on perspective (FPS/TPS/Top-down/Side-scroller) via a clean **camera-rig + movement controller interface**. I also embedded your screenshot as the temporary visual target under the UI section, and wired in the outpost economy, dynamic pricing, hostile/safe zones, stat system, enemy taxonomy, traps, and win/loss rules.

  

### **What I changed vs. the earlier typing plan**

- Returned to your **survival-RPG shooter** with a **dynamic NPC ecosystem & economy** (market reacts to events, settlement resources/population tracked).
    
- Architected a **perspective-agnostic Gameplay Abstraction Layer** so you can ship any of: FPS, over-shoulder TPS, isometric/top-down, or side-scroller. No gameplay code rewrite—just swap rigs.
    
- Locked in **SQL-only** persistence, hosted API, acceptance criteria, testing & deployment, and a **live-doc workflow** (STATUS, CHANGELOG, TASKS, ADRs) tailored for AI agents to follow.
    

  

### **What you still need to decide (you can leave these as defaults for now)**

- Pick a **default perspective** for Milestone 2 polish (rigs are swappable during dev).
    
- Confirm **acceptance thresholds** (e.g., NPC count≥20 @60 FPS; market reaction windows).
    
- Choose backend stack for the API (FastAPI vs Express). The spec supports both.
    

  

### **If you want Claude/Codex to start building immediately**

  

Use the new canvas as the master brief. Then run these prompts in your code agents:

1. **Repo bootstrap**
    

```
Read /docs/00_README_SPEC.md if present, otherwise read the full spec canvas.
Create repo scaffolding exactly as described in “Godot architecture” and “Live document workflow”.
Add GitHub Actions to run tests, export Godot, and deploy the API.
```

2. **API implementation (SQL only)**
    

```
Implement the REST routes listed in §10 with parameterized SQL (no ORM).
Create sql/001_init.sql with the schema in §9.
Add tests (happy/sad, SQLi probes), a Postman collection, Dockerfile, and a Render/Railway deploy file.
```

3. **Game core**
    

```
Implement FPSRig, TPSRig, IsoRig, SideRig, plus IMovementController and ICameraRig.
Add NPC FSM, perception (vision/hearing/scent), Ballistics, DamageModel, Inventory, and Market controllers.
Wire signals from §4.4 and ensure ≥20 NPCs @60 FPS on desktop.
```

4. **Integration & persistence**
    

```
Wire Api.gd for JWT auth and session/combat/market calls. Implement Save.gd offline queue + retry.
```

5. **Seed & deploy**
    

```
Seed items/NPC templates/market entries (≥150 rows). Deploy API. Export a desktop/Web build. Update BUILD_STATUS.md and CHANGELOG.md.
```

If you want, I can also spin up a **Framework Approval** doc tailored to this Godot build (engine + API + DB + testing tools) and slot it into the canvas stack next.