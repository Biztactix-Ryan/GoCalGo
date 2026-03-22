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
    /// Verifies acceptance criterion for story US-GCG-34:
    /// "Swagger/OpenAPI spec generated from code annotations"
    ///
    /// Tests that:
    /// 1. The OpenAPI document endpoint is reachable
    /// 2. The document contains paths for all versioned API endpoints
    /// 3. The document describes the API in valid OpenAPI format
    /// </summary>
    public class OpenApiSpecTests
    {
        private sealed class TestFactory : WebApplicationFactory<Program>
        {
            private readonly string _dbName = "OpenApiSpecTest_" + Guid.NewGuid();

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
        public async Task OpenApiEndpoint_ReturnsOk()
        {
            using TestFactory factory = new();
            HttpClient client = factory.CreateClient();

            HttpResponseMessage response = await client.GetAsync("/openapi/v1.json");

            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        }

        [Fact]
        public async Task OpenApiDocument_ContainsVersionedEventEndpoints()
        {
            using TestFactory factory = new();
            HttpClient client = factory.CreateClient();

            HttpResponseMessage response = await client.GetAsync("/openapi/v1.json");
            string content = await response.Content.ReadAsStringAsync();
            JsonDocument doc = JsonDocument.Parse(content);
            JsonElement root = doc.RootElement;

            // Verify document has paths section
            Assert.True(root.TryGetProperty("paths", out JsonElement paths),
                "OpenAPI document should contain a 'paths' section");

            // Verify all versioned API endpoints are documented
            Assert.True(paths.TryGetProperty("/api/v1/events", out _),
                "OpenAPI spec should include /api/v1/events");
            Assert.True(paths.TryGetProperty("/api/v1/events/active", out _),
                "OpenAPI spec should include /api/v1/events/active");
            Assert.True(paths.TryGetProperty("/api/v1/events/upcoming", out _),
                "OpenAPI spec should include /api/v1/events/upcoming");
        }

        [Fact]
        public async Task OpenApiDocument_ContainsHealthEndpoint()
        {
            using TestFactory factory = new();
            HttpClient client = factory.CreateClient();

            HttpResponseMessage response = await client.GetAsync("/openapi/v1.json");
            string content = await response.Content.ReadAsStringAsync();
            JsonDocument doc = JsonDocument.Parse(content);
            JsonElement paths = doc.RootElement.GetProperty("paths");

            Assert.True(paths.TryGetProperty("/health", out _),
                "OpenAPI spec should include /health endpoint");
        }

        [Fact]
        public async Task OpenApiDocument_HasValidInfoSection()
        {
            using TestFactory factory = new();
            HttpClient client = factory.CreateClient();

            HttpResponseMessage response = await client.GetAsync("/openapi/v1.json");
            string content = await response.Content.ReadAsStringAsync();
            JsonDocument doc = JsonDocument.Parse(content);
            JsonElement root = doc.RootElement;

            // Verify document has info section with title and version
            Assert.True(root.TryGetProperty("info", out JsonElement info),
                "OpenAPI document should contain an 'info' section");
            Assert.True(info.TryGetProperty("title", out _),
                "OpenAPI info should contain a 'title'");
            Assert.True(info.TryGetProperty("version", out _),
                "OpenAPI info should contain a 'version'");
        }

        [Fact]
        public async Task OpenApiDocument_EndpointsHaveGetOperations()
        {
            using TestFactory factory = new();
            HttpClient client = factory.CreateClient();

            HttpResponseMessage response = await client.GetAsync("/openapi/v1.json");
            string content = await response.Content.ReadAsStringAsync();
            JsonDocument doc = JsonDocument.Parse(content);
            JsonElement paths = doc.RootElement.GetProperty("paths");

            // Each endpoint should define a GET operation
            string[] expectedPaths = ["/api/v1/events", "/api/v1/events/active", "/api/v1/events/upcoming", "/health"];
            foreach (string path in expectedPaths)
            {
                JsonElement pathItem = paths.GetProperty(path);
                Assert.True(pathItem.TryGetProperty("get", out _),
                    $"Path '{path}' should have a GET operation defined");
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
