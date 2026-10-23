"""Add bounded durable diagnostics to the official private-press archive."""

import hashlib
import io
import json
import os
import stat
import tempfile
import time
import zipfile
from pathlib import Path


LOG_DIRECTORY = "/tmp/kutuzov/logs"
FILE_LIMITS = (("launcher-shutdown.json", 4096),
               ("events.jsonl", 32 * 1024 * 1024),
               ("details.jsonl", 128 * 1024 * 1024))
CHUNK_BYTES = 64 * 1024
ARCHIVE_SECONDS = 5.0
MAX_ARCHIVE_BYTES = 200 * 1024 * 1024


def shutdown_output(record):
    """Keep failed telemetry writes from changing launcher control flow."""
    try:
        print(json.dumps(record), flush=True)
    except (OSError, ValueError):
        pass


def record_shutdown(child, reason, launcher_status, was_running):
    """Record the reaped child outcome without inventing a normal bot return."""
    returncode = child.returncode
    record = {
        "schema_version": 1,
        "event": "launcher_child_stopped",
        "recorded_at_unix": time.time(),
        "child_pid": child.pid,
        "child_returncode": returncode,
        "child_signal": -returncode if returncode is not None and returncode < 0 else None,
        "child_running_before_stop": was_running,
        "reason": reason,
        "launcher_status": launcher_status,
        "collection_order": "after_child_reaped_before_archive",
    }
    shutdown_output(record)
    directory = os.environ.get("KUTUZOV_LOG_DIR", LOG_DIRECTORY)
    if not directory:
        return
    temporary = None
    try:
        folder = Path(directory)
        folder.mkdir(parents=True, exist_ok=True)
        descriptor, temporary = tempfile.mkstemp(
            prefix=".launcher-shutdown-", dir=folder)
        with os.fdopen(descriptor, "w") as target:
            json.dump(record, target, sort_keys=True)
            target.write("\n")
            target.flush()
        os.replace(temporary, folder / "launcher-shutdown.json")
    except (OSError, ValueError):
        shutdown_output({"event": "launcher_shutdown_log_failed"})
    finally:
        if temporary is not None:
            try:
                os.unlink(temporary)
            except FileNotFoundError:
                pass
            except OSError:
                pass


def append_logs(archive):
    """Stream diagnostic files before upload, preserving explicit coverage."""
    directory = Path(os.environ.get("KUTUZOV_LOG_DIR", LOG_DIRECTORY))
    deadline = time.monotonic() + ARCHIVE_SECONDS
    records = []
    for name, limit in FILE_LIMITS:
        record = {"path": "logs/" + name, "archived_bytes": 0,
                  "complete": False}
        records.append(record)
        descriptor = None
        try:
            descriptor = os.open(directory / name, os.O_RDONLY |
                                 os.O_NOFOLLOW | os.O_NONBLOCK)
            size = os.fstat(descriptor)
            if not stat.S_ISREG(size.st_mode):
                record["status"] = "not_regular"
                continue
            record["source_bytes"] = size.st_size
            digest = hashlib.sha256()
            remaining = min(size.st_size, limit)
            record["status"] = (
                "size_limit" if size.st_size > limit else "complete")
            with os.fdopen(descriptor, "rb") as source:
                descriptor = None
                with archive.open(record["path"], "w") as target:
                    while remaining:
                        if time.monotonic() >= deadline:
                            record["status"] = "time_limit"
                            break
                        chunk = source.read(min(CHUNK_BYTES, remaining))
                        if not chunk:
                            record["status"] = "source_shortened"
                            break
                        target.write(chunk)
                        digest.update(chunk)
                        record["archived_bytes"] += len(chunk)
                        remaining -= len(chunk)
            record["sha256"] = digest.hexdigest()
            record["complete"] = record["status"] == "complete"
        except FileNotFoundError:
            record["status"] = "missing"
        except (OSError, ValueError):
            # Filesystem exceptions can include paths or other sensitive data.
            record["status"] = "unavailable"
        finally:
            if descriptor is not None:
                os.close(descriptor)
    manifest = {
        "schema_version": 1,
        "files": records,
        "complete": all(record["complete"] for record in records),
        "note": "Files are flushed by the bot before launcher collection. "
                "A limited file can end in a partial JSON line. Missing or "
                "limited files are explicitly recorded here."
    }
    archive.writestr("logs/manifest.json", json.dumps(manifest, sort_keys=True))
    print(json.dumps({"event": "artifact_logs",
                      "complete": manifest["complete"],
                      "files": records}), flush=True)


def bounded_archive(payload):
    """Enforce the actual upload limit while preferring compact diagnostics."""
    if len(payload) <= MAX_ARCHIVE_BYTES:
        return payload
    destination = io.BytesIO()
    with zipfile.ZipFile(io.BytesIO(payload)) as source:
        manifest = json.loads(source.read("logs/manifest.json"))
        manifest["complete"] = False
        for record in manifest["files"]:
            if record["path"] == "logs/details.jsonl":
                record.update(status="omitted_archive_size_limit",
                              complete=False, archived_bytes=0)
                record.pop("sha256", None)
        with zipfile.ZipFile(destination, "w", zipfile.ZIP_DEFLATED,
                             compresslevel=1) as target:
            for name in source.namelist():
                if name == "logs/details.jsonl":
                    continue
                contents = (json.dumps(manifest, sort_keys=True).encode()
                            if name == "logs/manifest.json"
                            else source.read(name))
                target.writestr(name, contents)
    result = destination.getvalue()
    print(json.dumps({"event": "artifact_size_limit",
                      "details_omitted": True,
                      "original_bytes": len(payload),
                      "archive_bytes": len(result)}), flush=True)
    if len(result) > MAX_ARCHIVE_BYTES:
        raise ValueError("Compact artifact exceeds the platform upload limit.")
    return result
