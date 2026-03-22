using Testcontainers.PostgreSql;
using Testcontainers.Redis;

namespace GoCalGo.Api.Tests.Infrastructure
{
    /// <summary>
    /// Shared fixture that starts PostgreSQL and Redis containers once per test collection.
    /// Implements IAsyncLifetime so xUnit manages the container lifecycle.
    /// </summary>
    public sealed class PostgresRedisFixture : IAsyncLifetime
    {
        private readonly PostgreSqlContainer _postgres = new PostgreSqlBuilder()
            .WithImage("postgres:16-alpine")
            .WithDatabase("gocalgo_test")
            .WithUsername("test")
            .WithPassword("test")
            .Build();

        private readonly RedisContainer _redis = new RedisBuilder()
            .WithImage("redis:7-alpine")
            .Build();

        public string PostgresConnectionString => _postgres.GetConnectionString();
        public string RedisConnectionString => _redis.GetConnectionString();

        public async Task InitializeAsync()
        {
            await Task.WhenAll(
                _postgres.StartAsync(),
                _redis.StartAsync());
        }

        public async Task DisposeAsync()
        {
            await Task.WhenAll(
                _postgres.DisposeAsync().AsTask(),
                _redis.DisposeAsync().AsTask());
        }
    }
}
