---
acceptance_criteria:
- EF Core migrations project is set up and configured
- Initial migration creates the base schema
- Migrations run automatically on app startup in development
- Migration CLI commands documented (add/apply/rollback)
- Seed data script exists for local development
- Production migration strategy documented (manual apply vs auto-migrate)
created: '2026-03-20'
epic_id: EPIC-GCG-1
id: US-GCG-18
points: 3
priority: must
status: done
tags:
- infra
- backend
- mvp
- layer-2-infra
title: Database migrations strategy and tooling
updated: '2026-03-22'
---

**Requires:** US-GCG-1 (.NET project), US-GCG-2 (Docker Compose — needs PostgreSQL running locally)\n\nEF Core migrations and initial schema. Must be done before ScrapedDuck ingestion (US-GCG-4).