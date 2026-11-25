# Vice Bloxy Current State

This snapshot covers the local working tree, including Eaton Centre and transit edits already in progress. Status is based on source and configuration inspection. Roblox Studio play, multiplayer behavior, asset permissions, map accuracy, and production persistence have not been verified in this audit.

## Runtime and source layout

| Source | Responsibility |
| --- | --- |
| [default.project.json](../default.project.json) | Rojo maps `src/server` to ServerScriptService, `src/client` to StarterPlayerScripts, and `src/shared` to ReplicatedStorage. Enables Workspace streaming and sets Future lighting. |
| [Main.server.lua](../src/server/Main.server.lua) | Starts player data, economy, phone, employment, and routing before generating the world. Binds work prompts after generation, starts the day/night cycle, spawns cars, and checks underground safe zones for the fall/respawn logic. |
| [World/init.lua](../src/server/World/init.lua) | Seeds and orchestrates generation under `Workspace.City`. Lays out all districts, highways, and transit before building ground around underground voids. Builds district geometry, highways and transit, publishes minimap data, and logs part budgets. A district build failure can be logged while the rest of the world continues. |
| [World/Util.lua](../src/server/World/Util.lua), [TorontoLayout.lua](../src/server/World/TorontoLayout.lua) | Occupancy grid, part factories, ground construction, coordinate conventions, Toronto streets and stations, and landmark reservations. X increases east and north is negative Z. |
| [Buildings.lua](../src/server/World/Buildings.lua), [TorontoStyles.lua](../src/server/World/TorontoStyles.lua), [Districts/Toronto.lua](../src/server/World/Districts/Toronto.lua) | Procedural lot and building geometry, district-specific styles, targeted landmarks, detailed station areas and simpler massing elsewhere. |
| [Services](../src/server/Services), [Remotes.lua](../src/server/Remotes.lua) | Persistence, economy, employment, work, notifications and phone endpoints. The phone router checks the request envelope, rate limits by player and delegates action-specific validation to handlers. |
| [src/client](../src/client), [src/shared](../src/shared) | Client UI, transit motion, driving and visual effects. Shared modules hold gameplay settings, balance values, catalogs, physics, and asset IDs. |
| [assets/textures](../assets/textures), [tools/eaton](../tools/eaton) | Texture PNG sources and offline mall plan extraction, Lua generation and tenant tooling. Runtime texture IDs live in `Assets.lua`. `AssetCheck.client.lua` reports load failures. |

The active build list contains Downtown (Manhattan-style), Toronto, Industrial, and Suburbs. Industrial and Suburbs largely supply roads. The first district offering a player spawn wins, so list order matters. Players still spawn in the legacy Downtown district.

**Vice Beach (Miami-inspired) is disabled.** The game is Toronto-only. `Layout.VICE_BEACH_ACTIVE = false` leaves it out:
- The district is not in the build list.
- The suspension bridge isn't built, and the Expressway and Harbor Freeway end at "ROAD CLOSED" barriers.
- Downtown's river railing is closed where the causeway crossed.
- The Vice Beach gantry signs and the "Vice Beach" area name on the minimap and phone are gone.
- The beach shuttle bus doesn't start, because there's no boulevard road for it.

`Districts/ViceBeach.lua` and `ViceStyles.lua` are kept, inactive. Setting the switch to true restores the island, causeway, bridge and signs. The approved Toronto-only direction is in [Game Vision](GAME_VISION.md), and the society plans are in [Society Design](SOCIETY_DESIGN.md) and [Society Architecture](SOCIETY_ARCHITECTURE.md).

## Eaton Centre and station interface

The mall is generated at runtime from plan-derived Lua data in [EatonCentre/Data](../src/server/World/EatonCentre/Data). [The builder](../src/server/World/EatonCentre/init.lua) turns floor plates, voids, partitions and unit data into geometry. [Exterior.lua](../src/server/World/EatonCentre/Exterior.lua) handles the Dundas corner and station entry details, and [Interiors.lua](../src/server/World/EatonCentre/Interiors.lua) fits open shops by category and populates food-court seating. The builder also contains storefront, roof and circulation logic. The catalog keys tenants by floor and unit and uses fictional public names. The working tree includes L4 data and tenant registry overlays. [The existing visual audit](eaton-centre-audit.html) records earlier geometry and should be checked against current source before reuse.

Plan coordinates use feet north from Queen and west from Yonge. The active `EATON_SCALE` is **1 stud per plan foot** horizontally. Older module comments still mention 0.5. TorontoLayout also stretches the Queen–Dundas block to accommodate the mall.

| Component | Current model Y in studs | Source evidence |
| --- | ---: | --- |
| Flat sidewalk and mall Level 3 | +0.75 | `Util.WALK_TOP` and `LEVEL_Y[3]`. The current builder describes Level 3 as the Dundas street level. |
| Mall Level 4 | +20.75 | Registered in `LEVEL_DATA`. A Level 5 height constant also exists outside that registered floor list. |
| Mall Level 2 and station passage/fare hall | -17 | Mall `LEVEL_Y[2]` and transit `CONCOURSE` align. Transit routes the TMU connection from `TorontoLayout.EATON_LINK` and feeds the resulting X position back into the mall build. |
| Mall Level 1 | -37 | Mall floor constant. |
| Urban Eatery mall concourse | -54.75 | Mall floor index 0. |
| Underground transit platform and track bed | -31 / -36 | Platform is `RAIL + FLOOR_UP`. These elevations belong to the station, independently of mall floor labels. |

Several transit and exterior comments and path labels describe older mall entry or concourse arrangements. In particular, the transit code calls its link an Eaton Centre concourse passage while its floor is aligned with L2. The current lift helper still labels stops using indices 0 and 1. These are reasons to test actual door thresholds, well and lift stops, stairs, escalators and ground cutouts. Source establishes the modeled heights, but continuous walks from the Dundas sidewalk through the mall to the TMU platform and from the Queen end to its street and station connections still need verification. The snapshot establishes no real-world count of underground floors, parking decks, or TTC underpasses.

## Transit

[Transit.lua](../src/server/World/Transit.lua) builds stations, tunnels, tracks, fare areas, entrances, signage and vehicle models. It takes the 17 Finch–Union stations from TorontoLayout and adds Harbour, Central and Portlands. It publishes routes, stop timings, and a Line 1 delay clock. [Transit.client.lua](../src/client/Transit.client.lua) uses the shared server clock to animate trains and surface vehicles, handle boarding motion and doors, and update signs and announcements. [Fares.lua](../src/server/Fares.lua) implements fare-card and gate interactions, with client gate animation. The configured subway headway target is **90 seconds**, and fleet sizing determines the actual timetable spacing. Random delays are already modeled. The roughly one-minute design target, broader disruption types, and phone-based arrivals and service alerts are future work.

## Feature inventory

| Area | Status in source |
| --- | --- |
| World navigation | Generated roads, landmarks, walk-in storefronts, minimap and expanded map, subway guidance, drivable cars, lighting and rotating ads have runtime code. Many Toronto blocks remain placeholders. |
| Player profiles and economy | DataStore profile loading and saving with `UpdateAsync` and session locks, cash and transaction tracking, transit card, HUD and bank history. A broader player-driven economy and ownership systems are planned. |
| Employment | Café, retail, and courier tracks have listings, applications, offers, interviews where applicable, progression, and shift or delivery gameplay. Other industry labels do not establish playable careers. |
| In-game phone | Home screen, Bank, Jobs, Calendar, Notifications, Profile and Settings have code. Property listings, transit arrivals, direct and group messaging, and integrated navigation remain planned. |
| Education and housing | Profile fields and eligibility or balance scaffolding exist. Schools, instruction, degrees, rentals, property purchase and furnishing remain planned as playable systems. |
| Society and recreation | Shops, cafés, other venues and travel exist as world features. Broader NPC staffing, player businesses, social networking, and generalized recreation progression remain planned. |

## Priorities and verification gaps

1. Walk each mall connection in Studio and record the street, mall floor, passage, fare hall and platform elevations independently. Verify Dundas entries, the TMU well and lift, Queen-side access, collision, and walkable continuity against current plans and TTC references before proposing geometry changes.
2. Check that newly carved underground spaces also have matching safe zones. Review generation output for district failures, part budget overruns, inaccessible entrances and failed pathfinding. Walk the routes manually alongside automated path checks.
3. Test transit with multiple clients and streaming enabled. Check boarding, riding, fare validation, and vehicle/board synchronization through a delay and a terminal reversal.
4. Review the legacy districts, spawn order, and southern transit extension before proposing Toronto-only migration. Preserve coordinate and route dependencies until a migration is approved.
5. Validate profile loading and concurrent-session handling, job rewards, and remote handler validation before expanding society gameplay. Capture startup time, part counts and client performance before increasing interior density.

No checked-in Studio place, automated test suite, or pinned toolchain manifest was identified during this audit. Use the README's Rojo/Studio setup to exercise the generated place. External architectural references were recorded for future verification and were not independently checked here.
