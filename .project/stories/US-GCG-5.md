---
acceptance_criteria:
- GET endpoint returns today's active events with buffs and bonuses
- GET endpoint returns upcoming events within a configurable window
- Responses are served from Redis cache with PostgreSQL fallback
- API returns properly shaped JSON matching the app's data model
- API enforces rate limiting to prevent abuse
- Health check endpoint exists for monitoring
created: '2026-03-20'
epic_id: EPIC-GCG-2
id: US-GCG-5
points: 5
priority: must
status: done
tags:
- backend
- mvp
- phase1
- layer-3-backend
title: REST API for serving event data
updated: '2026-03-22'
---

**Requires:** US-GCG-4 (ingestion — events must exist in DB), US-GCG-21 (Redis cache), US-GCG-22 (timezone handling), US-GCG-29 (logging)\n\nREST API endpoints. Must be done before Flutter app can display real data (US-GCG-7).