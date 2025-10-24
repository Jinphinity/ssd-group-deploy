-- Character progression and survivability extension for Dizzy's Disease

ALTER TABLE characters
  ADD COLUMN IF NOT EXISTS available_stat_points INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS proficiency_melee INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS proficiency_axes_clubs INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS proficiency_pistols INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS proficiency_rifles INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS proficiency_shotguns INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS proficiency_automatics INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS survivability_health REAL NOT NULL DEFAULT 100.0,
  ADD COLUMN IF NOT EXISTS survivability_stamina REAL NOT NULL DEFAULT 100.0,
  ADD COLUMN IF NOT EXISTS nourishment_level REAL NOT NULL DEFAULT 100.0,
  ADD COLUMN IF NOT EXISTS sleep_level REAL NOT NULL DEFAULT 100.0,
  ADD COLUMN IF NOT EXISTS is_legacy_auto_created BOOLEAN NOT NULL DEFAULT FALSE;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'characters_valid_proficiencies'
    ) THEN
        ALTER TABLE characters
            ADD CONSTRAINT characters_valid_proficiencies
            CHECK (
                proficiency_melee BETWEEN 0 AND 100 AND
                proficiency_axes_clubs BETWEEN 0 AND 100 AND
                proficiency_pistols BETWEEN 0 AND 100 AND
                proficiency_rifles BETWEEN 0 AND 100 AND
                proficiency_shotguns BETWEEN 0 AND 100 AND
                proficiency_automatics BETWEEN 0 AND 100
            );
    END IF;
END$$;

-- Flag auto-generated legacy characters so the selection UI can filter them
UPDATE characters
SET is_legacy_auto_created = TRUE
WHERE is_legacy_auto_created = FALSE
  AND (name LIKE 'Survivor_%');
