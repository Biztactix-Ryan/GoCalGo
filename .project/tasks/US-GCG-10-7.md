---
assignee: claude
created: '2026-03-20'
depends_on: []
id: US-GCG-10-7
points: 2
status: done
story_id: US-GCG-10
tags: []
title: Implement backend device token registration endpoint
updated: '2026-03-21'
---

Create POST /api/v1/devices endpoint. Accept FCM token and device timezone. Store in PostgreSQL. Validate token format. Handle token refresh (upsert on device ID).