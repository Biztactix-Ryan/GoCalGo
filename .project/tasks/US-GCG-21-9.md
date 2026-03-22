---
assignee: claude
created: '2026-03-20'
depends_on: []
id: US-GCG-21-9
points: 1
status: done
story_id: US-GCG-21
tags: []
title: Implement Redis graceful fallback on outage
updated: '2026-03-21'
---

Wrap Redis operations in try-catch. On Redis connection failure, log warning and fall back to PostgreSQL. Do not propagate Redis errors to API consumers.