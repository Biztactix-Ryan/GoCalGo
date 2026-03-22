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
    public class FlagSyncEndpointTests
    {
        private sealed class FlagSyncFactory : WebApplicationFactory<Program>
        {
            private readonly string _dbName = "FlagSync_" + Guid.NewGuid();

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

        private const string Endpoint = "/api/v1/flags";

        [Fact]
        public async Task FlagEvent_ValidRequest_ReturnsCreated()
        {
            using FlagSyncFactory factory = new();
            HttpClient client = factory.CreateClient();

            HttpResponseMessage response = await client.PostAsJsonAsync(Endpoint, new
            {
                eventId = "community-day-2026-03",
                fcmToken = "valid-fcm-token-abc123",
                action = "flag"
            });

            Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        }

        [Fact]
        public async Task FlagEvent_DuplicateFlag_ReturnsOk()
        {
            using FlagSyncFactory factory = new();
            HttpClient client = factory.CreateClient();

            object payload = new
            {
                eventId = "community-day-2026-03",
                fcmToken = "valid-fcm-token-abc123",
                action = "flag"
            };

            await client.PostAsJsonAsync(Endpoint, payload);
            HttpResponseMessage second = await client.PostAsJsonAsync(Endpoint, payload);

            Assert.Equal(HttpStatusCode.OK, second.StatusCode);
        }

        [Fact]
        public async Task UnflagEvent_ExistingFlag_ReturnsOk()
        {
            using FlagSyncFactory factory = new();
            HttpClient client = factory.CreateClient();

            await client.PostAsJsonAsync(Endpoint, new
            {
                eventId = "community-day-2026-03",
                fcmToken = "valid-fcm-token-abc123",
                action = "flag"
            });

            HttpResponseMessage response = await client.PostAsJsonAsync(Endpoint, new
            {
                eventId = "community-day-2026-03",
                fcmToken = "valid-fcm-token-abc123",
                action = "unflag"
            });

            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        }

        [Fact]
        public async Task UnflagEvent_NonExistentFlag_ReturnsOk()
        {
            using FlagSyncFactory factory = new();
            HttpClient client = factory.CreateClient();

            HttpResponseMessage response = await client.PostAsJsonAsync(Endpoint, new
            {
                eventId = "community-day-2026-03",
                fcmToken = "valid-fcm-token-abc123",
                action = "unflag"
            });

            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        }

        [Theory]
        [InlineData(null, "valid-token", "flag")]
        [InlineData("", "valid-token", "flag")]
        [InlineData("   ", "valid-token", "flag")]
        [InlineData("event-1", null, "flag")]
        [InlineData("event-1", "", "flag")]
        [InlineData("event-1", "valid-token", null)]
        [InlineData("event-1", "valid-token", "")]
        public async Task FlagEvent_MissingRequiredFields_ReturnsBadRequest(
            string? eventId, string? fcmToken, string? action)
        {
            using FlagSyncFactory factory = new();
            HttpClient client = factory.CreateClient();

            HttpResponseMessage response = await client.PostAsJsonAsync(Endpoint, new
            {
                eventId,
                fcmToken,
                action
            });

            Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        }

        [Theory]
        [InlineData("bookmark")]
        [InlineData("toggle")]
        [InlineData("remove")]
        public async Task FlagEvent_InvalidAction_ReturnsBadRequest(string action)
        {
            using FlagSyncFactory factory = new();
            HttpClient client = factory.CreateClient();

            HttpResponseMessage response = await client.PostAsJsonAsync(Endpoint, new
            {
                eventId = "event-1",
                fcmToken = "valid-token",
                action
            });

            Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        }

        [Fact]
        public async Task FlagEvent_EventIdExceedsMaxLength_ReturnsBadRequest()
        {
            using FlagSyncFactory factory = new();
            HttpClient client = factory.CreateClient();

            string oversizedEventId = new('x', 201);

            HttpResponseMessage response = await client.PostAsJsonAsync(Endpoint, new
            {
                eventId = oversizedEventId,
                fcmToken = "valid-token",
                action = "flag"
            });

            Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        }

        [Fact]
        public async Task FlagEvent_FcmTokenExceedsMaxLength_ReturnsBadRequest()
        {
            using FlagSyncFactory factory = new();
            HttpClient client = factory.CreateClient();

            string oversizedToken = new('x', 501);

            HttpResponseMessage response = await client.PostAsJsonAsync(Endpoint, new
            {
                eventId = "event-1",
                fcmToken = oversizedToken,
                action = "flag"
            });

            Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        }

        [Fact]
        public async Task FlagEvent_EmptyBody_ReturnsBadRequest()
        {
            using FlagSyncFactory factory = new();
            HttpClient client = factory.CreateClient();

            HttpResponseMessage response = await client.PostAsync(Endpoint,
                new StringContent("{}", System.Text.Encoding.UTF8, "application/json"));

            Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        }

        [Fact]
        public async Task FlagEvent_NoBody_ReturnsBadRequest()
        {
            using FlagSyncFactory factory = new();
            HttpClient client = factory.CreateClient();

            HttpResponseMessage response = await client.PostAsync(Endpoint, null);

            Assert.True(
                response.StatusCode is HttpStatusCode.BadRequest or HttpStatusCode.UnsupportedMediaType,
                $"Expected 400 or 415 but got {(int)response.StatusCode}");
        }

        [Fact]
        public async Task UnflagEvent_RemovesFlagFromDatabase()
        {
            using FlagSyncFactory factory = new();
            HttpClient client = factory.CreateClient();

            await client.PostAsJsonAsync(Endpoint, new
            {
                eventId = "community-day-2026-03",
                fcmToken = "token-for-removal-test",
                action = "flag"
            });

            await client.PostAsJsonAsync(Endpoint, new
            {
                eventId = "community-day-2026-03",
                fcmToken = "token-for-removal-test",
                action = "unflag"
            });

            // Re-flag should return Created (not OK), proving the flag was actually removed
            HttpResponseMessage reflag = await client.PostAsJsonAsync(Endpoint, new
            {
                eventId = "community-day-2026-03",
                fcmToken = "token-for-removal-test",
                action = "flag"
            });

            Assert.Equal(HttpStatusCode.Created, reflag.StatusCode);
        }

        [Fact]
        public async Task FlagEvent_DifferentTokensSameEvent_BothSucceed()
        {
            using FlagSyncFactory factory = new();
            HttpClient client = factory.CreateClient();

            HttpResponseMessage first = await client.PostAsJsonAsync(Endpoint, new
            {
                eventId = "community-day-2026-03",
                fcmToken = "device-token-1",
                action = "flag"
            });

            HttpResponseMessage second = await client.PostAsJsonAsync(Endpoint, new
            {
                eventId = "community-day-2026-03",
                fcmToken = "device-token-2",
                action = "flag"
            });

            Assert.Equal(HttpStatusCode.Created, first.StatusCode);
            Assert.Equal(HttpStatusCode.Created, second.StatusCode);
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
