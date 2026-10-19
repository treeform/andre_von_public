import std/os

let sentinelDir = currentSourcePath().parentDir()
let engineSdk = sentinelDir.parentDir().parentDir().parentDir() / "coworld-ctf" / "play_sdk"

switch("path", engineSdk / "examples")
switch("define", "danger")
include "../../../../coworld-ctf/play_sdk/play.nims"

switch("out", sentinelDir / "build" / "sentinel.wasm")
switch("nimcache", sentinelDir / "build" / "sentinel-nimcache")
