# The Cogiavelli board - Italy, 1499

42 areas: 36 land provinces (24 of them cities) and 6 seas. There are NO SPLIT COASTS anywhere: every
province that touches two seas touches two ADJACENT seas, so `SPA/NC`-style coast notation does not
exist and never has to be disambiguated.

## The land

| code | name | kind | city | land neighbours | seas |
|---|---|---|---|---|---|
| TUR | Turin | inland | neutral | SAV PAV GEN MIL | - |
| SAV | Savoy | inland | | TUR GEN PAV | - |
| COM | Como | inland | MILAN | MIL TRE | - |
| MIL | Milan | inland | MILAN | TUR COM PAV MAN | - |
| PAV | Pavia | inland | MILAN | TUR SAV MIL GEN MAN MOD | - |
| GEN | Genoa | coastal | neutral | TUR SAV PAV MOD PIS | LIG |
| TRE | Trent | inland | | COM VER MAN | - |
| MAN | Mantua | inland | | MIL PAV TRE VER MOD FER | - |
| VER | Verona | inland | VENICE | TRE MAN PAD FER | - |
| PAD | Padua | inland | VENICE | VER VEN FER FRI | - |
| VEN | Venice | coastal | VENICE | PAD FRI FER | UAD |
| FRI | Friuli | coastal | | PAD VEN TRI | UAD |
| TRI | Trieste | coastal | neutral | FRI BOS | UAD |
| FER | Ferrara | coastal | neutral | MAN VER PAD VEN BOL RMG | UAD |
| MOD | Modena | inland | | GEN PAV MAN BOL PIS | - |
| BOL | Bologna | inland | neutral | FER MOD RMG FLO | - |
| RMG | Romagna | coastal | | FER BOL FLO URB | UAD |
| PIS | Pisa | coastal | FLORENCE | GEN MOD FLO SIE | LIG UTS |
| FLO | Florence | inland | FLORENCE | BOL RMG PIS SIE URB | - |
| SIE | Siena | inland | FLORENCE | PIS FLO PER ROM | - |
| URB | Urbino | inland | | RMG FLO PER ANC | - |
| ANC | Ancona | coastal | PAPACY | URB PER ABR | LAD |
| PER | Perugia | inland | PAPACY | SIE URB ANC ROM ABR | - |
| ROM | Rome | coastal | PAPACY | SIE PER ABR NAP | UTS LTS |
| ABR | Abruzzi | coastal | | ANC PER ROM NAP APU | LAD |
| NAP | Naples | coastal | NAPLES | ROM ABR APU CAL | LTS |
| APU | Apulia | coastal | | ABR NAP BAR CAL | LAD |
| BAR | Bari | coastal | NAPLES | APU CAL | LAD |
| CAL | Calabria | coastal | | NAP APU BAR | LTS ION |
| MES | Messina | coastal | neutral | PAL | LTS ION |
| PAL | Palermo | coastal | NAPLES | MES | LTS |
| BOS | Bosnia | inland | | TRI RAG ALB | - |
| RAG | Ragusa | coastal | TURK | BOS ALB | LAD |
| ALB | Albania | inland | | BOS RAG DUR AVL | - |
| DUR | Durazzo | coastal | TURK | ALB AVL | LAD |
| AVL | Avlona | coastal | TURK | ALB DUR | LAD ION |

## The seas

LIG Ligurian Sea (touches UTS) - UTS Upper Tyrrhenian Sea (LIG, LTS) - LTS Lower Tyrrhenian Sea
(UTS, ION) - ION Ionian Sea (LTS, LAD) - LAD Lower Adriatic Sea (ION, UAD) - UAD Upper Adriatic Sea
(LAD). A sea is adjacent to exactly the coastal provinces that list it in the table above.

## The 24 cities

Home cities (18): VEN PAD VER (Venice) - MIL PAV COM (Milan) - FLO PIS SIE (Florence) -
ROM ANC PER (Papacy) - NAP BAR PAL (Naples) - RAG DUR AVL (Turk).
Neutral at start (6): TUR GEN TRI FER BOL MES.

## The two movement graphs

- ARMIES move on the land-neighbour column, land provinces only. An army never enters a sea and is
  never adjacent to one.
- FLEETS move on: sea-to-sea edges; sea to each of its coastal provinces; COAST-HOPS, meaning two
  coastal provinces that are land-adjacent AND share at least one sea (GEN-PIS on the Ligurian,
  DUR-AVL on the Lower Adriatic; BAR-CAL is NOT a coast-hop, because they share no sea); and exactly
  one fleet-only edge, CAL-MES, THE STRAIT OF MESSINA. A fleet never enters an inland province.
- AN ARMY REACHES SICILY (MES, PAL) ONLY BY CONVOY. Sicily is the only part of the land graph that is
  not connected to the mainland by land.

## The 18 starting units

Venice A VER, A PAD, F VEN - Milan A MIL, A PAV, A COM - Florence A FLO, A SIE, F PIS -
Papacy A ROM, A PER, F ANC - Naples A NAP, A BAR, F PAL - Turk A DUR, A AVL, F RAG.
Every power starts with 12 ducats.

## Order notation

One grammar, whitespace- and case-tolerant; `-`, `-` and `->` all read as a move, and
S/SUPPORT, C/CONVOY, H/HOLD/HOLDS are all accepted.

    A VER H                  the army in Verona holds
    A VER - MAN              the army in Verona moves to Mantua
    A BAR - PAL VIA CONVOY   the army in Bari is carried to Palermo by sea
    F VEN S A PAD - FER      the fleet in Venice supports Padua's move to Ferrara
    F VEN S A PAD            the fleet in Venice supports Padua's hold
    F LAD C A BAR - RAG      the fleet in the Lower Adriatic convoys Bari to Ragusa

Worked examples:

    A URB - ANC  +  A PER S A URB - ANC   beats  F ANC H         Ancona is taken, the fleet retreats
    A VER - MAN  +  A MOD - MAN                                   both bounce, STANDOFF in Mantua
    A MAN - VER  cuts  A VER S A PAD - FER                        so the attack on Ferrara fails
    A BAR - AVL VIA CONVOY  +  F LAD C A BAR - AVL                the army crosses the Adriatic

Each seat is handed the COMPLETE list of legal orders for each of its own units, in exactly this
notation, in its orders prompt; an order that is not on that list becomes a hold.
