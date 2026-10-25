# Economy (working draft)

Status: draft. Decisions come from the Q&A with the game designer. Numbers are placeholders.

## 1. Who owns money
- Money belongs to the **section** (its commander's wallet). There is no team or guild treasury.

## 2. Earning money
Already decided (overview):
- successful hits, engineer constructions, enemy deaths, enemy HQ hits and HQ destruction;
- medics earn money for their section when healing other units.

## 3. Spending money
- A commander buys **troops** for his section (within the section size cap, which grows with the commander level).
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

## 6. Numbers (decision 112, `data/economy.yaml`)
- Currency: **w€**.
- **Prices**: anything not priced costs **100 w€**; guild encampment **500 w€**. The designer adjusts prices over time.
- **Money earned** by the acting unit's section: hit 1, kill 5, construction 5, heal 5, HQ hit 10, HQ destruction 100.
- **Transfer fees**: **2 %** inside a guild, **7 %** outside.
- **Starting money** of a new section = minStartingMoney = **500 w€** (decision 102).
- **XP cannot be bought.**
- **No limit** against build-and-destroy farming by engineers.

- **Constructions** cost **AP paid up front plus a build time** per structure, **no money** (decision 113, confirms 25d). Values in `data/terrain.yaml` (`objects`).
