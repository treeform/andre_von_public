"""Run and audit one hosted four-Kutuzov, three-Scott Diplomacy game."""

import argparse
import collections
import contextlib
import datetime
import fcntl
import hashlib
import io
import json
import os
import re
import subprocess
import sys
import time
import uuid
import zipfile
from pathlib import Path
from urllib.parse import urlencode

BASE = "https://softmax.com/api/observatory"
LEAGUE = "league_1bccc63d-cd0a-47d7-92d7-e762797b5f1c"
AUTO = "ply_3d22435e-30a2-4f2a-b037-a5c249583788"
SCOTT = "ply_5b832230-f519-4af8-adda-bb3e02349b7d"
SCOTT_VERSION = "2fcc2040-f729-4486-93cd-56d115621faa"
COUNTRIES = ["England", "France", "Italy", "Germany", "Austria",
             "Turkey", "Russia"]
TERMINAL = {"completed", "failed", "cancelled", "canceled"}


class HostedError(Exception):
    """Report a failed hosted operation without exposing credentials."""


def save(path, value):
    """Atomically save private JSON evidence with restrictive permissions."""
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    temporary = path.with_suffix(path.suffix + ".tmp")
    with temporary.open("w", encoding="utf-8") as output:
        os.chmod(temporary, 0o600)
        json.dump(value, output, indent=2)
        output.write("\n")
    temporary.replace(path)


def read(path):
    """Read a saved JSON response or prepared request."""
    return json.loads(path.read_text(encoding="utf-8"))


def token():
    """Read the existing user credential without displaying its value."""
    value = os.environ.get("SOFTMAX_API_TOKEN")
    if not value:
        credentials = (Path.home() / ".softmax/credentials.yaml").read_text()
        block = re.search(r"(?m)^tokens:\s*\n((?:[ \t]+.*\n?)*)",
                          credentials)
        match = re.search(
            r"(?m)^\s+['\"]?https://softmax\.com/api['\"]?:\s*(.+)$",
            block[1] if block else "")
        value = match[1].strip() if match else None
        if value and value.startswith('"'):
            value = json.loads(value)
        elif value and value.startswith("'"):
            value = value[1:-1].replace("''", "'")
    if not value or any(character in value for character in '\r\n"\\'):
        raise HostedError("No usable Softmax user credential is configured.")
    return value


def audit(directory, event):
    """Append HTTP outcomes and timings without request headers or secrets."""
    path = directory / "hosted-operations.jsonl"
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    event = {"at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
             **event}
    with path.open("a", encoding="utf-8") as output:
        os.chmod(path, 0o600)
        output.write(json.dumps(event) + "\n")


def request(directory, method, path, destination, body=None, optional=False):
    """Call only Softmax, using stdin for credentials and files for bodies."""
    if not path.startswith(("/v2/", "/stats/", "/sql/query")):
        raise HostedError("Unsupported API route.")
    if method not in {"GET", "POST"}:
        raise HostedError("Unsupported HTTP method.")
    destination.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    temporary = destination.with_suffix(destination.suffix + ".part")
    temporary.touch(mode=0o600, exist_ok=True)
    os.chmod(temporary, 0o600)
    config = 'header = "Authorization: Bearer ' + token() + '"\n'
    config += 'header = "X-Use-Elevated-Privileges: true"\n'
    command = ["curl", "-sS", "--connect-timeout", "20", "--max-time",
               "180", "--config", "-", "-X", method, "-o", str(temporary),
               "-w", "%{http_code}", BASE + path]
    if body is not None:
        command.extend(["-H", "Content-Type: application/json",
                        "--data-binary", "@" + str(body)])
    started = time.monotonic()
    result = subprocess.run(command, input=config, text=True,
                            capture_output=True)
    status = result.stdout.strip()
    audit(directory, {"event": "http", "method": method, "path": path,
                      "status": status, "curl_exit": result.returncode,
                      "seconds": round(time.monotonic() - started, 3),
                      "bytes": temporary.stat().st_size})
    if result.returncode or status not in {"200", "201"}:
        if optional and status in {"403", "404"}:
            return False
        raise HostedError(
            f"{method} {path}: HTTP {status or 'unavailable'}, "
            f"curl exit {result.returncode}; response saved to {temporary}. "
            "For an ambiguous submit, rerun submit in this same directory "
            "to reuse its persisted idempotency key.")
    temporary.replace(destination)
    return True


def get_json(directory, path, filename):
    """Fetch fresh metadata and return its decoded JSON object."""
    destination = directory / filename
    request(directory, "GET", path, destination)
    return read(destination)


def uuid_value(value):
    """Require a canonical UUID before using an identifier in SQL."""
    try:
        return str(uuid.UUID(value))
    except ValueError as error:
        raise HostedError("Expected a policy-version UUID.") from error


def entries(value):
    """Normalize list and paginated-list response shapes."""
    return value.get("entries", []) if isinstance(value, dict) else value


def phase_config(directory):
    """Read a phase's explicit one-through-seven game ceiling."""
    config = read(directory / "phase.json")
    maximum = config.get("max_games")
    if (config.get("schema_version") != 1 or type(maximum) is not int or
            maximum < 1 or maximum > 7):
        raise HostedError("phase.json must declare schema_version 1 and "
                          "max_games between 1 and 7.")
    return config


def initialize_phase(arguments):
    """Create immutable local phase limits without making a hosted request."""
    maximum = arguments.max_games
    if maximum < 1 or maximum > 7:
        raise HostedError("An analysis phase may contain between 1 and 7 games.")
    path = arguments.directory / "phase.json"
    if path.exists():
        config = phase_config(arguments.directory)
        if config["max_games"] != maximum:
            raise HostedError("Existing phase limits cannot be changed; "
                              "analyze this phase before starting another.")
    else:
        config = {"schema_version": 1, "max_games": maximum,
                  "created_at": datetime.datetime.now(
                      datetime.timezone.utc).isoformat()}
        save(path, config)
    print(json.dumps(config, indent=2))


def phase_directory(directory, selection, supplied=None):
    """Resolve the persisted phase and require its run to be a descendant."""
    directory = directory.expanduser().resolve()
    stored = selection.get("analysis_phase_dir")
    if not stored:
        raise HostedError("New submissions require a prepared analysis phase; "
                          "use prepare with --analysis-phase-dir.")
    phase = Path(stored).expanduser().resolve()
    if supplied is not None and supplied.expanduser().resolve() != phase:
        raise HostedError("The supplied phase differs from the prepared phase.")
    if directory == phase or not directory.is_relative_to(phase):
        raise HostedError("Each game directory must be inside its analysis phase.")
    phase_config(phase)
    return phase


@contextlib.contextmanager
def phase_lock(phase):
    """Serialize reservations and submits so concurrent processes cannot overrun."""
    with (phase / ".submission.lock").open("a", encoding="utf-8") as lock:
        os.chmod(phase / ".submission.lock", 0o600)
        try:
            fcntl.flock(lock.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as error:
            raise HostedError("Another submission is resolving in this phase; "
                              "retry after it finishes.") from error
        try:
            yield
        finally:
            fcntl.flock(lock.fileno(), fcntl.LOCK_UN)


def reserve_submission(directory, phase, digest, key):
    """Count known games and unresolved attempts before reserving one POST."""
    directory = directory.resolve()
    phase = phase.resolve()
    maximum = phase_config(phase)["max_games"]
    known = set()
    runs = {path.parent for filename in ["submission.json", "created.json"]
            for path in phase.rglob(filename)}
    for run in sorted(runs):
        if run == directory:
            continue
        created = run / "created.json"
        if created.exists():
            detail = read(created)
            if not str(detail.get("id", "")).startswith("xreq_"):
                raise HostedError("A phase run has no valid hosted request ID.")
            if detail.get("episode_count") != 1:
                raise HostedError("A phase run does not contain exactly one game.")
            known.add(detail["id"])
        else:
            raise HostedError("Another submission in this phase has an "
                              "ambiguous outcome. Retry submit in its original "
                              "directory to recover its ID before starting "
                              "another game: " + str(run))
    marker = directory / "submission.json"
    retry = marker.exists()
    reservation = read(marker) if retry else {}
    if reservation and (reservation.get("request_sha256") != digest or
                        reservation.get("idempotency_key") != key):
        raise HostedError("The pending request differs from its reservation.")
    if len(known) + 1 > maximum:
        raise HostedError(f"Analysis phase limit reached ({len(known)}/{maximum}); "
                          "analyze its games before preparing another phase.")
    if not reservation:
        reservation = {
            "request_sha256": digest, "idempotency_key": key,
            "analysis_phase_dir": str(phase),
            "reserved_at": datetime.datetime.now(
                datetime.timezone.utc).isoformat()}
        save(marker, reservation)
    return {"known_games": len(known), "reserved_games": 1,
            "max_games": maximum, "idempotent_retry": retry}


def prepare(arguments):
    """Freeze the exact one-game roster and idempotency key before launch."""
    directory = arguments.directory
    policy = uuid_value(arguments.kutuzov_version)
    player = getattr(arguments, "player_id", AUTO)
    if player not in {AUTO, "ply_607f17a2-3acf-405b-91fe-d12ef1001c00"}:
        raise HostedError("Expected one of the explicitly supported Andre players.")
    path = directory / "request.json"
    if path.exists():
        existing = read(path)
        if existing["roster"][0]["player"]["policy_ref"] != policy:
            raise HostedError("This directory already names another policy.")
        print(json.dumps(read(directory / "selection.json"), indent=2))
        return
    supplied = getattr(arguments, "analysis_phase_dir", None)
    if supplied is None:
        raise HostedError("New games require --analysis-phase-dir. Initialize "
                          "that directory with phase --max-games 1 through 7.")
    phase = phase_directory(directory, {"analysis_phase_dir": str(supplied)},
                            supplied)
    league = get_json(directory, "/v2/leagues/" + LEAGUE, "league.json")
    query = urlencode({"name_exact": "kutuzov", "player_id": player,
                       "limit": 100})
    versions = get_json(directory, "/stats/policy-versions?" + query,
                        "kutuzov-versions.json")
    matches = [version for version in entries(versions)
               if version["id"] == policy]
    if len(matches) != 1:
        raise HostedError("Kutuzov version was not found under the selected player.")
    uploaded = inspect_policy(directory, policy, player_id=player)
    expected_run = ["/opt/.venv/bin/python", "-m", "players.launcher",
                    "/opt/kutuzov"]
    if uploaded["run"] != expected_run:
        raise HostedError("Uploaded launcher argv is incorrect; inspect policy.json.")
    if not uploaded["has_secret_env"]:
        raise HostedError("Uploaded policy has no LLM sidecar secret environment.")
    query = urlencode({"league_id": LEAGUE, "player_id": SCOTT,
                       "champions_only": "true", "active_only": "true",
                       "limit": 100})
    memberships = get_json(directory, "/v2/league-policy-memberships?" + query,
                           "scott-memberships.json")
    champions = [entry for entry in entries(memberships)
                 if entry.get("is_champion")]
    if not any(entry["policy_version"]["id"] == SCOTT_VERSION
               for entry in champions):
        raise HostedError("Scott v15 is no longer the active champion; review "
                          "the saved membership response before preparing.")
    config = {"press": "Regular", "end_year": 1908,
              "phase_minutes": 3, "retreat_build_minutes": 1}
    if arguments.fixed_countries:
        config["countries"] = list(range(1, 8))
    roster = [{"player": {"policy_ref": policy if slot % 2 == 0
                           else SCOTT_VERSION}, "slot": slot}
              for slot in range(7)]
    body = {
        "idempotency_key": "kutuzov-four-scott-three-" + str(uuid.uuid4()),
        "private": False, "target": {"league_id": LEAGUE},
        "roster": roster, "num_episodes": 1,
        "game_config_overrides": config,
        "notes": "Operational audit: four Kutuzov seats versus three "
                 "macromackie scott-pidip:v15 seats. All powers act "
                 "independently; one game, not a league submission."
    }
    selection = {
        "kutuzov_version_id": policy,
        "kutuzov_player_id": player,
        "kutuzov_label": "kutuzov:v" + str(matches[0]["version"]),
        "scott_version_id": SCOTT_VERSION, "scott_label": "scott-pidip:v15",
        "league_id": LEAGUE,
        "analysis_phase_dir": str(phase),
        "player_pod_limit_usd": league["settings"].get(
            "episode_player_pod_llm_spend_limit_usd"),
        "countries": "fixed" if arguments.fixed_countries else "seeded random",
        "slots": ["Kutuzov" if slot % 2 == 0 else "Scott"
                  for slot in range(7)],
        "num_episodes": 1
    }
    save(directory / "selection.json", selection)
    save(path, body)
    print(json.dumps(selection, indent=2))


def verify(directory, detail):
    """Verify exactly one episode with the seven intended policy positions."""
    body = read(directory / "request.json")
    if detail.get("episode_count") != 1 or len(detail.get("episodes", [])) != 1:
        raise HostedError("Softmax did not return exactly one episode.")
    expected = [entry["player"]["policy_ref"] for entry in body["roster"]]
    episode = detail["episodes"][0]
    participants = sorted(episode["participants"],
                          key=lambda participant: participant["position"])
    if [participant["policy_version_id"] for participant in participants] != expected:
        raise HostedError("Hosted roster differs from the prepared request.")
    if [participant["position"] for participant in participants] != list(range(7)):
        raise HostedError("Hosted roster does not contain exactly seven seats.")
    return episode


def show(directory, detail):
    """Print a compact status while preserving full responses on disk."""
    episode = verify(directory, detail)
    print(json.dumps({"experience_request_id": detail["id"],
                      "status": detail["status"], "episode_id": episode["id"],
                      "episode_status": episode["status"],
                      "cost_preview": detail.get("cost_preview"),
                      "roster_verified": True}, indent=2))


def submit(arguments):
    """Submit only the persisted request, reusing its key after interruption."""
    directory = arguments.directory
    path = directory / "request.json"
    body = read(path)
    if body.get("num_episodes") != 1 or len(body.get("roster", [])) != 7:
        raise HostedError("Only the prepared seven-seat, one-game request is allowed.")
    selection = read(directory / "selection.json")
    expected = [{"player": {"policy_ref": selection["kutuzov_version_id"]
                             if slot % 2 == 0 else SCOTT_VERSION}, "slot": slot}
                for slot in range(7)]
    if body["roster"] != expected or body.get("target") != {"league_id": LEAGUE}:
        raise HostedError("The request must retain the prepared four-versus-three roster.")
    if not body.get("idempotency_key"):
        raise HostedError("Prepared request lacks an idempotency key.")
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    marker = directory / "submission.json"
    if marker.exists() and read(marker)["request_sha256"] != digest:
        raise HostedError("The request changed after submission was attempted.")
    created = directory / "created.json"
    if created.exists():
        show(directory, read(created))
        return
    phase = phase_directory(directory, selection,
                            getattr(arguments, "analysis_phase_dir", None))
    with phase_lock(phase):
        if created.exists():
            show(directory, read(created))
            return
        reservation = reserve_submission(directory, phase, digest,
                                         body["idempotency_key"])
        audit(directory, {"event": "phase_submission", **reservation})
        request(directory, "POST", "/v2/experience-requests", created, body=path)
        show(directory, read(created))


def status(arguments):
    """Read fresh request status without starting or modifying any game."""
    directory = arguments.directory
    identifier = read(directory / "created.json")["id"]
    detail = get_json(directory, "/v2/experience-requests/" + identifier,
                      "status.json")
    show(directory, detail)
    return verify(directory, detail)


def sql(directory, name, query):
    """Execute a fixed read-only query and retain both query and response."""
    if not query.lstrip().upper().startswith("SELECT "):
        raise HostedError("Only read-only SELECT statements are supported.")
    body = directory / (name + "-query.json")
    destination = directory / (name + ".json")
    save(body, {"query": query})
    request(directory, "POST", "/sql/query", destination, body=body)
    response = read(destination)
    return [dict(zip(response["columns"], row)) for row in response["rows"]]


def inspect_policy(directory, identifier, player_id=AUTO):
    """Verify owner and execution metadata without reading secret values."""
    identifier = uuid_value(identifier)
    rows = sql(directory, "policy", (
        "SELECT p.name, pv.version, pv.player_id, pv.attributes->'run' AS run, "
        "pv.policy_secret_env_id IS NOT NULL AS has_secret_env, "
        "c.image_digest, c.status AS image_status "
        "FROM policy_versions pv JOIN policies p ON p.id = pv.policy_id "
        "LEFT JOIN container_images c "
        "ON c.container_image_id = pv.container_image_id "
        f"WHERE pv.id = '{identifier}'"))
    if len(rows) != 1 or rows[0]["player_id"] != player_id:
        raise HostedError("Uploaded policy is not owned by the selected Andre player.")
    return rows[0]


def usage_log(path):
    """Prefer bounded archived events and report their file integrity coverage."""
    metadata = {"logged_source": "stdout", "logged_coverage": "stdout_unknown",
                "logged_coverage_reasons": []}
    archive_path = path.with_suffix(".zip")
    if archive_path.exists():
        try:
            with zipfile.ZipFile(archive_path) as archive:
                info = archive.getinfo("logs/events.jsonl")
                if info.file_size > 32 * 1024 * 1024 + 4096:
                    raise ValueError("Archived events exceed their size limit.")
                raw = archive.read(info)
                metadata["logged_source"] = "artifact:logs/events.jsonl"
                reasons = metadata["logged_coverage_reasons"]
                try:
                    info = archive.getinfo("logs/manifest.json")
                    if info.file_size > 65536:
                        raise ValueError("Oversized log manifest.")
                    manifest = json.loads(archive.read(info))
                    if not isinstance(manifest, dict) or not isinstance(
                            manifest.get("files"), list):
                        raise ValueError("Invalid log manifest structure.")
                    record = next(row for row in manifest["files"]
                                  if isinstance(row, dict) and
                                  row.get("path") == "logs/events.jsonl")
                    if manifest.get("schema_version") != 1:
                        reasons.append("manifest_schema")
                    if record.get("complete") is not True:
                        reasons.append("manifest_" + str(record.get("status")))
                    if (record.get("archived_bytes") != len(raw) or
                            record.get("source_bytes") != len(raw)):
                        reasons.append("manifest_size_mismatch")
                    if record.get("sha256") != hashlib.sha256(raw).hexdigest():
                        reasons.append("manifest_checksum_mismatch")
                except (KeyError, StopIteration, ValueError, TypeError,
                        zipfile.BadZipFile):
                    reasons.append("manifest_missing_or_invalid")
                metadata["logged_coverage"] = (
                    "partial_archive_file" if reasons else "complete_archive_file")
                return raw.decode("utf-8", errors="replace"), metadata
        except KeyError:
            metadata["logged_coverage_reasons"].append("artifact_events_absent")
        except (OSError, ValueError, RuntimeError, zipfile.BadZipFile):
            metadata["logged_source"] = "stdout"
            metadata["logged_coverage"] = "stdout_unknown"
            metadata["logged_coverage_reasons"].append("artifact_events_unreadable")
    if not path.exists():
        return None, metadata
    return path.read_text(encoding="utf-8", errors="replace"), metadata


def call_keys(row, body=None):
    """Identify duplicate full and compact responses without token-value guesses."""
    body = body if isinstance(body, dict) else {}
    keys = []
    for value in [body.get("id"), row.get("response_id"),
                  row.get("generation_id"), row.get("response_generation_id")]:
        if value is not None:
            keys.append(("response", str(value)))
    if row.get("request_id") is not None:
        keys.append(("request", str(row.get("pid", "")),
                     str(row["request_id"])))
    return keys


def log_usage(path):
    """Read full or compact provider usage, with explicit source coverage."""
    contents, metadata = usage_log(path)
    if contents is None:
        return {"policy_log_present": False, **metadata}
    calls = []
    estimates = []
    sidecar_readings = []
    legacy_readings = []
    invalid = 0
    with io.StringIO(contents) as source:
        for line in source:
            try:
                row = json.loads(line)
            except ValueError:
                invalid += 1
                continue
            if not isinstance(row, dict):
                invalid += 1
                continue
            if row.get("event") == "llm_call":
                if row.get("estimated_spend_usd") is not None:
                    estimates.append(float(row["estimated_spend_usd"]))
                if row.get("sidecar_spend_usd") is not None:
                    sidecar_readings.append(float(row["sidecar_spend_usd"]))
                if row.get("[REDACTED]_spend_usd") is not None:
                    legacy_readings.append(float(row["[REDACTED]_spend_usd"]))
                if "cost_usd" in row:
                    calls.append({"keys": call_keys(row),
                                  "model": row.get("model"),
                                  "cost": row["cost_usd"],
                                  "input": row.get("prompt_tokens", 0),
                                  "output": row.get("completion_tokens", 0),
                                  "cached": row.get("cached_tokens", 0)})
            elif row.get("event") == "spend_sync":
                if row.get("spent_usd") is not None:
                    sidecar_readings.append(float(row["spent_usd"]))
            elif row.get("event") == "spend_return":
                if row.get("available") and row.get("spend_usd") is not None:
                    sidecar_readings.append(float(row["spend_usd"]))
            elif row.get("event") == "http_response" and row.get("scope") == "model":
                body = row.get("body")
                body = body if isinstance(body, dict) else {}
                usage = body.get("usage") or row.get("response_usage")
                if isinstance(usage, dict) and not usage.get("omitted"):
                    details = usage.get("prompt_tokens_details") or usage.get(
                        "input_tokens_details") or {}
                    calls.append({"keys": call_keys(row, body),
                                  "model": body.get("model") or row.get("response_model"),
                                  "cost": usage.get("cost"),
                                  "input": usage.get("prompt_tokens", usage.get("input_tokens", 0)),
                                  "output": usage.get("completion_tokens", usage.get("output_tokens", 0)),
                                  "cached": details.get("cached_tokens", 0)})
            elif row.get("event") in ["artifact_event_limit", "artifact_log_write_failed",
                                      "artifact_log_init_failed"]:
                metadata["logged_coverage_reasons"].append(row["event"])
                if metadata["logged_source"].startswith("artifact:"):
                    metadata["logged_coverage"] = "partial_archive_file"
    seen = set()
    unique = []
    for call in calls:
        if any(key in seen for key in call["keys"]):
            seen.update(call["keys"])
            continue
        seen.update(call["keys"])
        unique.append(call)
    costs = [float(call["cost"]) for call in unique if call["cost"] is not None]
    if invalid and metadata["logged_source"].startswith("artifact:"):
        metadata["logged_coverage_reasons"].append("unparseable_log_lines")
        metadata["logged_coverage"] = "partial_archive_file"
    inputs = sum(call["input"] for call in unique)
    cached = sum(call["cached"] for call in unique)
    return {"policy_log_present": True, "logged_calls": len(unique),
            **metadata,
            "logged_parse_errors": invalid,
            "logged_models": sorted({call["model"] for call in unique
                                      if isinstance(call["model"], str)}),
            "logged_usage_cost_calls": len(costs),
            "logged_usage_cost_usd": sum(costs) if costs else None,
            "logged_input_tokens": inputs,
            "logged_output_tokens": sum(call["output"] for call in unique),
            "logged_cached_tokens": cached,
            "logged_cache_fraction": cached / inputs if inputs else None,
            "logged_estimated_spend_usd": max(estimates) if estimates else None,
            "logged_sidecar_spend_usd": (
                max(sidecar_readings) if sidecar_readings else
                max(legacy_readings) if legacy_readings else None),
            "logged_sidecar_legacy_only": bool(legacy_readings) and
                not sidecar_readings}


def spend(directory, episode, quiet=False):
    """Read billing for the current job without combining retried games."""
    identifier = uuid_value(episode["id"].removeprefix("ereq_"))
    if not episode.get("job_id"):
        raise HostedError("Spend is unavailable until a job is assigned.")
    job = uuid_value(episode["job_id"])
    created = datetime.datetime.fromisoformat(
        (episode.get("dispatched_at") or episode["created_at"])
        .replace("Z", "+00:00")).isoformat()
    where = (
        f"a.timestamp >= '{created}'::timestamptz "
        f"AND a.timestamp < '{created}'::timestamptz + interval '3 hours' "
        f"AND a.request_metadata->>'episode_request_id' = '{identifier}' "
        f"AND a.request_metadata->>'job_request_id' = '{job}' "
        "AND a.request_metadata->>'role' = 'player'")
    attempts = sql(directory, "llm-attempts", (
        "SELECT a.request_metadata->>'slot' AS slot, a.canonical_model, "
        "a.policy_result, a.status_code, a.error_type, count(*) AS attempts, "
        "max(a.budget_cap_usd) AS cap_usd, "
        "max(a.recorded_spend_after_usd) AS sidecar_spend_usd, "
        "avg(a.latency_ms) AS mean_latency_ms, "
        "max(a.latency_ms) AS max_latency_ms "
        "FROM llm_attempt_events a WHERE " + where +
        " GROUP BY 1,2,3,4,5 ORDER BY 1,2,3,4,5"))
    providers = sql(directory, "llm-provider-spend", (
        "SELECT a.request_metadata->>'slot' AS slot, "
        "p.resolved_model, p.status, count(*) AS billed_calls, "
        "sum(p.input_tokens) AS input_tokens, "
        "sum(p.output_tokens) AS output_tokens, "
        "sum(p.cache_read_tokens) AS cache_read_tokens, "
        "sum(p.cache_write_tokens) AS cache_write_tokens, "
        "sum(p.reasoning_tokens) AS reasoning_tokens, "
        "sum(p.billed_cost_usd) AS billed_cost_usd "
        "FROM llm_attempt_events a JOIN llm_provider_events p "
        "ON p.platform_call_id = a.platform_call_id WHERE " + where +
        " GROUP BY 1,2,3 ORDER BY 1,2,3"))
    totals = collections.defaultdict(lambda: {
        "attempts": 0, "http_errors": 0, "sidecar_spend_usd": 0.0,
        "provider_calls": 0, "provider_billed_usd": 0.0,
        "input_tokens": 0, "output_tokens": 0, "cache_read_tokens": 0,
        "cache_write_tokens": 0})
    for row in attempts:
        total = totals[int(row["slot"])]
        total["attempts"] += row["attempts"]
        total["http_errors"] += row["attempts"] if (
            row["status_code"] is not None and row["status_code"] >= 400) else 0
        total["sidecar_spend_usd"] = max(
            total["sidecar_spend_usd"], float(row["sidecar_spend_usd"] or 0))
    for row in providers:
        total = totals[int(row["slot"])]
        total["provider_calls"] += row["billed_calls"]
        total["provider_billed_usd"] += float(row["billed_cost_usd"] or 0)
        for key in ["input_tokens", "output_tokens", "cache_read_tokens",
                    "cache_write_tokens"]:
            total[key] += int(row[key] or 0)
    participants = {participant["position"]: participant
                    for participant in episode["participants"]}
    summary = [{"slot": slot, "policy": participants[slot]["policy_name"],
                "version": participants[slot]["version"],
                "telemetry_present": slot in totals, **totals[slot],
                **log_usage(directory / f"slot-{slot}.log")}
               for slot in range(7)]
    save(directory / "spend-summary.json", {
        "job_request_id": job,
        "billing_scope": "current_job_attempt",
        "note": "Provider ingestion can lag. Missing telemetry is unknown, "
                "not zero actual spend. Retried jobs are separate games; "
                "this summary includes only the metadata's current job. "
                "Compare with policy usage.cost logs; "
                "external models may report a zero sidecar total. Provider "
                "input_tokens excludes cached tokens: the cache denominator "
                "is input_tokens + cache_read_tokens + cache_write_tokens. "
                "Prefer raw response usage.prompt_tokens for the final "
                "cache ratio when policy logs are available.",
        "participants": summary})
    if not quiet:
        print(json.dumps(summary, indent=2))
    return summary


def live(arguments):
    """Snapshot available runtime evidence without requiring game completion."""
    directory = arguments.directory
    episode = status(arguments)
    identifier = episode["id"]
    episode = get_json(directory, "/v2/episode-requests/" + identifier,
                       "episode.json")
    prefix = "/v2/episode-requests/" + identifier
    destination = directory / "live"
    destination.mkdir(parents=True, exist_ok=True, mode=0o700)
    available = {}
    for artifact, filename in [("logs", "game.log"),
                               ("player-status", "player-status.json"),
                               ("error-info", "error-info.json")]:
        available[filename] = request(
            directory, "GET", prefix + "/artifacts/" + artifact,
            destination / filename, optional=True)
    for participant in episode["participants"]:
        slot = participant["position"]
        policy = participant["policy_version_id"]
        filename = f"slot-{slot}.log"
        available[filename] = request(
            directory, "GET", f"{prefix}/{policy}/policy-logs/{slot}",
            destination / filename, optional=True)
    costs = spend(destination, episode, quiet=True)
    attempts = read(destination / "llm-attempts.json")
    summary = {
        "at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "episode_id": identifier, "status": episode["status"],
        "available": available, "participants": costs,
        "model_statuses": [dict(zip(attempts["columns"], row))
                           for row in attempts["rows"]],
        "note": "Runtime log artifacts may appear only after container exit. "
                "Unavailable logs and delayed telemetry do not prove health."
    }
    save(destination / "snapshot.json", summary)
    audit(directory, {"event": "live_snapshot", "episode_id": identifier,
                      "status": episode["status"], "available": available})
    print(json.dumps(summary, indent=2))


def download(arguments):
    """Download authoritative results, logs and archives without extracting ZIPs."""
    directory = arguments.directory
    episode = status(arguments)
    identifier = episode["id"]
    episode = get_json(directory, "/v2/episode-requests/" + identifier,
                       "episode.json")
    if episode["status"] not in TERMINAL:
        raise HostedError("The game is still running; use status before download.")
    prefix = "/v2/episode-requests/" + identifier
    request(directory, "GET", prefix + "/bundle", directory / "bundle.zip")
    for artifact, filename in [
            ("results", "results.json"), ("logs", "game.log"),
            ("player-status", "player-status.json"),
            ("error-info", "error-info.json"), ("replay", "game.replay")]:
        request(directory, "GET", prefix + "/artifacts/" + artifact,
                directory / filename, optional=True)
    for participant in episode["participants"]:
        slot = participant["position"]
        policy = participant["policy_version_id"]
        for endpoint, extension in [("policy-logs", "log"),
                                    ("policy-artifact", "zip")]:
            request(directory, "GET", f"{prefix}/{policy}/{endpoint}/{slot}",
                    directory / f"slot-{slot}.{extension}", optional=True)
    result_path = directory / "results.json"
    if result_path.exists():
        results = read(result_path)
        rows = []
        members = {int(member["countryID"]): member
                   for member in results.get("members", [])}
        for participant in sorted(episode["participants"],
                                  key=lambda value: value["position"]):
            slot = participant["position"]
            country = results["countries"][slot]
            member = members.get(country, {})
            rows.append({"slot": slot, "country": results.get("roles", [
                COUNTRIES[value - 1] for value in results["countries"]])[slot],
                "policy": participant["policy_name"],
                "version": participant["version"],
                "score": results["scores"][slot],
                "centers": int(member.get("supplyCenterNo", 0)),
                "status": member.get("status")})
        save(directory / "scoreboard.json", {
            "outcome": results.get("outcome"), "reason": results.get("reason"),
            "participants": rows,
            "note": "Scores are per independent country, not team scores. "
                    "Non-solo score is surviving centers squared divided by "
                    "all surviving centers squared; a solo scores one."})
        print(json.dumps(read(directory / "scoreboard.json"), indent=2))
    spend(directory, episode)


def main():
    """Dispatch explicit preparation, launch, status and evidence operations."""
    os.umask(0o077)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", required=True, type=Path,
                        help="Private evidence directory; reuse it after interruption.")
    parser.add_argument("--analysis-phase-dir", type=Path,
                        help="Parent phase directory containing phase.json.")
    commands = parser.add_subparsers(dest="command", required=True)
    phase_parser = commands.add_parser("phase")
    phase_parser.add_argument("--max-games", required=True, type=int)
    prepare_parser = commands.add_parser("prepare")
    prepare_parser.add_argument("--kutuzov-version", required=True)
    prepare_parser.add_argument("--fixed-countries", action="store_true")
    commands.add_parser("submit")
    commands.add_parser("status")
    commands.add_parser("download")
    commands.add_parser("spend")
    commands.add_parser("live")
    inspect_parser = commands.add_parser("inspect")
    inspect_parser.add_argument("--kutuzov-version", required=True)
    arguments = parser.parse_args()
    arguments.directory = arguments.directory.expanduser().resolve()
    if arguments.command == "phase":
        initialize_phase(arguments)
    elif arguments.command == "prepare":
        prepare(arguments)
    elif arguments.command == "submit":
        submit(arguments)
    elif arguments.command == "status":
        status(arguments)
    elif arguments.command == "download":
        download(arguments)
    elif arguments.command == "live":
        live(arguments)
    elif arguments.command == "inspect":
        print(json.dumps(inspect_policy(arguments.directory,
                                        arguments.kutuzov_version), indent=2))
    else:
        episode = status(arguments)
        spend(arguments.directory, episode)


if __name__ == "__main__":
    try:
        main()
    except (HostedError, OSError, ValueError, KeyError) as error:
        print(f"hosted.py: {error}", file=sys.stderr)
        sys.exit(1)
