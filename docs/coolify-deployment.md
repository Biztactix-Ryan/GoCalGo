# Coolify Deployment Guide

Step-by-step guide to deploy the GoCalGo .NET API on Coolify with automatic builds triggered by GitHub webhooks.

## Prerequisites

- Coolify instance running and accessible
- GitHub repository: `Biztactix-Ryan/GoCalGo`
- PostgreSQL and Redis services provisioned (either on Coolify or externally)

## 1. Create a New Project in Coolify

1. Open Coolify dashboard
2. Click **New Project**
3. Name it `GoCalGo` (or similar)
4. Add a new **Production** environment within the project

## 2. Add the Application Resource

1. Inside the project environment, click **Add New Resource** → **Application**
2. Select **GitHub** as the source
3. Connect to the `Biztactix-Ryan/GoCalGo` repository
4. Configure the build settings:

| Setting | Value |
|---------|-------|
| Branch | `main` |
| Build Pack | Dockerfile |
| Dockerfile Location | `src/backend/GoCalGo.Api/Dockerfile` |
| Build Context | `src/backend` |
| Port | `8080` |
| Health Check Path | `/health` |

## 3. Configure GitHub Webhook

Coolify auto-creates a webhook when you connect a GitHub repository. Verify it:

1. Go to GitHub → `Biztactix-Ryan/GoCalGo` → **Settings** → **Webhooks**
2. Confirm a webhook exists pointing to your Coolify instance (e.g., `https://<coolify-domain>/webhooks/...`)
3. Ensure it is:
   - **Active** (green checkmark)
   - Subscribed to **push** events
4. If the webhook was not auto-created, add it manually:
   - Payload URL: `https://<coolify-domain>/webhooks/source/github/events`
   - Content type: `application/json`
   - Secret: copy from Coolify's webhook settings
   - Events: select **Just the push event**

**Validate:** Run `bash scripts/test-coolify-webhook.sh` to verify webhook configuration via the GitHub API.

## 4. Set Environment Variables

In the Coolify application settings, go to **Environment Variables** and add:

### PostgreSQL Connection

```
ConnectionStrings__PostgreSQL=Host=<postgres-host>;Port=5432;Database=gocalgo;Username=gocalgo;Password=<password>
```

Replace `<postgres-host>` with the hostname of your PostgreSQL service. If PostgreSQL runs as a Coolify service in the same project, use the service name (e.g., `postgres`). Replace `<password>` with the actual database password.

### Redis Connection

```
ConnectionStrings__Redis=<redis-host>:6379
```

Replace `<redis-host>` with the hostname of your Redis service.

### Application Settings

| Variable | Value | Notes |
|----------|-------|-------|
| `ASPNETCORE_ENVIRONMENT` | `Production` | Required — disables auto-migration, enables production logging |
| `ScrapedDuck__BaseUrl` | `https://pokemon-go-api.github.io/pokemon-go-api` | Event data source |
| `ScrapedDuck__CacheExpirationMinutes` | `30` | How long to cache event data |
| `Firebase__ProjectId` | `gocalgo` | Firebase project for push notifications |
| `Firebase__CredentialsPath` | `/app/firebase-credentials.json` | Path inside container — mount or embed the service account JSON |

### Firebase Credentials

The Firebase service account JSON must be available inside the container. Options:

1. **Build-time:** Add the JSON file to the Docker build context (not recommended — leaks credentials into the image)
2. **Runtime mount:** Use Coolify's file mount feature to inject the JSON at `/app/firebase-credentials.json`
3. **Environment variable:** Modify the app to read credentials from an env var instead of a file path

**Validate:** Run `bash scripts/test-coolify-env-vars.sh` to verify environment variable structure.

## 5. Deploy

1. Click **Deploy** in Coolify to trigger the first build
2. Monitor the build logs to verify:
   - Dockerfile builds successfully (multi-stage: restore → publish → runtime)
   - Container starts and health check passes at `/health`
3. Subsequent deployments happen automatically on push to `main`

## 6. Verify Deployment

After the first successful deploy:

1. Check the application URL responds (Coolify assigns a domain or use the configured one)
2. Hit the health endpoint: `curl https://<your-domain>/health`
3. Verify database connectivity by checking API endpoints return data
4. Push a test commit to `main` and confirm Coolify triggers a new build automatically

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Build fails at restore | Check that `src/backend/Directory.Build.props` and project files are in the build context |
| Container starts but health check fails | Verify `ASPNETCORE_ENVIRONMENT` is set and connection strings are correct |
| Webhook doesn't trigger | Check webhook is active in GitHub, check Coolify webhook logs |
| Database connection refused | Verify PostgreSQL host is reachable from the container network |
| Redis connection refused | Verify Redis host is reachable and port 6379 is not firewalled |
