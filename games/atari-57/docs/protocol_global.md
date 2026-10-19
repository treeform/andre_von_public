THE SPECTATOR SOCKET (ws://<game>/global) AND THE REPLAY BYTES

/global carries the same Sprite v1 board every viewer draws — the 2x2
quad-split of four 17x17 screens on one 1400x1400 board — plus ONE reserved
never-drawn 1x1 sprite (id 4090) whose LABEL is the whole JSON chrome frame.
That frame carries: `t`/`mt`/`ph`/`sp`/`mx`/`st`/`en` (the transport), `teams`
keyed red/blue/green/yellow with each lane's score, points, lives,
livesPerLane, screen, record flag and over flag, `roster` (the REAL policy
names — spectator side only), `events`, `a57` (the rom, the par, and each
lane's tiles, sprites, avatar and standing stance), `stances`, `lead` (the
momentum series), `beats`, `lulls` and, at game over, `over`.

THE REPLAY is the starter's binary COWLDA57 format and is SELF-SUFFICIENT:

  header      magic COWLDA57, format version, gameName atari-57, gameVersion 1
  config JSON seed, rom, the FULLY RESOLVED cartridge preset, the loaded map's
              17 rows verbatim and its sha256, the whole geometry table, the
              point tables, the scoring constants, the real player names and
              the in-game aliases
  joins       one per seat
  inputs      THE ACTION LOG: one action byte per seat per tick, written on
              change only. dir = cmd mod 5 (0 stay, 1 up, 2 down, 3 left,
              4 right); act = cmd div 5 (0 none, 1 fire, 2 brake); cmd >= 15
              is repaired to 0 identically on both sides
  chats       register / stance / fallback / budget_guard / stopped / result
  hashes      one gameHash per tick — the integrity chain the wasm viewer
              re-checks against its own re-simulation, every tick

The viewer is a STATIC wasm bundle (`replay_viewer.bundle =
static-replay-viewer`): it re-runs the same sim module the server ran from the
recorded action bytes and contacts no server but S3. `tools/replay_summary.py`
(Python 3 stdlib only) prints one strict-UTF-8 JSON object from a replay
file.