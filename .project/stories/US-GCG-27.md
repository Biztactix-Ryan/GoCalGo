---
acceptance_criteria:
- Loading skeleton or spinner shown while fetching data
- Empty state screen when no events are active today
- Error state screen with retry button on API failure
- Network error state with offline mode explanation
- All states are visually consistent with the app theme
created: '2026-03-20'
epic_id: EPIC-GCG-2
id: US-GCG-27
points: 3
priority: must
status: done
tags:
- frontend
- mvp
- phase1
- layer-5-frontend
title: Error empty and loading state screens
updated: '2026-03-21'
---

**Requires:** US-GCG-6 (Flutter scaffold — app structure and theme must exist)\n\nReusable loading, error, and empty state widgets. Build these before feature screens so they can be used everywhere.