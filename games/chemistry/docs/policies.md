# Fielding a policy

A policy is a prompt. Reuse the published player runnable and set `PLAYER_PROMPT` to your strategy:

    coworld upload-policy <chemistry-image> --name my-chemistry \
      --run /bin/chemistry-player \
      --secret-env PLAYER_PROMPT="<your strategy>"

Set `USE_BEDROCK=true` alongside it: without it the platform gives the player pod no Bedrock sidecar and the seat silently plays scripted.

## The standing order
Once per shift the game sends your seat the whole room state and your prompt, and expects exactly one JSON object whose first character is `{`:

    {"job":"supply","molecule":"resin","reactor":"cobalt",
     "say":"Cobalt is cold - I bring resin, someone bring brine",
     "notes":"amber at 7 and safe"}

| field | values | notes |
|---|---|---|
| `job` | supply / forage / hoard / idle | missing or unknown is an invalid reply |
| `molecule` | resin / spark / brine / glitter / quartz | required for supply and hoard; a species absent in this variant is invalid; a feedstock the named vat does not take is ACCEPTED (the misdrop is the graph test) |
| `reactor` | amber / beryl / cobalt | required for supply, optional for forage; a vat absent in this variant is clamped to the present vat with the lowest charge |
| `say` | string, 80 characters | truncated on rune boundaries; broadcast to all eight seats next shift |
| `notes` | string, 320 characters | truncated on rune boundaries; private to you |

An invalid reply is retried ONCE with a hint; still failing, that seat plays the `courier` order for the shift and the `order` event records `"source":"fallback"`.

## The scripted baselines
`PLAYER_SCRIPTED=courier` builds the lane table (every vat x each of its two feedstocks), sorts it by shortfall and takes one lane per slot. `PLAYER_SCRIPTED=freeloader` camps the spill ring of the highest-charge vat and only works when every vat is cold. Both are legal in every variant by construction.
