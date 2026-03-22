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
    /// Verifies acceptance criterion for story US-GCG-5:
    /// "Health check endpoint exists for monitoring"
    ///
    /// Tests that:
    /// 1. GET /health returns 200 OK
    /// 2. Response contains monitoring-relevant fields (status, subsystems)
    /// 3. Endpoint returns JSON content type for automated monitoring tools
    /// </summary>
    public class HealthCheckEndpointTests
    {
        private sealed class TestFactory : WebApplicationFactory<Program>
        {
            private readonly string _dbName = "HealthCheckTest_" + Guid.NewGuid();

            protected override void ConfigureWebHost(IWebHostBuilder builder)
            {
                builder.UseEnvironment("Testing");

                builder.ConfigureServices(services =>
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

        [Fact]
        public async Task HealthEndpoint_Exists_ReturnsOk()
        {
            using TestFactory factory = new();
            HttpClient client = factory.CreateClient();

            HttpResponseMessage response = await client.GetAsync("/health");

            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        }

        [Fact]
        public async Task HealthEndpoint_ReturnsJson_ForMonitoringTools()
        {
            using TestFactory factory = new();
            HttpClient client = factory.CreateClient();

            HttpResponseMessage response = await client.GetAsync("/health");

            Assert.Equal("application/json", response.Content.Headers.ContentType?.MediaType);
        }

        [Fact]
        public async Task HealthEndpoint_IncludesStatusField_ForMonitoringAlerts()
        {
            using TestFactory factory = new();
            HttpClient client = factory.CreateClient();

            HttpResponseMessage response = await client.GetAsync("/health");
            string content = await response.Content.ReadAsStringAsync();
            JsonDocument doc = JsonDocument.Parse(content);

            Assert.True(doc.RootElement.TryGetProperty("status", out JsonElement status),
                "Health response must include a 'status' field for monitoring tools to evaluate");
            Assert.False(string.IsNullOrEmpty(status.GetString()),
                "Status field must not be empty");
        }

        [Fact]
        public async Task HealthEndpoint_IncludesSubsystems_ForDetailedMonitoring()
        {
            using TestFactory factory = new();
            HttpClient client = factory.CreateClient();

            HttpResponseMessage response = await client.GetAsync("/health");
            string content = await response.Content.ReadAsStringAsync();
            JsonDocument doc = JsonDocument.Parse(content);

            Assert.True(doc.RootElement.TryGetProperty("subsystems", out JsonElement subsystems),
                "Health response must include 'subsystems' for granular monitoring");
            Assert.True(subsystems.TryGetProperty("database", out _),
                "Subsystems must include database status");
            Assert.True(subsystems.TryGetProperty("redis", out _),
                "Subsystems must include redis status");
            Assert.True(subsystems.TryGetProperty("scrapedDuck", out _),
                "Subsystems must include scrapedDuck status");
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
