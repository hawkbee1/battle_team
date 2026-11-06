# Section AI, AI Agents and Server-Managed Sections

Status: **ready**. Built in milestone 1 (`milestones/m1-ai-and-automation.md`). Decisions come from the Q&A with the game designer; the decision numbers are in `specs/00-overview.md`. Each rule keeps its ID (`AI-NN`); changes go through a new decision.

## 1. Rules

### Player units
- **AI-01** A unit controlled by a player acts only on an order from that player. Nothing happens automatically for it: no fire, movement, healing, repair, capture, push or construction. (Decisions 156, 20.)
- **AI-02** A unit of an offline player stays passive on the field and can be attacked. Players are expected to store their units before leaving. (Decisions 156, 29.)

### AI agents and the API
- **AI-03** An AI agent acting through the API has the same rules and limits as a human player. Only the rate of its calls is limited, to stop floods. (Decision 157.)
- **AI-04** Each user account has one API key. The key identifies the user on every call. A user can revoke their own key, and an admin can revoke any key. (Decisions 158, 161.)
- **AI-05** Every action records its origin: the player, an AI (according to the API key used), or the server. (Decisions 162, 166.)

### Server-managed sections
- **AI-06** The server creates and runs some sections. They look the same as other sections, and can do everything a player's section can do. Their purpose is not written in the specs. (Decisions 159, 163.)
- **AI-07** A unit of a server-managed section that sees an enemy within its weapon range may fire. The chance, 50 %, is checked every 30 minutes from the battle start and is the same at each check. It is not rolled each time an enemy enters range. The values are placeholders in `data/battle.yaml`. The unit fires at the nearest enemy unit it can fire at, never at an HQ or an object. (Decisions 160, 196, 228, 229.)
- **AI-08** A shot by a server-managed unit follows the normal rules: the hit chance of COMBAT-15, like any unit acting under orders. (Decision 164.)
- **AI-09** The server gives the orders of its sections through the same API as AI agents. (Decision 165.)

## 2. Existing rules this touches
- Decision 20 (units without orders follow section AI behaviours) is revised by decision 156. Section AI no longer applies to player units.
- Decision 29 (offline units stay passive and can be attacked) is consistent with AI-02.
- COMBAT-15 and COMBAT-16 describe the hit chance under orders. AI-08 applies the same rule to server-managed shots.
- R-01 and R-07 (logging off) are unchanged by these rules.

## 3. Not written here
- The engine that triggers the server's API calls (AI-09). It is developed in a later phase. Decision 159 keeps the purpose of the server-managed sections out of the specs.
- The API itself is a technical design. It belongs to M2 (networking, Issue 3; accounts, Issue 6). The rules only require that each call identifies its user (AI-04).
- Server load: each server-managed unit is checked every 30 minutes, which keeps the load small. This feeds the estimate for a 1,000-unit battle (M2 Issue 1).
