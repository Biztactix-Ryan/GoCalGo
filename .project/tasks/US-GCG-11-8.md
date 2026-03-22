---
assignee: claude
created: '2026-03-20'
depends_on:
- US-GCG-11-7
id: US-GCG-11-8
points: 3
status: done
story_id: US-GCG-11
tags: []
title: Implement notification scheduler service
updated: '2026-03-22'
---

Background service that monitors flagged events. Calculate notification time (event end minus user's lead time preference, adjusted for timezone). Queue notifications for delivery via FCM.