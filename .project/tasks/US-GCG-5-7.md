---
assignee: claude
created: '2026-03-20'
depends_on: []
id: US-GCG-5-7
points: 2
status: done
story_id: US-GCG-5
tags: []
title: Implement GET /events/active endpoint
updated: '2026-03-21'
---

Return currently active events with buffs, bonuses, and time remaining. Serve from Redis cache with PostgreSQL fallback. Include proper JSON serialisation.