"""Inspect saved model-budget ledgers without network access or private press.

Usage: python3 tools/budget_forensics.py --directory runs/EXPERIMENT/GAME
Writes budget-analysis.json and budget-report.md; --output-directory is optional.
"""

import argparse
import collections
import datetime
import hashlib
import json
import math
import re
import zipfile
from pathlib import Path

import audit


COUNTRIES = audit.COUNTRIES
TASKS = {"plan", "update", "review", "repair", "press"}
NUMBERS = ("sequence", "pid", "request_id", "country_id", "year", "order_slots",
           "spent_usd", "effective_limit_usd", "reserve_usd", "call",
           "call_reserve_usd", "call_allowance_usd", "request_bytes",
           "timeout_seconds", "conversation_messages", "deadline_unix",
           "seconds_left_after_spend", "estimated_spend_usd",
           "sidecar_spend_usd", "input_tokens", "output_tokens", "cached_tokens",
           "cache_write_tokens", "uncertain_usd", "uncertain_calls",
           "phase_cost_usd", "phase_allowance_usd", "status", "limit_usd",
           "exit_code", "end_year", "slots", "remaining_seconds", "deadline",
           "max_phase_calls")
FLAGS = ("cost_known", "reservation_is_estimate", "final_year", "state_restored",
         "stopped", "stop_spending", "ready")
LABELS = ("event", "model", "scope", "reason", "budget_mode", "preferred_model",
          "selected_model")


def number(value):
    """Accept finite nonnegative accounting numbers without inventing zeros."""
    if isinstance(value, bool):
        return None
    try:
        result = float(value)
    except (TypeError, ValueError, OverflowError):
        return None
    return result if math.isfinite(result) and result >= 0 else None


def phase_year(value):
    """Derive the classic-board year only from an explicit turn stamp."""
    return 1901 + int(value.split(":")[0]) // 2 if re.fullmatch(
        r"\d+:(Diplomacy|Retreats|Builds|Finished)", value or "") else None


def before_deadline(timestamp, deadline):
    """Require a recorded acceptance time strictly before a known deadline."""
    if timestamp is None or number(deadline) is None:
        return None
    try:
        return datetime.datetime.fromisoformat(timestamp.replace("Z", "+00:00")).timestamp() < deadline
    except (TypeError, ValueError, OverflowError):
        return None


def safe_event(row):
    """Retain accounting fields and sanitized orders, never prompts or press."""
    result = {key: audit.label(row[key]) for key in LABELS if key in row}
    result.update({key: row[key] for key in NUMBERS
                   if key in row and number(row[key]) is not None})
    result.update({key: row[key] for key in FLAGS
                   if isinstance(row.get(key), bool)})
    timestamp = row.get("timestamp")
    if isinstance(timestamp, str) and re.fullmatch(
            r"\d{4}-\d\d-\d\dT[\d:.]+Z", timestamp):
        result["timestamp"] = timestamp
    phase = audit.phase_key(row)
    if phase != "unknown":
        result["phase"] = phase
    if row.get("task") in TASKS:
        result["task"] = row["task"]
    if row.get("event") == "inference_stopped":
        result["reason"] = "model_requested_stop"
    if row.get("event") in ("llm_call", "model_return") and isinstance(row.get("error"), str):
        result["completion_error"] = bool(row["error"])
    body = row.get("body")
    if isinstance(body, str) and row.get("scope") == "model":
        try:
            body = json.loads(body)
        except ValueError:
            body = None
    if row.get("scope") == "model" and isinstance(body, dict):
        usage = body.get("usage")
        if isinstance(usage, dict):
            result["usage_cost_usd"] = number(usage.get("cost"))
        if isinstance(body.get("model"), str):
            result["body_model"] = audit.label(body["model"])
    if row.get("event") == "model_return":
        usage = row.get("usage")
        if isinstance(usage, dict):
            flags = [usage.get("hasInput"), usage.get("hasOutput")]
            result["usage_known"] = all(flags) if all(
                isinstance(value, bool) for value in flags) else None
    if row.get("route") == "/api.php?route=game/orders":
        result["orders_endpoint"] = True
        if isinstance(body, dict) and isinstance(body.get("orders"), list):
            result["submitted_order_count"] = len(body["orders"])
        elif isinstance(body, list):
            result["returned_order_types"] = dict(collections.Counter(
                audit.label(order.get("type")) for order in body
                if isinstance(order, dict)))
            result["unselected_destinations"] = sum(
                isinstance(order, dict) and order.get("type") == "Retreat"
                and order.get("toTerrID") is None for order in body)
            result["unselected_units"] = sum(
                isinstance(order, dict) and order.get("type") == "Destroy"
                and order.get("terrID") is None for order in body)
    return result


def sequence_issues(events):
    """Require each process's canonical archive sequence to start at one."""
    previous = {}
    issues = set()
    for row in events:
        pid, sequence = row.get("pid"), row.get("sequence")
        if type(pid) is not int or pid <= 0 or type(sequence) is not int or sequence <= 0:
            issues.add("event_sequence_missing_or_invalid")
            continue
        if pid not in previous:
            if sequence != 1:
                issues.add("event_sequence_not_initial")
        elif sequence <= previous[pid]:
            issues.add("event_sequence_out_of_order")
        elif sequence != previous[pid] + 1:
            issues.add("event_sequence_gap")
        previous[pid] = sequence
    return sorted(issues)


def read_events(directory, slot):
    """Keep compact events usable even when optional detail data is corrupt."""
    archive_path = directory / f"slot-{slot}.zip"
    stdout_path = directory / f"slot-{slot}.log"
    events = []
    issues = []
    detail_issues = []
    source = None
    enrichments = ("usage_cost_usd", "body_model", "returned_order_types",
                   "submitted_order_count", "orders_endpoint",
                   "unselected_destinations", "unselected_units")
    if archive_path.is_file():
        try:
            with zipfile.ZipFile(archive_path) as archive:
                if "logs/events.jsonl" in archive.namelist():
                    compact = archive.read("logs/events.jsonl").decode("utf-8", errors="replace")
                    source = "archive"
                    for line in compact.splitlines():
                        row = audit.event_from_line(line)
                        if row is None:
                            issues.append("compact_parse_error")
                        else:
                            events.append(safe_event(row))
                    issues.extend(sequence_issues(events))
                    coverage = audit.audit_slot(
                        archive_path, slot, "kutuzov", "logs/events.jsonl")
                    issues.extend(coverage["coverage_reasons"])
                    detail_issues.extend(coverage["detail_coverage_reasons"])
                    try:
                        raw = archive.read("logs/details.jsonl")
                        manifest = json.loads(archive.read("logs/manifest.json"))
                        files = manifest.get("files") if isinstance(manifest, dict) else None
                        record = next((item for item in files
                                       if isinstance(item, dict) and
                                       item.get("path") == "logs/details.jsonl"), {}) if isinstance(files, list) else {}
                        if record.get("sha256") != hashlib.sha256(raw).hexdigest():
                            detail_issues.append("detail_checksum_unverified")
                        else:
                            details = {}
                            for line in raw.decode("utf-8").splitlines():
                                row = audit.event_from_line(line)
                                if row is None:
                                    detail_issues.append("detail_parse_error")
                                    continue
                                key = (row.get("pid"), row.get("sequence"), row.get("timestamp"))
                                details[key] = safe_event(row)
                            for event in events:
                                key = (event.get("pid"), event.get("sequence"), event.get("timestamp"))
                                detail = details.get(key, {})
                                if detail.get("event") == event.get("event"):
                                    event.update({key: detail[key] for key in enrichments if key in detail})
                    except (OSError, ValueError, KeyError, TypeError, zipfile.BadZipFile):
                        detail_issues.append("detail_unreadable")
        except (OSError, ValueError, KeyError, TypeError, zipfile.BadZipFile):
            issues.append("archive_unreadable")
    if source is None and stdout_path.is_file():
        source = "stdout"
        issues.append("durable_archive_unavailable")
        detail_issues.append("stdout_detail_coverage_unknown")
        for line in stdout_path.read_text(encoding="utf-8", errors="replace").splitlines():
            row = audit.event_from_line(line)
            if row:
                events.append(safe_event(row))
    if source is None:
        issues.append("logs_unavailable")
    return events, {"source": source, "complete_events": not issues,
                    "event_issues": sorted(set(issues)),
                    "detail_issues": sorted(set(detail_issues))}


def summarize(events, coverage, slot):
    """Join sequential inference frames to exact HTTP request IDs and ledgers."""
    calls, phases, skips, fallbacks, ledger = [], [], [], [], []
    stops, terminals = [], []
    current = pending = last_skip = None
    meter = local = None
    mode = None
    uncertainty = base = snapshot_local = None
    stopped = None
    phase_call_limit = None
    pending_fallback = None
    country_id = None
    session = 0
    seen = set()
    join_issues = []
    for row in events:
        key = (row.get("pid"), row.get("sequence"), row.get("timestamp"))
        if key in seen:
            continue
        seen.add(key)
        kind = row.get("event")
        if kind == "process_start":
            session += 1
            pending = current = last_skip = None
            mode = uncertainty = base = snapshot_local = None
        elif kind == "bot_start":
            country_id = row.get("country_id", country_id)
            mode = row.get("budget_mode", "ConservativeBudget")
            uncertainty = None if row.get("state_restored") else 0
            stopped = row.get("stopped")
            phase_call_limit = row.get("max_phase_calls")
        elif kind == "phase_start":
            last_skip = None
            current = {**row, "session": session, "calls": [], "skips": [],
                       "successful_decisions": 0, "verified_decisions": 0,
                       "stopped_at_start": stopped, "model_stops": [],
                       "call_limit": phase_call_limit,
                       "start_meter_usd": meter}
            phases.append(current)
            local = row.get("spent_usd", local)
            snapshot_local = local
            if local is not None and uncertainty is not None:
                base = max(0, local - uncertainty)
        elif kind == "spend_sync":
            if "spent_usd" in row:
                meter = max(meter or 0, row["spent_usd"])
            if meter is not None:
                if mode == "EmpiricalBudget":
                    base = max(base, meter) if base is not None else None
                    local = base + uncertainty if base is not None and uncertainty is not None else None
                else:
                    local = max(local or 0, meter)
            ledger.append({**row, "local_observed_usd": local})
        elif kind == "economy_fallback":
            pending_fallback = {**row, "local_before_usd": local,
                                "meter_before_usd": meter}
            fallbacks.append(pending_fallback)
        elif kind == "inference_start":
            last_skip = None
            stopped = False
            if current and current.get("stopped_at_start") is None:
                current["stopped_at_start"] = False
            mode = row.get("budget_mode", mode)
            if mode == "EmpiricalBudget" and "uncertain_usd" in row:
                uncertainty = row["uncertain_usd"]
                if base is None and snapshot_local is not None:
                    base = max(0, snapshot_local - uncertainty)
                local = max(base or 0, meter or 0) + uncertainty if base is not None else None
            if pending and "return_sequence" not in pending:
                join_issues.append("inference_without_completion")
            pending = {**row, "session": session, "year": phase_year(row.get("phase")),
                       "local_before_usd": local, "meter_before_usd": meter,
                       "uncertain_before_usd": row.get("uncertain_usd"),
                       "join": "inference_only", "actual_usage_cost_usd": None,
                       "cost_classification": "unknown_evidence"}
            if pending_fallback and pending_fallback.get("phase") == row.get("phase"):
                if pending_fallback.get("selected_model") == row.get("model"):
                    pending_fallback["task"] = row.get("task")
                    pending_fallback["inference_sequence"] = row.get("sequence")
                pending_fallback = None
            calls.append(pending)
            if current and current.get("phase") == row.get("phase"):
                current["calls"].append(len(calls) - 1)
            else:
                join_issues.append("inference_without_phase_start")
        elif kind == "http_request" and row.get("scope") == "model":
            if pending and "return_sequence" not in pending:
                if "http_request_id" in pending:
                    join_issues.append("multiple_model_requests_per_inference")
                pending["http_request_id"] = row.get("request_id")
                pending["request_sequence"] = row.get("sequence")
                if row.get("body_model") not in (None, pending.get("model")):
                    join_issues.append("request_model_mismatch")
        elif kind in ("http_response", "model_return") and row.get("scope", "model") == "model":
            if pending and row.get("request_id") == pending.get("http_request_id"):
                pending["policy_http_status"] = row.get("status")
                if "usage_cost_usd" in row:
                    pending["actual_usage_cost_usd"] = row["usage_cost_usd"]
                if "usage_known" in row:
                    pending["runtime_cost_known"] = row["usage_known"]
                if "completion_error" in row:
                    pending["completion_error"] = row["completion_error"]
        elif kind == "http_transport_error" and row.get("scope") == "model":
            if (pending and "return_sequence" not in pending and
                    row.get("pid") == pending.get("pid") and
                    row.get("request_id") == pending.get("http_request_id")):
                pending.update(return_sequence=row.get("sequence"),
                               return_timestamp=row.get("timestamp"),
                               terminal_outcome="http_transport_error",
                               policy_http_status=None, status=None,
                               completion_error=True, runtime_cost_known=False,
                               cost_classification="uncertain_reservation",
                               join="sequential_inference_and_request_id",
                               local_after_usd=None, uncertain_after_usd=None)
                # The next native ledger observation must establish settlement.
                local = uncertainty = None
                ledger.append({**row, "local_observed_usd": None,
                               "uncertain_usd": None})
            else:
                join_issues.append("unmatched_model_transport_error")
        elif kind == "llm_call":
            if not pending or "return_sequence" in pending or any(
                    pending.get(key) != row.get(key) for key in ("phase", "model")):
                join_issues.append("unmatched_llm_call")
                pending = {"session": session, "actual_usage_cost_usd": None,
                           "join": "orphan_llm_event", "year": phase_year(row.get("phase"))}
                calls.append(pending)
            local = row.get("estimated_spend_usd", local)
            meter = row.get("sidecar_spend_usd", meter)
            mode = row.get("budget_mode", mode)
            if mode == "EmpiricalBudget" and "uncertain_usd" in row:
                uncertainty = row["uncertain_usd"]
                base = max(0, local - uncertainty) if local is not None else None
                snapshot_local = local
            pending.update({key: value for key, value in row.items()
                            if key not in ("event", "sequence", "timestamp")})
            pending.update(return_sequence=row.get("sequence"),
                           return_timestamp=row.get("timestamp"), local_after_usd=local,
                           meter_after_usd=meter,
                           uncertain_after_usd=row.get("uncertain_usd"))
            if "http_request_id" in pending:
                pending["join"] = "sequential_inference_and_request_id"
            known = row.get("cost_known", pending.get("runtime_cost_known"))
            pending["runtime_cost_known"] = known
            pending["cost_classification"] = (
                "reported_usage_cost" if pending["actual_usage_cost_usd"] is not None
                else "runtime_known_cost_amount_missing" if known is True
                else "uncertain_reservation" if known is False
                else "unknown_evidence")
            ledger.append({**row, "local_observed_usd": local})
        elif kind == "decision_parsed" and current:
            current["successful_decisions"] += 1
            if pending and pending.get("phase") == current.get("phase"):
                pending["decision_parsed"] = True
                pending["model_stop_requested"] = row.get("stop_spending")
        elif kind == "orders_verified" and current and row.get("task"):
            if (pending and row.get("phase") == current.get("phase") and
                    pending.get("phase") == row.get("phase") and
                    pending.get("task") == row.get("task") and
                    number(pending.get("return_sequence")) is not None and
                    number(row.get("sequence")) is not None and
                    pending["return_sequence"] < row["sequence"]):
                current["verified_decisions"] += 1
                pending["orders_verified"] = True
                pending["orders_verified_sequence"] = row.get("sequence")
                pending["orders_verified_timestamp"] = row.get("timestamp")
                pending["orders_verified_before_deadline"] = before_deadline(
                    row.get("timestamp"), pending.get("deadline_unix", current.get("deadline")))
            else:
                join_issues.append("unmatched_engine_order_verification")
        elif kind == "inference_stopped":
            stopped = True
            stop = {**row, "phase": current.get("phase") if current else None,
                    "trigger_call": len(calls) - 1 if pending else None}
            stops.append(stop)
            if current:
                current["model_stops"].append(len(stops) - 1)
        elif kind == "bot_return":
            terminals.append(row)
        elif kind == "inference_skipped":
            last_skip = {**row, "meter_spend_usd": meter,
                         "prior_calls": len(current["calls"]) if current else None,
                         "prior_decisions": current["successful_decisions"] if current else None,
                         "prior_verified_decisions": current["verified_decisions"] if current else None,
                         "disposition": "unknown"}
            skips.append(last_skip)
            if current:
                current["skips"].append(len(skips) - 1)
        elif kind == "updates_stopped" and last_skip and row.get("phase") == last_skip.get("phase"):
            last_skip["disposition"] = "optional_update_deferred"
        elif kind == "phase_ready":
            if current and row.get("phase") == current.get("phase"):
                current["ready_reason"] = row.get("reason")
                current["stopped_at_ready"] = row.get("stopped")
            if last_skip and row.get("phase") == last_skip.get("phase") and row.get("reason") == "inference_skipped":
                last_skip["disposition"] = "phase_ready_after_skip"
        elif row.get("orders_endpoint") and last_skip:
            if kind == "http_request" and row.get("submitted_order_count") == 0:
                last_skip["ready_request_id"] = row.get("request_id")
            elif kind == "http_response" and row.get("request_id") == last_skip.get("ready_request_id"):
                for key in ("returned_order_types", "unselected_destinations", "unselected_units"):
                    if key in row:
                        last_skip[key] = row[key]
    for call in calls:
        if "return_sequence" not in call:
            join_issues.append("inference_without_completion")
        if "http_request_id" not in call:
            join_issues.append("inference_without_model_request")
    complete = coverage["complete_events"] and not join_issues
    finished = any(row.get("event") == "bot_return" and row.get("reason") in
                   ("finished_or_horizon", "Defeated") for row in events)
    exits = [row.get("exit_code") for row in events if row.get("event") == "process_return"]
    completed_lifetime = finished and bool(exits) and all(code == 0 for code in exits)
    years = []
    observed_years = {phase_year(phase.get("phase")) for phase in phases}
    verified_partial_prefix = (
        coverage.get("source") == "archive" and not join_issues and
        all(type(row.get(key)) is int and row[key] > 0
            for row in events for key in ("pid", "sequence")) and
        set(coverage.get("event_issues", [])) == {"missing_process_end"})
    latest_observed_year = max(observed_years - {None}, default=None)
    closed_years = {year for year in observed_years - {None}
                    if verified_partial_prefix and latest_observed_year > year}
    for year in sorted((observed_years | {1905, 1906, 1907}) - {None}):
        subset = [call for call in calls if call.get("year") == year]
        reviews = [call for call in subset if call.get("task") == "review"
                   and call.get("model", "").endswith("sol") and call.get("status") == 200]
        trusted_year = (complete and completed_lifetime and year in observed_years
                        or year in closed_years)
        years.append({"year": year, "observed_attempts": len(subset),
                      "successful_sol_reviews_observed": len(reviews),
                      "successful_sol_reviews": len(reviews) if trusted_year else None,
                      "evidence": "closed_observed_year_missing_process_end" if year in closed_years else
                                  "complete_observed_year" if trusted_year else "incomplete_or_unobserved_year",
                      "task_model_status_counts": dict(collections.Counter(
                          f"{call.get('task', 'unknown')}/{call.get('model', 'unknown')}/{call.get('status', 'unknown')}"
                          for call in subset))})
    known = [call["actual_usage_cost_usd"] for call in calls
             if call.get("actual_usage_cost_usd") is not None]
    uncertain = [call.get("call_reserve_usd") for call in calls
                 if call.get("runtime_cost_known") is False]
    observed_uncertain = sum(value for value in uncertain if value is not None)
    result = {"slot": slot, "country_id": country_id,
            "country": COUNTRIES[int(country_id)-1] if country_id in range(1, 8) else None,
            "coverage": coverage, "join_issues": sorted(set(join_issues)),
            "completed_lifetime": completed_lifetime,
            "verified_partial_prefix": verified_partial_prefix,
            "closed_observed_years": sorted(closed_years),
            "observed_attempts": len(calls), "observed_known_usage_usd": sum(known),
            "actual_usage_cost_usd": sum(known) if complete and all(
                call.get("cost_classification") in ("reported_usage_cost", "uncertain_reservation")
                for call in calls) else None,
            "uncertain_reservations_observed_usd": observed_uncertain,
            "runtime_final_uncertain_usd": next((row["uncertain_usd"] for row in reversed(ledger)
                                                  if "uncertain_usd" in row), None),
            "local_final_observed_usd": local, "meter_final_observed_usd": meter,
            "yearly": years, "calls": calls, "phases": phases, "skips": skips,
            "fallbacks": fallbacks, "ledger": ledger,
            "model_stops": stops, "terminal_events": terminals}
    result["routing"] = routing(result)
    return result


def routing(seat):
    """Separate late Sol use, eligibility, elimination and governor outcomes."""
    def accepted(call):
        """Require every link in the successful pre-deadline acceptance chain."""
        return (call.get("status") == 200 and call.get("completion_error") is False
                and call.get("orders_verified") is True and
                call.get("orders_verified_before_deadline") is True)

    complete = (seat["coverage"]["complete_events"] and
                not seat["join_issues"] and seat["completed_lifetime"])
    terminal = seat["terminal_events"][-1] if seat["terminal_events"] else {}
    defeat_turn = None
    if terminal.get("reason") == "Defeated" and phase_year(terminal.get("phase")):
        defeat_turn = int(terminal["phase"].split(":")[0])
    movements = []
    for phase in seat["phases"]:
        if not phase.get("phase", "").endswith(":Diplomacy"):
            continue
        calls = [seat["calls"][index] for index in phase["calls"]]
        skips = [seat["skips"][index] for index in phase["skips"]]
        slots = number(phase.get("order_slots"))
        required = slots > 0 if slots is not None else None
        stopped = phase.get("stopped_at_start")
        inference_enabled = (False if required is False else
                             not stopped if required is True and stopped is not None else None)
        sol_reviews = [call for call in calls if call.get("status") == 200
                       and call.get("model", "").endswith("sol")
                       and call.get("task") == "review"]
        luna_reviews = [call for call in calls if call.get("status") == 200
                        and call.get("model", "").endswith("luna")
                        and call.get("task") == "review"]
        verified_reviews = [call for call in sol_reviews if accepted(call)]
        unknown_review_evidence = [call for call in sol_reviews
                                   if call.get("orders_verified") is True and
                                   (call.get("completion_error") is None or
                                    call.get("orders_verified_before_deadline") is None)]
        verified_repairs = [call for call in calls if call.get("task") == "repair"
                            and call.get("model", "").endswith("sol") and accepted(call)]
        repairs_after_review = []
        prior_review = None
        for call in calls:
            if call.get("task") == "review":
                prior_review = call if not accepted(call) else None
            elif call.get("task") == "repair":
                if prior_review and call in verified_repairs:
                    repairs_after_review.append({
                        "review_sequence": prior_review.get("sequence"),
                        "review_model": prior_review.get("model"),
                        "repair_sequence": call.get("sequence"),
                        "repair_verified_sequence": call.get("orders_verified_sequence")})
                    prior_review = None
            else:
                prior_review = None
        observations = []
        if required and not verified_reviews:
            if phase["model_stops"] or stopped is True:
                observations.append("explicit_model_stop")
            if any(row.get("task") == "review" and row.get("phase") == phase["phase"]
                   for row in seat["fallbacks"]):
                observations.append("review_fallback_admission_reason_unlogged")
            if any(call.get("task") == "review" and ((call.get("status") or 0) >= 400 or
                   call.get("completion_error") is True) for call in calls):
                observations.append("review_provider_or_completion_failure")
            if sol_reviews and not verified_reviews:
                observations.append("sol_review_acceptance_not_confirmed_before_deadline")
            for reason in sorted({row.get("reason") for row in skips} - {None}):
                observations.append("inference_skipped_" + reason)
            if phase.get("call_limit") and len(calls) >= phase["call_limit"]:
                observations.append("phase_call_limit_reached")
            if not observations:
                observations.append("requires_ordered_event_attribution")
        movements.append({
            "phase": phase["phase"], "year": phase_year(phase["phase"]),
            "start_sequence": phase.get("sequence"),
            "order_slots": slots, "requires_orders": required,
            "stopped_at_start": stopped, "eligible_at_start": required,
            "inference_enabled_at_start": inference_enabled,
            "sol_review_calls": len(sol_reviews),
            "verified_sol_review_calls": len(verified_reviews),
            "unknown_sol_review_acceptance_calls": len(unknown_review_evidence),
            "verified_sol_repair_calls": len(verified_repairs),
            "sol_repairs_after_unverified_review": repairs_after_review,
            "review_gap_observations": observations,
            "other_sol_calls": sum(call.get("status") == 200 and
                                   call.get("model", "").endswith("sol") and
                                   call.get("task") != "review" for call in calls),
            "luna_review_calls": len(luna_reviews),
            "economy_fallbacks": sum(row.get("phase") == phase["phase"]
                                     for row in seat["fallbacks"]),
            "optional_deferrals": sum(row["disposition"] == "optional_update_deferred" for row in skips),
            "budget_defaults": sum(row.get("reason") == "budget_reserve" and
                                   row["disposition"] == "phase_ready_after_skip" and
                                   row.get("prior_calls") == 0 and required is True for row in skips),
            "budget_ready_after_attempts": sum(row.get("reason") == "budget_reserve" and
                                               row["disposition"] == "phase_ready_after_skip" and
                                               (row.get("prior_calls") or 0) > 0 for row in skips),
            "model_stops": len(phase["model_stops"]),
            "stopped_default": (required is True and not calls and
                                phase.get("stopped_at_ready") is True),
        })
    years = []
    for year in sorted({row["year"] for row in movements} | {1905, 1906, 1907, 1908}):
        phases = [row for row in movements if row["year"] == year]
        spring_turn = (year - 1901) * 2
        eliminated_before = defeat_turn is not None and (
            defeat_turn < spring_turn or
            (defeat_turn == spring_turn and
             terminal.get("phase", "").endswith(":Diplomacy") and not phases))
        eliminated_during = (defeat_turn is not None and
                             spring_turn <= defeat_turn <= spring_turn + 1 and
                             not eliminated_before)
        closed_year = year in seat.get("closed_observed_years", [])
        evidence = ("eliminated_before_year" if complete and eliminated_before else
                    "eliminated_during_year" if complete and eliminated_during else
                    "closed_observed_year_missing_process_end" if closed_year else
                    "complete_observed_year" if complete and phases else
                    "incomplete_or_unobserved_year")
        trusted = (complete and (bool(phases) or eliminated_before)
                   or closed_year and bool(phases))
        counts = {"eligible_movements": sum(row["eligible_at_start"] is True for row in phases),
                  "eligibility_unknown_movements": sum(row["eligible_at_start"] is None for row in phases),
                  "movements_requiring_orders": sum(row["requires_orders"] is True for row in phases),
                  "inference_enabled_movements": sum(row["inference_enabled_at_start"] is True for row in phases),
                  "sol_review_phases": sum(row["sol_review_calls"] > 0 for row in phases),
                  "verified_sol_review_phases": sum(row["verified_sol_review_calls"] > 0 for row in phases),
                  "sol_repair_after_review_phases": sum(bool(row["sol_repairs_after_unverified_review"]) for row in phases),
                  "luna_review_phases": sum(row["luna_review_calls"] > 0 for row in phases)}
        for key in ("sol_review_calls", "verified_sol_review_calls",
                    "unknown_sol_review_acceptance_calls", "verified_sol_repair_calls", "other_sol_calls",
                    "economy_fallbacks", "optional_deferrals", "budget_defaults",
                    "budget_ready_after_attempts", "model_stops", "stopped_default"):
            counts[key] = sum(row[key] for row in phases)
        final_counts = dict(counts) if trusted else {key: None for key in counts}
        if counts["eligibility_unknown_movements"]:
            final_counts["eligible_movements"] = None
        if counts["unknown_sol_review_acceptance_calls"]:
            final_counts["verified_sol_review_phases"] = None
            final_counts["verified_sol_review_calls"] = None
        eligible_count = final_counts["eligible_movements"]
        verified_count = final_counts["verified_sol_review_phases"]
        positive_prefix_evidence = (seat.get("verified_partial_prefix") and
                                   any(row["eligible_at_start"] is True and
                                       row["verified_sol_review_calls"] > 0
                                       for row in phases))
        criterion = ("not_eligible" if eligible_count == 0 else
                     "satisfied" if positive_prefix_evidence or
                     (eligible_count is not None and counts["verified_sol_review_phases"] >= 1) else
                     "unknown" if eligible_count is None or verified_count is None else
                     "not_satisfied")
        years.append({"year": year, "evidence": evidence,
                      "counts": final_counts,
                      "observed_counts": counts, "yearly_review_criterion": criterion})
    return {"eligibility_definition": "An active country has required movement orders. Explicit model stops do not remove phases from this denominator; inference-enabled phases are a separate measure.",
            "success_definition": "verified_sol_review_calls requires task=review, Sol, HTTP200, no completion error, and the matching engine orders_verified(task=review) strictly before the recorded phase deadline. HTTP-only reviews and successful Sol repairs are separate.",
            "budget_default_definition": "Budget rejection before any model call, followed by Ready in a phase requiring orders. Budget rejections after attempts are separate and may preserve existing orders.",
            "terminal_reason": terminal.get("reason"),
            "defeat_observed_phase": terminal.get("phase") if defeat_turn is not None else None,
            "movements": movements, "yearly": years}


def analyze(directory):
    """Read only local slot evidence, retaining unknown slots when identified."""
    def metadata(name):
        """Treat malformed metadata shapes as unavailable evidence."""
        value = audit.read_json(directory / name)
        return value if isinstance(value, dict) else {}

    def rows(value):
        """Read list fields without interpreting malformed objects as rows."""
        return value if isinstance(value, list) else []

    scoreboard = metadata("scoreboard.json")
    roster = {row.get("slot") for row in rows(scoreboard.get("participants"))
              if isinstance(row, dict) and row.get("policy") == "kutuzov"}
    episode = metadata("episode.json")
    roster.update(row.get("position") for row in rows(episode.get("participants"))
                  if isinstance(row, dict) and row.get("policy_name") == "kutuzov")
    selection = metadata("selection.json")
    roster.update(slot for slot, name in enumerate(rows(selection.get("slots")))
                  if isinstance(name, str) and name.lower().split(":")[0] == "kutuzov")
    seats = []
    for slot in range(7):
        events, coverage = read_events(directory, slot)
        if slot in roster or any(row.get("event") == "bot_start" for row in events):
            seats.append(summarize(events, coverage, slot))
    return {"schema": 2, "seats": seats,
            "method": "Local sequential inference/request-ID joins. Known cost is response usage.cost. Missing usage is not assumed zero; explicit runtime cost-known flags identify uncertain reservations. A checksum-verified contiguous archive missing only process_end can prove earlier years closed by a later observed year. Open-year exact counts remain unknown, although a verified eligible review can satisfy the positive yearly criterion. Final lifetime and spend completeness are unchanged.",
            "sources_present": bool(seats)}


def markdown(report):
    """Render a compact accounting and late-review report without raw logs."""
    lines = ["# Kutuzov budget forensics", "", report["method"], "",
             "| Country | Observed attempts | Known usage observed USD | Uncertain allowances observed USD | Final local ledger USD |",
             "|---|---:|---:|---:|---:|"]
    for seat in report["seats"]:
        local = seat["local_final_observed_usd"]
        lines.append(f"| {seat['country'] or 'Unknown'} | {seat['observed_attempts']} | "
                     f"{seat['observed_known_usage_usd']:.8f} | {seat['uncertain_reservations_observed_usd']:.8f} | "
                     f"{f'{local:.8f}' if local is not None else 'unknown'} |")
    lines += ["", "Observed amounts are lower bounds when coverage is incomplete. "
              "Uncertain allowances are not verified charges. A model HTTP 200 "
              "does not establish that its orders were accepted.", "",
              "## Sol routing in later years", "",
              "Eligible movement phases have required orders for an active "
              "country. Model-directed stops remain in this denominator. "
              "A counted Sol review needs task=review, HTTP 200 without a "
              "completion error, and matching engine orders_verified before "
              "the deadline. Successful Sol repairs remain separate. Each "
              "eligible country-year requires at least one counted review.", "",
              "| Country | Year | Eligible movements | Counted Sol review phases / calls | Sol HTTP200 review calls | Other Sol calls | Verified Sol repairs | Criterion | Evidence |",
              "|---|---:|---:|---:|---:|---:|---:|---|---|"]
    for seat in report["seats"]:
        for year in seat["routing"]["yearly"]:
            if year["year"] in (1905, 1906, 1907, 1908):
                counts = year["counts"]
                values = [str(counts[key]) if counts[key] is not None else "unknown"
                          for key in ("eligible_movements", "verified_sol_review_phases",
                                      "verified_sol_review_calls", "sol_review_calls",
                                      "other_sol_calls", "verified_sol_repair_calls")]
                lines.append(f"| {seat['country'] or 'Unknown'} | {year['year']} | "
                             f"{values[0]} | {values[1]} / {values[2]} | {values[3]} | "
                             f"{values[4]} | {values[5]} | {year['yearly_review_criterion']} | {year['evidence']} |")
    lines += ["", "## Phase coverage in 1905–1907", "",
              "These are observed event counts. A verified contiguous archive "
              "missing only process_end preserves counts for years closed by "
              "a later observed year. A verified review can establish the "
              "positive criterion in an open year while exact counts remain "
              "unknown. Other archive or join failures remain unknown. Gap "
              "observations identify evidence to inspect; an unlogged fallback "
              "reason is not automatically attributed to pacing or global funds.", "",
              "| Country | Phase | Eligible | Counted Sol reviews | Sol HTTP200 reviews | Sol repair after unverified review | Gap observations |",
              "|---|---|---|---:|---:|---:|---|"]
    for seat in report["seats"]:
        for phase in seat["routing"]["movements"]:
            if phase["year"] in (1905, 1906, 1907):
                eligible = phase["eligible_at_start"]
                value = "unknown" if eligible is None else "yes" if eligible else "no"
                lines.append(f"| {seat['country'] or 'Unknown'} | {phase['phase']} | {value} | "
                             f"{phase['verified_sol_review_calls']} | {phase['sol_review_calls']} | "
                             f"{len(phase['sol_repairs_after_unverified_review'])} | "
                             f"{', '.join(phase['review_gap_observations']) or 'none'} |")
    lines += ["", "The following governor counts concern movement phases in "
              "1905–1907 only. Economy fallbacks select a cheaper model. Optional "
              "deferrals preserve the later review opportunity. Budget defaults "
              "mark Ready before any model call; model-stop defaults are separate.", "",
              "| Country | Fallbacks | Optional deferrals | Budget defaults | Budget Ready after attempts | Model stops | Model-stop defaults |",
              "|---|---:|---:|---:|---:|---:|---:|"]
    for seat in report["seats"]:
        years = [year for year in seat["routing"]["yearly"] if year["year"] in (1905, 1906, 1907)]
        values = []
        for key in ("economy_fallbacks", "optional_deferrals", "budget_defaults",
                    "budget_ready_after_attempts", "model_stops", "stopped_default"):
            observed = [year["counts"][key] for year in years]
            values.append(str(sum(observed)) if all(value is not None for value in observed) else "unknown")
        lines.append(f"| {seat['country'] or 'Unknown'} | " + " | ".join(values) + " |")
    lines += ["", "## Skips and coverage", ""]
    for seat in report["seats"]:
        dispositions = dict(collections.Counter(skip["disposition"] for skip in seat["skips"]))
        issues = seat["coverage"]["event_issues"] + seat["coverage"]["detail_issues"] + seat["join_issues"]
        lines.append(f"- {seat['country'] or 'Unknown'}: skip dispositions {json.dumps(dispositions)}; "
                     f"terminal {seat['routing']['terminal_reason'] or 'unknown'} "
                     f"at {seat['routing']['defeat_observed_phase'] or 'game end/unknown'}; "
                     f"coverage issues {json.dumps(issues)}.")
    lines += ["", "The JSON includes individual calls, request IDs, policy HTTP statuses, "
              "task/year/phase joins, empirical pacing fields, ledger snapshots, "
              "fallbacks and returned default-order counts. No raw prompts or private press are exported.", ""]
    return "\n".join(lines)


def main():
    """Write reusable reports for one completed or partial downloaded game."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", type=Path, required=True)
    parser.add_argument("--output-directory", type=Path)
    args = parser.parse_args()
    output = args.output_directory or args.directory
    output.mkdir(parents=True, exist_ok=True)
    report = analyze(args.directory)
    (output / "budget-analysis.json").write_text(json.dumps(report, indent=2) + "\n")
    (output / "budget-report.md").write_text(markdown(report))
    print(json.dumps({"output": str(output), "seats": len(report["seats"])}))


if __name__ == "__main__":
    main()
