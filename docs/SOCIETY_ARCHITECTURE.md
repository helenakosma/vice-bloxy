# Society Architecture

The technical design for Vice Bloxy's society systems: the services, data, interfaces and rules that let employment, money, housing, education and the phone work together. [SOCIETY_DESIGN.md](SOCIETY_DESIGN.md) covers the gameplay vision.

Each section marks what **exists** (code in the repository, audited 2026-11-24) and what is **proposed** (not built; for review). No balance values are decided here. `src/shared/Economy.lua` holds temporary test values.

## 1. Runtime layout (exists)

Rojo maps `src/server` → ServerScriptService, `src/client` → StarterPlayerScripts and `src/shared` → ReplicatedStorage.Shared.

`Main.server.lua` starts the society services before the world build, so early joiners load straight away:

```
PlayerData.start → Economy.start → Phone.start → Employment.start → Router.start
World.build(...)  (districts, highways, transit, Eaton Centre)
Work.start        (binds prompts to workplaces the world just built)
```

| Service (`src/server/Services`) | Responsibility | Interface |
| --- | --- | --- |
| `PlayerData` | Loads and saves one profile per player in DataStore `Profiles_v1`, with a session lock (`UpdateAsync`, takeover after `SessionLockSeconds`, Studio-lock takeover), autosave, save on leave and on `BindToClose`, retries. It reconciles missing fields from a versioned template, and guest mode applies when DataStores are unavailable. | `get`, `waitFor`, `onLoaded`, `onLeaving`, `isGuest` |
| `Economy` | **The only code that changes money.** Each change is a transaction `{id, t, a, k, m, b}`. A transaction id applies once (the last `RememberTransactions` ids are kept), and balances never go negative. It keeps a ledger of `LedgerSize` entries, mirrors the balance to `leaderstats.Cash` for display and pushes `bank` events to the client. | `balance`, `canAfford`, `pay(player, amount, kind, memo, txId?)`, `charge(...)` |
| `Router` | A single RemoteFunction `Remotes.Request(action, args)`. It rejects unknown actions, rate-limits each player (`RequestBurst` per `RequestWindowSeconds`), refuses requests until the profile is loaded, requires args to be a table, and catches handler errors. Handlers validate their own arguments. | `Router.on(action, fn)` |
| `Phone` | Home summary, bank history, the public profile (bio filtered through TextService, privacy flags), settings and the notification inbox. | `home.*`, `bank.get`, `profile.*`, `settings.set`, `notify.*` |
| `Notify` | Inbox entries and pushes to the client. | `Notify.send(...)` |
| `Employment` | The job market, saved jobs, applications (limit on open applications, re-apply cooldown), offers with expiry, contracts, promotions, history and the work calendar. | `jobs.*`, `calendar.get`; `Employment.onJobChanged` |
| `Hiring` | Deterministic NPC hiring managers. Scores a profile against a listing using the employer's weights (education, experience, skills, previous employment, suitability), requests an interview near the threshold, and returns the reasons and tips. | `Hiring.evaluate(data, listing, interviewScore?)` |
| `Work` | Shifts: clock in and out at a workplace, the café loop (order → stations → hand-over → tips), the retail loop (till, restock from the stockroom, fold displays) and courier deliveries (pick-up → drop-off, paid by distance). Pay = wage × hours × (floor + rest × performance), paid through `Economy` with the shift's id. A shift ends after `AwaySeconds` away, and a shift in progress is paid out when the player leaves. | `work.startDelivery`, `work.end`, `work.state` |
| `Fares` (`src/server`) | Transit card, fare gates and bus fares. | RemoteEvents `FareGate`, `BoardVehicle` |

Catalogs and configuration (`src/shared`):
- `Economy.lua` holds every balance number. Its values are temporary.
- `Catalog/Jobs.lua` holds tracks, employers, listings and interview questions.
- `Catalog/EatonTenants.lua` holds the mall's tenants with fictional names.

Client (`src/client/Phone`):
- `Phone.client.lua` is the frame, home screen and app switcher.
- `PhoneUI.lua` holds the shared widgets.
- `Apps/` holds `Bank`, `Calendar`, `Jobs`, `Notifications`, `Profile` and `Settings`.
- `Work.client.lua` handles shift UI, and `Hud.client.lua` shows the balance.

### Profile schema v1 (exists)

```
version, _name, __lock
identity   { joined, bio, privacy{profile, job, home, education} }
money      { balance, ledger[], seen[] }
transit    { card, balance }
phone      { wallpaper, theme, notify{bank, jobs, system} }
inbox      []
employment { current?, history[], applications{}, saved{}, experience{industry=n}, skills{industry=n}, totalShifts, shiftLog }
education  { applications{}, enrolment?, degrees[] }          -- scaffold, no service yet
housing    { lease?, owned{}, layouts{} }                     -- scaffold, no service yet
inventory  { furniture{}, items{} }                           -- scaffold, no service yet
social     { connections{}, requestsIn{}, requestsOut{}, referrals{given, received} }  -- scaffold
achievements, stats{ playSeconds }
```

## 2. Audit: what to reuse and what is missing

**Reuse as-is:**
- `PlayerData` (session locking and versioning are sound).
- `Economy`'s transaction model.
- `Router` and its rate limit.
- The `Hiring` explain-your-decision model.
- `Work`'s server-side task validation and pay by shift id.
- The phone framework and the Jobs and Bank apps.

**Weaknesses and missing foundations:**

1. **Gameplay places are tied to map geometry.**
   - The two workplaces are created inside the Eaton Centre builder (`EatonCentre/init.lua` calls `Workplaces.cafe` and `Workplaces.clothing`, choosing units by a size heuristic).
   - That file is the map team's. When the mall's levels moved, both workplaces moved to Level 1 with it.
   - Employers name a workplace id, but nothing gives a stable "where is this" for the Jobs app, navigation or future housing.
   - Delivery destinations are picked from built geometry.
2. **No shared (cross-server) state.**
   - Everything persists per player. Business ownership, property availability, limited job openings and market prices need a global store with concurrency control. None exists.
3. **No two-party money movement.**
   - `Economy` changes one profile. Paying another player, payroll or rent to a player landlord need a transfer that can't duplicate or lose money across two profiles, possibly on two servers.
4. **No game-time service.**
   - Opening hours read `Lighting.ClockTime` directly. Schedules, rent periods and courses need one clock with a stated time scale.
5. **The skills model is thin.**
   - Skills are a number per industry, raised by shifts. There's no named skill set and no stated effects.
6. **Some profile sections are scaffolds only.**
   - Education, housing, inventory and social have fields but no service, so the phone can't show them yet.
7. **Profile growth.**
   - The ledger (100), inbox (40), application records and shift logs are capped individually. Their total size isn't checked against the DataStore limit, and nothing archives old records.
8. **No automated tests or exploit checks.**
   - Duplicate pay, remote flooding and session-lock behaviour have only been reasoned about, not exercised in multi-client tests.
9. **Arrival.**
   - Players spawn in the legacy Downtown district: the first district to offer a spawn wins.

## 3. Proposed architecture

### 3.1 Layers

```
Catalogs (shared, data only)    Locations, Jobs, Properties*, Programs*, Items*     (* later phases)
Domain services (server)        Employment, Hiring, Work, Housing*, Education*, Business*
Core services (server)          PlayerData, Economy, Ledger/Transfers*, Locations, Clock, SharedState*, Notify
Interface                       Router (requests), Push (events), world prompts
Clients                         Phone + apps, HUD, Waypoint/Maps*, Work UI
World (map team)                builds geometry; tags anchors with a LocationId
```

**Rules:**
- Domain services call core services and never write another domain's profile section.
- Money moves only through `Economy`, or `Transfers` for two-party movement.
- Places are referenced only by location id.

### 3.2 Location and business registry (proposed, Phase 1)

- **`src/shared/Catalog/Locations.lua`** is data only. Each entry is `id → { name, kind, area, address, station? }`.
  - Example ids: `eaton.grind`, `eaton.threads`, `station.dundas`, `uoft.campus`.
  - `kind` is one of workplace, shop, campus, home, station or venue.
- **The world marks anchors.** A builder tags a part with the `Location` tag and a `LocationId` attribute. The map team owns where it goes. One line in a builder, or an anchor placed after building, is the whole interface.
- **`src/server/Services/Locations.lua`** resolves an id to `{ position, cframe, radius, entrance? }` from tagged anchors. It also answers nearest-station queries and publishes positions for client navigation.
- **Workplaces migration.**
  - `Jobs.EMPLOYERS[*].workplace` becomes a location id.
  - `Work` asks `Locations` for the site, and the station set-up is unchanged.
  - The existing `Workplaces.registry` keeps working during the move.
  - Long term, the café and store fit-outs should be built by a gameplay-owned "fit-out" step that runs after the world, at an anchor. The mall builder would then only provide the unit and its tag.

### 3.3 Clock (proposed, Phase 1)

`Clock.now()` returns in-game minutes since an epoch, with `Clock.hour()` and `Clock.day()`. It has one configured time scale (currently 1 game hour = 1 real minute) and is synced to the `Atmosphere` cycle. Employers' hours, shift calendars and later rent and course schedules use it instead of reading `Lighting`.

### 3.4 Shared state (proposed, Phase 3–5; not in the first slice)

Things that are limited across all servers (property units, business ownership, unique job openings) need one source of truth:

- **Ownership records:** DataStore keys like `Property/<id>` and `Business/<id>`, written with `UpdateAsync` and checked against a version number. These are the authority.
- **Short-lived claims:** MemoryStore (`SortedMap` with a TTL), for example "this unit is being viewed or applied for".
- **Two-party money:** a `Transfers` service.
  - It debits the payer through `Economy` with transaction id `T`, records a pending credit `T` in the payee's mailbox key (DataStore), and the payee's server applies it with the same id.
  - Ids make every step idempotent, so a crash between steps can't duplicate or lose money.
  - Business revenue and payroll use this path.
- **NPC economy:** abstract and periodic, not simulated per NPC. Each business has a demand model evaluated on a timer (customers per hour by location, price and quality). Physical NPCs appear only where a player is present to serve them, as the café queue already does.

### 3.5 Skills (proposed, Phase 4)

- **Catalog:** `src/shared/Catalog/Skills.lua` lists the named skills, each with the activities that raise it and its stated effects.
- **Profile:** `skills{name = xp}` replaces `employment.skills`, migrated from the per-industry values with a schema v2 migration in `PlayerData.migrate`.
- **Service:** `Skills.award(player, skill, amount, source)` is server-only and capped per source per period, to stop farming.

### 3.6 Phone apps

Every app is backed by Router actions. Existing: Bank, Jobs, Calendar, Notifications, Profile, Settings.

Proposed, in order:
1. **Today:** optional first objectives and what to do next.
2. **Maps:** the location registry and waypoints.
3. **TTC:** arrivals from the transit timetable and service alerts.
4. **Housing.**
5. **Messages:** TextChatService and TextService filtered, contacts only.
6. **Network.**
7. **Business.**

## 4. First vertical slice (proposed, Phase 2)

Most of this loop exists (Milestone 2). The slice is about making it complete, reliable and pleasant for one career, not adding more careers. The recommended career is the café (Grind Coffee). It's an open question in the design doc.

| Step | Today | Work in the slice |
| --- | --- | --- |
| 1. Join | Profile loads (or guest). Spawn is in legacy Downtown. | Arrival in Toronto (decision needed). A welcome notification. |
| 2. Profile | v1 schema, session lock | Profile-size check; migration test from v1 saves |
| 3. Phone | Opens; Home, Bank and Jobs work | **Today** app: 3 optional first objectives (no forced tutorial) |
| 4. Browse jobs | Listings with requirements and pay | Listing shows the location by id, with distance and nearest station |
| 5. Apply | Limits and cooldown | Unchanged |
| 6. NPC decision | Deterministic score, interview, offer, reasons | Unchanged; wording pass |
| 7. Travel | The player has to know where the mall is | **Navigate** button: waypoint to the location's anchor, minimap marker, "take Line 1 to Dundas" hint |
| 8. Work | Café loop, retail loop, deliveries | Café polish: clearer station feedback, an end-of-shift summary card |
| 9. Validated pay | Server-computed, paid once by shift id | A duplicate-pay test; payslip lines in the ledger memo |
| 10. Finances | Bank app and HUD | Payslip view |
| 11. Rejoin | Saves on leave, on shutdown and periodically | A Studio test: quit mid-shift, rejoin, check the payout and history |

**Verification for the slice:**
- Two-client Studio test.
- Forced session-lock contention (two servers).
- Spamming remotes past the rate limit.
- Attempting double pay (quitting during payout).
- Walking from the arrival point to the workplace by phone directions alone.

## 5. Files

**Changed in Phase 0 (done):**
- `src/server/World/Layout.lua`: `VICE_BEACH_ACTIVE` switch; Vice Beach gantry signs dropped.
- `src/server/World/init.lua`: Vice Beach left out of the district list.
- `src/server/World/Highways.lua`: no bridge; closed ends on the Expressway and Harbor Freeway.
- `src/server/World/Districts/Downtown.lua`: river railing closed where the causeway was.
- `src/client/Minimap.client.lua` and `src/server/Services/Phone.lua`: "Vice Beach" area name removed.
- `ViceBeach.lua` and `ViceStyles.lua` are kept, inactive.

**Proposed for Phase 1–2:**
- New:
  - `src/shared/Catalog/Locations.lua`
  - `src/server/Services/Locations.lua`
  - `src/server/Services/Clock.lua`
  - `src/client/Phone/Apps/Today.lua`
  - `src/client/Phone/Apps/Maps.lua` (or a Navigate action inside Jobs)
  - `src/client/Waypoint.client.lua`
- Changed:
  - `src/shared/Catalog/Jobs.lua`: employers reference location ids.
  - `src/server/Services/Employment.lua`: listings carry location data.
  - `src/server/Services/Work.lua`: sites resolved through `Locations`, plus the shift summary.
  - `src/server/Services/PlayerData.lua`: v2 migration hook and size check.
  - `src/client/Phone/Phone.client.lua`: app list.
  - `src/client/Phone/Apps/Jobs.lua`: Navigate.
  - `src/server/Main.server.lua`: start `Locations` and `Clock`.

## 6. Coordination with the map team (Codex)

- **Codex's files are off limits to gameplay.**
  - Codex owns Toronto geometry, the Eaton Centre (`EatonCentre/*`), stations (`Transit.lua`, `TMUStation.lua`, `Transit.client.lua`) and street layout.
  - Gameplay doesn't edit them.
- **The only interface needed is anchors.** Proposed contract: a builder tags one part per gameplay place with the `Location` tag and a `LocationId` attribute.
- **Known conflict: the workplaces.**
  - The café and store are built from inside `EatonCentre/init.lua` (the `Workplaces.cafe` and `Workplaces.clothing` calls and their unit-picking heuristics).
  - Until the anchor contract is agreed, gameplay will not touch those calls.
  - Proposal: the mall builder tags the two chosen units (`eaton.grind`, `eaton.threads`), and the fit-out moves to the gameplay side later.
- **Transit integration** (arrival times, alerts) reads the timetable that `Transit.lua` already publishes. It won't modify it.
- **Vice Beach's beach bus** (`BusBeach` in `Transit.lua`) switches itself off because no boulevard road exists. `Transit.lua` was not edited.

## 7. Security rules (apply to every service)

- **Never trust client data.**
  - Clients send intents only, through Router actions or prompts.
  - The server decides amounts, prices, eligibility, outcomes and ownership.
  - Every handler checks types, ranges, ownership and proximity where it applies.
- **Money and ledger.**
  - Money changes only through `Economy` (or `Transfers`), each with a transaction id derived from the game event (a shift id, an order id, a rent period id). That makes retries idempotent.
  - Records are kept for exploit investigation, in the ledger and later a server-side audit log.
- **Anti-farming.**
  - Rewards are computed from server-observed work, not from client-reported completion.
  - Rewards are capped by game time: the expected tasks per hour, `AwaySeconds`.
- **Rate limits.**
  - The Router limit applies per player.
  - Expensive actions get their own cooldowns, as applications already do.
- **Text** uses Roblox text filtering, and profiles stay fictional.

## 8. Performance

- **No per-frame server loops for society systems.** Use timers (seconds) and events.
- **The NPC economy is abstract and periodic.** Physical NPCs only near players.
- **DataStore budget.**
  - Autosave is spread across `SaveEverySeconds`.
  - Shared-state writes batch through `UpdateAsync` and are never written on a timer per entity.
- **Phone.** Requests carry only the data the open app needs. Pushes are small deltas, as `bank` pushes already are.

## 9. Proposed implementation sequence (after review)

1. **Decisions:** arrival point, polished career, time scale, cash vs bank-only, which state is global.
2. **Location registry and anchor contract:** agreed with Codex. Tag the two Eaton workplaces and Dundas station first.
3. **Clock service:** move employer hours to it.
4. **Navigate and Today:** Jobs shows the location; waypoint and minimap marker; first objectives.
5. **Café polish and payslips:** shift summary, ledger memo lines.
6. **Hardening:** v2 migration hook, profile size check, multi-client and duplicate-pay tests.
7. **Then Phase 3** (housing, rent, shopping) on the same foundations.
