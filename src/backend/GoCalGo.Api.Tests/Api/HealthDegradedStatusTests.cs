using System.Net;
using System.Text.Json;
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
    /// Verifies acceptance criterion for story US-GCG-36:
    /// "Health endpoint reports degraded status when dependencies are down"
    /// </summary>
    public class HealthDegradedStatusTests
    {
        private sealed class HealthyFactory : WebApplicationFactory<Program>
        {
            private readonly string _dbName = "HealthDegraded_" + Guid.NewGuid();

            protected override void ConfigureWebHost(IWebHostBuilder builder)
            {
                builder.UseEnvironment("Testing");

                builder.ConfigureServices(services =>
                {
                    RemoveDbServices(services);
                    services.AddDbContext<GoCalGoDbContext>(options =>
                        options.UseInMemoryDatabase(_dbName));

                    services.RemoveAll<StackExchange.Redis.IConnectionMultiplexer>();
                    services.RemoveAll<RedisCacheService>();
                    services.RemoveAll<ICacheService>();
                    services.AddSingleton<ICacheService>(new InMemoryCacheService());

                    services.RemoveAll<IHostedService>();
                });
            }
        }

        private sealed class FailingDbFactory : WebApplicationFactory<Program>
        {
            protected override void ConfigureWebHost(IWebHostBuilder builder)
            {
                builder.UseEnvironment("Testing");

                builder.ConfigureServices(services =>
                {
                    RemoveDbServices(services);
                    services.AddDbContext<GoCalGoDbContext>(options =>
                        options.UseInMemoryDatabase("FailingDb_" + Guid.NewGuid()));

                    // Replace with a provider that throws on CanConnectAsync
                    services.AddScoped(sp =>
                    {
                        DbContextOptionsBuilder<GoCalGoDbContext> opts = new();
                        opts.UseNpgsql("Host=invalid_host_that_does_not_exist;Port=1;Database=fake;Timeout=1;Command Timeout=1");
                        return new GoCalGoDbContext(opts.Options);
                    });

                    services.RemoveAll<StackExchange.Redis.IConnectionMultiplexer>();
                    services.RemoveAll<RedisCacheService>();
                    services.RemoveAll<ICacheService>();
                    services.AddSingleton<ICacheService>(new InMemoryCacheService());

                    services.RemoveAll<IHostedService>();
                });
            }
        }

        private sealed class ScrapedDuckUnhealthyFactory : WebApplicationFactory<Program>
        {
            private readonly string _dbName = "ScrapedDuckDown_" + Guid.NewGuid();

            protected override void ConfigureWebHost(IWebHostBuilder builder)
            {
                builder.UseEnvironment("Testing");

                builder.ConfigureServices(services =>
                {
                    RemoveDbServices(services);
                    services.AddDbContext<GoCalGoDbContext>(options =>
                        options.UseInMemoryDatabase(_dbName));

                    services.RemoveAll<StackExchange.Redis.IConnectionMultiplexer>();
                    services.RemoveAll<RedisCacheService>();
                    services.RemoveAll<ICacheService>();
                    services.AddSingleton<ICacheService>(new InMemoryCacheService());

                    // Mark ScrapedDuck as unhealthy
                    services.RemoveAll<IngestionStatusTracker>();
                    services.AddSingleton(new IngestionStatusTracker
                    {
                        LastFetchSuccess = false,
                        LastFetchTime = DateTime.UtcNow.AddMinutes(-5),
                        LastFetchEventCount = 0
                    });

                    services.RemoveAll<IHostedService>();
                });
            }
        }

        [Fact]
        public async Task HealthEndpoint_ReportsHealthy_WhenAllDependenciesAreUp()
        {
            using HealthyFactory factory = new();
            HttpClient client = factory.CreateClient();

            HttpResponseMessage response = await client.GetAsync("/health");
            string content = await response.Content.ReadAsStringAsync();
            JsonDocument doc = JsonDocument.Parse(content);

            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            string? status = doc.RootElement.GetProperty("status").GetString();
            Assert.Equal("healthy", status);
        }

        [Fact]
        public async Task HealthEndpoint_ReturnsDegraded_WhenDatabaseIsDown()
        {
            using FailingDbFactory factory = new();
            HttpClient client = factory.CreateClient();

            HttpResponseMessage response = await client.GetAsync("/health");
            string content = await response.Content.ReadAsStringAsync();
            JsonDocument doc = JsonDocument.Parse(content);

            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            string? status = doc.RootElement.GetProperty("status").GetString();
            Assert.Equal("degraded", status);

            string? dbStatus = doc.RootElement
                .GetProperty("subsystems")
                .GetProperty("database")
                .GetProperty("status")
                .GetString();
            Assert.Equal("unhealthy", dbStatus);
        }

        [Fact]
        public async Task HealthEndpoint_ReturnsDegraded_WhenScrapedDuckIsUnhealthy()
        {
            using ScrapedDuckUnhealthyFactory factory = new();
            HttpClient client = factory.CreateClient();

            HttpResponseMessage response = await client.GetAsync("/health");
            string content = await response.Content.ReadAsStringAsync();
            JsonDocument doc = JsonDocument.Parse(content);

            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            string? status = doc.RootElement.GetProperty("status").GetString();
            Assert.Equal("degraded", status);

            string? scrapedDuckStatus = doc.RootElement
                .GetProperty("subsystems")
                .GetProperty("scrapedDuck")
                .GetProperty("status")
                .GetString();
            Assert.Equal("unhealthy", scrapedDuckStatus);
        }

        [Fact]
        public async Task HealthEndpoint_ReportsHealthy_WhenScrapedDuckStatusIsUnknown()
        {
            // Unknown (null) ScrapedDuck status should NOT cause degraded —
            // only explicit failure (false) should.
            using HealthyFactory factory = new();
            HttpClient client = factory.CreateClient();

            HttpResponseMessage response = await client.GetAsync("/health");
            string content = await response.Content.ReadAsStringAsync();
            JsonDocument doc = JsonDocument.Parse(content);

            string? status = doc.RootElement.GetProperty("status").GetString();
            Assert.Equal("healthy", status);

            string? scrapedDuckStatus = doc.RootElement
                .GetProperty("subsystems")
                .GetProperty("scrapedDuck")
                .GetProperty("status")
                .GetString();
            Assert.Equal("unknown", scrapedDuckStatus);
        }

        private static void RemoveDbServices(IServiceCollection services)
        {
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
