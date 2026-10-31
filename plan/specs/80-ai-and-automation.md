# Section AI and Automation

Status: **draft**. Built in milestone 1 (`milestones/m1-ai-and-automation.md`). The discussion starts at the top level: the principles in section 1 and the questions in section 3. Precise rules (behaviours, targeting, numbers) come only after those answers. Open points are `Q-AI-NN` in `specs/95-open-questions.md`.

## 1. Principles stated by the designer (2026-10-31)
Not yet numbered decisions. They become decisions in `specs/00-overview.md` when the top-level discussion closes.

- **No automatic fire and no automatic action for player units.** A unit controlled by a player, or acting for a player through the API, acts only on an order.
- **An API** exposes the game's actions to the app and to AI agents. Every call carries a code that clearly identifies the user. An AI agent can use the API to trigger actions.
- **Server-managed sections.** The server creates and runs some sections. They have a limited automaticity, and it is not reflexive: a unit does not fire each time an enemy enters its range. A unit of such a section that sees an enemy in range fires with a chance, checked periodically (for example every 30 minutes).

## 2. What the existing rules say
These rules predate the principles above, so they must be checked against them.
- Decision 20: units not directly controlled follow simple section AI behaviours (follow, hold, patrol).
- Decision 29: units of an offline player stay passive on the field and can be attacked. Players are expected to store them before leaving.
- COMBAT-15 and COMBAT-16: a unit acting under orders or section AI uses a hit chance, and both control modes should give comparable results.
- COMBAT-11 and COMBAT-12: a unit fires only at what it sees. Artillery can also fire at a ground position its section sees, or one a scout reports by radio.
- HQ-32, R-01 and R-07: a recall takes 6 hours and cannot be stopped; logging off is the costly part.

## 3. Questions to settle first
The proposals are a starting point for the discussion. They are not rules.

- **Q-AI-01** A player unit with no order: does it stay where it is, or does it follow a simple behaviour (follow the commander, hold)? Proposal: it stays where it is and does not fire. A movement behaviour can be added later if the designer wants one.
- **Q-AI-02** Units of an offline player: do they behave like Q-AI-01 (idle, can be attacked, decision 29), or differently? Proposal: the same as Q-AI-01.
- **Q-AI-03** AI agents using the API: do they follow the same rules and limits as a human player (same AP, one commander per battle, same actions), or do they have limits of their own? Proposal: the same rules. Only the rate of calls is limited, to stop floods.
- **Q-AI-04** Keys: one key per user account, or one key per agent? Can a key be revoked? Which sections can it act for? Proposal: one key per agent, revocable, acting only for the user's own sections. Every action is logged under the user.
- **Q-AI-05** Server-managed sections: what are they for (filling battles, defending an HQ, a training ground, something else)? Which units do they have? Are they visible to players as sections of other players? No proposal yet.
- **Q-AI-06** Server-managed sections: is the chance to fire the same for every target and every unit? Is it checked every 30 minutes, or on another rhythm? Proposal: a fixed chance per check, with the values in `data/battle.yaml`, set later.

## 4. Later, after section 3
- Precise behaviours, targeting, and what happens to friendly fire.
- Queued orders, waypoints and timed orders.
- The number of server-managed units that decide per tick, which is the input for the server load of a 1,000-unit battle (M2 Issue 1).
- The API itself is a technical design: it belongs to M2 (networking, Issue 3; accounts, Issue 6). The rules only require that each call identifies its user.
