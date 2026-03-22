# ScrapedDuck API Reliability & Rate Limit Assessment

Assessment date: 2026-03-20

## Live Endpoint Test Results

All four endpoints tested successfully on 2026-03-20:

| Endpoint | Status | Entries | Approx Size |
|----------|--------|---------|-------------|
| `/data/events.json` | 200 OK | 71 events | ~150-180 KB |
| `/data/raids.json` | 200 OK | 14 raids | ~5 KB |
| `/data/eggs.json` | 200 OK | 103 eggs | ~20 KB |
| `/data/research.json` | 200 OK | 62 tasks | ~15 KB |

All responses returned valid JSON arrays with the documented schema structure.

## Rate Limits

- **Hard limit:** 5,000 requests/hour per IP (GitHub raw content infrastructure)
- **GitHub cache TTL:** 5 minutes (responses are cached; polling faster returns stale data)
- **Data refresh cycle:** ~12 hours (ScrapedDuck scrapes LeekDuck on this cadence)
- **No authentication required** — public GitHub raw content, IP-based rate limiting only

### GoCalGo Impact

At a **15-minute poll interval** (our planned cadence), the backend makes:
- 4 requests/hour x 4 endpoints = **16 requests/hour** (0.3% of the 5,000 limit)
- Even at 5-minute intervals: 48 requests/hour (< 1% of limit)

Rate limits are a non-issue for our use case. The constraint is the 5-minute GitHub cache and 12-hour data refresh, not the request quota.

## Reliability Characteristics

### Strengths
1. **Static file hosting** — Data is served as static JSON from GitHub's raw content CDN, which has high availability (backed by GitHub/Microsoft infrastructure)
2. **No server-side processing** — No API logic to fail; it's just file serving
3. **Predictable data shape** — Schema is stable; changes only when ScrapedDuck updates its scraper
4. **No auth dependency** — No tokens to expire or rotate

### Risks
1. **No SLA** — Community-maintained project with no uptime guarantees
2. **Single maintainer** — The `bigfoott` GitHub account is the sole maintainer; bus factor of 1
3. **Scraping dependency** — Data accuracy depends on LeekDuck.com not changing its HTML structure
4. **GitHub outages** — Raw content CDN shares GitHub's availability (~99.9% historical)
5. **Stale data** — If the scraper breaks silently, we'd serve outdated events with no signal
6. **11 open issues** — Some may indicate data quality problems
7. **Wiki last edited Dec 2022** — Documentation may lag behind actual API behavior (confirmed: spotlight hour key name discrepancy)

### Data Quality Quirks (confirmed from sibling task research + live API exploration)
- Spotlight hour `extraData` key may be `spotlight` or `spotlighthour` (wiki vs observation)
- Research breakthrough key may be `breakthrough` or `researchbreakthrough`
- Unicode inconsistency: both `2x` and `2×` appear in bonus text
- Timestamps are local time with no timezone offset — **except GO Battle League events**, which use UTC with `Z` suffix (e.g. `"2026-03-17T20:00:00.000Z"`)
- Egg `eggType` field uses `"N km"` format (e.g. `"2 km"`, `"10 km"`), not bare numbers
- Egg `eggType` includes `"1 km"` tier (starter Pokemon eggs) not mentioned in wiki
- Some research tasks omit the `type` field entirely (confirmed undefined, not just undocumented)

## Recommended Mitigations for GoCalGo

| Risk | Mitigation | Priority |
|------|-----------|----------|
| API down | Cache last-known-good data in PostgreSQL; serve stale if fetch fails | Must |
| Stale data (scraper broken) | Track `Last-Modified` / response hash; alert if unchanged for >24 hours | Should |
| Schema change | Defensive deserialization with fallback defaults; log unknown fields | Must |
| GitHub rate limit | 15-min poll interval (uses < 1% of quota) | Done (by design) |
| Data format quirks | Normalize on ingest: handle both key variants, normalize unicode multipliers | Must |
| Single point of failure | Consider periodic LeekDuck.com scrape as fallback (future, low priority) | Could |

## Conclusion

The ScrapedDuck API is **suitable for GoCalGo's needs** with appropriate caching and resilience:

- **Rate limits** are generous and will never be a constraint at our polling frequency
- **Reliability** is good enough for a non-critical consumer app, given that we cache aggressively and serve stale data during outages
- **The main risk** is silent data staleness (scraper breaks, no error signal) — mitigate with change-detection monitoring
- **Data quality** requires defensive parsing to handle known inconsistencies

The .NET backend's role as a caching/normalization layer (ADR-002) is well-justified by these findings — it insulates the Flutter app from all of these API quirks and failure modes.

---

*Source: Live API testing + [ScrapedDuck Wiki](https://github.com/bigfoott/ScrapedDuck/wiki) + sibling task research (US-GCG-20-1 through US-GCG-20-5)*
