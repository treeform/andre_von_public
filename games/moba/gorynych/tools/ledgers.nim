import std/[json, os, strutils, sets]

const
  Root = "games/moba/gorynych"
  Marker = "## Hosted request ledger"
  Trials = [
    ("baseline", "Submitted champion"),
    ("occupancy", "Avoid occupied next cells"),
    ("topstack", "All heroes use top lane"),
    ("haste", "Assassin E while moving in push mode"),
    ("soak", "Strictly closer L1 creep cover"),
    ("recovery", "Recover near the front")
  ]

proc main() =
  ## Refresh the full request ledger without changing the manual backlog.
  let path = Root / "ideas.md"
  var text = readFile(path)
  let start = text.find(Marker)
  if start >= 0:
    text.setLen(start)
  text.add(Marker & "\n\n")
  text.add("b1/a1 are historical nearest-rating cohorts. Only t1 and later " &
    "top-three cohorts are eligible for promotion.\n\n")
  text.add("| Trial | Idea | Policy | XP IDs | Opponents | Verdict |\n")
  text.add("|---|---|---|---|---|---|\n")
  for batch in ["b1", "a1", "t1", "t2", "t3", "t4"]:
    for (trial, idea) in Trials:
      var
        ids, opponents: seq[string]
        seen = initHashSet[string]()
        policy = ""
      for i in 0 .. 2:
        let file = Root / "evidence" /
          ("xp-" & trial & "-" & batch & "-" & $i & ".json")
        if not fileExists(file):
          continue
        let request = parseFile(file)
        ids.add(request["id"].getStr)
        for player in request["episodes"][0]["participants"]:
          let label = player["label"].getStr
          if label.startsWith("gorynych"):
            policy = label
          elif label notin seen:
            seen.incl(label)
            opponents.add(label)
      if ids.len == 0:
        continue
      var verdict = "Historical, not eligible"
      if batch.startsWith("t"):
        verdict = "Hosted evidence pending"
        if trial == "baseline":
          verdict = "Champion reference cohort"
        let scores = Root / "evidence" /
          ("stats-" & trial & "-" & batch & ".json")
        if fileExists(scores):
          let score = parseFile(scores)
          verdict = "p=" & $score{"oneSidedExactP"}.getFloat &
            "; score gate=" & $score{"scoreGate"}.getBool &
            "; unsubmitted"
      text.add("| " & trial & " " & batch & " | " & idea & " | " &
        policy & " | " & ids.join("; ") & " | " &
        opponents.join("; ") & " | " & verdict & " |\n")
  writeFile(path, text)
  echo "Updated ", path

main()
