-- PostgreSQL schema for Dizzy's Disease (1-to-many relationships only)

CREATE TABLE IF NOT EXISTS users (
  user_id SERIAL PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  display_name TEXT NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS characters (
  character_id SERIAL PRIMARY KEY,
  user_id INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  name TEXT UNIQUE NOT NULL,
  level INT NOT NULL DEFAULT 1,
  xp INT NOT NULL DEFAULT 0,
  strength INT NOT NULL DEFAULT 1,
  dexterity INT NOT NULL DEFAULT 1,
  agility INT NOT NULL DEFAULT 1,
  endurance INT NOT NULL DEFAULT 1,
  accuracy INT NOT NULL DEFAULT 1,
  money INT NOT NULL DEFAULT 100,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS items (
  item_id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  type TEXT NOT NULL,
  slot_size INT NOT NULL DEFAULT 1,
  weight REAL NOT NULL DEFAULT 0,
  durability_max INT NOT NULL DEFAULT 100,
  armor_dr INT,
  damage INT,
  noise INT NOT NULL DEFAULT 0,
  noise_radius INT NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS inventories (
  inventory_id SERIAL PRIMARY KEY,
  character_id INT NOT NULL REFERENCES characters(character_id) ON DELETE CASCADE,
  item_id INT NOT NULL REFERENCES items(item_id) ON DELETE RESTRICT,
  quantity INT NOT NULL DEFAULT 1,
  durability_current INT NOT NULL DEFAULT 100
);

CREATE TABLE IF NOT EXISTS settlements (
  settlement_id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  population INT NOT NULL DEFAULT 20,
  resource_food INT NOT NULL DEFAULT 100,
  resource_ammo INT NOT NULL DEFAULT 120,
  resource_med INT NOT NULL DEFAULT 30
);

CREATE TABLE IF NOT EXISTS market (
  market_id SERIAL PRIMARY KEY,
  settlement_id INT NOT NULL REFERENCES settlements(settlement_id) ON DELETE CASCADE,
  item_id INT NOT NULL REFERENCES items(item_id) ON DELETE RESTRICT,
  current_price INT NOT NULL,
  qty_available INT NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS zones (
  zone_id SERIAL PRIMARY KEY,
  settlement_id INT REFERENCES settlements(settlement_id) ON DELETE SET NULL,
  type TEXT NOT NULL CHECK (type IN ('safe','hostile')),
  noise_radius INT NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS npcs (
  npc_id SERIAL PRIMARY KEY,
  zone_id INT NOT NULL REFERENCES zones(zone_id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  health INT NOT NULL DEFAULT 50,
  strength INT NOT NULL DEFAULT 1,
  agility INT NOT NULL DEFAULT 1,
  perception_visual INT NOT NULL DEFAULT 10,
  perception_hearing INT NOT NULL DEFAULT 10
);

CREATE TABLE IF NOT EXISTS sessions (
  session_id SERIAL PRIMARY KEY,
  user_id INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  started_at TIMESTAMP NOT NULL DEFAULT NOW(),
  finished_at TIMESTAMP,
  difficulty TEXT NOT NULL DEFAULT 'Normal'
);

CREATE TABLE IF NOT EXISTS combat_logs (
  combat_log_id SERIAL PRIMARY KEY,
  character_id INT NOT NULL REFERENCES characters(character_id) ON DELETE CASCADE,
  npc_id INT,
  timestamp TIMESTAMP NOT NULL DEFAULT NOW(),
  outcome TEXT NOT NULL,
  xp_gained INT NOT NULL DEFAULT 0,
  resources_json JSONB NOT NULL DEFAULT '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS events (
  event_id SERIAL PRIMARY KEY,
  type TEXT NOT NULL,
  payload_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS leaderboards (
  entry_id SERIAL PRIMARY KEY,
  user_id INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  score INT NOT NULL,
  mode TEXT NOT NULL CHECK (mode IN ('story','endless')),
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Seed minimal data
INSERT INTO settlements(name) VALUES ('Outpost One') ON CONFLICT DO NOTHING;
INSERT INTO items(name, type, slot_size, weight, durability_max, armor_dr, damage, noise, noise_radius)
VALUES
 ('Pistol','weapon',1,1.5,100,NULL,20,50,100),
 ('Ammo','ammo',1,0.1,1,NULL,NULL,0,0),
 ('Medkit','consumable',1,1.0,1,NULL,NULL,0,0)
ON CONFLICT DO NOTHING;

INSERT INTO market(settlement_id, item_id, current_price, qty_available)
SELECT 1, item_id,
  CASE name WHEN 'Pistol' THEN 100 WHEN 'Ammo' THEN 5 ELSE 25 END,
  CASE name WHEN 'Pistol' THEN 5 WHEN 'Ammo' THEN 500 ELSE 30 END
FROM items
ON CONFLICT DO NOTHING;

