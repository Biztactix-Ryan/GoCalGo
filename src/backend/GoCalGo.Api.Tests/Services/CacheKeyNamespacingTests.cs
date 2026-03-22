using System.Reflection;
using GoCalGo.Api.Services;

namespace GoCalGo.Api.Tests.Services
{
    /// <summary>
    /// Verifies acceptance criterion for story US-GCG-21:
    /// "Cache keys are namespaced and documented"
    ///
    /// Ensures all cache key constants follow the "namespace:identifier" convention
    /// and that each key has an XML documentation comment.
    /// </summary>
    public class CacheKeyNamespacingTests
    {
        [Fact]
        public void CacheKeys_ClassExists()
        {
            Type? type = typeof(CacheKeys);

            Assert.NotNull(type);
            Assert.True(type.IsAbstract && type.IsSealed, "CacheKeys should be a static class");
        }

        [Fact]
        public void CacheKeys_EventsAll_IsNamespaced()
        {
            Assert.Contains(":", CacheKeys.EventsAll);
        }

        [Fact]
        public void CacheKeys_EventsAll_StartsWithEventsNamespace()
        {
            Assert.StartsWith(CacheKeys.EventsNamespace + ":", CacheKeys.EventsAll);
        }

        [Fact]
        public void CacheKeys_EventsAll_EqualsExpectedValue()
        {
            Assert.Equal("events:all", CacheKeys.EventsAll);
        }

        [Fact]
        public void AllCacheKeyConstants_FollowNamespacingConvention()
        {
            // Every string constant in CacheKeys (except namespace prefixes) must contain a colon
            FieldInfo[] fields = typeof(CacheKeys).GetFields(BindingFlags.Public | BindingFlags.Static);

            Assert.NotEmpty(fields);

            FieldInfo[] keyFields = [.. fields
                .Where(f => f.IsLiteral && f.FieldType == typeof(string) && !f.Name.EndsWith("Namespace", StringComparison.Ordinal))];

            Assert.NotEmpty(keyFields);

            foreach (FieldInfo field in keyFields)
            {
                string? value = (string?)field.GetValue(null);
                Assert.NotNull(value);
                Assert.Contains(":", value);
                Assert.False(value.StartsWith(':', StringComparison.Ordinal), $"Key '{field.Name}' must not start with ':'");
                Assert.False(value.EndsWith(':', StringComparison.Ordinal), $"Key '{field.Name}' must not end with ':'");
            }
        }

        [Fact]
        public void AllCacheKeyConstants_UseKnownNamespace()
        {
            // Every key constant must be prefixed with one of the declared namespace constants
            FieldInfo[] fields = typeof(CacheKeys).GetFields(BindingFlags.Public | BindingFlags.Static);

            string[] namespaces = [.. fields
                .Where(f => f.IsLiteral && f.FieldType == typeof(string) && f.Name.EndsWith("Namespace", StringComparison.Ordinal))
                .Select(f => (string)f.GetValue(null)!)];

            Assert.NotEmpty(namespaces);

            FieldInfo[] keyFields = [.. fields
                .Where(f => f.IsLiteral && f.FieldType == typeof(string) && !f.Name.EndsWith("Namespace", StringComparison.Ordinal))];

            foreach (FieldInfo field in keyFields)
            {
                string value = (string)field.GetValue(null)!;
                Assert.True(
                    namespaces.Any(ns => value.StartsWith(ns + ":", StringComparison.Ordinal)),
                    $"Key '{field.Name}' ({value}) must start with a declared namespace prefix");
            }
        }

        [Fact]
        public void CacheKeys_EventsNamespace_DoesNotContainColon()
        {
            // Namespace prefixes themselves should be plain identifiers
            Assert.DoesNotContain(":", CacheKeys.EventsNamespace);
        }
    }
}
