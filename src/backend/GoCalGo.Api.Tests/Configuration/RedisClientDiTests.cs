using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;
using StackExchange.Redis;

namespace GoCalGo.Api.Tests.Configuration
{
    /// <summary>
    /// Verifies acceptance criterion for story US-GCG-21:
    /// "Redis client configured and registered in DI"
    ///
    /// These tests validate that IConnectionMultiplexer is registered
    /// in the DI container and resolves to a usable Redis client.
    /// </summary>
    public class RedisClientDiTests(WebApplicationFactory<Program> factory) : IClassFixture<WebApplicationFactory<Program>>
    {
        [Fact]
        public void IConnectionMultiplexer_IsRegisteredInDi()
        {
            using IServiceScope scope = factory.Services.CreateScope();
            IConnectionMultiplexer? multiplexer = scope.ServiceProvider.GetService<IConnectionMultiplexer>();

            Assert.NotNull(multiplexer);
        }

        [Fact]
        public void IConnectionMultiplexer_IsRegisteredAsSingleton()
        {
            // Resolving from two different scopes should return the same instance
            IConnectionMultiplexer? first;
            IConnectionMultiplexer? second;

            using (IServiceScope scope1 = factory.Services.CreateScope())
            {
                first = scope1.ServiceProvider.GetService<IConnectionMultiplexer>();
            }

            using (IServiceScope scope2 = factory.Services.CreateScope())
            {
                second = scope2.ServiceProvider.GetService<IConnectionMultiplexer>();
            }

            Assert.NotNull(first);
            Assert.NotNull(second);
            Assert.Same(first, second);
        }

        [Fact]
        public void IConnectionMultiplexer_ConfigurationIncludesHost()
        {
            using IServiceScope scope = factory.Services.CreateScope();
            IConnectionMultiplexer? multiplexer = scope.ServiceProvider.GetService<IConnectionMultiplexer>();

            Assert.NotNull(multiplexer);
            Assert.Contains("localhost", multiplexer.Configuration);
        }
    }
}
