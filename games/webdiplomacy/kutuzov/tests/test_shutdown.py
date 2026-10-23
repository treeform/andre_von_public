"""Exercise real launcher control flow with fake transport and child processes."""

import contextlib
import importlib.util
import io
import json
import os
import signal
import subprocess
import sys
import tempfile
import types
import zipfile
from pathlib import Path
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
OFFICIAL = Path(sys.argv[1])


def load(name, path):
    """Load one isolated candidate without importing production modules."""
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def scenario(initial_returncode, ignore_term=False):
    """Prove reaping and durable observation precede archive construction."""
    hook = load("isolated_artifacts", ROOT / "tools/kutuzov_artifacts.py")
    installer = load("isolated_installer", ROOT / "tools/install_artifact_hook.py")
    source = installer.patch_launcher(OFFICIAL.read_bytes())
    try:
        installer.patch_launcher(OFFICIAL.read_bytes() + b"\n")
        raise AssertionError("Unpinned launcher source was accepted.")
    except ValueError:
        pass
    trace = []
    captured = {}

    class Child:
        """Represent a child whose exit behavior is entirely controlled."""

        pid = 1234
        returncode = initial_returncode

        def poll(self):
            """Report the child status without launching a process."""
            return self.returncode

        def wait(self, timeout):
            """Model wait success or the ignored-SIGTERM timeout."""
            trace.append("wait")
            if self.returncode is None:
                raise subprocess.TimeoutExpired("fake-child", timeout)
            trace.append("reaped")
            return self.returncode

    child = Child()

    def killpg(pid, number):
        """Model signals and reject calls after the fake child exits."""
        assert pid == child.pid
        trace.append("SIGTERM" if number == signal.SIGTERM else "SIGKILL")
        if child.returncode is not None:
            raise ProcessLookupError()
        if number == signal.SIGTERM and ignore_term:
            return
        child.returncode = -number

    class Control:
        """Build the archive when the launcher requests final collection."""

        def send(self, reason):
            """Read lifecycle metadata only after the direct child is reaped."""
            assert "reaped" in trace
            assert child.returncode is not None
            trace.append("archive")
            data = io.BytesIO()
            with zipfile.ZipFile(data, "w", zipfile.ZIP_DEFLATED) as archive:
                archive.writestr("private-press.json", json.dumps({"reason": reason}))
                hook.append_logs(archive)
            with zipfile.ZipFile(io.BytesIO(data.getvalue())) as archive:
                captured["lifecycle"] = json.loads(archive.read("logs/launcher-shutdown.json"))
                captured["manifest"] = json.loads(archive.read("logs/manifest.json"))

        def close(self):
            """Close the fake control channel."""
            pass

    class Worker:
        """Represent the independently owned archive worker."""

        exitcode = 0

        def start(self):
            """Model a successful worker start."""
            pass

        def join(self, timeout):
            """Model already completed archive collection."""
            pass

        def is_alive(self):
            """Report that archive collection completed."""
            return False

    class WebSocket:
        """Supply one handshake and one game-over notification."""

        def __init__(self):
            """Initialize the deterministic protocol cursor."""
            self.cursor = 0

        def __enter__(self):
            """Open the fake context."""
            return self

        def __exit__(self, *arguments):
            """Close the fake context."""
            return False

        def recv(self, timeout):
            """Yield valid launcher messages without network access."""
            self.cursor += 1
            if self.cursor == 1:
                return json.dumps({
                    "protocol": "webdip-coworld/1", "slot": 2,
                    "webdip": {"base_url": "http://fixture", "api_key": "fixture",
                               "game_id": 1, "country_id": 3},
                    "rules": {"seed": 0, "end_year": 1908,
                              "scoring": "sum_of_squares"}})
            return json.dumps({"type": "game_over", "results": {"outcome": "drawn"}})

        def send(self, message):
            """Require acknowledgement only after the archive is complete."""
            assert json.loads(message)["type"] == "game_over_ack"
            assert "archive" in trace
            trace.append("ack")

    exceptions = types.ModuleType("websockets.exceptions")
    exceptions.ConnectionClosed = type("ConnectionClosed", (Exception,), {})
    client = types.ModuleType("websockets.sync.client")
    client.connect = lambda *arguments, **keywords: WebSocket()
    press = types.ModuleType("players.press")
    press.collect = lambda *arguments: None
    modules = {"websockets.exceptions": exceptions,
               "websockets.sync.client": client,
               "players.press": press,
               "players.kutuzov_artifacts": hook}
    with tempfile.TemporaryDirectory() as temporary:
        folder = Path(temporary)
        (folder / "events.jsonl").write_text('{"event":"phase_ready","sequence":1}\n')
        (folder / "details.jsonl").write_text('{"event":"phase_ready","sequence":1}\n')
        with patch.dict(os.environ, {"KUTUZOV_LOG_DIR": temporary}):
            with patch.dict(sys.modules, modules):
                namespace = {"__name__": "isolated_launcher"}
                exec(compile(source, "players/launcher.py", "exec"), namespace)
            namespace["os"] = types.SimpleNamespace(
                environ={"COWORLD_PLAYER_WS_URL": "ws://fixture/player?slot=2"},
                killpg=killpg)
            namespace["sys"] = types.SimpleNamespace(
                argv=["launcher", "/opt/kutuzov"], executable="/fake/python")
            namespace["signal"] = types.SimpleNamespace(
                SIGTERM=signal.SIGTERM, SIGKILL=signal.SIGKILL,
                SIGINT=signal.SIGINT, signal=lambda *arguments: None)
            namespace["subprocess"] = types.SimpleNamespace(
                Popen=lambda *arguments, **keywords: child,
                TimeoutExpired=subprocess.TimeoutExpired)
            receiver = types.SimpleNamespace(close=lambda: None)
            context = types.SimpleNamespace(
                Pipe=lambda **keywords: (receiver, Control()),
                Process=lambda **keywords: Worker())
            namespace["multiprocessing"] = types.SimpleNamespace(
                get_context=lambda *arguments: context)
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                status = namespace["main"]()
    expected_returncode = initial_returncode
    if expected_returncode is None:
        expected_returncode = -signal.SIGKILL if ignore_term else -signal.SIGTERM
    lifecycle = captured["lifecycle"]
    assert status == (initial_returncode or 0)
    assert lifecycle["child_returncode"] == expected_returncode
    assert lifecycle["launcher_status"] == status
    assert lifecycle["child_running_before_stop"] == (initial_returncode is None)
    assert "launcher_stop_requested" not in lifecycle
    assert lifecycle["collection_order"] == "after_child_reaped_before_archive"
    assert lifecycle["reason"] == "game_over"
    assert captured["manifest"]["complete"] is True
    assert trace.index("reaped") < trace.index("archive") < trace.index("ack")
    assert output.getvalue().count('"event": "launcher_child_stopped"') == 1
    assert "process_return" not in output.getvalue()
    return {"initial_returncode": initial_returncode,
            "ignored_sigterm": ignore_term,
            "child_returncode": expected_returncode,
            "launcher_status": status, "ordering": trace}


def telemetry_failures():
    """Preserve durable logging when normal and fallback stdout writes fail."""
    hook = load("isolated_artifacts", ROOT / "tools/kutuzov_artifacts.py")
    child = types.SimpleNamespace(pid=1234, returncode=-signal.SIGTERM)
    results = []

    class FailingOutput:
        """Fail at the selected stdout boundary without touching real stdout."""

        def __init__(self, boundary):
            """Track both attempts when durable logging also fails."""
            self.boundary = boundary
            self.writes = 0
            self.flushes = 0

        def write(self, value):
            """Simulate a broken stdout pipe during printing."""
            self.writes += 1
            if self.boundary == "write":
                raise BrokenPipeError("fixture write failure")
            return len(value)

        def flush(self):
            """Simulate a flush failure after a successful buffered write."""
            self.flushes += 1
            raise OSError("fixture flush failure")

    with tempfile.TemporaryDirectory() as temporary:
        folder = Path(temporary)
        for boundary in ("write", "flush"):
            destination = folder / boundary
            output = FailingOutput(boundary)
            with patch.dict(os.environ, {"KUTUZOV_LOG_DIR": str(destination)}):
                with contextlib.redirect_stdout(output):
                    hook.record_shutdown(child, "game_over", 0, True)
            lifecycle = json.loads(
                (destination / "launcher-shutdown.json").read_text())
            assert lifecycle["child_returncode"] == -signal.SIGTERM
            assert lifecycle["child_running_before_stop"] is True
            assert "launcher_stop_requested" not in lifecycle
            assert output.writes >= 1
            assert output.flushes == (1 if boundary == "flush" else 0)
            assert not list(destination.glob(".launcher-shutdown-*"))

            blocked = folder / (boundary + "-blocked")
            blocked.write_text("This regular file prevents directory creation.")
            failed = FailingOutput(boundary)
            with patch.dict(os.environ, {"KUTUZOV_LOG_DIR": str(blocked)}):
                with contextlib.redirect_stdout(failed):
                    hook.record_shutdown(child, "game_over", 0, True)
            assert failed.writes >= 2
            assert failed.flushes == (2 if boundary == "flush" else 0)
            results.append({"stdout_failure": boundary,
                            "durable_record_preserved": True,
                            "fallback_stdout_failure_contained": True})
    return results


def main():
    """Cover requested SIGTERM, SIGKILL escalation, and preexisting exits."""
    results = [scenario(None), scenario(None, True), scenario(0), scenario(7)]
    print(json.dumps(results, indent=2))
    print(json.dumps(telemetry_failures(), indent=2))
    print("Isolated launcher lifecycle checks passed; no processes or network used.")


if __name__ == "__main__":
    main()

