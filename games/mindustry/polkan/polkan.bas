' Polkan: a Mindustry economy that converts sand and coal into silicon,
' silicon and lead into Daggers, and Daggers into a dead enemy core.
' tools/mplan.nim plans the industry for each built-in map from its terrain
' (the API cannot see floors) and writes the orders where BLUEPRINT stands.
' Member 0 builds the blueprint: a silicon smelter against the core, a
' conveyor trunk out to a field of sand drills, combustion generators that
' touch what they power, and a ground factory. It hand-feeds coal to the
' smelter and generators and silicon and lead to the factory. Members 1-3
' mine copper, lead and coal into the core by hand; member 3 also sends
' the Daggers at the enemy core.
dim orderKind(159)
dim orderX(159)
dim orderY(159)
dim orderRotation(159)
dim orderAsked(159)
dim orderTries(159)
dim oreX(3)
dim oreY(3)
dim oreBest(3)
dim scanX(3)
dim scanY(3)
dim scanBest(3)
dim flankX(2)
dim flankY(2)
dim turretX(15)
dim turretY(15)
dim kin(3)

' The survival variant has no enemy core.
if enemyCoreX() < 0 then end

if ready = 0 then
  ready = 1
  cx = coreX()
  cy = coreY()
  ex = enemyCoreX()
  ey = enemyCoreY()
  me = member()
  width = mapWidth()
  height = mapHeight()
  copper = itemId("copper")
  lead = itemId("lead")
  coal = itemId("coal")
  sand = itemId("sand")
  silicon = itemId("silicon")
  dagger = unitTypeId("dagger")
  ' Kinds in the blueprint: 0 conveyor, 1 drill, 2 smelter, 3 generator,
  ' 4 ground factory, 5 guard Scatter, 6 guard Duo.
  conveyor = blockId("conveyor")
  drill = blockId("mechanical-drill")
  smelter = blockId("silicon-smelter")
  generator = blockId("combustion-generator")
  factory = blockId("ground-factory")
  scatter = blockId("scatter")
  duo = blockId("duo")
  hail = blockId("hail")
  orderCount = 0
  flankCount = 0
if mapWidth() = 350 and coreX() = 61 and coreY() = 104 then
  orderCount = 155
  orderKind(0) = 2226429
  orderKind(1) = 390879
  orderKind(2) = 390880
  orderKind(3) = 390881
  orderKind(4) = 390882
  orderKind(5) = 390883
  orderKind(6) = 390884
  orderKind(7) = 390885
  orderKind(8) = 390886
  orderKind(9) = 390887
  orderKind(10) = 390888
  orderKind(11) = 390889
  orderKind(12) = 390890
  orderKind(13) = 390891
  orderKind(14) = 390892
  orderKind(15) = 390893
  orderKind(16) = 390894
  orderKind(17) = 390895
  orderKind(18) = 390896
  orderKind(19) = 390897
  orderKind(20) = 390898
  orderKind(21) = 390899
  orderKind(22) = 390900
  orderKind(23) = 390901
  orderKind(24) = 390902
  orderKind(25) = 390903
  orderKind(26) = 390904
  orderKind(27) = 390905
  orderKind(28) = 390906
  orderKind(29) = 390907
  orderKind(30) = 390908
  orderKind(31) = 128765
  orderKind(32) = 390878
  orderKind(33) = 390877
  orderKind(34) = 390876
  orderKind(35) = 390875
  orderKind(36) = 390874
  orderKind(37) = 390873
  orderKind(38) = 390872
  orderKind(39) = 390871
  orderKind(40) = 390870
  orderKind(41) = 390869
  orderKind(42) = 390868
  orderKind(43) = 390867
  orderKind(44) = 390866
  orderKind(45) = 390865
  orderKind(46) = 390864
  orderKind(47) = 390863
  orderKind(48) = 390862
  orderKind(49) = 390861
  orderKind(50) = 390860
  orderKind(51) = 390859
  orderKind(52) = 390858
  orderKind(53) = 390857
  orderKind(54) = 390856
  orderKind(55) = 1176286
  orderKind(56) = 1177822
  orderKind(57) = 1176284
  orderKind(58) = 1177820
  orderKind(59) = 1176282
  orderKind(60) = 1177818
  orderKind(61) = 1176280
  orderKind(62) = 1177816
  orderKind(63) = 1176278
  orderKind(64) = 1177814
  orderKind(65) = 1176276
  orderKind(66) = 1177812
  orderKind(67) = 1176274
  orderKind(68) = 1177810
  orderKind(69) = 1176272
  orderKind(70) = 1177808
  orderKind(71) = 1176270
  orderKind(72) = 1177806
  orderKind(73) = 1176268
  orderKind(74) = 1177804
  orderKind(75) = 1176266
  orderKind(76) = 1177802
  orderKind(77) = 1176264
  orderKind(78) = 1177800
  orderKind(79) = 3275004
  orderKind(80) = 4328192
  orderKind(81) = 3279102
  orderKind(82) = 3279614
  orderKind(83) = 6424834
  orderKind(84) = 6424836
  orderKind(85) = 6422788
  orderKind(86) = 6420740
  orderKind(87) = 6420736
  orderKind(88) = 6419710
  orderKind(89) = 6421756
  orderKind(90) = 6424828
  orderKind(91) = 2227459
  orderKind(92) = 130315
  orderKind(93) = 917259
  orderKind(94) = 917258
  orderKind(95) = 917257
  orderKind(96) = 917256
  orderKind(97) = 917255
  orderKind(98) = 917254
  orderKind(99) = 917253
  orderKind(100) = 129803
  orderKind(101) = 129291
  orderKind(102) = 128779
  orderKind(103) = 128267
  orderKind(104) = 127755
  orderKind(105) = 127243
  orderKind(106) = 126731
  orderKind(107) = 126219
  orderKind(108) = 125707
  orderKind(109) = 125195
  orderKind(110) = 124683
  orderKind(111) = 124171
  orderKind(112) = 123659
  orderKind(113) = 123147
  orderKind(114) = 122635
  orderKind(115) = 122123
  orderKind(116) = 121611
  orderKind(117) = 121099
  orderKind(118) = 120587
  orderKind(119) = 120075
  orderKind(120) = 119563
  orderKind(121) = 119051
  orderKind(122) = 118539
  orderKind(123) = 1178380
  orderKind(124) = 1178377
  orderKind(125) = 1177356
  orderKind(126) = 1177353
  orderKind(127) = 1176332
  orderKind(128) = 1176329
  orderKind(129) = 1175308
  orderKind(130) = 1175305
  orderKind(131) = 1173260
  orderKind(132) = 1173257
  orderKind(133) = 1172236
  orderKind(134) = 1172233
  orderKind(135) = 1171212
  orderKind(136) = 1171209
  orderKind(137) = 1170188
  orderKind(138) = 1170185
  orderKind(139) = 1169164
  orderKind(140) = 1169161
  orderKind(141) = 1168140
  orderKind(142) = 1168137
  orderKind(143) = 1167116
  orderKind(144) = 1167113
  orderKind(145) = 3275523
  orderKind(146) = 4325627
  orderKind(147) = 3276537
  orderKind(148) = 3277049
  orderKind(149) = 5377282
  orderKind(150) = 5374214
  orderKind(151) = 5371136
  orderKind(152) = 5372666
  orderKind(153) = 5386499
  orderKind(154) = 5416190
  flankCount = 0
end if
if mapWidth() = 350 and coreX() = 289 and coreY() = 104 then
  orderCount = 154
  orderKind(0) = 2230013
  orderKind(1) = 395487
  orderKind(2) = 395488
  orderKind(3) = 395489
  orderKind(4) = 395490
  orderKind(5) = 395491
  orderKind(6) = 395492
  orderKind(7) = 395493
  orderKind(8) = 395494
  orderKind(9) = 395495
  orderKind(10) = 395496
  orderKind(11) = 395497
  orderKind(12) = 395498
  orderKind(13) = 395499
  orderKind(14) = 395500
  orderKind(15) = 395501
  orderKind(16) = 395502
  orderKind(17) = 395503
  orderKind(18) = 395504
  orderKind(19) = 395505
  orderKind(20) = 395506
  orderKind(21) = 395507
  orderKind(22) = 395508
  orderKind(23) = 395509
  orderKind(24) = 395510
  orderKind(25) = 395511
  orderKind(26) = 395512
  orderKind(27) = 395513
  orderKind(28) = 395514
  orderKind(29) = 395515
  orderKind(30) = 395516
  orderKind(31) = 395486
  orderKind(32) = 395485
  orderKind(33) = 395484
  orderKind(34) = 395483
  orderKind(35) = 395482
  orderKind(36) = 395481
  orderKind(37) = 395480
  orderKind(38) = 395479
  orderKind(39) = 395478
  orderKind(40) = 395477
  orderKind(41) = 395476
  orderKind(42) = 395475
  orderKind(43) = 395474
  orderKind(44) = 395473
  orderKind(45) = 395472
  orderKind(46) = 395471
  orderKind(47) = 395470
  orderKind(48) = 395469
  orderKind(49) = 395468
  orderKind(50) = 395467
  orderKind(51) = 395466
  orderKind(52) = 395465
  orderKind(53) = 395464
  orderKind(54) = 1180894
  orderKind(55) = 1182430
  orderKind(56) = 1180892
  orderKind(57) = 1182428
  orderKind(58) = 1180890
  orderKind(59) = 1182426
  orderKind(60) = 1180888
  orderKind(61) = 1182424
  orderKind(62) = 1180886
  orderKind(63) = 1182422
  orderKind(64) = 1180884
  orderKind(65) = 1182420
  orderKind(66) = 1180882
  orderKind(67) = 1182418
  orderKind(68) = 1180880
  orderKind(69) = 1182416
  orderKind(70) = 1180878
  orderKind(71) = 1182414
  orderKind(72) = 1180876
  orderKind(73) = 1182412
  orderKind(74) = 1180874
  orderKind(75) = 1182410
  orderKind(76) = 1180872
  orderKind(77) = 1182408
  orderKind(78) = 3278588
  orderKind(79) = 4847360
  orderKind(80) = 3273982
  orderKind(81) = 3274494
  orderKind(82) = 6424832
  orderKind(83) = 6424836
  orderKind(84) = 6423300
  orderKind(85) = 6420740
  orderKind(86) = 6420734
  orderKind(87) = 6420732
  orderKind(88) = 6423804
  orderKind(89) = 6425341
  orderKind(90) = 2227971
  orderKind(91) = 656139
  orderKind(92) = 917771
  orderKind(93) = 917770
  orderKind(94) = 917769
  orderKind(95) = 917768
  orderKind(96) = 917767
  orderKind(97) = 917766
  orderKind(98) = 917765
  orderKind(99) = 656651
  orderKind(100) = 657163
  orderKind(101) = 657675
  orderKind(102) = 658187
  orderKind(103) = 658699
  orderKind(104) = 659211
  orderKind(105) = 659723
  orderKind(106) = 660235
  orderKind(107) = 660747
  orderKind(108) = 661259
  orderKind(109) = 661771
  orderKind(110) = 662283
  orderKind(111) = 662795
  orderKind(112) = 663307
  orderKind(113) = 663819
  orderKind(114) = 664331
  orderKind(115) = 664843
  orderKind(116) = 665355
  orderKind(117) = 665867
  orderKind(118) = 666379
  orderKind(119) = 666891
  orderKind(120) = 667403
  orderKind(121) = 667915
  orderKind(122) = 1180425
  orderKind(123) = 1180428
  orderKind(124) = 1181449
  orderKind(125) = 1181452
  orderKind(126) = 1182473
  orderKind(127) = 1182476
  orderKind(128) = 1183497
  orderKind(129) = 1183500
  orderKind(130) = 1185545
  orderKind(131) = 1185548
  orderKind(132) = 1186569
  orderKind(133) = 1186572
  orderKind(134) = 1187593
  orderKind(135) = 1187596
  orderKind(136) = 1188617
  orderKind(137) = 1188620
  orderKind(138) = 1189641
  orderKind(139) = 1189644
  orderKind(140) = 1190665
  orderKind(141) = 1190668
  orderKind(142) = 1191689
  orderKind(143) = 1191692
  orderKind(144) = 3276035
  orderKind(145) = 4849915
  orderKind(146) = 3276537
  orderKind(147) = 3277049
  orderKind(148) = 5377280
  orderKind(149) = 5374726
  orderKind(150) = 5371138
  orderKind(151) = 5375226
  orderKind(152) = 5360899
  orderKind(153) = 5331709
  flankCount = 0
end if
if mapWidth() = 150 and coreX() = 81 and coreY() = 26 then
  orderCount = 124
  orderKind(0) = 2226947
  orderKind(1) = 124691
  orderKind(2) = 125203
  orderKind(3) = 125715
  orderKind(4) = 126227
  orderKind(5) = 126739
  orderKind(6) = 127251
  orderKind(7) = 127763
  orderKind(8) = 128275
  orderKind(9) = 128787
  orderKind(10) = 129299
  orderKind(11) = 916243
  orderKind(12) = 916242
  orderKind(13) = 916241
  orderKind(14) = 916240
  orderKind(15) = 916239
  orderKind(16) = 916238
  orderKind(17) = 916237
  orderKind(18) = 916236
  orderKind(19) = 916235
  orderKind(20) = 916234
  orderKind(21) = 916233
  orderKind(22) = 916232
  orderKind(23) = 916231
  orderKind(24) = 916230
  orderKind(25) = 916229
  orderKind(26) = 124179
  orderKind(27) = 123667
  orderKind(28) = 123155
  orderKind(29) = 122643
  orderKind(30) = 122131
  orderKind(31) = 121619
  orderKind(32) = 121107
  orderKind(33) = 120595
  orderKind(34) = 120083
  orderKind(35) = 119571
  orderKind(36) = 119059
  orderKind(37) = 118547
  orderKind(38) = 118035
  orderKind(39) = 117523
  orderKind(40) = 117011
  orderKind(41) = 116499
  orderKind(42) = 115987
  orderKind(43) = 115475
  orderKind(44) = 114963
  orderKind(45) = 1172756
  orderKind(46) = 1171732
  orderKind(47) = 1170708
  orderKind(48) = 1169684
  orderKind(49) = 1168660
  orderKind(50) = 1167636
  orderKind(51) = 1166612
  orderKind(52) = 1165588
  orderKind(53) = 1163537
  orderKind(54) = 3275522
  orderKind(55) = 4587781
  orderKind(56) = 3276547
  orderKind(57) = 3277059
  orderKind(58) = 6424832
  orderKind(59) = 6424836
  orderKind(60) = 6421765
  orderKind(61) = 6420740
  orderKind(62) = 6420734
  orderKind(63) = 6420732
  orderKind(64) = 6422780
  orderKind(65) = 6424828
  orderKind(66) = 2229507
  orderKind(67) = 131867
  orderKind(68) = 918811
  orderKind(69) = 918810
  orderKind(70) = 918809
  orderKind(71) = 918808
  orderKind(72) = 918807
  orderKind(73) = 918806
  orderKind(74) = 918805
  orderKind(75) = 918804
  orderKind(76) = 918803
  orderKind(77) = 918802
  orderKind(78) = 918801
  orderKind(79) = 918800
  orderKind(80) = 918799
  orderKind(81) = 918798
  orderKind(82) = 918797
  orderKind(83) = 918796
  orderKind(84) = 918795
  orderKind(85) = 918794
  orderKind(86) = 918793
  orderKind(87) = 918792
  orderKind(88) = 918791
  orderKind(89) = 918790
  orderKind(90) = 918789
  orderKind(91) = 131355
  orderKind(92) = 130843
  orderKind(93) = 130331
  orderKind(94) = 129819
  orderKind(95) = 129307
  orderKind(96) = 128795
  orderKind(97) = 128283
  orderKind(98) = 127771
  orderKind(99) = 127259
  orderKind(100) = 126747
  orderKind(101) = 126235
  orderKind(102) = 125723
  orderKind(103) = 125211
  orderKind(104) = 124699
  orderKind(105) = 1179932
  orderKind(106) = 1179929
  orderKind(107) = 1178908
  orderKind(108) = 1177884
  orderKind(109) = 1176860
  orderKind(110) = 1175836
  orderKind(111) = 1174812
  orderKind(112) = 1173785
  orderKind(113) = 3278594
  orderKind(114) = 4585216
  orderKind(115) = 3273982
  orderKind(116) = 3274494
  orderKind(117) = 5377280
  orderKind(118) = 5375750
  orderKind(119) = 5370112
  orderKind(120) = 5374202
  orderKind(121) = 5374238
  orderKind(122) = 5374263
  orderKind(123) = 5374288
  flankCount = 3
  flankX(0) = 34
  flankY(0) = 69
  flankX(1) = 31
  flankY(1) = 139
  flankX(2) = 46
  flankY(2) = 199
end if
if mapWidth() = 150 and coreX() = 81 and coreY() = 224 then
  orderCount = 127
  orderKind(0) = 2226429
  orderKind(1) = 124652
  orderKind(2) = 125164
  orderKind(3) = 125676
  orderKind(4) = 126188
  orderKind(5) = 126700
  orderKind(6) = 127212
  orderKind(7) = 127724
  orderKind(8) = 128236
  orderKind(9) = 390892
  orderKind(10) = 390893
  orderKind(11) = 390894
  orderKind(12) = 390895
  orderKind(13) = 390896
  orderKind(14) = 390897
  orderKind(15) = 390898
  orderKind(16) = 390899
  orderKind(17) = 390900
  orderKind(18) = 390901
  orderKind(19) = 390902
  orderKind(20) = 390903
  orderKind(21) = 390904
  orderKind(22) = 390905
  orderKind(23) = 390906
  orderKind(24) = 390907
  orderKind(25) = 390908
  orderKind(26) = 128765
  orderKind(27) = 124140
  orderKind(28) = 123628
  orderKind(29) = 123116
  orderKind(30) = 122604
  orderKind(31) = 122092
  orderKind(32) = 121580
  orderKind(33) = 121068
  orderKind(34) = 120556
  orderKind(35) = 120044
  orderKind(36) = 119532
  orderKind(37) = 119020
  orderKind(38) = 118508
  orderKind(39) = 117996
  orderKind(40) = 117484
  orderKind(41) = 116972
  orderKind(42) = 116460
  orderKind(43) = 115948
  orderKind(44) = 115436
  orderKind(45) = 114924
  orderKind(46) = 1172714
  orderKind(47) = 1171690
  orderKind(48) = 1170666
  orderKind(49) = 1169642
  orderKind(50) = 1168618
  orderKind(51) = 1167594
  orderKind(52) = 1166570
  orderKind(53) = 1165546
  orderKind(54) = 1163501
  orderKind(55) = 3275004
  orderKind(56) = 5112059
  orderKind(57) = 3276026
  orderKind(58) = 3278074
  orderKind(59) = 6424834
  orderKind(60) = 6424836
  orderKind(61) = 6422788
  orderKind(62) = 6420740
  orderKind(63) = 6420736
  orderKind(64) = 6421243
  orderKind(65) = 6421756
  orderKind(66) = 6424828
  orderKind(67) = 2229500
  orderKind(68) = 131812
  orderKind(69) = 132324
  orderKind(70) = 394980
  orderKind(71) = 394981
  orderKind(72) = 394982
  orderKind(73) = 394983
  orderKind(74) = 394984
  orderKind(75) = 394985
  orderKind(76) = 394986
  orderKind(77) = 394987
  orderKind(78) = 394988
  orderKind(79) = 394989
  orderKind(80) = 394990
  orderKind(81) = 394991
  orderKind(82) = 394992
  orderKind(83) = 394993
  orderKind(84) = 394994
  orderKind(85) = 394995
  orderKind(86) = 394996
  orderKind(87) = 394997
  orderKind(88) = 394998
  orderKind(89) = 394999
  orderKind(90) = 395000
  orderKind(91) = 395001
  orderKind(92) = 395002
  orderKind(93) = 395003
  orderKind(94) = 131300
  orderKind(95) = 130788
  orderKind(96) = 130276
  orderKind(97) = 129764
  orderKind(98) = 129252
  orderKind(99) = 128740
  orderKind(100) = 128228
  orderKind(101) = 127716
  orderKind(102) = 127204
  orderKind(103) = 126692
  orderKind(104) = 126180
  orderKind(105) = 125668
  orderKind(106) = 125156
  orderKind(107) = 124644
  orderKind(108) = 1179877
  orderKind(109) = 1179874
  orderKind(110) = 1178850
  orderKind(111) = 1177826
  orderKind(112) = 1176802
  orderKind(113) = 1175778
  orderKind(114) = 1174754
  orderKind(115) = 1173733
  orderKind(116) = 3278075
  orderKind(117) = 5114624
  orderKind(118) = 3278591
  orderKind(119) = 3280639
  orderKind(120) = 5377282
  orderKind(121) = 5374214
  orderKind(122) = 5371136
  orderKind(123) = 5372664
  orderKind(124) = 5373152
  orderKind(125) = 5374153
  orderKind(126) = 5374128
  flankCount = 3
  flankX(0) = 42
  flankY(0) = 173
  flankX(1) = 30
  flankY(1) = 110
  flankX(2) = 42
  flankY(2) = 47
end if
  ' Each order arrives packed in orderKind (see tools/mplan.nim):
  ' ((kind * 4 + rotation) * 512 + x offset + 256) * 512 + y offset + 256.
  for k = 0 to orderCount - 1
    v = orderKind(k)
    orderY(k) = cy + v - (v \ 512) * 512 - 256
    v = v \ 512
    orderX(k) = cx + v - (v \ 512) * 512 - 256
    v = v \ 512
    orderRotation(k) = v - (v \ 4) * 4
    orderKind(k) = v \ 4
  next k
  for k = 1 to 3
    oreBest(k) = 100000
    scanBest(k) = 100000
  next k
  scanRow = 0
  scanRadius = 80
  waveSize = 20
  role = me
end if

' Keep finding the nearest open copper, lead and coal ore within 80 tiles,
' eight rows a decision, so miners leave tiles our buildings cover. Ores
' vary by seed: some Glacier seeds put the nearest lead 80-105 tiles out,
' so a pass that misses an ore widens the next ones to 125 tiles. Players
' drop mined items into a core within 27.5 tiles; farther ore is carried
' home by hand.
for row = 0 to 7
  y = cy - scanRadius + scanRow
  for x = cx - scanRadius to cx + scanRadius
    k = oreAt(x, y)
    if k > 0 then
      if blockAt(x, y) = -1 then
        dx = x - cx
        dy = y - cy
        d2 = dx * dx + dy * dy
        if d2 < scanBest(k) and d2 <= scanRadius * scanRadius then
          scanBest(k) = d2
          scanX(k) = x
          scanY(k) = y
        end if
      end if
    end if
  next x
  scanRow = scanRow + 1
  if scanRow > 2 * scanRadius then
    scanRow = 0
    for k = 1 to 3
      oreBest(k) = scanBest(k)
      oreX(k) = scanX(k)
      oreY(k) = scanY(k)
      scanBest(k) = 100000
    next k
    for k = 1 to 3
      if oreBest(k) >= 100000 then scanRadius = 125
    next k
  end if
next row

if flyerHealth() <= 0 then end
fx = flyerX()
fy = flyerY()

' Kin: league rounds deal six entrants into eight seats, so a team mixes
' Polkan seats with strangers. For half a second every Polkan seat drifts
' to its signature tile, three east of its spawn (core y - 3 + 2 * member),
' and counts the teammates seen on theirs at ticks 24 and 30. Four
' Polkans keep the member roles; a mixed team gets a Duo guardian (the
' lowest Polkan) and miners, and never spends the shared core on industry.
if tick() <= 30 then
  buildEnable(0)
  move((cx + 3 - fx) / 6, (cy - 3 + 2 * me - fy) / 6)
  if tick() >= 24 then
    mySeat = -1
    for i = 0 to unitCount() - 1
      if unit(i, 0) = controlled() then mySeat = unit(i, 13)
    next i
    base = mySeat - me
    for i = 0 to unitCount() - 1
      if unit(i, 6) = team() and unit(i, 13) >= 0 then
        m = unit(i, 13) - base
        if m >= 0 and m <= 3 and m <> me then
          dx = unit(i, 2) - (cx + 3)
          dy = unit(i, 3) - (cy - 3 + 2 * m)
          seen = 0
          if dx > -1.5 and dx < 1.5 and dy > -1.5 and dy < 1.5 then seen = 1
          if tick() < 30 then
            kin(m) = seen
          else
            kin(m) = kin(m) * seen
          end if
        end if
      end if
    next i
  end if
  if tick() < 30 then end
  kinCount = 1
  rank = 0
  for m = 0 to 3
    if m <> me and kin(m) = 1 then
      kinCount = kinCount + 1
      if m < me then rank = rank + 1
    end if
  next m
  role = me
  if kinCount < 4 then role = 10 + rank
  ' A second Polkan on a mixed team runs our industry while the first
  ' guards: one seat doing both lost its core four times sooner.
  if kinCount < 4 and rank = 1 then role = 20
end if

' An alpha or gamma with live build plans cannot mine: pause building while
' the core is out of copper so a stalled plan never stops all income.
if stock(copper) < 12 then paused = 1
if stock(copper) >= 40 then paused = 0
if paused = 1 then
  buildEnable(0)
else
  buildEnable(1)
end if

' Pick what to mine by member preference and stock targets. A new choice
' holds for 300 ticks: when a stock hovers at a threshold, flipping between
' ores on opposite sides of the core every decision mines nothing.
want = 1
if role = 1 then
  want = 3
  if stock(coal) >= 300 then want = 1
  if stock(copper) < 150 then want = 1
end if
if role = 2 then
  want = 2
  if stock(lead) >= 400 then want = 1
  if stock(copper) < 150 then want = 1
end if
if role = 3 then
  want = 1
  if stock(copper) >= 600 then want = 2
  ' Two smelters and their generators outrun one coal miner.
  if stock(copper) >= 300 and stock(coal) < 100 then want = 3
end if
if role >= 10 then
  ' Mixed-team seats bank whatever the shared core holds least of, against
  ' goals of 300 copper, 200 lead and 100 coal. The guardian only counts
  ' ore within 19 tiles, where it can still feed every Duo.
  want = 1
  short = stock(copper) / 300
  if stock(lead) / 200 < short and (role >= 11 or oreBest(2) <= 361) then
    want = 2
    short = stock(lead) / 200
  end if
  if stock(coal) / 100 < short and (role >= 11 or oreBest(3) <= 361) then want = 3
end if
if lastWant > 0 and tick() < wantUntil then want = lastWant
if want <> lastWant then wantUntil = tick() + 300
lastWant = want
if oreBest(want) >= 100000 then want = 1
targetX = cx
targetY = cy
if oreBest(want) < 100000 then
  if oreBest(want) <= 756 or role = 0 or role = 10 then
    targetX = oreX(want)
    targetY = oreY(want)
    mine(oreX(want), oreY(want))
  else
    ' Far ore: fill our own hold, then fly home and hand it to the core.
    wantItem = copper
    if want = 2 then wantItem = lead
    if want = 3 then wantItem = coal
    if carried() = 0 then hauling = 0
    if carried() >= 60 then hauling = 1
    if carried() > 0 and carriedItem() <> wantItem then hauling = 1
    if hauling = 1 then
      dx = fx - cx
      dy = fy - cy
      if dx * dx + dy * dy <= 500 then deposit(cx, cy)
    else
      targetX = oreX(want)
      targetY = oreY(want)
      mine(oreX(want), oreY(want))
    end if
  end if
end if

' Member 3 keeps far Scatters (the route chain) loaded with lead; it beats
' building, mining and hauling while one runs low.
supplying = 0
if role = 3 then
  supply = -1
  for i = 0 to buildingCount() - 1
    if supply < 0 and building(i, 5) = team() and building(i, 9) >= 1 then
      sx = building(i, 2)
      sy = building(i, 3)
      if contentAt(sx, sy) = scatter and building(i, 11) < 12 then
        dx = sx - cx
        dy = sy - cy
        if dx * dx + dy * dy > 484 then supply = i
      end if
    end if
  next i
  if supply >= 0 and stock(lead) >= 40 then
    supplying = 1
    sx = building(supply, 2)
    sy = building(supply, 3)
    if carried() > 0 and carriedItem() <> lead then
      targetX = cx
      targetY = cy
      deposit(cx, cy)
    else
      if carried() = 0 then
        targetX = cx
        targetY = cy
        if homeDistance <= 500 then take(cx, cy, lead, 60)
      else
        targetX = sx
        targetY = sy
        deposit(sx, sy)
      end if
    end if
  end if
end if

' Member 0 builds every order within 22 tiles of the core and stays home
' for the hand logistics; member 3 flies out to build the rest.
builder = 0
if role = 0 or role = 10 then builder = 1
if role = 3 then builder = 2
if role = 20 then builder = 3
if builder > 0 then
  queued = 0
  far = -1
  for k = 0 to orderCount - 1
    kind = orderKind(k)
    dx = orderX(k) - cx
    dy = orderY(k) - cy
    mine2 = 1
    if dx * dx + dy * dy > 484 then mine2 = 2
    ' A skipped order gets another round of tries after 30 seconds; sites
    ' started while the core ran dry would otherwise stay unfinished.
    if orderTries(k) >= 6 and tick() - orderAsked(k) >= 1800 then orderTries(k) = 0
    if (mine2 <> builder and builder <> 3) or orderTries(k) >= 6 then kind = -1
    ' The mixed-team guardian builds only the Duo ring.
    if role = 10 and kind <> 6 then kind = -1
    id = conveyor
    if kind = 1 then id = drill
    if kind = 2 then id = smelter
    if kind = 3 then id = generator
    if kind = 4 then id = factory
    if kind = 5 then id = scatter
    if kind = 6 then id = duo
    x = orderX(k)
    y = orderY(k)
    skip = 0
    if kind < 0 then skip = 1
    if kind = 1 then
      ' A drill on copper, lead or coal would jam the sand trunk.
      if oreAt(x, y) + oreAt(x + 1, y) + oreAt(x, y + 1) + oreAt(x + 1, y + 1) > 0 then skip = 1
    end if
    if skip = 0 and contentAt(x, y) <> id then
      affordable = 1
      if kind = 1 and stock(copper) < 20 then affordable = 0
      if kind = 2 and (stock(copper) < 40 or stock(lead) < 30) then affordable = 0
      if kind = 3 and (stock(copper) < 35 or stock(lead) < 20) then affordable = 0
      if kind = 4 and (stock(copper) < 60 or stock(lead) < 130 or stock(silicon) < 80) then affordable = 0
      if kind = 5 and (stock(copper) < 120 or stock(lead) < 80) then affordable = 0
      if kind = 6 and stock(copper) < 60 then affordable = 0
      if affordable = 1 and queued < 4 then
        if orderAsked(k) = 0 or tick() - orderAsked(k) >= 120 then
          if buildBlock(id, x, y, orderRotation(k)) = 1 then
            orderAsked(k) = tick()
            ' Count a try only when we stand in build range of it.
            dx = x - fx
            dy = y - fy
            if dx * dx + dy * dy <= 600 then orderTries(k) = orderTries(k) + 1
            queued = queued + 1
          end if
        end if
      end if
      if far < 0 and affordable = 1 then far = k
    end if
  next k
  ' The outer builder flies to the first affordable unbuilt far order.
  buildTrip = 0
  if builder >= 2 and far >= 0 and supplying = 0 then
    buildTrip = 1
    targetX = orderX(far)
    targetY = orderY(far)
  end if
  ' contentAt reports a started site as its finished block, so the order
  ' loop skips it; resume our first unfinished site and fly to it.
  site = -1
  for i = 0 to buildingCount() - 1
    if site < 0 and building(i, 5) = team() and building(i, 9) < 1 then
      dx = building(i, 2) - cx
      dy = building(i, 3) - cy
      mine2 = 2
      if dx > -23 and dx < 23 and dy > -23 and dy < 23 then
        if dx * dx + dy * dy <= 484 then mine2 = 1
      end if
      if mine2 = builder or builder = 3 then site = i
    end if
  next i
  if site >= 0 then
    sx = building(site, 2)
    sy = building(site, 3)
    if tick() - siteAsked >= 120 then
      buildBlock(contentAt(sx, sy), sx, sy, building(site, 7))
      siteAsked = tick()
    end if
    ' A site with nothing to build from would hold member 3 off mining.
    if builder >= 2 and supplying = 0 and stock(copper) >= 100 and stock(lead) >= 50 then
      buildTrip = 1
      targetX = sx
      targetY = sy
    end if
  end if
end if

if role = 0 or role = 10 or role = 20 then
  ' Stay near the core: hover on it while inner orders remain, and only
  ' mine ore within 12 tiles of it. The guardian's only job at home is the
  ' Duo ring 4-8 tiles out, and transfers reach 27.5 tiles, so it mines
  ' anything within 19 tiles: a mixed team's core is usually broke.
  reach = 144
  if role = 10 then reach = 361
  if (oreBest(want) > reach or (far >= 0 and role = 0)) and buildTrip = 0 then
    targetX = cx
    targetY = cy
  end if
  ' Hand logistics: empty our hands into the core first, then feed.
  if carried() > 0 then deposit(cx, cy)
  if carried() = 0 then
    fed = 0
    for i = 0 to buildingCount() - 1
      if building(i, 5) = team() and building(i, 9) >= 1 then
        bx = building(i, 2)
        bxy = building(i, 3)
        b = contentAt(bx, bxy)
        ' The mixed-team guardian feeds only the Duos; the industry is not ours.
        if role = 10 and b <> duo then b = -1
        if b = smelter or b = generator then
          have = buildingItem(i, coal)
          if have < 6 and stock(coal) >= 10 then
            take(cx, cy, coal, 10 - have)
            deposit(bx, bxy)
          end if
        end if
        if b = scatter then
          ' Guard Scatters burn lead, which piles up in the thousands. Route
          ' Scatters are member 3's: a deposit out of reach leaves the lead
          ' in hand and every later take fails.
          near = 0
          dx = bx - cx
          dy = bxy - cy
          if dx > -23 and dx < 23 and dy > -23 and dy < 23 then
            if dx * dx + dy * dy <= 484 then near = 1
          end if
          if near = 1 and building(i, 11) < 12 and stock(lead) >= 60 then
            take(cx, cy, lead, 6)
            deposit(bx, bxy)
          end if
        end if
        if b = duo then
          ' Copper is Duo ammo and piles up too; four refills per decision
          ' keep a fresh ring under the 32-command limit.
          if building(i, 11) < 10 and stock(copper) >= 60 and fed < 4 then
            take(cx, cy, copper, 6)
            deposit(bx, bxy)
            fed = fed + 1
          end if
        end if
        if b = factory then
          have = buildingItem(i, silicon)
          if have < 10 and stock(silicon) >= 20 then
            take(cx, cy, silicon, 20 - have)
            deposit(bx, bxy)
          end if
          have = buildingItem(i, lead)
          if have < 10 and stock(lead) >= 20 then
            take(cx, cy, lead, 20 - have)
            deposit(bx, bxy)
          end if
          if tick() mod 300 = 0 then
            configure(bx, bxy, 0, 0)
            ' Gather near the factory until the first wave, then send every
            ' new Dagger straight at the enemy core (unit ids above 32767
            ' cannot be commanded through the BASIC host).
            rallyX = bx + (ex - bx) / 20
            rallyY = bxy + (ey - bxy) / 20
            commandBuilding(bx, bxy, rallyX, rallyY)
          end if
        end if
      end if
    next i
  end if
end if

' Waves: Daggers gather at home and go 20 at a time (the cap is 24). The
' gathered army guards home while a rival trickles tens into our Duos, and
' a trickle of our own dies to enemy Gammas one Dagger at a time.
if (role = 3 or role = 20) and tick() mod 60 = 0 then
  waiting = 0
  for i = 0 to unitCount() - 1
    if unit(i, 6) = team() and unit(i, 11) = dagger and unit(i, 13) = -1 then
      dx = unit(i, 2) - cx
      dy = unit(i, 3) - cy
      if dx > -31 and dx < 31 and dy > -31 and dy < 31 then
        if dx * dx + dy * dy <= 900 then waiting = waiting + 1
      end if
    end if
  next i
  ' A home army that has not grown for a minute (silicon short, Gammas
  ' picking it off) goes anyway once it holds twelve: waiting for twenty
  ' would never attack.
  if waiting > peakWaiting then
    peakWaiting = waiting
    peakTick = tick()
  end if
  stalled = 0
  if waiting >= 12 and tick() - peakTick >= 3600 then stalled = 1
  if waiting >= waveSize or stalled = 1 then
    peakWaiting = 0
    peakTick = tick()
    issued = 0
    for i = 0 to unitCount() - 1
      if issued < 30 and unit(i, 6) = team() and unit(i, 11) = dagger and unit(i, 13) = -1 then
        dx = unit(i, 2) - cx
        dy = unit(i, 3) - cy
        near = 0
        if dx > -31 and dx < 31 and dy > -31 and dy < 31 then
          if dx * dx + dy * dy <= 900 then near = 1
        end if
        if near = 1 then
          if flankCount > 0 then
            commandMove(unit(i, 0), flankX(0), flankY(0), 0)
          else
            commandAttackBuilding(unit(i, 0), ex, ey, 0)
          end if
          issued = issued + 1
        end if
      end if
    next i
  end if
end if

' Flank: on Glacier the centre corridor runs under the enemy Gammas' flight
' line, so a wave walks the planner's flank waypoints with move orders and
' attacks the core from the last one. Daggers within seven tiles of a
' waypoint move on to the next.
if (role = 3 or role = 20) and flankCount > 0 and tick() mod 60 = 12 then
  issued = 0
  for i = 0 to unitCount() - 1
    if issued < 20 and unit(i, 6) = team() and unit(i, 11) = dagger and unit(i, 13) = -1 then
      ux = unit(i, 2)
      uy = unit(i, 3)
      for k = 0 to flankCount - 1
        dx = ux - flankX(k)
        dy = uy - flankY(k)
        if dx > -7 and dx < 7 and dy > -7 and dy < 7 then
          if k + 1 < flankCount then
            commandMove(unit(i, 0), flankX(k + 1), flankY(k + 1), 0)
          else
            commandAttackBuilding(unit(i, 0), ex, ey, 0)
          end if
          issued = issued + 1
        end if
      next k
    end if
  next i
end if

' Siege: a Duo ring shreds a wave that shoots the core first, and Daggers
' outrange Duos, so Daggers near the enemy core take the nearest turret
' within 20 tiles first and the core once none is left. A separate tick
' from the launch keeps both under the 32-command limit.
if (role = 3 or role = 20) and tick() mod 60 = 30 then
  turrets = 0
  for i = 0 to buildingCount() - 1
    if turrets < 16 and building(i, 5) <> team() and building(i, 5) > 0 and building(i, 9) >= 1 then
      bx = building(i, 2)
      bxy = building(i, 3)
      dx = bx - ex
      dy = bxy - ey
      if dx > -21 and dx < 21 and dy > -21 and dy < 21 then
        b = contentAt(bx, bxy)
        if b = duo or b = hail then
          turretX(turrets) = bx
          turretY(turrets) = bxy
          turrets = turrets + 1
        end if
      end if
    end if
  next i
  issued = 0
  for i = 0 to unitCount() - 1
    if issued < 20 and unit(i, 6) = team() and unit(i, 11) = dagger and unit(i, 13) = -1 then
      ux = unit(i, 2)
      uy = unit(i, 3)
      dx = ux - ex
      dy = uy - ey
      if dx > -36 and dx < 36 and dy > -36 and dy < 36 then
        tx = ex
        ty = ey
        best = 400
        for k = 0 to turrets - 1
          dx = turretX(k) - ux
          dy = turretY(k) - uy
          if dx > -21 and dx < 21 and dy > -21 and dy < 21 then
            if dx * dx + dy * dy < best then
              best = dx * dx + dy * dy
              tx = turretX(k)
              ty = turretY(k)
            end if
          end if
        next k
        commandAttackBuilding(unit(i, 0), tx, ty, 0)
        issued = issued + 1
      end if
    end if
  next i
end if

' Escort: while five or more Daggers march, members 2 and 3 fly over the
' column and shoot. Daggers cannot hit kiting Gammas; Gammas with aim-lead can.
marching = 0
marchX = 0
marchY = 0
for i = 0 to unitCount() - 1
  if unit(i, 6) = team() and unit(i, 11) = dagger then
    dx = unit(i, 2) - cx
    dy = unit(i, 3) - cy
    out = 1
    if dx > -31 and dx < 31 and dy > -31 and dy < 31 then
      if dx * dx + dy * dy <= 900 then out = 0
    end if
    if out = 1 then
      marching = marching + 1
      marchX = marchX + unit(i, 2)
      marchY = marchY + unit(i, 3)
    end if
  end if
next i
' Only a rich core spares its copper and lead miners; the coal miner stays.
escorting = 0
rich = 0
if stock(copper) >= 500 and stock(lead) >= 200 then rich = 1
if rich = 1 and role >= 2 and role <= 3 and marching >= 5 and supplying = 0 then
  escorting = 1
  targetX = marchX / marching
  targetY = marchY / marching
end if

' Steer with a short brake near the target.
dx = targetX - fx
dy = targetY - fy
d2 = 100
if dx > -50 and dx < 50 and dy > -50 and dy < 50 then d2 = dx * dx + dy * dy
if d2 > 4 then
  move(dx, dy)
else
  move(dx / 4, dy / 4)
end if

' Shoot the closest enemy unit in weapon range (wider while escorting).
' Gamma bolts fly 3.5 units a tick, as fast as a Gamma, so aim where the
' target will be: its velocity (tiles a tick) times the flight time, which
' is the distance (three Newton steps from 10) times 8 / 3.5 ticks.
best = 300
if escorting = 1 then best = 400
target = -1
for i = 0 to unitCount() - 1
  if unit(i, 6) <> team() and unit(i, 5) > 0 then
    dx = unit(i, 2) - fx
    dy = unit(i, 3) - fy
    d2 = 100000
    if dx > -25 and dx < 25 and dy > -25 and dy < 25 then d2 = dx * dx + dy * dy
    if d2 < best then
      best = d2
      target = i
    end if
  end if
next i
if target >= 0 then
  g = 10
  g = (g + best / g) / 2
  g = (g + best / g) / 2
  g = (g + best / g) / 2
  flight = g * 2.2857
  aim(unit(target, 2) + unit(target, 9) * flight, unit(target, 3) + unit(target, 10) * flight)
  shoot(1)
end if
