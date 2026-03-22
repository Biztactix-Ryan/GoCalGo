---
acceptance_criteria:
- Dockerfile builds the .NET API successfully
- Coolify webhook triggers on push to main
- Container deploys and runs on Coolify infrastructure
- Environment variables configured in Coolify for DB and Redis connections
created: '2026-03-20'
epic_id: EPIC-GCG-1
id: US-GCG-3
points: 3
priority: must
status: done
tags:
- infra
- layer-4-deploy
title: Coolify deployment pipeline
updated: '2026-03-21'
---

**Requires:** US-GCG-2 (Docker Compose — production Dockerfile based on dev), US-GCG-19 (env config — Coolify needs env vars defined)\n\nDeploy backend to Coolify. Can be done once backend is functional.