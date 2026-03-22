using GoCalGo.Api.Configuration;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;

namespace GoCalGo.Api.Tests.Configuration
{
    public class IOptionsPatternTests(WebApplicationFactory<Program> factory) : IClassFixture<WebApplicationFactory<Program>>
    {
        [Fact]
        public void DatabaseSettings_IsBoundViaIOptions()
        {
            using IServiceScope scope = factory.Services.CreateScope();
            IOptions<DatabaseSettings>? options = scope.ServiceProvider.GetService<IOptions<DatabaseSettings>>();

            Assert.NotNull(options);
            Assert.NotNull(options.Value);
            Assert.Equal("localhost", options.Value.Host);
            Assert.Equal(5432, options.Value.Port);
            Assert.False(string.IsNullOrEmpty(options.Value.Database));
            Assert.False(string.IsNullOrEmpty(options.Value.Username));
        }

        [Fact]
        public void DatabaseSettings_GeneratesConnectionString()
        {
            using IServiceScope scope = factory.Services.CreateScope();
            IOptions<DatabaseSettings>? options = scope.ServiceProvider.GetService<IOptions<DatabaseSettings>>();

            Assert.NotNull(options);
            string connStr = options.Value.ConnectionString;
            Assert.Contains("Host=", connStr);
            Assert.Contains("Port=", connStr);
            Assert.Contains("Database=", connStr);
            Assert.Contains("Username=", connStr);
        }

        [Fact]
        public void RedisSettings_IsBoundViaIOptions()
        {
            using IServiceScope scope = factory.Services.CreateScope();
            IOptions<RedisSettings>? options = scope.ServiceProvider.GetService<IOptions<RedisSettings>>();

            Assert.NotNull(options);
            Assert.NotNull(options.Value);
            Assert.Equal("localhost", options.Value.Host);
            Assert.Equal(6379, options.Value.Port);
        }

        [Fact]
        public void RedisSettings_GeneratesConnectionString()
        {
            using IServiceScope scope = factory.Services.CreateScope();
            IOptions<RedisSettings>? options = scope.ServiceProvider.GetService<IOptions<RedisSettings>>();

            Assert.NotNull(options);
            Assert.Equal("localhost:6379", options.Value.ConnectionString);
        }

        [Fact]
        public void ScrapedDuckSettings_IsBoundViaIOptions()
        {
            using IServiceScope scope = factory.Services.CreateScope();
            IOptions<ScrapedDuckSettings>? options = scope.ServiceProvider.GetService<IOptions<ScrapedDuckSettings>>();

            Assert.NotNull(options);
            Assert.NotNull(options.Value);
            Assert.Equal("https://pokemon-go-api.github.io/pokemon-go-api", options.Value.BaseUrl);
            Assert.True(options.Value.CacheExpirationMinutes > 0);
        }

        [Fact]
        public void FirebaseSettings_IsBoundViaIOptions()
        {
            using IServiceScope scope = factory.Services.CreateScope();
            IOptions<FirebaseSettings>? options = scope.ServiceProvider.GetService<IOptions<FirebaseSettings>>();

            Assert.NotNull(options);
            Assert.NotNull(options.Value);
        }

        [Fact]
        public void DatabaseSettings_SupportsIOptionsSnapshot()
        {
            using IServiceScope scope = factory.Services.CreateScope();
            IOptionsSnapshot<DatabaseSettings>? snapshot = scope.ServiceProvider.GetService<IOptionsSnapshot<DatabaseSettings>>();

            Assert.NotNull(snapshot);
            Assert.NotNull(snapshot.Value);
        }

        [Fact]
        public void RedisSettings_SupportsIOptionsSnapshot()
        {
            using IServiceScope scope = factory.Services.CreateScope();
            IOptionsSnapshot<RedisSettings>? snapshot = scope.ServiceProvider.GetService<IOptionsSnapshot<RedisSettings>>();

            Assert.NotNull(snapshot);
            Assert.NotNull(snapshot.Value);
        }

        [Fact]
        public void ScrapedDuckSettings_SupportsIOptionsSnapshot()
        {
            using IServiceScope scope = factory.Services.CreateScope();
            IOptionsSnapshot<ScrapedDuckSettings>? snapshot = scope.ServiceProvider.GetService<IOptionsSnapshot<ScrapedDuckSettings>>();

            Assert.NotNull(snapshot);
            Assert.NotNull(snapshot.Value);
        }

        [Fact]
        public void FirebaseSettings_SupportsIOptionsSnapshot()
        {
            using IServiceScope scope = factory.Services.CreateScope();
            IOptionsSnapshot<FirebaseSettings>? snapshot = scope.ServiceProvider.GetService<IOptionsSnapshot<FirebaseSettings>>();

            Assert.NotNull(snapshot);
            Assert.NotNull(snapshot.Value);
        }
    }
}
