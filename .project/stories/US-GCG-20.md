---
acceptance_criteria:
- ScrapedDuck API endpoints documented with example responses
- Event types identified and catalogued (community day and spotlight hour and raid
  hour etc)
- Buff/bonus data structure understood and mapped
- Internal event data contract defined as shared DTOs
- Edge cases identified (multi-day events and recurring events and timezone quirks)
- API reliability and rate limits assessed
created: '2026-03-20'
epic_id: EPIC-GCG-2
id: US-GCG-20
points: 3
priority: must
status: done
tags:
- backend
- research
- mvp
- phase1
- layer-0-research
title: ScrapedDuck API exploration and data contract definition
updated: '2026-03-20'
---

As a developer, I want to explore the ScrapedDuck API responses, document the available data, and define the internal event data contract so that both the backend and Flutter app agree on a shared schema before implementation begins.