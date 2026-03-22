---
acceptance_criteria:
- docker compose up starts PostgreSQL Redis and .NET API
- PostgreSQL is accessible on a standard local port
- Redis is accessible on a standard local port
- .NET API connects to local PostgreSQL and Redis
- Environment variables are documented
created: '2026-03-20'
epic_id: EPIC-GCG-1
id: US-GCG-2
points: 3
priority: must
status: active
tags:
- infra
- mvp
- layer-2-infra
title: Local development environment with Docker Compose
updated: '2026-03-21'
---

**Requires:** US-GCG-1 (repo scaffolding — .NET project must exist for Dockerfile)\n\nDocker Compose for local dev with PostgreSQL, Redis, and .NET API.