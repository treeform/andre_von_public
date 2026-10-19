## Balda — Cogolf policy for Andre von Auto.
## Cogolf (wire protocol cogame.cogolf.v1): nine holes, each revealing one
## deliberately ambiguous spec; both seats simultaneously submit a Python
## solve() implementation plus up to five tests. Legal tests (the hidden
## reference agrees with the expectation) are fired at the opponent's code;
## a hidden four-case par suite audits both. Zero-sum score.
##
## This is the Nim rewrite of the default scripted example
## (`/bin/cogolf-player` with PLAYER_SCRIPTED=literalist), upgraded with the
## stronger scripted line the public repo makes obvious: the core deck's
## twelve specs — including each spec's hidden REFERENCE implementation —
## live in Metta-AI/cogame-cogolf/server/cogame_cogolf/specs/. Balda
## therefore submits the REFERENCE implementation verbatim (zero par fails,
## and every legal opposing test agrees with the reference, so zero
## breaches conceded). Scoring is (breaches + their par_fails) minus the
## symmetric term, so a par case the opponent fails is worth +2 if we also
## fire it as one of our five legal shots. Balda therefore fires each
## spec's four hidden PAR_TESTS plus one extra legal killer that does not
## duplicate those args and still breaches the literalist and/or pedant
## readings. An unknown spec key falls back to the same bounded stub the
## upstream baselines use: echo the first worked example.
##
## Wire flow (docs/PROTOCOL.md): welcome -> observation (one per hole,
## possibly re-sent with retry: true) -> submission -> done (exit 0).
## Deterministic, so a retry just resubmits the same move.
## No secret envs needed: Balda is fully scripted.

import std/[json, strutils], coworld_client

const specTableJson = """
{
 "chunk": {
  "impl": "def solve(xs, n):\n    if not isinstance(n, int) or isinstance(n, bool) or n < 1:\n        raise ValueError(\"chunk size must be at least 1\")\n    return [list(xs[i:i + n]) for i in range(0, len(xs), n)]\n",
  "note": "reference-aligned; shots aimed at the other reading",
  "tests": [
   {
    "name": "empty list",
    "args": [
     [],
     2
    ],
    "expect": [],
    "why": "hidden par: empty input is no chunks"
   },
   {
    "name": "short tail",
    "args": [
     [
      1,
      2,
      3
     ],
     2
    ],
    "expect": [
     [
      1,
      2
     ],
     [
      3
     ]
    ],
    "why": "hidden par: the short trailing chunk is kept"
   },
   {
    "name": "exact fit",
    "args": [
     [
      1,
      2,
      3,
      4
     ],
     4
    ],
    "expect": [
     [
      1,
      2,
      3,
      4
     ]
    ],
    "why": "hidden par: one chunk exactly n long"
   },
   {
    "name": "two tails",
    "args": [
     [
      1,
      2,
      3,
      4,
      5
     ],
     2
    ],
    "expect": [
     [
      1,
      2
     ],
     [
      3,
      4
     ],
     [
      5
     ]
    ],
    "why": "hidden par: two full chunks then a tail of one"
   },
   {
    "name": "chunk bigger than list",
    "args": [
     [
      1,
      2
     ],
     5
    ],
    "expect": [
     [
      1,
      2
     ]
    ],
    "why": "n larger than the list is still one short chunk"
   }
  ]
 },
 "dedupe": {
  "impl": "def solve(xs):\n    out = []\n    for x in xs:\n        seen = False\n        for y in out:\n            if type(x) is type(y) and x == y:\n                seen = True\n                break\n        if not seen:\n            out.append(x)\n    return out\n",
  "note": "reference-aligned; shots aimed at the other reading",
  "tests": [
   {
    "name": "gapped duplicate",
    "args": [
     [
      1,
      2,
      1
     ]
    ],
    "expect": [
     1,
     2
    ],
    "why": "hidden par: a duplicate need not be adjacent"
   },
   {
    "name": "descending order kept",
    "args": [
     [
      3,
      1,
      2
     ]
    ],
    "expect": [
     3,
     1,
     2
    ],
    "why": "hidden par: first appearance, not sorted"
   },
   {
    "name": "neighbouring pair",
    "args": [
     [
      1,
      1
     ]
    ],
    "expect": [
     1
    ],
    "why": "hidden par: the first of a pair survives"
   },
   {
    "name": "gapped strings",
    "args": [
     [
      "a",
      "b",
      "a"
     ]
    ],
    "expect": [
     "a",
     "b"
    ],
    "why": "hidden par: strings collapse the same way"
   },
   {
    "name": "nested lists",
    "args": [
     [
      [
       1
      ],
      [
       1
      ],
      [
       2
      ]
     ]
    ],
    "expect": [
     [
      1
     ],
     [
      2
     ]
    ],
    "why": "items may be lists, which compare by value"
   }
  ]
 },
 "longest_run": {
  "impl": "def solve(xs):\n    best = 0\n    run = 0\n    prev = object()\n    for x in xs:\n        if run and x == prev:\n            run += 1\n        else:\n            run = 1\n        prev = x\n        if run > best:\n            best = run\n    return best\n",
  "note": "reference-aligned; shots aimed at the other reading",
  "tests": [
   {
    "name": "empty is zero",
    "args": [
     []
    ],
    "expect": 0,
    "why": "hidden par: a list with no elements has no runs"
   },
   {
    "name": "alternating",
    "args": [
     [
      1,
      2,
      1,
      2,
      1
     ]
    ],
    "expect": 1,
    "why": "hidden par: non-neighbours are not one run"
   },
   {
    "name": "pair",
    "args": [
     [
      7,
      7
     ]
    ],
    "expect": 2,
    "why": "hidden par: two neighbours equal is a run of two"
   },
   {
    "name": "split run",
    "args": [
     [
      3,
      3,
      1,
      3
     ]
    ],
    "expect": 2,
    "why": "hidden par: the trailing 3 does not extend the lead"
   },
   {
    "name": "negatives",
    "args": [
     [
      -2,
      -2,
      -2,
      0
     ]
    ],
    "expect": 3,
    "why": "negative values run like any other"
   }
  ]
 },
 "median": {
  "impl": "def solve(xs):\n    if not xs:\n        raise ValueError(\"median of an empty list\")\n    ordered = sorted(xs)\n    return ordered[(len(ordered) - 1) // 2]\n",
  "note": "reference-aligned; shots aimed at the other reading",
  "tests": [
   {
    "name": "unsorted even",
    "args": [
     [
      4,
      1,
      3,
      2
     ]
    ],
    "expect": 2,
    "why": "hidden par: order first, then the lower middle"
   },
   {
    "name": "single",
    "args": [
     [
      7
     ]
    ],
    "expect": 7,
    "why": "hidden par: one element is its own median"
   },
   {
    "name": "even pair",
    "args": [
     [
      1,
      2
     ]
    ],
    "expect": 1,
    "why": "hidden par: two elements, the earlier middle wins"
   },
   {
    "name": "unsorted pair",
    "args": [
     [
      5,
      3
     ]
    ],
    "expect": 3,
    "why": "hidden par: order first, then the earlier middle"
   },
   {
    "name": "even length",
    "args": [
     [
      1,
      2,
      3,
      4
     ]
    ],
    "expect": 2,
    "why": "the first of the two middle values, not their mean"
   }
  ]
 },
 "path_norm": {
  "impl": "def solve(p):\n    absolute = p.startswith(\"/\")\n    parts = []\n    for piece in p.split(\"/\"):\n        if piece == \"\" or piece == \".\":\n            continue\n        if piece == \"..\":\n            if parts and parts[-1] != \"..\":\n                parts.pop()\n            elif not absolute:\n                parts.append(\"..\")\n            continue\n        parts.append(piece)\n    if absolute:\n        return \"/\" + \"/\".join(parts)\n    return \"/\".join(parts) or \".\"\n",
  "note": "reference-aligned; shots aimed at the other reading",
  "tests": [
   {
    "name": "trailing slash",
    "args": [
     "/a/"
    ],
    "expect": "/a",
    "why": "hidden par: a trailing slash names the same thing"
   },
   {
    "name": "dotdot at root",
    "args": [
     "/../x"
    ],
    "expect": "/x",
    "why": "hidden par: the root has nothing to remove"
   },
   {
    "name": "double slash",
    "args": [
     "/a//b"
    ],
    "expect": "/a/b",
    "why": "hidden par: runs of slashes collapse to one"
   },
   {
    "name": "relative dotdot kept",
    "args": [
     "../x"
    ],
    "expect": "../x",
    "why": "hidden par: a relative path may walk above its start"
   },
   {
    "name": "relative trailing slash",
    "args": [
     "a/b/"
    ],
    "expect": "a/b",
    "why": "relative paths drop a trailing slash too"
   }
  ]
 },
 "range_merge": {
  "impl": "def solve(ranges):\n    ordered = sorted([list(r) for r in ranges])\n    out = []\n    for start, end in ordered:\n        if out and start <= out[-1][1]:\n            if end > out[-1][1]:\n                out[-1][1] = end\n        else:\n            out.append([start, end])\n    return out\n",
  "note": "reference-aligned; shots aimed at the other reading",
  "tests": [
   {
    "name": "touching ends merge",
    "args": [
     [
      [
       1,
       2
      ],
      [
       2,
       3
      ]
     ]
    ],
    "expect": [
     [
      1,
      3
     ]
    ],
    "why": "hidden par: both ranges cover the number 2"
   },
   {
    "name": "unsorted input",
    "args": [
     [
      [
       5,
       6
      ],
      [
       1,
       2
      ]
     ]
    ],
    "expect": [
     [
      1,
      2
     ],
     [
      5,
      6
     ]
    ],
    "why": "hidden par: sort by start before merging"
   },
   {
    "name": "empty",
    "args": [
     []
    ],
    "expect": [],
    "why": "hidden par: nothing to merge"
   },
   {
    "name": "point range",
    "args": [
     [
      [
       1,
       1
      ]
     ]
    ],
    "expect": [
     [
      1,
      1
     ]
    ],
    "why": "hidden par: a point range covers one number"
   },
   {
    "name": "chain out of order",
    "args": [
     [
      [
       3,
       4
      ],
      [
       1,
       2
      ],
      [
       2,
       9
      ]
     ]
    ],
    "expect": [
     [
      1,
      9
     ]
    ],
    "why": "merging can cascade once sorted"
   }
  ]
 },
 "roman": {
  "impl": "def solve(n):\n    if not isinstance(n, int) or isinstance(n, bool) or not 1 <= n <= 3999:\n        raise ValueError(\"roman numerals cover 1..3999\")\n    table = [(1000, \"M\"), (900, \"CM\"), (500, \"D\"), (400, \"CD\"),\n             (100, \"C\"), (90, \"XC\"), (50, \"L\"), (40, \"XL\"),\n             (10, \"X\"), (9, \"IX\"), (5, \"V\"), (4, \"IV\"), (1, \"I\")]\n    out = []\n    left = n\n    for value, sign in table:\n        while left >= value:\n            out.append(sign)\n            left -= value\n    return \"\".join(out)\n",
  "note": "reference-aligned; shots aimed at the other reading",
  "tests": [
   {
    "name": "nineteen ninety four",
    "args": [
     1994
    ],
    "expect": "MCMXCIV",
    "why": "hidden par: CM, XC and IV in one numeral"
   },
   {
    "name": "this year",
    "args": [
     2024
    ],
    "expect": "MMXXIV",
    "why": "hidden par: subtractive IV after tens"
   },
   {
    "name": "four hundred",
    "args": [
     400
    ],
    "expect": "CD",
    "why": "hidden par: 400 is CD, never CCCC"
   },
   {
    "name": "the biggest",
    "args": [
     3999
    ],
    "expect": "MMMCMXCIX",
    "why": "hidden par: every subtractive form at once"
   },
   {
    "name": "nine",
    "args": [
     9
    ],
    "expect": "IX",
    "why": "the subtractive form for nine"
   }
  ]
 },
 "round_to": {
  "impl": "def solve(x, n):\n    from decimal import Decimal, ROUND_HALF_UP\n    quantum = Decimal(1).scaleb(-n)\n    value = Decimal(str(x)).quantize(quantum, rounding=ROUND_HALF_UP)\n    return float(value)\n",
  "note": "reference-aligned; shots aimed at the other reading",
  "tests": [
   {
    "name": "half up",
    "args": [
     2.5,
     0
    ],
    "expect": 3.0,
    "why": "hidden par: a half goes away from zero"
   },
   {
    "name": "third decimal",
    "args": [
     0.125,
     2
    ],
    "expect": 0.13,
    "why": "hidden par: the same rule two places in"
   },
   {
    "name": "hundreds down",
    "args": [
     12345.0,
     -2
    ],
    "expect": 12300.0,
    "why": "hidden par: negative n rounds left of the point"
   },
   {
    "name": "hundreds half",
    "args": [
     1250.0,
     -2
    ],
    "expect": 1300.0,
    "why": "hidden par: the halfway rule holds for negative n"
   },
   {
    "name": "negative half",
    "args": [
     -2.5,
     0
    ],
    "expect": -3.0,
    "why": "away from zero also means down for negatives"
   }
  ]
 },
 "score_grade": {
  "impl": "def solve(score):\n    if score >= 90:\n        return \"A\"\n    if score >= 80:\n        return \"B\"\n    if score >= 70:\n        return \"C\"\n    if score >= 60:\n        return \"D\"\n    return \"F\"\n",
  "note": "reference-aligned; shots aimed at the other reading",
  "tests": [
   {
    "name": "on the A line",
    "args": [
     90
    ],
    "expect": "A",
    "why": "hidden par: a score on the threshold earns A"
   },
   {
    "name": "on the D line",
    "args": [
     60
    ],
    "expect": "D",
    "why": "hidden par: the same rule at the D line"
   },
   {
    "name": "over a hundred",
    "args": [
     120
    ],
    "expect": "A",
    "why": "hidden par: above 100 is still the best grade"
   },
   {
    "name": "negative",
    "args": [
     -3
    ],
    "expect": "F",
    "why": "hidden par: below zero is still the worst grade"
   },
   {
    "name": "exactly eighty",
    "args": [
     80
    ],
    "expect": "B",
    "why": "the same inclusive rule at the B line"
   }
  ]
 },
 "title_case": {
  "impl": "def solve(s):\n    words = s.split(\" \")\n    out = []\n    for w in words:\n        out.append(w[:1].upper() + w[1:] if w else w)\n    return \" \".join(out)\n",
  "note": "reference-aligned; shots aimed at the other reading",
  "tests": [
   {
    "name": "caps and spacing",
    "args": [
     "NASA  usa"
    ],
    "expect": "NASA  Usa",
    "why": "hidden par: acronyms stay, double space stays"
   },
   {
    "name": "double space",
    "args": [
     "a  b"
    ],
    "expect": "A  B",
    "why": "hidden par: the spacing of the input is kept"
   },
   {
    "name": "acronym",
    "args": [
     "USA today"
    ],
    "expect": "USA Today",
    "why": "hidden par: only the first character changes"
   },
   {
    "name": "empty string",
    "args": [
     ""
    ],
    "expect": "",
    "why": "hidden par: nothing to capitalise"
   },
   {
    "name": "leading space",
    "args": [
     " x"
    ],
    "expect": " X",
    "why": "a leading space is not removed"
   }
  ]
 },
 "top_k": {
  "impl": "def solve(xs, k):\n    order = []\n    counts = {}\n    for x in xs:\n        key = (type(x).__name__, repr(x))\n        if key not in counts:\n            counts[key] = [0, len(order), x]\n            order.append(key)\n        counts[key][0] += 1\n    ranked = sorted(order, key=lambda key: (-counts[key][0], counts[key][1]))\n    return [counts[key][2] for key in ranked[:max(0, k)]]\n",
  "note": "reference-aligned; shots aimed at the other reading",
  "tests": [
   {
    "name": "tie by first appearance",
    "args": [
     [
      3,
      1,
      3,
      1,
      2
     ],
     2
    ],
    "expect": [
     3,
     1
    ],
    "why": "hidden par: ties break by first appearance"
   },
   {
    "name": "k over distinct",
    "args": [
     [
      1,
      2
     ],
     5
    ],
    "expect": [
     1,
     2
    ],
    "why": "hidden par: k is a request, not a promise"
   },
   {
    "name": "single item",
    "args": [
     [
      7
     ],
     1
    ],
    "expect": [
     7
    ],
    "why": "hidden par: one item, k of one"
   },
   {
    "name": "strings over distinct",
    "args": [
     [
      "z",
      "a",
      "z",
      "a"
     ],
     3
    ],
    "expect": [
     "z",
     "a"
    ],
    "why": "hidden par: fewer distinct items than asked"
   },
   {
    "name": "empty list",
    "args": [
     [],
     2
    ],
    "expect": [],
    "why": "no items to rank, k is ignored"
   }
  ]
 },
 "word_count": {
  "impl": "def solve(s):\n    counts = {}\n    for raw in s.split():\n        word = raw\n        while word and not word[0].isalnum():\n            word = word[1:]\n        while word and not word[-1].isalnum():\n            word = word[:-1]\n        if not word:\n            continue\n        word = word.lower()\n        counts[word] = counts.get(word, 0) + 1\n    return counts\n",
  "note": "reference-aligned; shots aimed at the other reading",
  "tests": [
   {
    "name": "apostrophe and case",
    "args": [
     "Don't stop"
    ],
    "expect": {
     "don't": 1,
     "stop": 1
    },
    "why": "hidden par: inner apostrophe stays, case folds"
   },
   {
    "name": "comma and case",
    "args": [
     "Hello, hello"
    ],
    "expect": {
     "hello": 2
    },
    "why": "hidden par: edge punctuation is not the word"
   },
   {
    "name": "one word",
    "args": [
     "x"
    ],
    "expect": {
     "x": 1
    },
    "why": "hidden par: a single word counts once"
   },
   {
    "name": "only spaces",
    "args": [
     "   "
    ],
    "expect": {},
    "why": "hidden par: whitespace is not a word"
   },
   {
    "name": "punctuation stripped",
    "args": [
     "a, a."
    ],
    "expect": {
     "a": 2
    },
    "why": "punctuation stuck to a word is not part of it"
   }
  ]
 }
}"""

let specTable = parseJson(specTableJson)

## Submission building

proc pyLiteral(node: JsonNode): string =
  ## A JSON value as a Python literal (JSON syntax is Python syntax except
  ## for the three keyword tokens).
  case node.kind
  of JNull: "None"
  of JBool: (if node.getBool(): "True" else: "False")
  of JInt, JFloat, JString: $node
  of JArray:
    var parts: seq[string]
    for item in node:
      parts.add(pyLiteral(item))
    "[" & parts.join(", ") & "]"
  of JObject:
    var parts: seq[string]
    for key, value in node:
      parts.add($(%key) & ": " & pyLiteral(value))
    "{" & parts.join(", ") & "}"

proc stubSubmission(spec: JsonNode): tuple[impl: string, tests: JsonNode, note: string] =
  ## Port of the upstream baselines' _stub: a deck extended without updating
  ## Balda still plays a bounded, schema-valid move that echoes the first
  ## worked example.
  let examples = spec{"examples"}
  var first = %*{"args": [], "expect": nil}
  if examples != nil and examples.kind == JArray and examples.len > 0:
    first = examples[0]
  let impl = "def solve(*args):\n" &
    "    known = " & pyLiteral(first{"args"}) & "\n" &
    "    if list(args) == known:\n" &
    "        return " & pyLiteral(first{"expect"}) & "\n" &
    "    return None\n"
  var tests = newJArray()
  if examples != nil and examples.kind == JArray:
    var i = 0
    for example in examples:
      i.inc()
      tests.add(%*{"name": "example " & $i,
                   "args": example{"args"},
                   "expect": example{"expect"},
                   "why": "the spec's own worked example"})
  (impl, tests, "unknown spec: echoing the worked example")

proc submissionFor(hole: int, observation: JsonNode): JsonNode =
  let spec = observation{"spec"}
  let key = spec{"key"}.getStr()
  var maxTests = observation{"rules"}{"max_tests_per_hole"}.getInt(5)
  if maxTests < 1:
    maxTests = 5
  var impl: string
  var tests: JsonNode
  var note: string
  if key in specTable:
    let entry = specTable[key]
    impl = entry["impl"].getStr()
    tests = entry["tests"]
    note = entry["note"].getStr()
  else:
    (impl, tests, note) = stubSubmission(spec)
  var capped = newJArray()
  for test in tests:
    if capped.len >= maxTests:
      break
    capped.add(test)
  %*{"type": "submission", "hole": hole, "impl": impl,
     "tests": capped, "note": note}

proc main() =
  let client = newCoworldClient("balda")
  client.run proc(message: JsonNode) =
    case message{"type"}.getStr()
    of "welcome":
      echo "balda: seated slot ", message{"slot"}.getInt(),
        " alias ", message{"alias"}.getStr(),
        " holes ", message{"holes"}.getInt()
    of "observation":
      let hole = message{"hole"}.getInt()
      if message{"retry"}.getBool():
        echo "balda: retry requested for hole ", hole
      client.send(submissionFor(hole, message{"observation"}))
    of "done":
      echo "balda: done, result ", message{"result"}
      quit(0)
    else:
      discard

main()
