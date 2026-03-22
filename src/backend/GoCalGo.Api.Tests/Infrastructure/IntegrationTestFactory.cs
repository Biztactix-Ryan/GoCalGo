using GoCalGo.Api.Configuration;
using GoCalGo.Api.Data;
using GoCalGo.Api.Services;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using StackExchange.Redis;

namespace GoCalGo.Api.Tests.Infrastructure
{
    /// <summary>
    /// WebApplicationFactory that replaces PostgreSQL and Redis registrations
    /// with connections to Testcontainers instances.
    /// Optionally accepts a ScrapedDuck base URL (e.g. WireMock) to wire up
    /// the real ingestion pipeline for E2E tests.
    /// </summary>
    public sealed class IntegrationTestFactory(
        PostgresRedisFixture fixture,
        string? scrapedDuckBaseUrl = null) : WebApplicationFactory<Program>
    {

        protected override void ConfigureWebHost(IWebHostBuilder builder)
        {
            builder.UseEnvironment("Testing");

            builder.ConfigureServices(services =>
            {
                // Replace PostgreSQL with Testcontainers instance
                List<ServiceDescriptor> dbDescriptors = [.. services
                    .Where(d => d.ServiceType.FullName?.Contains("EntityFrameworkCore") == true
                             || d.ServiceType.FullName?.Contains("Npgsql") == true
                             || d.ServiceType == typeof(DbContextOptions<GoCalGoDbContext>)
                             || d.ImplementationType?.FullName?.Contains("Npgsql") == true
                             || d.ImplementationType?.FullName?.Contains("EntityFrameworkCore") == true)];
                foreach (ServiceDescriptor descriptor in dbDescriptors)
                {
                    services.Remove(descriptor);
                }
                services.AddDbContext<GoCalGoDbContext>(options =>
                    options.UseNpgsql(fixture.PostgresConnectionString));

                // Replace Redis with Testcontainers instance
                services.RemoveAll<IConnectionMultiplexer>();
                services.RemoveAll<RedisCacheService>();
                services.RemoveAll<ICacheService>();
                services.AddSingleton<IConnectionMultiplexer>(
                    ConnectionMultiplexer.Connect($"{fixture.RedisConnectionString},abortConnect=false"));
                services.AddSingleton<RedisCacheService>();
                services.AddSingleton<ICacheService>(sp =>
                    new ResilientCacheService(
                        sp.GetRequiredService<RedisCacheService>(),
                        sp.GetRequiredService<ILogger<ResilientCacheService>>()));

                // Remove background jobs so they don't interfere with tests
                services.RemoveAll<IHostedService>();

                // Wire up ScrapedDuck client pointing at WireMock for E2E tests
                if (scrapedDuckBaseUrl is not null)
                {
                    services.RemoveAll<IScrapedDuckClient>();
                    services.RemoveAll<ScrapedDuckClient>();
                    services.AddSingleton(Options.Create(new ScrapedDuckSettings
                    {
                        BaseUrl = scrapedDuckBaseUrl,
                    }));
                    services.AddHttpClient<ScrapedDuckClient>();
                    services.AddTransient<IScrapedDuckClient>(sp =>
                        sp.GetRequiredService<ScrapedDuckClient>());
                    services.AddTransient<ScrapedDuckIngestionService>();
                }
            });
        }

        /// <summary>
        /// Ensures the database schema is created via EF Core migrations.
        /// Call this once per test run after the factory is built.
        /// </summary>
        public async Task EnsureDatabaseMigratedAsync()
        {
            using IServiceScope scope = Services.CreateScope();
            GoCalGoDbContext db = scope.ServiceProvider.GetRequiredService<GoCalGoDbContext>();
            await db.Database.MigrateAsync();
        }
    }
}
