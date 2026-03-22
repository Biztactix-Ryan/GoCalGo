---
acceptance_criteria:
- Today's active events are displayed with buff/bonus details
- Events show start and end times in the user's local timezone
- Event types are visually distinct (community day vs spotlight hour vs raid hour
  etc)
- Active buffs are prominently displayed (2x candy and bonus XP etc)
- Pull-to-refresh updates event data from the API
- Loading and error states are handled gracefully
created: '2026-03-20'
epic_id: EPIC-GCG-2
id: US-GCG-7
points: 8
priority: must
status: done
tags:
- frontend
- mvp
- phase1
- layer-5-frontend
title: Daily event calendar view
updated: '2026-03-21'
---

**Requires:** US-GCG-6 (Flutter scaffold), US-GCG-5 (REST API — need real endpoints), US-GCG-22 (timezone — need timezone conversion for display), US-GCG-27 (error states — for loading/error/empty handling)\n\nThe hero screen of the app. Must be done before flagging, upcoming, filtering, and onboarding.