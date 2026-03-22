---
assignee: claude
created: '2026-03-20'
depends_on:
- US-GCG-10-6
- US-GCG-10-7
id: US-GCG-10-8
points: 1
status: done
story_id: US-GCG-10
tags: []
title: Send token from Flutter to backend on launch and refresh
updated: '2026-03-21'
---

On app launch and on FCM token refresh, POST the token to the backend. Include device timezone. Retry on failure with backoff.