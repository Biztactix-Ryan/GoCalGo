---
assignee: claude
created: '2026-03-20'
depends_on: []
id: US-GCG-22-7
points: 2
status: done
story_id: US-GCG-22
tags: []
title: Implement backend timezone metadata storage and API response format
updated: '2026-03-22'
---

Store event times with timezone type flag (local-time vs fixed-UTC) from ScrapedDuck. API responses include ISO 8601 timestamps with timezone info and a local_time boolean flag.