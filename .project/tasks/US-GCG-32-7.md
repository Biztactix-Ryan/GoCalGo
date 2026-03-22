---
assignee: claude
created: '2026-03-20'
depends_on: []
id: US-GCG-32-7
points: 2
status: done
story_id: US-GCG-32
tags: []
title: Create GitHub Actions workflow for .NET backend
updated: '2026-03-21'
---

Workflow on push/PR: checkout, setup .NET, dotnet format --verify-no-changes, dotnet build, dotnet test. Cache NuGet packages. Fail on any step failure.