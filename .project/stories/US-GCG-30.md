---
acceptance_criteria:
- xUnit test project created and referenced from solution
- Unit test pattern established with mocking (NSubstitute or Moq)
- Integration test pattern using WebApplicationFactory with Testcontainers for PostgreSQL
  and Redis
- ScrapedDuck client tests using WireMock or similar for HTTP mocking
- Test data builders or fixtures for common entities
- Tests run via dotnet test and report results clearly
created: '2026-03-20'
epic_id: EPIC-GCG-5
id: US-GCG-30
points: 5
priority: must
status: done
tags:
- backend
- testing
- dx
- mvp
- layer-6-testing
title: .NET backend unit and integration test infrastructure
updated: '2026-03-21'
---

**Requires:** US-GCG-1 (.NET project), US-GCG-5 (REST API — need code to test), US-GCG-4 (ingestion — need ScrapedDuck client to test)\n\nBackend test infrastructure. Must be done before CI pipeline (US-GCG-32).