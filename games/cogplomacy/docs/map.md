# The 1901 map and the order notation

## Provinces

75 provinces: 56 land (14 inland, 42 coastal) and 19 sea spaces. The viewer and the feed always print the full name; the codes below are what an order uses.

### Sea spaces (19)

ADR Adriatic Sea · AEG Aegean Sea · BAL Baltic Sea · BAR Barents Sea · BLA Black Sea · BOT Gulf of Bothnia · EAS Eastern Mediterranean · ENG English Channel · GOL Gulf of Lyon · HEL Helgoland Bight · ION Ionian Sea · IRI Irish Sea · MAO Mid-Atlantic Ocean · NAO North Atlantic Ocean · NTH North Sea · NWG Norwegian Sea · SKA Skagerrak · TYS Tyrrhenian Sea · WES Western Mediterranean

### Inland provinces (14)

BOH Bohemia · BUD Budapest* · BUR Burgundy · GAL Galicia · MOS Moscow* · MUN Munich* · PAR Paris* · RUH Ruhr · SER Serbia* · SIL Silesia · TYR Tyrolia · UKR Ukraine · VIE Vienna* · WAR Warsaw*

### Coastal provinces (42)

ALB Albania · ANK Ankara* · APU Apulia · ARM Armenia · BEL Belgium* · BER Berlin* · BRE Brest* · BUL Bulgaria* · CLY Clyde · CON Constantinople* · DEN Denmark* · EDI Edinburgh* · FIN Finland · GAS Gascony · GRE Greece* · HOL Holland* · KIE Kiel* · LON London* · LVN Livonia · LVP Liverpool* · MAR Marseilles* · NAF North Africa · NAP Naples* · NWY Norway* · PIC Picardy · PIE Piedmont · POR Portugal* · PRU Prussia · ROM Rome* · RUM Rumania* · SEV Sevastopol* · SMY Smyrna* · SPA Spain* · STP St Petersburg* · SWE Sweden* · SYR Syria · TRI Trieste* · TUN Tunis* · TUS Tuscany · VEN Venice* · WAL Wales · YOR Yorkshire

`*` marks a supply centre.

## Supply centres (34)

**Home centres (22).** Austria VIE BUD TRI · England LON EDI LVP · France PAR MAR BRE · Germany BER MUN KIE · Italy ROM VEN NAP · Russia MOS WAR SEV STP · Turkey CON SMY ANK.

**Neutrals (12).** NWY SWE DEN HOL BEL SPA POR TUN SER RUM BUL GRE.

## Split coasts

Three provinces have two coasts each, modelled as distinct fleet nodes that share one province for occupancy, ownership and army movement:

- **SPA/NC** (Gascony, Mid-Atlantic, Portugal) and **SPA/SC** (Gulf of Lyon, Mid-Atlantic, Marseilles, Portugal, Western Mediterranean)
- **STP/NC** (Barents, Norway) and **STP/SC** (Gulf of Bothnia, Finland, Livonia)
- **BUL/EC** (Black Sea, Constantinople, Rumania) and **BUL/SC** (Aegean, Constantinople, Greece)

A fleet move into one of these that names no coast when both are reachable is `ambiguouscoast` and becomes a hold; where only one coast is reachable the coast is filled in silently.

## Starting units (22, Spring 1901)

- Austria: A VIE, A BUD, F TRI
- England: F LON, F EDI, A LVP
- France: A PAR, A MAR, F BRE
- Germany: A BER, A MUN, F KIE
- Italy: A ROM, A VEN, F NAP
- Russia: A MOS, A WAR, F SEV, F STP/SC
- Turkey: A CON, A SMY, F ANK

## Order notation

One grammar for reading and writing. Case-insensitive; `-`, `–` and `->` all mean a move.

| form | meaning |
|---|---|
| `A PAR H` | hold |
| `A PAR - BUR` | move |
| `A PAR - BUR VIA CONVOY` | move, demanding a convoy |
| `F BRE S A PAR` | support a hold |
| `F BRE S A PAR - PIC` | support a move |
| `F ENG C A LON - BRE` | convoy |
| `F STP/SC - BOT` | a fleet on a named coast |
| `A VIE - TYR` / `A VIE - D` | retreat, or disband |
| `BUILD F STP/SC` | winter build |
| `DISBAND A MOS` | winter disband |

In an orders phase the prompt lists **every legal order for every one of your units** in exactly this notation; an order that is not legal becomes a hold and is reported with its reason.
