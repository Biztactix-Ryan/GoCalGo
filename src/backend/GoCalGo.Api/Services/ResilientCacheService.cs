namespace GoCalGo.Api.Services
{
    /// <summary>
    /// Decorator around ICacheService that catches Redis failures and degrades gracefully.
    /// On failure: GetAsync returns null (triggering DB fallback via cache-aside),
    /// SetAsync and InvalidateAsync complete silently.
    /// </summary>
    public class ResilientCacheService(ICacheService inner, ILogger<ResilientCacheService> logger) : ICacheService
    {
        public async Task<string?> GetAsync(string key)
        {
            try
            {
                return await inner.GetAsync(key);
            }
            catch (Exception ex)
            {
                logger.LogWarning(ex, "Redis GetAsync failed for key {CacheKey}, falling back to database", key);
                return null;
            }
        }

        public async Task SetAsync(string key, string value, TimeSpan? ttl = null)
        {
            try
            {
                await inner.SetAsync(key, value, ttl);
            }
            catch (Exception ex)
            {
                logger.LogWarning(ex, "Redis SetAsync failed for key {CacheKey}, skipping cache write", key);
            }
        }

        public async Task InvalidateAsync(string key)
        {
            try
            {
                await inner.InvalidateAsync(key);
            }
            catch (Exception ex)
            {
                logger.LogWarning(ex, "Redis InvalidateAsync failed for key {CacheKey}, entry will expire via TTL", key);
            }
        }
    }
}
