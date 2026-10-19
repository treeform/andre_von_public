import std/os

let shieldAimRideDir = currentSourcePath().parentDir()
let engineSdk = shieldAimRideDir.parentDir().parentDir().parentDir() / "coworld-ctf" / "play_sdk"

switch("path", engineSdk / "examples")
switch("define", "danger")
switch("define", "shieldRideAim")
include "../../../../coworld-ctf/play_sdk/play.nims"

switch("out", shieldAimRideDir / "build" / "shield_aim_ride.wasm")
switch("nimcache", shieldAimRideDir / "build" / "shield-aim-ride-nimcache")
