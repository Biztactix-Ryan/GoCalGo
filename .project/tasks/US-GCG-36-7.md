---
assignee: claude
created: '2026-03-20'
depends_on: []
id: US-GCG-36-7
points: 2
status: done
story_id: US-GCG-36
tags: []
title: Implement HTTP retry with Polly for ScrapedDuck client
updated: '2026-03-21'
---

Add Polly package. Configure retry policy with exponential backoff (3 retries). Add circuit breaker policy to stop calling after sustained failures. Log each retry and circuit state change.