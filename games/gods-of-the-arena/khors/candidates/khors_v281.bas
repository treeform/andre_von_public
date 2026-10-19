' @gota-structures
' Khors v281 - macromackie clone: decision trees learned from 120 replays
' The 120 replays hold 781,526 macromackie order ticks from the 2026.10.8.1
' league build (30 each against BeWellBot, preston, khors v270 and itself).
' One CART tree per choice was fitted on them: the depth-9 primary tree
' picks the order class (77.3% on held-out games), two pointwise trees pick
' the hero and creep targets, four cast trees decide whether Q, W, E or R
' goes out, four aim trees pick what each spell hits, and a buy tree picks
' each purchase. This program computes every tree feature the way the clone
' feature dictionary defines it, walks the trees, and turns each class into
' a concrete order. The order points (lane corners, the map center, enemy
' guards, creep approach spots and fallen tower spots) come from the walk
' and attack-move targets measured in the same replays. The draft, ability
' levels, potions and buyback stay hand-written.

dim feat(139)
dim nodeFeature(767)
dim nodeValue(767)
dim nodeRight(767)
dim treeRoots(11)
dim castChance(3)
dim castTried(3)
dim unitIds(127)
dim unitKinds(127)
dim unitXs(127)
dim unitYs(127)
dim unitHps(127)
dim unitMaxHps(127)
dim unitTargets(127)
dim unitDists(127)
dim towerXs(31)
dim towerYs(31)
dim towerMaxHps(31)
dim towerStates(31)
dim towerSeen(31)
dim towerTargets(31)
dim towerLayers(31)

' The legacy whole-tile index of a tile-center coordinate: floor(p + .5), with
' the Blue observer taking the lower cell on an exact tile edge.
sub mapTile(value)
  tileValue = floor(value + .5)
  if self.team = 1 and tileValue = value + .5 then
    tileValue = tileValue - 1
  end if
end sub

sub chooseHero()
  if draft.turnId <> self.id then
    exit sub
  end if
  bestClass = -1
  bestScore = -10000
  for candidate = 0 to 9
    if heroChoices(candidate).available then
      ' Demon Hunter > Lich > Arcanist > Berserker > Druid > Warlock >
      ' Crossbowman > Vanguard > Death Knight > Ranger, 100 apart so the
      ' same-role penalty never reorders them.
      score = 100
      if candidate = DemonHunter then
        score = 1000
      elseif candidate = Lich then
        score = 900
      elseif candidate = Arcanist then
        score = 800
      elseif candidate = Berserker then
        score = 700
      elseif candidate = DruidWarden then
        score = 600
      elseif candidate = Warlock then
        score = 500
      elseif candidate = Crossbowman then
        ' The October 5 rebalance made Crossbowman the strongest pick; 1200
        ' keeps it first even after four same-role teammates (-100).
        score = 1200
      elseif candidate = 0 then
        score = 300
      elseif candidate = DeathKnight then
        score = 200
      end if
      for player = 0 to draft.playerCount - 1
        if players(player).team = self.team then
          picked = players(player).class
          if picked >= 0 then
            if heroChoices(picked).role = heroChoices(candidate).role then
              score = score - 25
            end if
          end if
        end if
      next player
      if score > bestScore then
        bestScore = score
        bestClass = candidate
      end if
    end if
  next candidate
  if bestClass >= 0 then
    accepted = draftHero(bestClass)
  end if
end sub

' One preorder tree node. An internal node packs its feature slot and right
' child as feature + 256 * right and keeps its threshold; a leaf (code -1)
' keeps its value.
sub node(code, value)
  nodeFeature(nodeCount) = -1
  nodeValue(nodeCount) = value
  if code >= 0 then
    nodeFeature(nodeCount) = code mod 256
    nodeRight(nodeCount) = code \ 256
  end if
  nodeCount = nodeCount + 1
end sub

' Walks one tree from its root: left when the feature is at most the
' threshold, right otherwise.
sub evalTree(root)
  at = root
  while nodeFeature(at) >= 0
    if feat(nodeFeature(at)) <= nodeValue(at) then
      at = at + 1
    else
      at = nodeRight(at)
    end if
  wend
  treeValue = nodeValue(at)
end sub

' The trees below are generated from model.md by gen_trees.nim. Feature
' slots 0-98 follow the clone feature list, 101-115 the target features and
' 116-135 the buy features. Primary leaves hold label + 32 * (runner-up + 1),
' target leaves the chance of being chosen, cast leaves the chance of a
' cast, aim leaves 1 hero, 2 creep, 3 building, 4 neutral or 6 nothing, and
' buy leaves the item id (0 stops).
sub loadTrees()
  nodeCount = 0
  ' The primary order tree starts at node 0.
  treeRoots(0) = 0
  node(86539,29):node(30513,1):node(8725,1):node(5937,-1.496):node(3138,6.021)
  node(1856,225):node(-1,229):node(2881,0.843):node(2641,122.977):node(-1,229)
  node(-1,198):node(-1,550):node(4170,0.222):node(3840,1.367):node(-1,4)
  node(-1,6):node(5654,1):node(5376,1.367):node(5175,2.333):node(-1,224)
  node(-1,166):node(-1,38):node(-1,102):node(6463,6.265):node(-1,101)
  node(7432,3):node(7242,1.222):node(-1,100):node(-1,166):node(7959,3)
  node(-1,101):node(8503,1.556):node(-1,66):node(-1,224):node(17975,1)
  node(10519,0):node(9728,11.632):node(-1,194):node(10332,105):node(-1,2)
  node(-1,97):node(14103,3):node(12822,42):node(12032,1.409):node(11825,0.565)
  node(-1,0):node(-1,41):node(12637,0):node(-1,361):node(-1,547):node(13847,1)
  node(13666,15.963):node(-1,70):node(-1,225):node(-1,34):node(16128,11.632)
  node(15423,6.945):node(15135,0):node(-1,354):node(-1,105):node(15953,123.680)
  node(-1,194):node(-1,299):node(17236,0.831):node(16900,497):node(-1,113)
  node(-1,578):node(17757,0):node(-1,70):node(-1,547):node(24087,1)
  node(20791,2):node(19990,42):node(19775,18.922):node(19506,7.663):node(-1,194)
  node(-1,581):node(-1,162):node(20529,-1.763):node(-1,34):node(-1,96)
  node(22325,0):node(22016,7.801):node(21760,1.276):node(-1,2):node(-1,36)
  node(-1,66):node(23359,18.922):node(23116,17.830):node(-1,100):node(-1,581)
  node(23891,11.498):node(-1,226):node(-1,166):node(27155,7.207):node(25887,0)
  node(25143,6.500):node(-1,34):node(25676,5.101):node(-1,228):node(-1,166)
  node(26954,2.222):node(26678,3):node(-1,322):node(-1,41):node(-1,41)
  node(28735,17.825):node(28509,0):node(28160,5.838):node(-1,209):node(-1,101)
  node(-1,547):node(29772,14.938):node(29495,2.750):node(-1,322):node(-1,228)
  node(30263,4):node(-1,96):node(-1,38):node(56080,0):node(42007,3)
  node(36117,36):node(33343,6.392):node(32577,0.866):node(32259,0):node(-1,16)
  node(-1,101):node(33024,1.626):node(-1,4):node(-1,549):node(34380,7.409)
  node(34048,6.438):node(-1,260):node(-1,167):node(35349,1):node(35122,13.593)
  node(-1,192):node(-1,39):node(35843,0):node(-1,16):node(-1,99):node(38678,6)
  node(38472,0):node(37695,10.586):node(37376,1.480):node(-1,3):node(-1,130)
  node(38167,2):node(-1,417):node(-1,35):node(-1,546):node(40274,0)
  node(39428,495):node(-1,481):node(39982,0):node(-1,497):node(-1,14)
  node(41231,0):node(40963,0):node(-1,16):node(-1,101):node(41733,0.898)
  node(-1,3):node(-1,64):node(49228,17.830):node(45843,6.171):node(44575,0)
  node(43811,0):node(43583,17.825):node(-1,165):node(-1,36):node(44305,2)
  node(-1,170):node(-1,580):node(45073,2):node(-1,169):node(45651,82.660)
  node(-1,580):node(-1,177):node(47409,4.420):node(47167,18.922):node(46852,158)
  node(-1,177):node(-1,196):node(-1,36):node(48476,388):node(48204,5.808)
  node(-1,548):node(-1,177):node(48984,0.431):node(-1,177):node(-1,36)
  node(52308,0.459):node(50446,0):node(50176,11.632):node(-1,33):node(-1,113)
  node(51537,7.004):node(51222,6):node(-1,588):node(-1,497):node(51991,16)
  node(-1,78):node(-1,35):node(54335,17.825):node(53523,6.942):node(53279,0)
  node(-1,354):node(-1,105):node(54019,0):node(-1,16):node(-1,581)
  node(55296,11.703):node(55045,0.239):node(-1,546):node(-1,64)
  node(55891,29.708):node(-1,257):node(-1,49):node(72012,18.394)
  node(64050,15.895):node(60178,0):node(58943,9.101):node(58135,15)
  node(57949,0):node(-1,165):node(-1,195):node(58716,143):node(-1,581)
  node(-1,177):node(59470,2):node(-1,36):node(59926,6):node(-1,160):node(-1,162)
  node(62227,7.012):node(61471,0):node(61219,0):node(-1,160):node(-1,170)
  node(62030,1):node(-1,41):node(-1,322):node(63308,6.839):node(63028,0)
  node(-1,580):node(-1,162):node(63807,17.825):node(-1,165):node(-1,160)
  node(68172,6.839):node(66367,14.611):node(65557,1):node(65345,0.866)
  node(-1,101):node(-1,196):node(66067,7.207):node(-1,361):node(-1,581)
  node(67404,5.607):node(67091,8.370):node(-1,330):node(-1,36):node(67917,0)
  node(-1,580):node(-1,177):node(70207,17.825):node(69395,6.852):node(69151,0)
  node(-1,106):node(-1,137):node(69909,2):node(-1,101):node(-1,209)
  node(71251,32.724):node(70995,22.435):node(-1,162):node(-1,580)
  node(71685,0.325):node(-1,162):node(-1,49):node(79188,0.461):node(75287,1)
  node(74007,0):node(73750,42):node(73535,18.922):node(-1,209):node(-1,327)
  node(-1,256):node(75030,42):node(74815,18.922):node(-1,581):node(-1,71)
  node(-1,257):node(77335,2):node(76566,42):node(76302,0):node(-1,579)
  node(-1,492):node(77140,0.054):node(-1,113):node(-1,578):node(78358,42)
  node(78101,1):node(-1,199):node(-1,81):node(78863,0):node(-1,337):node(-1,579)
  node(82751,18.922):node(81426,0):node(80640,6.684):node(80452,0):node(-1,209)
  node(-1,194):node(81245,0):node(-1,101):node(-1,195):node(82451,7.082)
  node(82207,0):node(-1,106):node(-1,137):node(-1,578):node(84736,11.703)
  node(83973,0.251):node(83734,42):node(-1,99):node(-1,130):node(84502,1)
  node(-1,39):node(-1,96):node(85843,30.467):node(85525,24):node(-1,327)
  node(-1,225):node(86295,0):node(-1,128):node(-1,113):node(92689,0)
  node(89932,9.555):node(87615,7.254):node(-1,165):node(88140,5.674):node(-1,36)
  node(88626,13.968):node(-1,36):node(89616,0):node(89417,2):node(-1,177)
  node(-1,580):node(-1,177):node(92477,0):node(91220,0.476):node(90961,45.081)
  node(-1,64):node(-1,257):node(92160,11.632):node(91953,1):node(-1,34)
  node(-1,96):node(-1,257):node(-1,101):node(-1,579)
  ' The hero target tree starts at node 363.
  treeRoots(1) = 363
  node(96616,1):node(94313,1):node(94061,0):node(-1,0.992):node(-1,0.000)
  node(95342,0):node(95079,6.002):node(-1,0.826):node(-1,0.335)
  node(95847,6.745):node(-1,0.968):node(96358,0.307):node(-1,0.388)
  node(-1,0.843):node(98670,0):node(98409,1):node(98156,4):node(97894,0.686)
  node(-1,0.604):node(-1,0.368):node(-1,0.204):node(-1,0.045):node(99177,1)
  node(-1,0.813):node(100204,4):node(99942,0.987):node(-1,0.491):node(-1,0.678)
  node(-1,0.369)
  ' The creep target tree starts at node 392.
  treeRoots(2) = 392
  node(103017,1):node(102765,0):node(101491,1):node(-1,1.000):node(101992,1)
  node(-1,0.802):node(102511,3):node(-1,0.670):node(-1,0.214):node(-1,0.000)
  node(105065,2):node(104293,24):node(104039,6.599):node(-1,0.609)
  node(-1,0.063):node(104807,9.993):node(-1,0.164):node(-1,0.963)
  node(106599,10.153):node(106341,21):node(106087,4.178):node(-1,0.812)
  node(-1,0.292):node(-1,0.034):node(-1,1.000)
  ' The Q cast tree starts at node 417.
  treeRoots(3) = 417
  node(109331,7.511):node(109067,28):node(107839,6.519):node(-1,0.890)
  node(108868,0):node(108582,0):node(-1,0.768):node(-1,0.422):node(-1,0.242)
  node(-1,0.000):node(110347,12):node(110167,0.606):node(-1,0.923)
  node(-1,0.142):node(111436,7.048):node(111104,11.561):node(-1,0.686)
  node(-1,0.141):node(-1,0.013)
  ' The W cast tree starts at node 436.
  treeRoots(4) = 436
  node(117267,7.082):node(117003,29):node(114767,0):node(114460,0)
  node(113727,6.519):node(113501,0):node(-1,0.942):node(-1,0.132)
  node(114226,6.057):node(-1,0.166):node(-1,0.690):node(-1,0.018)
  node(115793,58.197):node(115532,20.821):node(-1,0.344):node(-1,0.875)
  node(116300,6.403):node(-1,0.768):node(116744,6):node(-1,0.019):node(-1,0.712)
  node(-1,0.000):node(121932,6.839):node(118037,4):node(-1,0.051)
  node(120128,197):node(119329,1):node(119114,0.800):node(-1,0.593)
  node(-1,0.107):node(119884,6.556):node(-1,0.722):node(-1,0.329)
  node(121137,11.370):node(120906,0.690):node(-1,0.536):node(-1,0.185)
  node(121663,6.945):node(-1,0.583):node(-1,0.114):node(123967,6.945)
  node(123732,0.915):node(122902,5):node(-1,0.083):node(123411,9.604)
  node(-1,0.148):node(-1,0.528):node(-1,0.047):node(124492,7.144):node(-1,0.099)
  node(125459,7.207):node(125195,12):node(-1,0.564):node(-1,0.064)
  node(-1,0.002)
  ' The E cast tree starts at node 491.
  treeRoots(5) = 491
  node(132896,11):node(130636,5.929):node(128799,0):node(128063,9.719)
  node(127243,12):node(-1,0.626):node(127744,6.288):node(-1,0.189)
  node(-1,0.554):node(128533,2):node(-1,0.347):node(-1,0.831):node(129354,0.800)
  node(-1,0.014):node(130337,1):node(130111,8.990):node(-1,0.202):node(-1,0.684)
  node(-1,0.002):node(132674,6.342):node(132383,0):node(131605,1):node(-1,0.014)
  node(132115,6.328):node(-1,0.826):node(-1,0.425):node(-1,0.000):node(-1,0.002)
  node(133899,12):node(133651,7.082):node(-1,0.820):node(-1,0.375)
  node(136008,0):node(134675,5.379):node(-1,0.777):node(135743,6.519)
  node(135445,1):node(-1,0.024):node(-1,0.558):node(-1,0.077):node(136469,1)
  node(-1,0.146):node(137036,5.674):node(-1,0.730):node(137521,1.083)
  node(-1,0.703):node(-1,0.440)
  ' The R cast tree starts at node 538.
  treeRoots(6) = 538
  node(140819,8.089):node(140555,14):node(139283,6.596):node(139044,192)
  node(-1,0.147):node(-1,0.920):node(140305,1):node(140054,6):node(-1,0.314)
  node(-1,0.648):node(-1,0.777):node(-1,0.023):node(143948,7.816)
  node(142156,6.337):node(141860,96):node(-1,0.080):node(-1,0.632)
  node(143616,11.632):node(143434,0.690):node(143167,13.762):node(-1,0.324)
  node(-1,0.640):node(-1,0.304):node(-1,0.109):node(145986,7.843):node(144662,5)
  node(-1,0.071):node(145215,6.054):node(-1,0.226):node(145686,6):node(-1,0.676)
  node(-1,0.401):node(-1,0.006)
  ' The Q aim tree starts at node 571.
  treeRoots(7) = 571
  node(147263,7.600):node(147028,0.936):node(-1,1):node(-1,3):node(147788,7.665)
  node(-1,2):node(148305,111.784):node(-1,4):node(-1,3)
  ' The W aim tree starts at node 580.
  treeRoots(8) = 580
  node(150591,7.254):node(149331,8.059):node(-1,3):node(150291,4.619)
  node(150090,0.674):node(-1,2):node(-1,1):node(-1,1):node(152140,7.273)
  node(151857,-2.428):node(151573,13):node(-1,3):node(-1,2):node(-1,2)
  node(153137,11.027):node(152919,4.158):node(-1,3):node(-1,4):node(-1,4)
  ' The E aim tree starts at node 599.
  treeRoots(9) = 599
  node(156479,6.945):node(155724,6.184):node(154929,5.305):node(154705,111.470)
  node(-1,2):node(-1,1):node(155411,6.456):node(-1,1):node(-1,2)
  node(156243,6.935):node(-1,3):node(-1,1):node(157513,0):node(157265,97.054)
  node(-1,4):node(-1,3):node(-1,2)
  ' The R aim tree starts at node 616.
  treeRoots(10) = 616
  node(159817,0):node(159039,8.218):node(158737,2):node(-1,1):node(-1,3)
  node(159537,10.627):node(-1,3):node(-1,4):node(161343,7.876)
  node(160577,0.898):node(-1,1):node(161046,16):node(-1,2):node(-1,1)
  node(161841,-2.085):node(-1,3):node(-1,2)
  ' The item buy tree starts at node 633.
  treeRoots(11) = 633
  node(170887,0):node(167558,2):node(166274,4):node(164468,11.644)
  node(164221,3):node(163958,95):node(-1,1):node(-1,8):node(-1,1):node(165510,0)
  node(165250,0):node(-1,2):node(-1,1):node(166006,95):node(-1,1):node(-1,21)
  node(167300,0):node(167030,95):node(-1,22):node(-1,21):node(-1,22)
  node(168052,0.001):node(-1,11):node(169085,1):node(168822,155):node(-1,1)
  node(-1,16):node(170109,2):node(169846,175):node(-1,1):node(-1,19)
  node(170614,65):node(-1,1):node(-1,8):node(175490,0):node(173174,150)
  node(171894,25):node(-1,0):node(172406,95):node(-1,1):node(172934,2)
  node(-1,1):node(-1,8):node(174205,2):node(173942,180):node(-1,1):node(-1,19)
  node(174717,3):node(-1,8):node(175237,0):node(-1,1):node(-1,0):node(177542,0)
  node(176244,11.708):node(-1,0):node(177282,4):node(177031,1):node(-1,1)
  node(-1,0):node(-1,0):node(179062,95):node(178294,40):node(-1,0)
  node(178813,2):node(-1,0):node(-1,22):node(180084,11.644):node(179847,4)
  node(-1,21):node(-1,0):node(-1,0)
end sub

' Priority R > W > E > Q gives macromackie's exact order: W, E, W, E, W, R,
' W, E, E, Q, Q, R.
sub learnAbilities()
  for upgrade = 1 to 4
    if self.abilityPoints = 0 then
      exit sub
    end if
    upgradeSlot = -1
    if abilities(0).canLevel then
      upgradeSlot = 0
    end if
    if abilities(2).canLevel then
      upgradeSlot = 2
    end if
    if abilities(1).canLevel then
      upgradeSlot = 1
    end if
    if abilities(3).canLevel then
      upgradeSlot = 3
    end if
    if upgradeSlot < 0 then
      exit sub
    end if
    accepted = levelAbility(upgradeSlot)
    noteOrder(15)
  next upgrade
end sub

' Order memory as the featurizer keeps it: the tick of the last order and
' the tick's primary label, ranked buyback, portal, movement or attack (the
' last one wins), cast (the first one wins), item use, buy, level.
sub noteOrder(label)
  rank = 6
  if label = 16 then
    rank = 0
  elseif label = 14 then
    rank = 1
  elseif label <= 7 or label = 17 then
    rank = 2
  elseif label <= 11 then
    rank = 3
  elseif label = 13 then
    rank = 4
  elseif label = 12 then
    rank = 5
  end if
  if lastOrderTick <> match.tick then
    orderRank = 99
  end if
  if rank < orderRank or (rank = 2 and orderRank = 2) then
    orderRank = rank
    prevLabel = label
  end if
  lastOrderTick = match.tick
end sub

' Tower reach and shot by tier, read from max health: outer 1900 (9 tiles,
' 36), inner 2600 (9.5 tiles, 48), gate and god guards 3900 (10 tiles, 60).
sub towerStats(hitPoints)
  towerRange = 9
  towerShot = 36
  if hitPoints >= 3000 then
    towerRange = 10
    towerShot = 60
  elseif hitPoints >= 2200 then
    towerRange = 9.5
    towerShot = 48
  end if
end sub

' Lists the nav layers whose read of the tower's center tile is blocked. The
' host's walkability read honors only towers our team still believes alive,
' so a blocked layer that later reads open proves our vision saw it fall:
' the engine's knownAlive flag behind match.enemyTowers.
sub towerMask(slot)
  mapTile(towerXs(slot))
  tileX = tileValue
  mapTile(towerYs(slot))
  tileY = tileValue
  mask = 0
  bit = 1
  for navLayer = 0 to map.layers - 1
    if terrainWalkableAt(tileX, tileY, navLayer) = 0 then
      mask = mask + bit
    end if
    bit = bit * 2
  next navLayer
  towerLayers(slot) = mask
end sub

' One pass over the visible objects fills the unit table: 1 enemy hero, 2
' enemy lane creep, 3 allied hero, 4 own lane creep, 5 neutral, 6 enemy
' tower, 7 own tower, 8 enemy barracks, 9 enemy god. Heroes, creeps and
' neutrals count while alive, buildings while standing. It also reads the
' current target and remembers enemy towers by id.
sub observe()
  unitCount = 0
  enemyTeam = 1 - self.team
  targetKind = 0
  targetHpFrac = 0
  targetDistance = 99
  if startTarget <> 0 then
    targetKind = 5
  end if
  godExposed = -1
  ownTowerSeen = 0
  lastIndex = match.objectCount - 1
  if lastIndex > 399 then
    lastIndex = 399
  end if
  for index = 0 to lastIndex
    id = objects(index).id
    kind = objects(index).kind
    team = objects(index).team
    hp = objects(index).hp
    px = objects(index).position.x
    py = objects(index).position.y
    if startTarget <> 0 and id = startTarget then
      dx = px - spotX
      dy = py - spotY
      targetDistance = sqrt(dx * dx + dy * dy)
      if objects(index).maxHp > 0 then
        targetHpFrac = hp / objects(index).maxHp
      end if
      targetX = px
      targetY = py
      if kind = 3 and team = enemyTeam then
        targetKind = 1
      elseif kind = 2 and team = enemyTeam then
        targetKind = 2
      elseif kind = 4 then
        targetKind = 3
      elseif kind = 6 then
        targetKind = 4
      end if
    end if
    code = 0
    if kind = 2 or kind = 3 or kind = 6 then
      if objects(index).alive <> 0 then
        if kind = 6 then
          code = 5
        elseif team = self.team then
          if kind = 3 then
            code = 4
          elseif id <> self.id then
            code = 3
          end if
        elseif team = enemyTeam then
          code = 1
          if kind = 3 then
            code = 2
          end if
        end if
      end if
    elseif hp > 0 then
      if kind = 4 then
        if team = self.team then
          code = 7
          ownTowerSeen = 1
          if towersKnown = 0 and id >= 10 and id <= 31 then
            ' Tower ids are 10 + lane * 6 + team * 3 + tier, guards 28-31.
            ' Lane L of one team mirrors lane 2 - L of the other through
            ' the map center, tier for tier.
            if id >= 28 then
              mirror = id + 2 - 4 * self.team
            else
              laneIndex = (id - 10) \ 6
              rest = (id - 10) mod 6
              mirror = 10 + (2 - laneIndex) * 6 + (1 - (rest \ 3)) * 3 + (rest mod 3)
            end if
            towerXs(mirror) = map.width - 1 - px
            towerYs(mirror) = map.height - 1 - py
            towerMaxHps(mirror) = objects(index).maxHp
            towerStates(mirror) = 1
          end if
        elseif team = enemyTeam and id >= 10 and id <= 31 then
          code = 6
          if id >= 28 then
            ' The two guards may sit in either mirrored spot: swap the
            ' remembered spots when this guard turns up in its sibling's.
            sibling = id + 1 - 2 * (id mod 2)
            sx = towerXs(sibling) - px
            sy = towerYs(sibling) - py
            if sx * sx + sy * sy < 2.25 then
              towerXs(sibling) = towerXs(id)
              towerYs(sibling) = towerYs(id)
              towerMask(sibling)
            end if
          end if
          towerXs(id) = px
          towerYs(id) = py
          towerMaxHps(id) = objects(index).maxHp
          towerStates(id) = 1
          towerSeen(id) = match.tick
          towerTargets(id) = objects(index).targetId
          towerMask(id)
        end if
      elseif kind = 5 and team = enemyTeam then
        code = 8
      elseif kind = 1 and team = enemyTeam then
        code = 9
        godExposed = objects(index).alive
      end if
    end if
    if code > 0 and unitCount < 128 then
      unitIds(unitCount) = id
      unitKinds(unitCount) = code
      unitXs(unitCount) = px
      unitYs(unitCount) = py
      unitHps(unitCount) = hp
      unitMaxHps(unitCount) = objects(index).maxHp
      unitTargets(unitCount) = objects(index).targetId
      unitCount = unitCount + 1
    end if
  next index
  if towersKnown = 0 and ownTowerSeen = 1 then
    towersKnown = 1
    for slot = 10 to 31
      if towerStates(slot) = 1 then
        towerMask(slot)
      end if
    next slot
  end if
end sub

' The danger tower is the known-alive enemy tower with the smallest margin
' (distance minus reach): features twMargin, twDist, twVisible, twTarget,
' twOwnCreeps and twCreepShots.
sub judgeTowers()
  dangerId = 0
  feat(49) = 9999
  for slot = 10 to 31
    if towerStates(slot) = 1 and towerSeen(slot) <> match.tick then
      if towerLayers(slot) > 0 then
        mapTile(towerXs(slot))
        tileX = tileValue
        mapTile(towerYs(slot))
        tileY = tileValue
        bit = 1
        for navLayer = 0 to map.layers - 1
          if (towerLayers(slot) \ bit) mod 2 = 1 then
            if terrainWalkableAt(tileX, tileY, navLayer) <> 0 then
              towerStates(slot) = 0
            end if
          end if
          bit = bit * 2
        next navLayer
      else
        ' Without a blocked layer to read, retire a tower whose spot lies
        ' well inside our own sight while it stays unseen.
        dx = towerXs(slot) - spotX
        dy = towerYs(slot) - spotY
        if dx * dx + dy * dy < 81 then
          towerStates(slot) = 0
        end if
      end if
    end if
    if towerStates(slot) = 1 then
      dx = towerXs(slot) - spotX
      dy = towerYs(slot) - spotY
      distance = sqrt(dx * dx + dy * dy)
      towerStats(towerMaxHps(slot))
      margin = distance - towerRange
      if margin < feat(49) then
        feat(49) = margin
        feat(50) = distance
        dangerId = slot
        dangerX = towerXs(slot)
        dangerY = towerYs(slot)
        dangerRange = towerRange
        dangerShot = towerShot
      end if
    end if
  next slot
  if dangerId = 0 then
    feat(49) = 99
    feat(50) = 99
    feat(52) = -1
    feat(53) = -1
    feat(54) = -1
    feat(55) = -1
    exit sub
  end if
  feat(52) = 0
  feat(53) = -1
  if towerSeen(dangerId) = match.tick then
    feat(52) = 1
    shown = towerTargets(dangerId)
    if shown = 0 then
      feat(53) = 0
    elseif shown = self.id then
      feat(53) = 3
    elseif shown >= 1000 then
      feat(53) = 1
    elseif shown >= 100 and shown < 110 then
      feat(53) = 2
    else
      feat(53) = 4
    end if
  end if
  creepsIn = 0
  creepHpIn = 0
  reach = dangerRange * dangerRange
  for u = 0 to unitCount - 1
    if unitKinds(u) = 4 then
      dx = unitXs(u) - dangerX
      dy = unitYs(u) - dangerY
      if dx * dx + dy * dy <= reach then
        creepsIn = creepsIn + 1
        creepHpIn = creepHpIn + unitHps(u)
      end if
    end if
  next u
  feat(54) = creepsIn
  feat(55) = creepHpIn / dangerShot
end sub

' Inventory counts summed over every slot, the gear chain held, and the
' slots of each consumable.
sub scanItems()
  healSlot = -1
  healCount = 0
  elixirSlot = -1
  elixirCount = 0
  manaSlot = -1
  manaCount = 0
  portalSlot = -1
  portalCount = 0
  freeSlots = 0
  gearStage = 0
  hasDagger = 0
  hasArmor = 0
  hasBow = 0
  hasBoots = 0
  for itemSlot = 0 to 5
    item = items(itemSlot).id
    if item = 0 then
      freeSlots = freeSlots + 1
    elseif item = 11 then
      hasDagger = 1
      gearStage = gearStage + 1
    elseif item = 16 then
      hasArmor = 1
      gearStage = gearStage + 1
    elseif item = 19 then
      hasBow = 1
      gearStage = gearStage + 1
    elseif item = 8 then
      hasBoots = 1
      gearStage = gearStage + 1
    elseif item = 1 then
      healSlot = itemSlot
      healCount = healCount + items(itemSlot).count
    elseif item = 2 then
      elixirSlot = itemSlot
      elixirCount = elixirCount + items(itemSlot).count
    elseif item = 22 then
      manaSlot = itemSlot
      manaCount = manaCount + items(itemSlot).count
    elseif item = 21 then
      portalSlot = itemSlot
      portalCount = portalCount + items(itemSlot).count
    end if
  next itemSlot
end sub

' Clockwork Charge (ability 27) lands at its impact tick in a capsule 8 tiles
' long and 1.25 tiles half-wide from the caster along its facing: rThreat.
' The dodge is a 1.5 tile sidestep to the side we already stand on.
sub readSpells()
  rThreat = 0
  lastSpell = match.spellCount - 1
  if lastSpell > 31 then
    lastSpell = 31
  end if
  for warning = 0 to lastSpell
    if spells(warning).hostile <> 0 and spells(warning).abilityId = 27 then
      impact = spells(warning).impactTick
      if impact > match.tick and rThreat = 0 then
        caster = spells(warning).casterId
        found = 0
        lastSeek = match.objectCount - 1
        if lastSeek > 399 then
          lastSeek = 399
        end if
        for seek = 0 to lastSeek
          if objects(seek).id = caster then
            axisX = objects(seek).facing.x
            axisY = objects(seek).facing.y
            found = 1
            exit for
          end if
        next seek
        if found = 1 and axisX * axisX + axisY * axisY < 0.5 then
          found = 0
        end if
        if found = 1 then
          relX = spotX - spells(warning).position.x
          relY = spotY - spells(warning).position.y
          along = relX * axisX + relY * axisY
          across = relY * axisX - relX * axisY
          if along >= -0.5 and along <= 8 and across <= 1.25 and across >= -1.25 then
            rThreat = 1
            sideSign = 1
            if across < 0 then
              sideSign = -1
            end if
            dodgeX = spotX - axisY * 1.5 * sideSign
            dodgeY = spotY + axisX * 1.5 * sideSign
            if dodgeX < 1 then
              dodgeX = 1
            elseif dodgeX > map.width - 2 then
              dodgeX = map.width - 2
            end if
            if dodgeY < 1 then
              dodgeY = 1
            elseif dodgeY > map.height - 2 then
              dodgeY = map.height - 2
            end if
            dodgeImpact = impact
          end if
        end if
      end if
    end if
  next warning
  feat(93) = rThreat
end sub

' Projects the query point on one route segment and keeps the closest
' point's distance and arc length along the route.
sub projectSegment(fromX, fromY, toX, toY)
  vx = toX - fromX
  vy = toY - fromY
  span = vx * vx + vy * vy
  segment = sqrt(span)
  t = 0
  if span > 0 then
    t = ((queryX - fromX) * vx + (queryY - fromY) * vy) / span
    if t < 0 then
      t = 0
    elseif t > 1 then
      t = 1
    end if
  end if
  qx = fromX + vx * t - queryX
  qy = fromY + vy * t - queryY
  d = sqrt(qx * qx + qy * qy)
  if d < lineBest then
    lineBest = d
    lineArc = lineTotal + t * segment
  end if
  lineTotal = lineTotal + segment
end sub

' God distances, axis progress and the nearest lane route: lane 0 runs own
' god, (12, 11), enemy god; lane 1 god to god; lane 2 own god, (103, 104),
' enemy god.
sub laneGeometry()
  enemyGodX = map.enemyGod.x
  enemyGodY = map.enemyGod.y
  ownGodX = map.width - 1 - enemyGodX
  ownGodY = map.height - 1 - enemyGodY
  dx = spotX - ownGodX
  dy = spotY - ownGodY
  feat(81) = sqrt(dx * dx + dy * dy)
  ax = enemyGodX - ownGodX
  ay = enemyGodY - ownGodY
  feat(84) = (dx * ax + dy * ay) / (ax * ax + ay * ay)
  dx = spotX - enemyGodX
  dy = spotY - enemyGodY
  feat(83) = sqrt(dx * dx + dy * dy)
  queryX = spotX
  queryY = spotY
  laneBest = 9999
  for lane = 0 to 2
    lineBest = 9999
    lineArc = 0
    lineTotal = 0
    if lane = 1 then
      projectSegment(ownGodX, ownGodY, enemyGodX, enemyGodY)
    else
      cornerX = 12
      cornerY = 11
      if lane = 2 then
        cornerX = 103
        cornerY = 104
      end if
      projectSegment(ownGodX, ownGodY, cornerX, cornerY)
      projectSegment(cornerX, cornerY, enemyGodX, enemyGodY)
    end if
    if lineBest < laneBest then
      laneBest = lineBest
      laneId = lane
      feat(88) = lineArc / lineTotal
    end if
  next lane
  feat(87) = laneBest
end sub

' Every tree feature in the decision frame: after vision, before this
' tick's orders, from self, abilities, items and the unit table.
sub computeFeatures()
  feat(0) = match.battleTick / 1440
  feat(3) = 0
  if self.alive <> 0 then
    feat(3) = 1
  end if
  feat(4) = self.hp
  feat(5) = 0
  if self.maxHp > 0 then
    feat(5) = self.hp / self.maxHp
  end if
  feat(8) = self.level
  feat(9) = self.gold
  damage = self.attackDamage
  if damage < 1 then
    damage = 1
  end if
  feat(10) = damage
  feat(11) = self.attackCooldownTicks
  feat(14) = 0
  if self.canShop <> 0 then
    feat(14) = 1
  end if
  feat(15) = 0
  if self.inOwnSpawn <> 0 then
    feat(15) = 1
  end if
  feat(16) = 0
  if self.hasMoveTarget <> 0 then
    feat(16) = 1
  end if
  feat(17) = targetKind
  feat(18) = targetHpFrac
  feat(19) = targetDistance
  feat(20) = justHit
  feat(21) = sinceHit
  feat(22) = sinceOrder
  feat(23) = prevLabel
  ' Ability slots: rank, ready, cooldown (and W charges) at 27-39.
  for slot = 0 to 3
    ready = 0
    if feat(3) = 1 and abilities(slot).level > 0 then
      if abilities(slot).cooldownTicks = 0 and abilities(slot).charges > 0 then
        if self.mana >= abilities(slot).manaCost then
          if self.controls.silenceTicks = 0 then
            ready = 1
          end if
        end if
      end if
    end if
    base = 27 + slot * 3
    if slot >= 2 then
      base = base + 1
    end if
    feat(base) = abilities(slot).level
    feat(base + 1) = ready
    feat(base + 2) = abilities(slot).cooldownTicks
  next slot
  feat(33) = abilities(1).charges
  ' Items at 41-48.
  feat(41) = healCount
  feat(42) = 0
  if healSlot >= 0 then
    feat(42) = items(healSlot).cooldownTicks
  end if
  feat(43) = manaCount
  feat(44) = elixirCount
  feat(45) = portalCount
  feat(46) = 0
  if portalCount > 0 and self.portalCooldownTicks = 0 then
    feat(46) = 1
  end if
  feat(47) = gearStage
  feat(48) = freeSlots
  ' Heroes, creeps and neutrals at 59-80 and 98.
  feat(61) = 0
  feat(63) = 99
  feat(64) = 0
  feat(65) = 0
  feat(66) = 99
  feat(68) = 0
  feat(72) = 0
  feat(73) = 0
  feat(74) = 99
  feat(76) = 99
  feat(77) = 0
  feat(78) = 0
  feat(79) = 0
  feat(98) = 99
  nearestCreep = -1
  lowestHero = 1000000
  for u = 0 to unitCount - 1
    dx = unitXs(u) - spotX
    dy = unitYs(u) - spotY
    d = sqrt(dx * dx + dy * dy)
    unitDists(u) = d
    code = unitKinds(u)
    if code = 1 then
      if d <= 10 then
        feat(61) = feat(61) + 1
        if unitHps(u) < lowestHero then
          lowestHero = unitHps(u)
          feat(64) = unitHps(u)
          feat(65) = unitHps(u) / unitMaxHps(u)
          feat(66) = d
        end if
      end if
      if d < feat(63) then
        feat(63) = d
      end if
      if unitTargets(u) = self.id then
        feat(68) = feat(68) + 1
      end if
    elseif code = 2 then
      if d <= self.attackRange then
        feat(72) = feat(72) + 1
      end if
      if d <= 8 then
        feat(73) = feat(73) + 1
      end if
      if d < feat(76) then
        feat(76) = d
        nearestCreep = u
      end if
      if d <= 7.5 then
        ratio = unitHps(u) / damage
        if ratio < feat(74) then
          feat(74) = ratio
        end if
      end if
      if unitTargets(u) = self.id then
        feat(78) = feat(78) + 1
      end if
    elseif code = 3 then
      if d < feat(98) then
        feat(98) = d
      end if
    elseif code = 4 then
      if d <= 8 then
        feat(77) = feat(77) + 1
      end if
    elseif code = 5 then
      if d <= 6 then
        feat(79) = feat(79) + 1
      end if
    end if
  next u
  dx = spotX - spawnX
  dy = spotY - spawnY
  feat(82) = sqrt(dx * dx + dy * dy)
  feat(92) = match.waveTicks
end sub

' Pointwise target trees: every visible enemy hero within 14 tiles (want 1)
' or enemy lane creep within 10 tiles (want 2) is scored, and the highest
' chance wins, ties to lower health, then nearer. isCurrent stays 0: the
' replays only hold attack orders that switch targets, so a pick equal to
' the current target means keep attacking. The trees only split rankHp at 1
' and rankDist at 1 and 2, so ranks stop at 3, and ownCreepsOn only matters
' for the nearest creep, which keeps a big creep pile cheap.
sub pickTarget(want, radius, root)
  pickId = 0
  candidateCount = 0
  nearest1 = 9999
  nearest2 = 9999
  lowestHp = 1000000
  for u = 0 to unitCount - 1
    if unitKinds(u) = want and unitDists(u) <= radius then
      candidateCount = candidateCount + 1
      d = unitDists(u)
      if d < nearest1 then
        nearest2 = nearest1
        nearest1 = d
      elseif d < nearest2 then
        nearest2 = d
      end if
      if unitHps(u) < lowestHp then
        lowestHp = unitHps(u)
      end if
    end if
  next u
  if candidateCount = 0 then
    exit sub
  end if
  pickScore = -1
  for u = 0 to unitCount - 1
    if unitKinds(u) = want and unitDists(u) <= radius then
      rankHp = 2
      if unitHps(u) <= lowestHp then
        rankHp = 1
      end if
      rankDist = 3
      if unitDists(u) <= nearest1 then
        rankDist = 1
      elseif unitDists(u) <= nearest2 then
        rankDist = 2
      end if
      alliesOn = 0
      creepsOn = 0
      if want = 1 or rankDist = 1 then
        for v = 0 to unitCount - 1
          if unitTargets(v) = unitIds(u) then
            if unitKinds(v) = 3 then
              alliesOn = alliesOn + 1
            elseif unitKinds(v) = 4 then
              creepsOn = creepsOn + 1
            end if
          end if
        next v
      end if
      hitPoints = unitHps(u)
      if hitPoints < 1 then
        hitPoints = 1
      end if
      feat(101) = unitHps(u)
      feat(102) = 0
      if unitMaxHps(u) > 0 then
        feat(102) = unitHps(u) / unitMaxHps(u)
      end if
      feat(103) = unitDists(u)
      feat(104) = rankHp
      feat(105) = rankDist
      feat(108) = (hitPoints + damage - 1) \ damage
      feat(109) = 0
      feat(110) = alliesOn
      feat(111) = creepsOn
      feat(115) = candidateCount
      evalTree(root)
      better = 0
      if treeValue > pickScore then
        better = 1
      elseif treeValue = pickScore then
        if unitHps(u) < pickHp then
          better = 1
        elseif unitHps(u) = pickHp and unitDists(u) < pickDist then
          better = 1
        end if
      end if
      if better = 1 then
        pickScore = treeValue
        pickId = unitIds(u)
        pickHp = unitHps(u)
        pickDist = unitDists(u)
      end if
    end if
  next u
end sub

' Attack order on a picked hero or creep. Status 0 issued, 1 already on it,
' 2 nobody to attack.
sub attackPick(choice, want, radius, root)
  status = 2
  pickTarget(want, radius, root)
  if pickId = 0 then
    exit sub
  end if
  status = 1
  if pickId = startTarget then
    exit sub
  end if
  accepted = attackTarget(pickId)
  moveLabel = -1
  noteOrder(choice)
  status = 0
end sub

' Attack the danger tower while it is in sight.
sub attackTower()
  status = 2
  if dangerId = 0 or towerSeen(dangerId) <> match.tick then
    exit sub
  end if
  status = 1
  if dangerId = startTarget then
    exit sub
  end if
  accepted = attackTarget(dangerId)
  moveLabel = -1
  noteOrder(6)
  status = 0
end sub

' Other attacks in the replays: a neutral hitting us, an exposed enemy god,
' the nearest enemy barracks, then the nearest neutral within 8 tiles.
sub attackOther()
  status = 2
  otherId = 0
  otherRank = 99
  otherDist = 99
  for u = 0 to unitCount - 1
    code = unitKinds(u)
    rank = 99
    if code = 5 and unitTargets(u) = self.id and unitDists(u) <= 10 then
      rank = 0
    elseif code = 9 and godExposed = 1 and unitDists(u) <= 12 then
      rank = 1
    elseif code = 8 and unitDists(u) <= 10 then
      rank = 2
    elseif code = 5 and unitDists(u) <= 8 then
      rank = 3
    end if
    if rank < otherRank or (rank = otherRank and unitDists(u) < otherDist) then
      if rank < 99 then
        otherRank = rank
        otherDist = unitDists(u)
        otherId = unitIds(u)
      end if
    end if
  next u
  if otherId = 0 then
    exit sub
  end if
  status = 1
  if otherId = startTarget then
    exit sub
  end if
  accepted = attackTarget(otherId)
  moveLabel = -1
  noteOrder(7)
  status = 0
end sub

' Casts one ability on what its aim tree names: the lowest-health enemy
' hero, our creep target or the nearest creep, the danger tower or nearest
' building, or the nearest neutral, all within the ability's range. Q and W
' take a target, E and R a point.
sub castSlot(slot)
  castDone = 0
  evalTree(treeRoots(7 + slot))
  aim = treeValue
  reach = abilities(slot).range
  castId = 0
  castBest = 1000000
  for u = 0 to unitCount - 1
    if unitDists(u) <= reach then
      code = unitKinds(u)
      score = 1000000
      if aim = 1 and code = 1 then
        score = unitHps(u)
      elseif aim = 2 and code = 2 then
        score = unitDists(u)
        if unitIds(u) = startTarget then
          score = -1
        end if
      elseif aim = 3 and (code = 6 or code = 8 or code = 9) then
        score = unitDists(u)
        if unitIds(u) = dangerId then
          score = -1
        end if
      elseif aim = 4 and code = 5 then
        score = unitDists(u)
      end if
      if score < castBest then
        castBest = score
        castId = unitIds(u)
        castX = unitXs(u)
        castY = unitYs(u)
      end if
    end if
  next u
  if castId = 0 then
    exit sub
  end if
  if slot <= 1 then
    accepted = castTarget(slot, castId)
  else
    accepted = castPoint(slot, castX, castY)
  end if
  noteOrder(8 + slot)
  castDone = 1
end sub

' One cast per decision, as on 99% of the replays' cast ticks: the slot the
' primary tree names comes first, then the ready slot whose cast tree gives
' the highest chance above one half, then the next if its aim finds nothing.
sub castSpells(choice)
  forcedDone = 0
  if choice >= 8 and choice <= 11 then
    if feat(28 + (choice - 8) * 3 + ((choice - 8) \ 2)) = 1 then
      castSlot(choice - 8)
      if castDone = 1 then
        forcedDone = 1
        exit sub
      end if
    end if
  end if
  for slot = 0 to 3
    castChance(slot) = 0
    castTried(slot) = 0
    readyIndex = 28 + slot * 3
    if slot >= 2 then
      readyIndex = readyIndex + 1
    end if
    if feat(readyIndex) = 1 then
      evalTree(treeRoots(3 + slot))
      castChance(slot) = treeValue
    end if
  next slot
  for attempt = 1 to 4
    bestSlot = -1
    bestChance = 0.5
    for slot = 0 to 3
      if castTried(slot) = 0 and castChance(slot) > bestChance then
        bestChance = castChance(slot)
        bestSlot = slot
      end if
    next slot
    if bestSlot < 0 then
      exit sub
    end if
    castTried(bestSlot) = 1
    castSlot(bestSlot)
    if castDone = 1 then
      exit sub
    end if
  next attempt
end sub

' Purchases while the shop is open: the buy tree names each item in turn
' (buyIndex counts this tick's purchases) until it says stop. The replays
' never hold more than five heals, two mana potions or one portal scroll.
sub shop()
  for buyIndex = 0 to 7
    scanItems()
    feat(116) = match.battleTick / 1440
    feat(118) = self.gold
    feat(125) = gearStage
    feat(130) = healCount
    feat(132) = manaCount
    feat(133) = elixirCount
    feat(134) = freeSlots
    feat(135) = buyIndex
    evalTree(treeRoots(11))
    item = treeValue
    if item = 0 then
      exit sub
    end if
    price = 30
    stacked = 0
    allowed = 1
    if item = 1 then
      stacked = healCount
      if healCount >= 5 then
        allowed = 0
      end if
    elseif item = 2 then
      price = 75
      stacked = elixirCount
      if elixirCount >= 2 then
        allowed = 0
      end if
    elseif item = 22 then
      price = 45
      stacked = manaCount
      if manaCount >= 2 then
        allowed = 0
      end if
    elseif item = 21 then
      price = 100
      if portalCount >= 1 then
        allowed = 0
      end if
    elseif item = 11 then
      price = 110
      allowed = 1 - hasDagger
    elseif item = 16 then
      price = 160
      allowed = 1 - hasArmor
    elseif item = 19 then
      price = 180
      allowed = 1 - hasBow
    elseif item = 8 then
      price = 100
      allowed = 1 - hasBoots
    end if
    if freeSlots = 0 and stacked = 0 then
      allowed = 0
    end if
    if self.gold < price then
      allowed = 0
    end if
    if allowed = 0 then
      exit sub
    end if
    accepted = buyItem(item)
    noteOrder(12)
    if accepted = 0 then
      exit sub
    end if
  next buyIndex
  scanItems()
end sub

' Potions in the field only, never short of a full restore: a heal at 120
' missing health (at once below half health, otherwise after a second without
' damage, since damage cancels the heal), an elixir at 90, a mana potion at
' 90 missing mana below half mana.
sub drink()
  if self.canShop <> 0 or feat(3) = 0 then
    exit sub
  end if
  drank = 0
  if healSlot >= 0 and self.maxHp - self.hp >= 120 then
    if items(healSlot).cooldownTicks = 0 then
      if self.hp * 2 < self.maxHp or match.tick - hurtTick > 24 then
        accepted = useItem(healSlot)
        noteOrder(13)
        drank = 1
      end if
    end if
  end if
  if drank = 0 and elixirSlot >= 0 and self.maxHp - self.hp >= 90 then
    if items(elixirSlot).cooldownTicks = 0 then
      accepted = useItem(elixirSlot)
      noteOrder(13)
    end if
  end if
  if manaSlot >= 0 and self.maxMana - self.mana >= 90 and self.mana * 2 < self.maxMana then
    if items(manaSlot).cooldownTicks = 0 then
      if self.mana * 10 < self.maxMana * 3 or match.tick - hurtTick > 24 then
        accepted = useItem(manaSlot)
        noteOrder(13)
      end if
    end if
  end if
end sub

' The portal target is our standing tower nearest the enemy god; allies in
' the field within 30 tiles of a tower break the tie between the edge lanes.
sub pickForward()
  forwardId = 0
  forwardScore = 1000000
  for u = 0 to unitCount - 1
    if unitKinds(u) = 7 then
      dx = unitXs(u) - enemyGodX
      dy = unitYs(u) - enemyGodY
      score = dx * dx + dy * dy
      for v = 0 to unitCount - 1
        if unitKinds(v) = 3 then
          hx = unitXs(v) - spawnX
          hy = unitYs(v) - spawnY
          if hx * hx + hy * hy > 400 then
            ax = unitXs(v) - unitXs(u)
            ay = unitYs(v) - unitYs(u)
            if ax * ax + ay * ay <= 900 then
              score = score - 300
            end if
          end if
        end if
      next v
      if score < forwardScore then
        forwardScore = score
        forwardId = unitIds(u)
        forwardX = unitXs(u)
        forwardY = unitYs(u)
      end if
    end if
  next u
end sub

' Walk or attack-move to a goal. The replays re-issue a standing movement
' order only every 48 ticks (12 for short creep approaches), so the same
' order to the same goal waits while the hero is still busy with it. The
' check reads the decision-start label and movement, since a cast or level
' earlier this tick already rewrote the live ones.
sub moveOrder(choice, goalX, goalY)
  status = 0
  if choice = feat(23) and choice = moveLabel then
    dx = goalX - moveX
    dy = goalY - moveY
    if dx * dx + dy * dy < 1 and match.tick - moveTick < moveGap then
      if feat(16) = 1 or startTarget <> 0 then
        status = 1
        exit sub
      end if
    end if
  end if
  if choice <= 1 then
    accepted = attackMove(goalX, goalY)
  else
    accepted = walkTo(goalX, goalY)
  end if
  moveLabel = choice
  moveX = goalX
  moveY = goalY
  moveTick = match.tick
  noteOrder(choice)
end sub

' A Red-frame point in our own frame: Blue mirrors it through the center.
sub framePoint(redX, redY)
  pointX = redX
  pointY = redY
  if self.team = 1 then
    pointX = map.width - 1 - redX
    pointY = map.height - 1 - redY
  end if
end sub

' The lane route nearest a point (0, 1 or 2), or -1 within 25 tiles of
' either god.
sub laneOf(pointX, pointY)
  pointLane = -1
  dx = pointX - ownGodX
  dy = pointY - ownGodY
  if dx * dx + dy * dy < 625 then
    exit sub
  end if
  dx = pointX - enemyGodX
  dy = pointY - enemyGodY
  if dx * dx + dy * dy < 625 then
    exit sub
  end if
  queryX = pointX
  queryY = pointY
  routeBest = 9999
  for route = 0 to 2
    lineBest = 9999
    lineArc = 0
    lineTotal = 0
    if route = 1 then
      projectSegment(ownGodX, ownGodY, enemyGodX, enemyGodY)
    else
      cornerX = 12
      cornerY = 11
      if route = 2 then
        cornerX = 103
        cornerY = 104
      end if
      projectSegment(ownGodX, ownGodY, cornerX, cornerY)
      projectSegment(cornerX, cornerY, enemyGodX, enemyGodY)
    end if
    if lineBest < routeBest then
      routeBest = lineBest
      pointLane = route
    end if
  next route
end sub

' Attack-move goals other than the god, picked at each decision: after
' minute 11.5 the nearest standing enemy guard; in the field the goal of the
' lane we stand on; from the base the map center after minute 6.5, the
' solo's corner for the first three minutes, otherwise the lane with the
' fewest allied heroes out in it (ties to the pack lane). Lane goals are the
' corners (11, 11) and (104, 104) and the center (58, 58 in the Red frame);
' these rules match 80% of the replays' choices on held-out games.
sub tripPoint()
  tripX = -1
  if feat(0) >= 11.5 then
    best = 1000000
    for slot = 28 to 31
      if towerStates(slot) = 1 and (slot - 28) \ 2 = enemyTeam then
        dx = towerXs(slot) - spotX
        dy = towerYs(slot) - spotY
        if dx * dx + dy * dy < best then
          best = dx * dx + dy * dy
          tripX = towerXs(slot)
          tripY = towerYs(slot)
        end if
      end if
    next slot
  end if
  if tripX >= 0 then
    exit sub
  end if
  packLane = 2
  if self.team = 1 then
    packLane = 0
  end if
  laneOf(spotX, spotY)
  tripLane = pointLane
  if tripLane < 0 then
    if feat(0) >= 6.5 then
      tripLane = 1
    elseif feat(0) < 3 and isSolo = 1 then
      tripLane = 2 - packLane
    else
      ' Count allied heroes out on each lane.
      laneAllies0 = 0
      laneAllies1 = 0
      laneAllies2 = 0
      for u = 0 to unitCount - 1
        if unitKinds(u) = 3 then
          laneOf(unitXs(u), unitYs(u))
          if pointLane = 0 then
            laneAllies0 = laneAllies0 + 1
          elseif pointLane = 1 then
            laneAllies1 = laneAllies1 + 1
          elseif pointLane = 2 then
            laneAllies2 = laneAllies2 + 1
          end if
        end if
      next u
      tripLane = packLane
      fewest = laneAllies0
      if packLane = 2 then
        fewest = laneAllies2
      end if
      if laneAllies0 < fewest then
        tripLane = 0
        fewest = laneAllies0
      end if
      if laneAllies1 < fewest then
        tripLane = 1
        fewest = laneAllies1
      end if
      if laneAllies2 < fewest then
        tripLane = 2
      end if
    end if
  end if
  if tripLane = 0 then
    pointX = 11
    pointY = 11
  elseif tripLane = 2 then
    pointX = 104
    pointY = 104
  else
    framePoint(58, 58)
  end if
  tripX = pointX
  tripY = pointY
end sub

' Where one route segment first comes within holdRadius of the hold tower:
' the foot of the tower on the segment, backed off along it.
sub routeEntry(fromX, fromY, toX, toY)
  if holdX >= 0 then
    exit sub
  end if
  vx = toX - fromX
  vy = toY - fromY
  span = vx * vx + vy * vy
  if span <= 0 then
    exit sub
  end if
  t = ((holdTowerX - fromX) * vx + (holdTowerY - fromY) * vy) / span
  qx = fromX + vx * t - holdTowerX
  qy = fromY + vy * t - holdTowerY
  side = qx * qx + qy * qy
  if side > holdRadius * holdRadius then
    exit sub
  end if
  t = t - sqrt(holdRadius * holdRadius - side) / sqrt(span)
  if t >= 0 and t <= 1 then
    holdX = fromX + vx * t
    holdY = fromY + vy * t
  end if
end sub

' Long walks stage 1.75 tiles outside the reach of the next enemy tower on
' our route: the first standing one of outer, inner and gate, then the guard
' nearest that lane's gate. The spot lies on the line from the fallen tower
' before it, or for an outer tower where the lane route enters that reach
' (the replays' (103, 97), (58, 104), (40, 106), (27, 110), (19, 105),
' (8, 75) and (5, 88) in the Red frame). The route is a lane with every
' tower down (our pack lane first, then mid, then the other edge), else the
' edge lane we stand on, else the pack lane (2 for Red, 0 for Blue).
sub holdSpot()
  holdX = -1
  holdTower = 0
  previous = 0
  packLane = 2
  if self.team = 1 then
    packLane = 0
  end if
  routeLane = -1
  for pass = 0 to 2
    lane = packLane
    if pass = 1 then
      lane = 1
    elseif pass = 2 then
      lane = 2 - packLane
    end if
    if routeLane < 0 then
      down = 0
      for tier = 0 to 2
        slot = 10 + lane * 6 + enemyTeam * 3 + tier
        if towerStates(slot) = 0 and towerMaxHps(slot) > 0 then
          down = down + 1
        end if
      next tier
      if down = 3 then
        routeLane = lane
      end if
    end if
  next pass
  if routeLane < 0 then
    routeLane = packLane
    if laneId <> 1 then
      routeLane = laneId
    end if
  end if
  for tier = 0 to 2
    if holdTower = 0 then
      slot = 10 + routeLane * 6 + enemyTeam * 3 + tier
      if towerStates(slot) = 1 then
        holdTower = slot
      else
        previous = slot
      end if
    end if
  next tier
  if holdTower = 0 then
    best = 1000000
    for slot = 28 + enemyTeam * 2 to 29 + enemyTeam * 2
      if towerStates(slot) = 1 then
        dx = towerXs(slot) - towerXs(previous)
        dy = towerYs(slot) - towerYs(previous)
        if dx * dx + dy * dy < best then
          best = dx * dx + dy * dy
          holdTower = slot
        end if
      end if
    next slot
  end if
  if holdTower = 0 then
    exit sub
  end if
  holdTowerX = towerXs(holdTower)
  holdTowerY = towerYs(holdTower)
  towerStats(towerMaxHps(holdTower))
  holdRadius = towerRange + 1.75
  if previous > 0 and towerMaxHps(previous) > 0 then
    dx = towerXs(previous) - holdTowerX
    dy = towerYs(previous) - holdTowerY
    span = sqrt(dx * dx + dy * dy)
    if span > 0 then
      holdX = holdTowerX + dx * holdRadius / span
      holdY = holdTowerY + dy * holdRadius / span
    end if
    exit sub
  end if
  if routeLane = 1 then
    routeEntry(ownGodX, ownGodY, enemyGodX, enemyGodY)
  else
    cornerX = 12
    cornerY = 11
    if routeLane = 2 then
      cornerX = 103
      cornerY = 104
    end if
    routeEntry(ownGodX, ownGodY, cornerX, cornerY)
    routeEntry(cornerX, cornerY, enemyGodX, enemyGodY)
  end if
end sub

' Walks in the replays: toward an enemy creep within 18.4 tiles, stopping
' 4.5 tiles short of it; otherwise to the hold spot of the next enemy tower
' on our lane; failing that, toward this trip's attack-move goal.
sub walkMove()
  status = 2
  moveGap = 48
  if nearestCreep >= 0 and feat(76) <= 18.4 then
    if feat(76) <= 4.75 then
      exit sub
    end if
    scale = 4.5 / feat(76)
    goalX = unitXs(nearestCreep) + (spotX - unitXs(nearestCreep)) * scale
    goalY = unitYs(nearestCreep) + (spotY - unitYs(nearestCreep)) * scale
    if feat(76) - 4.5 < 10 then
      moveGap = 12
    end if
    moveOrder(17, goalX, goalY)
    exit sub
  end if
  holdSpot()
  goalX = holdX
  goalY = holdY
  if goalX < 0 then
    tripPoint()
    goalX = tripX
    goalY = tripY
  end if
  dx = goalX - spotX
  dy = goalY - spotY
  if dx * dx + dy * dy <= 4 then
    ' Already there: hold on the spot rather than fall back.
    accepted = walkTo(spotX, spotY)
    moveLabel = 3
    noteOrder(3)
    status = 0
    exit sub
  end if
  moveOrder(17, goalX, goalY)
end sub

' Stand still with a walk onto our own spot: the stutter step after a hit
' (the next tick re-attacks) and the hold while hurt; inside an enemy Clockwork
' Charge it is the sidestep instead.
sub stepOrder()
  if rThreat = 1 then
    accepted = walkTo(dodgeX, dodgeY)
    if accepted = 0 then
      accepted = walkTo(spotX + spotX - dodgeX, spotY + spotY - dodgeY)
    end if
    dodgeUntil = dodgeImpact + 1
  else
    accepted = walkTo(spotX, spotY)
    if justHit = 1 and startTarget <> 0 then
      resumeTick = match.tick + 1
    end if
  end if
  moveLabel = 3
  noteOrder(3)
  status = 0
end sub

' Portal from the shop to the forward tower, or from the field home.
sub portalOrder()
  status = 2
  if portalSlot < 0 or portalCount = 0 or self.portalCooldownTicks > 0 then
    exit sub
  end if
  if feat(14) = 1 then
    pickForward()
    if forwardId = 0 then
      exit sub
    end if
    dx = forwardX - spotX
    dy = forwardY - spotY
    if dx * dx + dy * dy <= 400 then
      exit sub
    end if
    accepted = useItemAt(portalSlot, forwardX, forwardY)
  else
    if feat(82) <= 10 then
      exit sub
    end if
    accepted = useItemAt(portalSlot, spawnX, spawnY)
  end if
  moveLabel = -1
  noteOrder(14)
  status = 0
end sub

' The tree's hold leaf (WALK_STEP after WALK_STEP within 6 ticks, nothing
' in range) has no way out: holds re-issue every 6 ticks, so sinceOrder
' never grows. The replays end holds this way: in base once healed past
' 0.898 (0 of 127 such rows hold on; 82% attack-move the god), never in the
' keep outside spawn, and at hpFrac 0.8 or more within 240 ticks (no such
' run lasts longer). The longest hold in the replays is 810 ticks.
sub holdExit()
  if label <> 3 or feat(23) <> 3 or startTarget <> 0 then
    exit sub
  end if
  if rThreat <> 0 or justHit <> 0 then
    exit sub
  end if
  holdTicks = match.tick - holdSince
  holdNext = -1
  if feat(14) = 1 then
    if feat(5) > 0.898 then
      holdNext = 0
    elseif feat(15) = 0 then
      holdNext = 2
    end if
  elseif holdTicks >= 960 then
    holdNext = 0
    if feat(5) < 0.65 then
      holdNext = 2
    end if
  elseif holdTicks >= 240 and feat(5) >= 0.8 then
    holdNext = 0
  end if
  if holdNext >= 0 then
    label = holdNext
    runnerUp = -1
  end if
end sub

' Turns one primary class into an order. Status 0 issued, 1 the hero is
' already doing it, 2 the class has no target here (try the runner-up).
sub execute(choice)
  status = 0
  moveGap = 48
  if choice = 0 then
    moveOrder(0, enemyGodX, enemyGodY)
  elseif choice = 1 then
    tripPoint()
    dx = tripX - spotX
    dy = tripY - spotY
    if dx * dx + dy * dy <= 36 then
      status = 2
    else
      moveOrder(1, tripX, tripY)
    end if
  elseif choice = 2 then
    moveOrder(2, homeX, homeY)
  elseif choice = 3 then
    stepOrder()
  elseif choice = 4 then
    attackPick(4, 2, 10, treeRoots(2))
  elseif choice = 5 then
    attackPick(5, 1, 14, treeRoots(1))
  elseif choice = 6 then
    attackTower()
  elseif choice = 7 then
    attackOther()
  elseif choice >= 8 and choice <= 11 then
    if forcedDone = 0 then
      status = 2
    end if
  elseif choice = 14 then
    portalOrder()
  elseif choice = 17 then
    walkMove()
  end if
end sub

' Drafting: pick and load the trees while the draft runs.
if draft.active then
  chooseHero()
  if nodeCount = 0 then
    loadTrees()
  end if
  end
end if
if nodeCount = 0 then
  loadTrees()
end if

' Decision-start state: our exact spot and tile, and the target before this
' tick's orders (self refreshes after every command).
spotX = self.position.x
spotY = self.position.y
startTarget = self.targetId
if memoryReady = 0 then
  memoryReady = 1
  lastHitTick = -10000
  lastOrderTick = -10000
  prevLabel = -1
  moveLabel = -1
  previousHits = self.attacksLanded
  previousHp = self.hp
  spawnX = spotX
  spawnY = spotY
  ' Walks home end on the spawn tile's center, as macromackie's do, never
  ' on the exact spawn point: there dSpawn reads 0, the tree's fresh
  ' respawn branch that leaves at once instead of healing up.
  homeX = floor(spawnX + .5)
  homeY = floor(spawnY + .5)
  holdSince = 0
  ordinal = 0
  for player = 0 to draft.playerCount - 1
    if players(player).team = self.team then
      if players(player).id < self.id then
        ordinal = ordinal + 1
      end if
    end if
  next player
  ' The solo holds the other edge: Red ordinal 4, Blue ordinal 1.
  isSolo = 0
  if self.team = 0 and ordinal = 4 then
    isSolo = 1
  elseif self.team = 1 and ordinal = 1 then
    isSolo = 1
  end if
end if

' Memory read every tick: landed hits and damage taken.
justHit = 0
if self.attacksLanded > previousHits then
  justHit = 1
  lastHitTick = match.tick
end if
previousHits = self.attacksLanded
if self.hp < previousHp then
  hurtTick = match.tick
end if
previousHp = self.hp

' Death: buy back whenever the price is covered (the buyback tree splits at
' gold minus price above -5, and a short purse is refused).
if self.hp <= 0 then
  price = self.buybackPrice
  if price > 0 and self.gold >= price then
    accepted = buyback()
    noteOrder(16)
  end if
  dodgeUntil = 0
  resumeTick = 0
  end
end if
if self.channelTicks > 0 or self.controls.stunTicks > 0 then
  end
end if
if match.tick < dodgeUntil then
  end
end if

' Think every six ticks, on a landed hit, and on the tick after a stutter
' step, as macromackie's order gaps of 6, 12, 18 and 48 ticks and its
' one-tick re-attacks show.
if justHit = 0 and match.tick <> resumeTick and match.tick < nextThink then
  end
end if
nextThink = match.tick + 6
sinceHit = match.tick - lastHitTick
if sinceHit > 9999 then
  sinceHit = 9999
end if
sinceOrder = match.tick - lastOrderTick
if sinceOrder > 9999 then
  sinceOrder = 9999
end if

observe()
judgeTowers()
scanItems()
readSpells()
laneGeometry()
computeFeatures()

' Same-tick order of the replays: levels, purchases and potions first, then
' a cast, then the movement or attack order.
learnAbilities()
if self.canShop <> 0 then
  shop()
end if
drink()
if feat(23) <> 3 then
  holdSince = match.tick
end if
evalTree(treeRoots(0))
label = treeValue mod 32
runnerUp = treeValue \ 32 - 1
holdExit()
castSpells(label)
execute(label)
if status = 2 and runnerUp >= 0 then
  execute(runnerUp)
end if

' Safety net: macromackie never goes four seconds without an order (its
' gaps stop at 72 ticks), so an idle hero outside spawn that has sent
' nothing for 96 ticks attack-moves on the enemy god.
if lastOrderTick <> match.tick and sinceOrder >= 96 and feat(3) = 1 then
  if self.hasMoveTarget = 0 and startTarget = 0 and self.inOwnSpawn = 0 then
    moveGap = 48
    moveOrder(0, enemyGodX, enemyGodY)
  end if
end if
