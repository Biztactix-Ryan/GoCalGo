# Infrastructure — Pokemon Go Events Calendar

## Hosting
Self-hosted Docker containers managed by Coolify. Runs on existing infrastructure alongside other projects. No cloud provider dependency.

## Environments
Production only. No separate dev or staging environments at this stage. Local development against the production API or a local Docker Compose stack.

## CI/CD
Coolify handles builds automatically. A GitHub webhook fires on push to the main branch, triggering Coolify to build and deploy the updated container. No separate CI pipeline (e.g. GitHub Actions) — Coolify is the build system.

For step-by-step setup instructions, see [docs/coolify-deployment.md](docs/coolify-deployment.md).

## Services & Dependencies

| Service | Role | Details |
|---------|------|---------|
| PostgreSQL | Primary database | Stores cached event data, device tokens, user event flags |
| Redis | Caching layer | Caches event data from ScrapedDuck to reduce API calls and improve response times |
| ScrapedDuck API | Event data source | Community-maintained JSON API that scrapes LeekDuck.com for Pokemon Go event data. External dependency — not under our control |
| Firebase Cloud Messaging | Push notifications | Delivers push notifications to iOS and Android devices when flagged events end |

## Monitoring & Observability
Coolify's built-in monitoring and logging. No additional monitoring tools planned at this stage. May add dedicated logging/alerting as the user base grows.

## Backup & Recovery
TBD — to be determined based on data volume. PostgreSQL backup strategy should be established before launch. Event data itself is transient and can be re-fetched from ScrapedDuck, so the critical data to back up is device tokens and user flags.
