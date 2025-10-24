extends Node

## Global signal hub; can be instanced or used via Game.event_bus

signal NoiseEmitted(source, intensity, radius)
signal ZombieAlerted(zombie_id, reason)
signal WeaponFired(weapon_id, params)
signal ItemDurabilityChanged(item_id, value)
signal SettlementEvent(event_type, payload)
signal PriceChanged(item_id, new_price)
signal SurvivabilityChanged(actor, snapshot)
signal PlayerDowned()
signal PlayerLeveledUp(new_level, stat_points)
signal PopulationChanged(new_value)
signal resources_changed(resources)
signal WaveSpawnerAlert(payload)
