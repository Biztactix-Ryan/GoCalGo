# ScrapedDuck API Reference

ScrapedDuck scrapes [LeekDuck.com](https://leekduck.com) (with permission) and publishes structured JSON data on a GitHub `data` branch. Data is updated every ~12 hours.

**Repository:** [github.com/bigfoott/ScrapedDuck](https://github.com/bigfoott/ScrapedDuck)

## Base URL

```
https://raw.githubusercontent.com/bigfoott/ScrapedDuck/data
```

## Rate Limits

- **Hard limit:** 5,000 requests/hour (GitHub raw content limit)
- **Cache TTL:** 5 minutes (GitHub caches raw files; polling faster is wasteful)
- **Recommendation:** Cache aggressively on our side. A 15-minute poll interval is more than sufficient given the 12-hour data refresh cycle.

## Usage Terms

- Application must not be behind a paywall
- Application must not include advertisements
- Must credit both ScrapedDuck and LeekDuck.com

---

## Endpoints

Each endpoint has a formatted and minified variant:

| Endpoint | Formatted | Minified |
|----------|-----------|----------|
| Events | `/data/events.json` | `/data/events.min.json` |
| Raids | `/data/raids.json` | `/data/raids.min.json` |
| Eggs | `/data/eggs.json` | `/data/eggs.min.json` |
| Research | `/data/research.json` | `/data/research.min.json` |

Full URL example:
```
https://raw.githubusercontent.com/bigfoott/ScrapedDuck/data/events.json
```

---

## 1. Events (`/data/events.json`)

The primary endpoint for GoCalGo. Returns an array of all current and upcoming Pokemon GO events.

### Schema

```jsonc
[
  {
    "eventID": "string",       // Unique ID, matches LeekDuck URL slug
    "name": "string",          // Display name
    "eventType": "string",     // Category (see Event Types below)
    "heading": "string",       // Display heading based on eventType
    "link": "string",          // Full URL to LeekDuck event page
    "image": "string",         // CDN URL for event header image
    "start": "string|null",    // ISO 8601 datetime (no timezone — local time)
    "end": "string|null",      // ISO 8601 datetime (no timezone — local time)
    "extraData": {}            // Type-specific payload (see below)
  }
]
```

### Event Types (32 documented)

**Events/General:**
`community-day`, `event`, `live-event`, `pokemon-go-fest`, `global-challenge`, `safari-zone`, `location-specific`, `bonus-hour`, `pokemon-spotlight-hour`, `potential-ultra-unlock`, `update`, `season`, `pokemon-go-tour`, `go-pass`, `ticketed`, `pokestop-showcase`, `wild-area`, `city-safari`

**Research:**
`research`, `timed-research`, `limited-research`, `research-breakthrough`, `special-research`, `research-day`

**Raids/Battle:**
`raid-day`, `raid-battles`, `raid-hour`, `raid-weekend`, `elite-raids`, `max-battles`, `max-mondays`

**GO Rocket:**
`go-rocket-takeover`, `team-go-rocket`, `giovanni-special-research`, `go-battle-league`

**Ticketed:**
`ticketed-event`

### extraData Structures

> For a consolidated mapping of all buff/bonus patterns and a proposed internal model, see [buff-bonus-mapping.md](buff-bonus-mapping.md).

Every event includes a `generic` block:

```json
{
  "generic": {
    "hasSpawns": false,
    "hasFieldResearchTasks": false
  }
}
```

#### Community Day extraData

```jsonc
{
  "communityday": {
    "spawns": [
      { "name": "Tinkatink", "image": "https://cdn.leekduck.com/..." }
    ],
    "bonuses": [
      { "text": "3x Catch Stardust", "image": "https://cdn.leekduck.com/..." }
    ],
    "bonusDisclaimers": ["* Extended bonus window text..."],
    "shinies": [
      { "name": "Tinkatink", "image": "https://cdn.leekduck.com/..." }
    ],
    "specialresearch": [
      {
        "name": "Tinkatink Community Day (1/3)",
        "step": 1,
        "tasks": [
          {
            "text": "Catch 3 Pokemon",
            "reward": { "text": "Tinkatink", "image": "..." }
          }
        ],
        "rewards": [
          { "text": "Tinkatink", "image": "..." },
          { "text": "x50", "image": ".../candy/regular/957.png" }
        ]
      }
    ]
  },
  "generic": { "hasSpawns": true, "hasFieldResearchTasks": true }
}
```

#### Spotlight Hour extraData

> **Note:** The wiki documents this key as `spotlight` with `bonus` as a plain string. Historical observations show `spotlighthour` with `bonus` as `{ text, image }`. Verify when spotlight hour events are next available. See `docs/buff-bonus-mapping.md` for details.

```jsonc
// Per wiki:
{
  "spotlight": {
    "name": "string",
    "canBeShiny": true,
    "image": "...",
    "bonus": "2× Transfer Candy"
  },
  "generic": { "hasSpawns": false, "hasFieldResearchTasks": false }
}

// Per historical observation (may be outdated):
{
  "spotlighthour": {
    "pokemon": { "name": "string", "canBeShiny": true, "image": "..." },
    "bonus": { "text": "2x Transfer Candy", "image": "..." }
  },
  "generic": { "hasSpawns": false, "hasFieldResearchTasks": false }
}
```

#### Raid Battles extraData

```jsonc
{
  "raidbattles": {
    "bosses": [
      { "name": "Tapu Koko", "image": "...", "canBeShiny": true }
    ],
    "shinies": [
      { "name": "Tapu Koko", "image": "..." }
    ]
  },
  "generic": { "hasSpawns": false, "hasFieldResearchTasks": false }
}
```

#### Research Breakthrough extraData

> **Note:** The wiki documents this key as `breakthrough`. Historical observations show `researchbreakthrough`. Verify when a research breakthrough event is next available.

```jsonc
// Per wiki:
{
  "breakthrough": {
    "name": "string",
    "canBeShiny": true,
    "image": "..."
  },
  "generic": { "hasSpawns": false, "hasFieldResearchTasks": false }
}

// Per historical observation (may be outdated):
{
  "researchbreakthrough": {
    "pokemon": { "name": "string", "canBeShiny": true, "image": "..." }
  },
  "generic": { "hasSpawns": false, "hasFieldResearchTasks": false }
}
```

#### Promo Code extraData

```jsonc
{
  "promocodes": ["TH4NKY0UF41RYMUCH"],
  "generic": { "hasSpawns": false, "hasFieldResearchTasks": false }
}
```

### Example: Full Community Day Event

```json
{
  "eventID": "april-communityday2026",
  "name": "Tinkatink Community Day",
  "eventType": "community-day",
  "heading": "Community Day",
  "link": "https://leekduck.com/events/april-communityday2026/",
  "image": "https://cdn.leekduck.com/assets/img/events/article-images/2026/2026-04-11-april-communityday2026/tinkatink-cd-april-2026-key.jpg",
  "start": "2026-04-11T14:00:00.000",
  "end": "2026-04-11T17:00:00.000",
  "extraData": {
    "communityday": {
      "spawns": [
        { "name": "Tinkatink", "image": "https://cdn.leekduck.com/assets/img/pokemon_icons/pm957.icon.png" }
      ],
      "bonuses": [
        { "text": "Increased Spawns", "image": "https://cdn.leekduck.com/assets/img/events/bonuses/wildgrass.png" },
        { "text": "3x Catch Stardust", "image": "https://cdn.leekduck.com/assets/img/events/bonuses/stardust3x.png" },
        { "text": "3-hour Incense", "image": "https://cdn.leekduck.com/assets/img/events/bonuses/incense.png" },
        { "text": "2x Catch Candy", "image": "https://cdn.leekduck.com/assets/img/events/bonuses/candy.png" },
        { "text": "2x Chance to receive Candy XL from catching Pokemon", "image": "https://cdn.leekduck.com/assets/img/events/bonuses/candyxl.png" }
      ],
      "bonusDisclaimers": [
        "* While most bonuses are only active during the three hours of the event..."
      ],
      "shinies": [
        { "name": "Tinkatink", "image": "https://cdn.leekduck.com/assets/img/pokemon_icons/pm957.s.icon.png" }
      ],
      "specialresearch": [ "..." ]
    },
    "generic": { "hasSpawns": true, "hasFieldResearchTasks": true }
  }
}
```

### Example: Research Event with Promo Code

```json
{
  "eventID": "go-tour-fairy-type-timed-research",
  "name": "[Promo Code] GO Tour Fairy Type Timed Research",
  "eventType": "research",
  "heading": "Research",
  "link": "https://leekduck.com/events/go-tour-fairy-type-timed-research/",
  "image": "https://cdn.leekduck.com/assets/img/events/article-images/2026/2026-02-20-go-tour-fairy-type-timed-research/sylveon.jpg",
  "start": "2026-02-19T19:00:00.000",
  "end": "2026-03-02T00:00:00.000",
  "extraData": {
    "promocodes": ["TH4NKY0UF41RYMUCH"],
    "generic": { "hasSpawns": false, "hasFieldResearchTasks": false }
  }
}
```

---

## 2. Raids (`/data/raids.json`)

Returns an array of current raid bosses.

### Schema

```jsonc
[
  {
    "name": "string",          // Pokemon name (e.g. "Shadow Latias")
    "tier": "string",          // "1-Star Raids", "3-Star Raids", "5-Star Raids", "Mega Raids"
    "canBeShiny": true,
    "types": [
      { "name": "Fairy", "image": "..." }
    ],
    "combatPower": {
      "normal": { "min": 1204, "max": 1271 },
      "boosted": { "min": 1505, "max": 1589 }
    },
    "boostedWeather": [
      { "name": "Cloudy", "image": "..." }
    ],
    "image": "string"          // Pokemon icon URL
  }
]
```

### Example

```json
{
  "name": "Tapu Koko",
  "tier": "5-Star Raids",
  "canBeShiny": true,
  "types": [
    { "name": "Electric", "image": "https://cdn.leekduck.com/assets/img/pokemon_types/electric.png" },
    { "name": "Fairy", "image": "https://cdn.leekduck.com/assets/img/pokemon_types/fairy.png" }
  ],
  "combatPower": {
    "normal": { "min": 1534, "max": 1606 },
    "boosted": { "min": 1917, "max": 2008 }
  },
  "boostedWeather": [
    { "name": "Rainy", "image": "https://cdn.leekduck.com/assets/img/weather/rainy.png" },
    { "name": "Cloudy", "image": "https://cdn.leekduck.com/assets/img/weather/cloudy.png" }
  ],
  "image": "https://cdn.leekduck.com/assets/img/pokemon_icons/pm785.icon.png"
}
```

---

## 3. Eggs (`/data/eggs.json`)

Returns an array of Pokemon available from egg hatches.

### Schema

```jsonc
[
  {
    "name": "string",             // Pokemon name
    "eggType": "string",          // Distance with unit: "1 km", "2 km", "5 km", "7 km", "10 km", "12 km"
    "isAdventureSync": false,     // Adventure Sync reward egg
    "image": "string",            // Pokemon icon URL
    "canBeShiny": true,
    "combatPower": {
      "min": 294,
      "max": 331
    },
    "isRegional": false,          // Region-exclusive
    "isGiftExchange": false,      // From gift eggs
    "rarity": 1                   // 1-4 scale (1 = common, 4 = rare)
  }
]
```

### Example

```json
{
  "name": "Togepi",
  "eggType": "2 km",
  "isAdventureSync": false,
  "image": "https://cdn.leekduck.com/assets/img/pokemon_icons/pm175.icon.png",
  "canBeShiny": true,
  "combatPower": { "min": 294, "max": 331 },
  "isRegional": false,
  "isGiftExchange": false,
  "rarity": 2
}
```

---

## 4. Research (`/data/research.json`)

Returns an array of current field research tasks and their Pokemon rewards.

### Schema

```jsonc
[
  {
    "text": "string",             // Task description
    "type": "string|undefined",   // Category: catch, throw, battle, explore, training, buddy, rocket
    "rewards": [
      {
        "name": "string",         // Pokemon name (may include form: "Alolan Exeggutor")
        "image": "string",        // Pokemon icon URL
        "canBeShiny": true,
        "combatPower": {
          "min": 579,
          "max": 629
        }
      }
    ]
  }
]
```

### Example

```json
{
  "text": "Make 3 Excellent Throws",
  "type": "throw",
  "rewards": [
    {
      "name": "Beldum",
      "image": "https://cdn.leekduck.com/assets/img/pokemon_icons_crop/pm374.icon.png",
      "canBeShiny": true,
      "combatPower": { "min": 579, "max": 629 }
    }
  ]
}
```

---

## Live API Exploration (2026-03-20)

All four endpoints were called and full response payloads captured. Summary of live data:

| Endpoint | Entries | Event Types Observed | Notable |
|----------|---------|---------------------|---------|
| `/data/events.json` | 57 events | `research`, `research-day`, `event`, `max-mondays`, `go-battle-league`, `raid-battles`, `raid-hour`, `max-battles`, `go-pass`, `community-day`, `raid-day`, `pokemon-go-fest`, `season` | GBL events use UTC (`Z` suffix); no spotlight hours currently live |
| `/data/raids.json` | 14 raids | Tiers: 1-Star, 3-Star, 5-Star, Mega | Shadow Pokemon prefixed in name (e.g. "Shadow Latias") |
| `/data/eggs.json` | 73 entries | Egg types: 1 km, 2 km, 5 km, 7 km, 10 km, 12 km | `eggType` uses "N km" format, not bare numbers; 1 km tier exists |
| `/data/research.json` | 43 tasks | Types: catch, throw, battle, explore, training, buddy, rocket | Some tasks omit `type` field entirely |

### Discrepancies Found vs Documentation

1. **`eggType` format change** — Wiki and previous docs show `"2"`, `"5"`, etc. Live API returns `"1 km"`, `"2 km"`, `"5 km"`, `"7 km"`, `"10 km"`, `"12 km"`. Backend must parse the `"N km"` format.
2. **New `1 km` egg tier** — Contains starter Pokemon from all generations. Not documented in the ScrapedDuck wiki.
3. **GBL UTC timestamps** — GO Battle League events use `Z`-suffixed UTC timestamps (e.g. `"2026-03-17T20:00:00.000Z"`), unlike all other events which use local time without timezone. Backend must detect and handle both formats.
4. **GO Fest UTC timestamps** — GO Fest city events also use `Z`-suffixed UTC timestamps.
5. **No spotlight hours live** — Cannot verify the `spotlight` vs `spotlighthour` key discrepancy.

---

## Reliability & Rate Limit Assessment

For the full reliability assessment, rate limit analysis, and recommended mitigations, see [api-reliability-assessment.md](api-reliability-assessment.md).

## Internal Data Contract

For the normalised DTO definitions that the .NET backend produces and the Flutter app consumes (derived from this API), see [event-dto-contract.md](event-dto-contract.md).

## Key Observations for GoCalGo

1. **Timestamps have no timezone — except GBL events** — `start`/`end` generally use ISO 8601 format without timezone offset, representing local time. However, **GO Battle League events include a `Z` (UTC) suffix** (e.g. `"2026-03-17T20:00:00.000Z"`), making them UTC timestamps. Our backend must detect and handle both formats: local time for most events, UTC for GBL. This is logical since GBL seasons start/end simultaneously worldwide.

2. **Events endpoint is our primary data source** — eggs, raids, and research are supplementary. The events endpoint covers all event types including raid hours, spotlight hours, community days, and seasonal events.

3. **extraData is polymorphic** — the structure varies by `eventType`. Our DTOs need to handle this gracefully (discriminated union or type-specific deserialization).

4. **start/end can be null** — some events (like ongoing seasons) may have null timestamps.

5. **Data refresh is ~12 hours** — combined with GitHub's 5-minute cache, we should poll no more than every 15 minutes and cache aggressively in Redis.

6. **No authentication required** — public GitHub raw content, subject only to IP-based rate limits.

7. **Some events use UTC timestamps** — GO Battle League and GO Fest city events include a `Z` suffix on their timestamps, indicating UTC. The backend must detect `Z` suffix and handle these as UTC (simultaneous worldwide start) vs local time (same wall-clock time per timezone).

---

*Last updated: 2026-03-20*
*Source: [ScrapedDuck Wiki](https://github.com/bigfoott/ScrapedDuck/wiki)*
