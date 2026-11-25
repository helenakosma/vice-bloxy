# Vice Bloxy Game Vision

## Player experience

Vice Bloxy is an open-world Roblox city and life simulator set in Toronto. Open-world exploration and driving are part of the experience alongside persistent multiplayer social and economic progression. Players choose how to spend their time. A player could take the subway to a shift, meet friends at a café, apply for school, save for a better apartment, or explore downtown without following a prescribed storyline. Toronto is the sole map direction. The older New York and Miami design influences have been superseded.

## Toronto and the built environment

Build a dense, recognizable, walkable Toronto using believable street widths, intersections, block sizes, building heights, storefronts, and pedestrian routes. Downtown should connect Yonge, Dundas, Queen, the Eaton Centre, the university district, the financial district, and the waterfront. Use distinct Toronto neighbourhoods for variation in architecture, density, and atmosphere. Expand in a way that makes commuting, shopping, and recreation feel geographically connected.

Give prominent destinations walk-in interiors and put detail where players spend time. Use modular shells and selective fit-outs elsewhere. Architecture and lighting should feel grounded, with convincing proportions, varied façades and active street frontage. Maintain a playable part count and streaming footprint as density rises.

### Eaton Centre and Yonge–Dundas

The mall should read as the Eaton Centre through its long shopping galleria, vaulted glass roof, atriums, balconies, escalators, lifts, anchor footprints, Urban Eatery, and Flight Stop geese. Use traced retail layouts as a basis and keep the displayed tenant names fictional. Connect retail floors to actual pedestrian routes from the streets and subway. Keep street entries, shopping levels, Urban Eatery, station passages, fare halls, platforms, any underpasses, and any parking levels distinct in the design. Verify each element before assigning its real elevation or connection. Street grade may differ between the north and south ends.

Use Cadillac Fairview leasing plans and mall directories alongside TTC station information and reliable street or architectural references. Build a cross-section from the evidence before moving any floor or entry. Treat older screenshots, code comments and assumed counts of underground levels as leads to check.

- [Cadillac Fairview leasing plan](https://assets.cadillacfairview.com/m/43273f2554bf438e/original/TECON20_LEASINGPLAN.pdf)
- [Interactive Eaton Centre directory](https://www.mappedin.com/map-gallery/cf-toronto-eaton-centre/)
- [TTC TMU Station](https://www.ttc.ca/subway-stations/TMU-station)
- [TTC Queen Station](https://www.ttc.ca/en/subway-stations/queen-station)

## Transportation

Make public transit a practical way to get around. A player should be able to walk from a sidewalk or connected building to a station, pass through a fare gate, board a train, and exit into another neighbourhood. Use recognizable Toronto routes, station access, signage, directional maps, platforms, arrival displays, car displays, doors, and announcements. Trains run independently of passengers. Keep headways configurable, with roughly one-minute service as the design target and randomized delays or disruptions communicated through stations and eventually the phone. Buses, streetcars, and driving should complement the subway. In-world advertising can later tie into business gameplay.

## Work, education, and housing

- **Employment.** Support job applications, interviews, qualifications, schedules, wages, performance, and promotions. Work should feel different across cafés, retail, delivery, transit, corporate roles, entertainment, and other illustrative tracks such as healthcare or public services. Use NPC staff and automated hiring where useful so essential services can operate with few players online.
- **Education.** Let players pursue optional courses, practical assessments, certifications, internships, and degrees through universities, colleges, or training programs. Education opens selected paths while skilled work and entrepreneurship remain viable alternatives. Campus life and dorms can connect education to the housing and social systems.
- **Housing.** Offer rentals and purchases across apartments, condos, houses, penthouses, and commercial properties. Price, location, and transit access should create meaningful choices. Rent, furnishing and customization come before more advanced utility or investment mechanics. Keep recurring obligations manageable.
- **Economy.** Connect earnings and spending across work, shopping, travel, housing, education, leisure, business ownership, and property. Make progression meaningful over time without excessive grinding. Balance income and spending against inflation. Validate all balances, rewards, prices, and ownership changes on the server.

## Phone, social life, and recreation

The smartphone is the main interface for city services. Expand it over time with contacts, direct and group messaging, maps and navigation, banking, applications, property listings, service alerts, scheduling, notifications, and business tools. Integrate each app with an actual player activity or system. Support organic friendships and professional networking through shared places, referrals, partnerships, events, and multiplayer activities. Provide reasons to visit the city outside of progression, including shops, cafés, restaurants, cinemas, arcades, gyms, sports, parks, waterfront spaces, and nightlife.

Monetization follows **pay to enhance, play to succeed**. Robux can add cosmetics, customization, convenience, or optional experiences. Players who spend nothing should be able to use essential transport, pursue consequential careers, and build meaningful wealth and progress.

## Development sequence

1. Refine the Toronto city foundation, starting with downtown geography, the Eaton Centre, surrounding street grades and entries, and pedestrian circulation.
2. Verify station connections and dependable subway boarding, schedules, signage and delay handling. Extend surface transit and road systems as the map supports them.
3. Harden existing profiles, currency, employment, and phone features before expanding persistent progression and additional player systems.
4. Add education, housing, wider career paths, and NPC participation. Expand into businesses, property ownership, commercial activity, social systems, and recreation as supporting systems mature.

This is a roadmap. The [implementation snapshot](CURRENT_STATE.md) records which pieces already have code and which remain pending.
