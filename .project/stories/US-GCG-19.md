---
acceptance_criteria:
- appsettings.json and appsettings.Development.json configured with sensible defaults
- .env.example documents all required environment variables
- Docker Compose passes environment variables to services
- Configuration is strongly typed using IOptions pattern in .NET
- Sensitive values (DB password and Firebase credentials and API keys) are loaded
  from environment only
- Flutter app reads API base URL from build-time environment config
created: '2026-03-20'
epic_id: EPIC-GCG-1
id: US-GCG-19
points: 3
priority: must
status: done
tags:
- infra
- mvp
- layer-2-infra
title: Environment configuration and secrets management
updated: '2026-03-21'
---

**Requires:** US-GCG-1 (repo scaffolding)\n\nSet up strongly-typed configuration for the .NET backend and environment-specific settings for Flutter before any feature work begins.