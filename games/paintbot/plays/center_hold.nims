import std/os

let centerHoldDir = currentSourcePath().parentDir()
let engineSdk = centerHoldDir.parentDir().parentDir().parentDir() / "coworld-ctf" / "play_sdk"

switch("path", engineSdk / "examples")
switch("define", "danger")
include "../../../../coworld-ctf/play_sdk/play.nims"

switch("out", centerHoldDir / "build" / "center_hold.wasm")
switch("nimcache", centerHoldDir / "build" / "center-hold-nimcache")
