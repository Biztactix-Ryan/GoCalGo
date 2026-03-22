---
acceptance_criteria:
- Event data is cached locally on the device after each API sync
- App displays cached data when offline
- App indicates when data may be stale due to offline mode
- Data syncs automatically when network connectivity is restored
- Local cache is cleared and refreshed on a reasonable schedule
created: '2026-03-20'
epic_id: EPIC-GCG-2
id: US-GCG-9
points: 5
priority: must
status: done
tags:
- frontend
- mvp
- phase1
- layer-5-frontend
title: Offline data sync and local caching
updated: '2026-03-21'
---

**Requires:** US-GCG-6 (Flutter scaffold — API service layer), US-GCG-5 (REST API — need endpoints to sync from)\n\nOffline-first data layer. Must be done before data freshness indicator (US-GCG-26).