"""Patch only the pinned official private-press archive implementation."""

import hashlib
import sys
from pathlib import Path


SOURCE_SHA256 = "210e2816446f8a4d2c0364d36bdc2a8759d4e6209de96bdbee81de98a40f86f3"
LAUNCHER_SHA256 = "251ac151a4e6edb81a17397d20824e4c7d99442c50a5826be164dc41a436af86"
REPLACEMENTS = (
    ("from players.api import WebDiplomacy\n",
     "from players.api import WebDiplomacy\n"
     "from players.kutuzov_artifacts import append_logs, bounded_archive\n"),
    ("with zipfile.ZipFile(buffer, \"w\", zipfile.ZIP_DEFLATED) as archive:\n",
     "with zipfile.ZipFile(buffer, \"w\", zipfile.ZIP_DEFLATED, "
     "compresslevel=1) as archive:\n"),
    ("                archive.writestr(\"private-press.json\", data)\n",
     "                archive.writestr(\"private-press.json\", data)\n"
     "                append_logs(archive)\n"),
    ("                    buffer.getvalue(),\n",
     "                    bounded_archive(buffer.getvalue()),\n"),
)


def patch(source):
    """Fail closed on upstream changes before editing the archive hook."""
    if hashlib.sha256(source).hexdigest() != SOURCE_SHA256:
        raise ValueError("Unsupported official players/press.py source hash.")
    result = source.decode("utf-8")
    for before, after in REPLACEMENTS:
        if result.count(before) != 1:
            raise ValueError("Unsupported official press archive hook target.")
        result = result.replace(before, after, 1)
    compile(result, "players/press.py", "exec")
    return result


def main():
    """Install the checked hook during image construction only."""
    path = Path(sys.argv[1])
    launcher = Path(sys.argv[2])
    result = patch(path.read_bytes())
    launcher_result = patch_launcher(launcher.read_bytes())
    path.write_text(result, encoding="utf-8")
    launcher.write_text(launcher_result, encoding="utf-8")
    print("Installed Kutuzov durable-log archive hook.")


def patch_launcher(source):
    """Add shutdown telemetry after reaping, preserving launcher exit behavior."""
    if hashlib.sha256(source).hexdigest() != LAUNCHER_SHA256:
        raise ValueError("Unsupported official players/launcher.py source hash.")
    result = source.decode("utf-8")
    replacements = (
        ("from players.press import collect\n",
         "from players.press import collect\n"
         "from players.kutuzov_artifacts import record_shutdown\n", 1),
        ("def stop_child(child):\n",
         "def stop_child(child, reason, launcher_status):\n", 1),
        ("    # The command owns its process group, including any subprocesses it starts.\n",
         "    was_running = child.poll() is None\n"
         "    # The command owns its process group, including any subprocesses it starts.\n", 1),
        ("    child.wait(timeout=2)\n\n\ndef finish_press",
         "    child.wait(timeout=2)\n"
         "    record_shutdown(child, reason, launcher_status, was_running)\n"
         "\n\ndef finish_press", 1),
        ("stop_child(child)\n", "stop_child(child, reason, status)\n", 2),
    )
    for before, after, count in replacements:
        if result.count(before) != count:
            raise ValueError("Unsupported official launcher shutdown hook target.")
        result = result.replace(before, after)
    compile(result, "players/launcher.py", "exec")
    return result


if __name__ == "__main__":
    main()
