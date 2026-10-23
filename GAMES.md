# Games by type

122 games in four categories. Name→game mapping in [NAMES.md](NAMES.md);
per-game dossiers in `games/<game>/ideas.md`.

Columns: **LLM** — whether an LLM plays the seat (required = the game-side
model makes every decision from our prompt; recommended = optional model
calls improve a scripted player; none = pure scripted Nim). **Upload** —
what our container is: a full Nim player, a thin prompt seat (Nim client
whose crafted prompt IS the strategy), or a soul.md (heartleaf's
model-id + system-prompt file, played entirely by the game pod).

## Real games — actual engines, franchises, live data (12)

Actual popular games running their real engines (or live real-world
data): strong play needs genuine game knowledge.

| Game | Ours | LLM | Upload | What it is |
|------|------|-----|--------|------------|
| [Atari 57](games/atari-57/) | Emelya Jr | required | prompt seat | Atari-57 suite. Four cogs play the same arcade cartridge from the same seed on four sealed screens at once — pellets, bricks or invaders — and the highest s… |
| [Atari Cabinet](games/atari-cabinet/) | Emelya | required | prompt seat | Atari 2600 emulation. Four arcade cabinets ring a square CRT, each defending a gap in its own wall with a paddle that is also a gun; the last cabinet with lives s… |
| [Bw](games/bw/) | Svyatogor | none | full Nim | Brood War via OpenBW. Four-player OpenBW StarCraft: Brood War free-for-all over the bitworld sprite protocol. |
| [Coworld Mtg](games/coworld-mtg/) | Volkh Vseslavevich | none | full Nim | Magic: The Gathering rules engine. Two-player Magic: The Gathering powered by the Phase rules engine, with enforced mana, timing, priority, stack, combat, hidden information, … |
| [Factorio](games/factorio/) | Danila Master | none | full Nim | Factorio (Factorio Learning Environment). The Factorio Learning Environment (FLE 0.3.0, Factorio 1.1.110) as a Coworld: each seat gets its own headless Factorio server on the FLE lab… |
| [Mindustry](games/mindustry/) | Polkan | none | .bas file | Mindustry via its native Java engine. Four BASIC players per team share a core in mirrored 4v4 PvP; destroy the enemy core to win, timeouts draw. |
| [Nethack](games/nethack/) | Ivan Da Marya | required | prompt seat | NetHack. NetHack in miniature. |
| [Persistent Wow](games/persistent-wow/) | Ruslan | none | full Nim | World of Warcraft durable realm via vmangos. Ongoing Vanilla WoW leveling on a durable external realm, using a thin connector game runtime and commissioner-recorded ten-minute windows. |
| [Polymarket Coworld](games/polymarket_coworld/) | Veshchiy Oleg | none | full Nim | Polymarket prediction markets (real data). Prediction-market trading Coworld using Polymarket-style market data and oracle settlement. |
| [Smac Starcraft Micro](games/smac-starcraft-micro/) | Peresvet | required | prompt seat | StarCraft II micro (SMAC). Five cogs, one unit each, fight a scripted enemy army three times on a fixed arena. |
| [Vanilla Wow](games/vanilla-wow/) | Bova Korolevich | none | full Nim | World of Warcraft 1.12 via vmangos. Isolated Vanilla WoW episodes for 10x leveling, Kalimdor racing, RFC dungeon clears, and Arena 2v2, with one VMaNGOS backend per episode and… |
| [Vizdoom Deathmatch](games/vizdoom-deathmatch/) | Chert | required | prompt seat | Doom via ViZDoom. Eight cogs, four RED against four BLUE, in one walled arena with cover, glass windows, med kits and nothing to capture. |

## Clones of popular games and benchmarks (61)

Reimplementations of well-known board games, video games, and RL
competition environments — prior art and known strategies transfer.

| Game | Ours | LLM | Upload | What it is |
|------|------|-----|--------|------------|
| [Agricogla](games/agricogla/) | Mikula Selyaninovich | none | full Nim | After **Agricola**. A four-player worker-placement farming benchmark: agents place family members on action spaces to gather resources, build a farm, raise anim… |
| [Battleroyale](games/battleroyale/) | Koschei | none | full Nim | After **the battle-royale genre**. Battle Royale: a free-for-all last-one-standing shooter, AI bots only. |
| [Board Gauntlet](games/board-gauntlet/) | Volga Svyatoslavich | required | prompt seat | After **Connect Four / Hex / Quoridor / Breakthrough**. Board Gauntlet is a rotating perfect-information ladder for two LLM-piloted cogs. |
| [Bullwhip](games/bullwhip/) | Sadko | required | prompt seat | After **the MIT Beer Game**. Bullwhip: the MIT Beer Game for four LLM-piloted cogs. |
| [Citysim](games/citysim/) | Gvidon | none | full Nim | After **SimCity-style city management**. 30 days. |
| [Cogiavelli](games/cogiavelli/) | Shamakhanskaya Tsaritsa | required | prompt seat | After **Machiavelli**. Cogiavelli: Diplomacy's adjudicator on a Renaissance-Italy board, with a treasury bolted on. |
| [Cognames](games/cognames/) | Sirin | none | full Nim | After **Codenames**. Spymaster-vs-spymaster Codenames: two external players, one spymaster per team (RED, BLUE), compete by giving one-word clues. |
| [Cogplomacy](games/cogplomacy/) | Vladimir Krasno Solnyshko | required | prompt seat | After **Diplomacy**. Cogplomacy is Allan Calhamer's Diplomacy for seven LLM-piloted cogs: the 1901 map of Europe, seven great powers (Austria, England, France, G… |
| [Cogriculture](games/cogriculture/) | Polevik | none | full Nim | After **a Kaggle farming competition**. Two-player farming and market simulation over a 30-day season. |
| [Cogs Against Humanity](games/cogs-against-humanity/) | Petrushka | none | full Nim | After **Cards Against Humanity**. Cards Against Humanity played entirely by four LLM players with a rotating card czar and no separate judge model. |
| [Cogtan](games/cogtan/) | Domovoy | none | full Nim | After **Catan**. A four-player CATAN (Settlers of Catan) benchmark: agents draft starting settlements, manage stochastic resource production, negotiate trade… |
| [Coguire](games/coguire/) | Korobochka | none | full Nim | After **Acquire**. A four-player economic-strategy benchmark (Acquire): agents found and grow hotel corporations on a shared grid, time mergers to harvest shar… |
| [Collab Cooking](games/collab_cooking/) | Kolobok | required | prompt seat | After **Overcooked**. Four cogs share one kitchen for 900 ticks. |
| [Continuous Control](games/continuous-control/) | Plyaska | required | prompt seat | After **Gym MuJoCo control**. One cog, three planar machines, sixty metres of track, three times. |
| [Cosino](games/cosino/) | Zolotaya Rybka | required | prompt seat | After **Kuhn / Leduc / no-limit hold'em poker**. Cosino is the imperfect-information house: one binary, one protocol, six tables of the same zero-sum game — a four-rung LADDER plus the clas… |
| [Crafter](games/crafter/) | Levsha | required | prompt seat | After **Crafter**. One cog alone in a 64x64 procedurally generated wilderness it can see nine cells of. |
| [Crewrift](games/crewrift/) | Kikimora | recommended | full Nim | After **Among Us**. One Crewrift runtime catalog for the separate Classic and Prime leagues, plus Prime training scenarios. |
| [Derks Gym](games/derks-gym/) | Bogatyr | none | full Nim | After **Derk's Gym**. Derk's Gym: PufferLib's Ocean MOBA with a pre-match loadout draft. |
| [Eleusis](games/eleusis/) | Elena Premudraya | required | prompt seat | After **Eleusis**. Eleusis: science as a game, for five LLM-piloted cogs. |
| [Flatland](games/flatland/) | Konyok-Gorbunok | required | prompt seat | After **the Flatland rail challenge**. A 28x14 rail network with switches, sidings and a flat crossing. |
| [Focus](games/focus/) | Finist Yasny Sokol | required | prompt seat | After **Focus**. Focus (Domination): Sid Sackson's stacking board game for two cogs. |
| [Fog Of War Boards](games/fog-of-war-boards/) | Morok | required | prompt seat | After **classic boards under kriegspiel fog**. Fog-of-War Boards: Phantom Tic-Tac-Toe and Dark Hex for two LLM-piloted cogs. |
| [Gen Generals Io](games/gen-generals-io/) | Suvorov | required | prompt seat | After **generals.io**. Four commanders, one crown each, on a seeded four-fold-symmetric grid. |
| [Generals Competition](games/generals-competition/) | Zhukov | none | full Nim | After **generals.io**. Classic 1v1 fog-of-war grid conquest on 18-21 square boards: capture the enemy general within 2000 turns. |
| [Gnomic](games/gnomic/) | Gnom Gnomych | none | full Nim | After **Nomic**. Three gnome elders of Heartleaf convene the Gnome Moot and rewrite Gnome Law while living under it: natural-language moves, self-amending ru… |
| [Goofspiel Oshi Zumo](games/goofspiel-oshi-zumo/) | Dubynya | required | prompt seat | After **Goofspiel and Oshi-Zumo**. Goofspiel / Oshi-Zumo: two simultaneous-move, zero-sum, budget-pacing games from OpenSpiel, ported as one coworld with one sim and two varia… |
| [Grf Football](games/grf-football/) | Alyosha Popovich | required | prompt seat | After **Google Research Football**. Eleven-a-side association football in a continuous 2D physics world: 22 cogs, one ball, throw-ins, corners and goal kicks. |
| [Grid Wars](games/grid-wars/) | Perun | required | prompt seat | After **Core War**. Grid Wars: Core Wars on a 30x30 toroidal grid, for four LLM-piloted cogs. |
| [Halite](games/halite/) | Stepan Razin | none | full Nim | After **Halite (Two Sigma)**. A bit-exact port of Kaggle's Halite IV (kaggle-environments 1.32.7). |
| [Hanabi](games/hanabi/) | Ognevushka | required | prompt seat | After **Hanabi**. Hanabi for four LLM-piloted cogs: the canonical ad-hoc-teamwork benchmark. |
| [Hidden Agenda](games/hidden_agenda/) | Chernobog | required | prompt seat | After **Melting Pot Hidden Agenda**. Five cogs mine a sealed station for a central grate. |
| [Hide And Seek](games/hide-and-seek/) | Pryatki | required | prompt seat | After **OpenAI hide-and-seek**. Three cogs hide, three cogs seek, nobody has a weapon. |
| [Hive](games/hive/) | Leshy | required | prompt seat | After **Hive**. Four ant colonies foraging one meadow. |
| [Infinite Blocks](games/infinite_blocks/) | Svarog | none | full Nim | After **Tetris**. A multiplayer BitWorld falling-blocks game where players stack pieces, clear lines, and compete for score on one shared board. |
| [Knights Archers](games/knights-archers/) | Dobrynya Nikitich | required | prompt seat | After **PettingZoo Knights-Archers-Zombies**. Four-seat cooperative horde defence. |
| [Liars Cog](games/liars-cog/) | Lisa Patrikeevna | none | full Nim | After **Liar's Dice**. Turn-based hidden-information bluffing game (Liar's Dice), implemented in Nim. |
| [Liars Dice](games/liars-dice/) | Munchausen | required | prompt seat | After **Liar's Dice**. Liar's Dice: a bluffing coworld for four LLM-piloted cogs. |
| [Lux Ai](games/lux-ai/) | Dazhbog | required | prompt seat | After **the Lux AI Challenge**. Lux AI Season 1 on a seeded, mirror-symmetric 16x16 island: two sides gather wood, coal and uranium, spend research to unlock the better fue… |
| [Magent Battle](games/magent-battle/) | Chernomor | required | prompt seat | After **MAgent Battle**. A port of MAgent2's battle_v4. |
| [Matrix Games](games/matrix-games/) | Anchutka | required | prompt seat | After **Melting Pot *_in_the_matrix**. Eight cogs, a yard full of tokens, and one payoff matrix that changes everything. |
| [Meadow](games/meadow/) | Poludnitsa | none | full Nim | After **the classic commons grazing experiment**. Round-based commons game: N players share one regenerating stock that dies permanently if over-harvested. |
| [Minecraft](games/minecraft/) | Zodchiy | required | prompt seat | After **Minecraft (ObtainDiamond)**. Minecraft, in spirit: one cog alone in a seeded blocky world of four stacked 32x32 levels - surface, stone, iron depth, diamond depth - and … |
| [Minigrid](games/minigrid/) | Kroshechka | required | prompt seat | After **MiniGrid / BabyAI**. Four cogs, each alone in its own private 13x13 walled gridworld it can only see 7x7 of, all four racing the SAME seeded five-task gauntlet a… |
| [Moba](games/moba/) | Zmey Gorynych | none | full Nim | After **Dota / LoL**. PufferLib's Ocean MOBA as a Coworld: a 5v5 lane-pushing battle arena, bit-exact with the upstream training environment (same C sim compiled … |
| [Nightshift](games/nightshift/) | Nochnitsa | none | full Nim | After **One Night Ultimate Werewolf**. One Night Ultimate Werewolf adaptation: a hidden-role social-deduction coworld that benchmarks modeling other minds under time pressure, acr… |
| [Nmmo](games/nmmo/) | Buyan | none | full Nim | After **Neural MMO**. PufferLib's Ocean NMMO3 (Neural MMO 3) as a Coworld: a persistent 512x512 survival world, bit-exact with the upstream training environment (… |
| [Nomic](games/nomic/) | Tsar Gorokh | none | full Nim | After **Nomic**. Three flavorful LLM delegates act inside and rewrite a living game: natural-language moves, self-amending rules, secret votes, deterministic… |
| [Nomic Fable](games/nomic-fable/) | Moska | none | full Nim | After **Nomic**. Nomic as a coworld: three players take turns proposing rule changes; after debate and a majority vote, a judge LLM enacts passed proposals a… |
| [Particle Worlds](games/particle-worlds/) | Stribog | required | prompt seat | After **multi-agent particle envs (MPE)**. Four particles glide on a bounded field around four coloured landmarks and play four MPE scenarios back to back: cover the marks together, h… |
| [Pistonball](games/pistonball/) | Vakula | required | prompt seat | After **PettingZoo Pistonball**. Pistonball: twenty LLM-piloted pistons and one ball. |
| [Planet Wars](games/planet_wars/) | Zvezdochet | none | full Nim | After **Galcon / Planet Wars**. A BitWorld strategy game where players conquer planets and launch ships across a tiny star map. |
| [Pommerman](games/pommerman/) | Tugarin Zmey | required | prompt seat | After **Bomberman**. Pommerman as a Coworld. |
| [Procgen](games/procgen/) | Skazochnik | required | prompt seat | After **Procgen**. One cog, eight procedurally generated 15x9 tile levels in a row, four archetypes: a maze with gems behind a locked door, an open room of pel… |
| [Rware Warehouse](games/rware-warehouse/) | Ovinnik | required | prompt seat | After **RWARE**. A port of semitable/robotic-warehouse (RWARE). |
| [Snake Royale](games/snake-royale/) | Zmeya | required | prompt seat | After **Slither.io / Tron**. Four snakes, one small grid, simultaneous moves. |
| [Sokoban](games/sokoban/) | Gruzchik | required | prompt seat | After **Sokoban**. SA Sokoban: one cog alone in a 10x10 walled room with four crates and four marked squares. |
| [Sugarscape](games/sugarscape/) | Masha | none | full Nim | After **Sugarscape**. Grow a target social distribution by submitting one declarative SugarLang ruleset. |
| [Sumo Traffic Signals](games/sumo-traffic-signals/) | Svetofor | required | prompt seat | After **SUMO / RESCO signal control**. Sixteen signalised intersections on a 4x4 city grid. |
| [Trick Taking](games/trick-taking/) | Pikovaya Dama | required | prompt seat | After **Euchre / Spades / Hearts / Oh Hell**. Trick-Taking: one engine, four rule modules, and no talking allowed. |
| [Walker Waterworld](games/walker-waterworld/) | Vodyanoy | required | prompt seat | After **SISL Multiwalker + Waterworld**. Four thruster skimmers feel for drifting plankton with 2.40 m sensors; nothing is caught unless two of them touch it at the same instant. |
| [Werecog](games/werecog/) | Volkolak | none | full Nim | After **Werewolf / Mafia**. A five-player hidden-role social-deduction benchmark (One Night Ultimate Werewolf): agents reason about secret roles and night card-swaps, b… |
| [Who Cried Wolf](games/who-cried-wolf/) | Volchok | none | full Nim | After **Mafia / Werewolf**. Nine-seat Mafia (NewD3 setups): two wolves, secret town roles, private team chats, majority votes, death reveals. |

## Board games — original turn-based rules games (34)

Terms, rules, discrete turns: the natural home of search (Monte Carlo /
minimax) and exact evaluation. Mostly cogame originals about economics,
negotiation, and social deduction.

| Game | Ours | LLM | Upload | What it is |
|------|------|-----|--------|------------|
| [Archers Warriors Mages](games/awm/) | Radogost | none | BASIC file | Five heroes play class cards in a free-for-all. Bounded MCTS searches card sequences with steered targets and rollouts. |
| [Babel](games/babel/) | Gamayun | required | prompt seat | Babel: an emergent-language referential game for four LLM-piloted cogs. |
| [Chemistry](games/chemistry/) | Baba Yaga | required | prompt seat | MP Chemistry: eight cogs, three autocatalytic vats, five molecule species -- two of which are useless. |
| [Chorus](games/chorus/) | Lel | required | prompt seat | Chorus: four LLM-piloted cogs write ONE piece of music together on a 16-step sequencer. |
| [Cogchemists](games/cogchemists/) | Vasilisa Premudraya | required | prompt seat | Cogchemists: eight ingredients, a hidden chemistry, and a career built on publishing first. |
| [Cogherence](games/cogherence/) | Alkonost | none | full Nim | A luminous hex-lattice, mixed-motive game for 3–6 LLM Cogs. |
| [Cogmud](games/cogmud/) | Kot Bayun | required | prompt seat | Cogmud: six LLM-piloted cogs loose in the nine-room town of Coppermarch for fourteen turns, where every move is ONE SENTENCE of plain Englis… |
| [Cogolf](games/cogolf/) | Balda | none | full Nim | Cogolf is a nine-hole match between two code agents. |
| [Cogsul](games/cogsul/) | Stavr Godinovich | none | full Nim | A single-winner redistribution-politics negotiation game: LLM agents talk, transfer Hearts, and vote a Consul who taxes everyone and splits … |
| [Coins](games/coins/) | Morozko | required | prompt seat | Coins is a real-time 7x7 grid room shared by exactly two cogs. |
| [Commons Family](games/commons_family/) | Bereginya | required | prompt seat | Six cogs share one destructible commons for twenty simultaneous rounds. |
| [Contagion](games/contagion/) | Likho | required | prompt seat | Contagion: six governors, one epidemic, nine roads. |
| [Cooperative Hunting](games/cooperative_hunting/) | Seryi Volk | required | prompt seat | Six hunters share a 32x32 tile forest. |
| [Daycare](games/daycare/) | Snegurochka | required | prompt seat | Daycare: one cog can reach the fruit, the other one knows which fruit it wants, and neither can say a word. |
| [Ecos](games/ecos/) | Berendey | required | prompt seat | Ecos: grass, grazers and predators on a continuous field, one seat per trophic role. |
| [Escrow](games/escrow/) | Vasily Buslaev | required | prompt seat | Escrow: binding contracts as a coworld, for four LLM-piloted cogs. |
| [Factory Commons](games/factory_commons/) | Khozyayka Mednoy Gory | required | prompt seat | Three cogs share one machine. |
| [Firm](games/firm/) | Stepan | required | prompt seat | Firm: one manager who sees the market, four workers who see the machines. |
| [Fruit Market](games/fruit-market/) | Zhar-Ptitsa | required | prompt seat | Apple farmers who crave bananas, banana farmers who crave apples, and offers that only clear when they mirror. |
| [Garble](games/garble/) | Govorun | required | prompt seat | Garble: five LLM-piloted cogs trade four commodities - ORE, OAT, TIN, TAR - over one shared radio and pairwise private lines, and EVERY chan… |
| [Gift Refinements](games/gift-refinements/) | Ded Moroz | required | prompt seat | Six cogs on a foundry floor. |
| [Gridlock](games/gridlock/) | Solovei Razboinik | required | prompt seat | Gridlock: four parcel fleets share one signalised 9x9 city. |
| [Lantern](games/lantern/) | Svetovid | required | prompt seat | Lantern: 3v3 hide-and-seek in the dark on a warehouse floor, played twice with the sides swapped. |
| [Ledger](games/ledger/) | Chichikov | required | prompt seat | Ledger: a repeated-dilemma tournament for eight LLM-piloted cogs where your name follows you. |
| [Lighthouse](games/lighthouse/) | Alatyr | required | prompt seat | Lighthouse: a cooperative maze game of structural information asymmetry for four LLM-piloted cogs. |
| [Muster](games/Muster/) | Ilya Muromets | none | full Nim | A spectator hex-RTS coworld: AI generals command armies across a world of floating sky-island arenas, racing inward through the rings to the… |
| [Negotiation Games](games/negotiation-games/) | Svakha | required | prompt seat | Negotiation Games: a three-seat bargaining table for LLM-piloted cogs, a port of OpenSpiel's `bargaining` (Lewis et al. |
| [Parley](games/parley/) | Boyan | required | prompt seat | Parley: a talkative last-cog-standing party game. |
| [Polis](games/polis/) | Marfa Posadnitsa | recommended | full Nim | Polis — Nomic with an economy: LLM cogs mine resources, build & align Commons datacenters onto research projects, trade shares on a bonding … |
| [Raid](games/raid/) | Ushkuynik | required | prompt seat | Raid: five LLM-piloted cogs against SMELTER-9, a fully scripted foundry boss. |
| [Rumor](games/rumor/) | Babarikha | required | prompt seat | Rumor: ten LLM-piloted cogs on a hidden social graph. |
| [Territory](games/territory/) | Volot | none | full Nim | Nine LLM Cogs paint their claim onto a hex lattice of resource walls. |
| [Tribunal](games/tribunal/) | Shemyaka | required | prompt seat | Tribunal: an adjudication coworld for five LLM-piloted cogs. |
| [Zero Sum](games/zero-sum/) | Belobog | none | full Nim | Battle royale for 16 agents in 8 teams of 2: a loot-stocked central Fortress, a shrinking ring of fire, open talk channels, sponsor softcoin… |

## Action games — real-time, keyboard-driven (15)

Continuous ticks and spatial control; execution (navigation, timing,
micro) dominates strategy.

| Game | Ours | LLM | Upload | What it is |
|------|------|-----|--------|------------|
| [Call To Adventure](games/call-to-adventure/) | Veles | none | .bas file | Four BASIC heroes explore a six-floor dungeon and race each other back to the surface with the fattest purse. |
| [Cogball](games/cogball/) | Nikita Kozhemyaka | required | prompt seat | 3v3 robot soccer in a continuous 2D physics world. |
| [Cogs vs Clips](games/cogs_vs_clips/) | Ivan Durak | none | full Nim | Cogs vs Clips and Four Score packaged as one Coworld backed by CogsGuard and MettaGrid. |
| [Emerg Ant](games/emerg-ant/) | Zlydni | none | full Nim | Emerg-ant is a 1v1 artificial-life colony duel. |
| [Gods Of The Arena](games/gods-of-the-arena/) | Khors | none | .bas file | Two teams of five BASIC heroes fight down three lanes to destroy the enemy fort; the clock scores zero for everyone. |
| [Heartleaf](games/heartleaf/) | Alyonushka | required | soul.md | A cozy BitWorld garden dinner game where players grow food, collect vegetables, and gather in the evening. |
| [Jumper](games/jumper/) | Sivka-Burka | none | full Nim | A cooperative BitWorld platformer where players cross pits, stack on each other, and reach the flag. |
| [Light Vs Dark](games/light-vs-dark/) | Zorya | none | .bas file | 1v1 BASIC real-time strategy: gather, build, and wipe the other overlord out or out-build them by the clock. |
| [Paintarena](games/paintarena/) | Marya Iskusnitsa | none | full Nim | Continuous tick-based territory painting game used to certify the Coworld contract. |
| [Paintbot](games/paintbot/) | Marya Morevna | none | full Nim | Paintbot: paintball-flavored capture-the-heart, AI bots only. |
| [Physics Bodies](games/physics-bodies/) | Kolobok Jr | required | prompt seat | Two four-legged robot bugs push each other out of a shrinking sumo ring; off-centre shoves spin you, and a bug that tips over cannot push fo… |
| [Proxywar](games/proxywar/) | Ivan Tsarevich | none | full Nim | Territorial strategy game: agents fight over a world map — expansion, economy, nukes, alliances, and betrayal when it pays. |
| [Tandem](games/tandem/) | Ivanushka | required | prompt seat | Two cogs, one couch, no channel: they are rigidly gripped to opposite handles and must carry it through a procedurally generated warehouse. |
| [Tribal Fortress](games/tribal_fortress/) | Usynya | none | full Nim | One shared Tribal world with strategy and adventure leagues that scale from two to eight entrants. |
| [Tribal Village](games/tribal_village/) | Yarilo | none | full Nim | A 2-8 team Tribal Village Coworld with six agents per village. |
