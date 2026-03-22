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
    /// "API response models documented with examples"
    ///
    /// Tests that the OpenAPI schema definitions include example values
    /// for all key response models (EventDto, BuffDto, etc.).
    /// </summary>
    public class ResponseModelExamplesTests
    {
        private sealed class TestFactory : WebApplicationFactory<Program>
        {
            private readonly string _dbName = "ResponseModelExamplesTest_" + Guid.NewGuid();

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

        private static async Task<JsonElement> GetOpenApiSchemas()
        {
            using TestFactory factory = new();
            HttpClient client = factory.CreateClient();
            HttpResponseMessage response = await client.GetAsync("/openapi/v1.json");
            Assert.Equal(HttpStatusCode.OK, response.StatusCode);

            string content = await response.Content.ReadAsStringAsync();
            JsonDocument doc = JsonDocument.Parse(content);
            return doc.RootElement.GetProperty("components").GetProperty("schemas");
        }

        [Theory]
        [InlineData("EventDto")]
        [InlineData("ActiveEventDto")]
        [InlineData("BuffDto")]
        [InlineData("PokemonDto")]
        [InlineData("EventsResponse")]
        [InlineData("ActiveEventsResponse")]
        public async Task ResponseModel_HasExampleInOpenApiSchema(string schemaName)
        {
            JsonElement schemas = await GetOpenApiSchemas();

            Assert.True(schemas.TryGetProperty(schemaName, out JsonElement schema),
                $"OpenAPI spec should contain a schema for '{schemaName}'");
            Assert.True(schema.TryGetProperty("example", out _),
                $"Schema '{schemaName}' should include an 'example' value");
        }

        [Fact]
        public async Task EventDtoExample_ContainsRealisticFields()
        {
            JsonElement schemas = await GetOpenApiSchemas();
            JsonElement example = schemas.GetProperty("EventDto").GetProperty("example");

            Assert.True(example.TryGetProperty("id", out JsonElement id));
            Assert.False(string.IsNullOrEmpty(id.GetString()));

            Assert.True(example.TryGetProperty("name", out JsonElement name));
            Assert.False(string.IsNullOrEmpty(name.GetString()));

            Assert.True(example.TryGetProperty("eventType", out JsonElement eventType));
            Assert.False(string.IsNullOrEmpty(eventType.GetString()));

            Assert.True(example.TryGetProperty("buffs", out JsonElement buffs));
            Assert.Equal(JsonValueKind.Array, buffs.ValueKind);
            Assert.True(buffs.GetArrayLength() > 0, "Example should include at least one buff");

            Assert.True(example.TryGetProperty("featuredPokemon", out JsonElement pokemon));
            Assert.Equal(JsonValueKind.Array, pokemon.ValueKind);
            Assert.True(pokemon.GetArrayLength() > 0, "Example should include at least one pokemon");
        }

        [Fact]
        public async Task ActiveEventDtoExample_IncludesTimeRemaining()
        {
            JsonElement schemas = await GetOpenApiSchemas();
            JsonElement example = schemas.GetProperty("ActiveEventDto").GetProperty("example");

            Assert.True(example.TryGetProperty("timeRemainingSeconds", out JsonElement timeRemaining));
            Assert.True(timeRemaining.GetDouble() > 0,
                "timeRemainingSeconds example should be a positive number");
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
