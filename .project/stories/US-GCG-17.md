---
acceptance_criteria:
- Apple Developer account configured with app ID and provisioning profile
- Android keystore generated and stored securely
- Flutter build configs reference signing credentials via environment variables
- Release builds succeed for both iOS and Android
- Signing credentials are documented but not committed to git
created: '2026-03-20'
epic_id: EPIC-GCG-1
id: US-GCG-17
points: 3
priority: must
status: done
tags:
- infra
- layer-2-infra
title: iOS and Android app signing setup
updated: '2026-03-22'
---

**Requires:** US-GCG-1 (Flutter project must exist for signing config)\n\nCan be done in parallel with backend work. Must be done before app store submission (US-GCG-15).