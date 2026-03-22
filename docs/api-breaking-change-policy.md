# API Breaking Change Policy

Defines what constitutes a breaking change for the GoCalGo API and how breaking changes are managed across versions.

---

## What is a breaking change?

A **breaking change** is any modification to the API that could cause existing clients to fail or behave incorrectly. The following are considered breaking changes:

- **Removing** an endpoint, field, or enum value
- **Renaming** an endpoint path, field, or enum value
- **Changing the type** of an existing field (e.g. `string` → `int`)
- **Making a nullable field required** (non-nullable)
- **Changing response envelope structure** (e.g. removing the `Events` wrapper)
- **Changing serialisation conventions** (e.g. camelCase → snake_case, enum format)
- **Adding required query parameters** to existing endpoints
- **Changing error response shapes** in ways clients may depend on
- **Changing the semantics** of an existing field (e.g. redefining what `Start` means)

## What is NOT a breaking change?

The following are **non-breaking** and can be made within the current API version:

- **Adding** new optional fields to response DTOs (clients must ignore unknown fields)
- **Adding** new endpoints
- **Adding** new enum values (clients must handle unknown values gracefully)
- **Adding** optional query parameters with sensible defaults
- **Relaxing** a constraint (e.g. making a required field nullable)
- **Improving** error messages without changing error codes or shapes
- **Performance** or caching changes that don't alter response content

## Versioning strategy

GoCalGo uses **URL-based versioning** with the prefix `/api/v{n}/`. The current version is **v1**.

### When to bump the version

Create a new API version (`/api/v2/`, etc.) when a breaking change is unavoidable. Both versions must run concurrently during the migration window.

### Migration window

When a new version is introduced:

1. **Announce** the deprecation in release notes and via a `Sunset` response header on the old version
2. **Run both versions concurrently** for a minimum of **2 minor app releases** so users have time to update
3. **Monitor** traffic to the old version — do not remove it while clients are still calling it
4. **Remove** the old version only after traffic drops to zero or the migration window has elapsed

## Client expectations

Clients (the Flutter app) must be built to tolerate non-breaking additions:

- Ignore unknown JSON fields
- Handle unknown enum values with a fallback (e.g. `other`)
- Do not rely on field ordering in JSON responses

## DTO contract

The shared DTO contract is defined in [docs/event-dto-contract.md](event-dto-contract.md). Changes to DTOs must be evaluated against this policy before merging.

---

*Last updated: 2026-03-21*
