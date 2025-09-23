-- Comprehensive seed data for Dizzy's Disease - Academic Compliance
-- Ensures ≥150 rows across items, NPC templates, markets, and events

-- Add missing columns for weapon proficiencies and survivability stats (§9 Academic Compliance)
ALTER TABLE characters
ADD COLUMN IF NOT EXISTS melee_knives INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS melee_axes_clubs INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS firearm_handguns INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS firearm_rifles INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS firearm_shotguns INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS firearm_automatics INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS nourishment_level FLOAT DEFAULT 100.0,
ADD COLUMN IF NOT EXISTS sleep_level FLOAT DEFAULT 100.0,
ADD COLUMN IF NOT EXISTS available_stat_points INT DEFAULT 0;

-- Add missing progression and audit tables
CREATE TABLE IF NOT EXISTS character_progression (
  progression_id SERIAL PRIMARY KEY,
  character_id INT NOT NULL REFERENCES characters(character_id) ON DELETE CASCADE,
  skill_type TEXT NOT NULL CHECK (skill_type IN ('melee_knives','melee_axes_clubs','firearm_handguns','firearm_rifles','firearm_shotguns','firearm_automatics')),
  xp_gained INT NOT NULL,
  level_achieved INT NOT NULL,
  timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS audit_logs (
  log_id SERIAL PRIMARY KEY,
  user_id INT REFERENCES users(user_id) ON DELETE SET NULL,
  action VARCHAR(255) NOT NULL,
  resource VARCHAR(100) NOT NULL,
  resource_id INT,
  ip_address INET,
  user_agent TEXT,
  timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  success BOOLEAN DEFAULT TRUE
);

-- Comprehensive Items (100+ items for specification compliance)
INSERT INTO items(name, type, slot_size, weight, durability_max, armor_dr, damage, noise, noise_radius) VALUES

-- Melee Weapons - Knives (12 items)
('Combat Knife', 'weapon', 1, 0.5, 150, NULL, 15, 10, 5),
('Survival Knife', 'weapon', 1, 0.4, 120, NULL, 12, 8, 4),
('Tactical Knife', 'weapon', 1, 0.6, 180, NULL, 18, 12, 6),
('Hunting Knife', 'weapon', 1, 0.7, 140, NULL, 16, 9, 5),
('Machete', 'weapon', 2, 1.2, 200, NULL, 22, 15, 8),
('Bayonet', 'weapon', 1, 0.8, 160, NULL, 17, 11, 6),
('Stiletto', 'weapon', 1, 0.3, 90, NULL, 20, 6, 3),
('Bowie Knife', 'weapon', 1, 0.9, 170, NULL, 19, 13, 7),
('Throwing Knife', 'weapon', 1, 0.2, 80, NULL, 14, 5, 3),
('Cleaver', 'weapon', 1, 1.1, 130, NULL, 21, 14, 7),
('Scalpel', 'weapon', 1, 0.1, 60, NULL, 25, 3, 2),
('Switchblade', 'weapon', 1, 0.3, 100, NULL, 13, 7, 4),

-- Melee Weapons - Axes/Clubs (12 items)
('Fire Axe', 'weapon', 2, 2.5, 250, NULL, 35, 25, 15),
('Hatchet', 'weapon', 1, 1.0, 180, NULL, 24, 18, 10),
('Baseball Bat', 'weapon', 2, 1.8, 200, NULL, 28, 20, 12),
('Crowbar', 'weapon', 2, 2.0, 300, NULL, 26, 22, 13),
('Sledgehammer', 'weapon', 3, 4.0, 400, NULL, 45, 35, 20),
('Pipe Wrench', 'weapon', 2, 1.5, 220, NULL, 23, 19, 11),
('Pickaxe', 'weapon', 2, 2.8, 280, NULL, 32, 28, 16),
('Tomahawk', 'weapon', 1, 0.8, 160, NULL, 27, 16, 9),
('Club', 'weapon', 1, 1.2, 150, NULL, 20, 15, 8),
('Mace', 'weapon', 2, 2.2, 240, NULL, 30, 24, 14),
('War Hammer', 'weapon', 2, 3.0, 320, NULL, 38, 30, 17),
('Spiked Club', 'weapon', 1, 1.4, 170, NULL, 25, 17, 9),

-- Handguns (12 items)
('9mm Pistol', 'weapon', 1, 1.2, 120, NULL, 22, 45, 80),
('.45 ACP Pistol', 'weapon', 1, 1.4, 140, NULL, 28, 50, 90),
('Revolver .357', 'weapon', 1, 1.6, 200, NULL, 35, 60, 110),
('Compact Pistol', 'weapon', 1, 0.8, 100, NULL, 18, 40, 70),
('Heavy Pistol', 'weapon', 1, 1.8, 160, NULL, 32, 55, 100),
('Tactical Pistol', 'weapon', 1, 1.3, 130, NULL, 25, 48, 85),
('Silenced Pistol', 'weapon', 1, 1.5, 110, NULL, 20, 15, 25),
('Desert Eagle', 'weapon', 1, 2.0, 180, NULL, 40, 65, 120),
('.22 Pistol', 'weapon', 1, 0.6, 90, NULL, 12, 30, 50),
('Flare Gun', 'weapon', 1, 1.0, 80, NULL, 8, 20, 200),
('Sawed-off Pistol', 'weapon', 1, 0.9, 70, NULL, 15, 35, 60),
('Competition Pistol', 'weapon', 1, 1.1, 150, NULL, 24, 42, 75),

-- Rifles (12 items)
('Hunting Rifle', 'weapon', 3, 3.5, 180, NULL, 55, 80, 300),
('Sniper Rifle', 'weapon', 3, 4.2, 200, NULL, 85, 90, 400),
('Assault Rifle', 'weapon', 2, 2.8, 150, NULL, 40, 70, 250),
('Battle Rifle', 'weapon', 3, 3.8, 190, NULL, 60, 75, 320),
('Carbine', 'weapon', 2, 2.2, 130, NULL, 35, 65, 200),
('Marksman Rifle', 'weapon', 3, 3.2, 170, NULL, 50, 72, 280),
('Scout Rifle', 'weapon', 2, 2.5, 140, NULL, 45, 68, 220),
('Precision Rifle', 'weapon', 3, 4.0, 210, NULL, 75, 85, 350),
('Semi-Auto Rifle', 'weapon', 2, 2.9, 160, NULL, 42, 66, 240),
('Lever Action', 'weapon', 3, 3.0, 220, NULL, 48, 60, 260),
('Bolt Action', 'weapon', 3, 3.4, 240, NULL, 65, 78, 310),
('DMR', 'weapon', 3, 3.6, 175, NULL, 52, 74, 290),

-- Shotguns (12 items)
('Pump Shotgun', 'weapon', 2, 3.0, 160, NULL, 65, 85, 150),
('Double Barrel', 'weapon', 2, 2.8, 180, NULL, 75, 90, 160),
('Semi-Auto Shotgun', 'weapon', 2, 3.2, 140, NULL, 60, 80, 140),
('Sawed-off Shotgun', 'weapon', 1, 2.0, 120, NULL, 50, 70, 100),
('Combat Shotgun', 'weapon', 2, 3.4, 170, NULL, 70, 88, 155),
('Tactical Shotgun', 'weapon', 2, 3.1, 150, NULL, 62, 82, 145),
('Hunting Shotgun', 'weapon', 2, 2.9, 200, NULL, 68, 75, 130),
('Breacher Shotgun', 'weapon', 1, 2.5, 130, NULL, 55, 95, 120),
('Automatic Shotgun', 'weapon', 2, 3.6, 120, NULL, 58, 92, 165),
('Compact Shotgun', 'weapon', 1, 2.2, 110, NULL, 45, 65, 90),
('Slug Shotgun', 'weapon', 2, 3.3, 190, NULL, 80, 85, 170),
('Riot Shotgun', 'weapon', 2, 3.5, 175, NULL, 72, 87, 158),

-- Automatic Weapons (12 items)
('SMG', 'weapon', 2, 2.0, 120, NULL, 25, 60, 180),
('Assault SMG', 'weapon', 2, 2.3, 130, NULL, 28, 65, 190),
('PDW', 'weapon', 1, 1.5, 100, NULL, 22, 55, 160),
('Machine Pistol', 'weapon', 1, 1.8, 90, NULL, 20, 50, 150),
('Tactical SMG', 'weapon', 2, 2.1, 140, NULL, 30, 68, 200),
('Compact SMG', 'weapon', 1, 1.4, 110, NULL, 24, 58, 170),
('Heavy SMG', 'weapon', 2, 2.5, 150, NULL, 32, 70, 210),
('Silenced SMG', 'weapon', 2, 2.2, 120, NULL, 26, 25, 80),
('Burst SMG', 'weapon', 2, 1.9, 125, NULL, 27, 62, 185),
('Micro SMG', 'weapon', 1, 1.2, 85, NULL, 18, 45, 140),
('Combat SMG', 'weapon', 2, 2.4, 135, NULL, 29, 67, 195),
('Special SMG', 'weapon', 2, 2.6, 145, NULL, 31, 72, 205),

-- Armor (15 items)
('Leather Jacket', 'armor', 2, 2.0, 80, 15, NULL, 0, 0),
('Sports Armor', 'armor', 3, 3.5, 100, 30, NULL, 0, 0),
('Tactical Vest', 'armor', 2, 2.5, 120, 25, NULL, 0, 0),
('Combat Armor', 'armor', 4, 5.0, 200, 45, NULL, 0, 0),
('Riot Gear', 'armor', 4, 6.0, 180, 40, NULL, 0, 0),
('Military Vest', 'armor', 3, 4.0, 160, 35, NULL, 0, 0),
('Kevlar Vest', 'armor', 2, 3.0, 140, 32, NULL, 0, 0),
('Plate Carrier', 'armor', 3, 4.5, 220, 50, NULL, 0, 0),
('Light Armor', 'armor', 2, 2.2, 90, 20, NULL, 0, 0),
('Heavy Armor', 'armor', 5, 8.0, 300, 60, NULL, 0, 0),
('Stealth Suit', 'armor', 2, 1.8, 70, 12, NULL, 0, 0),
('Hazmat Suit', 'armor', 3, 3.8, 110, 18, NULL, 0, 0),
('Reinforced Vest', 'armor', 3, 4.2, 170, 38, NULL, 0, 0),
('Padded Jacket', 'armor', 2, 2.8, 60, 10, NULL, 0, 0),
('Power Armor', 'armor', 6, 12.0, 500, 80, NULL, 0, 0),

-- Consumables (15 items)
('Small Medkit', 'consumable', 1, 0.5, 1, NULL, NULL, 0, 0),
('Large Medkit', 'consumable', 2, 1.2, 1, NULL, NULL, 0, 0),
('Bandage', 'consumable', 1, 0.2, 1, NULL, NULL, 0, 0),
('Painkillers', 'consumable', 1, 0.1, 1, NULL, NULL, 0, 0),
('Stimpak', 'consumable', 1, 0.3, 1, NULL, NULL, 0, 0),
('Energy Drink', 'consumable', 1, 0.4, 1, NULL, NULL, 0, 0),
('MRE', 'consumable', 1, 1.0, 1, NULL, NULL, 0, 0),
('Water Bottle', 'consumable', 1, 0.5, 1, NULL, NULL, 0, 0),
('Protein Bar', 'consumable', 1, 0.2, 1, NULL, NULL, 0, 0),
('Vitamins', 'consumable', 1, 0.1, 1, NULL, NULL, 0, 0),
('Emergency Ration', 'consumable', 1, 0.8, 1, NULL, NULL, 0, 0),
('Electrolyte Drink', 'consumable', 1, 0.4, 1, NULL, NULL, 0, 0),
('Field Ration', 'consumable', 1, 0.9, 1, NULL, NULL, 0, 0),
('Coffee', 'consumable', 1, 0.2, 1, NULL, NULL, 0, 0),
('Adrenaline', 'consumable', 1, 0.1, 1, NULL, NULL, 0, 0)

ON CONFLICT (name) DO NOTHING;

-- Additional Settlements (5 total)
INSERT INTO settlements(name, population, resource_food, resource_ammo, resource_med) VALUES
('Fort Haven', 45, 150, 200, 50),
('New Eden', 32, 80, 90, 25),
('Sanctuary Hills', 28, 120, 110, 35),
('The Bunker', 55, 200, 300, 80)
ON CONFLICT (name) DO NOTHING;

-- Comprehensive Market Data (populate all items across all settlements)
INSERT INTO market(settlement_id, item_id, current_price, qty_available)
SELECT
  s.settlement_id,
  i.item_id,
  CASE
    WHEN i.type = 'weapon' AND i.damage > 50 THEN 250 + (i.damage * 3)
    WHEN i.type = 'weapon' AND i.damage > 30 THEN 150 + (i.damage * 2)
    WHEN i.type = 'weapon' THEN 50 + i.damage
    WHEN i.type = 'armor' AND i.armor_dr > 40 THEN 200 + (i.armor_dr * 4)
    WHEN i.type = 'armor' THEN 100 + (i.armor_dr * 2)
    WHEN i.type = 'consumable' THEN 25
    ELSE 15
  END as current_price,
  CASE
    WHEN i.type = 'weapon' AND i.damage > 50 THEN 1 + (random() * 3)::int
    WHEN i.type = 'weapon' THEN 3 + (random() * 7)::int
    WHEN i.type = 'armor' THEN 2 + (random() * 5)::int
    WHEN i.type = 'consumable' THEN 10 + (random() * 20)::int
    ELSE 5 + (random() * 15)::int
  END as qty_available
FROM settlements s
CROSS JOIN items i
WHERE i.name != 'Pistol' AND i.name != 'Ammo' AND i.name != 'Medkit'
ON CONFLICT DO NOTHING;

-- Zone Data (10 zones total)
INSERT INTO zones(settlement_id, type, noise_radius) VALUES
(1, 'safe', 0),      -- Outpost One safe zone
(1, 'hostile', 100), -- Outpost One hostile zone
(2, 'safe', 0),      -- Fort Haven safe zone
(2, 'hostile', 120),
(3, 'safe', 0),      -- New Eden safe zone
(3, 'hostile', 80),
(4, 'safe', 0),      -- Sanctuary Hills safe zone
(4, 'hostile', 90),
(5, 'safe', 0),      -- The Bunker safe zone
(5, 'hostile', 150)
ON CONFLICT DO NOTHING;

-- NPC Templates (50+ templates for specification compliance)
INSERT INTO npcs(zone_id, type, health, strength, agility, perception_visual, perception_hearing) VALUES
-- Basic Zombies (variety of stats)
(2, 'Zombie_Basic', 50, 2, 2, 10, 12),
(2, 'Zombie_Basic', 45, 1, 3, 12, 10),
(2, 'Zombie_Basic', 60, 3, 1, 8, 15),
(2, 'Zombie_Basic', 55, 2, 2, 11, 11),
(2, 'Zombie_Basic', 40, 1, 4, 15, 8),
(4, 'Zombie_Basic', 52, 2, 2, 9, 13),
(4, 'Zombie_Basic', 48, 2, 3, 13, 9),
(4, 'Zombie_Basic', 58, 3, 1, 7, 16),
(6, 'Zombie_Basic', 46, 1, 3, 14, 10),
(6, 'Zombie_Basic', 54, 2, 2, 10, 12),

-- Ranger Zombies (acid spitters)
(2, 'Zombie_Ranger', 75, 2, 3, 15, 14),
(2, 'Zombie_Ranger', 70, 2, 4, 18, 12),
(2, 'Zombie_Ranger', 80, 3, 2, 12, 16),
(4, 'Zombie_Ranger', 72, 2, 3, 16, 13),
(4, 'Zombie_Ranger', 78, 3, 3, 14, 15),
(6, 'Zombie_Ranger', 74, 2, 4, 17, 11),
(6, 'Zombie_Ranger', 76, 2, 3, 13, 17),
(8, 'Zombie_Ranger', 73, 2, 3, 15, 14),
(8, 'Zombie_Ranger', 77, 3, 2, 11, 18),
(10, 'Zombie_Ranger', 75, 2, 4, 19, 12),

-- Alarm Zombies (horde callers)
(2, 'Zombie_Alarm', 65, 2, 2, 12, 20),
(2, 'Zombie_Alarm', 60, 1, 3, 15, 18),
(4, 'Zombie_Alarm', 70, 2, 2, 10, 22),
(4, 'Zombie_Alarm', 62, 2, 3, 14, 19),
(6, 'Zombie_Alarm', 68, 2, 2, 11, 21),
(6, 'Zombie_Alarm', 64, 1, 3, 16, 17),
(8, 'Zombie_Alarm', 66, 2, 2, 13, 20),
(8, 'Zombie_Alarm', 69, 2, 3, 9, 23),
(10, 'Zombie_Alarm', 67, 2, 2, 12, 21),
(10, 'Zombie_Alarm', 63, 1, 3, 17, 18),

-- Heavy Zombies (armored)
(2, 'Zombie_Heavy', 120, 4, 1, 8, 10),
(2, 'Zombie_Heavy', 115, 4, 1, 10, 8),
(4, 'Zombie_Heavy', 130, 5, 1, 6, 12),
(4, 'Zombie_Heavy', 125, 4, 2, 9, 9),
(6, 'Zombie_Heavy', 118, 4, 1, 11, 7),
(6, 'Zombie_Heavy', 135, 5, 1, 7, 11),
(8, 'Zombie_Heavy', 122, 4, 1, 8, 10),
(8, 'Zombie_Heavy', 128, 4, 2, 10, 8),
(10, 'Zombie_Heavy', 132, 5, 1, 6, 13),
(10, 'Zombie_Heavy', 127, 4, 1, 9, 9),

-- Big Zombies (large targets)
(2, 'Zombie_Big', 200, 6, 1, 5, 8),
(2, 'Zombie_Big', 190, 5, 2, 7, 6),
(4, 'Zombie_Big', 210, 6, 1, 4, 10),
(4, 'Zombie_Big', 195, 5, 2, 8, 5),
(6, 'Zombie_Big', 185, 5, 2, 9, 4),
(6, 'Zombie_Big', 205, 6, 1, 3, 12),
(8, 'Zombie_Big', 198, 5, 2, 6, 7),
(8, 'Zombie_Big', 215, 6, 1, 5, 9),
(10, 'Zombie_Big', 192, 5, 2, 10, 3),
(10, 'Zombie_Big', 208, 6, 1, 4, 11)
ON CONFLICT DO NOTHING;

-- Event Definitions for Dynamic Economy (20+ events)
INSERT INTO events(type, payload_json) VALUES
('OutpostAttacked', '{"severity": 3, "duration": 120, "affected_settlements": [1], "price_impact": {"weapons": 1.3, "ammo": 1.5, "armor": 1.2}}'),
('OutpostAttacked', '{"severity": 2, "duration": 90, "affected_settlements": [2], "price_impact": {"weapons": 1.2, "ammo": 1.3, "armor": 1.1}}'),
('OutpostAttacked', '{"severity": 1, "duration": 60, "affected_settlements": [3], "price_impact": {"weapons": 1.1, "ammo": 1.2, "armor": 1.05}}'),

('Shortage', '{"affected_item": "Ammo", "severity": 0.8, "duration": 180, "price_multiplier": 2.0, "settlements": [1,2]}'),
('Shortage', '{"affected_item": "Medkit", "severity": 0.6, "duration": 150, "price_multiplier": 1.8, "settlements": [2,3]}'),
('Shortage', '{"affected_item": "Weapons", "severity": 0.7, "duration": 200, "price_multiplier": 1.6, "settlements": [3,4]}'),
('Shortage', '{"affected_item": "Armor", "severity": 0.5, "duration": 120, "price_multiplier": 1.4, "settlements": [4,5]}'),

('ConvoyArrived', '{"cargo_size": 150, "trader_rep": 0.9, "price_reduction": 0.8, "affected_settlements": [1], "items": ["weapons", "ammo"]}'),
('ConvoyArrived', '{"cargo_size": 100, "trader_rep": 0.7, "price_reduction": 0.85, "affected_settlements": [2], "items": ["armor", "consumables"]}'),
('ConvoyArrived', '{"cargo_size": 200, "trader_rep": 1.0, "price_reduction": 0.75, "affected_settlements": [3], "items": ["weapons", "armor", "ammo"]}'),

('TradeRouteClear', '{"route_length": 25.5, "safety_bonus": 0.2, "duration": 300, "affected_settlements": [1,2], "price_stability": 1.1}'),
('TradeRouteClear', '{"route_length": 40.0, "safety_bonus": 0.3, "duration": 450, "affected_settlements": [2,3], "price_stability": 1.2}'),
('TradeRouteClear', '{"route_length": 15.0, "safety_bonus": 0.15, "duration": 200, "affected_settlements": [3,4], "price_stability": 1.05}'),

('Raider', '{"raider_count": 5, "threat_level": 0.7, "duration": 180, "affected_settlements": [1], "trade_disruption": 0.3}'),
('Raider', '{"raider_count": 8, "threat_level": 0.9, "duration": 240, "affected_settlements": [2], "trade_disruption": 0.5}'),
('Raider', '{"raider_count": 3, "threat_level": 0.4, "duration": 120, "affected_settlements": [4], "trade_disruption": 0.2}'),

('Settlement', '{"population_change": 12, "morale_boost": 0.3, "affected_settlements": [1], "economic_growth": 1.15}'),
('Settlement', '{"population_change": 8, "morale_boost": 0.2, "affected_settlements": [3], "economic_growth": 1.1}'),
('Settlement', '{"population_change": 15, "morale_boost": 0.4, "affected_settlements": [5], "economic_growth": 1.2}'),

('MarketCrash', '{"cause": "oversupply", "duration": 600, "price_impact": 0.6, "affected_items": ["weapons"], "settlements": [1,2,3]}'),
('MarketBoom', '{"cause": "high_demand", "duration": 400, "price_impact": 1.8, "affected_items": ["armor", "consumables"], "settlements": [2,3,4]}'),
('ResourceDiscovery', '{"resource_type": "medical", "quality": 0.9, "duration": 800, "price_impact": 0.7, "affected_items": ["consumables"], "settlements": [1,3,5]}'),
('TechAdvancement', '{"tech_type": "weapons", "efficiency": 1.3, "duration": 1200, "price_impact": 1.4, "affected_items": ["weapons"], "settlements": [2,4,5]}')
ON CONFLICT DO NOTHING;

-- Performance validation
SELECT
  'Items' as table_name, COUNT(*) as row_count FROM items
UNION ALL
SELECT 'NPCs', COUNT(*) FROM npcs
UNION ALL
SELECT 'Market entries', COUNT(*) FROM market
UNION ALL
SELECT 'Events', COUNT(*) FROM events
UNION ALL
SELECT 'Settlements', COUNT(*) FROM settlements
UNION ALL
SELECT 'Zones', COUNT(*) FROM zones
ORDER BY row_count DESC;