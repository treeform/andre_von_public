Fix haste scope and evidence in experiments/haste only. Preserve every
baseline RetreatMode E flag exactly, including stationary, cooldown and
already-buffed cases. The ONE strategy change is adding E for a moving
assassin in PushMode when E is ready, mana >=100 and not already buffed.
Keep Q/W unchanged. Rename intent counter to pushEIntents. Count triggers
only when a following observation confirms the added push E actually
activated: previous new push-E intent and ready timer, new E cooldown near
100 and movement buff active. Flat per-hero pending state is fine. Q/W can
preempt E, so intent alone is not activation proof. Keep changedActions
as count of actual issued E-flag differences from original. Add fixtures
for Q/W preemption, confirmation, and exact unchanged retreat flags.
No other behavior changes. New constants use PascalCase. Run nim check
and tests using --nimcache:games/moba/gorynych/experiments/haste/nimcache/review.
Update report.md. No commits, builds, uploads or XP. Work efficiently.
