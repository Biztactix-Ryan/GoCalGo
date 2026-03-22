---
acceptance_criteria:
- Serilog configured with structured JSON output
- Log levels used consistently (Information for business events and Warning for degraded
  states and Error for failures)
- ScrapedDuck ingestion job logs fetch results with event counts and timing
- API request logging with correlation IDs
- Health check endpoint reports subsystem status (DB and Redis and ScrapedDuck last
  fetch)
- Logs are viewable in Coolify dashboard
created: '2026-03-20'
epic_id: EPIC-GCG-5
id: US-GCG-29
points: 3
priority: must
status: done
tags:
- backend
- dx
- mvp
- layer-3-backend
title: Backend structured logging and error tracking
updated: '2026-03-21'
---

**Requires:** US-GCG-1 (.NET project)\n\nSet up Serilog early so all subsequent backend work has proper logging from the start.