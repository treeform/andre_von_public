"""Keep child outcomes distinct from launcher status in offline archives."""

import hashlib
import importlib.util
import io
import json
import tempfile
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("audit", ROOT / "tools/audit.py")
AUDIT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(AUDIT)
EVENTS = b'{"event":"process_start","pid":9,"sequence":1}\n'
MISSING = object()


def lifecycle(code=-15, running=True, launcher_status=0):
    """Build the exact schema emitted after the launcher reaps its child."""
    return {
        "schema_version": 1, "event": "launcher_child_stopped",
        "recorded_at_unix": 1792107502.25, "child_pid": 9,
        "child_returncode": code,
        "child_signal": -code if code is not None and code < 0 else None,
        "child_running_before_stop": running, "reason": "game_over",
        "launcher_status": launcher_status,
        "collection_order": "after_child_reaped_before_archive",
    }


def archive_bytes(record=MISSING, manifest_change=None, raw=None):
    """Build small archives with independently controlled integrity evidence."""
    files = {"logs/events.jsonl": EVENTS, "logs/details.jsonl": EVENTS}
    if record is not MISSING:
        files["logs/launcher-shutdown.json"] = (
            raw if raw is not None else json.dumps(record).encode() + b"\n")
    manifest = {
        "schema_version": 1, "complete": True,
        "files": [{"path": path, "source_bytes": len(data),
                   "archived_bytes": len(data), "complete": True,
                   "status": "complete",
                   "sha256": hashlib.sha256(data).hexdigest()}
                  for path, data in files.items()],
    }
    if manifest_change:
        manifest_change(manifest)
    destination = io.BytesIO()
    with zipfile.ZipFile(destination, "w", zipfile.ZIP_DEFLATED) as archive:
        for path, data in files.items():
            archive.writestr(path, data)
        archive.writestr("logs/manifest.json", json.dumps(manifest))
    return destination.getvalue()


def inspect(payload):
    """Read shutdown evidence without any launcher or network activity."""
    with zipfile.ZipFile(io.BytesIO(payload)) as archive:
        return AUDIT.audit_shutdown(archive)


def corrupt_checksum(manifest):
    """Keep plausible metadata while making payload integrity fail."""
    manifest["files"][-1]["sha256"] = "0" * 64


def incomplete_shutdown(manifest):
    """Limit only the lifecycle record, leaving both log files complete."""
    manifest["complete"] = False
    manifest["files"][-1].update(complete=False, status="time_limit")


def checks():
    """Cover normal exits, stop signals, old archives, and malformed records."""
    for code, running, launcher_status in (
            (-15, True, 0), (-9, True, 0), (0, False, 0), (7, False, 7)):
        record = lifecycle(code, running, launcher_status)
        result = inspect(archive_bytes(record))
        assert result["known"] and result["archive_verified"]
        assert result["child_returncode"] == code
        assert result["child_signal"] == record["child_signal"]
        assert result["launcher_status"] == launcher_status
        assert result["child_running_before_stop"] is running
        assert result["reason"] == "game_over"
        assert not result["issues"]
        assert "launcher_stop_requested" not in result

    old = inspect(archive_bytes())
    assert not old["available"] and not old["known"]
    assert old["child_returncode"] is None
    assert old["launcher_status"] is None
    assert old["issues"] == ["shutdown_record_missing"]

    bad = inspect(archive_bytes(lifecycle(), corrupt_checksum))
    assert not bad["known"] and not bad["archive_verified"]
    assert bad["child_returncode"] is None
    assert "shutdown_manifest_checksum_mismatch" in bad["issues"]

    limited = archive_bytes(lifecycle(), incomplete_shutdown)
    assert not inspect(limited)["known"]
    with zipfile.ZipFile(io.BytesIO(limited)) as archive:
        assert AUDIT.manifest_coverage(archive, EVENTS) == {
            "events": [], "details": []}

    oversized = inspect(archive_bytes(lifecycle(), raw=b" " * 4097))
    assert not oversized["known"]
    malformed = inspect(archive_bytes(lifecycle(), raw=b"not JSON"))
    assert malformed["archive_verified"] and not malformed["known"]
    assert malformed["issues"] == ["shutdown_record_invalid"]

    for field, value in (("child_signal", None), ("child_signal", True),
                         ("child_returncode", "-15"),
                         ("child_running_before_stop", 1),
                         ("launcher_status", True),
                         ("collection_order", "before_child_reaped"),
                         ("reason", "https://private.invalid/auth-secret")):
        record = lifecycle()
        record[field] = value
        result = inspect(archive_bytes(record))
        assert not result["known"], field
        assert result["child_returncode"] is None
        assert "auth-secret" not in json.dumps(result)

    unavailable = inspect(archive_bytes(lifecycle(None)))
    assert unavailable["archive_verified"] and not unavailable["known"]
    assert unavailable["child_returncode"] is None
    assert unavailable["issues"] == ["child_returncode_unavailable"]

    with tempfile.TemporaryDirectory() as temporary:
        path = Path(temporary) / "slot-2.zip"
        path.write_bytes(archive_bytes(lifecycle()))
        slot = AUDIT.audit_slot(
            path, 2, "kutuzov", archive_member="logs/events.jsonl")
        assert slot["partial_log_coverage"]
        assert "missing_process_end" in slot["coverage_reasons"]
        assert slot["launcher_shutdown"]["child_returncode"] == -15
        assert slot["launcher_shutdown"]["launcher_status"] == 0
        assert slot["exit_codes"] == {}
        assert slot["fatal_events"] == 0
        path.write_bytes(archive_bytes())
        old_slot = AUDIT.audit_slot(
            path, 2, "kutuzov", archive_member="logs/events.jsonl")
        assert old_slot["launcher_shutdown"]["child_returncode"] is None
        assert old_slot["partial_log_coverage"]
    print("Offline shutdown audit checks passed; no processes or network used.")


checks()
