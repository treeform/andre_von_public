## Reproduce two smoke-run deaths where fleeMove returned nothing.
import ../scripted

const
  Cols = 15
  TileBytes = 10
  ScalarsOffset = 1650

proc fromArt(art: seq[string], comb, prof, hp: int): seq[uint8] =
  result = newSeq[uint8](ObservationSize)
  result[ScalarsOffset + 1] = uint8(comb)
  result[ScalarsOffset + 5] = uint8(hp)
  result[ScalarsOffset + 6] = 99
  result[ScalarsOffset + 7] = uint8(prof)
  for r in 0 ..< 11:
    for c in 0 ..< 15:
      let base = (r * Cols + c) * TileBytes
      let ch = art[r][c]
      case ch
      of '#': result[base + 1] = 2
      of 'i': result[base + 2] = 12
      of '0', '1', '2', '3', '4':
        result[base + 4] = 2
        result[base + 6] = uint8(ord(ch) - ord('0'))
        result[base + 7] = 4
      else: discard

proc main() =
  let art1 = @[
    "...............",
    "...............",
    ".........4.....",
    "...............",
    "........i....i.",
    "....4..@##i....",
    "......i######..",
    ".....i########i",
    "......#########",
    "......#########",
    "...i...#######i"]
  var m = newMind(1, 0)
  var obs = fromArt(art1, 1, 1, 45)
  echo "case1 action ", m.decide(obs, 0), " flees ", m.flees
  let art2 = @[
    "...............",
    "...............",
    ".............i.",
    ".....i......###",
    ".......0.0.####",
    ".......@..#####",
    "..........#####",
    ".........######",
    "#.......i######",
    "#........######",
    "#........######"]
  m = newMind(1, 0)
  obs = fromArt(art2, 1, 1, 16)
  obs[ScalarsOffset + 12] = 4
  echo "case2 action ", m.decide(obs, 0), " flees ", m.flees, " fights ", m.fights

main()
