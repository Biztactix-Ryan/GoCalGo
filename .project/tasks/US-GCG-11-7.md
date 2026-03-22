---
assignee: claude
created: '2026-03-20'
depends_on: []
id: US-GCG-11-7
points: 2
status: done
story_id: US-GCG-11
tags: []
title: Implement backend flag sync endpoint
updated: '2026-03-22'
---

Create POST /api/v1/flags endpoint. Accept event ID, FCM token, and action (flag/unflag). Store flag in PostgreSQL linked to device token.