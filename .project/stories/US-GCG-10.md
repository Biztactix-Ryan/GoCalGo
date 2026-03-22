---
acceptance_criteria:
- Flutter app requests and obtains FCM device token
- Token is sent to the .NET backend on first launch and on refresh
- Backend stores device tokens in PostgreSQL
- Backend validates incoming token registrations to prevent abuse
- Token refresh is handled automatically when FCM rotates tokens
created: '2026-03-20'
epic_id: EPIC-GCG-3
id: US-GCG-10
points: 5
priority: should
status: done
tags:
- phase2
- backend
- frontend
- layer-7-notifications
title: FCM device token registration
updated: '2026-03-21'
---

**Requires:** US-GCG-16 (Firebase setup — credentials needed), US-GCG-6 (Flutter scaffold — app must exist), US-GCG-5 (REST API — need backend to register tokens with)\n\nFCM token registration. Must be done before notification scheduling (US-GCG-11) and Flutter handling (US-GCG-12).