"""Analyze downloaded Diplomacy evidence without network or private press.

Usage: python3 tools/analyze.py --directory runs/EXPERIMENT/GAME
Only analysis.json is written. Run tools/audit.py separately for raw log coverage.
"""

import argparse
import collections
import datetime
import json
import math
import os
import re
from pathlib import Path


COUNTRIES = ("England", "France", "Italy", "Germany", "Austria", "Turkey",
             "Russia")
PHASES = ("Pre-game", "Diplomacy", "Retreats", "Builds", "Finished")
METRICS = ("billed_calls", "input_tokens", "output_tokens", "cache_read_tokens",
           "cache_write_tokens", "reasoning_tokens", "billed_cost_usd")
TERMINAL = ("completed", "failed", "cancelled", "canceled", "error")


def number(value):
    """Return a finite nonnegative metric, preserving unknown values."""
    if isinstance(value, bool):
        return None
    try:
        result = float(value)
    except (TypeError, ValueError, OverflowError):
        return None
    return result if math.isfinite(result) and result >= 0 else None


def integer(value):
    """Accept integer counts without silently rounding malformed values."""
    result = number(value)
    return int(result) if result is not None and result.is_integer() else None


def choice(value, choices):
    """Keep an enumerated value without exporting arbitrary source text."""
    return value if isinstance(value, str) and value in choices else None


def policy(value):
    """Map known policy names to comparison groups without copying labels."""
    if isinstance(value, str):
        base = value.lower().split(":", 1)[0]
        if base == "kutuzov":
            return "kutuzov"
        if base in ("scott", "scott-pidip"):
            return "scott"
    return "unknown"


def model(value):
    """Keep provider model identifiers while excluding URLs and free text."""
    if isinstance(value, str) and re.fullmatch(
            r"(?:[a-z][a-z0-9-]{0,30}/)?(?:gpt-[\w.-]{1,80}|"
            r"claude-[\w.-]{1,80}|external-[a-f0-9]{16,128})", value):
        return value
    return "unknown"


def load(directory, name, sources):
    """Read one exact local artifact, reporting missing or malformed data."""
    path = directory / name
    if not path.is_file():
        sources[name] = "missing"
        return None
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        sources[name] = "invalid_json"
        return None
    if isinstance(value, dict) and value.get("type") == "not_found":
        sources[name] = "not_found_payload"
        return None
    sources[name] = "available"
    return value


def objects(value):
    """Ignore malformed rows instead of treating them as observations."""
    return [row for row in value if isinstance(row, dict)] if isinstance(
        value, list) else []


def indexed(value, key):
    """Index explicit numeric IDs independently of source array ordering."""
    return {integer(row.get(key)): row for row in objects(value)
            if integer(row.get(key)) is not None}


def mean(values):
    """Require complete values before reporting a group mean."""
    if not values or any(value is None for value in values):
        return None
    return round(sum(values) / len(values), 12)


def activity(directory, sources, final_autumn):
    """Collect sampled Saved/Ready status with the configured episode horizon."""
    path = directory / "game.log"
    records = None
    if path.is_file():
        try:
            with path.open(encoding="utf-8", errors="replace") as stream:
                for line in stream:
                    try:
                        row = json.loads(line)
                    except ValueError:
                        continue
                    if isinstance(row, dict) and row.get("event") == \
                            "seat_activity" and isinstance(row.get("phases"), list):
                        records = row["phases"]
            sources["game.log"] = "available"
        except OSError:
            sources["game.log"] = "unreadable"
    else:
        sources["game.log"] = "missing"
    phases = {}
    for row in objects(records):
        turn = integer(row.get("turn"))
        phase = choice(row.get("phase"), PHASES)
        if turn is not None and phase in ("Diplomacy", "Retreats", "Builds"):
            phases[(turn, phase)] = row.get("seats")
    return records is not None, phases, final_autumn


def seat_activity(slot, sampled):
    """Count observations without calling an absent sample a missed deadline."""
    available, phases, final_autumn = sampled
    if not available:
        return {"available": False}
    required = saved = ready = no_orders = excluded = malformed = 0
    post_horizon = 0
    by_phase = collections.Counter()
    gaps = []
    for (turn, phase), seats in sorted(phases.items()):
        if not isinstance(seats, list) or slot >= len(seats):
            malformed += 1
            continue
        seat = seats[slot]
        if final_autumn is not None and turn > final_autumn:
            post_horizon += isinstance(seat, dict)
            continue
        if turn == final_autumn and phase == "Builds":
            excluded += isinstance(seat, dict)
            continue
        if seat is None:
            no_orders += 1
            continue
        if not isinstance(seat, dict):
            malformed += 1
            continue
        required += 1
        by_phase[phase] += 1
        has_saved = number(seat.get("first_saved_seconds")) is not None
        has_ready = number(seat.get("first_ready_seconds")) is not None
        saved += has_saved
        ready += has_ready
        if not has_saved or not has_ready:
            gaps.append({"turn": turn, "phase": phase,
                         "saved_unobserved": not has_saved,
                         "ready_unobserved": not has_ready})
    return {"available": True, "required_phases": required,
            "required_by_phase": dict(by_phase), "saved_observed": saved,
            "ready_observed": ready, "saved_unobserved": required - saved,
            "ready_unobserved": required - ready, "sampling_gaps": gaps,
            "no_orders_excluded": no_orders,
            "final_year_build_obligations_excluded": excluded,
            "post_horizon_obligations_excluded": post_horizon,
            "malformed_phase_records": malformed}


def table_rows(document):
    """Decode named columns without depending on query column order."""
    if not isinstance(document, dict) or not isinstance(
            document.get("columns"), list) or not isinstance(
            document.get("rows"), list):
        return []
    columns = document["columns"]
    if not all(isinstance(column, str) for column in columns) or \
            len(columns) != len(set(columns)):
        return []
    return [dict(zip(columns, values)) for values in document["rows"]
            if isinstance(values, list) and len(values) == len(columns)]


def provider_rows(document):
    """Decode column-indexed final telemetry without adding live snapshots."""
    result = []
    for row in table_rows(document):
        slot = integer(row.get("slot"))
        if slot is None:
            continue
        parsed = {key: number(row.get(key)) if key == "billed_cost_usd"
                  else integer(row.get(key)) for key in METRICS}
        parsed.update(slot=slot, model=model(row.get("resolved_model")),
                      status=choice(row.get("status"), (
                          "completed", "failed", "error", "success", "cancelled",
                          "canceled", "timeout", "rejected", "pending")) or "unknown")
        result.append(parsed)
    return result


def attempt_rows(document):
    """Classify attempt failures independently of HTTP response availability."""
    result = []
    for row in table_rows(document):
        slot = integer(row.get("slot"))
        if slot is None:
            continue
        status = integer(row.get("status_code"))
        if status is not None and not 100 <= status <= 599:
            status = None
        policy_result = choice(row.get("policy_result"), (
            "accepted", "rejected", "denied", "blocked", "failed", "error"))
        error = row.get("error_type")
        reported_error = error is not None and error != ""
        error_type = choice(error, ("upstream_transport_error", "upstream_timeout",
            "request_cancelled", "rate_limit", "budget_exceeded",
            "spend_limit_exceeded", "invalid_request", "authentication_error"))
        if isinstance(error, str) and re.fullmatch(r"upstream_http_[45]\d{2}", error):
            error_type = error
        http_error = status is not None and status >= 400
        rejected = policy_result in ("rejected", "denied", "blocked", "failed", "error")
        failed = reported_error or http_error or rejected
        if reported_error and error_type is None:
            error_type = "other_reported_error"
        elif not reported_error and http_error:
            error_type = "http_error_without_error_type"
        elif not reported_error and rejected:
            error_type = "policy_rejection_without_error_type"
        success = status is not None and 200 <= status < 300 and not failed
        result.append({"slot": slot, "model": model(row.get("canonical_model")),
            "attempts": integer(row.get("attempts")), "status": status,
            "policy_result": policy_result or "unknown", "error_type": error_type,
            "failed": failed, "http_error": http_error,
            "transport_error": error_type == "upstream_transport_error",
            "failed_without_http_status": failed and status is None,
            "policy_rejected": rejected, "success": success,
            "unresolved": not failed and not success})
    return result


def attempt_totals(rows):
    """Count each failed attempt once, retaining overlapping failure categories."""
    available = bool(rows)
    complete = available and all(row["attempts"] is not None for row in rows)
    counters = {"attempts": 0, "failed_attempts": 0, "http_error_attempts": 0,
        "transport_error_attempts": 0,
        "upstream_transport_error_label_attempts": 0,
        "failed_without_http_status": 0,
        "policy_rejected_attempts": 0, "successful_response_attempts": 0,
        "unresolved_attempts": 0}
    flags = {"failed_attempts": "failed", "http_error_attempts": "http_error",
        "transport_error_attempts": "transport_error",
        "upstream_transport_error_label_attempts": "transport_error",
        "failed_without_http_status": "failed_without_http_status",
        "policy_rejected_attempts": "policy_rejected",
        "successful_response_attempts": "success", "unresolved_attempts": "unresolved"}
    errors = collections.Counter()
    statuses = collections.Counter()
    policy_results = collections.Counter()
    for row in rows:
        count = row["attempts"]
        if count is None:
            continue
        counters["attempts"] += count
        for key, flag in flags.items():
            if row[flag]:
                counters[key] += count
        if row["error_type"] is not None:
            errors[row["error_type"]] += count
        statuses[str(row["status"]) if row["status"] is not None else "null"] += count
        policy_results[row["policy_result"]] += count
    return {"available": available, "counts_complete": complete, "rows": len(rows),
        **{key: value if complete else None for key, value in counters.items()},
        "known_subtotals": counters if available else {},
        "error_types": dict(errors), "http_statuses": dict(statuses),
        "policy_results": dict(policy_results)}


def seat_attempts(slot, rows):
    """Expose independent attempt counts for each seat and canonical model."""
    selected = [row for row in rows if row["slot"] == slot]
    return {**attempt_totals(selected), "models": [
        {"model": name, **attempt_totals([row for row in selected
                                         if row["model"] == name])}
        for name in sorted({row["model"] for row in selected})]}


def totals(rows):
    """Keep missing telemetry fields separate from known zero values."""
    result = {"rows": len(rows), "reported_rows": {}, "known_subtotals": {}}
    for key in METRICS:
        values = [row[key] for row in rows if row[key] is not None]
        result["reported_rows"][key] = len(values)
        subtotal = round(sum(values), 12) if values else None
        result["known_subtotals"][key] = subtotal
        result[key] = subtotal if len(values) == len(rows) else None
    inputs = [result[key] for key in (
        "input_tokens", "cache_read_tokens", "cache_write_tokens")]
    complete = bool(rows) and all(result["reported_rows"][key] == len(rows)
                                 for key in METRICS)
    input_complete = bool(rows) and all(
        result["reported_rows"][key] == len(rows) for key in (
            "input_tokens", "cache_read_tokens", "cache_write_tokens"))
    total = sum(inputs) if input_complete else None
    result.update(all_metrics_reported=complete,
                  total_input_tokens=total,
                  cache_read_share=round(result["cache_read_tokens"] / total, 6)
                  if total else None)
    return result


def seat_provider(slot, rows):
    """Aggregate per model and status using only numeric provider fields."""
    selected = [row for row in rows if row["slot"] == slot]
    grouped = []
    for name in sorted({row["model"] for row in selected}):
        model_rows = [row for row in selected if row["model"] == name]
        statuses = {}
        for status in sorted({row["status"] for row in model_rows}):
            statuses[status] = totals([row for row in model_rows
                                      if row["status"] == status])["billed_calls"]
        grouped.append({"model": name, "calls_by_status": statuses,
                        **totals(model_rows)})
    return {"available": bool(selected), "models": grouped, **totals(selected)}


def seat_health(row):
    """Expose connection counts, never URLs, tokens or raw failure text."""
    if not isinstance(row, dict):
        return {"available": False}
    connections = collections.Counter(choice(item.get("event"), (
        "connect", "disconnect", "reconnect")) or "other"
        for item in objects(row.get("connections")))
    return {"available": True, "connection_events": dict(connections),
            "disconnects": connections["disconnect"],
            "additional_connections": max(0, connections["connect"] - 1),
            "api_requests": integer(row.get("api_requests"))}


def seat_exit(row):
    """Expose process completion without copying potentially sensitive errors."""
    if not isinstance(row, dict):
        return {"available": False}
    code = row.get("exit_code")
    if isinstance(code, str) and re.fullmatch(r"-?\d{1,9}", code):
        code = int(code)
    if isinstance(code, bool) or not isinstance(code, int):
        code = None
    state = choice(row.get("state"), ("exited", "running", "pending", "failed",
                                      "terminated", "waiting"))
    return {"available": True, "state": state, "exit_code": code,
            "reason": choice(row.get("reason"), ("Completed", "Error", "Failed",
                "OOMKilled", "DeadlineExceeded", "Evicted", "Killed")),
            "clean_exit": state == "exited" and code == 0}


def trajectory(replay, countries):
    """Extract numeric center history while discarding map pixels and press."""
    result = []
    for index, frame in enumerate(replay if isinstance(replay, list) else []):
        if not isinstance(frame, dict) or not isinstance(frame.get("game"), dict):
            continue
        game = frame["game"]
        phase = choice(game.get("phase"), PHASES)
        turn = integer(game.get("turn"))
        if phase is None or turn is None:
            continue
        members = indexed(game.get("members"), "countryID")
        result.append({"frame_index": index, "turn": turn, "phase": phase,
                       "centers_by_slot": [integer(members.get(country, {}).get(
                           "supplyCenterNo")) for country in countries]})
    return result


def analyze_directory(directory):
    """Build a reproducible public-fact summary of one downloaded episode."""
    sources = {}
    documents = {name: load(directory, name, sources) for name in (
        "results.json", "episode.json", "selection.json", "request.json",
        "player-status.json", "llm-provider-spend.json", "llm-attempts.json", "game.replay",
        "audit.json")}
    results = documents["results.json"]
    results = results if isinstance(results, dict) else {}
    episode = documents["episode.json"]
    episode = episode if isinstance(episode, dict) else {}
    selection = documents["selection.json"]
    selection = selection if isinstance(selection, dict) else {}
    request = documents["request.json"]
    request = request if isinstance(request, dict) else {}
    config = episode.get("game_config") or request.get("game_config_overrides")
    config = config if isinstance(config, dict) else {}
    end_year = integer(config.get("end_year"))
    final_autumn = (end_year - 1901) * 2 + 1 if end_year and end_year >= 1901 else None
    final = results.get("final_state")
    final = final if isinstance(final, dict) else {}
    final_phase = choice(final.get("phase"), PHASES)
    status = choice(episode.get("status"), TERMINAL + (
        "pending", "submitted", "running", "dispatched"))
    public_terminal = final_phase == "Finished"
    outcome = choice(results.get("outcome"), ("won", "drawn", "cancelled",
                                             "canceled", "abandoned"))
    reason = choice(results.get("reason"), ("end_year", "time_budget", "solo",
        "won", "draw", "drawn", "cancelled", "canceled", "game_over"))
    if final_autumn is None and reason == "end_year":
        turn = integer(final.get("turn"))
        if turn is not None and turn % 2 == 1:
            final_autumn = turn
            end_year = 1901 + turn // 2
    participants = indexed(episode.get("participants"), "position")
    labels = selection.get("slots")
    labels = labels if isinstance(labels, list) else []
    country_values = results.get("countries")
    country_values = country_values if isinstance(country_values, list) else []
    scores = results.get("scores")
    scores = scores if isinstance(scores, list) else []
    count = max(len(country_values), len(scores), len(labels),
                max(participants, default=-1) + 1)
    countries = [integer(country_values[slot]) if slot < len(country_values)
                 else None for slot in range(count)]
    members = indexed(results.get("members"), "countryID")
    player_status = documents["player-status.json"]
    exits = indexed(player_status.get("players"), "slot") if isinstance(
        player_status, dict) else {}
    health = indexed(results.get("seat_health"), "slot")
    sampled = activity(directory, sources, final_autumn)
    provider = provider_rows(documents["llm-provider-spend.json"])
    attempts = attempt_rows(documents["llm-attempts.json"])
    seats = []
    for slot, country in enumerate(countries):
        participant = participants.get(slot, {})
        group = policy(participant.get("policy_name"))
        if group == "unknown" and not participant.get("policy_name"):
            version = participant.get("policy_version_id")
            if version and version == selection.get("kutuzov_version_id"):
                group = "kutuzov"
            elif version and version == selection.get("scott_version_id"):
                group = "scott"
            elif not version and slot < len(labels):
                group = policy(labels[slot])
        member = members.get(country, {})
        seats.append({"slot": slot, "policy": group, "country_id": country,
            "country": COUNTRIES[country - 1] if country and
            1 <= country <= len(COUNTRIES) else None,
            "centers": integer(member.get("supplyCenterNo")),
            "units": integer(member.get("unitNo")),
            "member_status": choice(member.get("status"), (
                "Won", "Drawn", "Defeated", "Survived", "Playing", "Left")),
            "score": number(scores[slot]) if slot < len(scores) else None,
            "exit": seat_exit(exits.get(slot)),
            "health": seat_health(health.get(slot)),
            "activity": seat_activity(slot, sampled),
            "attempts": seat_attempts(slot, attempts),
            "provider": seat_provider(slot, provider)})
    for metric in ("centers", "score"):
        complete = bool(seats) and all(seat[metric] is not None for seat in seats)
        for seat in seats:
            seat[metric + "_rank"] = 1 + sum(other[metric] > seat[metric]
                for other in seats) if complete else None
    groups = {}
    for group in ("kutuzov", "scott", "unknown"):
        selected = [seat for seat in seats if seat["policy"] == group]
        if selected:
            groups[group] = {"slots": [seat["slot"] for seat in selected],
                "seat_count": len(selected),
                "mean_centers": mean([seat["centers"] for seat in selected]),
                "mean_score": mean([seat["score"] for seat in selected]),
                "attempt_totals": attempt_totals([row for row in attempts
                    if row["slot"] in {seat["slot"] for seat in selected}])}
    known = bool(seats) and all(seat["centers"] is not None for seat in seats)
    ranked = sorted(seats, key=lambda seat: seat["centers"] or 0, reverse=True)
    top = ranked[0] if known else None
    lead = top["centers"] - ranked[1]["centers"] if top and len(ranked) > 1 else None
    solo_slots = [seat["slot"] for seat in seats if seat["member_status"] == "Won"]
    full_countries = len(countries) == 7 and set(countries) == set(range(1, 8))
    winners = [row for row in objects(results.get("members"))
               if row.get("status") == "Won"]
    solo = public_terminal and full_countries and outcome == "won" and \
        len(solo_slots) == 1 and len(winners) == 1
    comparison_complete = status == "completed" and public_terminal and \
        full_countries and known and all(
        seat["policy"] != "unknown" for seat in seats) and all(
        group in groups for group in ("kutuzov", "scott"))
    kut_solo = solo and seats[solo_slots[0]]["policy"] == "kutuzov"
    kut_centers = [seat["centers"] for seat in seats
                   if seat["policy"] == "kutuzov" and seat["centers"] is not None]
    scott_centers = [seat["centers"] for seat in seats
                     if seat["policy"] == "scott" and seat["centers"] is not None]
    kut_best = max(kut_centers) if kut_centers and comparison_complete else None
    scott_best = max(scott_centers) if scott_centers and comparison_complete else None
    margin = kut_best - scott_best if kut_best is not None and scott_best is not None else None
    kut_mean = groups.get("kutuzov", {}).get("mean_score")
    scott_mean = groups.get("scott", {}).get("mean_score")
    means_complete = kut_mean is not None and scott_mean is not None
    non_solo_signal = bool(top and kut_best == top["centers"] and margin >= 4
                           and kut_mean > scott_mean) if comparison_complete \
        and means_complete else None
    signal_available = comparison_complete and (kut_solo or means_complete)
    audit = documents["audit.json"]
    audit = audit if isinstance(audit, dict) else {}
    audit_seats = []
    for row in objects(audit.get("seats")):
        audit_seats.append({"slot": integer(row.get("slot")),
            **{key: row.get(key) if isinstance(row.get(key), bool) else None
               for key in ("log_available", "partial_log_coverage",
                           "partial_detail_coverage")},
            "first_sequence": integer(row.get("first_sequence")),
            "last_sequence": integer(row.get("last_sequence"))})
    episode_id = episode.get("id")
    if not isinstance(episode_id, str) or not re.fullmatch(
            r"ereq_[a-f0-9-]{36}", episode_id):
        episode_id = None
    return {"schema_version": 1,
        "generated_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "episode_request_id": episode_id, "episode_status": status,
        "platform_terminal": status in TERMINAL,
        "public_game_terminal": public_terminal,
        "outcome": outcome, "reason": reason, "sources": sources,
        "seats": seats, "policy_means": groups,
        "mean_comparison_note": "Arithmetic means over independent seats; policies are not coalitions.",
        "signals": {"available": signal_available,
            "requires_completed_episode_and_finished_game": True,
            "authoritative_solo_slots": solo_slots if solo else [],
            "top_center_slots": [seat["slot"] for seat in seats
                if top and seat["centers"] == top["centers"]],
            "top_center_lead_over_runner_up": lead,
            "kutuzov_solo": kut_solo if comparison_complete else None,
            "best_kutuzov_centers": kut_best,
            "best_scott_centers": scott_best,
            "best_kutuzov_vs_best_scott_center_margin": margin,
            "kutuzov_mean_score_exceeds_scott": kut_mean > scott_mean
                if means_complete else None,
            "non_solo_confirmation_candidate": non_solo_signal,
            "kutuzov_clear_win_signal": (kut_solo or non_solo_signal)
                if signal_available else None,
            "definition": "A terminal Kutuzov solo, or Kutuzov has a top country at least four centers above the best Scott country AND a higher mean per-country score. Other Kutuzov countries need not trail by four.",
            "stopping_rule_note": "One solo suffices. Otherwise two consecutive completed qualifying games are required; this single-game analyzer does not decide that batch-level stopping rule."},
        "exits": {"expected_seats": len(seats),
            "reported_seats": sum(seat["exit"]["available"] for seat in seats),
            "all_exited_zero": all(seat["exit"].get("clean_exit") for seat in seats)
                if seats and all(seat["exit"]["available"] for seat in seats) else None},
        "activity_rules": {"end_year": end_year, "final_autumn_turn": final_autumn,
            "excluded": {"turn": final_autumn, "phase": "Builds"}
                if final_autumn is not None else None,
            "first_post_horizon_turn": final_autumn + 1
                if final_autumn is not None else None,
            "note": "Final-year builds and turns beyond the configured final autumn are outside the episode. Final-year retreats remain required when orders exist. Null seats have no orders. Missing Saved/Ready samples are unobserved status, not proof of a missed deadline; a Ready shorter than an adapter tick can be missed."},
        "provider_totals": totals(provider),
        "provider_note": "Final provider aggregates only; live totals are not added. Unknown fields remain null. Cache read share uses input + cache read + cache write. External-route billed zero is not proof of zero underlying provider spend. Platform episode cost is separate.",
        "attempt_totals": attempt_totals(attempts),
        "attempt_note": "Final llm-attempts.json only; cumulative live snapshots are not added. policy_result=accepted means admitted by policy, not successful upstream completion. Failure is the union of reported error_type, HTTP >=400 and policy rejection; each grouped attempt is counted once. upstream_transport_error_label_attempts counts the reported label, which can have null HTTP status and can wrap platform or provider-response failures; it does not establish a network transport failure. transport_error_attempts is a compatibility alias for that same label count. Inspect detailed request events for actual failure classification. Failure categories overlap and must not be summed. Missing attempt counts remain unknown. Attempt counts and billed provider calls are different populations; no recovery or deadline conclusion is inferred.",
        "raw_artifact_coverage": {"tool": "tools/audit.py", "file": "audit.json",
            "available": bool(audit), "seats": audit_seats,
            "note": "Run audit.py separately; this tool neither reads private press nor infers full log coverage from successful results."},
        "center_trajectory": trajectory(documents["game.replay"], countries)}


def main():
    """Write a private JSON artifact atomically and print only its path."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    arguments = parser.parse_args()
    if not arguments.directory.is_dir():
        parser.error("The downloaded run directory does not exist.")
    report = analyze_directory(arguments.directory)
    destination = arguments.output or arguments.directory / "analysis.json"
    destination.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    temporary = destination.with_suffix(destination.suffix + ".tmp")
    with temporary.open("w", encoding="utf-8") as output:
        os.chmod(temporary, 0o600)
        json.dump(report, output, indent=2, allow_nan=False)
        output.write("\n")
    temporary.replace(destination)
    print(str(destination))


if __name__ == "__main__":
    main()
