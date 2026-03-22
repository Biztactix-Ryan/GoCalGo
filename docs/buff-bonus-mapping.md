# Buff & Bonus Data Structure Mapping

Maps all buff/bonus patterns from the ScrapedDuck API into a unified model for GoCalGo. This is the foundation for internal DTO design (US-GCG-20-4).

## Buff/Bonus Sources in ScrapedDuck

Buffs and bonuses appear in **three different shapes** across the API, plus one indirect source:

| Source | Location | Shape | Example |
|--------|----------|-------|---------|
| Community Day bonuses | `extraData.communityday.bonuses[]` | `{ text, image }` | "3x Catch Stardust" |
| Community Day disclaimers | `extraData.communityday.bonusDisclaimers[]` | `string` | "* Extended bonus window..." |
| Spotlight Hour bonus | `extraData.spotlighthour.bonus` | `{ text, image }` | "2x Transfer Candy" |
| Weather-boosted raids | `raids.json[].boostedWeather[]` | `{ name, image }` + CP range | "Cloudy" → +25% CP |

> **Wiki vs live data discrepancy:** The ScrapedDuck wiki documents the spotlight hour key as `spotlight` with `bonus` as a plain string. The existing API reference (based on historical observation) documents it as `spotlighthour` with `bonus` as `{ text, image }`. Since no spotlight hour events are currently live, the exact shape cannot be verified today. The DTO design should handle both forms defensively.

## Detailed Structures

### 1. Community Day Bonuses (array of bonuses)

The richest buff source. Each Community Day has multiple simultaneous bonuses.

```jsonc
{
  "communityday": {
    "bonuses": [
      { "text": "Increased Spawns", "image": "https://cdn.leekduck.com/.../wildgrass.png" },
      { "text": "3x Catch Stardust", "image": "https://cdn.leekduck.com/.../stardust3x.png" },
      { "text": "3-hour Incense", "image": "https://cdn.leekduck.com/.../incense.png" },
      { "text": "2x Catch Candy", "image": "https://cdn.leekduck.com/.../candy.png" },
      { "text": "2x Chance to receive Candy XL from catching Pokémon", "image": "https://cdn.leekduck.com/.../candyxl.png" },
      { "text": "One additional Special Trade can be made for a maximum of two for the day*", "image": "..." },
      { "text": "Trades made will require 50% less Stardust*", "image": "..." }
    ],
    "bonusDisclaimers": [
      "* While most bonuses are only active during the three hours of the event..."
    ]
  }
}
```

**Observed bonus categories from text parsing:**

| Category | Pattern | Examples |
|----------|---------|----------|
| Multiplier | `Nx <resource>` | "3x Catch Stardust", "2x Catch Candy" |
| Duration | `N-hour <item>` | "3-hour Incense", "3-hour Lures" |
| Spawn boost | literal | "Increased Spawns" |
| Probability | `Nx Chance...` | "2x Chance to receive Candy XL..." |
| Trade bonus | literal | "50% less Stardust", "One additional Special Trade..." |

**Key insight:** Bonus text is free-form, not a fixed enum. Multipliers and durations are embedded in the text string, not as structured fields. Parsing these into structured data will require text analysis or a lookup table.

### 2. Spotlight Hour Bonus (single bonus)

Each Spotlight Hour features exactly one Pokemon and one bonus.

```jsonc
// Per wiki documentation:
{
  "spotlight": {
    "name": "Psyduck",
    "canBeShiny": true,
    "image": "https://cdn.leekduck.com/...",
    "bonus": "2× Transfer Candy"       // string per wiki
  }
}

// Per historical API observation (may be outdated):
{
  "spotlighthour": {
    "pokemon": { "name": "Psyduck", "canBeShiny": true, "image": "..." },
    "bonus": { "text": "2× Transfer Candy", "image": "..." }  // object
  }
}
```

**Known Spotlight Hour bonus types** (fixed rotation):
- 2× Transfer Candy
- 2× Catch Candy
- 2× Catch Stardust
- 2× Catch XP
- 2× Evolution XP

### 3. Weather-Boosted Raids (implicit buff)

Not a traditional "bonus" but produces a buff effect: Pokemon caught during matching weather have higher CP.

```jsonc
{
  "boostedWeather": [
    { "name": "Rainy", "image": "https://cdn.leekduck.com/.../rainy.png" },
    { "name": "Cloudy", "image": "https://cdn.leekduck.com/.../cloudy.png" }
  ],
  "combatPower": {
    "normal": { "min": 1534, "max": 1606 },
    "boosted": { "min": 1917, "max": 2008 }   // ~25% higher
  }
}
```

### 4. Generic Flags (boolean buff indicators)

Every event includes flags that indicate whether spawn or research buffs are active, even if the specific buffs aren't detailed:

```json
{
  "generic": {
    "hasSpawns": true,
    "hasFieldResearchTasks": true
  }
}
```

## Event Types WITHOUT Structured Buff Data

These event types use only the `generic` block — any buffs they offer are described only in the event name/text or on the linked LeekDuck page, not in structured data:

- `event` (general events — often have buffs like "2x Hatch Stardust" but only in the LeekDuck page text)
- `raid-hour`, `raid-day`, `raid-weekend`
- `bonus-hour`
- `go-rocket-takeover`, `team-go-rocket`
- `pokemon-go-fest`, `safari-zone`, `go-pass`
- `season`
- `max-battles`, `max-mondays`
- All research types (except breakthrough)

**Implication for GoCalGo:** For these event types, we cannot extract specific buff details from the API alone. Options:
1. Display only the event name and image (sufficient for most users)
2. Scrape the linked LeekDuck page for buff details (fragile, not recommended)
3. Accept that detailed buffs are only available for Community Days and Spotlight Hours

## Proposed Internal Buff Model

> **Canonical definition:** The formal Buff DTO and full event data contract are defined in [event-dto-contract.md](event-dto-contract.md). The model below is the analysis that informed that contract.

Based on the above analysis, a unified buff representation for GoCalGo DTOs:

```
Buff {
    Text        string   // Display text: "3x Catch Stardust"
    IconUrl     string   // CDN URL for bonus icon (nullable)
    Category    enum     // multiplier | duration | spawn | probability | trade | other
    Multiplier  float?   // Parsed: 3.0 from "3x Catch Stardust" (nullable)
    Resource    string?  // Parsed: "Catch Stardust" (nullable)
    Disclaimer  string?  // Footnote/disclaimer text (nullable)
}
```

This model normalizes Community Day bonuses (array → multiple Buffs), Spotlight Hour bonuses (single → one Buff), and can represent weather boosts if needed.

## Edge Cases

1. **Bonus disclaimers with asterisks** — Community Day bonuses marked with `*` have extended or restricted windows documented in `bonusDisclaimers[]`. The disclaimer applies to all asterisked bonuses.
2. **Lure duration text** — "1-hour Lures*" with asterisk, meaning duration varies by event phase.
3. **Unicode multiplier symbols** — API uses both `2x` and `2×` inconsistently. Normalize on parse.
4. **Compound bonuses** — "2x Chance to receive Candy XL from catching Pokémon" is a probability modifier, not a simple multiplier.
5. **Missing icon URLs** — Some bonus entries may have empty or missing image fields.

---

*Last updated: 2026-03-20*
*Derived from: ScrapedDuck API live data + [wiki documentation](https://github.com/bigfoott/ScrapedDuck/wiki/Events)*
