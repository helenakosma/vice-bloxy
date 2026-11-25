# Society Design

The long-term gameplay vision for Vice Bloxy's society: what players do in Toronto and why they come back. [SOCIETY_ARCHITECTURE.md](SOCIETY_ARCHITECTURE.md) covers how it is built, and [CURRENT_STATE.md](CURRENT_STATE.md) covers what exists today.

**Status legend:** _Exists_ means playable code is in the repository now. _Planned_ means a design intent that has not been built. Balance numbers (starting money, wages, rent, tuition, durations) are deliberately left open. The values in `src/shared/Economy.lua` are temporary test values, not decisions.

## The idea

The player is building a life in Toronto, not running a minigame. The city is the foundation, and the society gives it a purpose. A session can be a shift at work, a subway ride to class, an evening at a café with friends, or a drive with no goal at all. Success has no single definition. The software engineer in a downtown condo, the restaurant owner, the landlord and the retail worker who loves their apartment and their friends are all successful.

The core loop:

> Explore the city → discover opportunities → develop skills and relationships → earn income → improve lifestyle → unlock new opportunities.

It is a loop, not a storyline. Players can change direction at any point, for example by quitting a job, going back to school or starting a business.

## Principles

1. **Systems feed each other.** Employment drives income. Education opens jobs. Income buys housing. Housing location shapes the commute. Relationships open opportunities, businesses create jobs, and spending keeps businesses running. One currency and one profile connect them all.
2. **Work is gameplay.** Every career has its own activity suited to the role. No standing on buttons, no progress bars standing in for work, no mandatory hour-long shifts.
3. **Progress comes from accomplishment.** Promotions, hiring and qualifications respond to what a player did and learned, not to how long they waited.
4. **Realism creates decisions, not chores.** Rent, commuting and bills should make choices interesting. They should never make the game tedious or punish players for being offline.
5. **It works with few players.** NPC employers, customers and services keep the city functional on a near-empty server. Real players add competition, cooperation and creativity on top.
6. **Pay to enhance, play to succeed.** Robux can buy cosmetics, decoration and convenience. It can't buy careers, wealth, essential transport or necessities. No monetization is built during the foundation phases.
7. **Explain decisions.** When a system says no (a hiring decision, a rental application), it says why and what would change the answer. The hiring manager already does this.

## Pillars

### Arrival (new players)

_Partly exists._ A new player gets a profile, a starting balance and a phone. They are free to explore immediately: no permanent career choice and no long tutorial.

_Planned:_
- A light set of optional first objectives: find a place to stay, apply for a first job, ride the subway, visit the Eaton Centre.
- Surfaced through the phone, never blocking play.
- Arrival in Toronto, not the legacy Downtown district (see open questions).

### Employment and careers

_Exists:_
- Three tracks: café (Grind Coffee), retail (Metro Threads) and courier (Quickdrop).
- Phone job listings with requirements and pay.
- Applications and deterministic NPC hiring that explains its score.
- Interviews when an applicant is close to the bar, offers and contracts.
- Shift gameplay: taking and making orders, ringing up, restocking, folding, delivery routes.
- Performance-based pay, promotions by shifts and performance, and employment history.

_Planned:_
- More employers per track, and the same track at different locations.
- Career fairs and referrals.
- Management roles that do management: scheduling, hiring, budgets.
- Skilled trades.
- Technology roles built around logic and debugging puzzles.
- Transit operations.
- Careers that span employers.

Illustrative ladders: retail runs from Sales Associate to Store Manager (in the game now). A software ladder (Intern to Engineering Manager) and a trades ladder are planned.

### Education

_Planned:_
- Optional courses, certifications and degrees at Toronto institutions (U of T, TMU and colleges), using real campus locations as gameplay venues.
- Learning-inspired activities: assessments that test something, not a purchase.
- Programmes unlock specific doors, such as internships, licensed roles and senior hiring weight.
- Durations are tuned to Roblox play sessions.
- Skilled trades and entrepreneurship stay viable without degrees.
- The hiring model already weights education. No current entry-level job requires a degree.

### Skills

_Partly exists:_ per-industry experience (shifts worked) and a skill value feed the hiring score.

_Planned:_
- A small, readable skill set: communication, customer service, technical problem-solving, management, financial literacy, culinary, driving, leadership, organisation.
- Skills grow from the matching activity (work, study, assessments), not from any action at all.
- Each skill's effect is stated where it applies, for example "Customer service raises tips" or "Driving unlocks courier level 2".

### Money

_Exists:_ one currency with a server-side ledger. Every payment and charge is a transaction with an id, a kind and a memo, and the Bank app shows them.

_Planned:_
- Recurring obligations (rent, tuition) and savings.
- Later, investments and business accounts.
- Money sinks that players want (lifestyle, housing, vehicles, recreation) balanced against income so wealth stays meaningful.

### Housing

_Planned:_
- Shared rooms and budget studios up to downtown condos, houses and penthouses.
- Renting first, then buying.
- Location matters: a condo near a subway station costs more and saves time.
- Furniture and interior customisation are the aspirational layer.
- Missed rent has grace periods and safeguards, never sudden loss of major investments.
- Properties are defined by stable ids mapped onto real buildings, without changing building geometry.

### Businesses

_Planned:_
- Player-owned cafés, restaurants, shops, tech firms and service businesses.
- Real operating decisions: prices, inventory, staff, marketing, quality, expansion.
- Operating costs as well as revenue.
- NPC staff and customers keep a business open while its owner is offline.
- Player owners hire other players, so the economy becomes player-driven.

### Phone

_Exists:_ the phone framework, with the Home, Bank, Jobs, Calendar, Notifications, Profile and Settings apps.

_Planned:_
- Maps and navigation.
- TTC arrivals and alerts.
- Housing listings.
- Messages through Roblox-compliant filtered channels.
- Professional networking.
- Business management.

Every app must be backed by a real service; no decorative apps.

### Social and professional networking

_Partly exists:_ profile fields for connections, requests and referrals; a privacy-controlled public profile with a filtered bio.

_Planned:_
- Contacts and coworker connections.
- Referrals that count in hiring.
- Partnerships and shared activities.
- All of it uses fictional in-game identities and Roblox text filtering, and collects no personal information.

### Transportation

_Exists, built separately:_ the Line 1 subway with fares and delays, buses, and drivable cars.

_Planned:_
- Gameplay hooks: trip planning in a Maps app, arrival times and service alerts on the phone, commute-aware housing value, and transit jobs.
- The physical system is owned by the map team; society code integrates through interfaces.

### Lifestyle and recreation

_Planned:_
- Reasons to spend and to stay: shopping at the Eaton Centre, cafés and restaurants, gyms and sports, parks, concerts, cinemas, nightlife, driving and decorating.
- Recreation can feed skills and relationships, but it is valuable on its own.

## Development phases

The phases are provisional and will be refined after review.

| Phase | Scope | State |
| --- | --- | --- |
| 0 | Toronto-only cleanup: Vice Beach (Miami) disabled, docs updated | Done in source; the Studio run is pending |
| 1 | Society foundation: harden profiles and the ledger, add a location and business registry, shared-state service, service interfaces, phone framework | Mostly exists; the registry and shared state are missing |
| 2 | First complete loop: join → profile → phone → entry-level job → apply → NPC decision → travel → work → validated pay → finances → rejoin | Exists in rough form (Milestone 2); needs hardening and one polished career |
| 3 | Lifestyle: housing and rent, shopping, inventory, more jobs, transit hooks | Planned |
| 4 | Education, skills, internships, advanced careers, networking | Planned |
| 5 | Player businesses, player hiring, property investment | Planned |
| 6 | Entertainment, events, more careers | Planned |

## Open design questions (for review)

1. **Spawn and arrival.** Players currently spawn in the legacy Manhattan-style Downtown district. Should arrival move to Toronto (for example Union Station or Yonge & Dundas)? And should Downtown, Industrial and Suburbs also be retired from the playable world?
2. **The polished first career.** Café (Grind Coffee) or retail (Metro Threads)? Both exist. The proposal recommends the café: its loop (order → make → serve → tip) is the most legible.
3. **The time scale.** One in-game hour equals one real minute now, so a full shift is 8 minutes. Is that the target?
4. **Offline obligations.** Should rent accrue only for time played (the current design note) or on real calendar time?
5. **Cash.** Bank balance only, or a separate cash balance as well? A cash balance would matter for theft or crime systems, which aren't planned.
6. **Global state.** Which things are limited across all servers (property units, business slots, job openings) and which are per-server? This decides the shared-state design.
7. **All balance numbers** are left open: starting balance, wages, rent, tuition and progression rates.
