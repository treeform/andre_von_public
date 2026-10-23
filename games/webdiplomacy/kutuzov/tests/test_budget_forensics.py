"""Sanitized regression checks for budget joins, uncertainty and coverage."""

import copy
import hashlib
import json
import sys
import tempfile
import zipfile
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import budget_forensics as budgets


def fixture(empirical=False):
    """Build two serial calls without copying any real prompts or press."""
    mode = {"budget_mode": "EmpiricalBudget"} if empirical else {}
    rows = [
        {"event": "process_start"},
        {"event": "bot_start", "country_id": 3, "stopped": False, **mode},
        {"event": "phase_start", "phase": "8:Diplomacy", "year": 1905,
         "order_slots": 1, "spent_usd": 0, "deadline": 1792101900},
        {"event": "spend_sync", "spent_usd": 0},
        {"event": "inference_start", "phase": "8:Diplomacy", "task": "plan",
         "model": "openai/gpt-6-luna", "call": 1, "call_reserve_usd": .003,
         "request_bytes": 1000, **mode},
        {"event": "http_request", "scope": "model", "request_id": 11,
         "body": {"model": "openai/gpt-6-luna",
                  "messages": [{"content": "NEVER_EXPORT_PRIVATE_TEXT"}]}},
        {"event": "http_response", "scope": "model", "request_id": 999,
         "status": 200, "body": {"usage": {"cost": 99}}},
        {"event": "http_response", "scope": "model", "request_id": 11,
         "status": 200, "body": {"usage": {"cost": .001}}},
        {"event": "model_return", "request_id": 11, "status": 200,
         "usage": {"hasInput": True, "hasOutput": True}},
        {"event": "llm_call", "phase": "8:Diplomacy", "model": "openai/gpt-6-luna",
         "status": 200, "estimated_spend_usd": .001, "sidecar_spend_usd": .001,
         "error": "",
         **({"cost_known": True, "uncertain_usd": 0, **mode} if empirical else {})},
        {"event": "decision_parsed", "phase": "8:Diplomacy",
         "memory": "NEVER_EXPORT_PRIVATE_TEXT", "press": "NEVER_EXPORT_PRIVATE_TEXT"},
        {"event": "inference_start", "phase": "8:Diplomacy", "task": "review",
         "model": "openai/gpt-6.1-sol", "call": 2, "call_reserve_usd": .04,
         "request_bytes": 1500, "phase_cost_usd": .001,
         "phase_allowance_usd": .02, "reservation_is_estimate": empirical, **mode},
        {"event": "http_request", "scope": "model", "request_id": 12,
         "body": {"model": "openai/gpt-6.1-sol"}},
        {"event": "http_response", "scope": "model", "request_id": 12,
         "status": 502, "body": {"error": "NEVER_EXPORT_PRIVATE_TEXT"}},
        {"event": "model_return", "request_id": 12, "status": 502,
         "usage": {"hasInput": False, "hasOutput": False}},
        {"event": "llm_call", "phase": "8:Diplomacy", "model": "openai/gpt-6.1-sol",
         "status": 502, "estimated_spend_usd": .041, "sidecar_spend_usd": .001,
         "error": "provider failed",
         **({"cost_known": False, "uncertain_usd": .04,
             "uncertain_calls": 1, **mode} if empirical else {})},
        {"event": "bot_return", "reason": "finished_or_horizon", "phase": "15:Finished"},
        {"event": "process_return", "exit_code": 0},
    ]
    for index, row in enumerate(rows):
        row.update(sequence=index + 1, pid=8,
                   timestamp=f"2026-10-15T22:00:{index:02}.000Z")
    return rows


def analyze(rows, complete=True):
    """Apply the production sanitizer before testing any accounting join."""
    coverage = {"complete_events": complete, "event_issues": [] if complete else ["sequence_gaps"],
                "detail_issues": [], "source": "fixture"}
    return budgets.summarize([budgets.safe_event(row) for row in rows], coverage, 2)


def test_legacy_and_empirical():
    """Join only matching request IDs and separate unknown allowances."""
    for empirical in (False, True):
        report = analyze(fixture(empirical))
        assert not report["join_issues"]
        assert report["actual_usage_cost_usd"] == .001
        assert report["uncertain_reservations_observed_usd"] == .04
        assert report["local_final_observed_usd"] == .041
        assert [call["http_request_id"] for call in report["calls"]] == [11, 12]
        assert [call["task"] for call in report["calls"]] == ["plan", "review"]
        assert [call["status"] for call in report["calls"]] == [200, 502]
        assert report["calls"][1]["cost_classification"] == "uncertain_reservation"
        assert report["calls"][1]["phase_allowance_usd"] == .02
        assert "NEVER_EXPORT_PRIVATE_TEXT" not in json.dumps(report)
        if empirical:
            assert report["runtime_final_uncertain_usd"] == .04
            assert report["calls"][1]["budget_mode"] == "EmpiricalBudget"
    duplicated = fixture() + [fixture()[-1]]
    assert analyze(duplicated)["observed_attempts"] == 2


def test_missing_evidence():
    """Missing cost bodies and unobserved years must not become known zeros."""
    rows = fixture(True)
    rows[7].pop("body")
    report = analyze(rows)
    assert report["actual_usage_cost_usd"] is None
    assert report["calls"][0]["cost_classification"] == "runtime_known_cost_amount_missing"
    assert report["uncertain_reservations_observed_usd"] == .04
    years = {row["year"]: row for row in report["yearly"]}
    assert years[1905]["successful_sol_reviews"] == 0
    assert years[1906]["successful_sol_reviews"] is None
    partial = analyze(fixture(), False)
    assert all(row["successful_sol_reviews"] is None for row in partial["yearly"])
    missing_start = [row for row in fixture() if row["event"] != "inference_start"]
    orphan = analyze(missing_start)
    assert "unmatched_llm_call" in orphan["join_issues"]
    assert orphan["actual_usage_cost_usd"] is None
    crashed = fixture()
    crashed[-1]["exit_code"] = 1
    assert all(row["successful_sol_reviews"] is None
               for row in analyze(crashed)["yearly"])


def test_empirical_delayed_meter():
    """A later meter increase must preserve separate uncertain allowances."""
    rows = fixture(True)[:-2]
    rows[11]["uncertain_usd"] = 0
    additions = [
        {"event": "spend_sync", "spent_usd": .02},
        {"event": "spend_sync", "spent_usd": .01},
        {"event": "inference_start", "phase": "8:Diplomacy", "task": "repair",
         "model": "openai/gpt-6-luna", "call_reserve_usd": .003,
         "budget_mode": "EmpiricalBudget", "uncertain_usd": .04},
    ]
    for index, row in enumerate(additions, len(rows) + 1):
        row.update(sequence=index, pid=8, timestamp=f"2026-10-15T22:02:{index:02}.000Z")
    report = analyze(rows + additions)
    assert report["calls"][1]["uncertain_before_usd"] == 0
    assert report["calls"][1]["uncertain_after_usd"] == .04
    assert report["calls"][1]["uncertain_usd"] == .04
    assert abs(report["calls"][-1]["local_before_usd"] - .06) < 1e-9
    assert abs(report["meter_final_observed_usd"] - .02) < 1e-9
    restored = fixture(True)[:5]
    restored[1]["state_restored"] = True
    restored[2]["spent_usd"] = .4
    restored[3]["spent_usd"] = .2
    restored[4]["uncertain_usd"] = .1
    assert abs(analyze(restored)["calls"][0]["local_before_usd"] - .4) < 1e-9


def test_deferral_and_defaults():
    """Optional empirical updates must not be counted as entire default phases."""
    base = fixture(True)[:-1]
    additions = [
        {"event": "inference_skipped", "phase": "8:Diplomacy", "reason": "budget_reserve"},
        {"event": "updates_stopped", "phase": "8:Diplomacy", "reason": "optional_budget_admission"},
        {"event": "phase_start", "phase": "9:Diplomacy", "year": 1905, "order_slots": 1, "spent_usd": .041},
        {"event": "inference_skipped", "phase": "9:Diplomacy", "reason": "budget_reserve"},
        {"event": "http_request", "scope": "game", "request_id": 15,
         "route": "/api.php?route=game/orders", "body": {"orders": []}},
        {"event": "http_response", "scope": "game", "request_id": 15,
         "route": "/api.php?route=game/orders", "body": [{"type": "Hold"}]},
        {"event": "phase_ready", "phase": "9:Diplomacy", "reason": "inference_skipped"},
        {"event": "phase_start", "phase": "9:Builds", "year": 1905, "order_slots": 0, "spent_usd": .041},
        {"event": "http_request", "scope": "game", "request_id": 16,
         "route": "/api.php?route=game/orders", "body": {"orders": []}},
        {"event": "http_response", "scope": "game", "request_id": 16,
         "route": "/api.php?route=game/orders", "body": [{"type": "Destroy", "terrID": None}]},
    ]
    for index, row in enumerate(additions, len(base) + 1):
        row.update(sequence=index, pid=8, timestamp=f"2026-10-15T22:01:{index:02}.000Z")
    report = analyze(base + additions)
    assert report["skips"][0]["disposition"] == "optional_update_deferred"
    assert report["skips"][1]["disposition"] == "phase_ready_after_skip"
    assert report["skips"][1]["prior_calls"] == 0
    assert report["skips"][1]["returned_order_types"] == {"Hold": 1}
    assert report["routing"]["movements"][1]["budget_defaults"] == 1


def test_late_routing_and_elimination():
    """Separate review success, other tasks, optional deferral and model stops."""
    rows = fixture(True)[:-2]
    for row in rows:
        if row.get("model") == "openai/gpt-6-luna":
            row["model"] = "openai/gpt-6.1-sol"
        if row.get("event") == "http_request" and row.get("scope") == "model":
            row["body"]["model"] = "openai/gpt-6.1-sol"
        if row.get("request_id") == 12:
            row["status"] = 200
            if row["event"] == "http_response":
                row["body"] = {"usage": {"cost": .02}}
            elif row["event"] == "model_return":
                row["usage"] = {"hasInput": True, "hasOutput": True}
        if row["event"] == "llm_call" and row.get("status") == 502:
            row.update(status=200, error="", cost_known=True, uncertain_usd=0,
                       estimated_spend_usd=.021, sidecar_spend_usd=.021)
    rows[11:11] = [
        {"event": "inference_skipped", "phase": "8:Diplomacy", "reason": "budget_reserve"},
        {"event": "updates_stopped", "phase": "8:Diplomacy", "reason": "optional_budget_admission"},
        {"event": "economy_fallback", "phase": "8:Diplomacy",
         "preferred_model": "openai/gpt-6.1-sol", "selected_model": "openai/gpt-6-luna"},
    ]
    rows += [
        {"event": "decision_parsed", "phase": "8:Diplomacy", "task": "review", "stop_spending": True},
        {"event": "orders_verified", "phase": "8:Diplomacy", "task": "review"},
        {"event": "inference_stopped", "reason": "NEVER_EXPORT_PRIVATE_TEXT"},
        {"event": "phase_start", "phase": "9:Diplomacy", "year": 1905, "order_slots": 0, "spent_usd": .021},
        {"event": "phase_ready", "phase": "9:Diplomacy", "stopped": True},
        {"event": "phase_start", "phase": "10:Diplomacy", "year": 1906, "order_slots": 1, "spent_usd": .021},
        {"event": "phase_ready", "phase": "10:Diplomacy", "stopped": True},
        {"event": "bot_return", "reason": "Defeated", "phase": "12:Diplomacy"},
        {"event": "process_return", "exit_code": 0},
    ]
    for index, row in enumerate(rows):
        row.update(sequence=index + 1, pid=8, timestamp=f"2026-10-15T22:03:{index:02}.000Z")
    report = analyze(rows)
    assert not report["join_issues"]
    years = {year["year"]: year for year in report["routing"]["yearly"]}
    first = years[1905]["counts"]
    assert first["eligible_movements"] == 1
    assert first["sol_review_phases"] == first["sol_review_calls"] == 1
    assert first["verified_sol_review_calls"] == 1
    assert first["other_sol_calls"] == 1
    assert first["optional_deferrals"] == first["economy_fallbacks"] == 1
    assert first["model_stops"] == 1
    second = years[1906]["counts"]
    assert second["eligible_movements"] == 1
    assert second["inference_enabled_movements"] == 0
    assert second["movements_requiring_orders"] == 1
    assert second["stopped_default"] == 1 and second["budget_defaults"] == 0
    assert years[1907]["evidence"] == "eliminated_before_year"
    assert years[1907]["counts"]["eligible_movements"] == 0
    assert report["model_stops"][0]["reason"] == "model_requested_stop"
    assert "NEVER_EXPORT_PRIVATE_TEXT" not in json.dumps(report)
    partial = analyze(rows[:-2], False)
    assert all(year["counts"]["eligible_movements"] is None
               for year in partial["routing"]["yearly"])
    later_defeat = fixture(True)
    later_defeat[-2].update(reason="Defeated", phase="8:Retreats")
    year = analyze(later_defeat)["routing"]["yearly"][0]
    assert year["evidence"] == "eliminated_during_year"
    assert year["counts"]["eligible_movements"] == 1
    unknown = fixture(True)
    unknown[1].pop("stopped")
    unknown[2].pop("order_slots")
    unknown = [row for row in unknown if row["event"] in
               ("process_start", "bot_start", "phase_start", "bot_return", "process_return")]
    year = analyze(unknown)["routing"]["yearly"][0]
    assert year["counts"]["eligible_movements"] is None
    assert year["counts"]["eligibility_unknown_movements"] == 1


def test_verified_reviews_and_repairs():
    """A verified Sol repair never substitutes for a literal successful review."""
    rows = fixture(True)[:-2]
    rows += [
        {"event": "inference_start", "phase": "8:Diplomacy", "task": "repair",
         "model": "openai/gpt-6.1-sol", "call": 3, "call_reserve_usd": .04,
         "deadline_unix": 1792101900},
        {"event": "http_request", "scope": "model", "request_id": 13},
        {"event": "http_response", "scope": "model", "request_id": 13,
         "status": 200, "body": {"usage": {"cost": .01}}},
        {"event": "model_return", "request_id": 13, "status": 200,
         "usage": {"hasInput": True, "hasOutput": True}},
        {"event": "llm_call", "phase": "8:Diplomacy", "model": "openai/gpt-6.1-sol",
         "status": 200, "error": "", "estimated_spend_usd": .051,
         "sidecar_spend_usd": .011, "cost_known": True, "uncertain_usd": .04},
        {"event": "decision_parsed", "phase": "8:Diplomacy", "task": "repair"},
        {"event": "orders_verified", "phase": "8:Diplomacy", "task": "repair"},
        {"event": "bot_return", "reason": "finished_or_horizon", "phase": "15:Finished"},
        {"event": "process_return", "exit_code": 0},
    ]
    for index, row in enumerate(rows):
        row.update(sequence=index + 1, pid=8, timestamp=f"2026-10-15T22:04:{index:02}.000Z")
    result = analyze(rows)
    year = result["routing"]["yearly"][0]
    assert year["counts"]["verified_sol_review_calls"] == 0
    assert year["counts"]["verified_sol_repair_calls"] == 1
    assert year["counts"]["sol_repair_after_review_phases"] == 1
    assert year["yearly_review_criterion"] == "not_satisfied"

    repair = result["routing"]["movements"][0]["sol_repairs_after_unverified_review"][0]
    assert repair["review_model"] == "openai/gpt-6.1-sol"
    assert repair["repair_sequence"] == rows[-9]["sequence"]
    acceptance = next(row for row in rows if row["event"] == "orders_verified")
    acceptance["timestamp"] = "2026-10-15T22:05:00.000Z"
    result = analyze(rows)
    assert result["routing"]["yearly"][0]["counts"]["verified_sol_repair_calls"] == 0
    acceptance["timestamp"] = "2026-10-15T22:04:59.000Z"
    for row in rows:
        if row.get("task") == "repair":
            row["task"] = "review"
    result = analyze(rows)
    year = result["routing"]["yearly"][0]
    assert year["counts"]["verified_sol_review_phases"] == 1
    assert year["yearly_review_criterion"] == "satisfied"
    success = next(row for row in reversed(rows) if row["event"] == "llm_call")
    success["error"] = "response incomplete"
    year = analyze(rows)["routing"]["yearly"][0]
    assert year["counts"]["verified_sol_review_phases"] == 0
    assert year["yearly_review_criterion"] == "not_satisfied"


def test_review_verification_order():
    """Never attach verification across phases or before completion."""
    rows = fixture(True)[:-2]
    rows += [
        {"event": "phase_start", "phase": "9:Diplomacy", "year": 1905,
         "order_slots": 1, "spent_usd": .041},
        {"event": "orders_verified", "phase": "9:Diplomacy", "task": "review"},
    ]
    for index, row in enumerate(rows):
        row.update(sequence=index + 1, pid=8, timestamp=f"2026-10-15T22:04:{index:02}.000Z")
    result = analyze(rows)
    assert "unmatched_engine_order_verification" in result["join_issues"]
    assert not result["calls"][-1].get("orders_verified")
    rows = fixture(True)
    index = max(index for index, row in enumerate(rows) if row["event"] == "llm_call")
    rows.insert(index, {"event": "orders_verified", "phase": "8:Diplomacy", "task": "review"})
    for index, row in enumerate(rows):
        row.update(sequence=index + 1, pid=8, timestamp=f"2026-10-15T22:04:{index:02}.000Z")
    result = analyze(rows)
    assert "unmatched_engine_order_verification" in result["join_issues"]
    assert not result["calls"][-1].get("orders_verified")


def test_closed_years_before_missing_process_end():
    """Preserve closed-year facts without claiming a complete missing tail."""
    def reviewed_phase(stamp):
        """Build an eligible phase with one verified successful Sol review."""
        rows = fixture(True)[:-2]
        for row in rows:
            if "phase" in row:
                row["phase"] = stamp
            if row.get("request_id") == 12:
                row["status"] = 200
            if row["event"] == "llm_call" and row["model"].endswith("sol"):
                row.update(status=200, error="")
        rows.append({"event": "orders_verified", "phase": stamp,
                     "task": "review"})
        return rows

    rows = reviewed_phase("8:Diplomacy")
    for stamp in ("10:Diplomacy", "12:Diplomacy"):
        rows += [
            {"event": "phase_start", "phase": stamp, "order_slots": 1,
             "spent_usd": .041},
            {"event": "inference_skipped", "phase": stamp,
             "reason": "budget_reserve"},
            {"event": "phase_ready", "phase": stamp,
             "reason": "inference_skipped"},
        ]
    rows += reviewed_phase("14:Diplomacy")[2:]
    for index, row in enumerate(rows):
        row.update(sequence=index + 1, pid=8,
                   timestamp=f"2026-10-15T22:00:{index:02}.000Z")

    with tempfile.TemporaryDirectory() as temporary:
        directory = Path(temporary)

        def archive_report(saved_rows, wrong_hash=False):
            """Exercise real manifest and sequence validation on a saved prefix."""
            raw = ("\n".join(json.dumps(row) for row in saved_rows) + "\n").encode()
            files = [{"path": f"logs/{name}.jsonl", "status": "complete",
                      "complete": True, "source_bytes": len(raw),
                      "archived_bytes": len(raw),
                      "sha256": "wrong" if wrong_hash and name == "events"
                      else hashlib.sha256(raw).hexdigest()}
                     for name in ("events", "details")]
            with zipfile.ZipFile(directory / "slot-2.zip", "w") as archive:
                archive.writestr("logs/events.jsonl", raw)
                archive.writestr("logs/details.jsonl", raw)
                archive.writestr("logs/manifest.json", json.dumps(
                    {"schema_version": 1, "complete": True, "files": files}))
            return budgets.analyze(directory)["seats"][0]

        report = archive_report(rows)
        assert report["coverage"]["event_issues"] == ["missing_process_end"]
        assert report["verified_partial_prefix"]
        assert report["closed_observed_years"] == [1905, 1906, 1907]
        assert not report["completed_lifetime"]
        assert report["actual_usage_cost_usd"] is None
        assert report["observed_attempts"] == 4
        years = {year["year"]: year for year in report["routing"]["yearly"]}
        for year in (1905, 1906, 1907):
            assert years[year]["evidence"] == "closed_observed_year_missing_process_end"
            assert years[year]["counts"]["eligible_movements"] == 1
        assert years[1905]["counts"]["verified_sol_review_calls"] == 1
        assert years[1905]["yearly_review_criterion"] == "satisfied"
        assert years[1906]["counts"]["verified_sol_review_calls"] == 0
        assert years[1906]["yearly_review_criterion"] == "not_satisfied"
        assert years[1907]["counts"]["budget_defaults"] == 1
        assert years[1908]["counts"]["eligible_movements"] is None
        assert years[1908]["counts"]["verified_sol_review_calls"] is None
        assert years[1908]["observed_counts"]["verified_sol_review_calls"] == 1
        assert years[1908]["yearly_review_criterion"] == "satisfied"
        negative_tail = copy.deepcopy(rows)
        next(row for row in reversed(negative_tail)
             if row["event"] == "llm_call")["error"] = "incomplete response"
        tail = archive_report(negative_tail)["routing"]["yearly"][-1]
        assert tail["yearly_review_criterion"] == "unknown"
        missing_sequences = [{key: value for key, value in row.items()
                              if key != "sequence"} for row in rows]
        for broken in (archive_report(rows, True),
                       archive_report(rows[:3] + rows[4:]),
                       archive_report(missing_sequences)):
            assert not broken["verified_partial_prefix"]
            assert not broken["closed_observed_years"]
            assert all(year["yearly_review_criterion"] == "unknown"
                       for year in broken["routing"]["yearly"])


def test_ordered_archive_sequences():
    """Reject sequence defects independently of model-call join validation."""
    prefix = [
        {"event": "process_start"},
        {"event": "bot_start", "country_id": 3, "stopped": False},
        {"event": "phase_start", "phase": "8:Diplomacy",
         "order_slots": 1, "spent_usd": 0},
        {"event": "phase_start", "phase": "10:Diplomacy",
         "order_slots": 1, "spent_usd": 0},
    ]
    terminal = [
        {"event": "bot_return", "reason": "finished_or_horizon",
         "phase": "15:Finished"},
        {"event": "process_return", "exit_code": 0},
    ]
    with tempfile.TemporaryDirectory() as temporary:
        directory = Path(temporary)

        def archive_report(rows):
            """Keep checksums valid so only sequence evidence is varied."""
            raw = ("\n".join(json.dumps(row) for row in rows) + "\n").encode()
            files = [{"path": f"logs/{name}.jsonl", "status": "complete",
                      "complete": True, "source_bytes": len(raw),
                      "archived_bytes": len(raw),
                      "sha256": hashlib.sha256(raw).hexdigest()}
                     for name in ("events", "details")]
            with zipfile.ZipFile(directory / "slot-2.zip", "w") as archive:
                archive.writestr("logs/events.jsonl", raw)
                archive.writestr("logs/details.jsonl", raw)
                archive.writestr("logs/manifest.json", json.dumps(
                    {"schema_version": 1, "complete": True, "files": files}))
            observed, coverage = budgets.read_events(directory, 2)
            assert len(observed) == len(rows)
            return budgets.summarize(observed, coverage, 2)

        for complete in (False, True):
            rows = copy.deepcopy(prefix + (terminal if complete else []))
            for index, row in enumerate(rows):
                row.update(pid=9, sequence=index + 1,
                           timestamp=f"2026-10-15T22:00:0{index}Z")
            good = archive_report(rows)
            assert good["coverage"]["complete_events"] is complete
            assert good["verified_partial_prefix"] is (not complete)
            assert not good["join_issues"]
            variants = [
                [{key: value for key, value in row.items() if key != "sequence"}
                 for row in rows],
                [{key: value for key, value in row.items() if key != "pid"}
                 for row in rows],
                [{**row, "sequence": row["sequence"] + 1} for row in rows],
                rows[:2] + [rows[3], rows[2]] + rows[4:],
                rows[:3] + [{**rows[3], "sequence": 3}] + rows[4:],
                rows[:3] + [rows[2]] + rows[3:],
                rows[:2] + rows[3:],
            ]
            for field in ("pid", "sequence"):
                for invalid in (None, 0, -1, True, 3.0, "3"):
                    variant = copy.deepcopy(rows)
                    variant[2][field] = invalid
                    variants.append(variant)
            for variant in variants:
                broken = archive_report(variant)
                assert not broken["join_issues"]
                assert not broken["coverage"]["complete_events"]
                assert any(issue.startswith("event_sequence_")
                           for issue in broken["coverage"]["event_issues"])
                assert not broken["verified_partial_prefix"]
                assert not broken["closed_observed_years"]
                assert broken["actual_usage_cost_usd"] is None
                assert all(year["yearly_review_criterion"] == "unknown"
                           for year in broken["routing"]["yearly"])
    assert budgets.sequence_issues([
        {"pid": 9, "sequence": 1}, {"pid": 10, "sequence": 1},
        {"pid": 9, "sequence": 2}, {"pid": 10, "sequence": 2},
    ]) == []


def test_archive_and_missing_slots():
    """Verify archive checksums and preserve missing identified seats."""
    with tempfile.TemporaryDirectory() as temporary:
        directory = Path(temporary)
        rows = fixture(True)
        raw = ("\n".join(json.dumps(row) for row in rows) + "\n").encode()
        files = [{"path": f"logs/{name}.jsonl", "status": "complete", "complete": True,
                  "source_bytes": len(raw), "archived_bytes": len(raw),
                  "sha256": hashlib.sha256(raw).hexdigest()} for name in ("events", "details")]
        with zipfile.ZipFile(directory / "slot-2.zip", "w") as archive:
            archive.writestr("logs/events.jsonl", raw)
            archive.writestr("logs/details.jsonl", raw)
            archive.writestr("logs/manifest.json", json.dumps(
                {"schema_version": 1, "complete": True, "files": files}))
        (directory / "scoreboard.json").write_text(json.dumps({"participants": [
            {"slot": 2, "policy": "kutuzov"}, {"slot": 6, "policy": "kutuzov"}]}))
        report = budgets.analyze(directory)
        assert len(report["seats"]) == 2
        assert report["seats"][0]["coverage"]["complete_events"]
        assert report["seats"][0]["actual_usage_cost_usd"] == .001
        missing = report["seats"][1]
        assert missing["actual_usage_cost_usd"] is None
        assert all(year["successful_sol_reviews"] is None for year in missing["yearly"])
        assert "NEVER_EXPORT_PRIVATE_TEXT" not in json.dumps(report)


def test_degraded_archives():
    """Bad detail files cannot erase compact events or inject trusted costs."""
    with tempfile.TemporaryDirectory() as temporary:
        directory = Path(temporary)
        rows = fixture(True)
        compact = ("\n".join(json.dumps({key: value for key, value in row.items()
                                      if key != "body"}) for row in rows) + "\n").encode()
        details = ("\n".join(json.dumps(row) for row in rows) + "\n").encode()

        def write_archive(raw_details, bad_manifest=None, wrong_hash=False):
            """Build one small complete-manifest archive with controlled faults."""
            files = []
            for name, data in (("events", compact), ("details", raw_details)):
                files.append({"path": f"logs/{name}.jsonl", "status": "complete",
                              "complete": True, "source_bytes": len(data),
                              "archived_bytes": len(data), "sha256": "wrong" if
                              wrong_hash and name == "details" else hashlib.sha256(data).hexdigest()})
            manifest = bad_manifest if bad_manifest is not None else {
                "schema_version": 1, "complete": True, "files": files}
            with zipfile.ZipFile(directory / "slot-2.zip", "w") as archive:
                archive.writestr("logs/events.jsonl", compact)
                archive.writestr("logs/details.jsonl", raw_details)
                archive.writestr("logs/manifest.json", json.dumps(manifest))

        for raw, manifest, bad_hash in [(b"\xff", None, False),
                                        (details, [], False),
                                        (details, {"files": [1]}, False),
                                        (details, None, True)]:
            write_archive(raw, manifest, bad_hash)
            report = budgets.analyze(directory)["seats"][0]
            assert report["observed_attempts"] == 2
            assert report["actual_usage_cost_usd"] is None
            assert report["calls"][0]["actual_usage_cost_usd"] is None
            assert report["coverage"]["detail_issues"]
        (directory / "selection.json").write_text(json.dumps({
            "slots": ["Scott", "Scott", "Kutuzov", "Scott", "Kutuzov"]}))
        report = budgets.analyze(directory)
        assert [seat["slot"] for seat in report["seats"]] == [2, 4]
        assert report["seats"][1]["actual_usage_cost_usd"] is None


def test_transport_terminal_outcome():
    """Close exact native timeouts without inventing a response or settlement."""
    rows = fixture(True)
    timeout = {"event": "http_transport_error", "scope": "model",
               "request_id": 12, "pid": 8, "sequence": 14,
               "timestamp": "2026-10-15T22:00:14.000Z",
               "error": "NEVER_EXPORT_PRIVATE_TEXT"}
    truncated = rows[:13] + [timeout] + rows[-2:]
    report = analyze(truncated)
    call = report["calls"][1]
    assert not report["join_issues"]
    assert call["terminal_outcome"] == "http_transport_error"
    assert call["status"] is None and call["policy_http_status"] is None
    assert call["actual_usage_cost_usd"] is None
    assert call["runtime_cost_known"] is False and call["completion_error"] is True
    assert call["uncertain_after_usd"] is None
    assert report["runtime_final_uncertain_usd"] is None
    assert "NEVER_EXPORT_PRIVATE_TEXT" not in json.dumps(report)
    for field, value in (("request_id", 999), ("pid", 99)):
        wrong = copy.deepcopy(truncated)
        wrong[13][field] = value
        bad = analyze(wrong)
        assert "unmatched_model_transport_error" in bad["join_issues"]
        assert "inference_without_completion" in bad["join_issues"]
    retry = copy.deepcopy(rows[4:11])
    for row in retry:
        if "request_id" in row:
            row["request_id"] = 13 if row["request_id"] == 11 else 999
        if row["event"] == "inference_start":
            row.update(call=3, uncertain_usd=.04)
        if row["event"] == "llm_call":
            row.update(estimated_spend_usd=.042, sidecar_spend_usd=.002,
                       uncertain_usd=.04)
    complete = rows[:13] + [timeout] + retry + rows[-2:]
    for index, row in enumerate(complete):
        row.update(sequence=index+1, timestamp=f"2026-10-15T22:00:{index:02}.000Z")
    recovered = analyze(complete)
    assert not recovered["join_issues"]
    assert len(recovered["calls"]) == 3
    assert abs(recovered["calls"][2]["local_before_usd"]-.041) < 1e-12
    assert recovered["runtime_final_uncertain_usd"] == .04
    assert recovered["actual_usage_cost_usd"] == .002


test_legacy_and_empirical()
test_missing_evidence()
test_empirical_delayed_meter()
test_deferral_and_defaults()
test_late_routing_and_elimination()
test_verified_reviews_and_repairs()
test_review_verification_order()
test_closed_years_before_missing_process_end()
test_ordered_archive_sequences()
test_archive_and_missing_slots()
test_degraded_archives()
test_transport_terminal_outcome()
print("Budget forensic fixtures passed.")
