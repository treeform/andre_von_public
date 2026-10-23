"""Measure a few tactical signals from saved public Diplomacy replay data."""

import argparse
import collections
import json
import os
from pathlib import Path


COUNTRIES = ("England", "France", "Italy", "Germany", "Austria", "Turkey",
             "Russia")
MOVEMENT_ORDERS = {"Hold", "Move", "Support hold", "Support move", "Convoy"}


def integer(value):
    """Accept explicit nonnegative integer IDs and counts only."""
    if isinstance(value, bool):
        return None
    if isinstance(value, int) and value >= 0:
        return value
    if isinstance(value, str) and value.isdecimal():
        return int(value)
    return None


def objects(value):
    """Select dictionary rows without assuming missing data means empty data."""
    return [row for row in value if isinstance(row, dict)] \
        if isinstance(value, list) else []


def published_phases(frames):
    """Deduplicate completed history phases repeated in successive frames."""
    phases = {}
    for frame in objects(frames):
        history = frame.get("history") or {}
        for phase in objects(history.get("phases")):
            turn = integer(phase.get("turn"))
            if turn is not None and phase.get("phase") == "Diplomacy":
                phases[turn] = phase
    return [phases[turn] for turn in sorted(phases)]


def unit_identifiers(frames):
    """Use public pre-movement snapshots to establish stable unit identity."""
    identifiers = {}
    for frame in objects(frames):
        game = frame.get("game") or {}
        turn = integer(game.get("turn"))
        if turn is None or game.get("phase") != "Diplomacy":
            continue
        for unit in objects(game.get("units")):
            country = integer(unit.get("countryID"))
            origin = integer(unit.get("terrID"))
            identifier = integer(unit.get("id")) or None
            kind = unit.get("type")
            if country and origin and kind in {"Army", "Fleet"}:
                key = (turn, country, origin, kind)
                if key in identifiers and identifiers[key] != identifier:
                    identifiers[key] = None
                else:
                    identifiers[key] = identifier
    return identifiers


def map_data(frames):
    """Read only public territory IDs, short names, and coast parent IDs."""
    territories = {}
    for frame in objects(frames):
        variant = frame.get("variant") or {}
        for row in objects(variant.get("territories")):
            identifier = integer(row.get("id"))
            if identifier:
                name = row.get("name")
                territories[identifier] = {
                    "id": identifier,
                    "name": name if isinstance(name, str) and
                    len(name) <= 80 else None,
                    "parent": integer(row.get("coastParentID")) or identifier,
                }
    return territories


def province(identifier, territories):
    """Compare provinces rather than fleet coasts for support matching."""
    return territories.get(identifier, {}).get("parent", identifier)


def location(identifier, territories):
    """Expose a public location without copying arbitrary replay objects."""
    return {"territory_id": identifier,
            "name": territories.get(identifier, {}).get("name")}


def centers(frames):
    """Separate observed centers from confirmed year-end ownership counts."""
    snapshots = {}
    for frame in objects(frames):
        game = frame.get("game") or {}
        turn = integer(game.get("turn"))
        phase = game.get("phase")
        if turn is None or phase not in {"Diplomacy", "Retreats", "Builds", "Finished"}:
            continue
        members = {integer(row.get("countryID")): row for row in
                   objects(game.get("members"))}
        snapshots[(turn, phase)] = {
            "turn": turn, "phase": phase, "year": 1901 + turn // 2,
            "centers": {str(country): integer(members.get(country, {}).get(
                "supplyCenterNo")) for country in range(1, 8)},
        }
    initial = snapshots.get((0, "Diplomacy"))
    annual = []
    if snapshots:
        last_year = 1901 + max(turn for turn, _ in snapshots) // 2
        for year in range(1901, last_year + 1):
            autumn = (year - 1901) * 2 + 1
            candidates = ((autumn, "Finished"), (autumn, "Builds"),
                          (autumn + 1, "Diplomacy"))
            source = next((snapshots[key] for key in candidates if key in snapshots), None)
            annual.append({
                "year": year,
                "source_turn": source["turn"] if source else None,
                "source_phase": source["phase"] if source else None,
                "centers": source["centers"] if source else
                {str(country): None for country in range(1, 8)},
            })
    return {"initial": initial, "year_end": annual,
            "observations": list(snapshots.values())}


def check_support(order, orders, units, territories):
    """Check order agreement without deciding legality or judging diplomacy."""
    country = integer(order.get("countryID"))
    source = integer(order.get("fromTerrID"))
    target = integer(order.get("toTerrID"))
    result = {"country_id": country,
              "supporter": location(integer(order.get("terrID")), territories),
              "referenced_origin": location(source, territories),
              "intended_destination": location(target, territories)}
    if not source or not target or not country:
        return {**result, "classification": "unknown_malformed_reference"}
    origin = province(source, territories)
    movers = [row for row in orders if province(integer(row.get("terrID")),
              territories) == origin]
    occupants = [row for row in units if province(integer(row.get("terrID")),
                 territories) == origin and row.get("retreating") is not True]
    owners = {integer(row.get("countryID")) for row in occupants}
    owners.discard(None)
    if len(movers) > 1 or len(owners) > 1:
        return {**result, "classification": "unknown_ambiguous_mover"}
    mover = movers[0] if movers else None
    owner = integer(mover.get("countryID")) if mover else next(iter(owners), None)
    if owners and owner not in owners:
        return {**result, "classification": "unknown_conflicting_ownership"}
    result["referenced_country_id"] = owner
    if owner is None:
        return {**result, "classification": "unknown_no_known_mover"}
    if mover is None:
        return {**result, "classification": "foreign_unit_order_unavailable"
                if owner != country else "own_unit_order_unavailable"}
    kind = mover.get("type")
    destination = integer(mover.get("toTerrID"))
    result["referenced_order"] = {
        "type": kind if kind in MOVEMENT_ORDERS else None,
        "destination": location(destination, territories)}
    agrees = kind == "Move" and destination is not None and \
        province(destination, territories) == province(target, territories)
    result["order_agrees"] = agrees if kind in MOVEMENT_ORDERS and (
        kind != "Move" or destination is not None) else None
    if owner != country:
        result["classification"] = "foreign_unit_reference"
    elif result["order_agrees"] is None:
        result["classification"] = "unknown_own_order"
    elif agrees:
        result["classification"] = "own_order_agrees"
    else:
        result["classification"] = "own_order_disagrees"
    return result


def analyze(frames, scoreboard=None):
    """Compute published-order signals, preserving unknown identity/outcomes."""
    phases = published_phases(frames)
    available_order_phases = sum(isinstance(phase.get("orders"), list)
                                 for phase in phases)
    territories = map_data(frames)
    identifiers = unit_identifiers(frames)
    trajectory = centers(frames)
    metadata = {row.get("country"): row for row in objects(
        (scoreboard or {}).get("participants"))}
    stats = {country: {
        "country_id": country, "country": COUNTRIES[country - 1],
        "policy": metadata.get(COUNTRIES[country - 1], {}).get("policy")
        if metadata.get(COUNTRIES[country - 1], {}).get("policy") in
        {"kutuzov", "scott-pidip"} else None,
        "movement_orders": 0, "hold_orders": 0,
        "failed_moves": 0, "unknown_move_outcomes": 0,
        "unknown_identity_repeat_pairs": 0,
        "replaced_unit_repeat_pairs_excluded": 0,
        "repeat_failed_move_runs": [], "support_move_checks": [],
    } for country in range(1, 8)}
    previous = {}
    repeated = {}
    missing_order_phases = []
    for phase in phases:
        turn = integer(phase.get("turn"))
        if not isinstance(phase.get("orders"), list):
            missing_order_phases.append(turn)
            continue
        orders = objects(phase["orders"])
        units = objects(phase.get("units"))
        current = {}
        for order in orders:
            country = integer(order.get("countryID"))
            if country not in stats:
                continue
            result = stats[country]
            kind = order.get("type")
            if kind in MOVEMENT_ORDERS:
                result["movement_orders"] += 1
                result["hold_orders"] += kind == "Hold"
            if kind == "Support move":
                result["support_move_checks"].append({
                    "turn": turn, "year": 1901 + turn // 2,
                    **check_support(order, orders, units, territories)})
            if kind != "Move":
                continue
            if not isinstance(order.get("success"), bool):
                result["unknown_move_outcomes"] += 1
                continue
            if order["success"]:
                continue
            result["failed_moves"] += 1
            origin = integer(order.get("terrID"))
            destination = integer(order.get("toTerrID"))
            unit_type = order.get("unitType")
            route = order.get("viaConvoy")
            identifier = identifiers.get((turn, country, origin, unit_type))
            if not origin or not destination or unit_type not in {"Army", "Fleet"}:
                continue
            signature = (country, origin, destination, unit_type,
                         route if isinstance(route, bool) else None)
            current[signature] = (turn, identifier)
            old = previous.get(signature)
            if old is None or old[0] != turn - 1:
                continue
            if identifier is None or old[1] is None or not isinstance(route, bool):
                result["unknown_identity_repeat_pairs"] += 1
                continue
            if identifier != old[1]:
                result["replaced_unit_repeat_pairs_excluded"] += 1
                continue
            key = (signature, identifier)
            run = repeated.get(key)
            if run is None or run["last_turn"] != turn - 1:
                run = {"unit_id": identifier, "unit_type": unit_type,
                       "origin": location(origin, territories),
                       "destination": location(destination, territories),
                       "via_convoy": route, "first_turn": turn - 1,
                       "last_turn": turn, "consecutive_failed_moves": 2}
                result["repeat_failed_move_runs"].append(run)
                repeated[key] = run
            else:
                run["last_turn"] = turn
                run["consecutive_failed_moves"] += 1
        previous = current
    for country, result in stats.items():
        total = result["movement_orders"]
        result["hold_share"] = round(result["hold_orders"] / total, 6) if total else None
        result["same_unit_repeat_pairs"] = sum(run["consecutive_failed_moves"] - 1
                                              for run in result["repeat_failed_move_runs"])
        result["support_move_classifications"] = dict(collections.Counter(
            check["classification"] for check in result["support_move_checks"]))
        result["initial_centers"] = trajectory["initial"]["centers"][str(country)] \
            if trajectory["initial"] else None
        result["year_end_centers"] = [{"year": row["year"],
                                       "centers": row["centers"][str(country)]}
                                      for row in trajectory["year_end"]]
        if not available_order_phases:
            for key in ("movement_orders", "hold_orders", "failed_moves",
                        "unknown_move_outcomes", "same_unit_repeat_pairs"):
                result[key] = None
    groups = {}
    for policy in ("kutuzov", "scott-pidip"):
        selected = [row for row in stats.values() if row["policy"] == policy]
        if selected and available_order_phases:
            total = sum(row["movement_orders"] for row in selected)
            holds = sum(row["hold_orders"] for row in selected)
            groups[policy] = {"movement_orders": total, "hold_orders": holds,
                              "hold_share": round(holds / total, 6) if total else None,
                              "same_unit_repeat_pairs": sum(row["same_unit_repeat_pairs"]
                                                            for row in selected)}
    return {"schema_version": 1, "movement_phases": len(phases),
            "available_order_phases": available_order_phases,
            "movement_turns": [row["turn"] for row in phases],
            "missing_order_phases": missing_order_phases,
            "center_trajectory": trajectory, "countries": list(stats.values()),
            "policy_groups": groups,
            "notes": [
                "Only public replay game/variant/history fields and scoreboard labels are read.",
                "Order counts describe available published orders; absent phase order lists remain missing.",
                "Hold share uses published movement-phase orders; Hold success=false is not a failure.",
                "Repeat runs require explicit failed Move results, identical orders, stable unit IDs, and adjacent turns.",
                "Supports compare province parents across coasts. Own order disagreement is not a legality verdict.",
                "Foreign supports may be legal even when the foreign unit orders something else.",
                "Year-end centers require autumn Builds/Finished or the following Spring snapshot.",
            ]}


def main():
    """Read saved public artifacts and write one private metrics JSON file."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    arguments = parser.parse_args()
    frames = json.loads((arguments.directory / "game.replay").read_text())
    if not isinstance(frames, list):
        raise ValueError("The saved replay must be an array of public frames.")
    scoreboard_path = arguments.directory / "scoreboard.json"
    scoreboard = json.loads(scoreboard_path.read_text()) if scoreboard_path.exists() else {}
    report = analyze(frames, scoreboard)
    destination = arguments.output or arguments.directory / "tactics.json"
    destination.parent.mkdir(parents=True, exist_ok=True)
    with destination.open("w", encoding="utf-8") as stream:
        os.chmod(destination, 0o600)
        json.dump(report, stream, indent=2)
        stream.write("\n")
    print(json.dumps({"output": str(destination), "movement_phases": report["movement_phases"],
                      "policy_groups": report["policy_groups"]}, indent=2))


if __name__ == "__main__":
    main()
