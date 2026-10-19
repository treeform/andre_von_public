# Ecos rules

## The field and the clock

- Continuous field, 1000 x 562 world units, no walls and no obstacles. Bodies are
  clamped to the rectangle; there is no wrap-around.
- One episode = 10 generations x 60 ticks = 600 ticks. Playback is 24 fps, so a
  full replay is 25 seconds of video.
- Every sim quantity is an integer. Headings are brads (0..255) resolved through
  a 256-entry integer sine table, and the RNG is a seeded integer stream, so one
  seed reproduces one replay bit-exactly on any host.

## Seats and roles

| slot | alias   | role when roleOffset = 0 | colour |
|------|---------|--------------------------|--------|
| 0    | Sedge   | grass (producer)         | green  |
| 1    | Bramble | grazers (herbivore)      | yellow |
| 2    | Quill   | predators (carnivore)    | red    |

role(slot) = (slot + roleOffset) mod 3, with roleOffset = seed mod 3 unless the
config pins it. Roles rotate; aliases do not. Seats see ONLY the three aliases -
no policy name, player name or account ever reaches a seat.

## The doctrine

| role      | field           | range   | default |
|-----------|-----------------|---------|---------|
| grass     | seed_threshold  | 60..200 | 100     |
| grass     | seed_range      | 24..240 | 90      |
| grass     | seed_cost       | 20..80  | 40      |
| grass     | crowd_limit     | 0..6    | 3       |
| grazers   | birth_threshold | 80..240 | 90      |
| grazers   | bite            | 2..14   | 10      |
| grazers   | flee_range      | 0..300  | 40      |
| grazers   | herd            | 0..100  | 20      |
| predators | birth_threshold | 150..400| 400     |
| predators | hunt_range      | 40..400 | 140     |
| predators | rest_energy     | 0..400  | 200     |
| predators | spread          | 0..100  | 40      |

A doctrine holds until the next generation. Out-of-range values are clamped and
the decision is recorded as clamped; a missing or non-numeric field is an
invalid reply, retried once and then replaced by the steward doctrine.

## Tick resolution order

1. Grass photosynthesis: gain = clamp(grassGain - neighbours within 55, 0,
   grassGain), then minus 1 metabolism, capped at 200.
2. Grazer sense: crowding within 60, stress = min(2, crowd / 6), distance to the
   nearest predator, whether a tuft is within 16.
3. Grazing: bite min(doctrine.bite, tuft energy) from the nearest tuft; the
   grazer keeps 80% of it.
4. Grazer movement and metabolism: grazing bodies hold still; fleeing bodies run
   at 9 (11 with four or more neighbours) for 2; the rest walk at 6 for 1,
   blending food and herd directions by `herd`.
5. Predator sense: crowding within 60, stress = min(2, crowd / 2), cooldown down
   one.
6. Predator act: above rest_energy it idles for 1; otherwise it locks the nearest
   grazer within hunt_range, kills within 16 once every 12 ticks for
   min(180, 90 + the grazer's energy), chases at 12 for 3, or roams at 7 for 2.
7. Positions are clamped to the field.
8. Deaths: grazers marked eaten (predation), then any body at 0 energy or less
   (starve). Dead bodies are removed before births.
9. Births, grass then grazers then predators, each stopping at its cap. Grass
   seeds seed_range away for seed_cost + 10, or pays 10 and fails when the target
   is already crowded. Grazers and predators split at birth_threshold, both
   halves keeping (energy - 20) / 2.
10. Record the tick's state frame, its events and the population/biomass row.

## Scoring

- Instantaneous biomass B(t) is the total energy of your living bodies.
- References: grass 20000, grazers 4000, predators 3000.
- G(g) = (sum of B(t) over generation g) / (60 x your reference).
- Score = sum over the ten generations of min(G(g), 2.0). Higher is better;
  a balanced ecosystem scores roughly 4..13 per seat.
- The episode ends the instant any species reaches 0. Every remaining generation
  scores 0 for all three seats, so a crash costs its author more than restraint
  would have.
