---
acceptance_criteria:
- Redis client configured and registered in DI
- Cache service implements get/set/invalidate with configurable TTL
- 'Cache-aside pattern: check Redis then fall back to PostgreSQL'
- Cache is refreshed by the ingestion job on each successful fetch
- Cache handles Redis downtime gracefully (falls back to DB without errors)
- Cache keys are namespaced and documented
created: '2026-03-20'
epic_id: EPIC-GCG-2
id: US-GCG-21
points: 3
priority: must
status: done
tags:
- backend
- mvp
- phase1
- layer-3-backend
title: Redis cache service implementation
updated: '2026-03-21'
---

**Requires:** US-GCG-1 (.NET project), US-GCG-2 (Docker Compose — Redis must be running)\n\nRedis cache service. Must be done before ingestion (US-GCG-4) and API endpoints (US-GCG-5).