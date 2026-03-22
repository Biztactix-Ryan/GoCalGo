using System.Text.Json;

namespace GoCalGo.Api.Services
{
    public interface ICacheService
    {
        Task<string?> GetAsync(string key);
        Task SetAsync(string key, string value, TimeSpan? ttl = null);
        Task InvalidateAsync(string key);

        async Task<T?> GetAsync<T>(string key)
        {
            string? json = await GetAsync(key);
            return json is null ? default : JsonSerializer.Deserialize<T>(json);
        }

        async Task SetAsync<T>(string key, T value, TimeSpan? ttl = null)
        {
            string json = JsonSerializer.Serialize(value);
            await SetAsync(key, json, ttl);
        }

        /// <summary>
        /// Cache-aside pattern: check cache first, on miss call the factory,
        /// populate cache with the result, and return it.
        /// </summary>
        async Task<T?> GetOrSetAsync<T>(string key, Func<Task<T?>> factory, TimeSpan? ttl = null)
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
    }
}
