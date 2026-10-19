# Candidate identity audit

2026-09-12: The first three hosted requests were the same submitted
gorynych:v1 deliberately measured against three different opponents.
All 30 games have two distinct real policy participants and five heroes
per policy. These requests are baseline data, not three experiments.

| Request | Other policy |
|---|---|
| xreq_a9bef67c-adb0-41bc-8a13-c8ada492611b | moba-example:v1 |
| xreq_43f0f8bf-48b3-48c7-a020-789ad65ed564 | pufferlib-baseline:v1 |
| xreq_980e792f-837f-4740-bcc4-2792aeb6712c | docxology-ply_176e1e1a-7af8-40f7-9ee3-a67b96690ad6:v1 |

Candidate source SHA256 prefixes at the first audit were all distinct:
occupancy 06de4ad93490, topstack bed2bf6f9fae, soak 88983e88ee47,
haste eed5f2b575f0, recovery 5f79e5869529. Haste and recovery were still
under review, so their release hashes may differ from this snapshot.

Each test imports/includes its own local candidate.nim. Occupancy,
topstack and soak passed a second isolation run with separate explicit
nimcache directories. Their Dockerfiles COPY their own candidate source.

| Candidate | Code commit | Docker image SHA256 prefix | Upload |
|---|---|---|---|
| occupancy | 353a3ca | 00b54f6202c7 | gorynych-occupancy-20260912:v1 |
| topstack | 9679ecf | 587fb46beb3c | gorynych-topstack-20260912:v1 |
| soak | da63010 | ce0a58cb1e11 | gorynych-soak-20260912:v1 |

The dashboard with only our player selected and top=0 drops opponent
pairs. pages.nim then infers solo mode from an empty matchup collection.
This is a display bug. Actual request and episode records show opponents.

Process correction: independent Grok lanes now execute CPUX immediately
after passing checks. Supervisor review no longer delays hosted trials.

Identity correction: the four original candidate versions above were
attributed to Andre von Houck. Their rosters revealed the mismatch.
Explicit player use plus authenticated whoami now verifies Andre von Auto.
An API query filtered to that player confirms corrected ownership.
The user now requires policy name gorynych with one version per idea.
All five lanes are uploading unchanged images under that convention.
The earlier candidate scores cannot authorize submission.
