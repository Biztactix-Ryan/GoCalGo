---
acceptance_criteria:
- Background job fetches from ScrapedDuck API on a configurable schedule
- Raw event data is parsed and normalised into a consistent schema
- Events are stored in PostgreSQL with proper fields (title name dates buffs type)
- Summarised event data is cached in Redis
- Job handles ScrapedDuck downtime gracefully by serving cached data
- Job logs success/failure for observability
created: '2026-03-20'
epic_id: EPIC-GCG-2
id: US-GCG-4
points: 8
priority: must
status: done
tags:
- backend
- mvp
- phase1
- layer-3-backend
title: Backend event ingestion from ScrapedDuck
updated: '2026-03-21'
---

**Requires:** US-GCG-18 (DB migrations — schema must exist), US-GCG-20 (data contract defined), US-GCG-21 (Redis cache service)\n\nCore ingestion pipeline. Must be done before REST API (US-GCG-5).