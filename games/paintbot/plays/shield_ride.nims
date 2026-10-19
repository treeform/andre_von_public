import std/os

let shieldRideDir = currentSourcePath().parentDir()
let engineSdk = shieldRideDir.parentDir().parentDir().parentDir() / "coworld-ctf" / "play_sdk"

switch("path", engineSdk / "examples")
switch("define", "danger")
include "../../../../coworld-ctf/play_sdk/play.nims"

switch("out", shieldRideDir / "build" / "shield_ride.wasm")
switch("nimcache", shieldRideDir / "build" / "shield-ride-nimcache")
