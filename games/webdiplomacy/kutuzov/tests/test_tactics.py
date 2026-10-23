"""Focused offline fixtures for public replay tactical measurements."""

import importlib.util
import json
from pathlib import Path


SPEC = importlib.util.spec_from_file_location(
    "tactics", Path(__file__).resolve().parents[1] / "tools/tactics.py")
TACTICS = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(TACTICS)


def move(success=False):
    """Build one public movement order with an explicit adjudication result."""
    return {"countryID": 1, "terrID": 1, "toTerrID": 2,
            "unitType": "Army", "type": "Move", "success": success,
            "viaConvoy": False}


def frame(turn, orders, identifier=10):
    """Pair published orders with a pre-movement stable unit identity."""
    return {"game": {"turn": turn, "phase": "Diplomacy", "units": [
        {"id": identifier, "countryID": 1, "terrID": 1, "type": "Army"}]},
        "history": {"phases": [{"turn": turn, "phase": "Diplomacy",
                                 "orders": orders}]},
        "messages": {"private": "NEVER_EXPORT_PRIVATE_TEXT"}}


def test_repeated_failures():
    """Require identical orders, stable identities, and adjacent failed turns."""
    frames = [frame(turn, [move()]) for turn in range(4)]
    report = TACTICS.analyze(frames)
    result = report["countries"][0]
    assert result["same_unit_repeat_pairs"] == 3
    assert result["repeat_failed_move_runs"][0]["consecutive_failed_moves"] == 4
    assert "NEVER_EXPORT_PRIVATE_TEXT" not in json.dumps(report)
    replaced = TACTICS.analyze([frame(0, [move()]), frame(1, [move()], 11)])
    assert replaced["countries"][0]["same_unit_repeat_pairs"] == 0
    assert replaced["countries"][0]["replaced_unit_repeat_pairs_excluded"] == 1
    unknown = TACTICS.analyze([frame(0, [move()], None), frame(1, [move()])])
    assert unknown["countries"][0]["unknown_identity_repeat_pairs"] == 1
    gap = TACTICS.analyze([frame(0, [move()]), frame(2, [move()])])
    assert gap["countries"][0]["same_unit_repeat_pairs"] == 0
    success = TACTICS.analyze([frame(0, [move()]), frame(1, [move(True)])])
    assert success["countries"][0]["same_unit_repeat_pairs"] == 0
    missing = TACTICS.analyze([frame(0, [move(None)])])["countries"][0]
    assert missing["failed_moves"] == 0 and missing["unknown_move_outcomes"] == 1


def test_holds_and_deduplication():
    """Do not count Hold success=false as failed or duplicate history frames."""
    hold = {**move(), "type": "Hold", "toTerrID": None}
    original = frame(0, [hold, {**move(), "terrID": 3}])
    result = TACTICS.analyze([original, original])["countries"][0]
    assert result["movement_orders"] == 2
    assert result["hold_orders"] == 1 and result["hold_share"] == 0.5
    assert result["failed_moves"] == 1
    assert TACTICS.analyze([])["countries"][0]["hold_share"] is None
    assert TACTICS.analyze([])["countries"][0]["movement_orders"] is None
    missing = {"history": {"phases": [{"turn": 0, "phase": "Diplomacy"}]}}
    result = TACTICS.analyze([missing])
    assert result["countries"][0]["movement_orders"] is None
    assert result["missing_order_phases"] == [0]


def test_supports():
    """Separate own disagreements from foreign supports and unknown movers."""
    territories = {12: {"parent": 2}, 13: {"parent": 3}}
    support = {"countryID": 1, "terrID": 1, "type": "Support move",
               "fromTerrID": 2, "toTerrID": 3}
    own = {"countryID": 1, "terrID": 12, "type": "Move", "toTerrID": 13}
    check = TACTICS.check_support(support, [support, own], [], territories)
    assert check["classification"] == "own_order_agrees"
    disagree = TACTICS.check_support(
        support, [support, {**own, "toTerrID": 4}], [], territories)
    assert disagree["classification"] == "own_order_disagrees"
    foreign = TACTICS.check_support(
        support, [support, {**own, "countryID": 2, "type": "Hold"}], [], territories)
    assert foreign["classification"] == "foreign_unit_reference"
    assert foreign["order_agrees"] is False
    missing = TACTICS.check_support(support, [support], [], territories)
    assert missing["classification"] == "unknown_no_known_mover"
    no_order = TACTICS.check_support(
        support, [support], [{"countryID": 1, "terrID": 12}], territories)
    assert no_order["classification"] == "own_unit_order_unavailable"


def test_centers():
    """Exclude pre-game placeholders and preserve missing annual totals."""
    def snapshot(turn, phase, count):
        """Build a public center-count observation for one country."""
        return {"game": {"turn": turn, "phase": phase,
                         "members": [{"countryID": 1, "supplyCenterNo": count}]}}
    result = TACTICS.centers([
        snapshot(0, "Pre-game", 0), snapshot(0, "Diplomacy", 3),
        snapshot(1, "Diplomacy", 3), snapshot(1, "Builds", 5),
        snapshot(2, "Diplomacy", 5), snapshot(3, "Retreats", 4)])
    assert result["initial"]["centers"]["1"] == 3
    assert result["year_end"][0]["centers"]["1"] == 5
    assert result["year_end"][1]["centers"]["1"] is None
    assert result["year_end"][0]["centers"]["2"] is None


test_repeated_failures()
test_holds_and_deduplication()
test_supports()
test_centers()
print("Public tactical analyzer fixtures passed.")
