---
assignee: claude
created: '2026-03-20'
depends_on: []
id: US-GCG-9-6
points: 2
status: done
story_id: US-GCG-9
tags: []
title: Implement local SQLite cache for event data
updated: '2026-03-22'
---

Use sqflite or drift to cache event data locally. Store full event payloads. Implement cache read/write with timestamp tracking for staleness detection.