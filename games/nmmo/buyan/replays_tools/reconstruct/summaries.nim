import std/[json, os, strutils]

type NmmoDiagnosisError = object of CatchableError

proc main() =
  ## Summarize verified replay behavior without deriving scores.
  for path in commandLineParams():
    let data = parseJson(readFile(path))
    if not data{"verified_state_digest"}.getBool() or
      not data{"verified_end_stats"}.getBool():
        raise newException(NmmoDiagnosisError, "Unverified reconstruction.")
    echo path.extractFilename()
    for agent in data["agents"]:
      var
        young = 0
        minimum = 0
        failed = 0
        lifespan = 0
      for death in agent["deaths"]:
        if death["pre_time_alive"].getInt() < 300:
          inc young
        if min(death["pre_comb"].getInt(),
          death["pre_prof"].getInt()) == 1:
            inc minimum
        if death["preceding20"]["run_failures"].getInt() > 0:
          inc failed
        lifespan += death["pre_time_alive"].getInt()
      let deaths = agent["deaths"].len
      echo "pid=", agent["pid"], " ", agent["player_name"].getStr(),
        " deaths=", deaths, " attack=", agent["death_totals"]["attack"],
        " stagnation=", agent["death_totals"]["stagnation"],
        " young=", young, " min1=", minimum,
        " lifespanMean=", (lifespan.float / max(1, deaths).float).
          formatFloat(ffDecimal, 1)
      echo "  runIssued=", agent["run_issued"], " fired=",
        agent["run_fired"], " failed=", agent["run_no_anim"],
        " maxFailStreak=", agent["max_consecutive_failed_moves"],
        " deathsAfterRunFail=", failed
      echo "  noop=", agent["action_histogram"][4], " hpLossTicks=",
        agent["hp_loss_ticks"], " emptyEquipmentTicks=",
        agent["naked_ticks"], " toolTicks=", agent["tool_held_ticks"],
        " firstToolTick=", agent["time_to_first_tool_held"],
        " combatGains=", agent["combat_gains"], " professionGains=",
        agent["profession_gains"]

main()
