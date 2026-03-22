---
assignee: claude
created: '2026-03-20'
depends_on:
- US-GCG-36-7
id: US-GCG-36-8
points: 2
status: done
story_id: US-GCG-36
tags: []
title: Implement graceful degradation in API endpoints
updated: '2026-03-21'
---

API endpoints catch Redis failures and fall back to PostgreSQL. Health endpoint reports degraded status per subsystem. Ingestion job logs at Warning/Error on repeated failures.