---
assignee: claude
created: '2026-03-20'
depends_on: []
id: US-GCG-32-8
points: 2
status: done
story_id: US-GCG-32
tags: []
title: Create GitHub Actions workflow for Flutter app
updated: '2026-03-21'
---

Workflow on push/PR: checkout, setup Flutter, flutter pub get, dart analyze, flutter test. Cache pub packages. Fail on any step failure.