"""Summarize Kutuzov and Scott slot logs without exporting prompts or secrets."""

import argparse
import collections
import datetime
import hashlib
import io
import json
import math
import os
import re
import zipfile
from pathlib import Path


COUNTRIES = ("England", "France", "Italy", "Germany", "Austria",
             "Turkey", "Russia")
DECODER = json.JSONDecoder()
EXIT_CODE = re.compile(
    r"(?:exit(?:ed)?|return)(?:\s+with)?(?:\s+code|\s+status)?\s*[:=]?\s+(-?\d+)",
    re.IGNORECASE)
PLAIN_ERRORS = (
    ("traceback", "Traceback (most recent call last)"),
    ("unhandled_exception", "unhandled exception"),
    ("segmentation_fault", "segmentation fault"),
    ("out_of_memory", "out of memory"),
    ("killed", "killed by signal"),
    ("timeout", "timed out"),
)


def number(value):
    """Accept finite accounting numbers while preserving unknown values."""
    if isinstance(value, bool):
        return None
    try:
        result = float(value)
    except (ValueError, TypeError, OverflowError):
        return None
    return result if math.isfinite(result) else None


def count(value):
    """Normalize a nonnegative token or event count."""
    result = number(value)
    return max(0, int(result)) if result is not None else 0


def label(value, fallback="unknown"):
    """Allow short identifier labels, never arbitrary messages or URLs."""
    if isinstance(value, (int, float)):
        return str(value)
    if isinstance(value, str) and re.fullmatch(r"[\w./:+-]{1,160}", value):
        if "://" not in value:
            return value
    return fallback


def read_json(path):
    """Read optional local metadata without failing an incomplete snapshot."""
    if not path.is_file():
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (ValueError, OSError):
        return {}


def event_from_line(line, depth=0):
    """Decode JSON events behind launcher prefixes or JSON log envelopes."""
    if depth > 3:
        return None
    for match in list(re.finditer(r"\{", line))[:16]:
        try:
            value, _ = DECODER.raw_decode(line, match.start())
        except ValueError:
            continue
        if not isinstance(value, dict):
            continue
        if isinstance(value.get("event"), str):
            return value
        for key in ("log", "message", "msg"):
            if isinstance(value.get(key), str):
                result = event_from_line(value[key], depth + 1)
                if result is not None:
                    return result
    return None


def error_category(value):
    """Classify failures without retaining their possibly sensitive text."""
    text = str(value).lower()
    for category, needles in (
        ("timeout", ("timeout", "timed out", "deadline", "curl 28")),
        ("budget", ("budget", "spend limit", "insufficient_quota")),
        ("rate_limit", ("rate_limit", "rate limit", "too many requests")),
        ("invalid_json", ("invalid json", "not valid json", "jsondecode")),
        ("orders_changed", ("server changed orders", "orders_verification")),
        ("empty_orders", ("orders cannot be empty",)),
        ("incomplete_model_response", ("did not complete", "finish_reason")),
        ("refusal", ("refused", "refusal")),
        ("phase_changed", ("phase changed", "stale")),
        ("connection", ("connection", "could not resolve", "dns")),
        ("authentication", ("unauthorized", "forbidden", "authentication")),
    ):
        if any(needle in text for needle in needles):
            return category
    return "other"


def phase_key(row):
    """Normalize phase identifiers without copying player-controlled text."""
    phase = row.get("phase")
    if isinstance(phase, str) and re.fullmatch(
            r"(?:\d+:)?(?:Diplomacy|Retreats|Builds|Finished)", phase):
        if ":" in phase or row.get("turn") is None:
            return phase
        return f"{count(row['turn'])}:{phase}"
    return "unknown"


def usage_call(row, usage, model=None):
    """Extract only model accounting fields from a request completion."""
    details = usage.get("prompt_tokens_details") or usage.get(
        "input_tokens_details") or {}
    if not isinstance(details, dict):
        details = {}
    return {
        "model": label(model or row.get("model")),
        "status": label(row.get("status", "unknown")),
        "input_tokens": count(usage.get("prompt_tokens", usage.get(
            "input_tokens", usage.get("input")))),
        "output_tokens": count(usage.get("completion_tokens", usage.get(
            "output_tokens", usage.get("output")))),
        "cached_tokens": count(usage.get("cached_tokens", usage.get(
            "cached", details.get("cached_tokens")))),
        "cost_usd": number(usage.get("cost", usage.get("cost_usd"))),
        "usage_reported": (usage.get("hasInput") is True or any(
            key in usage for key in ("prompt_tokens", "input_tokens"))),
        "cache_reported": ("cached_tokens" in details or
                           "cached_tokens" in usage or
                           bool(usage.get("hasCached"))),
    }


def summarize_calls(calls):
    """Aggregate token usage and costs without conflating unknown with zero."""
    by_model = {}
    for model in sorted({call["model"] for call in calls}):
        selected = [call for call in calls if call["model"] == model]
        inputs = sum(call["input_tokens"] for call in selected)
        cached = sum(call["cached_tokens"] for call in selected)
        costs = [call["cost_usd"] for call in selected
                 if call["cost_usd"] is not None]
        by_model[model] = {
            "calls": len(selected),
            "statuses": dict(collections.Counter(call["status"]
                                                 for call in selected)),
            "input_tokens": inputs,
            "output_tokens": sum(call["output_tokens"] for call in selected),
            "cached_tokens": cached,
            "cached_input_ratio": round(cached / inputs, 6) if inputs else None,
            "usage_reported_calls": sum(call["usage_reported"]
                                        for call in selected),
            "cache_reported_calls": sum(call["cache_reported"]
                                        for call in selected),
            "provider_cost_reported_calls": len(costs),
            "logged_provider_cost_usd": round(sum(costs), 8) if costs else None,
        }
    inputs = sum(call["input_tokens"] for call in calls)
    cached = sum(call["cached_tokens"] for call in calls)
    costs = [call["cost_usd"] for call in calls if call["cost_usd"] is not None]
    return {
        "calls": len(calls), "models": by_model,
        "input_tokens": inputs,
        "output_tokens": sum(call["output_tokens"] for call in calls),
        "cached_tokens": cached,
        "cached_input_ratio": round(cached / inputs, 6) if inputs else None,
        "logged_provider_cost_usd": round(sum(costs), 8) if costs else None,
        "provider_cost_reported_calls": len(costs),
    }


def manifest_coverage(archive, compact):
    """Verify compact collection and distinguish incomplete detail artifacts."""
    reasons = {"events": [], "details": []}
    try:
        info = archive.getinfo("logs/manifest.json")
        if info.file_size > 65536:
            raise ValueError("Oversized manifest")
        manifest = json.loads(archive.read(info))
        if not isinstance(manifest, dict) or manifest.get("schema_version") != 1:
            raise ValueError("Invalid manifest")
        files = {row["path"]: row for row in manifest["files"]
                 if isinstance(row, dict) and "path" in row}
    except (KeyError, ValueError, TypeError, zipfile.BadZipFile):
        return {key: ["manifest_missing_or_invalid"] for key in reasons}
    for name in reasons:
        path = f"logs/{name}.jsonl"
        row = files.get(path)
        if not row:
            reasons[name].append("manifest_file_missing")
            continue
        status = label(row.get("status"))
        if row.get("complete") is not True or status != "complete":
            reasons[name].append("manifest_" + status)
        try:
            size = archive.getinfo(path).file_size
        except KeyError:
            reasons[name].append("archive_file_missing")
            continue
        if number(row.get("archived_bytes")) != size:
            reasons[name].append("manifest_archived_size_mismatch")
        if row.get("complete") is True and number(row.get("source_bytes")) != size:
            reasons[name].append("manifest_source_size_mismatch")
        if name == "events" and row.get("sha256") != hashlib.sha256(compact).hexdigest():
            reasons[name].append("manifest_checksum_mismatch")
    shutdown = files.get("logs/launcher-shutdown.json", {})
    shutdown_incomplete = bool(shutdown) and (
        shutdown.get("complete") is not True or
        shutdown.get("status") != "complete")
    if (manifest.get("complete") is not True and not any(reasons.values())
            and not shutdown_incomplete):
        for name in reasons:
            reasons[name].append("manifest_incomplete")
    return reasons


def audit_shutdown(archive=None):
    """Verify launcher telemetry without equating its status to child exit."""
    result = {
        "available": False, "known": False, "archive_verified": False,
        "child_returncode": None, "child_signal": None,
        "child_running_before_stop": None, "reason": None,
        "launcher_status": None, "recorded_at_unix": None,
        "collection_order": None, "issues": [],
    }
    if archive is None:
        result["issues"].append("shutdown_archive_unavailable")
        return result
    path = "logs/launcher-shutdown.json"
    try:
        info = archive.getinfo(path)
    except KeyError:
        result["issues"].append("shutdown_record_missing")
        return result
    result["available"] = True
    if info.file_size > 4096 or archive.namelist().count(path) != 1:
        result["issues"].append("shutdown_record_size_or_duplicate_invalid")
        return result
    try:
        raw = archive.read(info)
        manifest_info = archive.getinfo("logs/manifest.json")
        if manifest_info.file_size > 65536:
            raise ValueError("Oversized manifest")
        manifest = json.loads(archive.read(manifest_info))
        if not isinstance(manifest, dict) or manifest.get("schema_version") != 1:
            raise ValueError("Invalid manifest")
        records = [r for r in manifest["files"]
                   if isinstance(r, dict) and r.get("path") == path]
        if len(records) != 1:
            raise ValueError("Missing or duplicated shutdown manifest record")
        item = records[0]
        if item.get("complete") is not True or item.get("status") != "complete":
            result["issues"].append("shutdown_manifest_incomplete")
        if (number(item.get("archived_bytes")) != len(raw) or
                number(item.get("source_bytes")) != len(raw)):
            result["issues"].append("shutdown_manifest_size_mismatch")
        if item.get("sha256") != hashlib.sha256(raw).hexdigest():
            result["issues"].append("shutdown_manifest_checksum_mismatch")
    except (KeyError, ValueError, TypeError, zipfile.BadZipFile):
        result["issues"].append("shutdown_manifest_missing_or_invalid")
        return result
    if result["issues"]:
        return result
    result["archive_verified"] = True
    try:
        record = json.loads(raw)
        if not isinstance(record, dict):
            raise ValueError("Invalid record")
        code = record.get("child_returncode")
        child_signal = record.get("child_signal")
        launcher_status = record.get("launcher_status")
        reason = label(record.get("reason"))
        timestamp = number(record.get("recorded_at_unix"))
        expected_signal = -code if type(code) is int and code < 0 else None
        if (type(record.get("schema_version")) is not int or
                record["schema_version"] != 1 or
                record.get("event") != "launcher_child_stopped" or
                (code is not None and type(code) is not int) or
                (child_signal is not None and type(child_signal) is not int) or
                child_signal != expected_signal or
                type(record.get("child_running_before_stop")) is not bool or
                type(launcher_status) is not int or reason == "unknown" or
                timestamp is None or
                record.get("collection_order") !=
                "after_child_reaped_before_archive"):
            raise ValueError("Invalid lifecycle fields")
    except (ValueError, TypeError):
        result["issues"].append("shutdown_record_invalid")
        return result
    result.update({
        "known": code is not None,
        "child_returncode": code, "child_signal": child_signal,
        "child_running_before_stop": record["child_running_before_stop"],
        "reason": reason, "launcher_status": launcher_status,
        "recorded_at_unix": timestamp,
        "collection_order": record["collection_order"],
    })
    if code is None:
        result["issues"].append("child_returncode_unavailable")
    return result


def diagnostic_event(row, phase="unknown"):
    """Separate observed error boundaries without exporting error text."""
    event = label(row.get("event"))
    scope = label(row.get("scope"))
    status = row.get("status")
    if type(status) is not int or not 100 <= status <= 599:
        status = None
    result = {"event": event, "scope": scope, "phase": phase,
              "sequence": count(row.get("sequence")),
              "request_id": count(row.get("request_id")) or None}
    timestamp = row.get("timestamp")
    if isinstance(timestamp, str) and re.fullmatch(
            r"[0-9TZ:+. -]{10,40}", timestamp):
        result["timestamp"] = timestamp
    body = row.get("body")
    body = body if isinstance(body, dict) else {}
    softmax = body.get("softmax_error")
    softmax = softmax if isinstance(softmax, dict) else {}
    if event == "http_response":
        failure = body.get("error")
        incomplete = None
        if scope == "model" and status == 200:
            if body.get("status") in ("incomplete", "failed"):
                incomplete = body["status"]
            choices = body.get("choices")
            if isinstance(choices, list) and choices and isinstance(
                    choices[0], dict):
                finish = choices[0].get("finish_reason")
                if finish in ("length", "content_filter", "tool_calls",
                              "function_call"):
                    incomplete = finish
        if not ((status is not None and status >= 400) or failure or
                softmax or incomplete):
            return None
        result["caller_http_status"] = status
        categories = ("invalid_request", "routing_parameters",
                      "model_unavailable", "model_denied", "spend_limit",
                      "request_rate_limit", "provider_access",
                      "provider_credits", "provider_rate_limit",
                      "provider_unavailable", "provider_error",
                      "provider_response", "provider_transport",
                      "platform_error")
        category = softmax.get("category")
        upstream = softmax.get("upstream_status")
        retryable = softmax.get("retryable")
        result["softmax_error_present"] = bool(softmax)
        result["softmax_category"] = category if category in categories else (
            "other_reported_category" if category is not None else None)
        result["softmax_retryable"] = retryable if type(retryable) is bool else None
        result["softmax_upstream_status"] = upstream if type(upstream) is int \
            and 100 <= upstream <= 599 else None
        call_id = softmax.get("call_id")
        result["softmax_call_id"] = call_id if isinstance(call_id, str) and \
            re.fullmatch(r"[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}",
                         call_id) else None
        result["model_incomplete_reason"] = incomplete
        result["error_body_present"] = bool(failure)
        route = str(row.get("route", ""))
        result["route_kind"] = next((name for name in (
            "playercontext", "orders", "messages") if
            "route=game/" + name in route), "other")
        result["classification"] = (
            "caller_http_error" if status is not None and status >= 400 else
            "model_response_error_body" if failure or softmax else
            "model_incomplete_response_body")
    elif event == "http_transport_error":
        result.update(classification="http_client_exception",
                      exception_type=label(row.get("error_type")),
                      caller_http_status=None)
    elif event in ("error", "exception", "fatal", "model_return", "llm_call"):
        error = row.get("error")
        if not error:
            return None
        value = str(error).lower()
        category = "other_reported_error"
        if scope == "model_response_parse":
            category = "model_envelope_parse_error"
        elif "invalid decision" in value:
            category = "model_decision_validation_error"
        elif "invalid json" in value or "not valid json" in value:
            category = "invalid_json_reported"
        elif "did not complete" in value:
            category = "incomplete_model_response"
        elif "failed or timed out" in value or "failed or exceeded its timeout" in value:
            category = "generic_failure_or_timeout_wording"
        elif "server changed orders" in value:
            category = "server_order_rewrite"
        result.update(classification=category,
                      exception_type=label(row.get("error_type")),
                      caller_http_status=status,
                      fatal=bool(scope == "fatal" or event == "fatal" or
                                 row.get("fatal")))
    elif event in ("process_return", "bot_return", "retry_wait"):
        result["classification"] = event
        if event == "process_return":
            code = row.get("exit_code")
            result["exit_code"] = code if type(code) is int else None
        elif event == "bot_return":
            result["reason"] = label(row.get("reason"))
    else:
        return None
    return result


def audit_error_details(archive):
    """Read bounded full details for error metadata omitted from compact logs."""
    result = {"available": False, "source_verified": False, "issues": [],
              "records": [], "records_omitted": 0, "classifications": {}}
    try:
        info = archive.getinfo("logs/details.jsonl")
        if info.file_size > 128 * 1024 * 1024:
            raise ValueError("Oversized details")
        raw = archive.read(info)
        manifest_info = archive.getinfo("logs/manifest.json")
        if manifest_info.file_size > 65536:
            raise ValueError("Oversized manifest")
        manifest = json.loads(archive.read(manifest_info))
        if not isinstance(manifest, dict) or manifest.get("schema_version") != 1:
            raise ValueError("Invalid manifest schema")
        record = next(r for r in manifest["files"] if
                      isinstance(r, dict) and r.get("path") == info.filename)
    except (KeyError, ValueError, TypeError, StopIteration, zipfile.BadZipFile):
        result["issues"].append("details_missing_or_invalid")
        return result
    result["available"] = True
    if (record.get("complete") is not True or record.get("status") != "complete"
            or record.get("source_bytes") != len(raw) or
            record.get("archived_bytes") != len(raw) or
            record.get("sha256") != hashlib.sha256(raw).hexdigest()):
        result["issues"].append("details_integrity_or_completeness_unverified")
    else:
        result["source_verified"] = True
    classifications = collections.Counter()
    phase = "unknown"
    for line in raw.decode("utf-8", errors="replace").splitlines():
        row = event_from_line(line)
        if row is None:
            continue
        if row.get("event") == "phase_start":
            phase = phase_key(row)
        detail = diagnostic_event(row, phase)
        if detail is not None:
            classifications[detail["classification"]] += 1
            if len(result["records"]) < 2048:
                result["records"].append(detail)
            else:
                result["records_omitted"] += 1
    result["classifications"] = dict(classifications)
    result["note"] = (
        "Ordered observations, not deduplicated incidents. Caller HTTP, "
        "softmax_error, upstream ledger labels, and client exceptions are "
        "different evidence. An upstream_transport_error ledger label alone "
        "does not prove a network cause. No raw messages or bodies exported.")
    return result


def audit_slot(path, slot, policy="unknown", archive_member=None):
    """Audit one slot using bounded summaries of events and model accounting."""
    result = {"slot": slot, "policy": label(policy),
              "log_available": path is not None}
    if path is None:
        result["health"] = "unknown_logs_unavailable"
        result["partial_log_coverage"] = True
        result["coverage_reasons"] = ["logs_unavailable"]
        return result
    events = collections.Counter()
    errors = collections.Counter()
    categories = collections.Counter()
    types = collections.Counter()
    http = collections.defaultdict(collections.Counter)
    request_counts = collections.Counter()
    transport_counts = collections.Counter()
    error_codes = collections.Counter()
    skips = collections.Counter()
    ready_reasons = collections.Counter()
    tasks = collections.Counter()
    governor = collections.Counter()
    plain_errors = collections.Counter()
    exit_codes = collections.Counter()
    phases = collections.defaultdict(collections.Counter)
    ready_phases = set()
    requests = {}
    model_requests = set()
    failed_model_requests = set()
    http_calls = {}
    legacy_calls = []
    generation_ids = set()
    process_ids = set()
    sidecar = []
    estimated = []
    latency = []
    country = None
    first_time = last_time = None
    line_count = parsed_count = truncated_count = duplicate_count = 0
    rejected_decisions = rejected_commits = 0
    fatal_count = 0
    event_artifact_limited = False
    detail_artifact_limited = False
    artifact_coverage = {"events": [], "details": []}
    shutdown = audit_shutdown()
    error_details = {"available": False, "source_verified": False,
                     "issues": ["full_details_unavailable"]}
    seen_sequences = set()
    sequence_values = collections.defaultdict(set)
    if archive_member:
        with zipfile.ZipFile(path) as archive:
            raw = archive.read(archive_member)
            artifact_coverage = manifest_coverage(archive, raw)
            shutdown = audit_shutdown(archive)
            error_details = audit_error_details(archive)
        source_file = io.StringIO(raw.decode("utf-8", errors="replace"))
        source_bytes = len(raw)
    else:
        source_file = path.open(encoding="utf-8", errors="replace")
        source_bytes = path.stat().st_size
    with source_file as source:
        for line in source:
            line_count += 1
            row = event_from_line(line)
            if row is None:
                lower = line.lower()
                for category, needle in PLAIN_ERRORS:
                    if needle.lower() in lower:
                        plain_errors[category] += 1
                for match in EXIT_CODE.finditer(line):
                    exit_codes[match[1]] += 1
                continue
            parsed_count += 1
            event = label(row.get("event"))
            pid = row.get("pid")
            if isinstance(pid, int):
                process_ids.add(pid)
            if isinstance(row.get("sequence"), int):
                sequence_values[pid].add(row["sequence"])
                key = (pid, row["sequence"], row.get("timestamp"))
                if key in seen_sequences:
                    duplicate_count += 1
                    continue
                seen_sequences.add(key)
            events[event] += 1
            stamp = row.get("timestamp", row.get("t"))
            if isinstance(stamp, (int, float)) or (
                    isinstance(stamp, str) and re.fullmatch(
                        r"[0-9TZ:+. -]{10,40}", stamp)):
                first_time = stamp if first_time is None else first_time
                last_time = stamp
            phase = phase_key(row)
            if phase != "unknown":
                phases[phase][event] += 1
            if row.get("truncated") is True:
                truncated_count += 1
            if row.get("artifact_body_limit_reached"):
                detail_artifact_limited = True
            if row.get("artifact_event_limit_reached"):
                event_artifact_limited = True
            if event in {"start", "bot_start", "decision"}:
                candidate = number(row.get("country_id", row.get("country")))
                if candidate is not None and int(candidate) in range(1, 8):
                    country = int(candidate)
            if event == "http_request":
                key = (pid, row.get("request_id"))
                scope = label(row.get("scope"))
                request_counts[scope] += 1
                if scope == "model":
                    model_requests.add(key)
                context = row.get("context") or {}
                body = row.get("body") or {}
                requests[key] = label(context.get("model", body.get("model"))) \
                    if isinstance(context, dict) and isinstance(body, dict) \
                    else "unknown"
            if event == "http_response":
                scope = label(row.get("scope"))
                http[scope][label(row.get("status"))] += 1
                body = row.get("body") or {}
                failure = body.get("error") if isinstance(body, dict) else None
                if isinstance(failure, dict):
                    for key in ("code", "type"):
                        if failure.get(key) is not None:
                            error_codes[label(failure[key])] += 1
                if scope == "model":
                    key = (pid, row.get("request_id"))
                    body = row.get("body") or {}
                    if not isinstance(body, dict):
                        body = {}
                    usage = body.get("usage") or row.get("response_usage") or {}
                    if not isinstance(usage, dict):
                        usage = {}
                    http_calls[key] = usage_call(
                        row, usage, body.get("model", row.get(
                            "response_model", requests.get(key))))
                    elapsed = number(row.get("elapsed_ms"))
                    if elapsed is not None:
                        latency.append(elapsed)
                    failure = body.get("error")
                    if failure:
                        categories[error_category(failure)] += 1
            if event == "model_return":
                key = (pid, row.get("request_id"))
                if key in http_calls and not http_calls[key]["usage_reported"]:
                    http_calls[key] = usage_call(row, row.get("usage") or {})
            if event == "llm_call":
                generation = row.get("generation_id")
                if not generation or generation not in generation_ids:
                    legacy_calls.append(usage_call(row, row))
                    if generation:
                        generation_ids.add(generation)
            if event in {"error", "exception", "http_error", "fatal",
                         "http_transport_error", "bridge_error"}:
                scope = label(row.get("scope", event))
                errors[scope] += 1
                types[label(row.get("error_type", event))] += 1
                categories[error_category(row.get("error", scope))] += 1
                if scope == "fatal" or event == "fatal" or row.get("fatal"):
                    fatal_count += 1
                if event == "http_error":
                    http["game"][label(row.get("code"))] += 1
                if event == "http_transport_error":
                    transport_counts[scope] += 1
                    if scope == "model":
                        failed_model_requests.add((pid, row.get("request_id")))
            elif row.get("error"):
                errors[event] += 1
                categories[error_category(row["error"])] += 1
            if row.get("fatal") and event not in {"error", "exception", "fatal"}:
                fatal_count += 1
            if event == "process_return":
                exit_codes[label(row.get("exit_code"))] += 1
            if event == "child_exit":
                exit_codes[label(row.get("code"))] += 1
            if event == "inference_start":
                tasks[label(row.get("task"))] += 1
            if event == "inference_skipped":
                skips[label(row.get("reason"))] += 1
            if event == "phase_ready":
                ready_reasons[label(row.get("reason"))] += 1
                ready_phases.add(phase)
            if event == "orders_verified" and row.get("ready") is True:
                ready_phases.add(phase)
            if event == "governor":
                governor[label(row.get("level"))] += 1
            if event == "decision":
                rejected_decisions += count(row.get("rejected"))
            if event == "press_commit":
                rejected_commits += count(row.get("rejected"))
            for key in ("sidecar_spend_usd",):
                value = number(row.get(key))
                if value is not None:
                    sidecar.append(value)
            if event in {"sidecar_spend", "spend_return", "spend_sync"}:
                value = number(row.get("spend_usd", row.get("spent_usd")))
                if value is not None:
                    sidecar.append(value)
            for key in ("estimated_spend_usd",):
                value = number(row.get(key))
                if value is not None:
                    estimated.append(value)
    calls = list(http_calls.values()) if http_calls else legacy_calls
    model_summary = summarize_calls(calls)
    coverage_reasons = artifact_coverage["events"][:]
    detail_reasons = artifact_coverage["details"][:]
    is_kutuzov = bool(sequence_values or events["bot_start"] or
                      "kutuzov" in policy.lower())
    if not (events["process_start"] if is_kutuzov else events["start"]):
        coverage_reasons.append("missing_process_start")
    if not (events["process_return"] if is_kutuzov else
            events["finished"] or events["child_exit"]):
        coverage_reasons.append("missing_process_end")
    sequence_gaps = 0
    first_sequence = last_sequence = None
    for sequences in sequence_values.values():
        first, last = min(sequences), max(sequences)
        first_sequence = first if first_sequence is None else min(first_sequence, first)
        last_sequence = last if last_sequence is None else max(last_sequence, last)
        sequence_gaps += last - first + 1 - len(sequences)
        if first > 1 and "missing_initial_sequences" not in coverage_reasons:
            coverage_reasons.append("missing_initial_sequences")
    if sequence_gaps:
        coverage_reasons.append("sequence_gaps")
    if event_artifact_limited or events["artifact_event_limit"]:
        coverage_reasons.append("artifact_event_limit_reached")
    if detail_artifact_limited or events["artifact_body_limit"]:
        detail_reasons.append("artifact_body_limit_reached")
    if truncated_count:
        coverage_reasons.append("truncated_events")
    http_failures = sum(value for statuses in http.values()
                        for status, value in statuses.items()
                        if status.isdigit() and int(status) >= 400)
    model_failures = sum(call["status"].isdigit() and
                         int(call["status"]) >= 400 for call in calls)
    ready_phases.discard("unknown")
    result.update({
        "source": path.name + (":" + archive_member if archive_member else ""),
        "country_id": country,
        "country": COUNTRIES[country - 1] if country else None,
        "bytes": source_bytes,
        "lines": line_count, "parsed_events": parsed_count,
        "unparsed_lines": line_count - parsed_count,
        "duplicate_events_ignored": duplicate_count,
        "partial_log_coverage": bool(coverage_reasons),
        "coverage_reasons": coverage_reasons,
        "partial_detail_coverage": bool(detail_reasons) if archive_member else None,
        "detail_coverage_reasons": detail_reasons,
        "artifact_incomplete_reasons": artifact_coverage,
        "launcher_shutdown": shutdown,
        "error_diagnostics": error_details,
        "first_sequence": first_sequence, "last_sequence": last_sequence,
        "sequence_gaps": sequence_gaps,
        "truncated_events": truncated_count,
        "first_timestamp": first_time, "last_timestamp": last_time,
        "processes_observed": len(process_ids),
        "events": dict(events), "http_statuses": dict(http),
        "http_requests": dict(request_counts),
        "transport_failures": dict(transport_counts),
        "http_error_responses": http_failures,
        "model_failed_responses": model_failures,
        "model_requests_without_outcome": len(
            model_requests - set(http_calls) - failed_model_requests),
        "error_events": sum(errors.values()), "errors_by_scope": dict(errors),
        "error_categories": dict(categories), "error_types": dict(types),
        "error_codes": dict(error_codes),
        "plain_log_error_markers": dict(plain_errors),
        "timeout_reports": categories["timeout"] + plain_errors["timeout"],
        "fatal_events": fatal_count, "exit_codes": dict(exit_codes),
        "models": model_summary,
        "max_sidecar_spend_usd": max(sidecar) if sidecar else None,
        "max_estimated_spend_usd": max(estimated) if estimated else None,
        "model_latency_ms": {
            "mean": round(sum(latency) / len(latency), 2) if latency else None,
            "max": max(latency) if latency else None},
        "inference_tasks": dict(tasks), "inference_skips": dict(skips),
        "economy_fallbacks": events["economy_fallback"],
        "discarded_decisions": events["decision_discarded"],
        "repair_calls": tasks["repair"],
        "verified_order_events": events["orders_verified"],
        "ready_phases": sorted(ready_phases),
        "ready_reasons": dict(ready_reasons),
        "press_sent": events["press_confirmed"] + events["press_out"],
        "press_skipped": events["press_skipped"],
        "press_unconfirmed": errors["press_unconfirmed_no_retry"],
        "governor_levels": dict(governor),
        "rejected_orders_decisions": rejected_decisions,
        "rejected_orders_press_commits": rejected_commits,
        "phases": {key: dict(value) for key, value in sorted(phases.items())},
        "health": "issues_observed" if errors or plain_errors or fatal_count
                  or http_failures or model_failures
                  else "unknown_partial_log_coverage" if coverage_reasons
                  else "no_errors_in_complete_event_log_details_partial"
                  if detail_reasons
                  else "no_errors_in_complete_log",
    })
    return result


def audit_directory(directory):
    """Choose one complete log snapshot per seat and include known empty seats."""
    metadata = directory
    if not (metadata / "selection.json").exists() and (
            metadata.parent / "selection.json").exists():
        metadata = metadata.parent
    selection = read_json(metadata / "selection.json")
    episode = read_json(metadata / "episode.json")
    scoreboard = read_json(metadata / "scoreboard.json")
    participants = {count(row.get("position")): row for row in
                    episode.get("participants", []) if isinstance(row, dict)}
    policies = {i: name for i, name in enumerate(selection.get("slots", []))}
    for slot, participant in participants.items():
        policies[slot] = participant.get("policy_name", policies.get(slot))
    logs = {}
    for base in (directory, directory / "src", directory / "live"):
        for path in sorted(base.glob("slot-*.zip")):
            match = re.fullmatch(r"slot-(\d+)\.zip", path.name)
            if not match:
                continue
            try:
                with zipfile.ZipFile(path) as archive:
                    info = archive.getinfo("logs/events.jsonl")
                    if info.file_size <= 32 * 1024 * 1024:
                        logs.setdefault(int(match[1]), (path, info.filename))
            except (KeyError, OSError, zipfile.BadZipFile):
                continue
        for path in sorted(base.glob("slot-*.log")):
            match = re.fullmatch(r"slot-(\d+)\.log", path.name)
            if match:
                logs.setdefault(int(match[1]), (path, None))
    seats = [audit_slot(logs.get(slot, (None, None))[0], slot,
                        policies.get(slot, "unknown"),
                        logs.get(slot, (None, None))[1])
             for slot in sorted(set(logs) | set(policies))]
    scores = {count(row.get("slot")): row for row in
              scoreboard.get("participants", []) if isinstance(row, dict)}
    for seat in seats:
        country = scores.get(seat["slot"], {}).get("country")
        if country in COUNTRIES:
            seat["country"] = country
            seat["country_id"] = COUNTRIES.index(country) + 1
            seat["country_source"] = "scoreboard"
    return {
        "generated_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "episode_id": label(episode.get("id")),
        "episode_status": label(episode.get("status")),
        "seats": seats,
        "summary": {
            "seats": len(seats),
            "logs_available": sum(seat["log_available"] for seat in seats),
            "partial_logs": sum(seat.get("partial_log_coverage", False)
                                for seat in seats),
            "error_events": sum(seat.get("error_events", 0) for seat in seats),
            "fatal_events": sum(seat.get("fatal_events", 0) for seat in seats),
            "model_calls": sum(seat.get("models", {}).get("calls", 0)
                               for seat in seats),
        },
        "notes": [
            "Missing or partial logs are unknown, not evidence of health.",
            "Durable logs/events.jsonl inside slot ZIPs is preferred to stdout.",
            "Country assignments use scoreboard.json when available.",
            "Error reports may describe the same failure at several layers.",
            "Verified-order events include protocol and engine confirmations.",
            "Provider usage costs, sidecar totals, and estimates stay separate.",
            "Prompt bodies, model replies, press text, and raw errors are omitted.",
        ],
    }


def main():
    """Write a private audit artifact and print only compact seat summaries."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    arguments = parser.parse_args()
    report = audit_directory(arguments.directory)
    destination = arguments.output or arguments.directory / "audit.json"
    destination.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    temporary = destination.with_suffix(destination.suffix + ".tmp")
    with temporary.open("w", encoding="utf-8") as output:
        os.chmod(temporary, 0o600)
        json.dump(report, output, indent=2)
        output.write("\n")
    temporary.replace(destination)
    print(json.dumps({"audit": str(destination), **report["summary"],
                      "seats": [{key: seat.get(key) for key in (
                          "slot", "policy", "country", "health", "error_events",
                          "timeout_reports", "fatal_events", "press_sent")}
                                for seat in report["seats"]]}, indent=2))


if __name__ == "__main__":
    main()
