"""Preserve independent HTTP, sidecar, parser, and process observations."""

import hashlib
import importlib.util
import io
import json
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("audit", ROOT / "tools/audit.py")
AUDIT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(AUDIT)


def response(category, retryable, upstream=None):
    """Keep sensitive source messages outside every exported diagnostic."""
    softmax = {"category": category, "retryable": retryable,
               "provider_error": {"message": "private-secret",
                                  "metadata": {"auth": "private-secret"}}}
    if upstream is not None:
        softmax["upstream_status"] = upstream
    return {"event": "http_response", "scope": "model", "status": 502,
            "request_id": 7, "sequence": 9,
            "body": {"error": {"message": "private-secret"},
                     "softmax_error": softmax}}


def details(rows, corrupt=False, schema_version=1):
    """Build a checksummed details stream without executing policy code."""
    raw = b"".join(json.dumps(row).encode() + b"\n" for row in rows)
    manifest = {"schema_version": schema_version, "complete": True, "files": [{
        "path": "logs/details.jsonl", "complete": True, "status": "complete",
        "source_bytes": len(raw), "archived_bytes": len(raw),
        "sha256": "0" * 64 if corrupt else hashlib.sha256(raw).hexdigest()}]}
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w") as archive:
        archive.writestr("logs/details.jsonl", raw)
        archive.writestr("logs/manifest.json", json.dumps(manifest))
    with zipfile.ZipFile(io.BytesIO(buffer.getvalue())) as archive:
        return AUDIT.audit_error_details(archive)


def checks():
    """Avoid inferring network causes or timeouts from generic labels."""
    for category in ("platform_error", "provider_response",
                     "provider_transport", "routing_parameters"):
        result = AUDIT.diagnostic_event(response(category, False))
        assert result["caller_http_status"] == 502
        assert result["softmax_category"] == category
        assert result["softmax_retryable"] is False
        assert result["softmax_upstream_status"] is None
        assert "private-secret" not in json.dumps(result)
        assert "network" not in result["classification"]
    result = AUDIT.diagnostic_event(response("provider_error", True, 200))
    assert result["caller_http_status"] == 502
    assert result["softmax_upstream_status"] == 200
    assert result["softmax_retryable"] is True
    identified = response("provider_error", False)
    identified["body"]["softmax_error"]["call_id"] = \
        "9d09fc66-9e53-403a-b86c-c062a68a1c9b"
    assert AUDIT.diagnostic_event(identified)["softmax_call_id"] == \
        "9d09fc66-9e53-403a-b86c-c062a68a1c9b"

    exception = AUDIT.diagnostic_event({
        "event": "http_transport_error", "scope": "model",
        "error_type": "CurlyError", "error": "private-secret"})
    assert exception["classification"] == "http_client_exception"
    assert exception["exception_type"] == "CurlyError"
    assert exception["caller_http_status"] is None
    generic = AUDIT.diagnostic_event({"event": "model_return", "status": 502,
        "error": "The provider failed or timed out. Provider detail: private-secret"})
    assert generic["classification"] == "generic_failure_or_timeout_wording"
    assert "private-secret" not in json.dumps(generic)

    incomplete = AUDIT.diagnostic_event({"event": "http_response",
        "scope": "model", "status": 200,
        "body": {"choices": [{"finish_reason": "length"}]}})
    assert incomplete["caller_http_status"] == 200
    assert incomplete["model_incomplete_reason"] == "length"
    parse = AUDIT.diagnostic_event({"event": "error",
        "scope": "model_response_parse", "error": "The LLM returned invalid JSON."})
    assert parse["classification"] == "model_envelope_parse_error"
    decision = AUDIT.diagnostic_event({"event": "error", "scope": "tick",
        "error": "Invalid decision stop_reason"})
    assert decision["classification"] == "model_decision_validation_error"

    chain = [{"event": "phase_start", "sequence": 1, "phase": "5:Builds"},
        {"event": "http_response", "scope": "game", "status": 404,
         "sequence": 2, "request_id": 41,
         "route": "/api.php?route=game/playercontext&credential=private-secret"},
        {"event": "error", "scope": "fatal", "sequence": 3,
         "error_type": "KutuzovHttpError", "error": "private-secret"},
        {"event": "process_return", "sequence": 4, "exit_code": 1}]
    summary = details(chain)
    assert summary["source_verified"]
    assert [r["sequence"] for r in summary["records"]] == [2, 3, 4]
    assert summary["records"][0]["caller_http_status"] == 404
    assert summary["records"][0]["route_kind"] == "playercontext"
    assert summary["records"][1]["fatal"]
    assert summary["records"][2]["exit_code"] == 1
    assert all(r["phase"] == "5:Builds" for r in summary["records"])
    assert "private-secret" not in json.dumps(summary)
    assert not details(chain, corrupt=True)["source_verified"]
    assert not details(chain, schema_version=99)["source_verified"]
    print("Error-boundary audit fixtures passed; no raw error text exported.")


checks()
