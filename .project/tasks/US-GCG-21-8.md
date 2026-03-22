---
assignee: claude
created: '2026-03-20'
depends_on: []
id: US-GCG-21-8
points: 2
status: done
story_id: US-GCG-21
tags: []
title: Implement cache service with cache-aside pattern
updated: '2026-03-21'
---

Create ICacheService with Get<T>, Set<T>, Invalidate methods. Implement cache-aside: check Redis, fallback to DB on miss, populate cache. Configurable TTL per key type. Namespace cache keys.