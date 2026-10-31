# Design risks

Status: **tracking**. Risks found in reviews that no decision addresses yet. Nothing here is a rule. Accepted risks are reviewed after a few real battles (milestone M8). Each risk keeps its ID (`R-NN`, never renumbered) and has a status:
- **open**: to settle with a decision, or to accept;
- **accepted for now**: the designer knows it and chose to wait (date);
- **closed**: settled by a decision in `00-overview.md` (its number is noted).

The numbers below come from `data/*.yaml` at the time of the review. They are placeholders and change with tuning.

| ID | Risk | Status |
|---|---|---|
| R-01 | A commander's death is a free instant recall and a money top-up | accepted for now (2026-10-31) |
| R-02 | Money is paid per hit, not per damage | accepted for now (2026-10-31) |
| R-03 | A newcomer's first week has no rule | open |
| R-04 | A newcomer cannot join friends | open |
| R-05 | Team power counts players who left | open |
| R-06 | Nothing ends a stalemated battle | open |
| R-07 | One player or one unit can block a whole group | open |
| R-08 | Tuning notes for the scenario harness | open |

## R-01 A commander's death is a free instant recall and a money top-up
Accepted for now (designer, 2026-10-31).
- When a commander dies, every unit of his section on the field goes to storage at once (UNIT-29), with no 24-hour lock (decision 125), and his money becomes at least `minStartingMoney` (SOC-10).
- Friendly fire does full damage (COMBAT-34), and the XP penalty only takes unspent XP (UNIT-29).
- So a surrounded section, or a player who wants to log off, can have a teammate shoot the commander. That skips the 6-hour recall, which the design note under HQ-32 calls the only thing that stops units from escaping fights.
- A player who first transfers his money away gets 500 w€ back each time without losing a unit. ECO-14 accepted the transfer loop on the assumption that units are lost.

## R-02 Money is paid per hit, not per damage
Accepted for now (designer, 2026-10-31).
- Destroying the 1,000 HP HQ earns about 25,000 w€ in hit money with machine guns (0.4 damage per hit, 10 w€ per HQ hit), and 90 w€ with explosive charges (ECO-18).
- Nothing excludes hits on relics (0 damage), on allies or on the team's own structures; only XP excludes allies (UNIT-10).
- A heal pays 5 w€ whatever it restores. A medic healing a teammate that a friendly rifleman keeps shooting earns about 2,700 w€/h. The build-and-destroy loop accepted in ECO-22 earns about 60 w€/h per engineer. Guild camps can heal too (decision 141).

## R-03 A newcomer's first week has no rule
The research note (`specs/90-research-topic-priority.md`) ranks it as the topic with the highest impact.
- There is no protection from veterans, no mentoring and no death recap. The note cites EVE players who quit because they "don't understand what happened" (A3).
- Decision 77's XP multiplier never goes below ×1, so killing new units pays as well as anything else.
- With the ×3 stat cap (decision 118), a veteran unit can have 3× HP and 3× AP regen.
- Decision 129 puts every new section in a guild as a trainee, awaiting the chief's acceptance (decision 146). It gives newcomers a group, not protection.

## R-04 A newcomer cannot join friends
- Placement forces the weakest team (SOC-02) and offers 4 random guilds (SOC-03). There is no invitation path, although the research note names friends and guilds as the strongest reason players stay (A2, B2).
- Whether a guild survives the end of a war is undefined. If it does not, that strongest reason is lost at every war end.

## R-05 Team power counts players who left
- Team power is unit XP + section XP, with no notion of active players (decision 93).
- About 90 % of new players leave a persistent PvP game within a week (research note, A1). Team balancing (SOC-20) and newcomer placement (SOC-02) will then be driven by sections whose players are gone.

## R-06 Nothing ends a stalemated battle
- A battle ends only with the last HQ standing or 5 relics held for 24 hours (RELIC-14). There is no time limit and no stalemate rule; the research note ranks stalemate breaking second (Foxhole, A5).
- A war ends when no more battle is planned (SOC-17), so a battle that never ends blocks its war.

## R-07 One player or one unit can block a whole group
- An absent HQ manager freezes HQ moves and team orders for as long as he is away; there is no fallback (HQ-08).
- One enemy unit parked within 20 m of a guild camp keeps all the guild's stored units in storage, and they cannot deploy from the HQ instead (HQ-36, HQ-39). New units arriving at the camp are blocked too (decision 147).
- Logging off safely means walking back within 10 m of the storage place or waiting for a 6-hour recall, and storing everything starts the 24-hour lock (HQ-35). That makes R-01 the easiest way to log off.

## R-08 Tuning notes for the scenario harness (M4 Issue 11)
- Sustained speed is about `ap_regen ÷ AP per metre`. A soldier empties its 60 AP in about 17 s; after that every ground unit moves at 1 to 2 m/s off-road, so `move_speed` only matters in short bursts.
- Vision is much shorter than weapon range: a soldier sees 150 m (60 m in fog), while weapon ranges go from 250 to 1,200 m. An anti-air soldier sees a helicopter at 150 m; the helicopter's height bonus lets it see him at 450 m.
- At 5 m per hour (decision 138), a pushed relic or HQ moves 120 m a day: about 8 days for 1 km, on maps up to 50 km long. Each pusher spends 10 AP per hour, so AP never limits a push, and units in the path can always step aside before being crushed.
