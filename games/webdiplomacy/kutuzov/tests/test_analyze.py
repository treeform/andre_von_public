"""Check public-fact analysis using a sanitized completed-game fixture."""

import copy
import importlib.util
import json
import math
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FIXTURE = Path(__file__).parent / "fixtures" / "analysis-baseline.json"
ATTEMPTS = Path(__file__).parent / "fixtures" / "analysis-attempts.json"
SPEC = importlib.util.spec_from_file_location("analyze", ROOT / "tools/analyze.py")
ANALYZE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ANALYZE)


def report(fixture):
    """Analyze disposable local artifacts without running CLI or network calls."""
    with tempfile.TemporaryDirectory() as temporary:
        directory = Path(temporary)
        for name, data in fixture.get("files", {}).items():
            (directory / name).write_text(json.dumps(data), encoding="utf-8")
        if "game_log_events" in fixture:
            (directory / "game.log").write_text("\n".join(
                json.dumps(event) for event in fixture["game_log_events"]),
                encoding="utf-8")
        before = sorted(path.name for path in directory.iterdir())
        result = ANALYZE.analyze_directory(directory)
        assert sorted(path.name for path in directory.iterdir()) == before
        json.dumps(result, allow_nan=False)
        return result


def set_centers(fixture, centers):
    """Replace fixture centers using country IDs, not the member array order."""
    results = fixture["files"]["results.json"]
    for member in results["members"]:
        slot = results["countries"].index(int(member["countryID"]))
        member["supplyCenterNo"] = str(centers[slot])
    denominator = sum(value * value for value in centers)
    results["scores"] = [value * value / denominator for value in centers]


def main():
    """Exercise authority, cutoff, uncertainty, telemetry and privacy invariants."""
    fixture = json.loads(FIXTURE.read_text(encoding="utf-8"))
    baseline = report(fixture)
    seats = baseline["seats"]
    assert [seat["centers"] for seat in seats] == [2, 10, 1, 2, 0, 16, 3]
    assert [seat["centers_rank"] for seat in seats] == [4, 2, 6, 4, 7, 1, 3]
    assert [seat["country"] for seat in seats] == [
        "England", "Turkey", "Italy", "Germany", "Austria", "France", "Russia"]
    assert baseline["policy_means"]["kutuzov"]["mean_centers"] == 1.5
    assert math.isclose(baseline["policy_means"]["scott"]["mean_centers"], 28 / 3)
    assert baseline["signals"]["kutuzov_clear_win_signal"] is False
    assert baseline["signals"]["authoritative_solo_slots"] == []
    assert baseline["exits"]["all_exited_zero"] is True
    assert all(seat["health"]["disconnects"] == 0 for seat in seats)
    assert [seat["activity"]["required_phases"] for seat in seats] == [
        23, 20, 21, 26, 25, 25, 24]
    assert sum(seat["activity"]["required_phases"] for seat in seats
               if seat["policy"] == "kutuzov") == 93
    assert sum(seat["activity"]["final_year_build_obligations_excluded"]
               for seat in seats) == 4
    assert seats[5]["activity"]["sampling_gaps"] == [{
        "turn": 9, "phase": "Retreats", "saved_unobserved": True,
        "ready_unobserved": True}]
    assert baseline["provider_totals"]["billed_calls"] == 756
    assert sum(seat["provider"]["billed_calls"] for seat in seats
               if seat["policy"] == "kutuzov") == 197
    assert math.isclose(baseline["provider_totals"]["billed_cost_usd"],
                        1.021999945)
    assert seats[0]["provider"]["total_input_tokens"] == 583418
    assert baseline["center_trajectory"][-1]["centers_by_slot"] == [
        2, 10, 1, 2, 0, 16, 3]
    assert baseline["raw_artifact_coverage"]["seats"][0][
        "partial_log_coverage"] is True
    assert baseline["attempt_totals"]["failed_attempts"] is None

    # A transient spring after the cutoff cannot create required movement gaps.
    horizon = copy.deepcopy(fixture)
    phases = next(event["phases"] for event in reversed(
        horizon["game_log_events"]) if event["event"] == "seat_activity")
    phases.append({"turn": 16, "phase": "Diplomacy", "seats": [
        {"first_saved_seconds": None, "first_ready_seconds": None}
        for _ in seats]})
    horizon["files"]["results.json"]["final_state"]["turn"] = "16"
    result = report(horizon)
    assert result["activity_rules"]["first_post_horizon_turn"] == 16
    for before, after in zip(seats, result["seats"]):
        assert after["activity"]["required_phases"] == before["activity"][
            "required_phases"]
        assert after["activity"]["sampling_gaps"] == before["activity"][
            "sampling_gaps"]
        assert after["activity"]["post_horizon_obligations_excluded"] == 1

    # Missing final-autumn movement and retreat samples must remain visible.
    for phase, slot in (("Diplomacy", 0), ("Retreats", 2)):
        row = next(row for row in phases if row["turn"] == 15 and
                   row["phase"] == phase)
        row["seats"][slot] = {
            "first_saved_seconds": None, "first_ready_seconds": None}
    result = report(horizon)
    for phase, slot in (("Diplomacy", 0), ("Retreats", 2)):
        assert {"turn": 15, "phase": phase, "saved_unobserved": True,
                "ready_unobserved": True} in result["seats"][slot][
                    "activity"]["sampling_gaps"]
        assert result["seats"][slot]["activity"]["required_phases"] == \
            seats[slot]["activity"]["required_phases"]

    # The cutoff comes from configuration, not a hard-coded turn or end frame.
    later = copy.deepcopy(horizon)
    later["files"]["request.json"]["game_config_overrides"]["end_year"] = 1909
    later["files"]["episode.json"].pop("game_config", None)
    result = report(later)
    assert result["activity_rules"]["first_post_horizon_turn"] == 18
    assert all(seat["activity"]["post_horizon_obligations_excluded"] == 0
               for seat in result["seats"])
    assert all(any(gap["turn"] == 16 for gap in seat["activity"][
        "sampling_gaps"]) for seat in result["seats"])
    unknown = copy.deepcopy(horizon)
    unknown["files"]["request.json"]["game_config_overrides"].pop("end_year")
    unknown["files"]["episode.json"].pop("game_config", None)
    result = report(unknown)
    assert result["activity_rules"]["first_post_horizon_turn"] is None
    assert all(any(gap["turn"] == 16 for gap in seat["activity"][
        "sampling_gaps"]) for seat in result["seats"])

    # Accepted admission is not success; null-status error labels still count.
    attempt_fixture = copy.deepcopy(fixture)
    attempt_fixture["files"]["llm-attempts.json"] = json.loads(
        ATTEMPTS.read_text(encoding="utf-8"))
    result = report(attempt_fixture)
    attempts = result["attempt_totals"]
    assert attempts["attempts"] == 337
    assert attempts["failed_attempts"] == 8
    assert attempts["transport_error_attempts"] == 5
    assert attempts["upstream_transport_error_label_attempts"] == 5
    assert "does not establish a network transport failure" in result["attempt_note"]
    assert attempts["http_error_attempts"] == 3
    assert attempts["failed_without_http_status"] == 5
    assert attempts["successful_response_attempts"] == 329
    assert attempts["unresolved_attempts"] == 0
    assert attempts["policy_results"]["accepted"] == 337
    assert attempts["error_types"] == {
        "upstream_transport_error": 5, "upstream_http_500": 3}
    assert result["policy_means"]["kutuzov"]["attempt_totals"][
        "failed_attempts"] == 3
    assert result["policy_means"]["scott"]["attempt_totals"][
        "failed_attempts"] == 5
    assert result["seats"][3]["attempts"]["failed_attempts"] == 4
    assert len(result["seats"][4]["attempts"]["models"]) == 2
    # Numeric HTTP errors and an error type describe the same failed attempts.
    assert attempts["failed_attempts"] < sum(attempts["error_types"].values()) + \
        attempts["http_error_attempts"]
    incomplete = copy.deepcopy(attempt_fixture)
    incomplete["files"]["llm-attempts.json"]["rows"][0][-1] = None
    assert report(incomplete)["attempt_totals"]["attempts"] is None
    unresolved = ANALYZE.attempt_totals(ANALYZE.attempt_rows({
        "columns": ["slot", "canonical_model", "policy_result", "status_code",
                    "error_type", "attempts"],
        "rows": [[0, "openai/gpt-6.1-sol", "accepted", None, None, 2],
                 [0, "openai/gpt-6.1-sol", "rejected", None, None, 1]]}))
    assert unresolved["unresolved_attempts"] == 2
    assert unresolved["failed_attempts"] == 1
    assert unresolved["policy_rejected_attempts"] == 1

    # A country lead is a heuristic and does not change an official draw.
    leading = copy.deepcopy(fixture)
    set_centers(leading, [12, 7, 3, 3, 2, 4, 3])
    result = report(leading)
    assert result["outcome"] == "drawn"
    assert result["signals"]["kutuzov_solo"] is False
    assert result["signals"]["kutuzov_clear_win_signal"] is True
    assert result["signals"]["top_center_lead_over_runner_up"] == 5
    set_centers(leading, [12, 4, 10, 2, 1, 3, 2])
    assert report(leading)["signals"]["kutuzov_clear_win_signal"] is True
    # A leading country alone is insufficient when the other seats perform poorly.
    set_centers(leading, [12, 8, 0, 7, 0, 7, 0])
    assert report(leading)["signals"]["kutuzov_clear_win_signal"] is False
    assert report(leading)["signals"]["kutuzov_mean_score_exceeds_scott"] is False

    # Official solo evidence is independent of the heuristic center threshold.
    solo = copy.deepcopy(fixture)
    set_centers(solo, [18, 4, 3, 3, 1, 3, 2])
    solo["files"]["results.json"]["outcome"] = "won"
    for member in solo["files"]["results.json"]["members"]:
        if int(member["countryID"]) == 1:
            member["status"] = "Won"
    assert report(solo)["signals"]["kutuzov_solo"] is True
    solo["files"]["results.json"]["members"].append(
        {"countryID": "99", "status": "Won"})
    assert report(solo)["signals"]["kutuzov_solo"] is False

    # Explicit participant identity must beat an obsolete selection label.
    conflict = copy.deepcopy(leading)
    for participant in conflict["files"]["episode.json"]["participants"]:
        if participant["position"] == 0:
            participant["policy_name"] = "different-bot"
            participant["policy_version_id"] = "different-version"
    assert report(conflict)["seats"][0]["policy"] == "unknown"
    assert report(conflict)["signals"]["kutuzov_clear_win_signal"] is None
    duplicate = copy.deepcopy(leading)
    duplicate["files"]["results.json"]["countries"][5] = 1
    assert report(duplicate)["signals"]["available"] is False
    unfinished = copy.deepcopy(fixture)
    unfinished["files"]["episode.json"]["status"] = "submitted"
    assert report(unfinished)["public_game_terminal"] is True
    assert report(unfinished)["signals"]["kutuzov_clear_win_signal"] is None

    # Incomplete final telemetry cannot become complete numerical accounting.
    partial = copy.deepcopy(fixture)
    table = partial["files"]["llm-provider-spend.json"]
    table["rows"][1][table["columns"].index("billed_cost_usd")] = None
    table["rows"][0][table["columns"].index("input_tokens")] = "NaN"
    result = report(partial)
    assert result["seats"][0]["provider"]["billed_cost_usd"] is None
    assert result["seats"][0]["provider"]["known_subtotals"][
        "billed_cost_usd"] == 0.2279821
    assert result["seats"][0]["provider"]["total_input_tokens"] is None
    assert result["provider_totals"]["billed_cost_usd"] is None

    # Missing terminal artifacts, including not_found payloads, remain unknown.
    pending = {"files": {"episode.json": {"status": "submitted"},
        "selection.json": fixture["files"]["selection.json"],
        "results.json": {"type": "not_found"},
        "llm-provider-spend.json": {"columns": ["slot"], "rows": []}}}
    result = report(pending)
    assert result["signals"]["kutuzov_clear_win_signal"] is None
    assert result["policy_means"]["kutuzov"]["mean_centers"] is None
    assert result["exits"]["all_exited_zero"] is None
    assert result["provider_totals"]["billed_calls"] is None
    assert all(seat["activity"]["available"] is False for seat in result["seats"])

    # Only whitelisted numeric and enum fields may leave public source objects.
    sensitive = copy.deepcopy(attempt_fixture)
    secret = "SECRET_SENTINEL_DO_NOT_EXPORT"
    sensitive["files"]["episode.json"]["replay_url"] = secret
    sensitive["files"]["results.json"]["members"][0]["token"] = secret
    sensitive["files"]["player-status.json"]["players"][0]["reason"] = secret
    sensitive["files"]["game.replay"][0]["messages"] = [{"message": secret}]
    sensitive["files"]["audit.json"]["seats"][0]["raw_error"] = secret
    sensitive["files"]["llm-attempts.json"]["rows"][0][1] = secret
    sensitive["files"]["llm-attempts.json"]["rows"][0][4] = secret
    sensitive["game_log_events"].append({"event": "private_press", "body": secret})
    assert secret not in json.dumps(report(sensitive))
    print("Analysis fixture checks passed.")


main()
