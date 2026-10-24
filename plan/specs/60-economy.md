# Economy (working draft)

Status: draft. Decisions come from the Q&A with the game designer. Numbers are placeholders.

## 1. Who owns money
- Money belongs to the **section** (its commander's wallet). There is no team or guild treasury.

## 2. Earning money
Already decided (overview):
- successful hits, engineer constructions, enemy deaths, enemy HQ hits and HQ destruction;
- medics earn money for their section when healing other units.

## 3. Spending money
- A commander buys **troops** for his section (within the section size cap, which grows with commander XP).
- A commander can buy **radios**.
- A guild commander can buy the **guild encampment** (again at any time if destroyed).
- Newly bought troops **appear in storage (homeland)**, then are deployed through the section's portal (guild encampment, or HQ for sections without guild), following the storage rules.

## 4. Transfers
- Money can be **transferred between players**, with **fees**.
- Fees are **lower between sections of the same guild**.
- Transfers are allowed **only within the same team**.
- Transfer fees are **destroyed** (removed from the game).

## 5. Persistence and safety net
- A section's money is **kept from one battle to the next** within a war (like its units). It is lost at the end of the war with the section.
- Safety net: when a commander dies or loses all his units, his money becomes `max(money, war.minStartingMoney)`. Deliberate abuse is accepted.
- The **transfer + safety-net loop is accepted**: a player can give his money away, lose his units, get minStartingMoney back and repeat. Transfer fees are the only brake. Balancing note: keep minStartingMoney and fees tuned so this stays a minor source of money.

## 5b. Constructions
- Engineers' constructions (walls, bridges, reinforced bridges, roads, ladders, traps) **cost no money**, only **AP and time**. Engineers even earn money by building.

## 6. Open questions
- Prices of each troop type, radio and encampment (data file `data/units.yaml`).
- Amounts earned per action (hit, kill, construction, heal, HQ hit, HQ destruction).
- Transfer fee rates (inside guild / outside guild).
- AP cost and build time per construction type.
- Can XP be bought, or only earned? (Assumed only earned.)
- Starting money of a section entering a war (= minStartingMoney?).
- Engineers earn money by building and building is free: limits needed against "build and destroy" farming?
