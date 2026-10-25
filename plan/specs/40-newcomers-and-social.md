# Newcomers, Teams, Guilds and Communication

Status: **ready**. Decisions come from the Q&A with the game designer; changes go through `specs/95-open-questions.md`. Each rule has a stable ID (`SOC-NN`).

## 1. Team power and newcomer placement
- **SOC-01** Each team has a **power** value.
- **SOC-02** A new player is placed in the **team with the lowest power**.
- **SOC-03** Inside that team, the new player is offered **4 guilds picked at random** among the guilds that have **opted in to accept new players**. The player chooses one of them.
- **SOC-04** Why (research note): early friends and guild membership are the strongest predictors of staying; having a choice supports autonomy; joining the weakest team helps balance battles.

- **SOC-05** **Team power = unit XP + section XP** of the team. The rules have **no notion of active or inactive players**. (Decision 93)
- **SOC-06** A **new player** is **anyone joining**. (Decision 101)
- **SOC-07** If fewer than 4 opted-in guilds exist in the team, the list is **filled with randomly picked guilds that did not opt in**, up to 4. A team with fewer than 4 guilds shows all of them.
- **SOC-08** A guild can **leave the newcomer list at any time**, with **no reward or penalty**. (Decision 101)

- **SOC-09** **A player never leaves a battle.** He stays in his team for the whole battle. To take a break he **stores his whole section**; he can deploy again when he wants, but **not before 24 hours** after the last alive unit was stored. (Decision 120)

## 2. Money safety net (minStartingMoney)
- **SOC-10** When a commander **dies** or **loses all his units**, his money becomes:
  `money = max(money_before_event, war.minStartingMoney)`
- **SOC-11** `minStartingMoney` is a variable of the **war** entity. Its value comes from the war's lore and settings (to be defined).
- **SOC-12** Effect: a player can always rebuild a minimum section, which limits the "lost everything, quit" pattern seen with permadeath (research note B4, B5).

- **SOC-13** A **war** is a **series of battles**. Its settings and lore (including `minStartingMoney`) apply to all its battles.

- **SOC-14** **Abuse is accepted**: a player may lose units on purpose to get back to the floor. This is a design choice, not a bug.

- **SOC-15** `minStartingMoney` is **500 w€** and is also the **starting money of a new section**. (Decision 102)

## 2b. War lifecycle
- **SOC-16** An **admin starts a war**. A war is a series of battles planned by the admin.
- **SOC-17** A war **ends when no more battle is planned** by the admin.
- **SOC-18** A player's **section is created when he enters the war** and is **lost at the end of the war** (units, XP and evolution included).
- **SOC-19** At the end of each battle, every unit of every section in the **winning team** gains **victoryXp**.
- **SOC-20** At the start of each battle, **teams are created automatically**, **balanced by team power**; the **number of teams is a battle setting** (2 to 5). **Guild members always stay together** in the same team. (Decision 103)
- **SOC-21** There is **no war winner**. (Decision 104)
- **SOC-22** **War and battle statistics** are available during and after the war.

### What a player keeps after a war
- **SOC-23** **War and battle statistics**: the player can consult them during and after the war.
- **SOC-24** **War medals**: earned during a war, attached to that war.
- **SOC-25** **Game medals**: permanent, account-level.
- **SOC-26** Medals are **bronze, silver and gold** for **every kind of action and kill** (kills by target type: units, commanders, jeeps...), earned at **thresholds**. Example: bronze for killing 5 commanders. Thresholds in `data/medals.yaml`. (Decision 105)
- **SOC-27** **Cosmetics** for sections and units: bought with **real money** during a war, **kept after the war** and can be applied to other units later. They are **purely visual**. (Decision 106)
- **SOC-28** victoryXp: 1 XP per unit of the winning team (decision 92).

- **SOC-29** **Medal points**: bronze 1, silver 3, gold 10. The HQ manager is the player with the most points; on a tie, the one whose commander has the most XP. (Decision 121)
- **SOC-30** A player can **join a running war at any time**, entering the **current battle** (commander + 3 units at his team's starting point, decision 33). (Decision 122)

## 3. Communication is fundamental
Three channels are core features of the game, not extras:
- **SOC-31** **Team** communication.
- **SOC-32** **Guild** communication.
- **SOC-33** **Direct** player-to-player communication.

- **SOC-34** **No in-game spying**: enemies can never intercept or read communications.
- **SOC-35** **Most communication may happen on a Discord server** rather than in the game.

- **SOC-36** Communication **history is kept**.
- **SOC-37** **In game: pings and map markers only.** Everything else (team, guild and direct chat, voice) happens **on Discord**. (Decision 123)
- **SOC-38** **Game and Discord accounts are linked.** Access to Discord channels depends on the player's **sections** (their wars, teams and guilds). (Decision 126)
- **SOC-39** Moderation tools are deferred until after a few real battles (Q-SOC-11).

## 4. Players, commanders and sections
- **SOC-40** A **section** is owned by **one commander only**.
- **SOC-41** A **player can have several sections** (several commanders).
- **SOC-42** Only **one commander of a player per battle**. Several battles run at the same time, so a player can have commanders in several battles.

Confirmed: a player account holds several commanders; each commander leads one section; a commander and his section take part in at most one battle at a time; a player cannot bring two commanders into the same battle.

- **SOC-43** A section belongs to one war; it follows its commander through the battles of that war and is lost when the war ends.
- **SOC-44** A player's sections **share nothing**, except cosmetics bought with a sharing option. (Decision 107)
- **SOC-45** A player has **one commander per war** and can take part in **several wars at the same time**. (Decision 124)

## 5. Guilds (decision 108)
- **SOC-46** The **creator of a guild is its chief** (the guild commander). He can **hand the role to another member** and can **disband the guild**. The chief **cannot leave** the guild while he is chief.
- **SOC-47** **Maximum guild size depends on the guild level**, which rises with the **total XP earned by its sections while in the guild**.
- **SOC-48** A guild can have **a single section**.
- **SOC-49** A section can play **without a guild**; it then stores its units at the HQ.
