# Newcomers, Teams, Guilds and Communication (working draft)

Status: draft. Decisions come from the Q&A with the game designer. This is the priority topic chosen in `specs/90-research-topic-priority.md` (first week of a new player).

## 1. Team power and newcomer placement
- Each team has a **power** value.
- A new player is placed in the **team with the lowest power**.
- Inside that team, the new player is offered **4 guilds picked at random** among the guilds that have **opted in to accept new players**. The player chooses one of them.
- Why (research note): early friends and guild membership are the strongest predictors of staying; having a choice supports autonomy; joining the weakest team helps balance battles.

- **Team power = unit XP + section XP** of the team. The rules have **no notion of active or inactive players**. (Decision 93)
- A **new player** is **anyone joining**. (Decision 101)
- If fewer than 4 opted-in guilds exist in the team, the list is **filled with randomly picked guilds that did not opt in**, up to 4. A team with fewer than 4 guilds shows all of them.
- A guild can **leave the newcomer list at any time**, with **no reward or penalty**. (Decision 101)

- **A player never leaves a battle.** He stays in his team for the whole battle. To take a break he **stores his whole section**; he can deploy again when he wants, but **not before 24 hours** after the last alive unit was stored. (Decision 120)

## 2. Money safety net (minStartingMoney)
- When a commander **dies** or **loses all his units**, his money becomes:
  `money = max(money_before_event, war.minStartingMoney)`
- `minStartingMoney` is a variable of the **war** entity. Its value comes from the war's lore and settings (to be defined).
- Effect: a player can always rebuild a minimum section, which limits the "lost everything, quit" pattern seen with permadeath (research note B4, B5).

- A **war** is a **series of battles**. Its settings and lore (including `minStartingMoney`) apply to all its battles.

- **Abuse is accepted**: a player may lose units on purpose to get back to the floor. This is a design choice, not a bug.

- `minStartingMoney` is **500 w€** and is also the **starting money of a new section**. (Decision 102)

## 2b. War lifecycle
- An **admin starts a war**. A war is a series of battles planned by the admin.
- A war **ends when no more battle is planned** by the admin.
- A player's **section is created when he enters the war** and is **lost at the end of the war** (units, XP and evolution included).
- At the end of each battle, every unit of every section in the **winning team** gains **victoryXp**.
- At the start of each battle, **teams are created automatically**, **balanced by team power**; the **number of teams is a battle setting** (2 to 5). **Guild members always stay together** in the same team. (Decision 103)
- There is **no war winner**. (Decision 104)
- **War and battle statistics** are available during and after the war.

### What a player keeps after a war
- **War and battle statistics**: the player can consult them during and after the war.
- **War medals**: earned during a war, attached to that war.
- **Game medals**: permanent, account-level.
- Medals are **bronze, silver and gold** for **every kind of action and kill** (kills by target type: units, commanders, jeeps...), earned at **thresholds**. Example: bronze for killing 5 commanders. Thresholds in `data/medals.yaml`. (Decision 105)
- **Cosmetics** for sections and units: bought with **real money** during a war, **kept after the war** and can be applied to other units later. They are **purely visual**. (Decision 106)
- victoryXp: 1 XP per unit of the winning team (decision 92).

- **Medal points**: bronze 1, silver 3, gold 10. The HQ manager is the player with the most points; on a tie, the one whose commander has the most XP. (Decision 121)
- A player can **join a running war at any time**, entering the **current battle** (commander + 3 units at his team's starting point, decision 33). (Decision 122)

## 3. Communication is fundamental
Three channels are core features of the game, not extras:
- **Team** communication.
- **Guild** communication.
- **Direct** player-to-player communication.

- **No in-game spying**: enemies can never intercept or read communications.
- **Most communication may happen on a Discord server** rather than in the game.

- Communication **history is kept**.
- **In game: pings and map markers only.** Everything else (team, guild and direct chat, voice) happens **on Discord**. (Decision 123)
- Open: Q-SOC-14 (Discord integration details). Moderation tools are deferred until after a few real battles (Q-SOC-11).

## 4. Players, commanders and sections
- A **section** is owned by **one commander only**.
- A **player can have several sections** (several commanders).
- Only **one commander of a player per battle**. Several battles run at the same time, so a player can have commanders in several battles.

Confirmed: a player account holds several commanders; each commander leads one section; a commander and his section take part in at most one battle at a time; a player cannot bring two commanders into the same battle.

- A section belongs to one war; it follows its commander through the battles of that war and is lost when the war ends.
- A player's sections **share nothing**, except cosmetics bought with a sharing option. (Decision 107)
- A player has **one commander per war** and can take part in **several wars at the same time**. (Decision 124)

## 5. Guilds (decision 108)
- The **creator of a guild is its chief** (the guild commander). He can **hand the role to another member** and can **disband the guild**. The chief **cannot leave** the guild while he is chief.
- **Maximum guild size depends on the guild level**, which rises with the **total XP earned by its sections while in the guild**.
- A guild can have **a single section**.
- A section can play **without a guild**; it then stores its units at the HQ.
