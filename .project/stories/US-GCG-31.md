---
acceptance_criteria:
- Unit test pattern established for Dart services and models
- Widget test pattern established for key screens
- Mock API service created for testing without backend
- Test coverage for event data parsing and timezone conversion
- Golden tests for critical UI components (event card and daily view)
- Tests run via flutter test and report results clearly
created: '2026-03-20'
epic_id: EPIC-GCG-5
id: US-GCG-31
points: 5
priority: must
status: done
tags:
- frontend
- testing
- dx
- mvp
- layer-6-testing
title: Flutter unit and widget test infrastructure
updated: '2026-03-21'
---

**Requires:** US-GCG-6 (Flutter scaffold), US-GCG-7 (daily calendar — need screens to widget-test), US-GCG-22 (timezone — need timezone logic to unit-test)\n\nFlutter test infrastructure. Must be done before CI pipeline (US-GCG-32).