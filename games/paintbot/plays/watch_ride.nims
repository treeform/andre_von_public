import std/os

let watchRideDir = currentSourcePath().parentDir()
let engineSdk = watchRideDir.parentDir().parentDir().parentDir() / "coworld-ctf" / "play_sdk"

switch("path", engineSdk / "examples")
switch("define", "danger")
include "../../../../coworld-ctf/play_sdk/play.nims"

switch("out", watchRideDir / "build" / "watch_ride.wasm")
switch("nimcache", watchRideDir / "build" / "watch-ride-nimcache")
