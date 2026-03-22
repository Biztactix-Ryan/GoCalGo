---
acceptance_criteria:
- User can tap to flag/unflag any event
- Flagged events are visually distinct in the calendar view
- Flags persist across app restarts using local storage
- Flagged events section or filter is available
created: '2026-03-20'
epic_id: EPIC-GCG-2
id: US-GCG-8
points: 3
priority: must
status: done
tags:
- frontend
- mvp
- phase1
- layer-5-frontend
title: On-device event flagging
updated: '2026-03-21'
---

**Requires:** US-GCG-7 (daily calendar view — need event cards to add flag toggle to)\n\nOn-device flagging. Must be done before push notification scheduling (US-GCG-11) which syncs flags to backend.