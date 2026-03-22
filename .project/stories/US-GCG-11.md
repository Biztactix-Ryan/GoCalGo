---
acceptance_criteria:
- When a user flags an event the flag and FCM token are sent to the backend
- Backend schedules a notification for the flagged event's end time minus a configurable
  buffer
- Notification scheduling accounts for the user's local timezone
- Notifications are delivered via FCM to both iOS and Android
- Unflagging an event cancels the scheduled notification
- Notifications include event name and remaining time
created: '2026-03-20'
epic_id: EPIC-GCG-3
id: US-GCG-11
points: 8
priority: should
status: active
tags:
- phase2
- backend
- layer-7-notifications
title: Server-side push notification scheduling
updated: '2026-03-21'
---

**Requires:** US-GCG-10 (FCM registration — need device tokens stored), US-GCG-8 (event flagging — flags drive notification scheduling), US-GCG-16 (Firebase — need Admin SDK for sending)\n\nServer-side notification scheduling with timezone awareness.