---
assignee: claude
created: '2026-03-20'
depends_on:
- US-GCG-4-7
- US-GCG-4-8
id: US-GCG-4-9
points: 3
status: done
story_id: US-GCG-4
tags: []
title: Implement scheduled background ingestion job
updated: '2026-03-21'
---

Create a hosted background service that runs the ScrapedDuck fetch on a configurable interval (default 15 min). Normalise data, upsert into PostgreSQL, refresh Redis cache. Log results.