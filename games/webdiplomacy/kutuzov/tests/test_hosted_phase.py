"""Check local phase ceilings and recovery reservations without network calls."""

import contextlib
import hashlib
import importlib.util
import io
import json
import tempfile
import types
from pathlib import Path


HELPER = Path(__file__).resolve().parents[1] / "tools" / "hosted.py"


def expect_failure(hosted, message, operation):
    """Require a guard failure before any external operation is attempted."""
    try:
        operation()
    except hosted.HostedError as error:
        assert message in str(error), error
    else:
        raise AssertionError("Expected phase guard to reject the operation.")


def main():
    """Exercise limits, ambiguous recovery, locking, and legacy created runs."""
    spec = importlib.util.spec_from_file_location("hosted", HELPER)
    hosted = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(hosted)

    def no_network(*args, **kwargs):
        """Make accidental real or mock API submission impossible in this test."""
        raise AssertionError("Network functions must not be called.")

    hosted.request = no_network
    with tempfile.TemporaryDirectory() as temporary:
        root = Path(temporary).resolve()
        phase = root / "phase-one"
        args = types.SimpleNamespace(directory=phase, max_games=2)
        with contextlib.redirect_stdout(io.StringIO()):
            hosted.initialize_phase(args)
        assert hosted.phase_config(phase)["max_games"] == 2
        args.max_games = 3
        expect_failure(hosted, "cannot be changed",
                       lambda: hosted.initialize_phase(args))
        for invalid in [0, 8, True]:
            hosted.save(root / "bad" / "phase.json",
                        {"schema_version": 1, "max_games": invalid})
            expect_failure(hosted, "between 1 and 7",
                           lambda: hosted.phase_config(root / "bad"))
        first = phase / "game-001"
        second = phase / "game-002"
        first.mkdir()
        second.mkdir()
        selection = {"analysis_phase_dir": str(phase)}
        assert hosted.phase_directory(first, selection) == phase
        expect_failure(hosted, "inside its analysis phase",
                       lambda: hosted.phase_directory(root / "outside", selection))
        with hosted.phase_lock(phase):
            initial = hosted.reserve_submission(first, phase, "digest-a", "key-a")
            assert initial == {"known_games": 0, "reserved_games": 1,
                               "max_games": 2, "idempotent_retry": False}
            retry = hosted.reserve_submission(first, phase, "digest-a", "key-a")
            assert retry["idempotent_retry"] and retry["reserved_games"] == 1
            expect_failure(hosted, "differs from its reservation",
                           lambda: hosted.reserve_submission(
                               first, phase, "changed", "key-a"))
            expect_failure(hosted, "ambiguous outcome",
                           lambda: hosted.reserve_submission(
                               second, phase, "digest-b", "key-b"))
            with hosted.phase_lock(root / "bad"):
                pass
            expect_failure(hosted, "submission is resolving",
                           lambda: hosted.phase_lock(phase).__enter__())
        hosted.save(first / "created.json", {"id": "xreq_first",
                                             "episode_count": 1})
        hosted.save(phase / "copied-evidence" / "created.json",
                    {"id": "xreq_first", "episode_count": 1})
        with hosted.phase_lock(phase):
            next_game = hosted.reserve_submission(second, phase, "digest-b", "key-b")
            assert next_game["known_games"] == 1
        hosted.save(second / "created.json", {"id": "xreq_second",
                                              "episode_count": 1})
        third = phase / "game-003"
        third.mkdir()
        expect_failure(hosted, "limit reached",
                       lambda: hosted.reserve_submission(
                           third, phase, "digest-c", "key-c"))
        # Seven is a hard ceiling, including games marked failed or canceled.
        seven = root / "phase-seven"
        hosted.save(seven / "phase.json", {"schema_version": 1, "max_games": 7})
        for number in range(7):
            hosted.save(seven / str(number) / "created.json",
                        {"id": f"xreq_{number}", "episode_count": 1,
                         "status": "failed"})
        expect_failure(hosted, "limit reached",
                       lambda: hosted.reserve_submission(
                           seven / "eighth", seven, "digest-d", "key-d"))
        # Existing created runs return without phase access or another POST.
        legacy = root / "legacy"
        policy = "00000000-0000-0000-0000-000000000001"
        roster = [{"slot": slot, "player": {"policy_ref":
                   policy if slot % 2 == 0 else hosted.SCOTT_VERSION}}
                  for slot in range(7)]
        hosted.save(legacy / "request.json", {
            "num_episodes": 1, "roster": roster, "idempotency_key": "old",
            "target": {"league_id": hosted.LEAGUE}})
        hosted.save(legacy / "selection.json", {"kutuzov_version_id": policy})
        hosted.save(legacy / "submission.json", {
            "request_sha256": hashlib.sha256(
                (legacy / "request.json").read_bytes()).hexdigest(),
            "idempotency_key": "old"})
        hosted.save(legacy / "created.json", {
            "id": "xreq_legacy", "status": "completed", "episode_count": 1,
            "episodes": [{"id": "ereq_legacy", "status": "completed",
                          "participants": [
                              {"position": entry["slot"], "policy_version_id":
                               entry["player"]["policy_ref"]} for entry in roster]}]})
        before = {p.name: p.read_bytes() for p in legacy.iterdir()}
        with contextlib.redirect_stdout(io.StringIO()):
            hosted.submit(types.SimpleNamespace(directory=legacy))
        assert before == {p.name: p.read_bytes() for p in legacy.iterdir()}
        hosted.save(legacy / "selection.json", {
            "kutuzov_version_id": policy, "analysis_phase_dir": str(phase)})
        with contextlib.redirect_stdout(io.StringIO()):
            hosted.submit(types.SimpleNamespace(directory=legacy))
    print("Hosted phase guard checks passed without network access.")


if __name__ == "__main__":
    main()
