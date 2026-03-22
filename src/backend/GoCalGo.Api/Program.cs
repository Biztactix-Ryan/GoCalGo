using System.Text.Json;
using GoCalGo.Api.Configuration;
using GoCalGo.Api.Data;
using GoCalGo.Api.Models;
using GoCalGo.Api.OpenApi;
using GoCalGo.Api.Services;
using GoCalGo.Contracts.Events;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Serilog;
using Serilog.Formatting.Compact;
using Polly;
using Polly.Extensions.Http;
using StackExchange.Redis;

WebApplicationBuilder builder = WebApplication.CreateBuilder(args);

// Structured logging via Serilog with compact JSON output
builder.Host.UseSerilog((context, configuration) =>
    configuration
        .ReadFrom.Configuration(context.Configuration)
        .Enrich.FromLogContext()
        .WriteTo.Console(new RenderedCompactJsonFormatter()));

// Map flat environment variables to configuration sections
builder.Configuration.AddInMemoryCollection(new Dictionary<string, string?>
{
    ["Firebase:ProjectId"] = Environment.GetEnvironmentVariable("FIREBASE_PROJECT_ID"),
    ["Firebase:CredentialsPath"] = Environment.GetEnvironmentVariable("FIREBASE_CREDENTIALS_JSON"),
}.Where(kv => kv.Value is not null));

// Strongly-typed configuration via IOptions pattern
builder.Services.Configure<DatabaseSettings>(
    builder.Configuration.GetSection(DatabaseSettings.SectionName));
builder.Services.Configure<RedisSettings>(
    builder.Configuration.GetSection(RedisSettings.SectionName));
builder.Services.Configure<ScrapedDuckSettings>(
    builder.Configuration.GetSection(ScrapedDuckSettings.SectionName));
builder.Services.Configure<FirebaseSettings>(
    builder.Configuration.GetSection(FirebaseSettings.SectionName));

// Ingestion status tracking (singleton for health endpoint)
builder.Services.AddSingleton<IngestionStatusTracker>();

// Redis client via StackExchange.Redis
RedisSettings redisConfig = builder.Configuration
    .GetSection(RedisSettings.SectionName)
    .Get<RedisSettings>() ?? new RedisSettings();
builder.Services.AddSingleton<IConnectionMultiplexer>(
    ConnectionMultiplexer.Connect($"{redisConfig.ConnectionString},abortConnect=false"));

// Cache service wrapping Redis with configurable TTL and graceful fallback
builder.Services.AddSingleton<RedisCacheService>();
builder.Services.AddSingleton<ICacheService>(sp =>
    new ResilientCacheService(
        sp.GetRequiredService<RedisCacheService>(),
        sp.GetRequiredService<ILogger<ResilientCacheService>>()));

// ScrapedDuck API client + ingestion service + scheduled background job
builder.Services.AddHttpClient<ScrapedDuckClient>()
    .AddPolicyHandler((services, _) =>
    {
        Microsoft.Extensions.Logging.ILogger logger = services.GetRequiredService<ILoggerFactory>().CreateLogger("ScrapedDuck.RetryPolicy");
        return HttpPolicyExtensions
            .HandleTransientHttpError()
            .WaitAndRetryAsync(3, retryAttempt =>
                TimeSpan.FromSeconds(Math.Pow(2, retryAttempt)),
                onRetry: (outcome, delay, retryAttempt, _) =>
                {
                    logger.LogWarning(
                        "ScrapedDuck HTTP retry {RetryAttempt}/3 after {DelaySeconds}s. Reason: {Reason}",
                        retryAttempt, delay.TotalSeconds,
                        outcome.Exception?.Message ?? $"HTTP {(int?)outcome.Result?.StatusCode}");
                });
    })
    .AddPolicyHandler((services, _) =>
    {
        Microsoft.Extensions.Logging.ILogger logger = services.GetRequiredService<ILoggerFactory>().CreateLogger("ScrapedDuck.CircuitBreaker");
        return HttpPolicyExtensions
            .HandleTransientHttpError()
            .CircuitBreakerAsync(
                handledEventsAllowedBeforeBreaking: 5,
                durationOfBreak: TimeSpan.FromSeconds(30),
                onBreak: (outcome, duration) =>
                {
                    logger.LogError(
                        "ScrapedDuck circuit OPEN for {BreakDurationSeconds}s. Reason: {Reason}",
                        duration.TotalSeconds,
                        outcome.Exception?.Message ?? $"HTTP {(int?)outcome.Result?.StatusCode}");
                },
                onReset: () =>
                {
                    logger.LogInformation("ScrapedDuck circuit CLOSED — recovered");
                },
                onHalfOpen: () =>
                {
                    logger.LogInformation("ScrapedDuck circuit HALF-OPEN — testing next request");
                });
    });
builder.Services.AddTransient<IScrapedDuckClient>(sp => sp.GetRequiredService<ScrapedDuckClient>());
builder.Services.AddTransient<ScrapedDuckIngestionService>();
builder.Services.AddHostedService<ScrapedDuckIngestionJob>();

// Notification scheduling and delivery
builder.Services.AddTransient<INotificationScheduler, NotificationScheduler>();
builder.Services.AddTransient<INotificationStore, NotificationStore>();
builder.Services.AddHostedService<NotificationSchedulerJob>();

// Initialize Firebase Admin SDK for push notifications
FirebaseSettings firebaseSettings = builder.Configuration
    .GetSection(FirebaseSettings.SectionName)
    .Get<FirebaseSettings>() ?? new FirebaseSettings();
if (!string.IsNullOrEmpty(firebaseSettings.CredentialsPath)
    && File.Exists(firebaseSettings.CredentialsPath))
{
#pragma warning disable CS0618 // GoogleCredential.FromFile is deprecated but replacement API is not yet stable
    FirebaseAdmin.FirebaseApp.Create(new FirebaseAdmin.AppOptions
    {
        Credential = Google.Apis.Auth.OAuth2.GoogleCredential.FromFile(firebaseSettings.CredentialsPath),
        ProjectId = firebaseSettings.ProjectId,
    });
#pragma warning restore CS0618
}

// EF Core with PostgreSQL
DatabaseSettings dbSettings = builder.Configuration
    .GetSection(DatabaseSettings.SectionName)
    .Get<DatabaseSettings>() ?? new DatabaseSettings();
builder.Services.AddDbContext<GoCalGoDbContext>(options =>
    options.UseNpgsql(dbSettings.ConnectionString));

// Rate limiting to prevent API abuse
int rateLimitPermits = builder.Configuration.GetValue("RateLimit:PermitLimit", 100);
int rateLimitWindowSeconds = builder.Configuration.GetValue("RateLimit:WindowSeconds", 60);
builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    options.AddFixedWindowLimiter("fixed", limiter =>
    {
        limiter.PermitLimit = rateLimitPermits;
        limiter.Window = TimeSpan.FromSeconds(rateLimitWindowSeconds);
        limiter.QueueLimit = 0;
    });
});

// OpenAPI document generation from code annotations
builder.Services.AddOpenApi(options =>
{
    options.AddDocumentTransformer((document, _, _) =>
    {
        document.Info.Title = "GoCalGo API";
        document.Info.Description = "Pokemon GO event calendar API — provides event listings, active event tracking, and upcoming event lookups sourced from ScrapedDuck.";
        document.Info.Version = "v1";
        return Task.CompletedTask;
    });
    options.AddSchemaTransformer<ResponseExampleSchemaTransformer>();
});

WebApplication app = builder.Build();

// Auto-apply EF Core migrations in development
if (app.Environment.IsDevelopment())
{
    using IServiceScope scope = app.Services.CreateScope();
    GoCalGoDbContext db = scope.ServiceProvider.GetRequiredService<GoCalGoDbContext>();
    try
    {
        db.Database.Migrate();
    }
    catch (Exception) when (app.Environment.IsDevelopment())
    {
        // Database not available — skip auto-migration (e.g. during testing)
    }
}

// Correlation ID middleware: read from request header or generate a new one
app.Use(async (context, next) =>
{
    const string correlationIdHeader = "X-Correlation-ID";
    string correlationId = context.Request.Headers[correlationIdHeader].FirstOrDefault()
                           ?? Guid.NewGuid().ToString();
    context.Response.Headers[correlationIdHeader] = correlationId;

    using (Serilog.Context.LogContext.PushProperty("CorrelationId", correlationId))
    {
        await next();
    }
});

app.MapOpenApi();

// Swagger UI available in development mode only
if (app.Environment.IsDevelopment())
{
    app.UseSwaggerUI(options =>
    {
        options.SwaggerEndpoint("/openapi/v1.json", "GoCalGo API v1");
    });
}

app.UseSerilogRequestLogging();
app.UseHttpsRedirection();
app.UseRateLimiter();

app.MapGet("/health", async (
    GoCalGoDbContext db,
    IServiceProvider sp,
    IOptions<RedisSettings> redisSettings,
    IngestionStatusTracker ingestionStatus) =>
{
    string dbStatus = "unhealthy";
    try
    {
        if (await db.Database.CanConnectAsync())
        {
            dbStatus = "healthy";
        }
    }
    catch
    {
        // DB unavailable
    }

    string redisStatus;
    if (string.IsNullOrEmpty(redisSettings.Value.Host))
    {
        redisStatus = "not_configured";
    }
    else
    {
        IConnectionMultiplexer? redis = sp.GetService<IConnectionMultiplexer>();
        if (redis is null)
        {
            redisStatus = "not_configured";
        }
        else
        {
            try
            {
                await redis.GetDatabase().PingAsync();
                redisStatus = "healthy";
            }
            catch
            {
                redisStatus = "unhealthy";
            }
        }
    }

    string scrapedDuckStatus = ingestionStatus.LastFetchSuccess switch
    {
        true => "healthy",
        false => "unhealthy",
        null => "unknown"
    };

    string overallStatus = dbStatus == "healthy"
                           && redisStatus != "unhealthy"
                           && scrapedDuckStatus != "unhealthy"
        ? "healthy"
        : "degraded";

    return Results.Ok(new
    {
        Status = overallStatus,
        Subsystems = new
        {
            Database = new { Status = dbStatus },
            Redis = new { Status = redisStatus, redisSettings.Value.Host, redisSettings.Value.Port },
            ScrapedDuck = new
            {
                Status = scrapedDuckStatus,
                LastFetch = ingestionStatus.LastFetchTime,
                LastFetchEventCount = ingestionStatus.LastFetchEventCount
            }
        }
    });
})
.WithSummary("Health check")
.WithDescription("Returns health status of all subsystems: database, Redis, and ScrapedDuck ingestion.")
.WithTags("Infrastructure");

// Versioned API route group — all endpoints under /api/v1/
// See docs/api-breaking-change-policy.md for versioning strategy
RouteGroupBuilder v1 = app.MapGroup("/api/v1")
    .RequireRateLimiting("fixed");

v1.MapGet("/events", async (
    ICacheService cache,
    GoCalGoDbContext db,
    IngestionStatusTracker ingestionStatus) =>
{
    bool cacheHit = false;
    List<Event>? events = null;

    // Try Redis cache first
    string? cached = await cache.GetAsync(CacheKeys.EventsAll);
    if (cached is not null)
    {
        events = JsonSerializer.Deserialize<List<Event>>(cached, new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        });
        cacheHit = true;
    }

    // Fall back to database
    events ??= await db.Events
        .Include(e => e.Buffs)
        .AsNoTracking()
        .OrderBy(e => e.Start)
        .ToListAsync();

    EventsResponse response = new()
    {
        Events = [.. events.Select(MapEventToDto)],
        LastUpdated = ingestionStatus.LastFetchTime ?? DateTime.MinValue,
        CacheHit = cacheHit,
    };

    return Results.Ok(response);
})
.Produces<EventsResponse>()
.WithSummary("List all events")
.WithDescription("Returns all Pokemon GO events ordered by start time. Results are served from Redis cache when available.")
.WithTags("Events");

v1.MapGet("/events/active", async (
    ICacheService cache,
    GoCalGoDbContext db,
    IngestionStatusTracker ingestionStatus) =>
{
    bool cacheHit = false;
    List<Event>? events = null;

    // Try Redis cache first (reuse the same cached event data)
    string? cached = await cache.GetAsync(CacheKeys.EventsAll);
    if (cached is not null)
    {
        events = JsonSerializer.Deserialize<List<Event>>(cached, new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        });
        cacheHit = true;
    }

    // Fall back to database
    events ??= await db.Events
        .Include(e => e.Buffs)
        .AsNoTracking()
        .OrderBy(e => e.Start)
        .ToListAsync();

    // Filter to currently active events (started and not yet ended)
    DateTime now = DateTime.UtcNow;
    List<Event> activeEvents = [.. events
        .Where(e => e.Start.HasValue && e.Start.Value <= now
                  && e.End.HasValue && e.End.Value > now)];

    ActiveEventsResponse response = new()
    {
        Events = [.. activeEvents.Select(e => MapActiveEventDto(e, now))],
        LastUpdated = ingestionStatus.LastFetchTime ?? DateTime.MinValue,
        CacheHit = cacheHit,
    };

    return Results.Ok(response);
})
.Produces<ActiveEventsResponse>()
.WithSummary("List active events")
.WithDescription("Returns events that are currently in progress (started and not yet ended), enriched with time-remaining metadata.")
.WithTags("Events");

v1.MapGet("/events/upcoming", async (
    ICacheService cache,
    GoCalGoDbContext db,
    IngestionStatusTracker ingestionStatus,
    int? days) =>
{
    int windowDays = days ?? 7;
    if (windowDays < 0)
    {
        return Results.BadRequest(new { error = "days parameter must be non-negative" });
    }

    bool cacheHit = false;
    List<Event>? events = null;

    // Try Redis cache first (reuse the same cached event data)
    string? cached = await cache.GetAsync(CacheKeys.EventsAll);
    if (cached is not null)
    {
        events = JsonSerializer.Deserialize<List<Event>>(cached, new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        });
        cacheHit = true;
    }

    // Fall back to database
    events ??= await db.Events
        .Include(e => e.Buffs)
        .AsNoTracking()
        .OrderBy(e => e.Start)
        .ToListAsync();

    // Filter to upcoming events: started after now and within the window
    DateTime now = DateTime.UtcNow;
    DateTime windowEnd = now.AddDays(windowDays);
    List<Event> upcomingEvents = [.. events
        .Where(e => e.Start.HasValue && e.Start.Value > now
                  && e.Start.Value <= windowEnd)
        .OrderBy(e => e.Start)];

    EventsResponse response = new()
    {
        Events = [.. upcomingEvents.Select(MapEventToDto)],
        LastUpdated = ingestionStatus.LastFetchTime ?? DateTime.MinValue,
        CacheHit = cacheHit,
    };

    return Results.Ok(response);
})
.Produces<EventsResponse>()
.WithSummary("List upcoming events")
.WithDescription("Returns events starting within a configurable lookahead window (default 7 days). Use the 'days' query parameter to adjust.")
.WithTags("Events");

v1.MapPost("/device-tokens", async (
    GoCalGoDbContext db,
    HttpContext httpContext) =>
{
    RegisterDeviceTokenRequest? request;
    try
    {
        request = await httpContext.Request.ReadFromJsonAsync<RegisterDeviceTokenRequest>();
    }
    catch
    {
        return Results.BadRequest(new { error = "Invalid request body" });
    }

    if (request is null
        || string.IsNullOrWhiteSpace(request.Token)
        || string.IsNullOrWhiteSpace(request.Platform))
    {
        return Results.BadRequest(new { error = "Token and platform are required" });
    }

    string token = request.Token.Trim();
    string platform = request.Platform.Trim();
    string? timezone = string.IsNullOrWhiteSpace(request.Timezone) ? null : request.Timezone.Trim();

    if (token.Length > 500)
    {
        return Results.BadRequest(new { error = "Token must not exceed 500 characters" });
    }

    if (platform is not ("android" or "ios"))
    {
        return Results.BadRequest(new { error = "Platform must be 'android' or 'ios'" });
    }

    if (timezone is not null && timezone.Length > 100)
    {
        return Results.BadRequest(new { error = "Timezone must not exceed 100 characters" });
    }

    DateTime now = DateTime.UtcNow;

    DeviceToken? existing = await db.DeviceTokens
        .FirstOrDefaultAsync(d => d.Token == token);

    if (existing is not null)
    {
        existing.Platform = platform;
        existing.Timezone = timezone;
        existing.UpdatedAt = now;
        await db.SaveChangesAsync();
        return Results.Ok(new { message = "Device token updated" });
    }

    db.DeviceTokens.Add(new DeviceToken
    {
        Token = token,
        Platform = platform,
        Timezone = timezone,
        CreatedAt = now,
        UpdatedAt = now,
    });
    await db.SaveChangesAsync();
    return Results.Created($"/api/v1/device-tokens", new { message = "Device token registered" });
})
.WithSummary("Register device token")
.WithDescription("Registers an FCM device token for push notifications. Performs upsert if the token already exists.")
.WithTags("Devices");

v1.MapPost("/flags", async (
    GoCalGoDbContext db,
    INotificationStore notificationStore,
    HttpContext httpContext) =>
{
    FlagSyncRequest? request;
    try
    {
        request = await httpContext.Request.ReadFromJsonAsync<FlagSyncRequest>();
    }
    catch
    {
        return Results.BadRequest(new { error = "Invalid request body" });
    }

    if (request is null
        || string.IsNullOrWhiteSpace(request.EventId)
        || string.IsNullOrWhiteSpace(request.FcmToken)
        || string.IsNullOrWhiteSpace(request.Action))
    {
        return Results.BadRequest(new { error = "eventId, fcmToken, and action are required" });
    }

    string eventId = request.EventId.Trim();
    string fcmToken = request.FcmToken.Trim();
    string action = request.Action.Trim().ToLowerInvariant();

    if (eventId.Length > 200)
    {
        return Results.BadRequest(new { error = "eventId must not exceed 200 characters" });
    }

    if (fcmToken.Length > 500)
    {
        return Results.BadRequest(new { error = "fcmToken must not exceed 500 characters" });
    }

    if (action is not ("flag" or "unflag"))
    {
        return Results.BadRequest(new { error = "action must be 'flag' or 'unflag'" });
    }

    EventFlag? existing = await db.EventFlags
        .FirstOrDefaultAsync(f => f.EventId == eventId && f.DeviceToken == fcmToken);

    int leadTimeMinutes = request.LeadTimeMinutes ?? 15;
    if (!EventFlag.AllowedLeadTimeMinutes.Contains(leadTimeMinutes))
    {
        return Results.BadRequest(new { error = "leadTimeMinutes must be one of: 5, 15, 30, 60" });
    }

    if (action == "flag")
    {
        if (existing is not null)
        {
            existing.LeadTimeMinutes = leadTimeMinutes;
            await db.SaveChangesAsync();
            return Results.Ok(new { message = "Event flag updated" });
        }

        db.EventFlags.Add(new EventFlag
        {
            EventId = eventId,
            DeviceToken = fcmToken,
            CreatedAt = DateTime.UtcNow,
            LeadTimeMinutes = leadTimeMinutes,
        });
        await db.SaveChangesAsync();
        return Results.Created($"/api/v1/flags", new { message = "Event flagged" });
    }
    else // unflag
    {
        if (existing is null)
        {
            return Results.Ok(new { message = "Event was not flagged" });
        }

        db.EventFlags.Remove(existing);

        // Cancel any pending notifications for this event+device
        DeviceToken? device = await db.DeviceTokens
            .FirstOrDefaultAsync(d => d.Token == fcmToken);
        if (device is not null)
        {
            await notificationStore.CancelByEventAndDeviceAsync(eventId, device.Id);
        }

        await db.SaveChangesAsync();
        return Results.Ok(new { message = "Event unflagged" });
    }
})
.WithSummary("Flag or unflag an event")
.WithDescription("Creates or removes an event flag linked to a device token. Used to sync flag preferences for push notification scheduling.")
.WithTags("Flags");

v1.MapPost("/notification-settings", async (
    GoCalGoDbContext db,
    HttpContext httpContext) =>
{
    NotificationSettingsRequest? request;
    try
    {
        request = await httpContext.Request.ReadFromJsonAsync<NotificationSettingsRequest>();
    }
    catch
    {
        return Results.BadRequest(new { error = "Invalid request body" });
    }

    if (request is null || string.IsNullOrWhiteSpace(request.FcmToken))
    {
        return Results.BadRequest(new { error = "fcmToken is required" });
    }

    string fcmToken = request.FcmToken.Trim();
    if (fcmToken.Length > 500)
    {
        return Results.BadRequest(new { error = "fcmToken must not exceed 500 characters" });
    }

    int leadTimeMinutes = request.LeadTimeMinutes ?? 15;
    if (!EventFlag.AllowedLeadTimeMinutes.Contains(leadTimeMinutes))
    {
        return Results.BadRequest(new { error = "leadTimeMinutes must be one of: 5, 15, 30, 60" });
    }

    string enabledEventTypes = request.EnabledEventTypes is not null
        ? string.Join(",", request.EnabledEventTypes.Where(t => !string.IsNullOrWhiteSpace(t)).Select(t => t.Trim()))
        : string.Empty;

    DateTime now = DateTime.UtcNow;

    NotificationPreference? existing = await db.NotificationPreferences
        .FirstOrDefaultAsync(p => p.DeviceToken == fcmToken);

    if (existing is not null)
    {
        existing.Enabled = request.Enabled ?? true;
        existing.LeadTimeMinutes = leadTimeMinutes;
        existing.EnabledEventTypes = enabledEventTypes;
        existing.UpdatedAt = now;
        await db.SaveChangesAsync();
        return Results.Ok(new { status = "ok" });
    }

    db.NotificationPreferences.Add(new NotificationPreference
    {
        DeviceToken = fcmToken,
        Enabled = request.Enabled ?? true,
        LeadTimeMinutes = leadTimeMinutes,
        EnabledEventTypes = enabledEventTypes,
        UpdatedAt = now,
    });
    await db.SaveChangesAsync();
    return Results.Created("/api/v1/notification-settings", new { status = "ok" });
})
.WithSummary("Sync notification settings")
.WithDescription("Persists global notification preferences (enabled, lead time, event type filters) for a device. Performs upsert based on FCM token.")
.WithTags("Notifications");

app.Run();

static EventDto MapEventToDto(Event e)
{
    return new()
    {
        Id = e.Id,
        Name = e.Name,
        EventType = (EventTypeDto)(int)e.EventType,
        Heading = e.Heading,
        ImageUrl = e.ImageUrl,
        LinkUrl = e.LinkUrl,
        Start = e.Start,
        End = e.End,
        IsUtcTime = e.IsUtcTime,
        HasSpawns = e.HasSpawns,
        HasResearchTasks = e.HasResearchTasks,
        Buffs = [.. e.Buffs.Select(b => new BuffDto
        {
            Text = b.Text,
            IconUrl = b.IconUrl,
            Category = (GoCalGo.Contracts.Events.BuffCategory)(int)b.Category,
            Multiplier = b.Multiplier,
            Resource = b.Resource,
            Disclaimer = b.Disclaimer,
        })],
        FeaturedPokemon = [],
        PromoCodes = [],
    };
}

static ActiveEventDto MapActiveEventDto(Event e, DateTime now)
{
    double timeRemainingSeconds = e.End.HasValue
        ? Math.Max(0, (e.End.Value - now).TotalSeconds)
        : 0;

    return new()
    {
        Id = e.Id,
        Name = e.Name,
        EventType = (EventTypeDto)(int)e.EventType,
        Heading = e.Heading,
        ImageUrl = e.ImageUrl,
        LinkUrl = e.LinkUrl,
        Start = e.Start,
        End = e.End,
        IsUtcTime = e.IsUtcTime,
        HasSpawns = e.HasSpawns,
        HasResearchTasks = e.HasResearchTasks,
        Buffs = [.. e.Buffs.Select(b => new BuffDto
        {
            Text = b.Text,
            IconUrl = b.IconUrl,
            Category = (GoCalGo.Contracts.Events.BuffCategory)(int)b.Category,
            Multiplier = b.Multiplier,
            Resource = b.Resource,
            Disclaimer = b.Disclaimer,
        })],
        FeaturedPokemon = [],
        PromoCodes = [],
        TimeRemainingSeconds = timeRemainingSeconds,
    };
}

// Make the implicit Program class accessible for integration tests
public partial class Program { }

internal sealed record RegisterDeviceTokenRequest(string? Token, string? Platform, string? Timezone);
internal sealed record FlagSyncRequest(string? EventId, string? FcmToken, string? Action, int? LeadTimeMinutes);
internal sealed record NotificationSettingsRequest(string? FcmToken, bool? Enabled, int? LeadTimeMinutes, List<string>? EnabledEventTypes);
