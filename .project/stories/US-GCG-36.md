---
acceptance_criteria:
- 'ScrapedDuck outage: backend serves cached data from PostgreSQL with degraded status'
- 'Redis outage: API falls back to PostgreSQL queries with no user-visible error'
- HTTP client uses retry with exponential backoff for ScrapedDuck calls
- Circuit breaker pattern prevents cascading failures on sustained outages
- Health endpoint reports degraded status when dependencies are down
- Ingestion job alerts on repeated failures (logged at Warning/Error level)
created: '2026-03-20'
epic_id: EPIC-GCG-2
id: US-GCG-36
points: 5
priority: must
status: done
tags:
- backend
- mvp
- phase1
- layer-3-backend
title: Backend graceful degradation and resilience
updated: '2026-03-21'
---

**Requires:** US-GCG-4 (ScrapedDuck client — need existing HTTP client to add Polly), US-GCG-21 (Redis cache — need cache service to add fallback logic)\n\nResilience patterns (retry, circuit breaker, graceful degradation).