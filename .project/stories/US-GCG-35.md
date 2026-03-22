---
acceptance_criteria:
- 'E2E test verifies: mock ScrapedDuck data is ingested and served via API and displayed
  in app'
- Flutter integration tests run against a local backend
- Test environment spins up via Docker Compose
- 'Critical user journeys covered: view today''s events and flag an event and view
  upcoming events'
- Tests can run in CI
created: '2026-03-20'
epic_id: EPIC-GCG-5
id: US-GCG-35
points: 5
priority: should
status: done
tags:
- testing
- dx
- layer-8-release
title: End-to-end integration testing
updated: '2026-03-22'
---

**Requires:** US-GCG-32 (CI pipeline), US-GCG-5 (REST API), US-GCG-7 (daily calendar), US-GCG-2 (Docker Compose)\n\nEnd-to-end tests. Near the end of the sprint after all features are built.