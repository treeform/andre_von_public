# Hosted replay recovery

- League: `league_d7e141f9-ee29-4a46-b15c-5bbdb1639a44` (`nmmo`).
- Most recent completed round: 2005,
  `round_d978b5e9-da00-44ff-a831-33c78ea07c59`,
  completed 2026-08-17 20:01:54 UTC.
- Preceding completed round: 2004,
  `round_eb1153c7-361c-471d-bb2f-154193c4324f`,
  completed 2026-08-17 19:53:16 UTC.
- Round 2005 returned 8 public binary replay artifacts. Round 2004
  requested separately for more historical behavior samples.
- Episode metadata resolves the game to
  `cow_09f084aa-cb18-4e7c-b3ac-07fc43132692`, NMMO 0.1.4.
- That coworld remains readable by ID and is noncanonical. Its source is
  commit `cb4a10878834793dc30325c5221e6cab1cdb9b58`.
- The 0.1.4 manifest uses the pretrained PufferLib baseline, 8 seats,
  1 agent per seat, 5000 maximum ticks, and 1000ms tick deadline.
- `episode-logs ... --list` for
  `ereq_29faff5c-74bf-4a32-a0b5-9f923ef065ad` returned 403:
  "You do not have access to this episode request". No private log
  access was attempted after that denial.

## Commands

Run from `/Users/me/p/andre_von_auto`:

```
uv --project /Users/me/p/metta run coworld rounds --league league_d7e141f9-ee29-4a46-b15c-5bbdb1639a44 --status completed --limit 2 --json
uv --project /Users/me/p/metta run coworld replays --round round_d978b5e9-da00-44ff-a831-33c78ea07c59 --download-dir /Users/me/p/andre_von_auto/games/nmmo/buyan/replays_tools/hosted --limit 10 --json
uv --project /Users/me/p/metta run coworld replays --round round_eb1153c7-361c-471d-bb2f-154193c4324f --download-dir /Users/me/p/andre_von_auto/games/nmmo/buyan/replays_tools/hosted --limit 10 --json
uv --project /Users/me/p/metta run coworld show cow_09f084aa-cb18-4e7c-b3ac-07fc43132692 --json
uv --project /Users/me/p/metta run coworld episode-logs ereq_29faff5c-74bf-4a32-a0b5-9f923ef065ad --list
```

## Evidence limits

These are hosted historical league artifacts, not a new XP comparison.
They cannot justify keeping or submitting a candidate. Binary replays
contain post-clamp actions and a final result, without per-tick
observations. They prove action choices only. In particular, attack
actions do not prove hits, movement does not prove distance traveled,
and inventory keys also serve market selections and prices.

The first five seats in both rounds are fixed:

| Seat | Player | Policy version ID |
| --- | --- | --- |
| 0 | relh | f879e7d1-4579-46b3-8322-405ee59165c9 |
| 1 | daveey | ee828572-195d-4318-bdbb-0b4cb2bc1295 |
| 2 | PufferLib | 77323624-430a-46f9-9c22-ee4096a0c67e |
| 3 | daveey-1 | a319845e-01db-4d23-a938-3f4ed55f02be |
| 4 | richard | 856588e8-842f-4378-a41f-e174b364a2c6 |

Extra seats duplicate these policies in varying order. Use the saved
round replay metadata to attribute those extra seats.
