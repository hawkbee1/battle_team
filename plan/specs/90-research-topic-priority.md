# Research note: which design topic matters most for success

Date: 2026-10-14. Status: research input for the spec, not a decision.

## Conclusion
The topic with the highest impact is **the first week of a new player**: how a newcomer joins a small group (section, guild), how they feel competent despite veterans with permanent, evolved units, and how they experience their first losses under permadeath.

Industry reports (part A) and peer-reviewed research (part B) point the same way. The academic work adds three precise levers:
1. **Competence**: early losing streaks and feeling outclassed are linked to quitting.
2. **Relatedness**: friends and guild ties predict staying, especially early; random crowds do not.
3. **Meaningful loss**: permadeath is not bad in itself; players accept it when the loss is understood and meaningful.

---

## Part A. Industry evidence (developer statements, press)

### A1. Most players of persistent PvP games quit in the first hours or days
- EVE Online: CCP's data shows "about 90 percent of incoming players drop out after a week" (Prima Games interview with CCP).
- EVE Online, 2016: of more than 1.5 million new sign-ups in a year, "the overwhelming majority of them permanently quit after two hours" (Destructoid).
- PlanetSide 2: developers wrote that "long-time players know how brutal this game can be to a fresh recruit" and added mentors, tutorials and a death camera (official dev letter, Aug. 2019).

### A2. Social ties are the strongest retention lever
- EVE Online: "new players that are sought out by others are twice as likely to stay" (CCP, Prima Games).

### A3. Early losses drive players away
- EVE Online: "many players quit the game upon losing their first ship, as they don't understand what happened" (TechRaptor reporting CCP, Sept. 2019).

### A4. Successful full-loss games make risk opt-in and graduated
- Albion Online zones: blue (no PvP), yellow (PvP but "you keep your items"), red and black (full loot) (community guide).

### A5. Persistent wars must stay accessible to late joiners
- Foxhole: in 2025 the developers changed victory conditions during a 70-day stalemate so that "new players who joined Charlie last month" could experience the war properly (Indian Defence Review, June 2025).
- Crowfall used time-limited campaigns to avoid "new players having nowhere to go and no chance of a meaningful impact", but still failed for population and niche-PvP reasons (Massively Overpowered).

---

## Part B. Academic evidence (peer-reviewed or conference papers)

### B1. Psychology of motivation: competence, autonomy, relatedness predict future play
- Ryan, Rigby & Przybylski (2006), *Motivation and Emotion* 30, 347–363. Four studies based on Self-Determination Theory. In the MMO study (n = 730), **competence, autonomy and relatedness each made a significant unique contribution to intention of future play** (β ≈ .12–.15), while Yee's motivation types (achievement, social, immersion) did not predict future play. Competence and relatedness also predicted hours played per week.
- Implication: a newcomer facing evolved veterans risks low competence; a newcomer alone risks low relatedness. Both are measured drivers of whether people keep playing.

### B2. Friends and guilds predict retention, especially early
- Park, Cha, Kwak & Chen (2017), WWW '17 Companion. Logs of 51,104 players of an MMORPG (Fairyland Online). In early phases (levels 10–35), **number of friends predicted progression success** (estimates ≈ +0.53 to +0.61, p < .001), while **interacting with many non-friends was negative** (−0.33, p < .001). At the top level, friends were the only significant predictor of not churning (+0.97, p < .001).
- Debeauvais, Nardi, Schiano, Ducheneaut & Yee (2010/2011), "If you build it they might stay: retention mechanisms in World of Warcraft". Survey of 2,865 players. **Stop rate fell with guild role: 88% (no guild) → 79% (member) → 71% (officer/guild master)**; weekly play rose from 19 to 24 hours.
- Huang, Neidhardt & Contractor (2014), Sunbelt conference, EverQuest II data. Players with more teammates and those in a guild were less likely to quit; **the likelihood of quitting increased with the number of teammates who quit** (social contagion).
- Nuance: Ducheneaut, Yee, Nickell & Moore (2006), CHI '06 "Alone together?" found that social activity in MMOs had been over-estimated; many players play near others rather than with them. Design cannot force socialising; it must make groups useful and easy to join.
- Implication: sections and guilds are BattleTeam's main retention tool. A newcomer should land in a small, stable group rather than a large anonymous crowd. Losing a guild has a contagion effect, which matters for permadeath and HQ destruction.

### B3. Losing streaks are linked to churn
- Chen, Xue, Kolen, Aghdaie, Zaman, Sun & Seif El-Nasr (2017), "EOMM: An Engagement Optimized Matchmaking Framework", WWW 2017 (Electronic Arts data: 36.9 million matches, 1.68 million players). **7-day churn risk after three losses (LLL) was 5.1%, almost double the safest sequences (≈2.6%)**. Engagement-aware matchmaking retained ≈0.7% more players per round in simulation.
- Implication: in a 100+ player war where newcomers meet veterans, repeated early defeats are a measurable churn risk. Who a newcomer fights early matters.

### B4. Losses weigh more than gains
- Tversky & Kahneman (1991), "Loss Aversion in Riskless Choice: A Reference-Dependent Model", *Quarterly Journal of Economics* 106(4), 1039–1061: losses and disadvantages have greater impact on preferences than equivalent gains.
- Implication: losing a permanent, evolved unit will feel worse than gaining an equivalent unit feels good. Permadeath of invested units needs careful framing and limits.

### B5. Permadeath can be positive when it is meaningful
- Carter & Allison (2017), "Fear, loss and meaningful play: Permadeath in DayZ", *Journal of Gaming & Virtual Worlds* 9(2), 143–158: comparing good and bad permadeath experiences, **meaningfulness** is essential for players to experience permadeath positively.
- Cuerdo, Mahajan & Melcer (2021), "Die-r Consequences", IEEE Conference on Games: in a lab study (n = 72), permadeath scored higher than checkpoints on autonomy (p = .037) and curiosity (p = .005).
- Implication: keep permadeath (it creates tension and meaning) but make each loss understandable (what happened, why) and proportionate. This matches EVE's observation that players quit when they "don't understand what happened".

---

## What the evidence does not show
- Most academic data come from MMORPGs (WoW, EverQuest II, Fairyland) and 1v1 matches, not from persistent mass-war games. Transfer to BattleTeam is a reasoned assumption.
- All retention studies cited are correlational: they show links, not causes.
- No study found directly measures the effect of a veteran power gap from permanent upgrades. That risk is supported indirectly (competence, losing streaks), not measured.
- Heroes & Generals, often cited as a power-gap failure, officially closed for engine and financing reasons (Wikipedia).

## Proposed order of topics
1. **First week of a new player**: landing in a small group (section/guild), mentoring, avoiding early losing streaks against veterans, understandable and limited loss of new units.
2. **Special units and victory**: pacing of multi-day battles, stalemate breaking, access for late joiners.
3. Economy, HQ and guild powers.
4. Combat and AP details.

## Sources

Academic
- Ryan, R. M., Rigby, C. S., & Przybylski, A. (2006). The motivational pull of video games: A self-determination theory approach. *Motivation and Emotion*, 30, 347–363. https://doi.org/10.1007/s11031-006-9051-8 (PDF: https://www.rochester.edu/warner/lida/wp-content/uploads/2022/11/02bfe513dd59366750000000.pdf)
- Park, K., Cha, M., Kwak, H., & Chen, K.-T. (2017). Achievement and Friends: Key Factors of Player Retention Vary Across Player Levels in Online Multiplayer Games. WWW '17 Companion. https://arxiv.org/pdf/1702.08005
- Debeauvais, T., Nardi, B., Schiano, D. J., Ducheneaut, N., & Yee, N. If you build it they might stay: retention mechanisms in World of Warcraft. https://www.artifex.org/~bonnie/WoW_retention_04_24_11.pdf
- Huang, Y., Neidhardt, J., & Contractor, N. (2014). Why Players Leave: Exploring Major Factors of Quitting EverQuest II. Sunbelt XXXIV. https://www.ec.tuwien.ac.at/node/9346
- Ducheneaut, N., Yee, N., Nickell, E., & Moore, R. J. (2006). "Alone together?" Exploring the social dynamics of massively multiplayer online games. CHI '06. https://doi.org/10.1145/1124772.1124834
- Chen, Z., Xue, S., Kolen, J., Aghdaie, N., Zaman, K. A., Sun, Y., & Seif El-Nasr, M. (2017). EOMM: An Engagement Optimized Matchmaking Framework. WWW 2017. https://arxiv.org/pdf/1702.06820
- Tversky, A., & Kahneman, D. (1991). Loss Aversion in Riskless Choice: A Reference-Dependent Model. *Quarterly Journal of Economics*, 106(4), 1039–1061. https://ideas.repec.org/a/oup/qjecon/v106y1991i4p1039-1061..html
- Carter, M., & Allison, F. (2017). Fear, loss and meaningful play: Permadeath in DayZ. *Journal of Gaming & Virtual Worlds*, 9(2), 143–158. https://doi.org/10.1386/jgvw.9.2.143_1
- Cuerdo, M. A. M., Mahajan, A., & Melcer, E. F. (2021). Die-r Consequences: Player Experience and the Design of Failure through Respawning Mechanics. IEEE Conference on Games. https://ieee-cog.org/2021/assets/papers/paper_70.pdf

Industry
- Prima Games, "How EVE Online is solving its new player problem [CCP Interview]": https://primagames.com/featured/how-eve-online-is-solving-its-new-player-problem-ccp-interview
- Destructoid (May 2016): https://destructoid.com/?p=206617
- TechRaptor (Sept. 2019): https://techraptor.net/gaming/news/ccp-games-announce-eve-online-grief-counseling-for-new-players-losing-first-ships
- PlanetSide 2 dev letter (Aug. 2019): https://www.planetside2.com/news/dev-letter-new-player-experience-august-2019
- Albion Online zone guide: https://www.albionmarket.gg/guides/zones-and-flagging
- Foxhole, Wikipedia: https://en.wikipedia.org/wiki/Foxhole_(video_game)
- Indian Defence Review (June 2025): https://indiandefencereview.com/70-days-and-over-9-million-deaths-developers-had-to-step-in-to-end-an-unstoppable-war/
- Massively Overpowered, "Alas, poor Crowfall": https://massivelyop.com/?p=413756
- Heroes & Generals, Wikipedia: https://en.wikipedia.org/wiki/Heroes_%26_Generals
