# Internal Event Data Contract — Shared DTOs

Defines the canonical data contract for event data flowing between the .NET backend API and the Flutter app. Both sides must implement models matching these DTOs. The backend produces these shapes; the app consumes them.

**Source story:** US-GCG-20 — ScrapedDuck API exploration and data contract definition

---

## Design Principles

1. **Backend owns the transformation** — ScrapedDuck's polymorphic `extraData` is normalised into flat, typed DTOs by the backend. The app never sees raw ScrapedDuck shapes.
2. **Shared schema, separate implementations** — This document is the single source of truth. C# records and Dart classes are generated/written to match these definitions exactly.
3. **Nullable fields are explicit** — Fields marked `?` may be null. All other fields are always present.
4. **Enums are string-backed** — Serialised as lowercase kebab-case strings for readability and forward compatibility.

---

## 1. EventDto

The primary DTO returned by the backend API. Represents a single Pokemon GO event with all relevant data pre-shaped for display.

```
EventDto {
    Id              string          // Unique event ID (from ScrapedDuck eventID)
    Name            string          // Display name: "Tinkatink Community Day"
    EventType       EventTypeEnum   // Categorised event type (see enum below)
    Heading         string          // Display heading: "Community Day"
    ImageUrl        string          // CDN URL for event header image
    LinkUrl         string          // LeekDuck event page URL
    Start           datetime?       // Event start time (ISO 8601, no timezone — local time)
    End             datetime?       // Event end time (ISO 8601, no timezone — local time)
    IsUtcTime       bool            // True if timestamps are UTC (e.g. GBL events); false for local time
    HasSpawns       bool            // Whether the event has boosted wild spawns
    HasResearchTasks bool           // Whether the event has field research tasks
    Buffs           Buff[]          // Normalised buff/bonus list (may be empty)
    FeaturedPokemon Pokemon[]       // Featured/spawning Pokemon (may be empty)
    PromoCodes      string[]        // Promo codes if any (may be empty)
}
```

### Field Notes

- `Start` and `End` are **usually** local time — Pokemon GO events happen at the same local time worldwide. **Exception:** GO Battle League events use UTC timestamps (with `Z` suffix in ScrapedDuck). The backend must normalize these on ingest: detect the `Z` suffix, and either store a flag (`IsUtcTime`) or convert to a canonical form. The app uses device timezone for display; the backend uses user timezone (derived from FCM token registration) for notification scheduling.
- `Buffs` is a flattened list combining Community Day bonuses, Spotlight Hour bonuses, and any other structured buff data. Events without structured buff data have an empty array.
- `FeaturedPokemon` combines spawns, shinies, spotlight Pokemon, and raid bosses into a single list with role context.

---

## 2. Buff

Unified representation of a buff or bonus, normalised from the various ScrapedDuck shapes. See [buff-bonus-mapping.md](buff-bonus-mapping.md) for the source analysis.

```
Buff {
    Text            string          // Display text: "3x Catch Stardust"
    IconUrl         string?         // CDN URL for bonus icon (nullable)
    Category        BuffCategory    // Parsed category (see enum below)
    Multiplier      float?          // Parsed multiplier: 3.0 from "3x Catch Stardust" (nullable)
    Resource        string?         // Parsed resource: "Catch Stardust" (nullable)
    Disclaimer      string?         // Footnote/disclaimer text (nullable)
}
```

---

## 3. Pokemon

A featured Pokemon within an event context.

```
Pokemon {
    Name            string          // Pokemon name: "Tinkatink"
    ImageUrl        string          // CDN URL for Pokemon icon
    CanBeShiny      bool            // Whether the shiny variant is available
    Role            PokemonRole     // Context within the event (see enum below)
}
```

---

## 4. Enums

### EventTypeEnum

Normalised event categories. Maps ScrapedDuck's 32 event types into logical groups for filtering and display.

```
EventTypeEnum {
    community-day
    spotlight-hour
    raid-hour
    raid-day
    event                   // General events, seasonal events, live events
    go-battle-league
    go-rocket
    research
    pokemon-go-fest
    safari-zone
    season
    other                   // Catch-all for unmapped types
}
```

**Mapping from ScrapedDuck eventType:**

| Internal Type | ScrapedDuck Types |
|---------------|-------------------|
| `community-day` | `community-day` |
| `spotlight-hour` | `pokemon-spotlight-hour` |
| `raid-hour` | `raid-hour`, `bonus-hour` |
| `raid-day` | `raid-day`, `raid-weekend`, `raid-battles`, `elite-raids` |
| `event` | `event`, `live-event`, `update`, `ticketed`, `ticketed-event`, `go-pass`, `pokestop-showcase`, `wild-area`, `city-safari`, `location-specific`, `global-challenge`, `potential-ultra-unlock`, `pokemon-go-tour`, `max-battles`, `max-mondays` |
| `go-battle-league` | `go-battle-league` |
| `go-rocket` | `go-rocket-takeover`, `team-go-rocket`, `giovanni-special-research` |
| `research` | `research`, `timed-research`, `limited-research`, `research-breakthrough`, `special-research`, `research-day` |
| `pokemon-go-fest` | `pokemon-go-fest` |
| `safari-zone` | `safari-zone` |
| `season` | `season` |
| `other` | Any unrecognised type |

### BuffCategory

```
BuffCategory {
    multiplier          // "3x Catch Stardust" — numeric multiplier on a resource
    duration            // "3-hour Incense" — extended item duration
    spawn               // "Increased Spawns" — boosted wild spawns
    probability         // "2x Chance to receive Candy XL" — probability modifier
    trade               // "50% less Stardust for trades" — trade cost reduction
    weather             // Weather-boosted raid catch CP bonus
    other               // Anything that doesn't fit the above categories
}
```

### PokemonRole

```
PokemonRole {
    spawn               // Wild spawn during the event
    shiny               // Shiny-eligible variant
    spotlight           // Spotlight Hour featured Pokemon
    raid-boss           // Raid boss during the event
    research-reward     // Research task reward encounter
    research-breakthrough // Research breakthrough encounter
}
```

---

## 5. API Response Envelope

The backend API wraps event data in a standard response envelope.

```
EventsResponse {
    Events          EventDto[]      // List of events
    LastUpdated     datetime        // When the backend last fetched from ScrapedDuck (UTC)
    CacheHit        bool            // Whether this response was served from Redis cache
}
```

---

## 6. Implementation Checklist

### .NET Backend (C#) — `src/backend/GoCalGo.Contracts/Events/`
- [x] `EventDto` record in shared/contracts namespace
- [x] `Buff` record
- [x] `Pokemon` record
- [x] `EventTypeEnum`, `BuffCategory`, `PokemonRole` enums
- [x] `EventsResponse` wrapper
- [x] ScrapedDuck-to-DTO event type mapping (`ScrapedDuckEventTypeMap`)

### Flutter App (Dart) — `src/app/lib/models/`
- [x] `EventDto` model class with `fromJson` factory
- [x] `Buff` model class with `fromJson` factory
- [x] `Pokemon` model class with `fromJson` factory
- [x] `EventType`, `BuffCategory`, `PokemonRole` enums
- [x] `EventsResponse` model with `fromJson` factory
- [x] Barrel export (`models.dart`)

---

## 7. Serialisation Contract

- All DTOs are serialised as JSON over HTTP
- Field names use **camelCase** in JSON (matching Dart conventions; C# maps via `JsonPropertyName` or naming policy)
- Enums serialise as **lowercase kebab-case strings**
- Dates serialise as **ISO 8601 strings without timezone** (e.g. `"2026-04-11T14:00:00"`)
- Null fields are **omitted** from JSON (not sent as `null`)
- Arrays are **never null** — empty arrays are sent as `[]`

---

*Last updated: 2026-03-20*
*Derived from: ScrapedDuck API analysis (docs/scrapedduck-api.md) and buff mapping (docs/buff-bonus-mapping.md)*
