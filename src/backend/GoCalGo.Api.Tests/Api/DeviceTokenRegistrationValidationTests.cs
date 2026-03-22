using System.Net;
using System.Net.Http.Json;
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
    /// Verifies acceptance criterion for story US-GCG-10:
    /// "Backend validates incoming token registrations to prevent abuse"
    ///
    /// Tests that:
    /// 1. Valid registrations succeed
    /// 2. Missing or empty token is rejected
    /// 3. Missing or empty platform is rejected
    /// 4. Token exceeding max length is rejected
    /// 5. Invalid platform values are rejected
    /// 6. Duplicate token registration performs upsert (not error)
    /// </summary>
    public class DeviceTokenRegistrationValidationTests
    {
        private sealed class TokenRegistrationFactory : WebApplicationFactory<Program>
        {
            private readonly string _dbName = "TokenValidation_" + Guid.NewGuid();

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

        private const string Endpoint = "/api/v1/device-tokens";

        [Fact]
        public async Task RegisterToken_ValidRequest_ReturnsSuccess()
        {
            using TokenRegistrationFactory factory = new();
            HttpClient client = factory.CreateClient();

            HttpResponseMessage response = await client.PostAsJsonAsync(Endpoint, new
            {
                token = "dMw6QDh-ORk:APA91bHqL5p-valid-fcm-token-format",
                platform = "android"
            });

            Assert.True(
                response.StatusCode is HttpStatusCode.OK or HttpStatusCode.Created,
                $"Expected 200 or 201 but got {(int)response.StatusCode}");
        }

        [Theory]
        [InlineData(null)]
        [InlineData("")]
        [InlineData("   ")]
        public async Task RegisterToken_MissingOrEmptyToken_ReturnsBadRequest(string? token)
        {
            using TokenRegistrationFactory factory = new();
            HttpClient client = factory.CreateClient();

            HttpResponseMessage response = await client.PostAsJsonAsync(Endpoint, new
            {
                token,
                platform = "android"
            });

            Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        }

        [Theory]
        [InlineData(null)]
        [InlineData("")]
        [InlineData("   ")]
        public async Task RegisterToken_MissingOrEmptyPlatform_ReturnsBadRequest(string? platform)
        {
            using TokenRegistrationFactory factory = new();
            HttpClient client = factory.CreateClient();

            HttpResponseMessage response = await client.PostAsJsonAsync(Endpoint, new
            {
                token = "valid-fcm-token-abc123",
                platform
            });

            Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        }

        [Fact]
        public async Task RegisterToken_TokenExceedsMaxLength_ReturnsBadRequest()
        {
            using TokenRegistrationFactory factory = new();
            HttpClient client = factory.CreateClient();

            string oversizedToken = new('x', 501);

            HttpResponseMessage response = await client.PostAsJsonAsync(Endpoint, new
            {
                token = oversizedToken,
                platform = "android"
            });

            Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        }

        [Theory]
        [InlineData("windows")]
        [InlineData("blackberry")]
        [InlineData("ANDROID")]
        [InlineData("IOS")]
        public async Task RegisterToken_InvalidPlatform_ReturnsBadRequest(string platform)
        {
            using TokenRegistrationFactory factory = new();
            HttpClient client = factory.CreateClient();

            HttpResponseMessage response = await client.PostAsJsonAsync(Endpoint, new
            {
                token = "valid-fcm-token-abc123",
                platform
            });

            Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        }

        [Theory]
        [InlineData("android")]
        [InlineData("ios")]
        public async Task RegisterToken_ValidPlatform_Succeeds(string platform)
        {
            using TokenRegistrationFactory factory = new();
            HttpClient client = factory.CreateClient();

            HttpResponseMessage response = await client.PostAsJsonAsync(Endpoint, new
            {
                token = $"valid-fcm-token-{platform}-test",
                platform
            });

            Assert.True(
                response.StatusCode is HttpStatusCode.OK or HttpStatusCode.Created,
                $"Expected 200 or 201 but got {(int)response.StatusCode}");
        }

        [Fact]
        public async Task RegisterToken_DuplicateToken_PerformsUpsert()
        {
            using TokenRegistrationFactory factory = new();
            HttpClient client = factory.CreateClient();

            object payload = new
            {
                token = "duplicate-test-token-xyz",
                platform = "android"
            };

            HttpResponseMessage first = await client.PostAsJsonAsync(Endpoint, payload);
            Assert.True(
                first.StatusCode is HttpStatusCode.OK or HttpStatusCode.Created,
                $"First registration failed with {(int)first.StatusCode}");

            HttpResponseMessage second = await client.PostAsJsonAsync(Endpoint, payload);
            Assert.True(
                second.StatusCode is HttpStatusCode.OK or HttpStatusCode.Created,
                $"Duplicate registration should upsert, not fail. Got {(int)second.StatusCode}");
        }

        [Fact]
        public async Task RegisterToken_EmptyBody_ReturnsBadRequest()
        {
            using TokenRegistrationFactory factory = new();
            HttpClient client = factory.CreateClient();

            HttpResponseMessage response = await client.PostAsync(Endpoint,
                new StringContent("{}", System.Text.Encoding.UTF8, "application/json"));

            Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        }

        [Fact]
        public async Task RegisterToken_NoBody_ReturnsBadRequest()
        {
            using TokenRegistrationFactory factory = new();
            HttpClient client = factory.CreateClient();

            HttpResponseMessage response = await client.PostAsync(Endpoint, null);

            Assert.True(
                response.StatusCode is HttpStatusCode.BadRequest or HttpStatusCode.UnsupportedMediaType,
                $"Expected 400 or 415 but got {(int)response.StatusCode}");
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
