extends RefCounted

# Updated only on birth/injection/death, never by scanning DNA every frame.
# Totals survive eviction; the bounded record list explicitly reports its gap.
const RECORD_LIMIT: int = 2048
var records: Array = []
var by_id: Dictionary = {}
var first_forms: Dictionary = {}
var discoveries: Array = []
var totals: Dictionary = {"initial_founders": 0, "manual_founders": 0, "rescue_founders": 0, "births": 0, "sexual_births": 0, "clonal_births": 0, "mutated_births": 0, "macro_births": 0, "deaths": 0, "highest_generation": 0, "new_topologies": 0, "dropped_records": 0}

func record(kind: String, details: Dictionary, step: int, time: float) -> void:
    if kind == "death":
        totals["deaths"] += 1
        var deceased_id: int = int(details.get("id", -1))
        if by_id.has(deceased_id):
            by_id[deceased_id]["alive"] = false
            by_id[deceased_id]["death_step"] = step
            by_id[deceased_id]["death_time"] = time
        return
    if kind not in ["founder_injection", "birth"]: return
    var entry: Dictionary = details.get("lineage", {}).duplicate(true)
    if entry.is_empty(): return
    var oid: int = int(entry["id"])
    if by_id.has(oid): return
    var natural: bool = kind == "birth"
    var origin: String = str(details.get("reason", "manual"))
    if natural:
        origin = "sexual" if int(entry["parents"][1]) >= 0 else "clonal"
        totals["births"] += 1
        totals[origin + "_births"] += 1
        if int(entry["mutations"]) > 0: totals["mutated_births"] += 1
        if int(entry["macro_mutations"]) > 0: totals["macro_births"] += 1
    elif origin == "initial":
        totals["initial_founders"] += 1
    elif origin == "population_rescue":
        totals["rescue_founders"] += 1
    else:
        totals["manual_founders"] += 1
    entry["origin"] = origin
    entry["birth_step"] = step
    entry["birth_time"] = time
    entry["alive"] = true
    entry["death_step"] = -1
    entry["death_time"] = -1.0
    var plan: String = str(entry["plan"])
    entry["new_topology"] = natural and not first_forms.has(plan)
    if not first_forms.has(plan):
        first_forms[plan] = {"plan": plan, "id": oid, "origin": origin, "generation": entry["generation"], "time": time, "step": step}
        if natural:
            discoveries.append(first_forms[plan].duplicate(true))
            totals["new_topologies"] += 1
    totals["highest_generation"] = maxi(int(totals["highest_generation"]), int(entry["generation"]))
    records.append(entry)
    by_id[oid] = entry
    if records.size() > RECORD_LIMIT:
        var removed: Dictionary = records.pop_front()
        by_id.erase(int(removed["id"]))
        totals["dropped_records"] += 1

func snapshot() -> Dictionary:
    return {"schema": "arena.evolution/1", "totals": totals.duplicate(true), "first_forms": first_forms.duplicate(true), "discoveries": discoveries.duplicate(true), "records": records.duplicate(true), "record_limit": RECORD_LIMIT}
