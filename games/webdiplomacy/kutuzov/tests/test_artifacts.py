"""Exercise the pinned official archive hook without network or a match."""

import hashlib
import importlib.util
import io
import json
import os
import sys
import tempfile
import types
import zipfile
from pathlib import Path


TOOLS = Path(__file__).resolve().parents[1] / "tools"


def load(name, filename):
    """Load the hook modules directly from the repository."""
    spec = importlib.util.spec_from_file_location(name, TOOLS / filename)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main():
    """Test source pinning and real ZIP contents through PressArchive.finish."""
    hook = load("kutuzov_artifacts", "kutuzov_artifacts.py")
    installer = load("install_artifact_hook", "install_artifact_hook.py")
    original = Path(sys.argv[1]).read_bytes()
    if hashlib.sha256(original).hexdigest() != installer.SOURCE_SHA256:
        # The same check can run against the rebuilt, already-patched image.
        restored = original.decode("utf-8")
        for before, after in reversed(installer.REPLACEMENTS):
            assert restored.count(after) == 1, "Unexpected installed hook."
            restored = restored.replace(after, before, 1)
        assert hashlib.sha256(restored.encode()).hexdigest() == installer.SOURCE_SHA256
        original = restored.encode()
    patched = installer.patch(original)
    assert original.decode().count("append_logs") == 0
    try:
        installer.patch(original + b"\n")
        raise AssertionError("Unsupported upstream source was accepted.")
    except ValueError:
        pass
    # Stub only the API and upload boundary, retaining the real finish method.
    uploads = []
    api = types.ModuleType("players.api")
    api.WebDiplomacy = object
    artifacts = types.ModuleType("adapter.artifacts")
    artifacts.write_artifact = lambda uri, body, *args, **kwargs: uploads.append(body)
    sys.modules.update({"players.api": api, "adapter.artifacts": artifacts,
                        "players.kutuzov_artifacts": hook})
    namespace = {}
    exec(compile(patched, "players/press.py", "exec"), namespace)
    player = types.SimpleNamespace(
        game_id=1, country_id=3,
        context=lambda: {"messages": {"messages": []}})
    with tempfile.TemporaryDirectory() as temporary:
        directory = Path(temporary)
        os.environ["KUTUZOV_LOG_DIR"] = temporary
        os.environ["COWORLD_PLAYER_ARTIFACT_UPLOAD_URL"] = "test://discard"
        details = b'{"event":"http_response","body":{"ok":true}}\n'
        events = b'{"event":"process_return","code":0}\n'
        (directory / "details.jsonl").write_bytes(details)
        (directory / "events.jsonl").write_bytes(events)
        hook.record_shutdown(types.SimpleNamespace(pid=123, returncode=-15),
                             "game_over", 0, True)
        for reason in ["game_over", "interrupted"]:
            namespace["PressArchive"](player).finish(reason)
            with zipfile.ZipFile(io.BytesIO(uploads[-1])) as archive:
                assert set(archive.namelist()) == {
                    "private-press.json", "logs/events.jsonl",
                    "logs/details.jsonl", "logs/manifest.json",
                    "logs/launcher-shutdown.json"}
                press = json.loads(archive.read("private-press.json"))
                assert press["complete"] == (reason == "game_over")
                assert press["reason"] == reason
                assert archive.read("logs/details.jsonl") == details
                assert archive.read("logs/events.jsonl") == events
                manifest = json.loads(archive.read("logs/manifest.json"))
                assert manifest["complete"]
                for record in manifest["files"]:
                    payload = archive.read(record["path"])
                    assert record["archived_bytes"] == len(payload)
                    assert record["sha256"] == hashlib.sha256(payload).hexdigest()
        (directory / "details.jsonl").unlink()
        (directory / "details.jsonl").symlink_to(directory / "events.jsonl")
        namespace["PressArchive"](player).finish("game_over")
        with zipfile.ZipFile(io.BytesIO(uploads[-1])) as archive:
            assert "logs/details.jsonl" not in archive.namelist()
            assert not json.loads(archive.read("logs/manifest.json"))["complete"]
        (directory / "details.jsonl").unlink()
        (directory / "details.jsonl").write_bytes(os.urandom(8192))
        hook.MAX_ARCHIVE_BYTES = 2048
        namespace["PressArchive"](player).finish("game_over")
        assert len(uploads[-1]) <= hook.MAX_ARCHIVE_BYTES
        with zipfile.ZipFile(io.BytesIO(uploads[-1])) as archive:
            assert archive.read("logs/events.jsonl") == events
            assert "private-press.json" in archive.namelist()
            assert "logs/details.jsonl" not in archive.namelist()
            manifest = json.loads(archive.read("logs/manifest.json"))
            assert not manifest["complete"]
            records = {record["path"]: record for record in manifest["files"]}
            assert records["logs/details.jsonl"]["status"] == "omitted_archive_size_limit"
        hook.MAX_ARCHIVE_BYTES = 200 * 1024 * 1024
        hook.ARCHIVE_SECONDS = 0
        namespace["PressArchive"](player).finish("interrupted")
        with zipfile.ZipFile(io.BytesIO(uploads[-1])) as archive:
            manifest = json.loads(archive.read("logs/manifest.json"))
            assert all(record["status"] == "time_limit"
                       for record in manifest["files"])
    print("Pinned launcher archive checks passed.")


if __name__ == "__main__":
    main()
