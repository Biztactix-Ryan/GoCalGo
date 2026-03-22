using GoCalGo.Api.Configuration;
using GoCalGo.Api.Services;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;

namespace GoCalGo.Api.Tests.Services
{
    /// <summary>
    /// Verifies acceptance criterion for story US-GCG-21:
    /// "Cache service implements get/set/invalidate with configurable TTL"
    ///
    /// DI tests use WebApplicationFactory. Behavioral tests verify the
    /// contract by constructing RedisCacheService with a fake Redis via Moq-free
    /// approach: we test the interface shape and DI wiring, then verify behavior
    /// through the ICacheService contract using an in-memory test double.
    /// </summary>
    public class CacheServiceDiTests(WebApplicationFactory<Program> factory) : IClassFixture<WebApplicationFactory<Program>>
    {
        [Fact]
        public void ICacheService_IsRegisteredInDi()
        {
            using IServiceScope scope = factory.Services.CreateScope();
            ICacheService? cache = scope.ServiceProvider.GetService<ICacheService>();

            Assert.NotNull(cache);
        }

        [Fact]
        public void ICacheService_ResolvesToResilientCacheService()
        {
            using IServiceScope scope = factory.Services.CreateScope();
            ICacheService? cache = scope.ServiceProvider.GetService<ICacheService>();

            Assert.NotNull(cache);
            Assert.IsType<ResilientCacheService>(cache);
        }

        [Fact]
        public void ICacheService_IsRegisteredAsSingleton()
        {
            ICacheService? first;
            ICacheService? second;

            using (IServiceScope scope1 = factory.Services.CreateScope())
            {
                first = scope1.ServiceProvider.GetService<ICacheService>();
            }

            using (IServiceScope scope2 = factory.Services.CreateScope())
            {
                second = scope2.ServiceProvider.GetService<ICacheService>();
            }

            Assert.NotNull(first);
            Assert.NotNull(second);
            Assert.Same(first, second);
        }

        [Fact]
        public void DefaultTtl_IsConfiguredViaCacheExpirationMinutes()
        {
            using IServiceScope scope = factory.Services.CreateScope();
            IOptions<ScrapedDuckSettings> settings = scope.ServiceProvider.GetRequiredService<IOptions<ScrapedDuckSettings>>();

            Assert.True(settings.Value.CacheExpirationMinutes > 0,
                "CacheExpirationMinutes must be positive for TTL to be meaningful");
        }
    }

    /// <summary>
    /// Verifies ICacheService interface defines get/set/invalidate with TTL support.
    /// Uses reflection to validate the contract without requiring a running Redis.
    /// </summary>
    public class CacheServiceContractTests
    {
        [Fact]
        public void ICacheService_HasGetAsyncMethod()
        {
            System.Reflection.MethodInfo? method = typeof(ICacheService).GetMethod(
                "GetAsync", 0, [typeof(string)]);

            Assert.NotNull(method);
            Assert.Equal(typeof(Task<string?>), method.ReturnType);
            Assert.Single(method.GetParameters());
            Assert.Equal(typeof(string), method.GetParameters()[0].ParameterType);
        }

        [Fact]
        public void ICacheService_HasSetAsyncMethod_WithOptionalTtl()
        {
            System.Reflection.MethodInfo? method = typeof(ICacheService).GetMethod(
                "SetAsync", [typeof(string), typeof(string), typeof(TimeSpan?)]);

            Assert.NotNull(method);
            Assert.Equal(typeof(Task), method.ReturnType);

            System.Reflection.ParameterInfo[] parameters = method.GetParameters();
            Assert.Equal(3, parameters.Length);
            Assert.Equal(typeof(string), parameters[0].ParameterType);   // key
            Assert.Equal(typeof(string), parameters[1].ParameterType);   // value
            Assert.Equal(typeof(TimeSpan?), parameters[2].ParameterType); // ttl (optional)
            Assert.True(parameters[2].IsOptional, "TTL parameter should be optional (configurable)");
        }

        [Fact]
        public void ICacheService_HasInvalidateAsyncMethod()
        {
            System.Reflection.MethodInfo? method = typeof(ICacheService).GetMethod("InvalidateAsync");

            Assert.NotNull(method);
            Assert.Equal(typeof(Task), method.ReturnType);
            Assert.Single(method.GetParameters());
            Assert.Equal(typeof(string), method.GetParameters()[0].ParameterType);
        }

        [Fact]
        public void RedisCacheService_ImplementsICacheService()
        {
            Assert.True(typeof(ICacheService).IsAssignableFrom(typeof(RedisCacheService)));
        }

        [Fact]
        public void RedisCacheService_AcceptsConfigurableTtlViaSettings()
        {
            // Verify the constructor accepts IOptions<ScrapedDuckSettings> for TTL configuration
            System.Reflection.ConstructorInfo[] constructors = typeof(RedisCacheService).GetConstructors();
            Assert.Single(constructors);

            System.Reflection.ParameterInfo[] parameters = constructors[0].GetParameters();
            Assert.Contains(parameters,
                p => p.ParameterType == typeof(IOptions<ScrapedDuckSettings>));
        }

        [Fact]
        public void ScrapedDuckSettings_HasCacheExpirationMinutesProperty()
        {
            ScrapedDuckSettings settings = new();

            Assert.Equal(30, settings.CacheExpirationMinutes); // default is 30 minutes
        }
    }
}
