namespace GoCalGo.Api.Tests.Configuration
{
    /// <summary>
    /// Verifies acceptance criterion for story US-GCG-2:
    /// ".NET API connects to local PostgreSQL and Redis"
    ///
    /// These tests validate that docker-compose.yml configures the API service
    /// with correct connection strings pointing to the PostgreSQL and Redis services.
    /// </summary>
    public class ApiConnectsToInfraTests
    {
        private readonly string _composeContent;

        public ApiConnectsToInfraTests()
        {
            string repoRoot = FindRepoRoot();
            string composePath = Path.Combine(repoRoot, "docker-compose.yml");
            Assert.True(File.Exists(composePath), "docker-compose.yml should exist at repo root");
            _composeContent = File.ReadAllText(composePath);
        }

        [Fact]
        public void ApiService_DependsOnPostgres()
        {
            // The API service must declare a dependency on postgres so it starts after the DB
            string apiSection = ExtractServiceSection("api");
            Assert.Contains("postgres", apiSection);
        }

        [Fact]
        public void ApiService_DependsOnRedis()
        {
            // The API service must declare a dependency on redis so it starts after the cache
            string apiSection = ExtractServiceSection("api");
            Assert.Contains("redis", apiSection);
        }

        [Fact]
        public void ApiService_PostgresConnectionString_ReferencesPostgresHost()
        {
            // Connection string must use the Docker service name "postgres" as the host
            Assert.Contains("Host=postgres", _composeContent);
        }

        [Fact]
        public void ApiService_PostgresConnectionString_UsesStandardPort()
        {
            // PostgreSQL connection should use the standard port 5432
            Assert.Contains("Port=5432", _composeContent);
        }

        [Fact]
        public void ApiService_PostgresConnectionString_IncludesCredentialVars()
        {
            // Connection string must reference env vars for database, user, and password
            string[] lines = _composeContent.Split('\n');
            string? connLine = Array.Find(lines,
                l => l.Contains("ConnectionStrings__PostgreSQL"));

            Assert.NotNull(connLine);
            Assert.Contains("${POSTGRES_DB}", connLine);
            Assert.Contains("${POSTGRES_USER}", connLine);
            Assert.Contains("${POSTGRES_PASSWORD}", connLine);
        }

        [Fact]
        public void ApiService_RedisConnectionString_ReferencesRedisHost()
        {
            // Redis connection string must use the Docker service name "redis" as the host
            string[] lines = _composeContent.Split('\n');
            string? connLine = Array.Find(lines,
                l => l.Contains("ConnectionStrings__Redis"));

            Assert.NotNull(connLine);
            Assert.Contains("redis:", connLine);
        }

        [Fact]
        public void ApiService_HasBothConnectionStrings()
        {
            // The API must have both PostgreSQL and Redis connection strings configured
            Assert.Contains("ConnectionStrings__PostgreSQL", _composeContent);
            Assert.Contains("ConnectionStrings__Redis", _composeContent);
        }

        private string ExtractServiceSection(string serviceName)
        {
            string[] lines = _composeContent.Split('\n');
            int startIndex = -1;

            for (int i = 0; i < lines.Length; i++)
            {
                string trimmed = lines[i].TrimEnd();
                if (trimmed == $"  {serviceName}:" || trimmed == $"  {serviceName}: ")
                {
                    startIndex = i;
                    continue;
                }

                // If we found the service and hit the next top-level service, stop
                if (startIndex >= 0 && i > startIndex && lines[i].Length > 0
                    && !char.IsWhiteSpace(lines[i][0]) && !lines[i].StartsWith('#'))
                {
                    return string.Join('\n', lines[startIndex..i]);
                }
            }

            if (startIndex >= 0)
            {
                return string.Join('\n', lines[startIndex..]);
            }

            Assert.Fail($"Service '{serviceName}' not found in docker-compose.yml");
            return string.Empty;
        }

        private static string FindRepoRoot()
        {
            string? dir = AppContext.BaseDirectory;
            while (dir != null)
            {
                if (File.Exists(Path.Combine(dir, ".env.example")))
                {
                    return dir;
                }

                dir = Path.GetDirectoryName(dir);
            }

            string fallback = Path.GetFullPath(
                Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", ".."));

            return File.Exists(Path.Combine(fallback, ".env.example"))
                ? fallback
                : throw new DirectoryNotFoundException("Could not find repository root");
        }
    }
}
