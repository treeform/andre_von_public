"""Check compact and archived spend parsing without platform requests."""

import hashlib
import importlib.util
import json
import tempfile
import zipfile
from pathlib import Path


HELPER = Path(__file__).resolve().parents[1] / "tools" / "hosted.py"


def encoded(rows):
    """Serialize compact fixture events exactly as JSONL."""
    return ("\n".join(json.dumps(row) for row in rows) + "\n").encode()


def artifact(path, rows, complete=True, checksum=None):
    """Build a private in-memory-style fixture with explicit coverage metadata."""
    raw = encoded(rows)
    manifest = {"schema_version": 1, "complete": complete, "files": [{
        "path": "logs/events.jsonl", "source_bytes": len(raw),
        "archived_bytes": len(raw), "complete": complete,
        "status": "complete" if complete else "time_limit",
        "sha256": checksum or hashlib.sha256(raw).hexdigest()}]}
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as archive:
        archive.writestr("logs/events.jsonl", raw)
        archive.writestr("logs/manifest.json", json.dumps(manifest))


def main():
    """Keep raw, compact, archived, and missing usage accounting distinct."""
    spec = importlib.util.spec_from_file_location("hosted", HELPER)
    hosted = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(hosted)
    usage = {"prompt_tokens": 1000, "completion_tokens": 25, "cost": 0.003,
             "prompt_tokens_details": {"cached_tokens": 800}}
    compact = {"event": "http_response", "scope": "model", "pid": 9,
               "request_id": 7, "response_usage": usage,
               "response_model": "openai/gpt-6.1-sol", "body_omitted": True}
    full = {"event": "http_response", "scope": "model", "pid": 9,
            "request_id": 7, "body": {"id": "generation-a", "usage": usage,
                                       "model": "openai/gpt-6.1-sol"}}
    second = {**compact, "request_id": 8, "response_id": "generation-b"}
    with tempfile.TemporaryDirectory() as temporary:
        path = Path(temporary) / "slot-0.log"
        path.write_bytes(encoded([compact]))
        summary = hosted.log_usage(path)
        assert summary["logged_calls"] == 1
        assert summary["logged_usage_cost_usd"] == 0.003
        assert summary["logged_cache_fraction"] == 0.8
        assert summary["logged_models"] == ["openai/gpt-6.1-sol"]
        assert summary["logged_source"] == "stdout"
        # A matching request ID deduplicates compact/full versions of one call.
        path.write_bytes(encoded([compact, full, second, second]))
        summary = hosted.log_usage(path)
        assert summary["logged_calls"] == 2
        assert summary["logged_input_tokens"] == 2000
        assert summary["logged_usage_cost_usd"] == 0.006
        # Archived compact events take precedence over a short stdout tail.
        path.write_bytes(encoded([second]))
        artifact(path.with_suffix(".zip"), [compact, second])
        summary = hosted.log_usage(path)
        assert summary["logged_calls"] == 2
        assert summary["logged_source"] == "artifact:logs/events.jsonl"
        assert summary["logged_coverage"] == "complete_archive_file"
        assert summary["logged_coverage_reasons"] == []
        path.unlink()
        assert hosted.log_usage(path)["logged_calls"] == 2
        artifact(path.with_suffix(".zip"), [compact], complete=False)
        assert hosted.log_usage(path)["logged_coverage"] == "partial_archive_file"
        artifact(path.with_suffix(".zip"), [compact], checksum="incorrect")
        assert "manifest_checksum_mismatch" in hosted.log_usage(path)["logged_coverage_reasons"]
        artifact(path.with_suffix(".zip"), [compact, {"event": "artifact_event_limit"}])
        assert "artifact_event_limit" in hosted.log_usage(path)["logged_coverage_reasons"]
        path.with_suffix(".zip").unlink()
        scott = {"event": "llm_call", "generation_id": "scott-a",
                 "model": "external", "cost_usd": 0.04,
                 "prompt_tokens": 2000, "completion_tokens": 80,
                 "cached_tokens": 1500}
        path.write_bytes(encoded([scott, scott]))
        summary = hosted.log_usage(path)
        assert summary["logged_calls"] == 1
        assert summary["logged_usage_cost_usd"] == 0.04
        assert summary["logged_cache_fraction"] == 0.75
        assert summary["logged_sidecar_spend_usd"] is None
        path.unlink()
        assert not hosted.log_usage(path)["policy_log_present"]
    print("Hosted compact and artifact usage checks passed without network access.")


if __name__ == "__main__":
    main()
