' Scott pidip v5: deterministic DAIDE negotiations and bounded search.
dim loc$(81)
dim power$(7)
dim uc(63)
dim uk(63)
dim ut(63)
dim ur(63)
dim parent(81)
dim tk$(255)
dim mate(255)
dim stack(63)
dim ru(15)
dim rk(15)
dim rt(15)
dim rs(15)
if initialized = 0 then
loc$(1)="CLY"
loc$(2)="EDI"
loc$(3)="LVP"
loc$(4)="YOR"
loc$(5)="WAL"
loc$(6)="LON"
loc$(7)="POR"
loc$(8)="SPA"
loc$(9)="NAF"
loc$(10)="TUN"
loc$(11)="NAP"
loc$(12)="ROM"
loc$(13)="TUS"
loc$(14)="PIE"
loc$(15)="VEN"
loc$(16)="APU"
loc$(17)="GRE"
loc$(18)="ALB"
loc$(19)="SER"
loc$(20)="BUL"
loc$(21)="RUM"
loc$(22)="CON"
loc$(23)="SMY"
loc$(24)="ANK"
loc$(25)="ARM"
loc$(26)="SYR"
loc$(27)="SEV"
loc$(28)="UKR"
loc$(29)="WAR"
loc$(30)="LVN"
loc$(31)="MOS"
loc$(32)="STP"
loc$(33)="FIN"
loc$(34)="SWE"
loc$(35)="NWY"
loc$(36)="DEN"
loc$(37)="KIE"
loc$(38)="BER"
loc$(39)="PRU"
loc$(40)="SIL"
loc$(41)="MUN"
loc$(42)="RUH"
loc$(43)="HOL"
loc$(44)="BEL"
loc$(45)="PIC"
loc$(46)="BRE"
loc$(47)="PAR"
loc$(48)="BUR"
loc$(49)="MAR"
loc$(50)="GAS"
loc$(51)="BAR"
loc$(52)="NWG"
loc$(53)="NTH"
loc$(54)="SKA"
loc$(55)="HEL"
loc$(56)="BAL"
loc$(57)="GOB"
loc$(58)="NAO"
loc$(59)="IRI"
loc$(60)="ECH"
loc$(61)="MAO"
loc$(62)="WES"
loc$(63)="GOL"
loc$(64)="TYS"
loc$(65)="ION"
loc$(66)="ADR"
loc$(67)="AEG"
loc$(68)="EAS"
loc$(69)="BLA"
loc$(70)="TYR"
loc$(71)="BOH"
loc$(72)="VIE"
loc$(73)="TRI"
loc$(74)="BUD"
loc$(75)="GAL"
loc$(76)="(SPA NCS)"
loc$(77)="(SPA SCS)"
loc$(78)="(STP NCS)"
loc$(79)="(STP SCS)"
loc$(80)="(BUL ECS)"
loc$(81)="(BUL SCS)"
power$(1)="ENG"
power$(2)="FRA"
power$(3)="ITA"
power$(4)="GER"
power$(5)="AUS"
power$(6)="TUR"
power$(7)="RUS"
  initialized = 1
end if
me = selfCountry()
nu = unitCount()
round = negotiationRound()
tick = worldTick()
for boardUnit = 0 to nu - 1
  uc(boardUnit) = unitCountry(boardUnit)
  uk(boardUnit) = unitType(boardUnit)
  ut(boardUnit) = unitTerritory(boardUnit)
  ur(boardUnit) = unitRetreating(boardUnit)
next boardUnit
for boardTerritory = 1 to 81
  parent(boardTerritory) = territoryParent(boardTerritory)
next boardTerritory
dim nodeValid(163)
dim edgeStart(163)
dim edgeCount(163)
dim edgeTo(1000)
dim incomingStart(81)
dim incomingCount(81)
dim incomingNode(1000)
dim supply(81)
dim terrain(81)
dim ownNodeStart(81)
dim ownNodeCount(81)
dim ownNode(163)
if mapReady = 0 then
nodeValid(1) = 1
edgeStart(1) = 0
edgeCount(1) = 2
edgeTo(0) = 2
edgeTo(1) = 3
nodeValid(2) = 1
edgeStart(2) = 2
edgeCount(2) = 3
edgeTo(2) = 1
edgeTo(3) = 3
edgeTo(4) = 4
nodeValid(3) = 1
edgeStart(3) = 5
edgeCount(3) = 4
edgeTo(5) = 1
edgeTo(6) = 2
edgeTo(7) = 4
edgeTo(8) = 5
nodeValid(4) = 1
edgeStart(4) = 9
edgeCount(4) = 4
edgeTo(9) = 2
edgeTo(10) = 3
edgeTo(11) = 5
edgeTo(12) = 6
nodeValid(5) = 1
edgeStart(5) = 13
edgeCount(5) = 3
edgeTo(13) = 3
edgeTo(14) = 4
edgeTo(15) = 6
nodeValid(6) = 1
edgeStart(6) = 16
edgeCount(6) = 2
edgeTo(16) = 4
edgeTo(17) = 5
nodeValid(7) = 1
edgeStart(7) = 18
edgeCount(7) = 1
edgeTo(18) = 8
nodeValid(8) = 1
edgeStart(8) = 19
edgeCount(8) = 3
edgeTo(19) = 7
edgeTo(20) = 49
edgeTo(21) = 50
nodeValid(9) = 1
edgeStart(9) = 22
edgeCount(9) = 1
edgeTo(22) = 10
nodeValid(10) = 1
edgeStart(10) = 23
edgeCount(10) = 1
edgeTo(23) = 9
nodeValid(11) = 1
edgeStart(11) = 24
edgeCount(11) = 2
edgeTo(24) = 12
edgeTo(25) = 16
nodeValid(12) = 1
edgeStart(12) = 26
edgeCount(12) = 4
edgeTo(26) = 11
edgeTo(27) = 13
edgeTo(28) = 15
edgeTo(29) = 16
nodeValid(13) = 1
edgeStart(13) = 30
edgeCount(13) = 3
edgeTo(30) = 12
edgeTo(31) = 14
edgeTo(32) = 15
nodeValid(14) = 1
edgeStart(14) = 33
edgeCount(14) = 4
edgeTo(33) = 13
edgeTo(34) = 15
edgeTo(35) = 49
edgeTo(36) = 70
nodeValid(15) = 1
edgeStart(15) = 37
edgeCount(15) = 6
edgeTo(37) = 12
edgeTo(38) = 13
edgeTo(39) = 14
edgeTo(40) = 16
edgeTo(41) = 70
edgeTo(42) = 73
nodeValid(16) = 1
edgeStart(16) = 43
edgeCount(16) = 3
edgeTo(43) = 11
edgeTo(44) = 12
edgeTo(45) = 15
nodeValid(17) = 1
edgeStart(17) = 46
edgeCount(17) = 3
edgeTo(46) = 18
edgeTo(47) = 19
edgeTo(48) = 20
nodeValid(18) = 1
edgeStart(18) = 49
edgeCount(18) = 3
edgeTo(49) = 17
edgeTo(50) = 19
edgeTo(51) = 73
nodeValid(19) = 1
edgeStart(19) = 52
edgeCount(19) = 6
edgeTo(52) = 17
edgeTo(53) = 18
edgeTo(54) = 20
edgeTo(55) = 21
edgeTo(56) = 73
edgeTo(57) = 74
nodeValid(20) = 1
edgeStart(20) = 58
edgeCount(20) = 4
edgeTo(58) = 17
edgeTo(59) = 19
edgeTo(60) = 21
edgeTo(61) = 22
nodeValid(21) = 1
edgeStart(21) = 62
edgeCount(21) = 6
edgeTo(62) = 19
edgeTo(63) = 20
edgeTo(64) = 27
edgeTo(65) = 28
edgeTo(66) = 74
edgeTo(67) = 75
nodeValid(22) = 1
edgeStart(22) = 68
edgeCount(22) = 3
edgeTo(68) = 20
edgeTo(69) = 23
edgeTo(70) = 24
nodeValid(23) = 1
edgeStart(23) = 71
edgeCount(23) = 4
edgeTo(71) = 22
edgeTo(72) = 24
edgeTo(73) = 25
edgeTo(74) = 26
nodeValid(24) = 1
edgeStart(24) = 75
edgeCount(24) = 3
edgeTo(75) = 22
edgeTo(76) = 23
edgeTo(77) = 25
nodeValid(25) = 1
edgeStart(25) = 78
edgeCount(25) = 4
edgeTo(78) = 23
edgeTo(79) = 24
edgeTo(80) = 26
edgeTo(81) = 27
nodeValid(26) = 1
edgeStart(26) = 82
edgeCount(26) = 2
edgeTo(82) = 23
edgeTo(83) = 25
nodeValid(27) = 1
edgeStart(27) = 84
edgeCount(27) = 4
edgeTo(84) = 21
edgeTo(85) = 25
edgeTo(86) = 28
edgeTo(87) = 31
nodeValid(28) = 1
edgeStart(28) = 88
edgeCount(28) = 5
edgeTo(88) = 21
edgeTo(89) = 27
edgeTo(90) = 29
edgeTo(91) = 31
edgeTo(92) = 75
nodeValid(29) = 1
edgeStart(29) = 93
edgeCount(29) = 6
edgeTo(93) = 28
edgeTo(94) = 30
edgeTo(95) = 31
edgeTo(96) = 39
edgeTo(97) = 40
edgeTo(98) = 75
nodeValid(30) = 1
edgeStart(30) = 99
edgeCount(30) = 4
edgeTo(99) = 29
edgeTo(100) = 31
edgeTo(101) = 32
edgeTo(102) = 39
nodeValid(31) = 1
edgeStart(31) = 103
edgeCount(31) = 5
edgeTo(103) = 27
edgeTo(104) = 28
edgeTo(105) = 29
edgeTo(106) = 30
edgeTo(107) = 32
nodeValid(32) = 1
edgeStart(32) = 108
edgeCount(32) = 4
edgeTo(108) = 30
edgeTo(109) = 31
edgeTo(110) = 33
edgeTo(111) = 35
nodeValid(33) = 1
edgeStart(33) = 112
edgeCount(33) = 3
edgeTo(112) = 32
edgeTo(113) = 34
edgeTo(114) = 35
nodeValid(34) = 1
edgeStart(34) = 115
edgeCount(34) = 3
edgeTo(115) = 33
edgeTo(116) = 35
edgeTo(117) = 36
nodeValid(35) = 1
edgeStart(35) = 118
edgeCount(35) = 3
edgeTo(118) = 32
edgeTo(119) = 33
edgeTo(120) = 34
nodeValid(36) = 1
edgeStart(36) = 121
edgeCount(36) = 2
edgeTo(121) = 34
edgeTo(122) = 37
nodeValid(37) = 1
edgeStart(37) = 123
edgeCount(37) = 5
edgeTo(123) = 36
edgeTo(124) = 38
edgeTo(125) = 41
edgeTo(126) = 42
edgeTo(127) = 43
nodeValid(38) = 1
edgeStart(38) = 128
edgeCount(38) = 4
edgeTo(128) = 37
edgeTo(129) = 39
edgeTo(130) = 40
edgeTo(131) = 41
nodeValid(39) = 1
edgeStart(39) = 132
edgeCount(39) = 4
edgeTo(132) = 29
edgeTo(133) = 30
edgeTo(134) = 38
edgeTo(135) = 40
nodeValid(40) = 1
edgeStart(40) = 136
edgeCount(40) = 6
edgeTo(136) = 29
edgeTo(137) = 38
edgeTo(138) = 39
edgeTo(139) = 41
edgeTo(140) = 71
edgeTo(141) = 75
nodeValid(41) = 1
edgeStart(41) = 142
edgeCount(41) = 7
edgeTo(142) = 37
edgeTo(143) = 38
edgeTo(144) = 40
edgeTo(145) = 42
edgeTo(146) = 48
edgeTo(147) = 70
edgeTo(148) = 71
nodeValid(42) = 1
edgeStart(42) = 149
edgeCount(42) = 5
edgeTo(149) = 37
edgeTo(150) = 41
edgeTo(151) = 43
edgeTo(152) = 44
edgeTo(153) = 48
nodeValid(43) = 1
edgeStart(43) = 154
edgeCount(43) = 3
edgeTo(154) = 37
edgeTo(155) = 42
edgeTo(156) = 44
nodeValid(44) = 1
edgeStart(44) = 157
edgeCount(44) = 4
edgeTo(157) = 42
edgeTo(158) = 43
edgeTo(159) = 45
edgeTo(160) = 48
nodeValid(45) = 1
edgeStart(45) = 161
edgeCount(45) = 4
edgeTo(161) = 44
edgeTo(162) = 46
edgeTo(163) = 47
edgeTo(164) = 48
nodeValid(46) = 1
edgeStart(46) = 165
edgeCount(46) = 3
edgeTo(165) = 45
edgeTo(166) = 47
edgeTo(167) = 50
nodeValid(47) = 1
edgeStart(47) = 168
edgeCount(47) = 4
edgeTo(168) = 45
edgeTo(169) = 46
edgeTo(170) = 48
edgeTo(171) = 50
nodeValid(48) = 1
edgeStart(48) = 172
edgeCount(48) = 7
edgeTo(172) = 41
edgeTo(173) = 42
edgeTo(174) = 44
edgeTo(175) = 45
edgeTo(176) = 47
edgeTo(177) = 49
edgeTo(178) = 50
nodeValid(49) = 1
edgeStart(49) = 179
edgeCount(49) = 4
edgeTo(179) = 8
edgeTo(180) = 14
edgeTo(181) = 48
edgeTo(182) = 50
nodeValid(50) = 1
edgeStart(50) = 183
edgeCount(50) = 5
edgeTo(183) = 8
edgeTo(184) = 46
edgeTo(185) = 47
edgeTo(186) = 48
edgeTo(187) = 49
nodeValid(70) = 1
edgeStart(70) = 188
edgeCount(70) = 6
edgeTo(188) = 14
edgeTo(189) = 15
edgeTo(190) = 41
edgeTo(191) = 71
edgeTo(192) = 72
edgeTo(193) = 73
nodeValid(71) = 1
edgeStart(71) = 194
edgeCount(71) = 5
edgeTo(194) = 40
edgeTo(195) = 41
edgeTo(196) = 70
edgeTo(197) = 72
edgeTo(198) = 75
nodeValid(72) = 1
edgeStart(72) = 199
edgeCount(72) = 5
edgeTo(199) = 70
edgeTo(200) = 71
edgeTo(201) = 73
edgeTo(202) = 74
edgeTo(203) = 75
nodeValid(73) = 1
edgeStart(73) = 204
edgeCount(73) = 6
edgeTo(204) = 15
edgeTo(205) = 18
edgeTo(206) = 19
edgeTo(207) = 70
edgeTo(208) = 72
edgeTo(209) = 74
nodeValid(74) = 1
edgeStart(74) = 210
edgeCount(74) = 5
edgeTo(210) = 19
edgeTo(211) = 21
edgeTo(212) = 72
edgeTo(213) = 73
edgeTo(214) = 75
nodeValid(75) = 1
edgeStart(75) = 215
edgeCount(75) = 7
edgeTo(215) = 21
edgeTo(216) = 28
edgeTo(217) = 29
edgeTo(218) = 40
edgeTo(219) = 71
edgeTo(220) = 72
edgeTo(221) = 74
nodeValid(83) = 1
edgeStart(83) = 222
edgeCount(83) = 4
edgeTo(222) = 84
edgeTo(223) = 85
edgeTo(224) = 134
edgeTo(225) = 140
nodeValid(84) = 1
edgeStart(84) = 226
edgeCount(84) = 4
edgeTo(226) = 83
edgeTo(227) = 86
edgeTo(228) = 134
edgeTo(229) = 135
nodeValid(85) = 1
edgeStart(85) = 230
edgeCount(85) = 4
edgeTo(230) = 83
edgeTo(231) = 87
edgeTo(232) = 140
edgeTo(233) = 141
nodeValid(86) = 1
edgeStart(86) = 234
edgeCount(86) = 3
edgeTo(234) = 84
edgeTo(235) = 88
edgeTo(236) = 135
nodeValid(87) = 1
edgeStart(87) = 237
edgeCount(87) = 4
edgeTo(237) = 85
edgeTo(238) = 88
edgeTo(239) = 141
edgeTo(240) = 142
nodeValid(88) = 1
edgeStart(88) = 241
edgeCount(88) = 4
edgeTo(241) = 86
edgeTo(242) = 87
edgeTo(243) = 135
edgeTo(244) = 142
nodeValid(89) = 1
edgeStart(89) = 245
edgeCount(89) = 3
edgeTo(245) = 143
edgeTo(246) = 158
edgeTo(247) = 159
nodeValid(91) = 1
edgeStart(91) = 248
edgeCount(91) = 3
edgeTo(248) = 92
edgeTo(249) = 143
edgeTo(250) = 144
nodeValid(92) = 1
edgeStart(92) = 251
edgeCount(92) = 4
edgeTo(251) = 91
edgeTo(252) = 144
edgeTo(253) = 146
edgeTo(254) = 147
nodeValid(93) = 1
edgeStart(93) = 255
edgeCount(93) = 4
edgeTo(255) = 94
edgeTo(256) = 98
edgeTo(257) = 146
edgeTo(258) = 147
nodeValid(94) = 1
edgeStart(94) = 259
edgeCount(94) = 3
edgeTo(259) = 93
edgeTo(260) = 95
edgeTo(261) = 146
nodeValid(95) = 1
edgeStart(95) = 262
edgeCount(95) = 4
edgeTo(262) = 94
edgeTo(263) = 96
edgeTo(264) = 145
edgeTo(265) = 146
nodeValid(96) = 1
edgeStart(96) = 266
edgeCount(96) = 3
edgeTo(266) = 95
edgeTo(267) = 131
edgeTo(268) = 145
nodeValid(97) = 1
edgeStart(97) = 269
edgeCount(97) = 3
edgeTo(269) = 98
edgeTo(270) = 148
edgeTo(271) = 155
nodeValid(98) = 1
edgeStart(98) = 272
edgeCount(98) = 4
edgeTo(272) = 93
edgeTo(273) = 97
edgeTo(274) = 147
edgeTo(275) = 148
nodeValid(99) = 1
edgeStart(99) = 276
edgeCount(99) = 4
edgeTo(276) = 100
edgeTo(277) = 147
edgeTo(278) = 149
edgeTo(279) = 163
nodeValid(100) = 1
edgeStart(100) = 280
edgeCount(100) = 4
edgeTo(280) = 99
edgeTo(281) = 147
edgeTo(282) = 148
edgeTo(283) = 155
nodeValid(103) = 1
edgeStart(103) = 284
edgeCount(103) = 3
edgeTo(284) = 109
edgeTo(285) = 151
edgeTo(286) = 162
nodeValid(104) = 1
edgeStart(104) = 287
edgeCount(104) = 6
edgeTo(287) = 105
edgeTo(288) = 106
edgeTo(289) = 149
edgeTo(290) = 151
edgeTo(291) = 162
edgeTo(292) = 163
nodeValid(105) = 1
edgeStart(105) = 293
edgeCount(105) = 4
edgeTo(293) = 104
edgeTo(294) = 108
edgeTo(295) = 149
edgeTo(296) = 150
nodeValid(106) = 1
edgeStart(106) = 297
edgeCount(106) = 3
edgeTo(297) = 104
edgeTo(298) = 107
edgeTo(299) = 151
nodeValid(107) = 1
edgeStart(107) = 300
edgeCount(107) = 3
edgeTo(300) = 106
edgeTo(301) = 109
edgeTo(302) = 151
nodeValid(108) = 1
edgeStart(108) = 303
edgeCount(108) = 2
edgeTo(303) = 105
edgeTo(304) = 150
nodeValid(109) = 1
edgeStart(109) = 305
edgeCount(109) = 3
edgeTo(305) = 103
edgeTo(306) = 107
edgeTo(307) = 151
nodeValid(112) = 1
edgeStart(112) = 308
edgeCount(112) = 4
edgeTo(308) = 121
edgeTo(309) = 138
edgeTo(310) = 139
edgeTo(311) = 161
nodeValid(115) = 1
edgeStart(115) = 312
edgeCount(115) = 3
edgeTo(312) = 116
edgeTo(313) = 139
edgeTo(314) = 161
nodeValid(116) = 1
edgeStart(116) = 315
edgeCount(116) = 6
edgeTo(315) = 115
edgeTo(316) = 117
edgeTo(317) = 118
edgeTo(318) = 136
edgeTo(319) = 138
edgeTo(320) = 139
nodeValid(117) = 1
edgeStart(117) = 321
edgeCount(117) = 6
edgeTo(321) = 116
edgeTo(322) = 133
edgeTo(323) = 134
edgeTo(324) = 135
edgeTo(325) = 136
edgeTo(326) = 160
nodeValid(118) = 1
edgeStart(118) = 327
edgeCount(118) = 6
edgeTo(327) = 116
edgeTo(328) = 119
edgeTo(329) = 135
edgeTo(330) = 136
edgeTo(331) = 137
edgeTo(332) = 138
nodeValid(119) = 1
edgeStart(119) = 333
edgeCount(119) = 5
edgeTo(333) = 118
edgeTo(334) = 120
edgeTo(335) = 125
edgeTo(336) = 137
edgeTo(337) = 138
nodeValid(120) = 1
edgeStart(120) = 338
edgeCount(120) = 3
edgeTo(338) = 119
edgeTo(339) = 121
edgeTo(340) = 138
nodeValid(121) = 1
edgeStart(121) = 341
edgeCount(121) = 3
edgeTo(341) = 112
edgeTo(342) = 120
edgeTo(343) = 138
nodeValid(125) = 1
edgeStart(125) = 344
edgeCount(125) = 4
edgeTo(344) = 119
edgeTo(345) = 126
edgeTo(346) = 135
edgeTo(347) = 137
nodeValid(126) = 1
edgeStart(126) = 348
edgeCount(126) = 4
edgeTo(348) = 125
edgeTo(349) = 127
edgeTo(350) = 135
edgeTo(351) = 142
nodeValid(127) = 1
edgeStart(127) = 352
edgeCount(127) = 3
edgeTo(352) = 126
edgeTo(353) = 128
edgeTo(354) = 142
nodeValid(128) = 1
edgeStart(128) = 355
edgeCount(128) = 4
edgeTo(355) = 127
edgeTo(356) = 132
edgeTo(357) = 142
edgeTo(358) = 143
nodeValid(131) = 1
edgeStart(131) = 359
edgeCount(131) = 3
edgeTo(359) = 96
edgeTo(360) = 145
edgeTo(361) = 159
nodeValid(132) = 1
edgeStart(132) = 362
edgeCount(132) = 3
edgeTo(362) = 128
edgeTo(363) = 143
edgeTo(364) = 158
nodeValid(133) = 1
edgeStart(133) = 365
edgeCount(133) = 3
edgeTo(365) = 117
edgeTo(366) = 134
edgeTo(367) = 160
nodeValid(134) = 1
edgeStart(134) = 368
edgeCount(134) = 6
edgeTo(368) = 83
edgeTo(369) = 84
edgeTo(370) = 117
edgeTo(371) = 133
edgeTo(372) = 135
edgeTo(373) = 140
nodeValid(135) = 1
edgeStart(135) = 374
edgeCount(135) = 11
edgeTo(374) = 84
edgeTo(375) = 86
edgeTo(376) = 88
edgeTo(377) = 117
edgeTo(378) = 118
edgeTo(379) = 125
edgeTo(380) = 126
edgeTo(381) = 134
edgeTo(382) = 136
edgeTo(383) = 137
edgeTo(384) = 142
nodeValid(136) = 1
edgeStart(136) = 385
edgeCount(136) = 4
edgeTo(385) = 116
edgeTo(386) = 117
edgeTo(387) = 118
edgeTo(388) = 135
nodeValid(137) = 1
edgeStart(137) = 389
edgeCount(137) = 4
edgeTo(389) = 118
edgeTo(390) = 119
edgeTo(391) = 125
edgeTo(392) = 135
nodeValid(138) = 1
edgeStart(138) = 393
edgeCount(138) = 7
edgeTo(393) = 112
edgeTo(394) = 116
edgeTo(395) = 118
edgeTo(396) = 119
edgeTo(397) = 120
edgeTo(398) = 121
edgeTo(399) = 139
nodeValid(139) = 1
edgeStart(139) = 400
edgeCount(139) = 5
edgeTo(400) = 112
edgeTo(401) = 115
edgeTo(402) = 116
edgeTo(403) = 138
edgeTo(404) = 161
nodeValid(140) = 1
edgeStart(140) = 405
edgeCount(140) = 5
edgeTo(405) = 83
edgeTo(406) = 85
edgeTo(407) = 134
edgeTo(408) = 141
edgeTo(409) = 143
nodeValid(141) = 1
edgeStart(141) = 410
edgeCount(141) = 5
edgeTo(410) = 85
edgeTo(411) = 87
edgeTo(412) = 140
edgeTo(413) = 142
edgeTo(414) = 143
nodeValid(142) = 1
edgeStart(142) = 415
edgeCount(142) = 8
edgeTo(415) = 87
edgeTo(416) = 88
edgeTo(417) = 126
edgeTo(418) = 127
edgeTo(419) = 128
edgeTo(420) = 135
edgeTo(421) = 141
edgeTo(422) = 143
nodeValid(143) = 1
edgeStart(143) = 423
edgeCount(143) = 10
edgeTo(423) = 89
edgeTo(424) = 91
edgeTo(425) = 128
edgeTo(426) = 132
edgeTo(427) = 140
edgeTo(428) = 141
edgeTo(429) = 142
edgeTo(430) = 144
edgeTo(431) = 158
edgeTo(432) = 159
nodeValid(144) = 1
edgeStart(144) = 433
edgeCount(144) = 6
edgeTo(433) = 91
edgeTo(434) = 92
edgeTo(435) = 143
edgeTo(436) = 145
edgeTo(437) = 146
edgeTo(438) = 159
nodeValid(145) = 1
edgeStart(145) = 439
edgeCount(145) = 6
edgeTo(439) = 95
edgeTo(440) = 96
edgeTo(441) = 131
edgeTo(442) = 144
edgeTo(443) = 146
edgeTo(444) = 159
nodeValid(146) = 1
edgeStart(146) = 445
edgeCount(146) = 7
edgeTo(445) = 92
edgeTo(446) = 93
edgeTo(447) = 94
edgeTo(448) = 95
edgeTo(449) = 144
edgeTo(450) = 145
edgeTo(451) = 147
nodeValid(147) = 1
edgeStart(147) = 452
edgeCount(147) = 9
edgeTo(452) = 92
edgeTo(453) = 93
edgeTo(454) = 98
edgeTo(455) = 99
edgeTo(456) = 100
edgeTo(457) = 146
edgeTo(458) = 148
edgeTo(459) = 149
edgeTo(460) = 150
nodeValid(148) = 1
edgeStart(148) = 461
edgeCount(148) = 5
edgeTo(461) = 97
edgeTo(462) = 98
edgeTo(463) = 100
edgeTo(464) = 147
edgeTo(465) = 155
nodeValid(149) = 1
edgeStart(149) = 466
edgeCount(149) = 6
edgeTo(466) = 99
edgeTo(467) = 104
edgeTo(468) = 105
edgeTo(469) = 147
edgeTo(470) = 150
edgeTo(471) = 163
nodeValid(150) = 1
edgeStart(150) = 472
edgeCount(150) = 4
edgeTo(472) = 105
edgeTo(473) = 108
edgeTo(474) = 147
edgeTo(475) = 149
nodeValid(151) = 1
edgeStart(151) = 476
edgeCount(151) = 6
edgeTo(476) = 103
edgeTo(477) = 104
edgeTo(478) = 106
edgeTo(479) = 107
edgeTo(480) = 109
edgeTo(481) = 162
nodeValid(155) = 1
edgeStart(155) = 482
edgeCount(155) = 3
edgeTo(482) = 97
edgeTo(483) = 100
edgeTo(484) = 148
nodeValid(158) = 1
edgeStart(158) = 485
edgeCount(158) = 3
edgeTo(485) = 89
edgeTo(486) = 132
edgeTo(487) = 143
nodeValid(159) = 1
edgeStart(159) = 488
edgeCount(159) = 5
edgeTo(488) = 89
edgeTo(489) = 131
edgeTo(490) = 143
edgeTo(491) = 144
edgeTo(492) = 145
nodeValid(160) = 1
edgeStart(160) = 493
edgeCount(160) = 2
edgeTo(493) = 117
edgeTo(494) = 133
nodeValid(161) = 1
edgeStart(161) = 495
edgeCount(161) = 3
edgeTo(495) = 112
edgeTo(496) = 115
edgeTo(497) = 139
nodeValid(162) = 1
edgeStart(162) = 498
edgeCount(162) = 3
edgeTo(498) = 103
edgeTo(499) = 104
edgeTo(500) = 151
nodeValid(163) = 1
edgeStart(163) = 501
edgeCount(163) = 3
edgeTo(501) = 99
edgeTo(502) = 104
edgeTo(503) = 149
terrain(1) = 1
incomingStart(1) = 0
incomingCount(1) = 6
incomingNode(0) = 2
incomingNode(1) = 3
incomingNode(2) = 84
incomingNode(3) = 85
incomingNode(4) = 134
incomingNode(5) = 140
ownNodeStart(1) = 0
ownNodeCount(1) = 2
ownNode(0) = 1
ownNode(1) = 83
terrain(2) = 1
supply(2) = 1
incomingStart(2) = 6
incomingCount(2) = 7
incomingNode(6) = 1
incomingNode(7) = 3
incomingNode(8) = 4
incomingNode(9) = 83
incomingNode(10) = 86
incomingNode(11) = 134
incomingNode(12) = 135
ownNodeStart(2) = 2
ownNodeCount(2) = 2
ownNode(2) = 2
ownNode(3) = 84
terrain(3) = 1
supply(3) = 1
incomingStart(3) = 13
incomingCount(3) = 8
incomingNode(13) = 1
incomingNode(14) = 2
incomingNode(15) = 4
incomingNode(16) = 5
incomingNode(17) = 83
incomingNode(18) = 87
incomingNode(19) = 140
incomingNode(20) = 141
ownNodeStart(3) = 4
ownNodeCount(3) = 2
ownNode(4) = 3
ownNode(5) = 85
terrain(4) = 1
incomingStart(4) = 21
incomingCount(4) = 7
incomingNode(21) = 2
incomingNode(22) = 3
incomingNode(23) = 5
incomingNode(24) = 6
incomingNode(25) = 84
incomingNode(26) = 88
incomingNode(27) = 135
ownNodeStart(4) = 6
ownNodeCount(4) = 2
ownNode(6) = 4
ownNode(7) = 86
terrain(5) = 1
incomingStart(5) = 28
incomingCount(5) = 7
incomingNode(28) = 3
incomingNode(29) = 4
incomingNode(30) = 6
incomingNode(31) = 85
incomingNode(32) = 88
incomingNode(33) = 141
incomingNode(34) = 142
ownNodeStart(5) = 8
ownNodeCount(5) = 2
ownNode(8) = 5
ownNode(9) = 87
terrain(6) = 1
supply(6) = 1
incomingStart(6) = 35
incomingCount(6) = 6
incomingNode(35) = 4
incomingNode(36) = 5
incomingNode(37) = 86
incomingNode(38) = 87
incomingNode(39) = 135
incomingNode(40) = 142
ownNodeStart(6) = 10
ownNodeCount(6) = 2
ownNode(10) = 6
ownNode(11) = 88
terrain(7) = 1
supply(7) = 1
incomingStart(7) = 41
incomingCount(7) = 4
incomingNode(41) = 8
incomingNode(42) = 143
incomingNode(43) = 158
incomingNode(44) = 159
ownNodeStart(7) = 12
ownNodeCount(7) = 2
ownNode(12) = 7
ownNode(13) = 89
terrain(8) = 1
supply(8) = 1
incomingStart(8) = 45
incomingCount(8) = 9
incomingNode(45) = 7
incomingNode(46) = 49
incomingNode(47) = 50
incomingNode(48) = 89
incomingNode(49) = 131
incomingNode(50) = 132
incomingNode(51) = 143
incomingNode(52) = 144
incomingNode(53) = 145
ownNodeStart(8) = 14
ownNodeCount(8) = 3
ownNode(14) = 8
ownNode(15) = 158
ownNode(16) = 159
terrain(9) = 1
incomingStart(9) = 54
incomingCount(9) = 4
incomingNode(54) = 10
incomingNode(55) = 92
incomingNode(56) = 143
incomingNode(57) = 144
ownNodeStart(9) = 17
ownNodeCount(9) = 2
ownNode(17) = 9
ownNode(18) = 91
terrain(10) = 1
supply(10) = 1
incomingStart(10) = 58
incomingCount(10) = 5
incomingNode(58) = 9
incomingNode(59) = 91
incomingNode(60) = 144
incomingNode(61) = 146
incomingNode(62) = 147
ownNodeStart(10) = 19
ownNodeCount(10) = 2
ownNode(19) = 10
ownNode(20) = 92
terrain(11) = 1
supply(11) = 1
incomingStart(11) = 63
incomingCount(11) = 6
incomingNode(63) = 12
incomingNode(64) = 16
incomingNode(65) = 94
incomingNode(66) = 98
incomingNode(67) = 146
incomingNode(68) = 147
ownNodeStart(11) = 21
ownNodeCount(11) = 2
ownNode(21) = 11
ownNode(22) = 93
terrain(12) = 1
supply(12) = 1
incomingStart(12) = 69
incomingCount(12) = 7
incomingNode(69) = 11
incomingNode(70) = 13
incomingNode(71) = 15
incomingNode(72) = 16
incomingNode(73) = 93
incomingNode(74) = 95
incomingNode(75) = 146
ownNodeStart(12) = 23
ownNodeCount(12) = 2
ownNode(23) = 12
ownNode(24) = 94
terrain(13) = 1
incomingStart(13) = 76
incomingCount(13) = 7
incomingNode(76) = 12
incomingNode(77) = 14
incomingNode(78) = 15
incomingNode(79) = 94
incomingNode(80) = 96
incomingNode(81) = 145
incomingNode(82) = 146
ownNodeStart(13) = 25
ownNodeCount(13) = 2
ownNode(25) = 13
ownNode(26) = 95
terrain(14) = 1
incomingStart(14) = 83
incomingCount(14) = 7
incomingNode(83) = 13
incomingNode(84) = 15
incomingNode(85) = 49
incomingNode(86) = 70
incomingNode(87) = 95
incomingNode(88) = 131
incomingNode(89) = 145
ownNodeStart(14) = 27
ownNodeCount(14) = 2
ownNode(27) = 14
ownNode(28) = 96
terrain(15) = 1
supply(15) = 1
incomingStart(15) = 90
incomingCount(15) = 9
incomingNode(90) = 12
incomingNode(91) = 13
incomingNode(92) = 14
incomingNode(93) = 16
incomingNode(94) = 70
incomingNode(95) = 73
incomingNode(96) = 98
incomingNode(97) = 148
incomingNode(98) = 155
ownNodeStart(15) = 29
ownNodeCount(15) = 2
ownNode(29) = 15
ownNode(30) = 97
terrain(16) = 1
incomingStart(16) = 99
incomingCount(16) = 7
incomingNode(99) = 11
incomingNode(100) = 12
incomingNode(101) = 15
incomingNode(102) = 93
incomingNode(103) = 97
incomingNode(104) = 147
incomingNode(105) = 148
ownNodeStart(16) = 31
ownNodeCount(16) = 2
ownNode(31) = 16
ownNode(32) = 98
terrain(17) = 1
supply(17) = 1
incomingStart(17) = 106
incomingCount(17) = 7
incomingNode(106) = 18
incomingNode(107) = 19
incomingNode(108) = 20
incomingNode(109) = 100
incomingNode(110) = 147
incomingNode(111) = 149
incomingNode(112) = 163
ownNodeStart(17) = 33
ownNodeCount(17) = 2
ownNode(33) = 17
ownNode(34) = 99
terrain(18) = 1
incomingStart(18) = 113
incomingCount(18) = 7
incomingNode(113) = 17
incomingNode(114) = 19
incomingNode(115) = 73
incomingNode(116) = 99
incomingNode(117) = 147
incomingNode(118) = 148
incomingNode(119) = 155
ownNodeStart(18) = 35
ownNodeCount(18) = 2
ownNode(35) = 18
ownNode(36) = 100
terrain(19) = 0
supply(19) = 1
incomingStart(19) = 120
incomingCount(19) = 6
incomingNode(120) = 17
incomingNode(121) = 18
incomingNode(122) = 20
incomingNode(123) = 21
incomingNode(124) = 73
incomingNode(125) = 74
ownNodeStart(19) = 37
ownNodeCount(19) = 1
ownNode(37) = 19
terrain(20) = 1
supply(20) = 1
incomingStart(20) = 126
incomingCount(20) = 9
incomingNode(126) = 17
incomingNode(127) = 19
incomingNode(128) = 21
incomingNode(129) = 22
incomingNode(130) = 99
incomingNode(131) = 103
incomingNode(132) = 104
incomingNode(133) = 149
incomingNode(134) = 151
ownNodeStart(20) = 38
ownNodeCount(20) = 3
ownNode(38) = 20
ownNode(39) = 162
ownNode(40) = 163
terrain(21) = 1
supply(21) = 1
incomingStart(21) = 135
incomingCount(21) = 9
incomingNode(135) = 19
incomingNode(136) = 20
incomingNode(137) = 27
incomingNode(138) = 28
incomingNode(139) = 74
incomingNode(140) = 75
incomingNode(141) = 109
incomingNode(142) = 151
incomingNode(143) = 162
ownNodeStart(21) = 41
ownNodeCount(21) = 2
ownNode(41) = 21
ownNode(42) = 103
terrain(22) = 1
supply(22) = 1
incomingStart(22) = 144
incomingCount(22) = 9
incomingNode(144) = 20
incomingNode(145) = 23
incomingNode(146) = 24
incomingNode(147) = 105
incomingNode(148) = 106
incomingNode(149) = 149
incomingNode(150) = 151
incomingNode(151) = 162
incomingNode(152) = 163
ownNodeStart(22) = 43
ownNodeCount(22) = 2
ownNode(43) = 22
ownNode(44) = 104
terrain(23) = 1
supply(23) = 1
incomingStart(23) = 153
incomingCount(23) = 8
incomingNode(153) = 22
incomingNode(154) = 24
incomingNode(155) = 25
incomingNode(156) = 26
incomingNode(157) = 104
incomingNode(158) = 108
incomingNode(159) = 149
incomingNode(160) = 150
ownNodeStart(23) = 45
ownNodeCount(23) = 2
ownNode(45) = 23
ownNode(46) = 105
terrain(24) = 1
supply(24) = 1
incomingStart(24) = 161
incomingCount(24) = 6
incomingNode(161) = 22
incomingNode(162) = 23
incomingNode(163) = 25
incomingNode(164) = 104
incomingNode(165) = 107
incomingNode(166) = 151
ownNodeStart(24) = 47
ownNodeCount(24) = 2
ownNode(47) = 24
ownNode(48) = 106
terrain(25) = 1
incomingStart(25) = 167
incomingCount(25) = 7
incomingNode(167) = 23
incomingNode(168) = 24
incomingNode(169) = 26
incomingNode(170) = 27
incomingNode(171) = 106
incomingNode(172) = 109
incomingNode(173) = 151
ownNodeStart(25) = 49
ownNodeCount(25) = 2
ownNode(49) = 25
ownNode(50) = 107
terrain(26) = 1
incomingStart(26) = 174
incomingCount(26) = 4
incomingNode(174) = 23
incomingNode(175) = 25
incomingNode(176) = 105
incomingNode(177) = 150
ownNodeStart(26) = 51
ownNodeCount(26) = 2
ownNode(51) = 26
ownNode(52) = 108
terrain(27) = 1
supply(27) = 1
incomingStart(27) = 178
incomingCount(27) = 7
incomingNode(178) = 21
incomingNode(179) = 25
incomingNode(180) = 28
incomingNode(181) = 31
incomingNode(182) = 103
incomingNode(183) = 107
incomingNode(184) = 151
ownNodeStart(27) = 53
ownNodeCount(27) = 2
ownNode(53) = 27
ownNode(54) = 109
terrain(28) = 0
incomingStart(28) = 185
incomingCount(28) = 5
incomingNode(185) = 21
incomingNode(186) = 27
incomingNode(187) = 29
incomingNode(188) = 31
incomingNode(189) = 75
ownNodeStart(28) = 55
ownNodeCount(28) = 1
ownNode(55) = 28
terrain(29) = 0
supply(29) = 1
incomingStart(29) = 190
incomingCount(29) = 6
incomingNode(190) = 28
incomingNode(191) = 30
incomingNode(192) = 31
incomingNode(193) = 39
incomingNode(194) = 40
incomingNode(195) = 75
ownNodeStart(29) = 56
ownNodeCount(29) = 1
ownNode(56) = 29
terrain(30) = 1
incomingStart(30) = 196
incomingCount(30) = 8
incomingNode(196) = 29
incomingNode(197) = 31
incomingNode(198) = 32
incomingNode(199) = 39
incomingNode(200) = 121
incomingNode(201) = 138
incomingNode(202) = 139
incomingNode(203) = 161
ownNodeStart(30) = 57
ownNodeCount(30) = 2
ownNode(57) = 30
ownNode(58) = 112
terrain(31) = 0
supply(31) = 1
incomingStart(31) = 204
incomingCount(31) = 5
incomingNode(204) = 27
incomingNode(205) = 28
incomingNode(206) = 29
incomingNode(207) = 30
incomingNode(208) = 32
ownNodeStart(31) = 59
ownNodeCount(31) = 1
ownNode(59) = 31
terrain(32) = 1
supply(32) = 1
incomingStart(32) = 209
incomingCount(32) = 9
incomingNode(209) = 30
incomingNode(210) = 31
incomingNode(211) = 33
incomingNode(212) = 35
incomingNode(213) = 112
incomingNode(214) = 115
incomingNode(215) = 117
incomingNode(216) = 133
incomingNode(217) = 139
ownNodeStart(32) = 60
ownNodeCount(32) = 3
ownNode(60) = 32
ownNode(61) = 160
ownNode(62) = 161
terrain(33) = 1
incomingStart(33) = 218
incomingCount(33) = 6
incomingNode(218) = 32
incomingNode(219) = 34
incomingNode(220) = 35
incomingNode(221) = 116
incomingNode(222) = 139
incomingNode(223) = 161
ownNodeStart(33) = 63
ownNodeCount(33) = 2
ownNode(63) = 33
ownNode(64) = 115
terrain(34) = 1
supply(34) = 1
incomingStart(34) = 224
incomingCount(34) = 9
incomingNode(224) = 33
incomingNode(225) = 35
incomingNode(226) = 36
incomingNode(227) = 115
incomingNode(228) = 117
incomingNode(229) = 118
incomingNode(230) = 136
incomingNode(231) = 138
incomingNode(232) = 139
ownNodeStart(34) = 65
ownNodeCount(34) = 2
ownNode(65) = 34
ownNode(66) = 116
terrain(35) = 1
supply(35) = 1
incomingStart(35) = 233
incomingCount(35) = 9
incomingNode(233) = 32
incomingNode(234) = 33
incomingNode(235) = 34
incomingNode(236) = 116
incomingNode(237) = 133
incomingNode(238) = 134
incomingNode(239) = 135
incomingNode(240) = 136
incomingNode(241) = 160
ownNodeStart(35) = 67
ownNodeCount(35) = 2
ownNode(67) = 35
ownNode(68) = 117
terrain(36) = 1
supply(36) = 1
incomingStart(36) = 242
incomingCount(36) = 8
incomingNode(242) = 34
incomingNode(243) = 37
incomingNode(244) = 116
incomingNode(245) = 119
incomingNode(246) = 135
incomingNode(247) = 136
incomingNode(248) = 137
incomingNode(249) = 138
ownNodeStart(36) = 69
ownNodeCount(36) = 2
ownNode(69) = 36
ownNode(70) = 118
terrain(37) = 1
supply(37) = 1
incomingStart(37) = 250
incomingCount(37) = 10
incomingNode(250) = 36
incomingNode(251) = 38
incomingNode(252) = 41
incomingNode(253) = 42
incomingNode(254) = 43
incomingNode(255) = 118
incomingNode(256) = 120
incomingNode(257) = 125
incomingNode(258) = 137
incomingNode(259) = 138
ownNodeStart(37) = 71
ownNodeCount(37) = 2
ownNode(71) = 37
ownNode(72) = 119
terrain(38) = 1
supply(38) = 1
incomingStart(38) = 260
incomingCount(38) = 7
incomingNode(260) = 37
incomingNode(261) = 39
incomingNode(262) = 40
incomingNode(263) = 41
incomingNode(264) = 119
incomingNode(265) = 121
incomingNode(266) = 138
ownNodeStart(38) = 73
ownNodeCount(38) = 2
ownNode(73) = 38
ownNode(74) = 120
terrain(39) = 1
incomingStart(39) = 267
incomingCount(39) = 7
incomingNode(267) = 29
incomingNode(268) = 30
incomingNode(269) = 38
incomingNode(270) = 40
incomingNode(271) = 112
incomingNode(272) = 120
incomingNode(273) = 138
ownNodeStart(39) = 75
ownNodeCount(39) = 2
ownNode(75) = 39
ownNode(76) = 121
terrain(40) = 0
incomingStart(40) = 274
incomingCount(40) = 6
incomingNode(274) = 29
incomingNode(275) = 38
incomingNode(276) = 39
incomingNode(277) = 41
incomingNode(278) = 71
incomingNode(279) = 75
ownNodeStart(40) = 77
ownNodeCount(40) = 1
ownNode(77) = 40
terrain(41) = 0
supply(41) = 1
incomingStart(41) = 280
incomingCount(41) = 7
incomingNode(280) = 37
incomingNode(281) = 38
incomingNode(282) = 40
incomingNode(283) = 42
incomingNode(284) = 48
incomingNode(285) = 70
incomingNode(286) = 71
ownNodeStart(41) = 78
ownNodeCount(41) = 1
ownNode(78) = 41
terrain(42) = 0
incomingStart(42) = 287
incomingCount(42) = 5
incomingNode(287) = 37
incomingNode(288) = 41
incomingNode(289) = 43
incomingNode(290) = 44
incomingNode(291) = 48
ownNodeStart(42) = 79
ownNodeCount(42) = 1
ownNode(79) = 42
terrain(43) = 1
supply(43) = 1
incomingStart(43) = 292
incomingCount(43) = 7
incomingNode(292) = 37
incomingNode(293) = 42
incomingNode(294) = 44
incomingNode(295) = 119
incomingNode(296) = 126
incomingNode(297) = 135
incomingNode(298) = 137
ownNodeStart(43) = 80
ownNodeCount(43) = 2
ownNode(80) = 43
ownNode(81) = 125
terrain(44) = 1
supply(44) = 1
incomingStart(44) = 299
incomingCount(44) = 8
incomingNode(299) = 42
incomingNode(300) = 43
incomingNode(301) = 45
incomingNode(302) = 48
incomingNode(303) = 125
incomingNode(304) = 127
incomingNode(305) = 135
incomingNode(306) = 142
ownNodeStart(44) = 82
ownNodeCount(44) = 2
ownNode(82) = 44
ownNode(83) = 126
terrain(45) = 1
incomingStart(45) = 307
incomingCount(45) = 7
incomingNode(307) = 44
incomingNode(308) = 46
incomingNode(309) = 47
incomingNode(310) = 48
incomingNode(311) = 126
incomingNode(312) = 128
incomingNode(313) = 142
ownNodeStart(45) = 84
ownNodeCount(45) = 2
ownNode(84) = 45
ownNode(85) = 127
terrain(46) = 1
supply(46) = 1
incomingStart(46) = 314
incomingCount(46) = 7
incomingNode(314) = 45
incomingNode(315) = 47
incomingNode(316) = 50
incomingNode(317) = 127
incomingNode(318) = 132
incomingNode(319) = 142
incomingNode(320) = 143
ownNodeStart(46) = 86
ownNodeCount(46) = 2
ownNode(86) = 46
ownNode(87) = 128
terrain(47) = 0
supply(47) = 1
incomingStart(47) = 321
incomingCount(47) = 4
incomingNode(321) = 45
incomingNode(322) = 46
incomingNode(323) = 48
incomingNode(324) = 50
ownNodeStart(47) = 88
ownNodeCount(47) = 1
ownNode(88) = 47
terrain(48) = 0
incomingStart(48) = 325
incomingCount(48) = 7
incomingNode(325) = 41
incomingNode(326) = 42
incomingNode(327) = 44
incomingNode(328) = 45
incomingNode(329) = 47
incomingNode(330) = 49
incomingNode(331) = 50
ownNodeStart(48) = 89
ownNodeCount(48) = 1
ownNode(89) = 48
terrain(49) = 1
supply(49) = 1
incomingStart(49) = 332
incomingCount(49) = 7
incomingNode(332) = 8
incomingNode(333) = 14
incomingNode(334) = 48
incomingNode(335) = 50
incomingNode(336) = 96
incomingNode(337) = 145
incomingNode(338) = 159
ownNodeStart(49) = 90
ownNodeCount(49) = 2
ownNode(90) = 49
ownNode(91) = 131
terrain(50) = 1
incomingStart(50) = 339
incomingCount(50) = 8
incomingNode(339) = 8
incomingNode(340) = 46
incomingNode(341) = 47
incomingNode(342) = 48
incomingNode(343) = 49
incomingNode(344) = 128
incomingNode(345) = 143
incomingNode(346) = 158
ownNodeStart(50) = 92
ownNodeCount(50) = 2
ownNode(92) = 50
ownNode(93) = 132
terrain(51) = 2
incomingStart(51) = 347
incomingCount(51) = 3
incomingNode(347) = 117
incomingNode(348) = 134
incomingNode(349) = 160
ownNodeStart(51) = 94
ownNodeCount(51) = 1
ownNode(94) = 133
terrain(52) = 2
incomingStart(52) = 350
incomingCount(52) = 6
incomingNode(350) = 83
incomingNode(351) = 84
incomingNode(352) = 117
incomingNode(353) = 133
incomingNode(354) = 135
incomingNode(355) = 140
ownNodeStart(52) = 95
ownNodeCount(52) = 1
ownNode(95) = 134
terrain(53) = 2
incomingStart(53) = 356
incomingCount(53) = 11
incomingNode(356) = 84
incomingNode(357) = 86
incomingNode(358) = 88
incomingNode(359) = 117
incomingNode(360) = 118
incomingNode(361) = 125
incomingNode(362) = 126
incomingNode(363) = 134
incomingNode(364) = 136
incomingNode(365) = 137
incomingNode(366) = 142
ownNodeStart(53) = 96
ownNodeCount(53) = 1
ownNode(96) = 135
terrain(54) = 2
incomingStart(54) = 367
incomingCount(54) = 4
incomingNode(367) = 116
incomingNode(368) = 117
incomingNode(369) = 118
incomingNode(370) = 135
ownNodeStart(54) = 97
ownNodeCount(54) = 1
ownNode(97) = 136
terrain(55) = 2
incomingStart(55) = 371
incomingCount(55) = 4
incomingNode(371) = 118
incomingNode(372) = 119
incomingNode(373) = 125
incomingNode(374) = 135
ownNodeStart(55) = 98
ownNodeCount(55) = 1
ownNode(98) = 137
terrain(56) = 2
incomingStart(56) = 375
incomingCount(56) = 7
incomingNode(375) = 112
incomingNode(376) = 116
incomingNode(377) = 118
incomingNode(378) = 119
incomingNode(379) = 120
incomingNode(380) = 121
incomingNode(381) = 139
ownNodeStart(56) = 99
ownNodeCount(56) = 1
ownNode(99) = 138
terrain(57) = 2
incomingStart(57) = 382
incomingCount(57) = 5
incomingNode(382) = 112
incomingNode(383) = 115
incomingNode(384) = 116
incomingNode(385) = 138
incomingNode(386) = 161
ownNodeStart(57) = 100
ownNodeCount(57) = 1
ownNode(100) = 139
terrain(58) = 2
incomingStart(58) = 387
incomingCount(58) = 5
incomingNode(387) = 83
incomingNode(388) = 85
incomingNode(389) = 134
incomingNode(390) = 141
incomingNode(391) = 143
ownNodeStart(58) = 101
ownNodeCount(58) = 1
ownNode(101) = 140
terrain(59) = 2
incomingStart(59) = 392
incomingCount(59) = 5
incomingNode(392) = 85
incomingNode(393) = 87
incomingNode(394) = 140
incomingNode(395) = 142
incomingNode(396) = 143
ownNodeStart(59) = 102
ownNodeCount(59) = 1
ownNode(102) = 141
terrain(60) = 2
incomingStart(60) = 397
incomingCount(60) = 8
incomingNode(397) = 87
incomingNode(398) = 88
incomingNode(399) = 126
incomingNode(400) = 127
incomingNode(401) = 128
incomingNode(402) = 135
incomingNode(403) = 141
incomingNode(404) = 143
ownNodeStart(60) = 103
ownNodeCount(60) = 1
ownNode(103) = 142
terrain(61) = 2
incomingStart(61) = 405
incomingCount(61) = 10
incomingNode(405) = 89
incomingNode(406) = 91
incomingNode(407) = 128
incomingNode(408) = 132
incomingNode(409) = 140
incomingNode(410) = 141
incomingNode(411) = 142
incomingNode(412) = 144
incomingNode(413) = 158
incomingNode(414) = 159
ownNodeStart(61) = 104
ownNodeCount(61) = 1
ownNode(104) = 143
terrain(62) = 2
incomingStart(62) = 415
incomingCount(62) = 6
incomingNode(415) = 91
incomingNode(416) = 92
incomingNode(417) = 143
incomingNode(418) = 145
incomingNode(419) = 146
incomingNode(420) = 159
ownNodeStart(62) = 105
ownNodeCount(62) = 1
ownNode(105) = 144
terrain(63) = 2
incomingStart(63) = 421
incomingCount(63) = 6
incomingNode(421) = 95
incomingNode(422) = 96
incomingNode(423) = 131
incomingNode(424) = 144
incomingNode(425) = 146
incomingNode(426) = 159
ownNodeStart(63) = 106
ownNodeCount(63) = 1
ownNode(106) = 145
terrain(64) = 2
incomingStart(64) = 427
incomingCount(64) = 7
incomingNode(427) = 92
incomingNode(428) = 93
incomingNode(429) = 94
incomingNode(430) = 95
incomingNode(431) = 144
incomingNode(432) = 145
incomingNode(433) = 147
ownNodeStart(64) = 107
ownNodeCount(64) = 1
ownNode(107) = 146
terrain(65) = 2
incomingStart(65) = 434
incomingCount(65) = 9
incomingNode(434) = 92
incomingNode(435) = 93
incomingNode(436) = 98
incomingNode(437) = 99
incomingNode(438) = 100
incomingNode(439) = 146
incomingNode(440) = 148
incomingNode(441) = 149
incomingNode(442) = 150
ownNodeStart(65) = 108
ownNodeCount(65) = 1
ownNode(108) = 147
terrain(66) = 2
incomingStart(66) = 443
incomingCount(66) = 5
incomingNode(443) = 97
incomingNode(444) = 98
incomingNode(445) = 100
incomingNode(446) = 147
incomingNode(447) = 155
ownNodeStart(66) = 109
ownNodeCount(66) = 1
ownNode(109) = 148
terrain(67) = 2
incomingStart(67) = 448
incomingCount(67) = 6
incomingNode(448) = 99
incomingNode(449) = 104
incomingNode(450) = 105
incomingNode(451) = 147
incomingNode(452) = 150
incomingNode(453) = 163
ownNodeStart(67) = 110
ownNodeCount(67) = 1
ownNode(110) = 149
terrain(68) = 2
incomingStart(68) = 454
incomingCount(68) = 4
incomingNode(454) = 105
incomingNode(455) = 108
incomingNode(456) = 147
incomingNode(457) = 149
ownNodeStart(68) = 111
ownNodeCount(68) = 1
ownNode(111) = 150
terrain(69) = 2
incomingStart(69) = 458
incomingCount(69) = 6
incomingNode(458) = 103
incomingNode(459) = 104
incomingNode(460) = 106
incomingNode(461) = 107
incomingNode(462) = 109
incomingNode(463) = 162
ownNodeStart(69) = 112
ownNodeCount(69) = 1
ownNode(112) = 151
terrain(70) = 0
incomingStart(70) = 464
incomingCount(70) = 6
incomingNode(464) = 14
incomingNode(465) = 15
incomingNode(466) = 41
incomingNode(467) = 71
incomingNode(468) = 72
incomingNode(469) = 73
ownNodeStart(70) = 113
ownNodeCount(70) = 1
ownNode(113) = 70
terrain(71) = 0
incomingStart(71) = 470
incomingCount(71) = 5
incomingNode(470) = 40
incomingNode(471) = 41
incomingNode(472) = 70
incomingNode(473) = 72
incomingNode(474) = 75
ownNodeStart(71) = 114
ownNodeCount(71) = 1
ownNode(114) = 71
terrain(72) = 0
supply(72) = 1
incomingStart(72) = 475
incomingCount(72) = 5
incomingNode(475) = 70
incomingNode(476) = 71
incomingNode(477) = 73
incomingNode(478) = 74
incomingNode(479) = 75
ownNodeStart(72) = 115
ownNodeCount(72) = 1
ownNode(115) = 72
terrain(73) = 1
supply(73) = 1
incomingStart(73) = 480
incomingCount(73) = 9
incomingNode(480) = 15
incomingNode(481) = 18
incomingNode(482) = 19
incomingNode(483) = 70
incomingNode(484) = 72
incomingNode(485) = 74
incomingNode(486) = 97
incomingNode(487) = 100
incomingNode(488) = 148
ownNodeStart(73) = 116
ownNodeCount(73) = 2
ownNode(116) = 73
ownNode(117) = 155
terrain(74) = 0
supply(74) = 1
incomingStart(74) = 489
incomingCount(74) = 5
incomingNode(489) = 19
incomingNode(490) = 21
incomingNode(491) = 72
incomingNode(492) = 73
incomingNode(493) = 75
ownNodeStart(74) = 118
ownNodeCount(74) = 1
ownNode(118) = 74
terrain(75) = 0
incomingStart(75) = 494
incomingCount(75) = 7
incomingNode(494) = 21
incomingNode(495) = 28
incomingNode(496) = 29
incomingNode(497) = 40
incomingNode(498) = 71
incomingNode(499) = 72
incomingNode(500) = 74
ownNodeStart(75) = 119
ownNodeCount(75) = 1
ownNode(119) = 75
terrain(76) = 1
incomingStart(76) = 501
incomingCount(76) = 0
ownNodeStart(76) = 120
ownNodeCount(76) = 0
terrain(77) = 1
incomingStart(77) = 501
incomingCount(77) = 0
ownNodeStart(77) = 120
ownNodeCount(77) = 0
terrain(78) = 1
incomingStart(78) = 501
incomingCount(78) = 0
ownNodeStart(78) = 120
ownNodeCount(78) = 0
terrain(79) = 1
incomingStart(79) = 501
incomingCount(79) = 0
ownNodeStart(79) = 120
ownNodeCount(79) = 0
terrain(80) = 1
incomingStart(80) = 501
incomingCount(80) = 0
ownNodeStart(80) = 120
ownNodeCount(80) = 0
terrain(81) = 1
incomingStart(81) = 501
incomingCount(81) = 0
ownNodeStart(81) = 120
ownNodeCount(81) = 0
mapReady = 1
end if
' Parameters of the deterministic instruction-bounded search.
searchSamples = 8
searchSeeds = 12
searchPasses = 6
searchEvaluations = 1000000
riskWeight = 0
scWeight = 10
posWeight = 1
lostWeight = 3
dim values(1311)
dim vmax(7)
dim prox(163)
dim proxNext(81)
dim reach(655)
dim strength(81)
dim competition(81)
dim defense(81)
dim sizes(7)
dim owner(81)
dim atUnit(81)
dim os(63)
dim oc(63)
dim ok(8191)
dim ot(8191)
dim of(8191)
dim ov(8191)
dim hostChoice(8191)
dim holdOption(63)
dim greedyStart(63)
dim greedyCount(63)
' Each of 64 units has one hold plus at most 11 direct walks, at most 768.
dim greedyOptions(1023)
dim choose(63)
dim best(63)
dim trial(63)
dim sampled(1151)
dim rawContext(1023)
dim ownSeedPlans(767)
dim modelCompetent(127)
dim modelPlan(63)
dim modelMissed(63)
dim modelLost(63)
foreignPolishEnabled = 1
dim orderQueue(63)
dim assigned(63)
dim waiting(4095)
dim deferred(63)
dim ranked(81)
dim rankValue(81)
dim reserved(81)
dim simKind(63)
dim simTo(63)
dim simFrom(63)
dim simRawTo(63)
dim simState(63)
dim simResult(63)
dim moved(63)
dim dislodged(63)
dim supportHoldHead(63)
dim supportMoveHead(63)
dim supportNext(63)
dim deps(255)
dim occupiedAfter(81)
dim counts(7)
dim provinceValue(655)
dim provinceEdgeStart(81)
dim provinceEdgeCount(81)
dim provinceEdgeSource(1000)
dim provinceEdgeWeight(1000)
if provinceGraphReady = 0 then
provinceEdgeStart(1) = 0
provinceEdgeCount(1) = 4
provinceEdgeSource(0) = 2
provinceEdgeWeight(0) = 2
provinceEdgeSource(1) = 3
provinceEdgeWeight(1) = 2
provinceEdgeSource(2) = 52
provinceEdgeWeight(2) = 1
provinceEdgeSource(3) = 58
provinceEdgeWeight(3) = 1
provinceEdgeStart(2) = 4
provinceEdgeCount(2) = 5
provinceEdgeSource(4) = 1
provinceEdgeWeight(4) = 2
provinceEdgeSource(5) = 3
provinceEdgeWeight(5) = 1
provinceEdgeSource(6) = 4
provinceEdgeWeight(6) = 2
provinceEdgeSource(7) = 52
provinceEdgeWeight(7) = 1
provinceEdgeSource(8) = 53
provinceEdgeWeight(8) = 1
provinceEdgeStart(3) = 9
provinceEdgeCount(3) = 6
provinceEdgeSource(9) = 1
provinceEdgeWeight(9) = 2
provinceEdgeSource(10) = 2
provinceEdgeWeight(10) = 1
provinceEdgeSource(11) = 4
provinceEdgeWeight(11) = 1
provinceEdgeSource(12) = 5
provinceEdgeWeight(12) = 2
provinceEdgeSource(13) = 58
provinceEdgeWeight(13) = 1
provinceEdgeSource(14) = 59
provinceEdgeWeight(14) = 1
provinceEdgeStart(4) = 15
provinceEdgeCount(4) = 5
provinceEdgeSource(15) = 2
provinceEdgeWeight(15) = 2
provinceEdgeSource(16) = 3
provinceEdgeWeight(16) = 1
provinceEdgeSource(17) = 5
provinceEdgeWeight(17) = 1
provinceEdgeSource(18) = 6
provinceEdgeWeight(18) = 2
provinceEdgeSource(19) = 53
provinceEdgeWeight(19) = 1
provinceEdgeStart(5) = 20
provinceEdgeCount(5) = 5
provinceEdgeSource(20) = 3
provinceEdgeWeight(20) = 2
provinceEdgeSource(21) = 4
provinceEdgeWeight(21) = 1
provinceEdgeSource(22) = 6
provinceEdgeWeight(22) = 2
provinceEdgeSource(23) = 59
provinceEdgeWeight(23) = 1
provinceEdgeSource(24) = 60
provinceEdgeWeight(24) = 1
provinceEdgeStart(6) = 25
provinceEdgeCount(6) = 4
provinceEdgeSource(25) = 4
provinceEdgeWeight(25) = 2
provinceEdgeSource(26) = 5
provinceEdgeWeight(26) = 2
provinceEdgeSource(27) = 53
provinceEdgeWeight(27) = 1
provinceEdgeSource(28) = 60
provinceEdgeWeight(28) = 1
provinceEdgeStart(7) = 29
provinceEdgeCount(7) = 2
provinceEdgeSource(29) = 8
provinceEdgeWeight(29) = 3
provinceEdgeSource(30) = 61
provinceEdgeWeight(30) = 1
provinceEdgeStart(8) = 31
provinceEdgeCount(8) = 6
provinceEdgeSource(31) = 7
provinceEdgeWeight(31) = 2
provinceEdgeSource(32) = 49
provinceEdgeWeight(32) = 2
provinceEdgeSource(33) = 50
provinceEdgeWeight(33) = 2
provinceEdgeSource(34) = 61
provinceEdgeWeight(34) = 1
provinceEdgeSource(35) = 62
provinceEdgeWeight(35) = 1
provinceEdgeSource(36) = 63
provinceEdgeWeight(36) = 1
provinceEdgeStart(9) = 37
provinceEdgeCount(9) = 3
provinceEdgeSource(37) = 10
provinceEdgeWeight(37) = 2
provinceEdgeSource(38) = 61
provinceEdgeWeight(38) = 1
provinceEdgeSource(39) = 62
provinceEdgeWeight(39) = 1
provinceEdgeStart(10) = 40
provinceEdgeCount(10) = 4
provinceEdgeSource(40) = 9
provinceEdgeWeight(40) = 2
provinceEdgeSource(41) = 62
provinceEdgeWeight(41) = 1
provinceEdgeSource(42) = 64
provinceEdgeWeight(42) = 1
provinceEdgeSource(43) = 65
provinceEdgeWeight(43) = 1
provinceEdgeStart(11) = 44
provinceEdgeCount(11) = 4
provinceEdgeSource(44) = 12
provinceEdgeWeight(44) = 2
provinceEdgeSource(45) = 16
provinceEdgeWeight(45) = 2
provinceEdgeSource(46) = 64
provinceEdgeWeight(46) = 1
provinceEdgeSource(47) = 65
provinceEdgeWeight(47) = 1
provinceEdgeStart(12) = 48
provinceEdgeCount(12) = 5
provinceEdgeSource(48) = 11
provinceEdgeWeight(48) = 2
provinceEdgeSource(49) = 13
provinceEdgeWeight(49) = 2
provinceEdgeSource(50) = 15
provinceEdgeWeight(50) = 1
provinceEdgeSource(51) = 16
provinceEdgeWeight(51) = 1
provinceEdgeSource(52) = 64
provinceEdgeWeight(52) = 1
provinceEdgeStart(13) = 53
provinceEdgeCount(13) = 5
provinceEdgeSource(53) = 12
provinceEdgeWeight(53) = 2
provinceEdgeSource(54) = 14
provinceEdgeWeight(54) = 2
provinceEdgeSource(55) = 15
provinceEdgeWeight(55) = 1
provinceEdgeSource(56) = 63
provinceEdgeWeight(56) = 1
provinceEdgeSource(57) = 64
provinceEdgeWeight(57) = 1
provinceEdgeStart(14) = 58
provinceEdgeCount(14) = 5
provinceEdgeSource(58) = 13
provinceEdgeWeight(58) = 2
provinceEdgeSource(59) = 15
provinceEdgeWeight(59) = 1
provinceEdgeSource(60) = 49
provinceEdgeWeight(60) = 2
provinceEdgeSource(61) = 63
provinceEdgeWeight(61) = 1
provinceEdgeSource(62) = 70
provinceEdgeWeight(62) = 1
provinceEdgeStart(15) = 63
provinceEdgeCount(15) = 7
provinceEdgeSource(63) = 12
provinceEdgeWeight(63) = 1
provinceEdgeSource(64) = 13
provinceEdgeWeight(64) = 1
provinceEdgeSource(65) = 14
provinceEdgeWeight(65) = 1
provinceEdgeSource(66) = 16
provinceEdgeWeight(66) = 2
provinceEdgeSource(67) = 66
provinceEdgeWeight(67) = 1
provinceEdgeSource(68) = 70
provinceEdgeWeight(68) = 1
provinceEdgeSource(69) = 73
provinceEdgeWeight(69) = 2
provinceEdgeStart(16) = 70
provinceEdgeCount(16) = 5
provinceEdgeSource(70) = 11
provinceEdgeWeight(70) = 2
provinceEdgeSource(71) = 12
provinceEdgeWeight(71) = 1
provinceEdgeSource(72) = 15
provinceEdgeWeight(72) = 2
provinceEdgeSource(73) = 65
provinceEdgeWeight(73) = 1
provinceEdgeSource(74) = 66
provinceEdgeWeight(74) = 1
provinceEdgeStart(17) = 75
provinceEdgeCount(17) = 5
provinceEdgeSource(75) = 18
provinceEdgeWeight(75) = 2
provinceEdgeSource(76) = 19
provinceEdgeWeight(76) = 1
provinceEdgeSource(77) = 20
provinceEdgeWeight(77) = 2
provinceEdgeSource(78) = 65
provinceEdgeWeight(78) = 1
provinceEdgeSource(79) = 67
provinceEdgeWeight(79) = 1
provinceEdgeStart(18) = 80
provinceEdgeCount(18) = 5
provinceEdgeSource(80) = 17
provinceEdgeWeight(80) = 2
provinceEdgeSource(81) = 19
provinceEdgeWeight(81) = 1
provinceEdgeSource(82) = 65
provinceEdgeWeight(82) = 1
provinceEdgeSource(83) = 66
provinceEdgeWeight(83) = 1
provinceEdgeSource(84) = 73
provinceEdgeWeight(84) = 2
provinceEdgeStart(19) = 85
provinceEdgeCount(19) = 6
provinceEdgeSource(85) = 17
provinceEdgeWeight(85) = 1
provinceEdgeSource(86) = 18
provinceEdgeWeight(86) = 1
provinceEdgeSource(87) = 20
provinceEdgeWeight(87) = 1
provinceEdgeSource(88) = 21
provinceEdgeWeight(88) = 1
provinceEdgeSource(89) = 73
provinceEdgeWeight(89) = 1
provinceEdgeSource(90) = 74
provinceEdgeWeight(90) = 1
provinceEdgeStart(20) = 91
provinceEdgeCount(20) = 6
provinceEdgeSource(91) = 17
provinceEdgeWeight(91) = 2
provinceEdgeSource(92) = 19
provinceEdgeWeight(92) = 1
provinceEdgeSource(93) = 21
provinceEdgeWeight(93) = 2
provinceEdgeSource(94) = 22
provinceEdgeWeight(94) = 2
provinceEdgeSource(95) = 67
provinceEdgeWeight(95) = 1
provinceEdgeSource(96) = 69
provinceEdgeWeight(96) = 1
provinceEdgeStart(21) = 97
provinceEdgeCount(21) = 7
provinceEdgeSource(97) = 19
provinceEdgeWeight(97) = 1
provinceEdgeSource(98) = 20
provinceEdgeWeight(98) = 2
provinceEdgeSource(99) = 27
provinceEdgeWeight(99) = 2
provinceEdgeSource(100) = 28
provinceEdgeWeight(100) = 1
provinceEdgeSource(101) = 69
provinceEdgeWeight(101) = 1
provinceEdgeSource(102) = 74
provinceEdgeWeight(102) = 1
provinceEdgeSource(103) = 75
provinceEdgeWeight(103) = 1
provinceEdgeStart(22) = 104
provinceEdgeCount(22) = 5
provinceEdgeSource(104) = 20
provinceEdgeWeight(104) = 3
provinceEdgeSource(105) = 23
provinceEdgeWeight(105) = 2
provinceEdgeSource(106) = 24
provinceEdgeWeight(106) = 2
provinceEdgeSource(107) = 67
provinceEdgeWeight(107) = 1
provinceEdgeSource(108) = 69
provinceEdgeWeight(108) = 1
provinceEdgeStart(23) = 109
provinceEdgeCount(23) = 6
provinceEdgeSource(109) = 22
provinceEdgeWeight(109) = 2
provinceEdgeSource(110) = 24
provinceEdgeWeight(110) = 1
provinceEdgeSource(111) = 25
provinceEdgeWeight(111) = 1
provinceEdgeSource(112) = 26
provinceEdgeWeight(112) = 2
provinceEdgeSource(113) = 67
provinceEdgeWeight(113) = 1
provinceEdgeSource(114) = 68
provinceEdgeWeight(114) = 1
provinceEdgeStart(24) = 115
provinceEdgeCount(24) = 4
provinceEdgeSource(115) = 22
provinceEdgeWeight(115) = 2
provinceEdgeSource(116) = 23
provinceEdgeWeight(116) = 1
provinceEdgeSource(117) = 25
provinceEdgeWeight(117) = 2
provinceEdgeSource(118) = 69
provinceEdgeWeight(118) = 1
provinceEdgeStart(25) = 119
provinceEdgeCount(25) = 5
provinceEdgeSource(119) = 23
provinceEdgeWeight(119) = 1
provinceEdgeSource(120) = 24
provinceEdgeWeight(120) = 2
provinceEdgeSource(121) = 26
provinceEdgeWeight(121) = 1
provinceEdgeSource(122) = 27
provinceEdgeWeight(122) = 2
provinceEdgeSource(123) = 69
provinceEdgeWeight(123) = 1
provinceEdgeStart(26) = 124
provinceEdgeCount(26) = 3
provinceEdgeSource(124) = 23
provinceEdgeWeight(124) = 2
provinceEdgeSource(125) = 25
provinceEdgeWeight(125) = 1
provinceEdgeSource(126) = 68
provinceEdgeWeight(126) = 1
provinceEdgeStart(27) = 127
provinceEdgeCount(27) = 5
provinceEdgeSource(127) = 21
provinceEdgeWeight(127) = 2
provinceEdgeSource(128) = 25
provinceEdgeWeight(128) = 2
provinceEdgeSource(129) = 28
provinceEdgeWeight(129) = 1
provinceEdgeSource(130) = 31
provinceEdgeWeight(130) = 1
provinceEdgeSource(131) = 69
provinceEdgeWeight(131) = 1
provinceEdgeStart(28) = 132
provinceEdgeCount(28) = 5
provinceEdgeSource(132) = 21
provinceEdgeWeight(132) = 1
provinceEdgeSource(133) = 27
provinceEdgeWeight(133) = 1
provinceEdgeSource(134) = 29
provinceEdgeWeight(134) = 1
provinceEdgeSource(135) = 31
provinceEdgeWeight(135) = 1
provinceEdgeSource(136) = 75
provinceEdgeWeight(136) = 1
provinceEdgeStart(29) = 137
provinceEdgeCount(29) = 6
provinceEdgeSource(137) = 28
provinceEdgeWeight(137) = 1
provinceEdgeSource(138) = 30
provinceEdgeWeight(138) = 1
provinceEdgeSource(139) = 31
provinceEdgeWeight(139) = 1
provinceEdgeSource(140) = 39
provinceEdgeWeight(140) = 1
provinceEdgeSource(141) = 40
provinceEdgeWeight(141) = 1
provinceEdgeSource(142) = 75
provinceEdgeWeight(142) = 1
provinceEdgeStart(30) = 143
provinceEdgeCount(30) = 6
provinceEdgeSource(143) = 29
provinceEdgeWeight(143) = 1
provinceEdgeSource(144) = 31
provinceEdgeWeight(144) = 1
provinceEdgeSource(145) = 32
provinceEdgeWeight(145) = 2
provinceEdgeSource(146) = 39
provinceEdgeWeight(146) = 2
provinceEdgeSource(147) = 56
provinceEdgeWeight(147) = 1
provinceEdgeSource(148) = 57
provinceEdgeWeight(148) = 1
provinceEdgeStart(31) = 149
provinceEdgeCount(31) = 5
provinceEdgeSource(149) = 27
provinceEdgeWeight(149) = 1
provinceEdgeSource(150) = 28
provinceEdgeWeight(150) = 1
provinceEdgeSource(151) = 29
provinceEdgeWeight(151) = 1
provinceEdgeSource(152) = 30
provinceEdgeWeight(152) = 1
provinceEdgeSource(153) = 32
provinceEdgeWeight(153) = 1
provinceEdgeStart(32) = 154
provinceEdgeCount(32) = 6
provinceEdgeSource(154) = 30
provinceEdgeWeight(154) = 2
provinceEdgeSource(155) = 31
provinceEdgeWeight(155) = 1
provinceEdgeSource(156) = 33
provinceEdgeWeight(156) = 2
provinceEdgeSource(157) = 35
provinceEdgeWeight(157) = 2
provinceEdgeSource(158) = 51
provinceEdgeWeight(158) = 1
provinceEdgeSource(159) = 57
provinceEdgeWeight(159) = 1
provinceEdgeStart(33) = 160
provinceEdgeCount(33) = 4
provinceEdgeSource(160) = 32
provinceEdgeWeight(160) = 2
provinceEdgeSource(161) = 34
provinceEdgeWeight(161) = 2
provinceEdgeSource(162) = 35
provinceEdgeWeight(162) = 1
provinceEdgeSource(163) = 57
provinceEdgeWeight(163) = 1
provinceEdgeStart(34) = 164
provinceEdgeCount(34) = 6
provinceEdgeSource(164) = 33
provinceEdgeWeight(164) = 2
provinceEdgeSource(165) = 35
provinceEdgeWeight(165) = 2
provinceEdgeSource(166) = 36
provinceEdgeWeight(166) = 2
provinceEdgeSource(167) = 54
provinceEdgeWeight(167) = 1
provinceEdgeSource(168) = 56
provinceEdgeWeight(168) = 1
provinceEdgeSource(169) = 57
provinceEdgeWeight(169) = 1
provinceEdgeStart(35) = 170
provinceEdgeCount(35) = 7
provinceEdgeSource(170) = 32
provinceEdgeWeight(170) = 2
provinceEdgeSource(171) = 33
provinceEdgeWeight(171) = 1
provinceEdgeSource(172) = 34
provinceEdgeWeight(172) = 2
provinceEdgeSource(173) = 51
provinceEdgeWeight(173) = 1
provinceEdgeSource(174) = 52
provinceEdgeWeight(174) = 1
provinceEdgeSource(175) = 53
provinceEdgeWeight(175) = 1
provinceEdgeSource(176) = 54
provinceEdgeWeight(176) = 1
provinceEdgeStart(36) = 177
provinceEdgeCount(36) = 6
provinceEdgeSource(177) = 34
provinceEdgeWeight(177) = 2
provinceEdgeSource(178) = 37
provinceEdgeWeight(178) = 2
provinceEdgeSource(179) = 53
provinceEdgeWeight(179) = 1
provinceEdgeSource(180) = 54
provinceEdgeWeight(180) = 1
provinceEdgeSource(181) = 55
provinceEdgeWeight(181) = 1
provinceEdgeSource(182) = 56
provinceEdgeWeight(182) = 1
provinceEdgeStart(37) = 183
provinceEdgeCount(37) = 7
provinceEdgeSource(183) = 36
provinceEdgeWeight(183) = 2
provinceEdgeSource(184) = 38
provinceEdgeWeight(184) = 2
provinceEdgeSource(185) = 41
provinceEdgeWeight(185) = 1
provinceEdgeSource(186) = 42
provinceEdgeWeight(186) = 1
provinceEdgeSource(187) = 43
provinceEdgeWeight(187) = 2
provinceEdgeSource(188) = 55
provinceEdgeWeight(188) = 1
provinceEdgeSource(189) = 56
provinceEdgeWeight(189) = 1
provinceEdgeStart(38) = 190
provinceEdgeCount(38) = 5
provinceEdgeSource(190) = 37
provinceEdgeWeight(190) = 2
provinceEdgeSource(191) = 39
provinceEdgeWeight(191) = 2
provinceEdgeSource(192) = 40
provinceEdgeWeight(192) = 1
provinceEdgeSource(193) = 41
provinceEdgeWeight(193) = 1
provinceEdgeSource(194) = 56
provinceEdgeWeight(194) = 1
provinceEdgeStart(39) = 195
provinceEdgeCount(39) = 5
provinceEdgeSource(195) = 29
provinceEdgeWeight(195) = 1
provinceEdgeSource(196) = 30
provinceEdgeWeight(196) = 2
provinceEdgeSource(197) = 38
provinceEdgeWeight(197) = 2
provinceEdgeSource(198) = 40
provinceEdgeWeight(198) = 1
provinceEdgeSource(199) = 56
provinceEdgeWeight(199) = 1
provinceEdgeStart(40) = 200
provinceEdgeCount(40) = 6
provinceEdgeSource(200) = 29
provinceEdgeWeight(200) = 1
provinceEdgeSource(201) = 38
provinceEdgeWeight(201) = 1
provinceEdgeSource(202) = 39
provinceEdgeWeight(202) = 1
provinceEdgeSource(203) = 41
provinceEdgeWeight(203) = 1
provinceEdgeSource(204) = 71
provinceEdgeWeight(204) = 1
provinceEdgeSource(205) = 75
provinceEdgeWeight(205) = 1
provinceEdgeStart(41) = 206
provinceEdgeCount(41) = 7
provinceEdgeSource(206) = 37
provinceEdgeWeight(206) = 1
provinceEdgeSource(207) = 38
provinceEdgeWeight(207) = 1
provinceEdgeSource(208) = 40
provinceEdgeWeight(208) = 1
provinceEdgeSource(209) = 42
provinceEdgeWeight(209) = 1
provinceEdgeSource(210) = 48
provinceEdgeWeight(210) = 1
provinceEdgeSource(211) = 70
provinceEdgeWeight(211) = 1
provinceEdgeSource(212) = 71
provinceEdgeWeight(212) = 1
provinceEdgeStart(42) = 213
provinceEdgeCount(42) = 5
provinceEdgeSource(213) = 37
provinceEdgeWeight(213) = 1
provinceEdgeSource(214) = 41
provinceEdgeWeight(214) = 1
provinceEdgeSource(215) = 43
provinceEdgeWeight(215) = 1
provinceEdgeSource(216) = 44
provinceEdgeWeight(216) = 1
provinceEdgeSource(217) = 48
provinceEdgeWeight(217) = 1
provinceEdgeStart(43) = 218
provinceEdgeCount(43) = 5
provinceEdgeSource(218) = 37
provinceEdgeWeight(218) = 2
provinceEdgeSource(219) = 42
provinceEdgeWeight(219) = 1
provinceEdgeSource(220) = 44
provinceEdgeWeight(220) = 2
provinceEdgeSource(221) = 53
provinceEdgeWeight(221) = 1
provinceEdgeSource(222) = 55
provinceEdgeWeight(222) = 1
provinceEdgeStart(44) = 223
provinceEdgeCount(44) = 6
provinceEdgeSource(223) = 42
provinceEdgeWeight(223) = 1
provinceEdgeSource(224) = 43
provinceEdgeWeight(224) = 2
provinceEdgeSource(225) = 45
provinceEdgeWeight(225) = 2
provinceEdgeSource(226) = 48
provinceEdgeWeight(226) = 1
provinceEdgeSource(227) = 53
provinceEdgeWeight(227) = 1
provinceEdgeSource(228) = 60
provinceEdgeWeight(228) = 1
provinceEdgeStart(45) = 229
provinceEdgeCount(45) = 5
provinceEdgeSource(229) = 44
provinceEdgeWeight(229) = 2
provinceEdgeSource(230) = 46
provinceEdgeWeight(230) = 2
provinceEdgeSource(231) = 47
provinceEdgeWeight(231) = 1
provinceEdgeSource(232) = 48
provinceEdgeWeight(232) = 1
provinceEdgeSource(233) = 60
provinceEdgeWeight(233) = 1
provinceEdgeStart(46) = 234
provinceEdgeCount(46) = 5
provinceEdgeSource(234) = 45
provinceEdgeWeight(234) = 2
provinceEdgeSource(235) = 47
provinceEdgeWeight(235) = 1
provinceEdgeSource(236) = 50
provinceEdgeWeight(236) = 2
provinceEdgeSource(237) = 60
provinceEdgeWeight(237) = 1
provinceEdgeSource(238) = 61
provinceEdgeWeight(238) = 1
provinceEdgeStart(47) = 239
provinceEdgeCount(47) = 4
provinceEdgeSource(239) = 45
provinceEdgeWeight(239) = 1
provinceEdgeSource(240) = 46
provinceEdgeWeight(240) = 1
provinceEdgeSource(241) = 48
provinceEdgeWeight(241) = 1
provinceEdgeSource(242) = 50
provinceEdgeWeight(242) = 1
provinceEdgeStart(48) = 243
provinceEdgeCount(48) = 7
provinceEdgeSource(243) = 41
provinceEdgeWeight(243) = 1
provinceEdgeSource(244) = 42
provinceEdgeWeight(244) = 1
provinceEdgeSource(245) = 44
provinceEdgeWeight(245) = 1
provinceEdgeSource(246) = 45
provinceEdgeWeight(246) = 1
provinceEdgeSource(247) = 47
provinceEdgeWeight(247) = 1
provinceEdgeSource(248) = 49
provinceEdgeWeight(248) = 1
provinceEdgeSource(249) = 50
provinceEdgeWeight(249) = 1
provinceEdgeStart(49) = 250
provinceEdgeCount(49) = 5
provinceEdgeSource(250) = 8
provinceEdgeWeight(250) = 2
provinceEdgeSource(251) = 14
provinceEdgeWeight(251) = 2
provinceEdgeSource(252) = 48
provinceEdgeWeight(252) = 1
provinceEdgeSource(253) = 50
provinceEdgeWeight(253) = 1
provinceEdgeSource(254) = 63
provinceEdgeWeight(254) = 1
provinceEdgeStart(50) = 255
provinceEdgeCount(50) = 6
provinceEdgeSource(255) = 8
provinceEdgeWeight(255) = 2
provinceEdgeSource(256) = 46
provinceEdgeWeight(256) = 2
provinceEdgeSource(257) = 47
provinceEdgeWeight(257) = 1
provinceEdgeSource(258) = 48
provinceEdgeWeight(258) = 1
provinceEdgeSource(259) = 49
provinceEdgeWeight(259) = 1
provinceEdgeSource(260) = 61
provinceEdgeWeight(260) = 1
provinceEdgeStart(51) = 261
provinceEdgeCount(51) = 3
provinceEdgeSource(261) = 32
provinceEdgeWeight(261) = 1
provinceEdgeSource(262) = 35
provinceEdgeWeight(262) = 1
provinceEdgeSource(263) = 52
provinceEdgeWeight(263) = 1
provinceEdgeStart(52) = 264
provinceEdgeCount(52) = 6
provinceEdgeSource(264) = 1
provinceEdgeWeight(264) = 1
provinceEdgeSource(265) = 2
provinceEdgeWeight(265) = 1
provinceEdgeSource(266) = 35
provinceEdgeWeight(266) = 1
provinceEdgeSource(267) = 51
provinceEdgeWeight(267) = 1
provinceEdgeSource(268) = 53
provinceEdgeWeight(268) = 1
provinceEdgeSource(269) = 58
provinceEdgeWeight(269) = 1
provinceEdgeStart(53) = 270
provinceEdgeCount(53) = 11
provinceEdgeSource(270) = 2
provinceEdgeWeight(270) = 1
provinceEdgeSource(271) = 4
provinceEdgeWeight(271) = 1
provinceEdgeSource(272) = 6
provinceEdgeWeight(272) = 1
provinceEdgeSource(273) = 35
provinceEdgeWeight(273) = 1
provinceEdgeSource(274) = 36
provinceEdgeWeight(274) = 1
provinceEdgeSource(275) = 43
provinceEdgeWeight(275) = 1
provinceEdgeSource(276) = 44
provinceEdgeWeight(276) = 1
provinceEdgeSource(277) = 52
provinceEdgeWeight(277) = 1
provinceEdgeSource(278) = 54
provinceEdgeWeight(278) = 1
provinceEdgeSource(279) = 55
provinceEdgeWeight(279) = 1
provinceEdgeSource(280) = 60
provinceEdgeWeight(280) = 1
provinceEdgeStart(54) = 281
provinceEdgeCount(54) = 4
provinceEdgeSource(281) = 34
provinceEdgeWeight(281) = 1
provinceEdgeSource(282) = 35
provinceEdgeWeight(282) = 1
provinceEdgeSource(283) = 36
provinceEdgeWeight(283) = 1
provinceEdgeSource(284) = 53
provinceEdgeWeight(284) = 1
provinceEdgeStart(55) = 285
provinceEdgeCount(55) = 4
provinceEdgeSource(285) = 36
provinceEdgeWeight(285) = 1
provinceEdgeSource(286) = 37
provinceEdgeWeight(286) = 1
provinceEdgeSource(287) = 43
provinceEdgeWeight(287) = 1
provinceEdgeSource(288) = 53
provinceEdgeWeight(288) = 1
provinceEdgeStart(56) = 289
provinceEdgeCount(56) = 7
provinceEdgeSource(289) = 30
provinceEdgeWeight(289) = 1
provinceEdgeSource(290) = 34
provinceEdgeWeight(290) = 1
provinceEdgeSource(291) = 36
provinceEdgeWeight(291) = 1
provinceEdgeSource(292) = 37
provinceEdgeWeight(292) = 1
provinceEdgeSource(293) = 38
provinceEdgeWeight(293) = 1
provinceEdgeSource(294) = 39
provinceEdgeWeight(294) = 1
provinceEdgeSource(295) = 57
provinceEdgeWeight(295) = 1
provinceEdgeStart(57) = 296
provinceEdgeCount(57) = 5
provinceEdgeSource(296) = 30
provinceEdgeWeight(296) = 1
provinceEdgeSource(297) = 32
provinceEdgeWeight(297) = 1
provinceEdgeSource(298) = 33
provinceEdgeWeight(298) = 1
provinceEdgeSource(299) = 34
provinceEdgeWeight(299) = 1
provinceEdgeSource(300) = 56
provinceEdgeWeight(300) = 1
provinceEdgeStart(58) = 301
provinceEdgeCount(58) = 5
provinceEdgeSource(301) = 1
provinceEdgeWeight(301) = 1
provinceEdgeSource(302) = 3
provinceEdgeWeight(302) = 1
provinceEdgeSource(303) = 52
provinceEdgeWeight(303) = 1
provinceEdgeSource(304) = 59
provinceEdgeWeight(304) = 1
provinceEdgeSource(305) = 61
provinceEdgeWeight(305) = 1
provinceEdgeStart(59) = 306
provinceEdgeCount(59) = 5
provinceEdgeSource(306) = 3
provinceEdgeWeight(306) = 1
provinceEdgeSource(307) = 5
provinceEdgeWeight(307) = 1
provinceEdgeSource(308) = 58
provinceEdgeWeight(308) = 1
provinceEdgeSource(309) = 60
provinceEdgeWeight(309) = 1
provinceEdgeSource(310) = 61
provinceEdgeWeight(310) = 1
provinceEdgeStart(60) = 311
provinceEdgeCount(60) = 8
provinceEdgeSource(311) = 5
provinceEdgeWeight(311) = 1
provinceEdgeSource(312) = 6
provinceEdgeWeight(312) = 1
provinceEdgeSource(313) = 44
provinceEdgeWeight(313) = 1
provinceEdgeSource(314) = 45
provinceEdgeWeight(314) = 1
provinceEdgeSource(315) = 46
provinceEdgeWeight(315) = 1
provinceEdgeSource(316) = 53
provinceEdgeWeight(316) = 1
provinceEdgeSource(317) = 59
provinceEdgeWeight(317) = 1
provinceEdgeSource(318) = 61
provinceEdgeWeight(318) = 1
provinceEdgeStart(61) = 319
provinceEdgeCount(61) = 9
provinceEdgeSource(319) = 7
provinceEdgeWeight(319) = 1
provinceEdgeSource(320) = 8
provinceEdgeWeight(320) = 2
provinceEdgeSource(321) = 9
provinceEdgeWeight(321) = 1
provinceEdgeSource(322) = 46
provinceEdgeWeight(322) = 1
provinceEdgeSource(323) = 50
provinceEdgeWeight(323) = 1
provinceEdgeSource(324) = 58
provinceEdgeWeight(324) = 1
provinceEdgeSource(325) = 59
provinceEdgeWeight(325) = 1
provinceEdgeSource(326) = 60
provinceEdgeWeight(326) = 1
provinceEdgeSource(327) = 62
provinceEdgeWeight(327) = 1
provinceEdgeStart(62) = 328
provinceEdgeCount(62) = 6
provinceEdgeSource(328) = 8
provinceEdgeWeight(328) = 1
provinceEdgeSource(329) = 9
provinceEdgeWeight(329) = 1
provinceEdgeSource(330) = 10
provinceEdgeWeight(330) = 1
provinceEdgeSource(331) = 61
provinceEdgeWeight(331) = 1
provinceEdgeSource(332) = 63
provinceEdgeWeight(332) = 1
provinceEdgeSource(333) = 64
provinceEdgeWeight(333) = 1
provinceEdgeStart(63) = 334
provinceEdgeCount(63) = 6
provinceEdgeSource(334) = 8
provinceEdgeWeight(334) = 1
provinceEdgeSource(335) = 13
provinceEdgeWeight(335) = 1
provinceEdgeSource(336) = 14
provinceEdgeWeight(336) = 1
provinceEdgeSource(337) = 49
provinceEdgeWeight(337) = 1
provinceEdgeSource(338) = 62
provinceEdgeWeight(338) = 1
provinceEdgeSource(339) = 64
provinceEdgeWeight(339) = 1
provinceEdgeStart(64) = 340
provinceEdgeCount(64) = 7
provinceEdgeSource(340) = 10
provinceEdgeWeight(340) = 1
provinceEdgeSource(341) = 11
provinceEdgeWeight(341) = 1
provinceEdgeSource(342) = 12
provinceEdgeWeight(342) = 1
provinceEdgeSource(343) = 13
provinceEdgeWeight(343) = 1
provinceEdgeSource(344) = 62
provinceEdgeWeight(344) = 1
provinceEdgeSource(345) = 63
provinceEdgeWeight(345) = 1
provinceEdgeSource(346) = 65
provinceEdgeWeight(346) = 1
provinceEdgeStart(65) = 347
provinceEdgeCount(65) = 9
provinceEdgeSource(347) = 10
provinceEdgeWeight(347) = 1
provinceEdgeSource(348) = 11
provinceEdgeWeight(348) = 1
provinceEdgeSource(349) = 16
provinceEdgeWeight(349) = 1
provinceEdgeSource(350) = 17
provinceEdgeWeight(350) = 1
provinceEdgeSource(351) = 18
provinceEdgeWeight(351) = 1
provinceEdgeSource(352) = 64
provinceEdgeWeight(352) = 1
provinceEdgeSource(353) = 66
provinceEdgeWeight(353) = 1
provinceEdgeSource(354) = 67
provinceEdgeWeight(354) = 1
provinceEdgeSource(355) = 68
provinceEdgeWeight(355) = 1
provinceEdgeStart(66) = 356
provinceEdgeCount(66) = 5
provinceEdgeSource(356) = 15
provinceEdgeWeight(356) = 1
provinceEdgeSource(357) = 16
provinceEdgeWeight(357) = 1
provinceEdgeSource(358) = 18
provinceEdgeWeight(358) = 1
provinceEdgeSource(359) = 65
provinceEdgeWeight(359) = 1
provinceEdgeSource(360) = 73
provinceEdgeWeight(360) = 1
provinceEdgeStart(67) = 361
provinceEdgeCount(67) = 6
provinceEdgeSource(361) = 17
provinceEdgeWeight(361) = 1
provinceEdgeSource(362) = 20
provinceEdgeWeight(362) = 1
provinceEdgeSource(363) = 22
provinceEdgeWeight(363) = 1
provinceEdgeSource(364) = 23
provinceEdgeWeight(364) = 1
provinceEdgeSource(365) = 65
provinceEdgeWeight(365) = 1
provinceEdgeSource(366) = 68
provinceEdgeWeight(366) = 1
provinceEdgeStart(68) = 367
provinceEdgeCount(68) = 4
provinceEdgeSource(367) = 23
provinceEdgeWeight(367) = 1
provinceEdgeSource(368) = 26
provinceEdgeWeight(368) = 1
provinceEdgeSource(369) = 65
provinceEdgeWeight(369) = 1
provinceEdgeSource(370) = 67
provinceEdgeWeight(370) = 1
provinceEdgeStart(69) = 371
provinceEdgeCount(69) = 6
provinceEdgeSource(371) = 20
provinceEdgeWeight(371) = 1
provinceEdgeSource(372) = 21
provinceEdgeWeight(372) = 1
provinceEdgeSource(373) = 22
provinceEdgeWeight(373) = 1
provinceEdgeSource(374) = 24
provinceEdgeWeight(374) = 1
provinceEdgeSource(375) = 25
provinceEdgeWeight(375) = 1
provinceEdgeSource(376) = 27
provinceEdgeWeight(376) = 1
provinceEdgeStart(70) = 377
provinceEdgeCount(70) = 6
provinceEdgeSource(377) = 14
provinceEdgeWeight(377) = 1
provinceEdgeSource(378) = 15
provinceEdgeWeight(378) = 1
provinceEdgeSource(379) = 41
provinceEdgeWeight(379) = 1
provinceEdgeSource(380) = 71
provinceEdgeWeight(380) = 1
provinceEdgeSource(381) = 72
provinceEdgeWeight(381) = 1
provinceEdgeSource(382) = 73
provinceEdgeWeight(382) = 1
provinceEdgeStart(71) = 383
provinceEdgeCount(71) = 5
provinceEdgeSource(383) = 40
provinceEdgeWeight(383) = 1
provinceEdgeSource(384) = 41
provinceEdgeWeight(384) = 1
provinceEdgeSource(385) = 70
provinceEdgeWeight(385) = 1
provinceEdgeSource(386) = 72
provinceEdgeWeight(386) = 1
provinceEdgeSource(387) = 75
provinceEdgeWeight(387) = 1
provinceEdgeStart(72) = 388
provinceEdgeCount(72) = 5
provinceEdgeSource(388) = 70
provinceEdgeWeight(388) = 1
provinceEdgeSource(389) = 71
provinceEdgeWeight(389) = 1
provinceEdgeSource(390) = 73
provinceEdgeWeight(390) = 1
provinceEdgeSource(391) = 74
provinceEdgeWeight(391) = 1
provinceEdgeSource(392) = 75
provinceEdgeWeight(392) = 1
provinceEdgeStart(73) = 393
provinceEdgeCount(73) = 7
provinceEdgeSource(393) = 15
provinceEdgeWeight(393) = 2
provinceEdgeSource(394) = 18
provinceEdgeWeight(394) = 2
provinceEdgeSource(395) = 19
provinceEdgeWeight(395) = 1
provinceEdgeSource(396) = 66
provinceEdgeWeight(396) = 1
provinceEdgeSource(397) = 70
provinceEdgeWeight(397) = 1
provinceEdgeSource(398) = 72
provinceEdgeWeight(398) = 1
provinceEdgeSource(399) = 74
provinceEdgeWeight(399) = 1
provinceEdgeStart(74) = 400
provinceEdgeCount(74) = 5
provinceEdgeSource(400) = 19
provinceEdgeWeight(400) = 1
provinceEdgeSource(401) = 21
provinceEdgeWeight(401) = 1
provinceEdgeSource(402) = 72
provinceEdgeWeight(402) = 1
provinceEdgeSource(403) = 73
provinceEdgeWeight(403) = 1
provinceEdgeSource(404) = 75
provinceEdgeWeight(404) = 1
provinceEdgeStart(75) = 405
provinceEdgeCount(75) = 7
provinceEdgeSource(405) = 21
provinceEdgeWeight(405) = 1
provinceEdgeSource(406) = 28
provinceEdgeWeight(406) = 1
provinceEdgeSource(407) = 29
provinceEdgeWeight(407) = 1
provinceEdgeSource(408) = 40
provinceEdgeWeight(408) = 1
provinceEdgeSource(409) = 71
provinceEdgeWeight(409) = 1
provinceEdgeSource(410) = 72
provinceEdgeWeight(410) = 1
provinceEdgeSource(411) = 74
provinceEdgeWeight(411) = 1
provinceGraphReady = 1
end if
dim belief(7)
dim pendingCountry(81)
dim pendingLegal(81)
dim pendingSensible(81)
dim pendingKind(1311)
dim pendingTarget(1311)
dim pendingSource(1311)
if beliefReady = 0 then
  for beliefCountry = 1 to 7
    belief(beliefCountry) = 0.5
  next beliefCountry
  beliefHistoryTick = -1
  beliefReady = 1
end if
dim incomingHead(81)
dim incomingNext(63)
richardPress = 0
' Phase-scoped commitments and bounded conversation memory.
dim pressPin(63)
dim pressPinPeer(63)
dim pressPinText$(63)
dim pressPactUnit(63)
dim pressPactPeer(63)
dim pressPactOrder(63)
dim pressPactText$(63)
dim pressPactLive(63)
dim pressExpected(63)
dim pressExpectedText$(63)
dim pressExtraUnit(31)
dim pressExtraOption(31)
dim pressSaved(63)
dim pressDealPlan(63)
dim pressCandidate(63)
dim pressTheirCandidate(63)
dim pressTrust(7)
dim pressPeace(7)
dim pressContact(7)
dim pressOutgoing$(7)
dim pressRejected$(7)
dim pressAsked(7)
dim pressAskedActor(7)
dim pressAskedMove(7)
dim pressPeaceAsked(7)
dim pressSeen$(63)
dim pressSeenPeer(63)
dim pressSeenReply$(63)
dim pressDmz(81)
dim pressMessageDmz(81)
dim pressAuditCountry(63)
dim pressAuditType(63)
dim pressAuditOrigin(63)
dim pressAuditKind(63)
dim pressAuditTarget(63)
dim pressAuditSource(63)
dim pressAuditPending(63)
dim rv(15)
if pressReady = 0 then
  for pressInit = 1 to 7
    pressTrust(pressInit) = 0.7
  next pressInit
  pressReady = 1
end if

' Persistent cooperative search and deal cursors; all arrays are bounded.
' Keep independent partial scores for movement and negotiation work.
dim sliceOrder(63)
dim sliceTrial(63)
dim sliceDealBase(63)
dim sliceDealPlan(63)
dim sliceDealState(63)
dim frontOwnTrial(63)
dim frontDealTrial(63)
dim frontLastMail$(7)

' Hosted port: the deployed host has no instruction counter, so every slice step is
' charged its upper bound and the estimate restarts with each negotiation pass.
estI = 0
estW = 0
passSteps = 0
sliceParts = negotiationLimit()
if sliceParts < 1 then sliceParts = 1
frontFirstI = 4000000 \ 10 * 7
frontFirstW = 10000000 \ 10 * 7
if sliceParts = 1 then
  frontFirstI = 4000000
  frontFirstW = 10000000
end if
' Hosted port: every negotiation pass has its own 4M budget, so each pass gets the
' same slice instead of a share of one budget.
sliceInstructions = frontFirstI
sliceWork = frontFirstW
sliceReserveI = sliceInstructions \ 16
sliceReserveW = sliceWork \ 16
sliceBoundI = 2000 + nu * nu * 100 + nu * nu * nu * 8
sliceBoundW = 3 * sliceBoundI
pressSends = 0
pressMode = 0
pressTesting = 0
if round = 0 then
  call sliceBegin()
  frontMode = 0
  frontOwnActive = 0
  frontDealActive = 0
  frontOwnEvaluations = 0
  frontDealEvaluations = 0
  frontFirstOwnEvaluations = 0
  frontFirstInstructions = 0
  for frontPeer = 1 to 7
    frontLastMail$(frontPeer) = ""
  next frontPeer
else
  if pressContextCount > 0 then searchSamples = pressContextCount
end if
sliceCalls = sliceCalls + 1
if phase() <> 0 then call drainMail()
sliceDidMail = 0
if sliceOrdersReady then call sliceMail()
if sliceContextDirty then
  call frontInvalidateSearch()
  frontDealActive = 0
  sliceDealStep = 0
  sliceContextDirty = 0
end if
sliceNextI = sliceBoundI
sliceNextW = sliceBoundW
if sliceMaximumI + sliceMaximumI \ 4 > sliceNextI then sliceNextI = sliceMaximumI + sliceMaximumI \ 4
if sliceMaximumW + sliceMaximumW \ 4 > sliceNextW then sliceNextW = sliceMaximumW + sliceMaximumW \ 4
frontMovementStopI = estI + (sliceInstructions - estI - sliceNextI - sliceReserveI) \ 2
frontMovementStopW = estW + (sliceWork - estW - sliceNextW - sliceReserveW) \ 2
call sliceBudget()
do while sliceCan
  sliceBeforeI = estI
  sliceBeforeW = estW
  stageBefore = sliceStage
  if sliceStage >= 8 then stageBefore = 8
  if sliceStage < 8 or sliceStage = 9 then
    if sliceDone then exit do
    call slicePrepare()
  elseif frontMode = 0 then
    if sliceDone or round > 0 and (estI >= frontMovementStopI or estW >= frontMovementStopW) then
      call frontSwitch(1)
      if sliceDeal >= 0 and frontDealSearchRevision <> searchImprovements then
        sliceEvalActive = 0
        sliceDealStep = 0
        frontDealSearchRevision = searchImprovements
      end if
    else
      call sliceSearch()
    end if
  else
    if sliceDeal < 0 then
      call sliceChooseDeal()
      frontDealSearchRevision = searchImprovements
    end if
    if sliceDeal < 0 then exit do
    call sliceDealAdvance()
  end if
  ' Charge each step twice the largest cost measured offline for its stage over forty
  ' hosted frames with up to 34 units (values 173k, options 53k, sampling 34k, search 14k).
  call stageCharge(stageBefore)
  estI = estI + chargeI
  estW = estW + chargeI * 5 \ 2
  sliceCostI = chargeI
  sliceCostW = chargeI * 5 \ 2
  passSteps = passSteps + 1
  ' The next step is charged at the heaviest stage charge that can still occur.
  sliceNextI = 350000
  sliceNextW = 875000
  if sliceStage >= 4 then
    sliceNextI = 70000
    sliceNextW = 175000
  end if
  call sliceBudget()
loop
call frontSwitch(0)
if sliceOrdersReady and phase() = 0 then
  call pressSubmit()
  if sliceStage = 8 then
    sliceNextI = 100000 + nu * nu * 200
    sliceNextW = 300000 + nu * nu * 400
    call sliceBudget()
    if sliceCan then call pressMakeOffers()
  end if
end if
if sliceDone = 0 or sliceDeal >= 0 then wantsPass = 1
if mailboxCount() > 0 then wantsPass = 1
sliceLastInstructions = estI
sliceLastWork = estW
sliceTotalInstructions = sliceTotalInstructions + sliceLastInstructions
sliceTotalWork = sliceTotalWork + sliceLastWork
if round = 0 then
  frontFirstOwnEvaluations = frontOwnEvaluations
  frontFirstInstructions = sliceLastInstructions
end if

sub frontSwitch(newMode)
  if newMode = frontMode then exit sub
  if frontMode = 0 then
    frontOwnActive = sliceEvalActive
    frontOwnSample = sliceEvalSample
    frontOwnSum = sliceEvalSum
    frontOwnWorst = sliceEvalWorst
    for frontI = 0 to nu - 1
      frontOwnTrial(frontI) = sliceTrial(frontI)
    next frontI
    sliceEvalActive = frontDealActive
    sliceEvalSample = frontDealSample
    sliceEvalSum = frontDealSum
    sliceEvalWorst = frontDealWorst
    for frontI = 0 to nu - 1
      sliceTrial(frontI) = frontDealTrial(frontI)
    next frontI
  else
    frontDealActive = sliceEvalActive
    frontDealSample = sliceEvalSample
    frontDealSum = sliceEvalSum
    frontDealWorst = sliceEvalWorst
    for frontI = 0 to nu - 1
      frontDealTrial(frontI) = sliceTrial(frontI)
    next frontI
    sliceEvalActive = frontOwnActive
    sliceEvalSample = frontOwnSample
    sliceEvalSum = frontOwnSum
    sliceEvalWorst = frontOwnWorst
    for frontI = 0 to nu - 1
      sliceTrial(frontI) = frontOwnTrial(frontI)
    next frontI
  end if
  frontMode = newMode
end sub

sub frontInvalidateSearch()
  frontOwnActive = 0
  if frontMode = 0 then sliceEvalActive = 0
  sliceScoreReady = 0
  sliceDone = 0
  sliceSeed = 0
  slicePass = 1
  sliceActor = 0
  sliceOption = -1
  sliceDonor = -1
  sliceChanged = 0
end sub

sub sliceBudget()
  sliceCan = 1
  if estI + sliceNextI + sliceReserveI >= sliceInstructions then sliceCan = 0
  if estW + sliceNextW + sliceReserveW >= sliceWork then sliceCan = 0
end sub

sub sliceBegin()
  call pressLearn()
  pressSeenCount = 0
  pressPactCount = 0
  pressContextCount = 0
  pressExtraCount = 0
  for sliceI = 0 to 63
    pressPin(sliceI) = -1
    pressPinPeer(sliceI) = 0
    pressPinText$(sliceI) = ""
    pressExpected(sliceI) = -1
    pressExpectedText$(sliceI) = ""
    sliceDealState(sliceI) = 0
  next sliceI
  for sliceI = 0 to 81
    pressDmz(sliceI) = 0
  next sliceI
  for sliceI = 1 to 7
    pressOutgoing$(sliceI) = ""
    pressRejected$(sliceI) = ""
    pressAsked(sliceI) = 0
    pressAskedActor(sliceI) = -1
    pressPeaceAsked(sliceI) = 0
  next sliceI
  while mailboxCount() > 0
    ignored$ = pullMailbox$()
    pressStaleDrained = pressStaleDrained + 1
  wend
  sliceStage = 1
  sliceOrdersReady = 0
  sliceDone = 0
  sliceEvalActive = 0
  sliceScoreReady = 0
  sliceDeal = -1
  sliceDealStep = 0
  sliceMaximumI = 0
  sliceMaximumW = 0
  sliceContextDirty = 0
  sliceCalls = 0
  sliceTotalInstructions = 0
  sliceTotalWork = 0
  slicePass = 1
  sliceActor = 0
  sliceOption = -1
  sliceDonor = -1
  sliceChanged = 0
  sliceSeed = 0
  sliceValueCountry = 1
  sliceOptionUnit = 0
  sliceSample = 0
  sliceCountry = 1
  sliceOwnSeed = 0
  sliceForeignStage = 0
  sliceForeignI = 0
  sliceForeignW = 0
  evaluations = 0
  searchImprovements = 0
  call prepareBoard()
  call updateBeliefs()
  call sliceValuesBegin()
  ' Always stage a legal provisional order before any resumable preparation.
  for sliceChoice = 0 to choiceCount() - 1
    if choiceKind(sliceChoice) = 0 or choiceKind(sliceChoice) = 6 or choiceKind(sliceChoice) = 10 then
      accepted = chooseOrder(sliceChoice)
    end if
  next sliceChoice
end sub

sub slicePrepare()
  if sliceStage = 1 then
    call sliceValuesStep()
    if sliceValueCountry > 7 then
      if phase() <> 0 then
        for sliceI = 0 to 81
          reserved(sliceI) = 0
        next sliceI
        sliceAdjustmentActor = 0
        sliceStage = 9
      else
        optionSize = 0
        greedySize = 0
        sliceStage = 2
      end if
    end if
  elseif sliceStage = 2 then
    call sliceOptionsStep()
    if sliceOptionUnit >= nu then sliceStage = 3
  elseif sliceStage = 3 then
    call indexJointOptions()
    sliceOwnCount = 0
    for sliceI = 0 to nu - 1
      best(sliceI) = holdOption(sliceI)
      if uc(sliceI) = me then
        sliceOrder(sliceOwnCount) = sliceI
        sliceOwnCount = sliceOwnCount + 1
      end if
    next sliceI
    for sliceI = sliceOwnCount - 1 to 1 step -1
      sliceJ = random(sliceI + 1)
      sliceTmp = sliceOrder(sliceI)
      sliceOrder(sliceI) = sliceOrder(sliceJ)
      sliceOrder(sliceJ) = sliceTmp
    next sliceI
    sliceStage = 4
    sliceOrdersReady = 1
    ' Submit a useful legal plan before expensive modeling or deal review.
    call dumbPlan(me)
    for sliceI = 0 to nu - 1
      if uc(sliceI) = me then best(sliceI) = choose(sliceI)
    next sliceI
    call pressSubmit()
  elseif sliceStage = 4 then
    call dumbPlan(sliceCountry)
    for sliceI = 0 to nu - 1
      if uc(sliceI) = sliceCountry then
        sliceO = choose(sliceI)
        rawContext(sliceSample * 64 + sliceI) = sliceO
        if sliceCountry <> me then
          modelIndex = sliceSample * 82 + parent(ut(sliceI))
          pendingKind(modelIndex) = ok(sliceO)
          pendingTarget(modelIndex) = ot(sliceO)
          if ok(sliceO) = 0 then pendingTarget(modelIndex) = 0
          pendingSource(modelIndex) = of(sliceO)
        end if
      end if
    next sliceI
    if sliceCountry <> me then
      sliceRandom = 0
      if random(10000) / 10000 >= belief(sliceCountry) then sliceRandom = 1
      modelCompetent(sliceSample * 8 + sliceCountry) = 1 - sliceRandom
      for sliceI = 0 to nu - 1
        if uc(sliceI) = sliceCountry then
          sliceO = choose(sliceI)
          if sliceRandom then sliceO = os(sliceI) + random(oc(sliceI))
          sampled(sliceSample * 64 + sliceI) = sliceO
        end if
      next sliceI
    end if
    sliceCountry = sliceCountry + 1
    if sliceCountry > 7 then
      sliceCountry = 1
      sliceSample = sliceSample + 1
    end if
    if sliceSample >= 16 then sliceStage = 5
  elseif sliceStage = 5 then
    call dumbPlan(me)
    for sliceI = 0 to nu - 1
      if uc(sliceI) = me then ownSeedPlans(sliceOwnSeed * 64 + sliceI) = choose(sliceI)
    next sliceI
    sliceOwnSeed = sliceOwnSeed + 1
    if sliceOwnSeed >= searchSeeds then sliceStage = 6
  elseif sliceStage = 6 then
    call sliceForeignStep()
  elseif sliceStage = 7 then
    ' Published-order learning uses the sixteen base samples, not stress slots.
    call rememberModel()
    if richardPress then call richardScenarios()
    pressContextCount = searchSamples
    sliceStage = 8
    sliceMaximumI = 0
    sliceMaximumW = 0
  elseif sliceStage = 9 then
    call sliceAdjustmentStep()
    if sliceAdjustmentActor > nu + 31 then sliceDone = 1
  end if
end sub

sub sliceMail()
  pressRead = 0
  pressDirty = 0
  sliceNextI = 150000
  sliceNextW = 600000
  call sliceBudget()
  while mailboxCount() > 0 and pressRead < 24 and sliceCan
    raw$ = pullMailbox$()
    pressSenderSeat = mailboxId()
    pressChannel = mailboxChannel()
    sender = 0
    for slicePower = 1 to 7
      if countrySeat(slicePower) = pressSenderSeat then sender = slicePower
    next slicePower
    pressRead = pressRead + 1
    sliceDidMail = sliceDidMail + 1
    if sender > 0 and sender <> me and pressChannel = selfPlayer() and phase() = 0 then
      frontDuplicateFact = 0
      if left$(raw$, 3) = "FCT" and frontLastMail$(sender) = raw$ then frontDuplicateFact = 1
      frontLastMail$(sender) = raw$
      if frontDuplicateFact = 0 then
        for sliceP = 0 to 81
          pressMessageDmz(sliceP) = 0
        next sliceP
        pressNegative = 0
        call normalize(raw$)
        if parsed then
          call handleMessage()
          if valid then
            pressParsed = pressParsed + 1
            if root$ = "CCL" then
              sliceCancel$ = mid$(canonical$, 6, len(canonical$) - 6)
              for sliceQ = 0 to pressSeenCount - 1
                if pressSeenPeer(sliceQ) = sender and pressSeen$(sliceQ) = sliceCancel$ then
                  sliceDealState(sliceQ) = 3
                  if sliceDeal = sliceQ then
                    sliceDeal = -1
                    frontDealActive = 0
                    sliceEvalActive = 0
                    sliceDealStep = 0
                  end if
                end if
              next sliceQ
            end if
            call pressReceive()
          else
            pressInvalid = pressInvalid + 1
          end if
        else
          pressInvalid = pressInvalid + 1
        end if
      end if
    end if
    call sliceBudget()
  wend
  if pressDirty then
    sliceContextDirty = 1
    sliceDone = 0
    pressReplans = pressReplans + 1
    for sliceI = 0 to nu - 1
      pressSaved(sliceI) = best(sliceI)
      trial(sliceI) = best(sliceI)
    next sliceI
    call pressConstrain()
    for sliceI = 0 to nu - 1
      if uc(sliceI) = me then best(sliceI) = trial(sliceI)
    next sliceI
  end if
end sub

sub sliceStartEval()
  sliceEvalSample = 0
  sliceEvalSum = 0
  sliceEvalWorst = 30000
  sliceEvalActive = 1
  for sliceI = 0 to nu - 1
    sliceTrial(sliceI) = trial(sliceI)
  next sliceI
end sub

sub sliceEvalStep()
  for sliceI = 0 to nu - 1
    trial(sliceI) = sliceTrial(sliceI)
  next sliceI
  call sliceScenario()
  sliceEvalSum = sliceEvalSum + score
  if score < sliceEvalWorst then sliceEvalWorst = score
  sliceEvalSample = sliceEvalSample + 1
  if sliceEvalSample >= searchSamples then
    evaluation = sliceEvalSum / searchSamples
    evaluation = evaluation - riskWeight * (evaluation - sliceEvalWorst)
    worstScore = sliceEvalWorst
    sliceEvalActive = 0
    evaluations = evaluations + 1
    if frontMode = 0 then
      frontOwnEvaluations = frontOwnEvaluations + 1
    else
      frontDealEvaluations = frontDealEvaluations + 1
    end if
  end if
end sub

sub sliceSearch()
  pressMode = 0
  pressTesting = 0
  if sliceEvalActive then
    call sliceEvalStep()
    if sliceEvalActive then exit sub
    if sliceScoreReady = 0 or evaluation > bestScore + 0.0001 then
      bestScore = evaluation
      for sliceI = 0 to nu - 1
        if uc(sliceI) = me then best(sliceI) = sliceTrial(sliceI)
      next sliceI
      if sliceScoreReady then
        searchImprovements = searchImprovements + 1
        sliceChanged = 1
      end if
    end if
    sliceScoreReady = 1
    exit sub
  end if
  for sliceI = 0 to nu - 1
    trial(sliceI) = best(sliceI)
  next sliceI
  if sliceScoreReady = 0 then
    call pressConstrain()
    call sliceStartEval()
    exit sub
  end if
  if sliceSeed < searchSeeds then
    for sliceI = 0 to nu - 1
      if uc(sliceI) = me then trial(sliceI) = ownSeedPlans(sliceSeed * 64 + sliceI)
    next sliceI
    sliceSeed = sliceSeed + 1
    call pressConstrain()
  else
    if sliceActor >= sliceOwnCount then
      if sliceChanged = 0 or slicePass >= searchPasses then
        sliceDone = 1
        exit sub
      end if
      slicePass = slicePass + 1
      sliceActor = 0
      sliceOption = -1
      sliceChanged = 0
    end if
    sliceUnit = sliceOrder(sliceActor)
    if sliceOption < 0 then sliceOption = os(sliceUnit)
    if sliceOption >= os(sliceUnit) + oc(sliceUnit) then
      sliceActor = sliceActor + 1
      sliceOption = -1
      sliceDonor = -1
      exit sub
    end if
    sliceO = sliceOption
    if sliceDonor < 0 then
      sliceDonor = 0
      if sliceO <> best(sliceUnit) and ok(sliceO) <> 4 and ov(sliceO) = 0 then
        trial(sliceUnit) = sliceO
      else
        exit sub
      end if
    else
      if ok(sliceO) <> 1 or sliceDonor >= nu then
        sliceOption = sliceOption + 1
        sliceDonor = -1
        exit sub
      end if
      sliceJ = sliceDonor
      sliceDonor = sliceDonor + 1
      if sliceJ = sliceUnit or uc(sliceJ) <> me then exit sub
      sliceKind = 3
      if ov(sliceO) then sliceKind = 4
      call findOption(sliceJ, sliceKind, parent(ot(sliceO)), parent(ut(sliceUnit)))
      if foundOption < 0 then exit sub
      if ov(sliceO) then
        sliceFrom = 0
        sliceTo = 0
        sliceNode = 82 + ut(sliceJ)
        for sliceEdge = edgeStart(sliceNode) to edgeStart(sliceNode) + edgeCount(sliceNode) - 1
          if parent(edgeTo(sliceEdge) mod 82) = parent(ut(sliceUnit)) then sliceFrom = 1
          if parent(edgeTo(sliceEdge) mod 82) = parent(ot(sliceO)) then sliceTo = 1
        next sliceEdge
        if sliceFrom = 0 or sliceTo = 0 then exit sub
      end if
      trial(sliceUnit) = sliceO
      trial(sliceJ) = foundOption
    end if
  end if
  call pressCheckPlan()
  if pressLegal then call sliceStartEval()
end sub

sub sliceChooseDeal()
  for sliceQ = 0 to pressSeenCount - 1
    if sliceDealState(sliceQ) = 0 then
      sliceDeal = sliceQ
      sliceDealState(sliceQ) = 1
      sliceDealStep = 0
      sliceEvalActive = 0
      sliceDone = 0
      exit sub
    end if
  next sliceQ
end sub

sub sliceDealAdvance()
  sender = pressSeenPeer(sliceDeal)
  if sliceParsedCall <> sliceCalls or sliceParsedDeal <> sliceDeal then
  sliceParsedCall = sliceCalls
  sliceParsedDeal = sliceDeal
  for sliceP = 0 to 81
    pressMessageDmz(sliceP) = 0
  next sliceP
  pressNegative = 0
  call normalize(pressSeen$(sliceDeal))
  call handleMessage()
  end if
  if sliceDealStep = 0 then
    call sliceDealBegin()
    if pressValidDeal = 0 then
      call sliceDealFinish()
      exit sub
    end if
    sliceDealStep = 1
    pressMode = 0
    pressTesting = 0
    call sliceStartEval()
    exit sub
  end if
  if sliceDealStep = 5 then
    call sliceDealRefine()
    exit sub
  end if
  pressMode = 0
  pressTesting = 0
  if sliceDealStep = 2 then
    pressMode = 1
    pressTesting = 1
  end if
  if sliceDealStep = 3 then pressMode = 2
  if sliceDealStep = 4 then pressMode = 3
  call sliceEvalStep()
  if sliceEvalActive then exit sub
  if sliceDealStep = 1 then
    pressBaseValue = evaluation
    pressBaseWorst = worstScore
    pressMode = 1
    pressTesting = 1
    call pressConstrain()
    call pressCheckPlan()
    if pressLegal = 0 then
      pressDealAccepted = 0
      call sliceDealFinish()
      exit sub
    end if
    for sliceI = 0 to nu - 1
      sliceDealPlan(sliceI) = trial(sliceI)
    next sliceI
  elseif sliceDealStep = 2 then
    pressHonourValue = evaluation
    sliceDealStep = 5
    sliceDealPass = 1
    sliceDealActor = 0
    sliceDealOption = -1
    sliceDealChanged = 0
    sliceDealProbes = 0
    exit sub
  elseif sliceDealStep = 3 then
    pressBetrayValue = evaluation
    pressBetrayWorst = worstScore
    pressMode = 3
    for sliceI = 0 to nu - 1
      trial(sliceI) = sliceDealBase(sliceI)
    next sliceI
  elseif sliceDealStep = 4 then
    pressFreeValue = evaluation
    pressDealAccepted = 0
    if pressHonourValue >= pressBaseValue - 0.5 and pressHonourValue >= pressFreeValue - 0.5 then
      if pressBetrayValue >= pressBaseValue - 2 then pressDealAccepted = 1
    end if
    if richardPress and pressBetrayWorst < pressBaseWorst - 0.5 then pressDealAccepted = 0
    pressAssessed = pressAssessed + 1
    call sliceDealFinish()
    exit sub
  end if
  sliceDealStep = sliceDealStep + 1
  call sliceStartEval()
end sub

sub sliceDealRefine()
  pressMode = 1
  pressTesting = 1
  if sliceEvalActive then
    call sliceEvalStep()
    if sliceEvalActive then exit sub
    if evaluation > pressHonourValue + 0.0001 then
      pressHonourValue = evaluation
      sliceDealChanged = 1
      for sliceI = 0 to nu - 1
        sliceDealPlan(sliceI) = sliceTrial(sliceI)
      next sliceI
    end if
    exit sub
  end if
  if sliceDealActor >= nu then
    if sliceDealChanged and sliceDealPass < 1 then
      sliceDealPass = sliceDealPass + 1
      sliceDealActor = 0
      sliceDealOption = -1
      sliceDealChanged = 0
    else
      sliceDealProbes = 2
    end if
  end if
  if sliceDealProbes >= 2 then
    for sliceI = 0 to nu - 1
      trial(sliceI) = sliceDealPlan(sliceI)
    next sliceI
    sliceDealStep = 3
    pressMode = 2
    pressTesting = 0
    call sliceStartEval()
    exit sub
  end if
  if uc(sliceDealActor) <> me then
    sliceDealActor = sliceDealActor + 1
    sliceDealOption = -1
    exit sub
  end if
  if sliceDealOption < 0 then sliceDealOption = os(sliceDealActor)
  if sliceDealOption >= os(sliceDealActor) + oc(sliceDealActor) then
    sliceDealActor = sliceDealActor + 1
    sliceDealOption = -1
    exit sub
  end if
  sliceO = sliceDealOption
  sliceDealOption = sliceDealOption + 1
  if sliceO = sliceDealPlan(sliceDealActor) then exit sub
  for sliceI = 0 to nu - 1
    trial(sliceI) = sliceDealPlan(sliceI)
  next sliceI
  trial(sliceDealActor) = sliceO
  call pressCheckPlan()
  if pressLegal then
    sliceDealProbes = sliceDealProbes + 1
    call sliceStartEval()
  end if
end sub

sub sliceDealFinish()
  pressMode = 0
  pressTesting = 0
  if pressDealAccepted then
    for sliceI = 0 to nu - 1
      pressSaved(sliceI) = best(sliceI)
      best(sliceI) = sliceDealPlan(sliceI)
    next sliceI
    call pressSubmit()
    if pressCommitted = 0 then pressDealAccepted = 0
  end if
  if pressDealAccepted then
    call sliceDealCommit()
    pressAccepted = pressAccepted + 1
  else
    pressDeclined = pressDeclined + 1
  end if
  pressReply$ = "REJ"
  if pressDealAccepted then pressReply$ = "YES"
  pressSeenReply$(sliceDeal) = pressReply$
  call pressSend(sender, pressReply$ + " (" + pressSeen$(sliceDeal) + ")")
  sliceDealState(sliceDeal) = 2
  sliceDeal = -1
  sliceDealStep = 0
  sliceEvalActive = 0
  if pressDealAccepted then
    call frontInvalidateSearch()
  end if
end sub

sub prepareBoard()
  for pbP = 0 to 81
    owner(pbP) = 0
    atUnit(pbP) = -1
  next pbP
  for pbP = 1 to 81
    owner(pbP) = territoryOwner(pbP)
  next pbP
  for pbI = 0 to nu - 1
    if ur(pbI) = 0 then atUnit(parent(ut(pbI))) = pbI
  next pbI
end sub

sub computeValues()
  ' David Norman proximity recurrence, with integer floors below one raw unit.
  for cvI = 0 to 655
    reach(cvI) = 0
  next cvI
  for cvI = 0 to nu - 1
    if ur(cvI) = 0 then
      for cvP = 0 to 81
        reserved(cvP) = 0
      next cvP
      cvN = uk(cvI) * 82 + ut(cvI)
      for cvE = edgeStart(cvN) to edgeStart(cvN) + edgeCount(cvN) - 1
        cvP = parent(edgeTo(cvE) mod 82)
        if reserved(cvP) = 0 then reach(uc(cvI) * 82 + cvP) = reach(uc(cvI) * 82 + cvP) + 1
        reserved(cvP) = 1
      next cvE
    end if
  next cvI
  neutral = 0
  for cvP = 1 to 81
    if supply(cvP) and owner(cvP) = 0 then neutral = neutral + 1
  next cvP
  sizes(0) = neutral * neutral + 4 * neutral + 16
  for cvC = 1 to 7
    cvS = centerCount(cvC)
    sizes(cvC) = cvS * cvS + 4 * cvS + 16
  next cvC
  for cvC = 1 to 7
    for cvP = 1 to 75
      strength(cvP) = reach(cvC * 82 + cvP)
      competition(cvP) = 0
      defense(cvP) = 0
      for cvOther = 1 to 7
        if cvOther <> cvC then
          if reach(cvOther * 82 + cvP) > competition(cvP) then competition(cvP) = reach(cvOther * 82 + cvP)
          if supply(cvP) and owner(cvP) = cvC and reach(cvOther * 82 + cvP) > 0 then
            if sizes(cvOther) > defense(cvP) then defense(cvP) = sizes(cvOther)
          end if
        end if
      next cvOther
      cvAttack = 0
      if supply(cvP) and owner(cvP) <> cvC then cvAttack = sizes(owner(cvP))
      if season() = 0 or phase() = 2 then
        prox(cvP) = cvAttack * 2800 + defense(cvP) * 1200
      else
        prox(cvP) = cvAttack * 2400 + defense(cvP) * 1600
      end if
      provinceValue(cvC * 82 + cvP) = 0
    next cvP
    for cvDepth = 0 to 9
      cvW = 1
      if cvDepth = 0 then
        cvW = 1000
        if season() = 0 and phase() <> 2 then cvW = 100
      end if
      if cvDepth = 1 then
        cvW = 100
        if season() = 0 and phase() <> 2 then cvW = 1000
      end if
      if cvDepth = 2 then cvW = 30
      if cvDepth = 3 then cvW = 10
      if cvDepth = 4 then cvW = 6
      if cvDepth = 5 then cvW = 5
      if cvDepth = 6 then cvW = 4
      if cvDepth = 7 then cvW = 3
      if cvDepth = 8 then cvW = 2
      for cvP = 1 to 75
        provinceValue(cvC * 82 + cvP) = provinceValue(cvC * 82 + cvP) + (prox(cvP) \ 64) * cvW + (prox(cvP) mod 64) * cvW \ 64
      next cvP
      if cvDepth < 9 then
        for cvP = 1 to 75
          cvTotal = prox(cvP)
          for cvJ = provinceEdgeStart(cvP) to provinceEdgeStart(cvP) + provinceEdgeCount(cvP) - 1
            cvTotal = cvTotal + prox(provinceEdgeSource(cvJ)) * provinceEdgeWeight(cvJ)
          next cvJ
          proxNext(cvP) = cvTotal \ 5
        next cvP
        for cvP = 1 to 75
          prox(cvP) = proxNext(cvP)
        next cvP
      end if
    next cvDepth
    vmax(cvC) = 1
    for cvN = 1 to 163
      values(cvC * 164 + cvN) = 0
      if nodeValid(cvN) then
        cvP = parent(cvN mod 82)
        cvValue = provinceValue(cvC * 82 + cvP)
        if phase() = 2 then
          cvValue = cvValue + defense(cvP) * 1000 \ 16
        else
          cvValue = cvValue + (strength(cvP) - competition(cvP)) * 1000 \ 16
        end if
        values(cvC * 164 + cvN) = cvValue
        if cvValue > vmax(cvC) then vmax(cvC) = cvValue
      end if
    next cvN
  next cvC
end sub

sub appendOption(a, k, t, f, v, h)
  ok(optionSize) = k
  ot(optionSize) = t
  of(optionSize) = f
  ov(optionSize) = v
  hostChoice(optionSize) = h
  if k = 0 then holdOption(a) = optionSize
  if k = 0 or k = 1 and v = 0 then
    greedyOptions(greedySize) = optionSize
    greedySize = greedySize + 1
    greedyCount(a) = greedyCount(a) + 1
  end if
  optionSize = optionSize + 1
  oc(a) = oc(a) + 1
end sub

sub prepareOptions()
  optionSize = 0
  greedySize = 0
  for poI = 0 to nu - 1
    os(poI) = optionSize
    oc(poI) = 0
    greedyStart(poI) = greedySize
    greedyCount(poI) = 0
    if uc(poI) = me then
      for poH = 0 to choiceCount() - 1
        if choiceUnit(poH) = poI then call appendOption(poI, choiceKind(poH), choiceTarget(poH), choiceSource(poH), choiceViaConvoy(poH), poH)
      next poH
    else
      call appendOption(poI, 0, ut(poI), 0, 0, -1)
      poN = uk(poI) * 82 + ut(poI)
      for poE = edgeStart(poN) to edgeStart(poN) + edgeCount(poN) - 1
        call appendOption(poI, 1, edgeTo(poE) mod 82, 0, 0, -1)
      next poE
      for poJ = 0 to nu - 1
        if poJ <> poI then
          for poE = edgeStart(poN) to edgeStart(poN) + edgeCount(poN) - 1
            if parent(edgeTo(poE) mod 82) = parent(ut(poJ)) then call appendOption(poI, 2, parent(ut(poJ)), 0, 0, -1)
          next poE
          poOtherN = uk(poJ) * 82 + ut(poJ)
          for poOtherE = edgeStart(poOtherN) to edgeStart(poOtherN) + edgeCount(poOtherN) - 1
            poTarget = parent(edgeTo(poOtherE) mod 82)
            for poE = edgeStart(poN) to edgeStart(poN) + edgeCount(poN) - 1
              if parent(edgeTo(poE) mod 82) = poTarget then call appendOption(poI, 3, poTarget, parent(ut(poJ)), 0, -1)
            next poE
          next poOtherE
        end if
      next poJ
    end if
  next poI
  call indexJointOptions()
end sub

sub dumbPlan(dpC)
  ' The upstream randomized descent and deferred friendly-unit dependencies.
  if waitingEpoch >= 2147483000 then
    for waitingClear = 0 to 4095
      waiting(waitingClear) = 0
    next waitingClear
    waitingEpoch = 0
  end if
  waitingEpoch = waitingEpoch + 1
  dpCount = 0
  for dpI = 0 to nu - 1
    assigned(dpI) = 0
    deferred(dpI) = 0
    choose(dpI) = holdOption(dpI)
    if uc(dpI) = dpC then
      orderQueue(dpCount) = dpI
      dpCount = dpCount + 1
    end if
  next dpI
  for dpI = dpCount - 1 to 1 step -1
    dpJ = random(dpI + 1)
    dpTmp = orderQueue(dpI)
    orderQueue(dpI) = orderQueue(dpJ)
    orderQueue(dpJ) = dpTmp
  next dpI
  dpHead = 0
  dpIterations = 0
  do while dpHead < dpCount and dpIterations < nu * 4
    dpIterations = dpIterations + 1
    dpI = orderQueue(dpHead)
    dpHead = dpHead + 1
    if assigned(dpI) = 0 then
      dpRankN = 0
      for dpGreedy = greedyStart(dpI) to greedyStart(dpI) + greedyCount(dpI) - 1
        dpO = greedyOptions(dpGreedy)
        if ok(dpO) = 0 or ok(dpO) = 1 and ov(dpO) = 0 then
          dpDest = ut(dpI)
          if ok(dpO) = 1 then dpDest = ot(dpO)
          dpBlock = atUnit(parent(dpDest))
          dpAllowed = 1
          if dpBlock >= 0 then
            if waiting(dpI * 64 + dpBlock) = waitingEpoch then dpAllowed = 0
          end if
          if dpAllowed then
            dpV = values(dpC * 164 + uk(dpI) * 82 + dpDest)
            dpPos = dpRankN
            do while dpPos > 0
              if rankValue(dpPos - 1) >= dpV then exit do
              ranked(dpPos) = ranked(dpPos - 1)
              rankValue(dpPos) = rankValue(dpPos - 1)
              dpPos = dpPos - 1
            loop
            ranked(dpPos) = dpO
            rankValue(dpPos) = dpV
            dpRankN = dpRankN + 1
          end if
        end if
      next dpGreedy
      dpDone = 0
      do while dpRankN > 0 and dpDone = 0
        dpPick = 0
        do while dpPick + 1 < dpRankN
          dpAbs = rankValue(dpPick)
          if dpAbs < 0 then dpAbs = -dpAbs
          dpDivisor = dpAbs \ 30000 + 1
          dpDiff = rankValue(dpPick) - rankValue(dpPick + 1)
          if dpDiff < 0 then dpDiff = -dpDiff
          dpDiff = dpDiff \ dpDivisor
          ' Integer comparison implements 0.5 > draw >= 5*relative difference.
          dpDraw = random(10000) / 10000
          dpChance = 5
          if rankValue(dpPick) <> 0 then dpChance = dpDiff / (dpAbs \ dpDivisor) * 5
          if dpDraw < 0.5 and dpDraw >= dpChance then
            dpPick = dpPick + 1
          else
            exit do
          end if
        loop
        dpO = ranked(dpPick)
        dpDest = parent(ot(dpO))
        if ok(dpO) = 0 then dpDest = parent(ut(dpI))
        dpBlock = atUnit(dpDest)
        dpRemove = 0
        if ok(dpO) = 0 then
          choose(dpI) = dpO
          assigned(dpI) = 1
          dpDone = 1
        else
          if dpBlock >= 0 then
            if uc(dpBlock) = dpC and assigned(dpBlock) = 0 then
              if deferred(dpI) < 2 and dpCount < 63 then
                orderQueue(dpCount) = dpI
                dpCount = dpCount + 1
                waiting(dpBlock * 64 + dpI) = waitingEpoch
                deferred(dpI) = deferred(dpI) + 1
                dpDone = 1
              else
                dpRemove = 1
              end if
            end if
            if uc(dpBlock) = dpC and assigned(dpBlock) and ok(choose(dpBlock)) <> 1 then
              dpComp = 0
              for dpEnemy = 1 to 7
                if dpEnemy <> dpC and reach(dpEnemy * 82 + dpDest) > dpComp then dpComp = reach(dpEnemy * 82 + dpDest)
              next dpEnemy
              if dpComp > 1 then
                call findOption(dpI, 2, dpDest, 0)
                if foundOption >= 0 then
                  choose(dpI) = foundOption
                  assigned(dpI) = 1
                  dpDone = 1
                end if
              end if
              if dpDone = 0 then dpRemove = 1
            end if
          end if
          if dpDone = 0 and dpRemove = 0 then
            dpMover = -1
            for dpJ = 0 to nu - 1
              if uc(dpJ) = dpC and assigned(dpJ) and ok(choose(dpJ)) = 1 then
                if parent(ot(choose(dpJ))) = dpDest then dpMover = dpJ
              end if
            next dpJ
            if dpMover >= 0 then
              dpComp = 0
              for dpEnemy = 1 to 7
                if dpEnemy <> dpC and reach(dpEnemy * 82 + dpDest) > dpComp then dpComp = reach(dpEnemy * 82 + dpDest)
              next dpEnemy
              if dpComp > 0 then
                call findOption(dpI, 3, dpDest, parent(ut(dpMover)))
                if foundOption >= 0 then
                  choose(dpI) = foundOption
                  assigned(dpI) = 1
                  dpDone = 1
                end if
              end if
              if dpDone = 0 then dpRemove = 1
            else
              choose(dpI) = dpO
              assigned(dpI) = 1
              dpDone = 1
            end if
          end if
        end if
        if dpRemove then
          for dpJ = dpPick to dpRankN - 2
            ranked(dpJ) = ranked(dpJ + 1)
            rankValue(dpJ) = rankValue(dpJ + 1)
          next dpJ
          dpRankN = dpRankN - 1
        end if
      loop
    end if
  loop
end sub

sub findOption(foI, foK, foT, foF)
  foundOption = -1
  ' Hosted port: scan the unit's own support-move options instead of the 95k-cell
  ' lookup table, which does not fit the deployed 4 MiB memory cap.
  if foK = 3 then
    foUnit = atUnit(parent(foF))
    if foUnit >= 0 then
      foTarget = parent(foT)
      for foO = os(foI) to os(foI) + oc(foI) - 1
        if ok(foO) = 3 then
          if parent(ot(foO)) = foTarget then
            if atUnit(parent(of(foO))) = foUnit then
              foundOption = foO
              exit sub
            end if
          end if
        end if
      next foO
      exit sub
    end if
  end if
  for foO = os(foI) to os(foI) + oc(foI) - 1
    if ok(foO) = foK and parent(ot(foO)) = parent(foT) and of(foO) = foF then
      foundOption = foO
      exit for
    end if
  next foO
end sub

sub searchMovement()
  searchEpoch = searchEpoch + 1
  distinctSingles = 0
  distinctJoints = 0
  for smS = 0 to searchSamples - 1
    for smC = 1 to 7
      if smC <> me then
        call dumbPlan(smC)
        for modelI = 0 to nu - 1
          if uc(modelI) = smC then
            modelIndex = smS * 82 + parent(ut(modelI))
            modelO = choose(modelI)
            pendingKind(modelIndex) = ok(modelO)
            pendingTarget(modelIndex) = ot(modelO)
            if ok(modelO) = 0 then pendingTarget(modelIndex) = 0
            pendingSource(modelIndex) = of(modelO)
          end if
        next modelI
        if belief(smC) = 0.5 then
          smRandom = random(2)
        else
          smRandom = 0
          if random(10000) / 10000 >= belief(smC) then smRandom = 1
        end if
        modelCompetent(smS * 8 + smC) = 1 - smRandom
        for smI = 0 to nu - 1
          if uc(smI) = smC then
            smO = choose(smI)
            rawContext(smS * 64 + smI) = smO
            if smRandom then smO = os(smI) + random(oc(smI))
            sampled(smS * 64 + smI) = smO
          end if
        next smI
      end if
    next smC
  next smS
  call rememberModel()
  for modelSeed = 0 to searchSamples - 1
    call dumbPlan(me)
    for modelI = 0 to nu - 1
      if uc(modelI) = me then rawContext(modelSeed * 64 + modelI) = choose(modelI)
    next modelI
  next modelSeed
  for stagedSeed = 1 to searchSeeds
    call dumbPlan(me)
    for stagedI = 0 to nu - 1
      if uc(stagedI) = me then
        ownSeedPlans((stagedSeed - 1) * 64 + stagedI) = choose(stagedI)
      end if
    next stagedI
  next stagedSeed
  if foreignPolishEnabled then call polishOpponents()
  evaluations = 0
  maximumPlanInstructions = 0
  maximumPlanWork = 0
  searchStoppedByBudget = 0
  bestScore = -30000
  searchImprovements = 0
  for smSeed = 1 to searchSeeds
    call searchBudget()
    if smSeed > 1 and searchCanContinue = 0 then exit for
    for smI = 0 to nu - 1
      if uc(smI) = me then trial(smI) = ownSeedPlans((smSeed - 1) * 64 + smI)
    next smI
    call pressConstrain()
    call evaluatePlan()
    if evaluation > bestScore then
      bestScore = evaluation
      for smI = 0 to nu - 1
        if uc(smI) = me then best(smI) = trial(smI)
      next smI
    end if
  next smSeed
  smOwnCount = 0
  for smI = 0 to nu - 1
    if uc(smI) = me then
      orderQueue(smOwnCount) = smI
      smOwnCount = smOwnCount + 1
    end if
  next smI
  for smI = smOwnCount - 1 to 1 step -1
    smJ = random(smI + 1)
    smTmp = orderQueue(smI)
    orderQueue(smI) = orderQueue(smJ)
    orderQueue(smJ) = smTmp
  next smI
  for smPass = 1 to searchPasses
    smChanged = 0
    for smActor = 0 to smOwnCount - 1
      smI = orderQueue(smActor)
      call searchBudget()
      if searchCanContinue = 0 then exit for
      ' Scan complete legal single changes, with a deterministic evaluation cap.
      for portO = os(smI) to os(smI) + oc(smI) - 1
        call searchBudget()
        if searchCanContinue = 0 then exit for
        if portO <> best(smI) and ok(portO) <> 4 and ov(portO) = 0 then
          for portI = 0 to nu - 1
            trial(portI) = best(portI)
          next portI
          trial(smI) = portO
          call tryPlan()
        end if
        if ok(portO) = 1 then
          ' Change the mover and supporting or convoying donor atomically.
          for portDonor = 0 to nu - 1
            call searchBudget()
            if searchCanContinue = 0 then exit for
            if portDonor <> smI and uc(portDonor) = me then
              portKind = 3
              if ov(portO) then portKind = 4
              call findOption(portDonor, portKind, parent(ot(portO)), parent(ut(smI)))
              portSupport = foundOption
              portAllowed = portSupport >= 0
              if ov(portO) then
                portFrom = 0
                portTo = 0
                portNode = 82 + ut(portDonor)
                for portEdge = edgeStart(portNode) to edgeStart(portNode) + edgeCount(portNode) - 1
                  if parent(edgeTo(portEdge) mod 82) = parent(ut(smI)) then portFrom = 1
                  if parent(edgeTo(portEdge) mod 82) = parent(ot(portO)) then portTo = 1
                next portEdge
                if portFrom = 0 or portTo = 0 then portAllowed = 0
              end if
              if portAllowed then
                if portO <> best(smI) or portSupport <> best(portDonor) then
                  for portI = 0 to nu - 1
                    trial(portI) = best(portI)
                  next portI
                  trial(smI) = portO
                  trial(portDonor) = portSupport
                  if ov(portO) then
                    convoyEvaluations = convoyEvaluations + 1
                  else
                    pairEvaluations = pairEvaluations + 1
                  end if
                  call tryPlan()
                end if
              end if
            end if
          next portDonor
        end if
      next portO
    next smActor
    if smChanged = 0 then exit for
  next smPass
  for smI = 0 to nu - 1
    if uc(smI) = me then
      smH = hostChoice(best(smI))
      if smH >= 0 then accepted = chooseOrder(smH)
    end if
  next smI
end sub

sub tryPlan()
  call pressCheckPlan()
  if pressLegal = 0 then exit sub
  call evaluatePlan()
  if evaluation > bestScore + 0.0001 then
    bestScore = evaluation
    searchImprovements = searchImprovements + 1
    smChanged = 1
    for tpI = 0 to nu - 1
      if uc(tpI) = me then best(tpI) = trial(tpI)
    next tpI
  end if
end sub

sub polishOpponents()
  ' Improve legal single orders against two immutable contexts, within one third budget.
  foreignKernelCalls = 0
  foreignProposals = 0
  foreignImprovements = 0
  foreignCountries = 0
  foreignMaximumCost = 0
  foreignMaximumWork = 0
  for fmSample = 0 to searchSamples - 1
    for fmCountry = 1 to 7
      if fmCountry <> me and modelCompetent(fmSample * 8 + fmCountry) then
        if estI + 4 * foreignMaximumCost >= 4000000 \ 3 then exit sub
        if estW + 4 * foreignMaximumWork >= 10000000 \ 3 then exit sub
        foreignCountries = foreignCountries + 1
        for fmI = 0 to nu - 1
          modelPlan(fmI) = rawContext(fmSample * 64 + fmI)
        next fmI
        fmRecord = 0
        call evaluateForeign()
        fmBestScore = foreignEvaluation
        for fmUnit = 0 to nu - 1
          if uc(fmUnit) = fmCountry then
            for foreignO = os(fmUnit) to os(fmUnit) + oc(fmUnit) - 1
              if estI + 4 * foreignMaximumCost >= 4000000 \ 3 then exit for
              if estW + 4 * foreignMaximumWork >= 10000000 \ 3 then exit for
              if foreignO <> modelPlan(fmUnit) and ok(foreignO) <> 4 and ov(foreignO) = 0 then
                fmPrevious = modelPlan(fmUnit)
                modelPlan(fmUnit) = foreignO
                foreignBefore = estI
                foreignBeforeWork = estW
                call evaluateForeign()
                foreignProposals = foreignProposals + 1
                foreignCost = estI - foreignBefore
                foreignWork = estW - foreignBeforeWork
                if foreignCost > foreignMaximumCost then foreignMaximumCost = foreignCost
                if foreignWork > foreignMaximumWork then foreignMaximumWork = foreignWork
                if foreignEvaluation > fmBestScore + 0.0001 then
                  fmBestScore = foreignEvaluation
                  foreignImprovements = foreignImprovements + 1
                else
                  modelPlan(fmUnit) = fmPrevious
                end if
              end if
            next foreignO
          end if
        next fmUnit
        for fmI = 0 to nu - 1
          if uc(fmI) = fmCountry then sampled(fmSample * 64 + fmI) = modelPlan(fmI)
        next fmI
      end if
    next fmCountry
  next fmSample
end sub

sub tryForeign()
  fmPrevious = modelPlan(fmUnit)
  modelPlan(fmUnit) = fmPick
  foreignProposals = foreignProposals + 1
  call evaluateForeign()
  if foreignEvaluation > fmBestScore then
    fmBestScore = foreignEvaluation
    foreignImprovements = foreignImprovements + 1
  else
    modelPlan(fmUnit) = fmPrevious
  end if
end sub

sub evaluateForeign()
  ' Score a complete foreign plan against two immutable unpolished contexts.
  foreignEvaluation = 0
  for feContext = 0 to 1
    feSample = (fmSample + feContext) mod searchSamples
    for feI = 0 to nu - 1
      feO = rawContext(feSample * 64 + feI)
      if uc(feI) = fmCountry then feO = modelPlan(feI)
      simKind(feI) = ok(feO)
      simTo(feI) = parent(ot(feO))
      simRawTo(feI) = ot(feO)
      simFrom(feI) = of(feO)
    next feI
    call adjudicateFast()
    foreignKernelCalls = foreignKernelCalls + 1
    call scoreForeign()
    foreignEvaluation = foreignEvaluation + foreignScore
    if fmRecord then
      for feI = 0 to nu - 1
        if uc(feI) = fmCountry then
          if ok(modelPlan(feI)) = 1 and moved(feI) = 0 then modelMissed(feI) = 1
          if dislodged(feI) then modelLost(feI) = 1
        end if
      next feI
    end if
  next feContext
  foreignEvaluation = foreignEvaluation / 2
end sub

sub scoreForeign()
  ' Retain the pinned raw center/position/loss score from the foreign side.
  for fsP = 0 to 81
    occupiedAfter(fsP) = 0
  next fsP
  fsPos = 0
  fsLost = 0
  fsDivisor = vmax(fmCountry) \ 30000 + 1
  fsMax = vmax(fmCountry) \ fsDivisor
  for fsI = 0 to nu - 1
    if dislodged(fsI) then
      if uc(fsI) = fmCountry then fsLost = fsLost + 1
    else
      fsWhere = parent(ut(fsI))
      fsNode = uk(fsI) * 82 + ut(fsI)
      if moved(fsI) then
        fsWhere = simTo(fsI)
        fsNode = uk(fsI) * 82 + simRawTo(fsI)
      end if
      occupiedAfter(fsWhere) = uc(fsI)
      if uc(fsI) = fmCountry then fsPos = fsPos + (values(fmCountry * 164 + fsNode) \ fsDivisor) / fsMax
    end if
  next fsI
  fsSC = 0
  for fsP = 1 to 75
    if supply(fsP) then
      fsHolder = occupiedAfter(fsP)
      if fsHolder = 0 then fsHolder = owner(fsP)
      if fsHolder = fmCountry then fsSC = fsSC + 1
    end if
  next fsP
  foreignScore = scWeight * fsSC + posWeight * fsPos - lostWeight * fsLost
end sub

sub evaluatePlan()
  planBeforeInstructions = estI
  planBeforeWork = estW
  evaluation = 0
  worstScore = 30000
  evaluations = evaluations + 1
  for epSample = 0 to searchSamples - 1
    for epI = 0 to nu - 1
      epO = trial(epI)
      if uc(epI) <> me then
        epO = sampled(epSample * 64 + epI)
        call pressForeign(epSample, epI, epO)
        epO = pressForeignOption
      end if
      simKind(epI) = ok(epO)
      simTo(epI) = parent(ot(epO))
      simRawTo(epI) = ot(epO)
      simFrom(epI) = of(epO)
      if ov(epO) then simKind(epI) = 0
      if ok(epO) = 4 then simKind(epI) = 0
      ' Match fast_orders' convoy approximation, bounded to one fleet.
      if ov(epO) then
        for epJ = 0 to nu - 1
          epJO = trial(epJ)
          if uc(epJ) <> me then
            epJO = sampled(epSample * 64 + epJ)
            call pressForeign(epSample, epJ, epJO)
            epJO = pressForeignOption
          end if
          if ok(epJO) = 4 and parent(of(epJO)) = parent(ut(epI)) and parent(ot(epJO)) = simTo(epI) then
            epSea = ut(epJ)
            epFromOK = 0
            epToOK = 0
            epN = 82 + epSea
            for epE = edgeStart(epN) to edgeStart(epN) + edgeCount(epN) - 1
              if parent(edgeTo(epE) mod 82) = parent(ut(epI)) then epFromOK = 1
              if parent(edgeTo(epE) mod 82) = simTo(epI) then epToOK = 1
            next epE
            if epFromOK and epToOK then simKind(epI) = 1
          end if
        next epJ
      end if
    next epI
    call adjudicateFast()
    call scoreFast()
    evaluation = evaluation + score
    if score < worstScore then worstScore = score
  next epSample
  evaluation = evaluation / searchSamples
  evaluation = evaluation - riskWeight * (evaluation - worstScore)
  planInstructionCost = estI - planBeforeInstructions
  planWorkCost = estW - planBeforeWork
  if planInstructionCost > maximumPlanInstructions then maximumPlanInstructions = planInstructionCost
  if planWorkCost > maximumPlanWork then maximumPlanWork = planWorkCost
end sub

sub adjudicateFast()
  depCount = 0
  resolveDepth = 0
  adjudicationAborted = 0
  for ajI = 0 to nu - 1
    simState(ajI) = 0
    simResult(ajI) = 0
    supportHoldHead(ajI) = -1
    supportMoveHead(ajI) = -1
    moved(ajI) = 0
    dislodged(ajI) = 0
  next ajI
  ' Preserve ascending unit order in each immutable incoming-move chain.
  for incomingP = 0 to 81
    incomingHead(incomingP) = -1
  next incomingP
  for incomingI = nu - 1 to 0 step -1
    if simKind(incomingI) = 1 then
      incomingNext(incomingI) = incomingHead(simTo(incomingI))
      incomingHead(simTo(incomingI)) = incomingI
    end if
  next incomingI
  ' Reverse insertion preserves ascending support resolution order.
  for ajJ = nu - 1 to 0 step -1
    if simKind(ajJ) = 2 then
      ajTarget = atUnit(simTo(ajJ))
      if ajTarget >= 0 then
        if simKind(ajTarget) <> 1 then
          supportNext(ajJ) = supportHoldHead(ajTarget)
          supportHoldHead(ajTarget) = ajJ
        end if
      end if
    end if
    if simKind(ajJ) = 3 then
      ajTarget = atUnit(simFrom(ajJ))
      if ajTarget >= 0 then
        if simKind(ajTarget) = 1 and simTo(ajTarget) = simTo(ajJ) then
          supportNext(ajJ) = supportMoveHead(ajTarget)
          supportMoveHead(ajTarget) = ajJ
        end if
      end if
    end if
  next ajJ
  for ajI = 0 to nu - 1
    if simKind(ajI) = 1 then
      call resolve(ajI, 0, 0, 0, 0)
      moved(ajI) = answer
    end if
  next ajI
  if adjudicationAborted then
    fallbackAdjudications = fallbackAdjudications + 1
    for ajI = 0 to nu - 1
      moved(ajI) = 0
    next ajI
  end if
  for ajJ = 0 to nu - 1
    if moved(ajJ) then
      ajOccupant = atUnit(simTo(ajJ))
      if ajOccupant >= 0 then
        if moved(ajOccupant) = 0 then dislodged(ajOccupant) = 1
      end if
    end if
  next ajJ
end sub

sub resolve(nr, old, first, second, d)
  ' Reserve native VM call frames for helpers around recursive dependencies.
  if resolveDepth >= 10 or adjudicationAborted then
    adjudicationAborted = 1
    answer = 0
    exit sub
  end if
  resolveDepth = resolveDepth + 1
  if resolveDepth > peakResolveDepth then peakResolveDepth = resolveDepth
  if simState(nr) = 2 then
    answer = simResult(nr)
    resolveDepth = resolveDepth - 1
    exit sub
  end if
  if simState(nr) = 1 then
    first = 0
    for d = 0 to depCount - 1
      if deps(d) = nr then first = 1
    next d
    if first = 0 then
      deps(depCount) = nr
      depCount = depCount + 1
    end if
    answer = simResult(nr)
    resolveDepth = resolveDepth - 1
    exit sub
  end if
  old = depCount
  simResult(nr) = 0
  simState(nr) = 1
  call adjudicateOne(nr)
  first = answer
  if depCount = old then
    if simState(nr) <> 2 then
      simResult(nr) = first
      simState(nr) = 2
    end if
    answer = first
    resolveDepth = resolveDepth - 1
    exit sub
  end if
  if deps(old) <> nr then
    deps(depCount) = nr
    depCount = depCount + 1
    simResult(nr) = first
    answer = first
    resolveDepth = resolveDepth - 1
    exit sub
  end if
  for d = old to depCount - 1
    simState(deps(d)) = 0
  next d
  depCount = old
  simResult(nr) = 1
  simState(nr) = 1
  call adjudicateOne(nr)
  second = answer
  if first = second then
    for d = old to depCount - 1
      simState(deps(d)) = 0
    next d
    depCount = old
    simResult(nr) = first
    simState(nr) = 2
    answer = first
    resolveDepth = resolveDepth - 1
    exit sub
  end if
  for d = old to depCount - 1
    simState(deps(d)) = 0
  next d
  for d = old to depCount - 1
    if simKind(deps(d)) = 1 then
      simResult(deps(d)) = 1
      simState(deps(d)) = 2
    end if
  next d
  depCount = old
  if simKind(nr) = 1 then
    simResult(nr) = 1
    simState(nr) = 2
  end if
  call resolve(nr, 0, 0, 0, 0)
  resolveDepth = resolveDepth - 1
end sub

sub adjudicateOne(nr)
  answer = 1
  if simKind(nr) = 1 then call moveSucceeds(nr, 0, 0, 0, 0)
  if simKind(nr) = 2 or simKind(nr) = 3 then call supportHolds(nr, 0)
end sub

sub supportHolds(nr, a)
  a = incomingHead(parent(ut(nr)))
  do while a >= 0
    if uc(a) <> uc(nr) then
      if simKind(nr) = 3 and parent(ut(a)) = simTo(nr) then
        call resolve(a, 0, 0, 0, 0)
        if answer then
          answer = 0
          exit sub
        end if
      else
        answer = 0
        exit sub
      end if
    end if
    a = incomingNext(a)
  loop
  answer = 1
end sub

sub supportCount(nr, hold, exclude, total, s, finish)
  total = 0
  s = supportMoveHead(nr)
  if hold then s = supportHoldHead(nr)
  do while s >= 0
    if exclude = 0 or uc(s) <> exclude then
      call resolve(s, 0, 0, 0, 0)
      if answer then total = total + 1
    end if
    s = supportNext(s)
  loop
  answer = total
end sub

sub headToHead(nr, j)
  j = atUnit(simTo(nr))
  head = -1
  if j >= 0 then
    if simKind(j) = 1 and simTo(j) = parent(ut(nr)) then head = j
  end if
end sub

sub attackStrength(nr, j, h)
  j = atUnit(simTo(nr))
  call headToHead(nr, 0)
  h = head
  if j < 0 then
    call supportCount(nr, 0, 0, 0, 0, 0)
    answer = 1 + answer
    exit sub
  end if
  if h < 0 and simKind(j) = 1 then
    call resolve(j, 0, 0, 0, 0)
    if answer then
      call supportCount(nr, 0, 0, 0, 0, 0)
      answer = 1 + answer
      exit sub
    end if
  end if
  if uc(j) = uc(nr) then
    answer = 0
    exit sub
  end if
  call supportCount(nr, 0, uc(j), 0, 0, 0)
  answer = 1 + answer
end sub

sub preventStrength(nr, h)
  call headToHead(nr, 0)
  h = head
  if h >= 0 then
    call resolve(h, 0, 0, 0, 0)
    if answer then
      answer = 0
      exit sub
    end if
  end if
  call supportCount(nr, 0, 0, 0, 0, 0)
  answer = 1 + answer
end sub

sub holdStrength(prov, j)
  j = atUnit(prov)
  answer = 0
  if j < 0 then exit sub
  if simKind(j) = 1 then
    call resolve(j, 0, 0, 0, 0)
    answer = 1 - answer
  else
    call supportCount(j, 1, 0, 0, 0, 0)
    answer = 1 + answer
  end if
end sub

sub moveSucceeds(nr, dest, attack, h, other)
  dest = simTo(nr)
  call attackStrength(nr, 0, 0)
  attack = answer
  call headToHead(nr, 0)
  h = head
  if h >= 0 then
    call supportCount(h, 0, 0, 0, 0, 0)
    if attack <= 1 + answer then
      answer = 0
      exit sub
    end if
  else
    call holdStrength(dest, 0)
    if attack <= answer then
      answer = 0
      exit sub
    end if
  end if
  other = incomingHead(dest)
  do while other >= 0
    if other <> nr then
      call preventStrength(other, 0)
      if attack <= answer then
        answer = 0
        exit sub
      end if
    end if
    other = incomingNext(other)
  loop
  answer = 1
end sub

sub scoreFast()
  for sfP = 0 to 81
    occupiedAfter(sfP) = 0
  next sfP
  sfPos = 0
  sfLost = 0
  sfDivisor = vmax(me) \ 30000 + 1
  sfMax = vmax(me) \ sfDivisor
  for sfI = 0 to nu - 1
    if dislodged(sfI) then
      if uc(sfI) = me then sfLost = sfLost + 1
    else
      sfWhere = parent(ut(sfI))
      sfNode = uk(sfI) * 82 + ut(sfI)
      if moved(sfI) then
        sfWhere = simTo(sfI)
        sfNode = uk(sfI) * 82 + simRawTo(sfI)
      end if
      occupiedAfter(sfWhere) = uc(sfI)
      if uc(sfI) = me then sfPos = sfPos + (values(me * 164 + sfNode) \ sfDivisor) / sfMax
    end if
  next sfI
  sfSC = 0
  for sfP = 1 to 75
    if supply(sfP) then
      sfHolder = occupiedAfter(sfP)
      if sfHolder = 0 then sfHolder = owner(sfP)
      if sfHolder = me then sfSC = sfSC + 1
    end if
  next sfP
  score = scWeight * sfSC + posWeight * sfPos - lostWeight * sfLost
end sub





sub chooseAdjustments()
  for caP = 0 to 81
    reserved(caP) = 0
  next caP
  for caActor = 0 to nu + 31
    caBest = -1
    caValue = -2147483647
    for caO = 0 to choiceCount() - 1
      if choiceUnit(caO) = caActor then
        caK = choiceKind(caO)
        caT = choiceTarget(caO)
        caP = parent(caT)
        caAllowed = 1
        if caP > 0 then
          if reserved(caP) then caAllowed = 0
        end if
        if caAllowed then
          caV = -2000000000
          if caK = 10 then caV = -1900000000
          if caK = 6 then caV = -1900000000
          if caK = 5 then caV = values(me * 164 + uk(caActor) * 82 + caT)
          if caK = 7 then caV = values(me * 164 + caT)
          if caK = 8 then caV = values(me * 164 + 82 + caT)
          if caK = 9 then
            caU = atUnit(caP)
            if caU >= 0 then caV = -values(me * 164 + uk(caU) * 82 + ut(caU))
          end if
          if caV > caValue then
            caBest = caO
            caValue = caV
          end if
        end if
      end if
    next caO
    if caBest >= 0 then
      accepted = chooseOrder(caBest)
      caT = choiceTarget(caBest)
      if caT > 0 then reserved(parent(caT)) = 1
    end if
  next caActor
end sub

sub updateBeliefs()
  ' Use only resolved public movement orders, once per recorded phase.
  if pendingActive = 0 then exit sub
  if historyTick() = beliefHistoryTick or historyTick() < 0 then exit sub
  if historyPhase() <> 0 then exit sub
  beliefHistoryTick = historyTick()
  for ubI = 0 to historyCount() - 1
    ubC = historyCountry(ubI)
    ubP = parent(historyOrigin(ubI))
    if ubC <> me and ubP > 0 then
      if pendingCountry(ubP) = ubC and pendingLegal(ubP) > 0 then
        ubK = historyKind(ubI)
        ubT = historyTarget(ubI)
        ubF = historySource(ubI)
        if ubK = 0 then ubT = 0
        ubMatches = 0
        for ubS = 0 to pendingSamples - 1
          ubIndex = ubS * 82 + ubP
          if pendingKind(ubIndex) = ubK and pendingTarget(ubIndex) = ubT and pendingSource(ubIndex) = ubF then ubMatches = ubMatches + 1
        next ubS
        ubSensible = 0
        if ubK = 0 or ubK = 1 then ubSensible = 1
        if ubK = 2 then
          if historyOccupantCountry(ubT) = ubC then ubSensible = 1
        end if
        if ubK = 3 or ubK = 4 then
          if historyOccupantCountry(ubF) = ubC then ubSensible = 1
        end if
        ubCompetent = 0.5 * ubMatches / pendingSamples
        if ubSensible then
          ubCompetent = ubCompetent + 0.5 / pendingSensible(ubP)
        else
          ubCompetent = ubCompetent + 0.02 / pendingLegal(ubP)
        end if
        ubRandom = 1.0 / pendingLegal(ubP)
        ubNumerator = ubCompetent * belief(ubC)
        ubDenominator = ubNumerator + ubRandom * (1.0 - belief(ubC))
        if ubDenominator > 0 then belief(ubC) = ubNumerator / ubDenominator
        if belief(ubC) < 0.02 then belief(ubC) = 0.02
        if belief(ubC) > 0.98 then belief(ubC) = 0.98
        beliefUpdates = beliefUpdates + 1
      end if
    end if
  next ubI
  pendingActive = 0
end sub

sub rememberModel()
  ' Keep bounded sufficient statistics for the next public movement history.
  for rmP = 0 to 81
    pendingCountry(rmP) = 0
    pendingLegal(rmP) = 0
    pendingSensible(rmP) = 0
  next rmP
  pendingSamples = searchSamples
  for rmI = 0 to nu - 1
    if uc(rmI) <> me then
      rmP = parent(ut(rmI))
      pendingCountry(rmP) = uc(rmI)
      pendingLegal(rmP) = oc(rmI)
      for rmO = os(rmI) to os(rmI) + oc(rmI) - 1
        rmSensible = 0
        if ok(rmO) = 0 or ok(rmO) = 1 then rmSensible = 1
        rmUnit = -1
        if ok(rmO) = 2 then rmUnit = atUnit(parent(ot(rmO)))
        if ok(rmO) = 3 or ok(rmO) = 4 then rmUnit = atUnit(parent(of(rmO)))
        if rmUnit >= 0 then
          if uc(rmUnit) = uc(rmI) then rmSensible = 1
        end if
        if rmSensible then pendingSensible(rmP) = pendingSensible(rmP) + 1
      next rmO
      if pendingSensible(rmP) < 1 then pendingSensible(rmP) = 1
    end if
  next rmI
  pendingActive = 1
end sub

sub indexJointOptions()
  ' Hosted port: no lookup table; findOption scans the unit's options.
  lookupEpoch = worldTick() + 1
  exit sub
  if nu > 34 then exit sub
  ixBase = lookupEpoch * 16384
  for ixI = 0 to nu - 1
    for ixO = os(ixI) to os(ixI) + oc(ixI) - 1
      if ok(ixO) = 3 then
        ixSource = atUnit(parent(of(ixO)))
        if ixSource >= 0 then
          ixKey = (ixI * 34 + ixSource) * 82 + parent(ot(ixO))
          ixExisting = indexedSupport(ixKey)
          if ixExisting \ 16384 <> lookupEpoch then indexedSupport(ixKey) = ixBase + ixO + 1
        end if
      end if
    next ixO
  next ixI
end sub






' Recover formatting, then validate every supported arrangement and order.
sub searchBudget()
  ' Leave measured worst-case headroom for completion and guarded repair.
  searchCanContinue = 1
  if estI + 4 * maximumPlanInstructions + 6000000 >= 4000000 then searchCanContinue = 0
  if estW + 4 * maximumPlanWork + 12000000 >= 10000000 then searchCanContinue = 0
  if searchCanContinue = 0 then searchStoppedByBudget = 1
end sub

sub normalize(raw$)
  parsed = 0
  call stripText(ucase$(raw$))
  text$ = stripped$
  if left$(text$, 3) = "```" then
    text$ = mid$(text$, 4)
    if left$(text$, 5) = "DAIDE" then text$ = mid$(text$, 6)
    call stripText(text$)
    text$ = stripped$
  end if
  if left$(text$, 1) = "`" or left$(text$, 1) = chr$(34) then text$ = mid$(text$, 2)
  if left$(text$, 11) = "UNDERSTOOD." then text$ = trim$(mid$(text$, 12))
  for c = 1 to 7
    name$ = ucase$(countryName$(c)) + ":"
    if left$(text$, len(name$)) = name$ then text$ = trim$(mid$(text$, len(name$) + 1))
  next c
  legacy$ = "FRM (" + power$(sender) + " " + power$(me) + "):"
  if left$(text$, len(legacy$)) = legacy$ then text$ = trim$(mid$(text$, len(legacy$) + 1))
  if left$(text$, 1) = "(" and right$(text$, 1) = ")" then text$ = trim$(mid$(text$, 2, len(text$) - 2))
  call stripText(text$)
  text$ = stripped$
  head$ = left$(text$, 3)
  if head$ = "DEC" then
    text$ = "REJ" + mid$(text$, 4)
    head$ = "REJ"
  end if
  if head$ <> "PRP" and head$ <> "YES" and head$ <> "REJ" and head$ <> "FCT" and head$ <> "CCL" and head$ <> "XDO" and head$ <> "PCE" and head$ <> "AND" then exit sub
  depth = 0
  began = 0
  stopAt = 0
  for pos = 4 to len(text$)
    char$ = mid$(text$, pos, 1)
    if char$ = "(" then
      depth = depth + 1
      began = 1
    elseif char$ = ")" then
      depth = depth - 1
      if depth < 0 then exit sub
      if began and depth = 0 then
        stopAt = pos
        exit for
      end if
    end if
  next pos
  if began = 0 then exit sub
  if stopAt = 0 then
    if depth < 1 or depth > 2 then exit sub
    text$ = text$ + string$(depth, ")")
    stopAt = len(text$)
  end if
  call stripText(mid$(text$, stopAt + 1))
  suffix$ = stripped$
  text$ = left$(text$, stopAt)
  if left$(suffix$, 4) = "AND " and head$ = "PRP" then
    text$ = "PRP (AND " + mid$(text$, 5) + " " + trim$(mid$(suffix$, 5)) + ")"
  else
    if left$(suffix$, 1) = ")" then exit sub
    if instr(suffix$, "PRP (") or instr(suffix$, "YES (") or instr(suffix$, "REJ (") or instr(suffix$, "PCE (") or instr(suffix$, "XDO (") then exit sub
  end if
  if head$ = "XDO" or head$ = "PCE" or head$ = "AND" then text$ = "PRP (" + text$ + ")"
  if head$ = "YES" or head$ = "REJ" then
    body$ = trim$(mid$(text$, 6, len(text$) - 6))
    if left$(body$, 3) <> "PRP" then text$ = head$ + " (PRP (" + body$ + "))"
  end if
  call tokenize(text$)
  if tokenError then exit sub
  parsed = 1
end sub

sub stripText(input$)
  firstByte = 1
  lastByte = len(input$)
  while firstByte <= lastByte
    if asc(mid$(input$, firstByte, 1)) > 32 then goto leftTrimmed
    firstByte = firstByte + 1
  wend
leftTrimmed:
  while lastByte >= firstByte
    if asc(mid$(input$, lastByte, 1)) > 32 then goto rightTrimmed
    lastByte = lastByte - 1
  wend
rightTrimmed:
  stripped$ = mid$(input$, firstByte, lastByte - firstByte + 1)
end sub

sub tokenize(text$)
  nt = 0
  sp = 0
  wordStart = 0
  tokenError = 0
  if len(text$) > 1024 then
    tokenError = 1
    exit sub
  end if
  for pos = 1 to len(text$) + 1
    char$ = " "
    if pos <= len(text$) then char$ = mid$(text$, pos, 1)
    if char$ = "(" or char$ = ")" or asc(char$) <= 32 then
      if wordStart > 0 then
        call token(mid$(text$, wordStart, pos - wordStart))
        wordStart = 0
      end if
      if char$ = "(" or char$ = ")" then call token(char$)
    else
      if wordStart = 0 then wordStart = pos
    end if
    if tokenError then exit sub
  next pos
  if sp <> 0 then tokenError = 1
end sub

sub token(word$)
  if nt >= 255 then
    tokenError = 1
    exit sub
  end if
  nt = nt + 1
  tk$(nt) = word$
  mate(nt) = 0
  if word$ = "(" then
    if sp >= 64 then
      tokenError = 1
      exit sub
    end if
    stack(sp) = nt
    sp = sp + 1
  elseif word$ = ")" then
    if sp = 0 then
      tokenError = 1
      exit sub
    end if
    sp = sp - 1
    mate(stack(sp)) = nt
  end if
end sub

sub renderTokens()
  canonical$ = ""
  for ti = 1 to nt
    if ti > 1 and tk$(ti) <> ")" and tk$(ti - 1) <> "(" then canonical$ = canonical$ + " "
    canonical$ = canonical$ + tk$(ti)
  next ti
end sub

sub readLocation()
  location = 0
  location$ = tk$(pi)
  if location$ = "ENG" then
    tk$(pi) = "ECH"
    location$ = "ECH"
  end if
  if location$ = "BOT" then
    tk$(pi) = "GOB"
    location$ = "GOB"
  end if
  if location$ = "LYO" then
    tk$(pi) = "GOL"
    location$ = "GOL"
  end if
  if location$ = "(" then
    if mate(pi) <> pi + 3 then
      valid = 0
      exit sub
    end if
    if tk$(pi + 1) = "BUL" and tk$(pi + 2) = "NCS" then tk$(pi + 2) = "ECS"
    location$ = "(" + tk$(pi + 1) + " " + tk$(pi + 2) + ")"
    pi = pi + 4
  else
    pi = pi + 1
  end if
  for li = 1 to 81
    if loc$(li) = location$ then location = li
  next li
  if location = 0 then valid = 0
end sub

sub readUnit()
  parsedUnit = -1
  if tk$(pi) <> "(" then
    valid = 0
    exit sub
  end if
  unitEnd = mate(pi)
  unitPower = 0
  for ui = 1 to 7
    if tk$(pi + 1) = power$(ui) then unitPower = ui
  next ui
  pi = pi + 2
  if tk$(pi) = "A" or tk$(pi) = "ARMY" then tk$(pi) = "AMY"
  if tk$(pi) = "F" or tk$(pi) = "FLEET" then tk$(pi) = "FLT"
  unitKind = -1
  if tk$(pi) = "AMY" then unitKind = 0
  if tk$(pi) = "FLT" then unitKind = 1
  pi = pi + 1
  call readLocation()
  if pi <> unitEnd then valid = 0
  for ui = 0 to nu - 1
    if uc(ui) = unitPower and uk(ui) = unitKind and ut(ui) = location then parsedUnit = ui
  next ui
  if parsedUnit < 0 then valid = 0
  pi = pi + 1
end sub

sub readOrder(start)
  if nr >= 16 then
    valid = 0
    exit sub
  end if
  orderEnd = mate(start)
  pi = start + 1
  call readUnit()
  requestedUnit = parsedUnit
  verb$ = tk$(pi)
  pi = pi + 1
  requestedVia = 0
  requestedKind = -1
  requestedTarget = 0
  requestedSource = 0
  if verb$ = "HLD" then
    requestedKind = 0
  elseif verb$ = "MTO" then
    requestedKind = 1
    call readLocation()
    requestedTarget = location
  elseif verb$ = "CTO" then
    requestedKind = 1
    requestedVia = 1
    call readLocation()
    requestedTarget = location
    if tk$(pi) = "VIA" and tk$(pi + 1) = "(" then pi = mate(pi + 1) + 1
  elseif verb$ = "CVY" then
    call readUnit()
    if parsedUnit >= 0 then requestedSource = parent(ut(parsedUnit))
    if tk$(pi) <> "CTO" then valid = 0
    pi = pi + 1
    call readLocation()
    requestedKind = 4
    requestedTarget = parent(location)
  elseif verb$ = "SUP" then
    call readUnit()
    carriedUnit = parsedUnit
    if carriedUnit >= 0 then
      requestedKind = 2
      requestedTarget = parent(ut(carriedUnit))
      if tk$(pi) = "MTO" then
        pi = pi + 1
        call readLocation()
        requestedKind = 3
        requestedSource = parent(ut(carriedUnit))
        requestedTarget = parent(location)
      end if
    end if
  end if
  if pi <> orderEnd or requestedKind < 0 or requestedUnit < 0 then valid = 0
  ' Requests are parsed as nonbinding statements, never executed here.
  ' Own orders are subsequently checked against the host legal choices.
  if valid then
    rv(nr) = requestedVia
    ru(nr) = requestedUnit
    rk(nr) = requestedKind
    rt(nr) = requestedTarget
    rs(nr) = requestedSource
    nr = nr + 1
  end if
end sub

sub arrangement(start)
  if tk$(start) <> "(" or mate(start) = 0 then
    valid = 0
    exit sub
  end if
  arrangementEnd = mate(start)
  if tk$(start + 1) = "XDO" then
    if tk$(start + 2) <> "(" or mate(start + 2) <> arrangementEnd - 1 then
      valid = 0
      exit sub
    end if
    call readOrder(start + 2)
  elseif tk$(start + 1) = "PCE" then
    if mate(start + 2) <> start + 5 or arrangementEnd <> start + 6 then
      valid = 0
      exit sub
    end if
    firstPower = 0
    secondPower = 0
    for ai = 1 to 7
      if tk$(start + 3) = power$(ai) then firstPower = ai
      if tk$(start + 4) = power$(ai) then secondPower = ai
    next ai
    if (firstPower = me and secondPower = sender) or (secondPower = me and firstPower = sender) then
      requestedPeace = sender
    else
      valid = 0
    end if
  elseif tk$(start + 1) = "DMZ" then
    dmzPowerStart = start + 2
    dmzPlaceStart = mate(dmzPowerStart) + 1
    if tk$(dmzPowerStart) <> "(" or tk$(dmzPlaceStart) <> "(" then
      valid = 0
      exit sub
    end if
    if mate(dmzPowerStart) <> dmzPowerStart + 3 or mate(dmzPlaceStart) <> arrangementEnd - 1 then
      valid = 0
      exit sub
    end if
    dmzMe = 0
    dmzPeer = 0
    for dmzI = dmzPowerStart + 1 to dmzPowerStart + 2
      if tk$(dmzI) = power$(me) then dmzMe = dmzMe + 1
      if tk$(dmzI) = power$(sender) then dmzPeer = dmzPeer + 1
    next dmzI
    if dmzMe <> 1 or dmzPeer <> 1 then valid = 0
    pi = dmzPlaceStart + 1
    if pi = mate(dmzPlaceStart) then valid = 0
    while pi < mate(dmzPlaceStart) and valid
      call readLocation()
      if location > 0 then pressMessageDmz(parent(location)) = 1
    wend
  elseif tk$(start + 1) = "AND" then
    clause = start + 2
    bound = mate(start)
    ' The current port accepts a flat explicit conjunction, never alternatives.
    while clause < bound and valid
      if tk$(clause + 1) <> "PCE" and tk$(clause + 1) <> "XDO" and tk$(clause + 1) <> "DMZ" then
        valid = 0
      else
        nextClause = mate(clause) + 1
        call arrangement(clause)
        clause = nextClause
      end if
    wend
    if clause <> bound then valid = 0
  else
    valid = 0
  end if
end sub


sub handleMessage()
  valid = 0
  nr = 0
  requestedPeace = 0
  if nt < 4 or tk$(2) <> "(" or mate(2) <> nt then exit sub
  root$ = tk$(1)
  start = 2
  if root$ = "YES" or root$ = "REJ" or root$ = "CCL" then
    if tk$(3) <> "PRP" or tk$(4) <> "(" or mate(4) <> nt - 1 then exit sub
    start = 4
  elseif root$ = "FCT" then
    if tk$(3) = "NAR" or tk$(3) = "NOT" then
      if tk$(4) <> "(" or mate(4) <> nt - 1 then exit sub
      start = 4
      pressNegative = 1
    end if
  elseif root$ <> "PRP" then
    exit sub
  end if
  valid = 1
  call arrangement(start)
  if valid then call renderTokens()
end sub

sub pressSend(peer, message$)
  ' Reserve two host sends and never reply to replies.
  pressSent = 0
  if pressSends >= 30 then exit sub
  if len(message$) = 0 or len(message$) > 1024 then exit sub
  pressSent = sendChat(countrySeat(peer), message$)
  if pressSent then
    pressSends = pressSends + 1
    pressMessagesSent = pressMessagesSent + 1
  end if
end sub

sub pressCanEvaluate()
  ' Retain measured headroom before every complete scenario evaluation.
  pressCan = 1
  if estI + 6 * maximumPlanInstructions + 1500000 >= 4000000 then pressCan = 0
  if estW + 6 * maximumPlanWork + 3000000 >= 10000000 then pressCan = 0
end sub

sub pressForbidden(pfOption)
  pressForbiddenOrder = 0
  if ok(pfOption) <> 1 and ok(pfOption) <> 3 then exit sub
  pfTarget = parent(ot(pfOption))
  if pressDmz(pfTarget) then pressForbiddenOrder = 1
  if pressTesting and pressMessageDmz(pfTarget) then pressForbiddenOrder = 1
  pfCountry = owner(pfTarget)
  if atUnit(pfTarget) >= 0 then pfCountry = uc(atUnit(pfTarget))
  if pfCountry > 0 and pfCountry <> me then
    if pressPeace(pfCountry) then pressForbiddenOrder = 1
    if pressTesting and requestedPeace = pfCountry then pressForbiddenOrder = 1
  end if
end sub

sub pressCheckPlan()
  pressLegal = 1
  for plI = 0 to nu - 1
    if uc(plI) = me then
      if pressPin(plI) >= 0 and trial(plI) <> pressPin(plI) then pressLegal = 0
      if pressTesting and pressCandidate(plI) >= 0 then
        if trial(plI) <> pressCandidate(plI) then pressLegal = 0
      end if
      call pressForbidden(trial(plI))
      if pressForbiddenOrder then pressLegal = 0
    end if
  next plI
end sub

sub pressConstrain()
  for pcI = 0 to nu - 1
    if uc(pcI) = me then
      call pressForbidden(trial(pcI))
      if pressForbiddenOrder then trial(pcI) = holdOption(pcI)
      if pressPin(pcI) >= 0 then trial(pcI) = pressPin(pcI)
      if pressTesting and pressCandidate(pcI) >= 0 then trial(pcI) = pressCandidate(pcI)
    end if
  next pcI
end sub

sub pressForeign(pfSample, pfUnit, pfOriginal)
  ' Stable stratified trust draws keep all deal comparisons on the same samples.
  pressForeignOption = pfOriginal
  pfPower = uc(pfUnit)
  pfTrust = pressTrust(pfPower)
  pfExpected = pressExpected(pfUnit)
  pfAlly = pressPeace(pfPower)
  if pressMode = 2 and pfPower = sender then
    pfExpected = -1
    pfAlly = 0
    pfTrust = 0
  elseif pressMode = 1 or pressMode = 3 then
    if pfPower = sender then
      if pressTheirCandidate(pfUnit) >= 0 then pfExpected = pressTheirCandidate(pfUnit)
      pfTrust = 1
      pfAlly = 1
    end if
  end if
  pfDraw = (((pfSample * 7 + pfUnit * 3 + tick) mod 16) + 0.5) / 16.0
  if pfDraw < pfTrust then
    if pfExpected >= 0 then
      pressForeignOption = pfExpected
    elseif pfAlly and (ok(pfOriginal) = 1 or ok(pfOriginal) = 3) then
      pfDestination = parent(ot(pfOriginal))
      pfOurs = owner(pfDestination) = me
      if atUnit(pfDestination) >= 0 then
        if uc(atUnit(pfDestination)) = me then pfOurs = 1
      end if
      if pfOurs then pressForeignOption = holdOption(pfUnit)
    end if
  end if
end sub

sub pressImprove()
  ' Reuse the phase's original scenarios and score, preserving every own pin.
  call pressConstrain()
  call pressCheckPlan()
  if pressLegal = 0 then exit sub
  call evaluatePlan()
  pressWorkingScore = evaluation
  for pwI = 0 to nu - 1
    if uc(pwI) = me then best(pwI) = trial(pwI)
  next pwI
  pressProbes = 0
  for pwPass = 1 to 2
    pwChanged = 0
    for pwActor = 0 to nu - 1
      if uc(pwActor) = me then
        for pwO = os(pwActor) to os(pwActor) + oc(pwActor) - 1
          call pressCanEvaluate()
          if pressCan = 0 or pressProbes >= 64 then exit for
          if pwO <> best(pwActor) then
            for pwI = 0 to nu - 1
              trial(pwI) = best(pwI)
            next pwI
            trial(pwActor) = pwO
            call pressCheckPlan()
            if pressLegal then
              call evaluatePlan()
              pressProbes = pressProbes + 1
              if evaluation > pressWorkingScore + 0.0001 then
                best(pwActor) = pwO
                pressWorkingScore = evaluation
                pwChanged = 1
              end if
            end if
          end if
        next pwO
      end if
    next pwActor
    if pwChanged = 0 then exit for
  next pwPass
end sub

sub pressSubmit()
  ' Stage the complete own vector, restoring old issued orders on refusal.
  pressCommitted = 1
  for psI = 0 to nu - 1
    if uc(psI) = me then
      psHost = hostChoice(best(psI))
      if psHost < 0 then
        pressCommitted = 0
      else
        if chooseOrder(psHost) = 0 then pressCommitted = 0
      end if
      if pressCommitted = 0 then exit for
    end if
  next psI
  if pressCommitted = 0 then
    for psI = 0 to nu - 1
      if uc(psI) = me then
        best(psI) = pressSaved(psI)
        if hostChoice(best(psI)) >= 0 then restored = chooseOrder(hostChoice(best(psI)))
      end if
    next psI
  end if
end sub

sub pressReconsider()
  call pressCanEvaluate()
  if pressCan = 0 then exit sub
  for prI = 0 to nu - 1
    pressSaved(prI) = best(prI)
    trial(prI) = best(prI)
  next prI
  call pressImprove()
  call pressSubmit()
  pressReplans = pressReplans + pressCommitted
end sub

sub pressFind(pu, pk, pt, ps, pv)
  pressOption = -1
  for po = os(pu) to os(pu) + oc(pu) - 1
    poTarget = parent(ot(po)) = parent(pt)
    if pk = 0 then poTarget = 1
    if pk = 1 then poTarget = ot(po) = pt
    if ok(po) = pk and poTarget and of(po) = ps and ov(po) = pv then
      pressOption = po
      exit sub
    end if
  next po
  for px = 0 to pressExtraCount - 1
    po = pressExtraOption(px)
    if pressExtraUnit(px) = pu and ok(po) = pk and ot(po) = pt and of(po) = ps and ov(po) = pv then
      pressOption = po
      exit sub
    end if
  next px
  ' Foreign convoy declarations need the existing one-fleet model's geometry.
  if uc(pu) = me or pressExtraCount >= 32 or optionSize >= 8192 then exit sub
  if pk <> 4 and (pk <> 1 or pv <> 1) then exit sub
  pxArmy = pu
  pxOrigin = parent(ut(pu))
  if pk = 4 then
    pxArmy = atUnit(parent(ps))
    pxOrigin = parent(ps)
    if uk(pu) <> 1 or terrain(ut(pu)) <> 2 then exit sub
  end if
  if pxArmy < 0 then exit sub
  if uk(pxArmy) <> 0 or terrain(pxOrigin) <> 1 or terrain(parent(pt)) <> 1 then exit sub
  pxLegal = 0
  for pxFleet = 0 to nu - 1
    if uk(pxFleet) = 1 and terrain(ut(pxFleet)) = 2 and ur(pxFleet) = 0 then
      if pk <> 4 or pxFleet = pu then
        pxFrom = 0
        pxTo = 0
        pxNode = 82 + ut(pxFleet)
        for pxEdge = edgeStart(pxNode) to edgeStart(pxNode) + edgeCount(pxNode) - 1
          if parent(edgeTo(pxEdge) mod 82) = pxOrigin then pxFrom = 1
          if parent(edgeTo(pxEdge) mod 82) = parent(pt) then pxTo = 1
        next pxEdge
        if pxFrom and pxTo then pxLegal = 1
      end if
    end if
  next pxFleet
  if pxLegal = 0 then exit sub
  pressOption = optionSize
  ok(optionSize) = pk
  ot(optionSize) = pt
  of(optionSize) = ps
  ov(optionSize) = pv
  hostChoice(optionSize) = -1
  pressExtraUnit(pressExtraCount) = pu
  pressExtraOption(pressExtraCount) = optionSize
  pressExtraCount = pressExtraCount + 1
  optionSize = optionSize + 1
end sub

sub pressAssess()
  ' Compare both honor, partner betrayal and our free alternative explicitly.
  pressDealAccepted = 0
  call pressCanEvaluate()
  if pressCan = 0 then exit sub
  for paI = 0 to nu - 1
    pressSaved(paI) = best(paI)
    trial(paI) = best(paI)
    pressCandidate(paI) = -1
    pressTheirCandidate(paI) = -1
  next paI
  pressValidDeal = 1
  for paR = 0 to nr - 1
    paU = ru(paR)
    if uc(paU) <> me and uc(paU) <> sender then pressValidDeal = 0
    call pressFind(paU, rk(paR), rt(paR), rs(paR), rv(paR))
    if pressOption < 0 then
      pressValidDeal = 0
    elseif uc(paU) = me then
      if pressPin(paU) >= 0 and pressPin(paU) <> pressOption then pressValidDeal = 0
      if pressCandidate(paU) >= 0 and pressCandidate(paU) <> pressOption then pressValidDeal = 0
      pressCandidate(paU) = pressOption
    else
      if pressTheirCandidate(paU) >= 0 and pressTheirCandidate(paU) <> pressOption then pressValidDeal = 0
      pressTheirCandidate(paU) = pressOption
    end if
  next paR
  paNeeded = 0
  for paI = 0 to nu - 1
    if pressCandidate(paI) >= 0 then paNeeded = paNeeded + 1
  next paI
  if pressPactCount + paNeeded > 64 then pressValidDeal = 0
  if pressValidDeal = 0 then exit sub
  pressMode = 0
  call evaluatePlan()
  pressBaseValue = evaluation
  pressBaseWorst = worstScore
  pressMode = 1
  pressTesting = 1
  call pressConstrain()
  call pressCheckPlan()
  if pressLegal = 0 then
    pressMode = 0
    pressTesting = 0
    exit sub
  end if
  call pressCanEvaluate()
  if pressCan = 0 then
    pressMode = 0
    pressTesting = 0
    exit sub
  end if
  call pressImprove()
  for paI = 0 to nu - 1
    pressDealPlan(paI) = best(paI)
    trial(paI) = best(paI)
  next paI
  pressHonourValue = pressWorkingScore
  pressCan = 1
  if estI + 3 * maximumPlanInstructions + 500000 >= 4000000 then pressCan = 0
  if estW + 3 * maximumPlanWork + 1000000 >= 10000000 then pressCan = 0
  if pressCan then
    pressMode = 2
    call evaluatePlan()
    pressBetrayValue = evaluation
    pressBetrayWorst = worstScore
    pressMode = 3
    pressTesting = 0
    for paI = 0 to nu - 1
      trial(paI) = pressSaved(paI)
    next paI
    call evaluatePlan()
    pressFreeValue = evaluation
    if pressHonourValue >= pressBaseValue - 0.5 and pressHonourValue >= pressFreeValue - 0.5 then
      if pressBetrayValue >= pressBaseValue - 2 then pressDealAccepted = 1
    end if
    if richardPress and pressBetrayWorst < pressBaseWorst - 0.5 then pressDealAccepted = 0
    pressAssessed = pressAssessed + 1
  end if
  pressMode = 0
  pressTesting = 0
  for paI = 0 to nu - 1
    best(paI) = pressSaved(paI)
  next paI
  if pressDealAccepted then
    for paI = 0 to nu - 1
      best(paI) = pressDealPlan(paI)
    next paI
    call pressSubmit()
    if pressCommitted = 0 then
      pressDealAccepted = 0
      exit sub
    end if
    for paI = 0 to nu - 1
      if pressCandidate(paI) >= 0 then
        call pressRememberPact(paI, pressCandidate(paI), sender, canonical$)
      end if
      if pressTheirCandidate(paI) >= 0 then
        pressExpected(paI) = pressTheirCandidate(paI)
        pressExpectedText$(paI) = canonical$
        call pressAudit(paI)
      end if
    next paI
    if requestedPeace then pressPeace(sender) = 1
    for paP = 1 to 81
      if pressMessageDmz(paP) then
        if pressDmz(paP) = 0 or pressDmz(paP) = sender then
          pressDmz(paP) = sender
        else
          pressDmz(paP) = -1
        end if
      end if
    next paP
    pressAccepted = pressAccepted + 1
  end if
end sub

sub pressReceive()
  if root$ = "PRP" then
    pressSeenIndex = -1
    for pmI = 0 to pressSeenCount - 1
      if pressSeenPeer(pmI) = sender and pressSeen$(pmI) = canonical$ then pressSeenIndex = pmI
    next pmI
    if pressSeenIndex >= 0 then exit sub
    if pressSeenCount >= 64 then exit sub
    pressSeenIndex = pressSeenCount
    pressSeenCount = pressSeenCount + 1
    pressSeen$(pressSeenIndex) = canonical$
    pressSeenPeer(pressSeenIndex) = sender
    sliceDealState(pressSeenIndex) = 0
    sliceDone = 0
  elseif root$ = "YES" or root$ = "REJ" then
    pressInner$ = mid$(canonical$, 6, len(canonical$) - 6)
    if pressOutgoing$(sender) <> "" and pressInner$ = pressOutgoing$(sender) then
      if root$ = "YES" then
        pmActor = pressAskedActor(sender)
        pmCurrent = 1
        if requestedPeace then
          call pressPeaceCompatible(sender)
          if pressCompatible = 0 then pmCurrent = 0
        end if
        if pmActor >= 0 then
          if best(pmActor) <> pressAskedMove(sender) then pmCurrent = 0
          if pressPactCount >= 64 then pmCurrent = 0
        end if
        if pmCurrent = 0 then
          call pressSend(sender, "CCL (" + pressOutgoing$(sender) + ")")
          pressOutgoing$(sender) = ""
          exit sub
        end if
        if requestedPeace then pressPeace(sender) = 1
        if pmActor >= 0 then
          call pressRememberPact(pmActor, best(pmActor), sender, pressInner$)
          call pressOrder(pmActor, best(pmActor))
          if pressOrder$ <> "" then call pressSend(sender, "FCT (XDO " + pressOrder$ + ")")
        end if
        for pmR = 0 to nr - 1
          pmU = ru(pmR)
          if uc(pmU) = sender then
            call pressFind(pmU, rk(pmR), rt(pmR), rs(pmR), rv(pmR))
            if pressOption >= 0 then
              pressExpected(pmU) = pressOption
              pressExpectedText$(pmU) = pressInner$
              call pressAudit(pmU)
            end if
          end if
        next pmR
        pressConfirmed = pressConfirmed + 1
      else
        pressRejected$(sender) = pressInner$
      end if
      pressOutgoing$(sender) = ""
      pressDirty = 1
    end if
  elseif root$ = "FCT" and pressNegative = 0 then
    for pmR = 0 to nr - 1
      pmU = ru(pmR)
      if uc(pmU) = sender then
        call pressFind(pmU, rk(pmR), rt(pmR), rs(pmR), rv(pmR))
        if pressOption >= 0 then
          pressExpected(pmU) = pressOption
          pressExpectedText$(pmU) = canonical$
          call pressAudit(pmU)
          pressDirty = 1
          pressAnnouncements = pressAnnouncements + 1
        end if
      end if
    next pmR
  elseif root$ = "FCT" and pressNegative and requestedPeace > 0 then
    pressPeace(sender) = 0
    pressDirty = 1
  elseif root$ = "CCL" then
    pressInner$ = mid$(canonical$, 6, len(canonical$) - 6)
    for pmPact = 0 to pressPactCount - 1
      if pressPactPeer(pmPact) = sender and pressPactText$(pmPact) = pressInner$ then
        pressPactLive(pmPact) = 0
        pressDirty = 1
      end if
    next pmPact
    for pmU = 0 to nu - 1
      if uc(pmU) = me then
        pressPin(pmU) = -1
        pressPinPeer(pmU) = 0
        pressPinText$(pmU) = ""
        for pmPact = 0 to pressPactCount - 1
          if pressPactLive(pmPact) and pressPactUnit(pmPact) = pmU then
            pressPin(pmU) = pressPactOrder(pmPact)
            pressPinPeer(pmU) = pressPactPeer(pmPact)
            pressPinText$(pmU) = pressPactText$(pmPact)
          end if
        next pmPact
      end if
      if uc(pmU) = sender and pressExpectedText$(pmU) = pressInner$ then
        pressExpected(pmU) = -1
        pressAuditPending(pmU) = 0
        pressDirty = 1
      end if
    next pmU
    if requestedPeace then pressPeace(sender) = 0
    for pmP = 1 to 81
      if pressMessageDmz(pmP) and pressDmz(pmP) = sender then pressDmz(pmP) = 0
    next pmP
  end if
end sub

sub pressUnit(pu)
  puKind$ = "AMY"
  if uk(pu) = 1 then puKind$ = "FLT"
  pressUnit$ = "(" + power$(uc(pu)) + " " + puKind$ + " " + loc$(ut(pu)) + ")"
end sub

sub pressOrder(pu, po)
  call pressUnit(pu)
  pressOrder$ = "(" + pressUnit$
  if ok(po) = 0 then
    pressOrder$ = pressOrder$ + " HLD)"
  elseif ok(po) = 1 and ov(po) = 0 then
    pressOrder$ = pressOrder$ + " MTO " + loc$(ot(po)) + ")"
  elseif ok(po) = 2 or ok(po) = 3 then
    puHelp = atUnit(parent(ot(po)))
    if ok(po) = 3 then puHelp = atUnit(parent(of(po)))
    if puHelp < 0 then
      pressOrder$ = ""
      exit sub
    end if
    call pressUnit(puHelp)
    pressOrder$ = pressOrder$ + " SUP " + pressUnit$
    if ok(po) = 3 then pressOrder$ = pressOrder$ + " MTO " + loc$(ot(po))
    pressOrder$ = pressOrder$ + ")"
  else
    pressOrder$ = ""
  end if
end sub

sub pressMakeOffers()
  if 0 = 0 and round >= negotiationLimit() - 1 then exit sub
  for moPeer = 1 to 7
    moOldActor = pressAskedActor(moPeer)
    if pressOutgoing$(moPeer) <> "" and moOldActor >= 0 then
      if best(moOldActor) <> pressAskedMove(moPeer) then
        call pressSend(moPeer, "CCL (" + pressOutgoing$(moPeer) + ")")
        if pressSent then pressOutgoing$(moPeer) = ""
      end if
    end if
    if moPeer <> me and pressOutgoing$(moPeer) = "" and pressAsked(moPeer) < 2 then
      moScore = -1
      moText$ = ""
      moChosenActor = -1
      for moOwn = 0 to nu - 1
        if uc(moOwn) = me then
          moAttack = best(moOwn)
          if ok(moAttack) = 1 and ov(moAttack) = 0 then
            for moDonor = 0 to nu - 1
              if uc(moDonor) = moPeer and ur(moDonor) = 0 then
                call pressFind(moDonor, 3, parent(ot(moAttack)), parent(ut(moOwn)), 0)
                if pressOption >= 0 then
                  call pressOrder(moDonor, pressOption)
                  moProposal$ = "PRP (XDO " + pressOrder$ + ")"
                  moValue = 1 + 10 * supply(parent(ot(moAttack)))
                  if pressOrder$ <> "" and moProposal$ <> pressRejected$(moPeer) and moValue > moScore then
                    moScore = moValue
                    moText$ = moProposal$
                    moChosenActor = moOwn
                    moChosenMove = moAttack
                  end if
                end if
              end if
            next moDonor
          end if
        end if
      next moOwn
      if moText$ = "" and pressPeaceAsked(moPeer) = 0 and pressPeace(moPeer) = 0 then
        moNear = 0
        for moI = 0 to nu - 1
          if uc(moI) = moPeer then
            for moJ = 0 to nu - 1
              if uc(moJ) = me then
                if reach(me * 82 + parent(ut(moI))) > 0 or reach(moPeer * 82 + parent(ut(moJ))) > 0 then moNear = 1
              end if
            next moJ
          end if
        next moI
        moSafe = 1
        for moI = 0 to nu - 1
          if uc(moI) = me then
            moO = best(moI)
            if ok(moO) = 1 or ok(moO) = 3 then
              moP = parent(ot(moO))
              if owner(moP) = moPeer then moSafe = 0
              if atUnit(moP) >= 0 then
                if uc(atUnit(moP)) = moPeer then moSafe = 0
              end if
            end if
          end if
        next moI
        if moNear and moSafe then
          moText$ = "PRP (PCE (" + power$(me) + " " + power$(moPeer) + "))"
          pressPeaceAsked(moPeer) = 1
        end if
      end if
      if moText$ <> "" then
        call pressSend(moPeer, moText$)
        if pressSent then
          ' Canonical tokens make exact reply matching independent of spacing.
          moSavedSender = sender
          sender = moPeer
          call tokenize(moText$)
          call renderTokens()
          pressOutgoing$(moPeer) = canonical$
          sender = moSavedSender
          pressAsked(moPeer) = pressAsked(moPeer) + 1
          pressAskedActor(moPeer) = moChosenActor
          pressAskedMove(moPeer) = moChosenMove
        end if
      end if
    end if
  next moPeer
end sub

sub pressRememberPact(ppUnit, ppOrder, ppPeer, ppText$)
  ' Separate records prevent one cancellation from releasing another promise.
  ppFound = 0
  for pp = 0 to pressPactCount - 1
    if pressPactLive(pp) and pressPactUnit(pp) = ppUnit and pressPactPeer(pp) = ppPeer and pressPactText$(pp) = ppText$ then ppFound = 1
  next pp
  if ppFound = 0 and pressPactCount < 64 then
    pp = pressPactCount
    pressPactUnit(pp) = ppUnit
    pressPactPeer(pp) = ppPeer
    pressPactOrder(pp) = ppOrder
    pressPactText$(pp) = ppText$
    pressPactLive(pp) = 1
    pressPactCount = pressPactCount + 1
  end if
  pressPin(ppUnit) = ppOrder
  pressPinPeer(ppUnit) = ppPeer
  pressPinText$(ppUnit) = ppText$
end sub

sub pressPeaceCompatible(ppPeer)
  pressCompatible = 1
  for ppUnit = 0 to nu - 1
    if uc(ppUnit) = me and pressPin(ppUnit) >= 0 then
      ppOrder = pressPin(ppUnit)
      if ok(ppOrder) = 1 or ok(ppOrder) = 3 then
        ppPlace = parent(ot(ppOrder))
        if owner(ppPlace) = ppPeer then pressCompatible = 0
        if atUnit(ppPlace) >= 0 then
          if uc(atUnit(ppPlace)) = ppPeer then pressCompatible = 0
        end if
      end if
    end if
  next ppUnit
end sub

sub pressAudit(pau)
  if pressExpected(pau) < 0 then exit sub
  pauOption = pressExpected(pau)
  pressAuditCountry(pau) = uc(pau)
  pressAuditType(pau) = uk(pau)
  pressAuditOrigin(pau) = ut(pau)
  pressAuditKind(pau) = ok(pauOption)
  pressAuditTarget(pau) = ot(pauOption)
  if ok(pauOption) = 0 then pressAuditTarget(pau) = 0
  pressAuditSource(pau) = of(pauOption)
  pressAuditPending(pau) = 1
end sub

sub pressLearn()
  ' Fulfillment is the published order, not whether the move succeeded.
  if historyTick() < 0 or historyPhase() <> 0 then exit sub
  if pressLearnedReady and pressLearnedTick = historyTick() then exit sub
  pressLearnedTick = historyTick()
  pressLearnedReady = 1
  for leU = 0 to 63
    if pressAuditPending(leU) then
      leFound = 0
      leMatch = 0
      for leH = 0 to historyCount() - 1
        if historyCountry(leH) = pressAuditCountry(leU) and historyUnitType(leH) = pressAuditType(leU) and historyOrigin(leH) = pressAuditOrigin(leU) then
          leFound = 1
          if historyKind(leH) = pressAuditKind(leU) and historyTarget(leH) = pressAuditTarget(leU) and historySource(leH) = pressAuditSource(leU) then leMatch = 1
        end if
      next leH
      if leFound then
        lePeer = pressAuditCountry(leU)
        pressTrust(lePeer) = 0.9 * pressTrust(lePeer) + 0.1 * leMatch
        if pressTrust(lePeer) < 0.1 then pressTrust(lePeer) = 0.1
        if pressTrust(lePeer) > 0.95 then pressTrust(lePeer) = 0.95
        pressTrustUpdates = pressTrustUpdates + 1
      end if
      pressAuditPending(leU) = 0
    end if
  next leU
end sub

sub sliceValuesBegin()
  ' David Norman proximity recurrence, with integer floors below one raw unit.
  for cvI = 0 to 655
    reach(cvI) = 0
  next cvI
  for cvI = 0 to nu - 1
    if ur(cvI) = 0 then
      for cvP = 0 to 81
        reserved(cvP) = 0
      next cvP
      cvN = uk(cvI) * 82 + ut(cvI)
      for cvE = edgeStart(cvN) to edgeStart(cvN) + edgeCount(cvN) - 1
        cvP = parent(edgeTo(cvE) mod 82)
        if reserved(cvP) = 0 then reach(uc(cvI) * 82 + cvP) = reach(uc(cvI) * 82 + cvP) + 1
        reserved(cvP) = 1
      next cvE
    end if
  next cvI
  neutral = 0
  for cvP = 1 to 81
    if supply(cvP) and owner(cvP) = 0 then neutral = neutral + 1
  next cvP
  sizes(0) = neutral * neutral + 4 * neutral + 16
  for cvC = 1 to 7
    cvS = centerCount(cvC)
    sizes(cvC) = cvS * cvS + 4 * cvS + 16
  next cvC
end sub

sub sliceValuesStep()
  cvC = sliceValueCountry
    for cvP = 1 to 75
      strength(cvP) = reach(cvC * 82 + cvP)
      competition(cvP) = 0
      defense(cvP) = 0
      for cvOther = 1 to 7
        if cvOther <> cvC then
          if reach(cvOther * 82 + cvP) > competition(cvP) then competition(cvP) = reach(cvOther * 82 + cvP)
          if supply(cvP) and owner(cvP) = cvC and reach(cvOther * 82 + cvP) > 0 then
            if sizes(cvOther) > defense(cvP) then defense(cvP) = sizes(cvOther)
          end if
        end if
      next cvOther
      cvAttack = 0
      if supply(cvP) and owner(cvP) <> cvC then cvAttack = sizes(owner(cvP))
      if season() = 0 or phase() = 2 then
        prox(cvP) = cvAttack * 2800 + defense(cvP) * 1200
      else
        prox(cvP) = cvAttack * 2400 + defense(cvP) * 1600
      end if
      provinceValue(cvC * 82 + cvP) = 0
    next cvP
    for cvDepth = 0 to 9
      cvW = 1
      if cvDepth = 0 then
        cvW = 1000
        if season() = 0 and phase() <> 2 then cvW = 100
      end if
      if cvDepth = 1 then
        cvW = 100
        if season() = 0 and phase() <> 2 then cvW = 1000
      end if
      if cvDepth = 2 then cvW = 30
      if cvDepth = 3 then cvW = 10
      if cvDepth = 4 then cvW = 6
      if cvDepth = 5 then cvW = 5
      if cvDepth = 6 then cvW = 4
      if cvDepth = 7 then cvW = 3
      if cvDepth = 8 then cvW = 2
      for cvP = 1 to 75
        provinceValue(cvC * 82 + cvP) = provinceValue(cvC * 82 + cvP) + (prox(cvP) \ 64) * cvW + (prox(cvP) mod 64) * cvW \ 64
      next cvP
      if cvDepth < 9 then
        for cvP = 1 to 75
          cvTotal = prox(cvP)
          for cvJ = provinceEdgeStart(cvP) to provinceEdgeStart(cvP) + provinceEdgeCount(cvP) - 1
            cvTotal = cvTotal + prox(provinceEdgeSource(cvJ)) * provinceEdgeWeight(cvJ)
          next cvJ
          proxNext(cvP) = cvTotal \ 5
        next cvP
        for cvP = 1 to 75
          prox(cvP) = proxNext(cvP)
        next cvP
      end if
    next cvDepth
    vmax(cvC) = 1
    for cvN = 1 to 163
      values(cvC * 164 + cvN) = 0
      if nodeValid(cvN) then
        cvP = parent(cvN mod 82)
        cvValue = provinceValue(cvC * 82 + cvP)
        if phase() = 2 then
          cvValue = cvValue + defense(cvP) * 1000 \ 16
        else
          cvValue = cvValue + (strength(cvP) - competition(cvP)) * 1000 \ 16
        end if
        values(cvC * 164 + cvN) = cvValue
        if cvValue > vmax(cvC) then vmax(cvC) = cvValue
      end if
    next cvN
  sliceValueCountry = sliceValueCountry + 1
end sub

sub sliceOptionsStep()
  poI = sliceOptionUnit
    os(poI) = optionSize
    oc(poI) = 0
    greedyStart(poI) = greedySize
    greedyCount(poI) = 0
    if uc(poI) = me then
      for poH = 0 to choiceCount() - 1
        if choiceUnit(poH) = poI then call appendOption(poI, choiceKind(poH), choiceTarget(poH), choiceSource(poH), choiceViaConvoy(poH), poH)
      next poH
    else
      call appendOption(poI, 0, ut(poI), 0, 0, -1)
      poN = uk(poI) * 82 + ut(poI)
      for poE = edgeStart(poN) to edgeStart(poN) + edgeCount(poN) - 1
        call appendOption(poI, 1, edgeTo(poE) mod 82, 0, 0, -1)
      next poE
      for poJ = 0 to nu - 1
        if poJ <> poI then
          for poE = edgeStart(poN) to edgeStart(poN) + edgeCount(poN) - 1
            if parent(edgeTo(poE) mod 82) = parent(ut(poJ)) then call appendOption(poI, 2, parent(ut(poJ)), 0, 0, -1)
          next poE
          poOtherN = uk(poJ) * 82 + ut(poJ)
          for poOtherE = edgeStart(poOtherN) to edgeStart(poOtherN) + edgeCount(poOtherN) - 1
            poTarget = parent(edgeTo(poOtherE) mod 82)
            for poE = edgeStart(poN) to edgeStart(poN) + edgeCount(poN) - 1
              if parent(edgeTo(poE) mod 82) = poTarget then call appendOption(poI, 3, poTarget, parent(ut(poJ)), 0, -1)
            next poE
          next poOtherE
        end if
      next poJ
    end if
  sliceOptionUnit = sliceOptionUnit + 1
end sub

sub sliceAdjustmentStep()
  caActor = sliceAdjustmentActor
    caBest = -1
    caValue = -2147483647
    for caO = 0 to choiceCount() - 1
      if choiceUnit(caO) = caActor then
        caK = choiceKind(caO)
        caT = choiceTarget(caO)
        caP = parent(caT)
        caAllowed = 1
        if caP > 0 then
          if reserved(caP) then caAllowed = 0
        end if
        if caAllowed then
          caV = -2000000000
          if caK = 10 then caV = -1900000000
          if caK = 6 then caV = -1900000000
          if caK = 5 then caV = values(me * 164 + uk(caActor) * 82 + caT)
          if caK = 7 then caV = values(me * 164 + caT)
          if caK = 8 then caV = values(me * 164 + 82 + caT)
          if caK = 9 then
            caU = atUnit(caP)
            if caU >= 0 then caV = -values(me * 164 + uk(caU) * 82 + ut(caU))
          end if
          if caV > caValue then
            caBest = caO
            caValue = caV
          end if
        end if
      end if
    next caO
    if caBest >= 0 then
      accepted = chooseOrder(caBest)
      caT = choiceTarget(caBest)
      if caT > 0 then reserved(parent(caT)) = 1
    end if
  sliceAdjustmentActor = sliceAdjustmentActor + 1
end sub

sub sliceScenario()
  epSample = sliceEvalSample
    for epI = 0 to nu - 1
      epO = trial(epI)
      if uc(epI) <> me then
        epO = sampled(epSample * 64 + epI)
        call pressForeign(epSample, epI, epO)
        epO = pressForeignOption
      end if
      simKind(epI) = ok(epO)
      simTo(epI) = parent(ot(epO))
      simRawTo(epI) = ot(epO)
      simFrom(epI) = of(epO)
      if ov(epO) then simKind(epI) = 0
      if ok(epO) = 4 then simKind(epI) = 0
      ' Match fast_orders' convoy approximation, bounded to one fleet.
      if ov(epO) then
        for epJ = 0 to nu - 1
          epJO = trial(epJ)
          if uc(epJ) <> me then
            epJO = sampled(epSample * 64 + epJ)
            call pressForeign(epSample, epJ, epJO)
            epJO = pressForeignOption
          end if
          if ok(epJO) = 4 and parent(of(epJO)) = parent(ut(epI)) and parent(ot(epJO)) = simTo(epI) then
            epSea = ut(epJ)
            epFromOK = 0
            epToOK = 0
            epN = 82 + epSea
            for epE = edgeStart(epN) to edgeStart(epN) + edgeCount(epN) - 1
              if parent(edgeTo(epE) mod 82) = parent(ut(epI)) then epFromOK = 1
              if parent(edgeTo(epE) mod 82) = simTo(epI) then epToOK = 1
            next epE
            if epFromOK and epToOK then simKind(epI) = 1
          end if
        next epJ
      end if
    next epI
    call adjudicateFast()
    call scoreFast()
end sub

sub sliceDealBegin()
  pressDealAccepted = 0
  for paI = 0 to nu - 1
    sliceDealBase(paI) = best(paI)
    trial(paI) = best(paI)
    pressCandidate(paI) = -1
    pressTheirCandidate(paI) = -1
  next paI
  pressValidDeal = 1
  for paR = 0 to nr - 1
    paU = ru(paR)
    if uc(paU) <> me and uc(paU) <> sender then pressValidDeal = 0
    call pressFind(paU, rk(paR), rt(paR), rs(paR), rv(paR))
    if pressOption < 0 then
      pressValidDeal = 0
    elseif uc(paU) = me then
      if pressPin(paU) >= 0 and pressPin(paU) <> pressOption then pressValidDeal = 0
      if pressCandidate(paU) >= 0 and pressCandidate(paU) <> pressOption then pressValidDeal = 0
      pressCandidate(paU) = pressOption
    else
      if pressTheirCandidate(paU) >= 0 and pressTheirCandidate(paU) <> pressOption then pressValidDeal = 0
      pressTheirCandidate(paU) = pressOption
    end if
  next paR
  paNeeded = 0
  for paI = 0 to nu - 1
    if pressCandidate(paI) >= 0 then paNeeded = paNeeded + 1
  next paI
  if pressPactCount + paNeeded > 64 then pressValidDeal = 0
  if pressValidDeal = 0 then exit sub
end sub

sub sliceDealCommit()
    for paI = 0 to nu - 1
      if pressCandidate(paI) >= 0 then
        call pressRememberPact(paI, pressCandidate(paI), sender, canonical$)
      end if
      if pressTheirCandidate(paI) >= 0 then
        pressExpected(paI) = pressTheirCandidate(paI)
        pressExpectedText$(paI) = canonical$
        call pressAudit(paI)
      end if
    next paI
    if requestedPeace then pressPeace(sender) = 1
    for paP = 1 to 81
      if pressMessageDmz(paP) then
        if pressDmz(paP) = 0 or pressDmz(paP) = sender then
          pressDmz(paP) = sender
        else
          pressDmz(paP) = -1
        end if
      end if
    next paP
end sub

sub richardScenarios()
end sub

sub sliceForeignStep()
  if sliceTotalInstructions + estI >= 4000000 \ 3 or sliceTotalWork + estW >= 10000000 \ 3 then
    if sliceForeignStage = 2 then
      for sliceI = 0 to nu - 1
        if uc(sliceI) = fmCountry then sampled(fmSample * 64 + sliceI) = modelPlan(sliceI)
      next sliceI
    end if
    sliceStage = 7
    exit sub
  end if
  if sliceForeignStage = 0 then
    fmSample = 0
    fmCountry = 1
    sliceForeignStage = 1
  end if
  if fmSample >= 16 then
    sliceStage = 7
    exit sub
  end if
  if sliceForeignStage = 1 then
    if fmCountry = me or modelCompetent(fmSample * 8 + fmCountry) = 0 then
      call sliceForeignNext()
      exit sub
    end if
    for sliceI = 0 to nu - 1
      modelPlan(sliceI) = rawContext(fmSample * 64 + sliceI)
    next sliceI
    fmRecord = 0
    foreignCountries = foreignCountries + 1
    sliceForeignBeforeI = estI
    sliceForeignBeforeW = estW
    call evaluateForeign()
    sliceForeignI = sliceForeignI + estI - sliceForeignBeforeI
    sliceForeignW = sliceForeignW + estW - sliceForeignBeforeW
    fmBestScore = foreignEvaluation
    fmUnit = 0
    foreignO = -1
    sliceForeignStage = 2
    exit sub
  end if
  if fmUnit >= nu then
    for sliceI = 0 to nu - 1
      if uc(sliceI) = fmCountry then sampled(fmSample * 64 + sliceI) = modelPlan(sliceI)
    next sliceI
    call sliceForeignNext()
    exit sub
  end if
  if uc(fmUnit) <> fmCountry then
    fmUnit = fmUnit + 1
    foreignO = -1
    exit sub
  end if
  if foreignO < 0 then foreignO = os(fmUnit)
  if foreignO >= os(fmUnit) + oc(fmUnit) then
    fmUnit = fmUnit + 1
    foreignO = -1
    exit sub
  end if
  sliceO = foreignO
  foreignO = foreignO + 1
  if sliceO = modelPlan(fmUnit) or ok(sliceO) = 4 or ov(sliceO) then exit sub
  fmPrevious = modelPlan(fmUnit)
  modelPlan(fmUnit) = sliceO
  sliceForeignBeforeI = estI
  sliceForeignBeforeW = estW
  call evaluateForeign()
  sliceForeignI = sliceForeignI + estI - sliceForeignBeforeI
  sliceForeignW = sliceForeignW + estW - sliceForeignBeforeW
  foreignProposals = foreignProposals + 1
  if foreignEvaluation > fmBestScore + 0.0001 then
    fmBestScore = foreignEvaluation
    foreignImprovements = foreignImprovements + 1
  else
    modelPlan(fmUnit) = fmPrevious
  end if
end sub

sub sliceForeignNext()
  fmCountry = fmCountry + 1
  if fmCountry > 7 then
    fmCountry = 1
    fmSample = fmSample + 1
  end if
  sliceForeignStage = 1
end sub

sub drainMail()
  ' Discard unread mail outside movement phases, as discardMailbox() did.
  while mailboxCount() > 0
    drained$ = pullMailbox$()
  wend
end sub

sub stageCharge(stage)
  ' Conservative instruction charge per slice step, by stage.
  chargeI = 30000
  if stage = 1 then chargeI = 350000
  if stage = 2 then chargeI = 110000
  if stage = 3 then chargeI = 35000
  if stage = 4 then chargeI = 70000
  if stage = 5 then chargeI = 17000
  if stage = 7 then chargeI = 32000
end sub
