using System.Text.Json;
using GoCalGo.Api.Configuration;
using Microsoft.Extensions.Options;
using StackExchange.Redis;

namespace GoCalGo.Api.Services
{
    public class RedisCacheService(IConnectionMultiplexer redis, IOptions<ScrapedDuckSettings> settings) : ICacheService
    {
        private readonly IDatabase _db = redis.GetDatabase();
        private readonly TimeSpan _defaultTtl = TimeSpan.FromMinutes(settings.Value.CacheExpirationMinutes);
        private readonly Dictionary<string, TimeSpan> _keyTtls = settings.Value.CacheTtlOverrides;

        private static readonly JsonSerializerOptions JsonOptions = new()
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        };

        public async Task<string?> GetAsync(string key)
        {
            RedisValue value = await _db.StringGetAsync(key);
            return value.IsNullOrEmpty ? null : value.ToString();
        }

        public async Task SetAsync(string key, string value, TimeSpan? ttl = null)
        {
            await _db.StringSetAsync(key, value, ttl ?? ResolveTtl(key));
        }

        public async Task InvalidateAsync(string key)
        {
            await _db.KeyDeleteAsync(key);
        }

        public async Task<T?> GetAsync<T>(string key)
        {
            string? json = await GetAsync(key);
            return json is null ? default : JsonSerializer.Deserialize<T>(json, JsonOptions);
        }

        public async Task SetAsync<T>(string key, T value, TimeSpan? ttl = null)
        {
            string json = JsonSerializer.Serialize(value, JsonOptions);
            await SetAsync(key, json, ttl);
        }

        public async Task<T?> GetOrSetAsync<T>(string key, Func<Task<T?>> factory, TimeSpan? ttl = null)
        {
            T? cached = await GetAsync<T>(key);
            if (cached is not null)
            {
                return cached;
            }

            T? result = await factory();
            if (result is null)
            {
                return default;
            }

            await SetAsync(key, result, ttl);
            return result;
        }

        private TimeSpan ResolveTtl(string key)
        {
            string ns = key.Contains(':') ? key[..key.IndexOf(':')] : key;

            return _keyTtls.TryGetValue(key, out TimeSpan exact) ? exact
                : _keyTtls.TryGetValue(ns, out TimeSpan nsTtl) ? nsTtl
                : _defaultTtl;
        }
    }
}
