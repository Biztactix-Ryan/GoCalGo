---
acceptance_criteria:
- Firebase project created with appropriate naming
- FCM enabled in the Firebase console
- iOS and Android apps registered in Firebase
- google-services.json and GoogleService-Info.plist generated
- Firebase Admin SDK service account credentials generated for the .NET backend
- Credentials stored securely (not committed to git)
created: '2026-03-20'
epic_id: EPIC-GCG-1
id: US-GCG-16
points: 3
priority: must
status: done
tags:
- infra
- mvp
- layer-2-infra
title: Firebase project setup and configuration
updated: '2026-03-22'
---

**Requires:** US-GCG-1 (repo scaffolding — Flutter project must exist to add Firebase config files)\n\nFirebase project setup. Can be done in parallel with Docker Compose work.