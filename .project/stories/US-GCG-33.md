---
acceptance_criteria:
- .editorconfig with consistent settings for both languages
- C# .NET analysers configured (nullable reference types enabled and CA rules)
- Dart analysis_options.yaml with strict mode and recommended lint rules
- Pre-commit formatting documented (dotnet format and dart format)
- IDE settings files (.vscode or equivalent) for consistent developer experience
created: '2026-03-20'
epic_id: EPIC-GCG-5
id: US-GCG-33
points: 2
priority: must
status: active
tags:
- dx
- mvp
- layer-1-foundation
title: Code quality tooling and linting configuration
updated: '2026-03-20'
---

**Requires:** US-GCG-1 (repo scaffolding — needs both Flutter and .NET projects to exist)\n\nConfigure linting and formatting rules for both Dart and C# immediately after scaffolding so all subsequent code follows consistent standards.