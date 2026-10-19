# Frozen first-round analysis plan

Written before any new XP outcome was observed, 2026-09-12.

- Five independent candidates versus submitted gorynych:v1.
- Current field: daveey-scripted:v39, co-gas-moba-topstack-richard:v7,
  co-gas-moba-topstack-relhalpha:v3. User replaced the nearest-rating rule.
- Start fresh baseline and candidate t1 cohorts on this field. Never use
  nearest-rating episodes or matches between our versions for promotion.
- Separate requests per opponent. Both seats rotate. Team variant,
  canonical 0.1.3 game, unchanged default settings and random game seeds.
- First look: 10 episodes per opponent, 30 total per policy.
- Additional planned looks: 20, 40 and 80 episodes per opponent.
- Require at least ten completed candidate episodes with strategy proof.
  Prefer proof in every candidate episode. Missing proof blocks a keep.
- Stratified exact one-sided randomization test over hosted scores
  (loss 0, draw 0.5, win 1), with opponent and side strata when available.
- Original alpha was 0.0025; the identity audit tightens it to 0.002 below.
- Positive effect and p <= 0.002 required, alongside the dashboard
  request results and visible uncertainty. No judgment from means alone.
- If cohorts differ by opponent/version/config/side, repair the field
  before inference. Never compare different fields.
- Any invalid or untriggered episode is reported before scoring.
  Do not select observations using wins/losses. If trigger selection
  cannot yield a valid matched comparison, reject rather than keep.
- At the final look, inconclusive means discard. No league submission
  until a candidate passes all gates. After promotion, freeze a new field
  and baseline before any follow-up strategy change.
# Identity correction, 2026-09-12

Original candidate uploads were attributed to Andre von Houck. They cannot
authorize submission for Andre von Auto. Repeat the same unchanged images
under gorynych:vN with verified Andre von Auto ownership. The original
champion baseline already belongs to Andre von Auto and remains valid.

Tighten per-look alpha to 0.002 = 0.05 / (5 ideas * 5 maximum looks),
covering the original audit look plus four corrected-cohort looks. This
only tightens the original gate. The original occupancy result had p=0.5.
Do not combine wrong-player candidate episodes into corrected cohorts.

# Theory batch, 2026-09-12

All first five candidates are now discarded. Recovery reached the second
look; the other four stopped at the first. No candidate was kept.

Before new outcomes, register five independent theory lanes: routes,
sieging, sustain, casting and targets. Each uses original champion v1 and
the same current three opponent versions. First look uses 10 episodes
per opponent. Further looks, if needed, use cumulative 20, 40 and 80 per
opponent. No selection using local scores or untriggered episodes.

Tighten the gate for all future looks to p <= 0.001. The seven saved
earlier statistical looks used at most 7 * .002 = .014 of the .05 error
budget. This new batch uses at most 5 * 4 * .001 = .020 more. Even counting
an extra audit look for each old candidate keeps the total below .05.
Refuted or inconclusive lanes may be discarded early. Repeatedly peeking
at scores does not permit an unscheduled promotion.
