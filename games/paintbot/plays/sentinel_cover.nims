import std/os

let sentinel_coverDir = currentSourcePath().parentDir()
let engineSdk = sentinel_coverDir.parentDir().parentDir().parentDir() / "coworld-ctf" / "play_sdk"

switch("path", engineSdk / "examples")
switch("define", "danger")
include "../../../../coworld-ctf/play_sdk/play.nims"

switch("out", sentinel_coverDir / "build" / "sentinel_cover.wasm")
switch("nimcache", sentinel_coverDir / "build" / "sentinel-cover-nimcache")
