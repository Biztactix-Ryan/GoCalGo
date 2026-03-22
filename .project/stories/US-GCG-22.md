---
acceptance_criteria:
- Backend stores event times with timezone metadata from ScrapedDuck
- API responses include timezone-aware timestamps
- Flutter app converts and displays times in device local timezone
- Events that use local time (same wall-clock time everywhere) are handled correctly
- Events with fixed UTC times are converted to local display correctly
- Unit tests cover timezone edge cases (DST transitions and date boundary crossings)
created: '2026-03-20'
epic_id: EPIC-GCG-2
id: US-GCG-22
points: 5
priority: must
status: done
tags:
- backend
- frontend
- mvp
- phase1
- layer-3-backend
title: Timezone handling service
updated: '2026-03-22'
---

**Requires:** US-GCG-20 (data contract — need to understand how ScrapedDuck represents times), US-GCG-4 (event schema — need to know how events are stored)\n\nTimezone logic for both backend and frontend. Must be done before daily calendar view (US-GCG-7).