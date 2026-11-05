# Economy

Status: **ready**. Decisions come from the Q&A with the game designer; changes go through `specs/95-open-questions.md`. Each rule has a stable ID (`ECO-NN`).

## 1. Who owns money
- **ECO-01** Money belongs to the **section** (its commander's wallet). There is no team or guild treasury.

## 2. Earning money
Already decided (overview):
- **ECO-02** successful hits on enemies, engineer constructions, enemy deaths, enemy HQ hits and HQ destruction; the shot that kills earns the hit and the kill (decisions 201, 202);
- **ECO-03** medics earn money for their section when healing other units.

## 3. Spending money
- **ECO-04** A commander buys **troops** for his section, only when the section has **free room** (UNIT-39, UNIT-40; decision 130).
- **ECO-05** A commander can buy **radios**.
- **ECO-06** A guild commander can buy the **guild encampment** (again at any time if destroyed).
- **ECO-07** A bought unit **arrives next to the section's portal**: the guild camp, or the HQ if the guild has no camp or the section has no guild (decision 130). Nothing is bought while an enemy blocks its arrival or the section is under its 24-hour lock (HQ-46, decision 205).

## 4. Transfers
- **ECO-08** Money can be **transferred between players**, with **fees**.
- **ECO-09** Fees are **lower between sections of the same guild**.
- **ECO-10** Transfers are allowed **only within the same team**.
- **ECO-11** Transfer fees are **destroyed** (removed from the game).

## 5. Persistence and safety net
- **ECO-12** A section's money is **kept from one battle to the next** within a war (like its units). It is lost at the end of the war with the section.
- **ECO-13** Safety net: when a commander dies or loses all his units, his money becomes `max(money, war.minStartingMoney)`. Deliberate abuse is accepted.
- **ECO-14** The **transfer + safety-net loop is accepted**: a player can give his money away, lose his units, get minStartingMoney back and repeat. Transfer fees are the only brake. Balancing note: keep minStartingMoney and fees tuned so this stays a minor source of money.

## 5b. Constructions
- **ECO-15** Engineers' constructions (walls, bridges, reinforced bridges, roads, ladders, traps) **cost no money**, only **AP and time**. Engineers even earn money by building.

## 6. Numbers (decision 112, `data/economy.yaml`)
- **ECO-16** Currency: **w€**. Every amount is a whole number of w€ (decision 200).
- **ECO-17** **Prices**: anything not priced costs **100 w€**; guild encampment **500 w€**. The designer adjusts prices over time.
- **ECO-18** **Money earned** by the acting unit's section: hit 1, kill 5, construction 5, heal 5, HQ hit 10, HQ destruction 100. A final blow that takes its target prisoner or turns it earns no kill money (decision 223).
- **ECO-19** **Transfer fees**: **2 %** inside a guild, **7 %** outside, taken from the amount sent and rounded to the nearest whole w€, halves up (decisions 200, 203).
- **ECO-20** **Starting money** of a new section = minStartingMoney = **500 w€** (decision 102).
- **ECO-21** **XP cannot be bought.**
- **ECO-22** **No limit** against build-and-destroy farming by engineers.
