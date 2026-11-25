# Vice Bloxy

An open-world Roblox life simulator set in Toronto: explore the city, ride the TTC, work, study, find a home and build a life alongside other players. Original name and assets only.

See [docs/GAME_VISION.md](docs/GAME_VISION.md) for the vision, [docs/CURRENT_STATE.md](docs/CURRENT_STATE.md) for what is built, and [docs/SOCIETY_DESIGN.md](docs/SOCIETY_DESIGN.md) and [docs/SOCIETY_ARCHITECTURE.md](docs/SOCIETY_ARCHITECTURE.md) for the gameplay systems. Contributors and agents should start with [AGENTS.md](AGENTS.md).

## Setup
1. `rojo serve` in this folder.
2. In Roblox Studio, install the Rojo plugin and click Connect.
3. Press Play.

## Layout
- `src/server`: world generation (`World/`), society services (`Services/`: profiles, money, jobs, work, phone), transit fares, cars
- `src/client`: phone and its apps, HUD, minimap, transit, driving, work UI
- `src/shared`: shared configuration (`Economy.lua` holds every balance value), catalogs (`Catalog/`), assets
- `tools/eaton`: offline Eaton Centre plan extraction
