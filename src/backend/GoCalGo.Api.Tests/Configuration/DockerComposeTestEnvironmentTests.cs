namespace GoCalGo.Api.Tests.Configuration
{
    /// <summary>
    /// Verifies acceptance criterion for story US-GCG-35:
    /// "Test environment spins up via Docker Compose"
    ///
    /// Validates that docker-compose.yml defines all services with healthchecks,
    /// correct dependency ordering, and proper configuration so that
    /// `docker compose up` produces a ready-to-test environment.
    /// </summary>
    public class DockerComposeTestEnvironmentTests
    {
        private readonly string _composeContent;
        private readonly string[] _composeLines;

        public DockerComposeTestEnvironmentTests()
        {
            string repoRoot = FindRepoRoot();
            string composePath = Path.Combine(repoRoot, "docker-compose.yml");
            Assert.True(File.Exists(composePath), "docker-compose.yml should exist at repo root");
            _composeContent = File.ReadAllText(composePath);
            _composeLines = _composeContent.Split('\n');
        }

        [Theory]
        [InlineData("postgres")]
        [InlineData("redis")]
        [InlineData("api")]
        public void AllServices_AreDefined(string serviceName)
        {
            string section = ExtractServiceSection(serviceName);
            Assert.False(string.IsNullOrEmpty(section),
                $"Service '{serviceName}' should be defined in docker-compose.yml");
        }

        [Theory]
        [InlineData("postgres")]
        [InlineData("redis")]
        public void InfraServices_HaveHealthchecks(string serviceName)
        {
            string section = ExtractServiceSection(serviceName);
            Assert.Contains("healthcheck:", section);
            Assert.Contains("test:", section);
            Assert.Contains("interval:", section);
            Assert.Contains("timeout:", section);
            Assert.Contains("retries:", section);
        }

        [Fact]
        public void PostgresHealthcheck_UsesPgIsReady()
        {
            string section = ExtractServiceSection("postgres");
            Assert.Contains("pg_isready", section);
        }

        [Fact]
        public void RedisHealthcheck_UsesRedisCli()
        {
            string section = ExtractServiceSection("redis");
            Assert.Contains("redis-cli", section);
        }

        [Fact]
        public void ApiService_WaitsForHealthyPostgres()
        {
            string section = ExtractServiceSection("api");
            // Must use condition: service_healthy, not just depends_on
            Assert.Contains("postgres:", section);
            Assert.Contains("condition: service_healthy", section);
        }

        [Fact]
        public void ApiService_WaitsForHealthyRedis()
        {
            string section = ExtractServiceSection("api");
            Assert.Contains("redis:", section);
            Assert.Contains("condition: service_healthy", section);
        }

        [Fact]
        public void ApiService_HasBuildContext()
        {
            string section = ExtractServiceSection("api");
            Assert.Contains("build:", section);
            Assert.Contains("dockerfile:", section);
        }

        [Fact]
        public void ApiService_ExposesPort5000()
        {
            string section = ExtractServiceSection("api");
            Assert.Contains("5000:", section);
        }

        [Fact]
        public void PostgresService_ExposesPort5432()
        {
            string section = ExtractServiceSection("postgres");
            Assert.Contains("5432", section);
        }

        [Fact]
        public void RedisService_ExposesPort6379()
        {
            string section = ExtractServiceSection("redis");
            Assert.Contains("6379", section);
        }

        [Theory]
        [InlineData("postgres")]
        [InlineData("redis")]
        public void InfraServices_HavePersistentVolumes(string serviceName)
        {
            string section = ExtractServiceSection(serviceName);
            Assert.Contains("volumes:", section);
        }

        [Fact]
        public void ComposeFile_DefinesVolumeSection()
        {
            // Top-level volumes section required for named volumes
            Assert.Contains("\nvolumes:", _composeContent);
        }

        [Fact]
        public void PostgresService_HasStartPeriod()
        {
            // start_period gives the container time to initialize before healthcheck failures count
            string section = ExtractServiceSection("postgres");
            Assert.Contains("start_period:", section);
        }

        [Fact]
        public void ApiService_HasRequiredEnvironmentVariables()
        {
            string section = ExtractServiceSection("api");
            string[] required =
            [
                "ASPNETCORE_ENVIRONMENT",
                "ConnectionStrings__PostgreSQL",
                "ConnectionStrings__Redis",
                "ScrapedDuck__BaseUrl",
                "Firebase__ProjectId",
            ];

            foreach (string variable in required)
            {
                Assert.Contains(variable, section);
            }
        }

        [Fact]
        public void Dockerfile_Exists_AtReferencedPath()
        {
            string repoRoot = FindRepoRoot();
            string dockerfilePath = Path.Combine(repoRoot, "src", "backend", "GoCalGo.Api", "Dockerfile");
            Assert.True(File.Exists(dockerfilePath),
                "Dockerfile should exist at the path referenced in docker-compose.yml");
        }

        [Fact]
        public void Dockerfile_HasHealthcheck()
        {
            string repoRoot = FindRepoRoot();
            string dockerfilePath = Path.Combine(repoRoot, "src", "backend", "GoCalGo.Api", "Dockerfile");
            string dockerfileContent = File.ReadAllText(dockerfilePath);
            Assert.Contains("HEALTHCHECK", dockerfileContent);
            Assert.Contains("/health", dockerfileContent);
        }

        [Fact]
        public void ApiService_InternalPortMatchesDockerfile()
        {
            // docker-compose maps 5000:8080, Dockerfile exposes 8080
            string repoRoot = FindRepoRoot();
            string dockerfileContent = File.ReadAllText(
                Path.Combine(repoRoot, "src", "backend", "GoCalGo.Api", "Dockerfile"));
            Assert.Contains("EXPOSE 8080", dockerfileContent);

            string apiSection = ExtractServiceSection("api");
            Assert.Contains("5000:8080", apiSection);
        }

        [Fact]
        public void ComposeFile_HasThreeServices()
        {
            // A complete test environment needs exactly postgres, redis, and api
            int serviceCount = 0;
            bool inServices = false;

            foreach (string line in _composeLines)
            {
                if (line.TrimEnd() == "services:")
                {
                    inServices = true;
                    continue;
                }

                if (inServices && line.Length > 0 && !char.IsWhiteSpace(line[0]))
                {
                    break;
                }

                // Service definitions are indented exactly 2 spaces and end with ':'
                if (inServices && line.Length > 2 && line.StartsWith("  ", StringComparison.Ordinal)
                    && !line.StartsWith("    ", StringComparison.Ordinal) && line.TrimEnd().EndsWith(':'))
                {
                    serviceCount++;
                }
            }

            Assert.Equal(3, serviceCount);
        }

        [Fact]
        public void InfraServices_UseOfficialImages()
        {
            string pgSection = ExtractServiceSection("postgres");
            Assert.Contains("image: postgres:", pgSection);

            string redisSection = ExtractServiceSection("redis");
            Assert.Contains("image: redis:", redisSection);
        }

        [Theory]
        [InlineData("postgres")]
        [InlineData("redis")]
        public void InfraServices_HaveRestartPolicy(string serviceName)
        {
            string section = ExtractServiceSection(serviceName);
            Assert.Contains("restart:", section);
        }

        private string ExtractServiceSection(string serviceName)
        {
            int startIndex = -1;

            for (int i = 0; i < _composeLines.Length; i++)
            {
                string trimmed = _composeLines[i].TrimEnd();
                if (trimmed == $"  {serviceName}:" || trimmed == $"  {serviceName}: ")
                {
                    startIndex = i;
                    continue;
                }

                if (startIndex >= 0 && i > startIndex && _composeLines[i].Length > 0
                    && !char.IsWhiteSpace(_composeLines[i][0]) && !_composeLines[i].StartsWith('#'))
                {
                    return string.Join('\n', _composeLines[startIndex..i]);
                }
            }

            if (startIndex >= 0)
            {
                return string.Join('\n', _composeLines[startIndex..]);
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
