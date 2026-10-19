import std/os

let aimRideDir = currentSourcePath().parentDir()
let engineSdk = aimRideDir.parentDir().parentDir().parentDir() / "coworld-ctf" / "play_sdk"

switch("path", engineSdk / "examples")
switch("define", "danger")
include "../../../../coworld-ctf/play_sdk/play.nims"

switch("out", aimRideDir / "build" / "aim_ride.wasm")
switch("nimcache", aimRideDir / "build" / "aim-ride-nimcache")
