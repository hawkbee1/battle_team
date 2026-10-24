# Newcomers, Teams, Guilds and Communication (working draft)

Status: draft. Decisions come from the Q&A with the game designer. This is the priority topic chosen in `specs/90-research-topic-priority.md` (first week of a new player).

## 1. Team power and newcomer placement
- Each team has a **power** value.
- A new player is placed in the **team with the lowest power**.
- Inside that team, the new player is offered **4 guilds picked at random** among the guilds that have **opted in to accept new players**. The player chooses one of them.
- Why (research note): early friends and guild membership are the strongest predictors of staying; having a choice supports autonomy; joining the weakest team helps balance battles.

- **Team power** combines the team's **active (online) players** and its **unit power**. A unit's power score is its **XP value**. A team with few active players gets newcomers even if its units are strong. Exact formula and weights: to be defined (data file).
- If fewer than 4 opted-in guilds exist in the team, the list is **filled with randomly picked guilds that did not opt in**, up to 4.

Open:
- Weighting between active players and total XP; time window for "active".
- What if the team has fewer than 4 guilds in total?
- Is "new player" a new account, or also an existing player joining a new battle?
- Is placement re-evaluated when a player comes back to a battle, or is the team fixed for the whole battle?
- Can a guild leave the "accept new players" list at any time? Does accepting newcomers give the guild a reward?

## 2. Money safety net (minStartingMoney)
- When a commander **dies** or **loses all his units**, his money becomes:
  `money = max(money_before_event, war.minStartingMoney)`
- `minStartingMoney` is a variable of the **war** entity. Its value comes from the war's lore and settings (to be defined).
- Effect: a player can always rebuild a minimum section, which limits the "lost everything, quit" pattern seen with permadeath (research note B4, B5).

- A **war** is a **series of battles**. Its settings and lore (including `minStartingMoney`) apply to all its battles.

- **Abuse is accepted**: a player may lose units on purpose to get back to the floor. This is a design choice, not a bug.

Open:
- Value of minStartingMoney for each war (lore).

## 2b. War lifecycle
- An **admin starts a war**. A war is a series of battles planned by the admin.
- A war **ends when no more battle is planned** by the admin.
- A player's **section is created when he enters the war** and is **lost at the end of the war** (units, XP and evolution included).
- At the end of each battle, every unit of every section in the **winning team** gains **victoryXp**.
- At the start of each battle, **teams are created automatically** (rule to be defined). **Guild members always stay together** in the same team.
- **War and battle statistics** are available during and after the war.

### What a player keeps after a war
- **War and battle statistics**: the player can consult them during and after the war.
- **War medals**: earned during a war, attached to that war.
- **Game medals**: permanent, account-level.
- **Cosmetics** for sections and units: bought with **real money** during a war, **kept after the war** and can be applied to other units later. Cosmetics have no gameplay effect (to confirm).

Open:
- Team creation rule at each battle: balance by team power? Keep teams stable across battles of a war? Number of teams per battle.
- Is there a war winner, and how is it decided from battle results?
- List of war medals and game medals, and their criteria.
- Cosmetics: confirm they are purely visual (no stat or vision advantage, e.g. no camouflage effect).
- Can a player enter a war that is already running (between battles, during a battle)?
- Value of victoryXp; is it the same for every unit?

## 3. Communication is fundamental
Three channels are core features of the game, not extras:
- **Team** communication.
- **Guild** communication.
- **Direct** player-to-player communication.

- **No in-game spying**: enemies can never intercept or read communications.
- **Most communication may happen on a Discord server** rather than in the game.

Open:
- What remains in-game: map pings and markers, short orders, minimal chat?
- Discord integration level: account linking, automatic channels per war/team/guild, a bot that posts statistics and battle events.
- Moderation and blocking tools.

## 4. Players, commanders and sections
- A **section** is owned by **one commander only**.
- A **player can have several sections** (several commanders).
- Only **one commander of a player per battle**. Several battles run at the same time, so a player can have commanders in several battles.

Confirmed: a player account holds several commanders; each commander leads one section; a commander and his section take part in at most one battle at a time; a player cannot bring two commanders into the same battle.

Open:
- How a player gets additional commanders (purchase, progression, unlock).
- A section belongs to one war; it follows its commander through the battles of that war and is lost when the war ends.
- Can a player take part in several wars at the same time (one commander per war)?
- Do commanders of the same player share money or units?
