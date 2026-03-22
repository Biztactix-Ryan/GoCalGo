using System.Net;
using GoCalGo.Api.Data;
using GoCalGo.Api.Services;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Hosting;

namespace GoCalGo.Api.Tests.Api
{
    /// <summary>
    /// Verifies acceptance criterion for story US-GCG-5:
    /// "API enforces rate limiting to prevent abuse"
    ///
    /// Tests that:
    /// 1. Requests within the limit succeed normally
    /// 2. Requests exceeding the limit receive 429 Too Many Requests
    /// 3. Health endpoint is not rate-limited
    /// </summary>
    public class RateLimitingTests
    {
        /// <summary>
        /// Factory with a tight rate limit (3 requests per 60s) for testability.
        /// Uses configuration overrides so the production rate limiter runs with a lower permit limit.
        /// </summary>
        private sealed class RateLimitedFactory : WebApplicationFactory<Program>
        {
            private readonly string _dbName = "RateLimitTest_" + Guid.NewGuid();

            protected override void ConfigureWebHost(IWebHostBuilder builder)
            {
                builder.UseEnvironment("Testing");

                // Override rate limit to 3 permits for testing
                builder.UseSetting("RateLimit:PermitLimit", "3");
                builder.UseSetting("RateLimit:WindowSeconds", "60");

                builder.ConfigureServices(services =>
                {
                    // Replace database with in-memory
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
                        options.UseInMemoryDatabase(_dbName));

                    // Replace cache with a no-op in-memory version
                    services.RemoveAll<StackExchange.Redis.IConnectionMultiplexer>();
                    services.RemoveAll<RedisCacheService>();
                    services.RemoveAll<ICacheService>();
                    services.AddSingleton<ICacheService>(new InMemoryCacheService());

                    services.RemoveAll<IHostedService>();
                });
            }
        }

        [Fact]
        public async Task ApiEvents_WithinRateLimit_ReturnsOk()
        {
            using RateLimitedFactory factory = new();
            HttpClient client = factory.CreateClient();

            HttpResponseMessage response = await client.GetAsync("/api/v1/events");

            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        }

        [Fact]
        public async Task ApiEvents_ExceedingRateLimit_Returns429()
        {
            using RateLimitedFactory factory = new();
            HttpClient client = factory.CreateClient();

            // Exhaust the 3-request limit
            for (int i = 0; i < 3; i++)
            {
                await client.GetAsync("/api/v1/events");
            }

            // The 4th request should be rate-limited
            HttpResponseMessage response = await client.GetAsync("/api/v1/events");

            Assert.Equal(HttpStatusCode.TooManyRequests, response.StatusCode);
        }

        [Fact]
        public async Task HealthEndpoint_IsNotRateLimited()
        {
            using RateLimitedFactory factory = new();
            HttpClient client = factory.CreateClient();

            // Exhaust the rate limit on /api/events
            for (int i = 0; i < 5; i++)
            {
                await client.GetAsync("/api/v1/events");
            }

            // Health endpoint should still respond OK
            HttpResponseMessage response = await client.GetAsync("/health");

            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        }

        private sealed class InMemoryCacheService : ICacheService
        {
            private readonly Dictionary<string, string> _store = [];

            public Task<string?> GetAsync(string key)
            {
                _store.TryGetValue(key, out string? value);
                return Task.FromResult(value);
            }

            public Task SetAsync(string key, string value, TimeSpan? ttl = null)
            {
                _store[key] = value;
                return Task.CompletedTask;
            }

            public Task InvalidateAsync(string key)
            {
                _store.Remove(key);
                return Task.CompletedTask;
            }
        }
    }
}
