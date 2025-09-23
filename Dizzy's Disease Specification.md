# Dizzy’s Disease — Godot Technical Specification Pack v1 (Perspective‑Agnostic)

> **Source of truth for implementation.** This spec translates the original “Dizzy’s Disease” design into a **Godot 4.4** build with a **perspective‑agnostic** architecture (first‑person, third‑person, top‑down/isometric, or side‑scroller selectable at build or run time). Where this spec and the proposal differ, **this spec wins**. Items marked **REQUIRED for capstone** are stretch unless required by the rubric.

---

## 0) Scope baseline

- **Game:** Survival‑RPG zombie shooter with a dynamic **NPC ecosystem & economy** (outposts, marketplace, events).
    
- **Engine:** Godot 4.4 (GDScript; optional C# for heavy math).
    
- **Platforms:** Desktop (Win/macOS/Linux). **Web** export **REQUIRED for capstone**.
    
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


### 4.2.1 Mobile-First Architecture (Academic Compliance)

**Responsive UI Framework**:
- **Viewport Management**: Dynamic scale adaptation for mobile/tablet/desktop viewports
- **Touch Input System**: Multi-touch gesture recognition, virtual joysticks, responsive touch zones
- **Adaptive UI Layouts**: Container-based responsive layouts using Godot's UI containers
- **Performance Scaling**: Automatic quality settings based on device capabilities

**Mobile-Specific Optimizations**:
- **Rendering Pipeline**: Mobile-optimized GL Compatibility mode, texture compression
- **Input Abstraction**: Unified input system supporting touch, gamepad, and keyboard
- **Battery Optimization**: Power-efficient update cycles, background processing management
- **Memory Management**: Asset streaming, texture atlasing, memory pool optimization

**Cross-Platform Features**:
- **Save Synchronization**: Cloud save compatibility across mobile/desktop platforms
- **Network Adaptation**: Bandwidth-aware networking, offline queue for mobile connectivity
- **Accessibility Support**: Screen reader compatibility, high contrast modes, font scaling
- **Platform Integration**: Native notifications, platform-specific UI conventions

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

### 6.1.1 Weapon Proficiency System (Academic Compliance)

**Six Weapon Proficiency Categories** (0-100 scale):
- **Melee - Knives**: Affects attack speed, critical hit chance, stealth kills
- **Melee - Axes/Clubs**: Affects damage multiplier, armor penetration, knockdown chance
- **Firearm - Handguns**: Affects accuracy, reload speed, dual-wield capability
- **Firearm - Rifles**: Affects long-range accuracy, stability, scope effectiveness
- **Firearm - Shotguns**: Affects spread pattern, reload efficiency, close-quarters damage
- **Firearm - Automatics**: Affects recoil control, burst accuracy, sustained fire

**Proficiency Progression**:
- Gains XP through weapon usage (hits, kills, successful actions)
- Each 10 levels reduces weapon-specific penalties by 5%
- Unlocks special abilities at 25, 50, 75, 100 proficiency
- Available stat points earned through leveling can boost proficiencies

### 6.1.2 Survivability Stats (Academic Compliance)

**Core Survivability Metrics** (0-100 scale, decay over time):
- **Nourishment Level**: Affects health regeneration, stamina recovery, accuracy penalties
  - Decays 1 point per hour of gameplay
  - Restored through food items with varying efficiency
  - Below 25: accuracy -15%, stamina recovery -25%

- **Sleep Level**: Affects reaction time, weapon sway, perception range
  - Decays 2 points per hour of gameplay
  - Restored through safe zone rest mechanics
  - Below 25: weapon sway +20%, perception range -30%

**Survivability Impact on Gameplay**:
- Well-fed and rested characters perform at peak efficiency
- Neglecting survivability creates cascading performance penalties
- Emergency consumables provide temporary boosts but don't replace proper rest/nutrition

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

- **users**(user_id PK, email UNIQUE, password_hash, display_name, created_at, email_verified BOOLEAN DEFAULT FALSE, verification_token VARCHAR(255) NULL, reset_token VARCHAR(255) NULL, reset_token_expires TIMESTAMP NULL, last_login TIMESTAMP NULL)

- **characters**(character_id PK, user_id FK, name UNIQUE, level, xp, strength, dexterity, agility, endurance, accuracy, money, melee_knives INT DEFAULT 0, melee_axes_clubs INT DEFAULT 0, firearm_handguns INT DEFAULT 0, firearm_rifles INT DEFAULT 0, firearm_shotguns INT DEFAULT 0, firearm_automatics INT DEFAULT 0, nourishment_level FLOAT DEFAULT 100.0, sleep_level FLOAT DEFAULT 100.0, available_stat_points INT DEFAULT 0)
    
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

- **character_progression**(progression_id PK, character_id FK, skill_type ENUM('melee_knives','melee_axes_clubs','firearm_handguns','firearm_rifles','firearm_shotguns','firearm_automatics'), xp_gained INT, level_achieved INT, timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP)

- **audit_logs**(log_id PK, user_id FK NULL, action VARCHAR(255), resource VARCHAR(100), resource_id INT NULL, ip_address INET NULL, user_agent TEXT NULL, timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP, success BOOLEAN DEFAULT TRUE)

- **orders**(request_id UUID PK, user_id FK, item_id FK, quantity INT, price DECIMAL(10,2), order_type ENUM('buy','sell'), created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, completed BOOLEAN DEFAULT FALSE)


**Sample data**: seed ≥100 items and ≥50 NPC templates; market seeded with one outpost.

---

## 10) REST API (explicit routes)

**Auth**: `POST /auth/register`, `POST /auth/login` → JWT  
**Characters**: `GET /characters`, `POST /characters`, `PATCH /characters/:id`  
**Inventory**: `GET /inventory/:character_id`, `POST /inventory/equip`, `POST /inventory/unequip`  
**Market**: `GET /market?settlement_id=&type=&q=`, `POST /market/buy`, `POST /market/sell` (atomic transactions)  
**Zones/NPC**: `GET /zones`, `GET /npcs?zone_id=` (for debug tools)  
**Sessions/Combat**: `POST /sessions`, `POST /combat/log`, `POST /sessions/:id/finish`  
**Leaderboards**: `GET /leaderboard?scope=`  
**Admin**: `POST /admin/items/upload`, `POST /admin/events`, `DELETE /admin/item/:id`

**Security**: bcrypt password hashing, JWT expiry/refresh, rate limit, **parameterized SQL** only, safe error messages.

### 10.1) Enhanced Authentication & Character API (Academic Compliance)

**Additional Auth Endpoints Required**:
- `GET /auth/check-username/:username` → real-time username availability validation
- `POST /auth/request-reset` → trigger password reset email with secure token
- `POST /auth/confirm-reset` → confirm password reset using token validation
- `POST /auth/verify-email` → confirm email verification with token
- `GET /auth/resend-verification` → resend email verification token
- `POST /auth/validate-password` → validate password strength requirements
- `POST /auth/refresh` → refresh JWT tokens securely

**Enhanced Character Management Endpoints**:
- `POST /characters/:id/allocate-stats` → allocate available stat points on level-up
- `GET /characters/:id/progression` → retrieve weapon proficiencies and survivability stats
- `PATCH /characters/:id/proficiency` → update weapon skill progression
- `POST /characters/:id/survivability` → update nourishment/sleep levels

**Password Requirements**: 8+ characters, mixed case, numbers, symbols, dictionary word check
**Email Verification**: Required before character creation, token expires in 24h
**Rate Limiting**: Auth endpoints 5/min per IP, general endpoints 100/min per IP
**Audit Logging**: All auth events, failed attempts, password changes logged securely

### 10.2) Server Authority & Idempotency (Academic Compliance)

**Hybrid Authority Model**:
- **Client-Authoritative**: Position, progression, UI state (offline queue for sync)
- **Server-Authoritative**: Currency, inventory, market transactions (immediate validation)

**Idempotency Requirements**:
- All state-changing endpoints require `X-Request-Id: <uuid>` header
- Market transactions use: `INSERT ... ON CONFLICT (request_id) DO NOTHING RETURNING *`
- Short transactions with `SELECT ... FOR UPDATE` on balances/stock

**API Testing Standards**:
- API-only ZAP scanning (no client headers controllable on itch.io)
- Parameterized SQL enforcement
- SQLi/XSS probe validation
- 25-request chaos testing for double-spend prevention

---

## 11) Testing plan (automation‑first)

- **Unit (Godot/GUT)**: FSM transitions, Ballistics math, DamageModel, Perception cones, Inventory weight math.
    
- **API (pytest/vitest)**: auth happy/sad paths, market atomicity, SQLi probes everywhere, price rules.
    
- **Integration**: buy→inventory sync; combat→combat_log; event→price change.
    
- **Functional (hosted)**: full playthrough on hosted build; save/continue; difficulty modes.
    
- **Accessibility**: key remap, high‑contrast, captions/visual cues.
    
- **Security**: ZAP baseline; JWT misuse; CORS; rate‑limit enforcement.


### 11.1 Enhanced Security Requirements (Academic Compliance)

**Authentication Security**:
- **Password Requirements**: Minimum 8 characters, complexity validation, strength meter
- **JWT Security**: Short expiry (15 min), secure refresh tokens (7 days), rotation on use
- **Email Verification**: Mandatory verification before login, secure token generation (256-bit)
- **Password Reset**: Time-limited tokens (1 hour), single-use validation, secure delivery
- **Rate Limiting**: Login attempts (5/10min), API calls (100/min), registration (3/day)

**Database Security**:
- **SQL Injection Prevention**: Parameterized queries only, input sanitization, ORM safety
- **Data Encryption**: bcrypt for passwords (cost 12+), sensitive data encryption at rest
- **Audit Logging**: All authentication events, failed attempts, privilege escalations
- **Connection Security**: SSL/TLS only, connection pooling, prepared statements

**API Security**:
- **CORS Configuration**: Strict origin controls, credential handling, preflight validation
- **Input Validation**: Server-side validation, sanitization, type checking, length limits
- **Error Handling**: Secure error messages, no information leakage, consistent responses
- **Security Headers**: HSTS, CSP, X-Frame-Options, X-Content-Type-Options

**Session Management**:
- **Token Security**: Secure storage, automatic expiry, revocation capability
- **Concurrent Sessions**: Multi-device support, session invalidation, activity tracking
- **CSRF Protection**: Token validation, same-site cookies, double-submit patterns
- **Device Tracking**: Fingerprinting, suspicious activity detection, notification system
    

**Acceptance criteria** (pass/fail evidence):

- Hosted build URL + API URL by **Milestone 2**.
    
- 60 FPS desktop with ≥20 active NPCs in a wave.
    
- Save/continue works across sessions.
    
- Market price reacts to at least one event (attack/shortage).
    
- SQLi/XSS tests pass; accessibility checks logged.

- By M2: hosted HTML5 build URL + live API URL published; smoke tests run against hosted build.

- CI artifact: test report includes SQLi/XSS checks + accessibility notes.


---

## 12) Deployment & CI/CD

- **Client hosting**: itch.io (HTML5 **REQUIRED for capstone**) Project page acts as canonical subdomain.
    
- **API host**: Render (or Railway) + Dockerfile, healthcheck.
    
- **DB**: Neon or Supabase (managed Postgres); weekly snapshots; `.sql` dumps in repo artifacts.
    
- **CI**: GitHub Actions exports Godot HTML5 + desktop, runs tests, deploys API.

- **Access URLs**: <itch.io game URL>, <API base URL>.

- **Cost (3 months)**: itch.io: $0; Render free tier: $0; Neon/Supabase free tier: $0–$9 depending on usage.

- **Milestone gate**: By M2, live HTML5 build + live API (both URLs in README).

### 12.1 itch.io Hosting Constraints (Academic Compliance)

**Authentication Approach**: Bearer JWT in `Authorization` headers (cookies won't work in third-party iframe)

**Security Headers**: API enforces CSP + CORS allowlist; client headers not controllable on itch.io

**Performance Gates**: Bundle ≤ 25 MB, TTFF ≤ 5s (Playwright measured), HTML5 ≥30 FPS goal with 5 NPCs

**Testing Strategy**: API-only ZAP scanning; client testing via Playwright automation


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
    
### 16.1 Mobile-First UI (Godot)

- **Layout**: Control-node containers (VBox/HBox/Grid/Tab/Panel), anchors/margins for scaling.

- **Breakpoints**: use DisplayServer.screen_get_size() to select HUD variants.

- **Touch**: larger hitboxes (>= 44 px), on-screen sticks/buttons via TouchScreenButton.

- **Accessibility**: high-contrast theme, font scaling, color-blind palettes, narration hooks.

- **Performance**: CanvasItem batching, compressed textures, lower shadow resolution on mobile.

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
    

  

## 14) Error Handling & Logging (Academic Compliance)

### 14.1 Client-Side Error Handling

**Godot Error Management**:
- **Scene Errors**: Graceful fallbacks for missing scenes, corrupted saves, network failures
- **Resource Loading**: Retry mechanisms, fallback assets, user feedback for loading failures
- **Input Validation**: Client-side validation with server-side verification, error state management
- **Network Errors**: Connection timeouts, retry logic, offline mode with queue synchronization

**User Experience**:
- **Error Messages**: User-friendly error descriptions, actionable recovery steps
- **Progress Feedback**: Loading indicators, operation status, timeout notifications
- **State Recovery**: Auto-save mechanisms, crash recovery, session restoration
- **Fallback Systems**: Offline mode, cached data usage, graceful degradation

### 14.2 Server-Side Error Handling

**API Error Management**:
- **Request Validation**: Input sanitization, type checking, business rule validation
- **Database Errors**: Connection failures, constraint violations, transaction rollbacks
- **Authentication Errors**: Token validation, permission checks, rate limiting responses
- **External Service Errors**: Third-party API failures, email service outages, backup providers

**Error Response Standards**:
- **HTTP Status Codes**: Consistent usage (400 Bad Request, 401 Unauthorized, 403 Forbidden, 500 Internal Server Error)
- **Error Payloads**: Structured error objects with error codes, messages, and context
- **Security Considerations**: No sensitive information leakage, consistent error timing
- **Logging Integration**: Correlated error IDs, structured logging, alerting thresholds

### 14.3 Comprehensive Logging Strategy

**Application Logging**:
- **Log Levels**: DEBUG, INFO, WARN, ERROR, FATAL with appropriate usage
- **Structured Logging**: JSON format, consistent field naming, searchable attributes
- **Context Preservation**: Request IDs, user IDs, session tracking, operation correlation
- **Performance Logging**: Response times, resource usage, bottleneck identification

**Security & Audit Logging**:
- **Authentication Events**: Login attempts, password changes, token usage, failures
- **Authorization Events**: Permission checks, role changes, access denials
- **Data Access**: Sensitive data queries, exports, modifications, deletions
- **System Events**: Configuration changes, user management, privilege escalations

**Log Management**:
- **Retention Policies**: 90 days for debug logs, 1 year for audit logs, permanent for security incidents
- **Storage Strategy**: Local files for development, centralized logging for production
- **Monitoring Integration**: Real-time alerting, dashboard metrics, trend analysis
- **Privacy Compliance**: PII masking, data anonymization, compliance reporting

## 15) Data Integrity & Validation (Academic Compliance)

### 15.1 Input Validation Framework

**Client-Side Validation**:
- **Form Validation**: Real-time input validation, pattern matching, length constraints
- **Type Safety**: Type checking for all user inputs, numeric range validation
- **Format Validation**: Email formats, password complexity, username patterns
- **User Feedback**: Immediate validation feedback, clear error messages, guided correction

**Server-Side Validation**:
- **Comprehensive Validation**: Re-validate all client inputs on server-side
- **Business Rule Enforcement**: Game rules, economic constraints, logical consistency
- **SQL Injection Prevention**: Parameterized queries only, input sanitization
- **Data Sanitization**: HTML encoding, special character handling, XSS prevention

### 15.2 Database Integrity

**Referential Integrity**:
- **Foreign Key Constraints**: Enforce relationships between tables, cascade rules
- **Check Constraints**: Business rule enforcement at database level
- **Unique Constraints**: Prevent duplicate data, ensure data quality
- **Not Null Constraints**: Required field enforcement, data completeness

**Transaction Management**:
- **ACID Compliance**: Atomicity, Consistency, Isolation, Durability for all operations
- **Transaction Boundaries**: Proper transaction scoping, rollback strategies
- **Deadlock Handling**: Deadlock detection, retry mechanisms, timeout management
- **Consistency Checks**: Data validation across related tables, integrity verification

### 15.3 Data Validation Layers

**API Layer Validation**:
- **Request Validation**: Schema validation, required field checking, format verification
- **Authentication Validation**: Token verification, permission checking, rate limiting
- **Business Logic Validation**: Game rule enforcement, economic constraints
- **Response Validation**: Ensure data consistency in API responses

**Database Layer Validation**:
- **Constraint Enforcement**: Primary keys, foreign keys, unique constraints, check constraints
- **Trigger Validation**: Complex business rule enforcement via database triggers
- **Data Type Enforcement**: Strict typing, range validation, enum constraints
- **Audit Trail**: Change tracking, version control, modification history

**Application Layer Validation**:
- **Model Validation**: Object-level validation, relationship validation
- **Service Layer Validation**: Business logic validation, cross-service consistency
- **Integration Validation**: External API data validation, third-party service responses
- **Cache Validation**: Data consistency between cache and database

## 16) Implementation Timeline: 4-Gate Approach

**Goal**: Pragmatic milestone-based development optimized for AI agent + human collaboration, with hosted validation at each gate.

### Gate 1 — Foundation (≈1 week)

**Goal**: Ship a blank, hosted HTML5 build with CI/CD, API, DB, and security testing.

**AI Agent Tasks**:
- Godot project scaffold; export presets (HTML5 + desktop)
- CI: run tests → export HTML5 → deploy client; build & deploy API (Render/Railway) with `/health`, `/version`
- PostgreSQL (Neon/Supabase); migrations wired; OpenAPI auto-gen at `/openapi.json`
- **itch.io Auth**: Bearer JWT in `Authorization` headers (no cookies in iframe)
- **Security**: API-only ZAP baseline, parameterized SQL, CORS allowlist
- **Performance Gates**: Bundle ≤ 25 MB; Playwright TTFF probe
- Test harness baseline (GUT/pytest)

**Human Tasks**:
- Art direction: moodboard, palette, font candidates, UI wireframes
- Asset budget sheet: triangle/texture budgets for HTML5
- Placeholder kit list: proxy character, weapon, UI sprites

**Pass = Ship**:
- Hosted HTML5 URL loads (Chrome/Edge); API `/health` green; CI green on push
- Auth = Bearer JWT documented; no cookie dependencies on itch.io
- CI bundle gate enforces ≤ 25 MB; Playwright logs baseline TTFF
- ZAP API report attached with no High severity findings

### Gate 2 — Core Loop (≈1–1.5 weeks)

**Goal**: A fun graybox loop you can resume later—all code/data, minimal art.

**AI Agent Tasks**:
- TPS rig + camera; Basic Zombie (capsule + navmesh); hitscan pistol; health HUD
- **Client-auth saves**: position/progression (offline queue with deterministic IDs)
- **Accessibility (early)**: input remap + font scaling + captions toggle
- Basic inventory: equip/unequip, durability; seed 20 items
- **Performance monitoring**: in-game sampler posts FPS/memory report to API after 60s

**Human Tasks**:
- Wireframes → first-pass HUD/mock screens (grayscale)
- Character silhouette exploration (blockouts)
- Sound palette sketches

**Pass = Ship**:
- From hosted build: login → play → quit → continue later (client state intact)
- ≥60 FPS desktop; **≥30 FPS HTML5 goal** with 5 NPCs (accept 25-30 on low-end)
- OpenAPI reachable; performance report received by API
- Input remap, font scaling, captions functional

### Gate 3 — Features (≈1–1.5 weeks)

**Goal**: Market works atomically and responds to events; zones/perception in place.

**AI Agent Tasks**:
- Safe/hostile zones; spawn volumes; vision/hearing perception
- **Server-auth market**: currency/inventory only (hybrid authority)
- **Idempotent buy/sell**: `X-Request-Id` header, `orders(request_id uuid PRIMARY KEY)`, `INSERT ... ON CONFLICT (request_id) DO NOTHING RETURNING *`
- Settlement resource signal → price curve change (scripted event)
- **Security validation**: SQLi/XSS probes, ZAP report attached

**Human Tasks**:
- HUD first-pass visuals (typography, spacing, icon placeholders)
- Temp character selection (Mixamo/proxy route)
- Color-blind palette verification

**Pass = Ship**:
- Hosted demo shows event-driven price shift
- **No double-spend** under 25-request chaos test
- ZAP API report: no High severity findings
- Market transactions idempotent and atomic

### Gate 4 — Polish (≈1 week)

**Goal**: Production-ready academic submission with visual cohesion.

**AI Agent Tasks**:
- Difficulty presets; XP/level-up affecting gameplay
- Error handling & offline queue robustness
- Desktop export presets finalized
- **CI provenance bundle**: URLs, commit SHA, OpenAPI hash, performance reports

**Human Tasks**:
- Aesthetic pass: palette locked, HUD icons, minimal environment
- Accessibility polish: high-contrast verification, controller support
- Final presentation assets; gameplay capture from hosted build

**Pass = Ship**:
- Visual consistency maintained; accessibility standards met
- Performance thresholds achieved: bundle ≤ 25 MB, TTFF ≤ 5s, stable 30 FPS
- All acceptance criteria satisfied from hosted build
- Academic deliverables complete with evidence

## 17) Hybrid Authority Architecture

**Design Principle**: Client-authoritative for low-risk data, server-authoritative for economic data.

### Client-Authoritative (Offline Queue)
- **Position/Movement**: Player location, rotation, camera state
- **Progression**: XP gains, skill improvements, cosmetic unlocks
- **UI State**: Settings, preferences, tutorial progress
- **Implementation**: `Save.gd` queues events with deterministic IDs for API sync

### Server-Authoritative (Immediate Validation)
- **Currency**: All money transactions, balance validation
- **Inventory**: Item ownership, transfers, market transactions
- **Market**: Buy/sell operations, price calculations
- **Implementation**: API validates and processes; client receives authoritative state

### Idempotency Pattern (Market Only)
```javascript
// Client sends:
headers: { 'X-Request-Id': crypto.randomUUID() }

// API implements:
INSERT INTO orders (request_id, user_id, item_id, quantity, price)
VALUES ($1, $2, $3, $4, $5)
ON CONFLICT (request_id) DO NOTHING
RETURNING *;
```

### **What you still need to decide (you can leave these as defaults for now)**

- Pick a **default perspective** for Milestone 2 polish (rigs are swappable during dev).

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