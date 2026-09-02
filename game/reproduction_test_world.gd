extends "res://game/sim_world.gd"
# Deterministic test fixture: no settings writes and no food/initial-population setup.
var test_cap: int = 20
func population_cap() -> int:
    return test_cap
func mating_radius() -> float:
    return 18.0
func mate_delay() -> float:
    return 16.0
func sexual_attempt_rate() -> float:
    return 1.0
func mutation_strength() -> float:
    return 0.0
func macro_rate() -> float:
    return 0.0
func viability_threshold() -> float:
    return 0.18
