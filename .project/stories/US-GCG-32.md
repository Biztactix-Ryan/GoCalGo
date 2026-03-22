---
acceptance_criteria:
- GitHub Actions workflow runs on push and PR
- 'Backend: dotnet format check and dotnet build and dotnet test'
- 'Frontend: dart analyze and flutter test'
- Pipeline fails on lint errors or test failures
- Pipeline status badge in README
- Pipeline completes in under 5 minutes
created: '2026-03-20'
epic_id: EPIC-GCG-5
id: US-GCG-32
points: 5
priority: must
status: done
tags:
- dx
- ci
- mvp
- layer-6-testing
title: CI pipeline with automated testing and linting
updated: '2026-03-21'
---

**Requires:** US-GCG-30 (.NET test infra), US-GCG-31 (Flutter test infra)\n\nGitHub Actions CI. Must be done before E2E testing (US-GCG-35).