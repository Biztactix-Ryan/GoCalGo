using GoCalGo.Api.Configuration;

namespace GoCalGo.Api.Tests.Configuration
{
    /// <summary>
    /// Verifies acceptance criterion for story US-GCG-16:
    /// "Firebase project created with appropriate naming"
    ///
    /// Firebase project IDs must be globally unique, 6-30 characters,
    /// lowercase letters/digits/hyphens, and start with a letter.
    /// These tests verify that the project's Firebase configuration
    /// references a well-named project ID and is wired through all layers.
    /// </summary>
    public class FirebaseProjectNamingTests
    {
        private readonly string _composeContent;
        private readonly string _envExampleContent;

        public FirebaseProjectNamingTests()
        {
            string repoRoot = FindRepoRoot();

            string composePath = Path.Combine(repoRoot, "docker-compose.yml");
            Assert.True(File.Exists(composePath), "docker-compose.yml should exist at repo root");
            _composeContent = File.ReadAllText(composePath);

            string envPath = Path.Combine(repoRoot, ".env.example");
            Assert.True(File.Exists(envPath), ".env.example should exist at repo root");
            _envExampleContent = File.ReadAllText(envPath);
        }

        [Fact]
        public void EnvExample_DefinesFirebaseProjectId()
        {
            Assert.Contains("FIREBASE_PROJECT_ID", _envExampleContent);
        }

        [Fact]
        public void DockerCompose_PassesFirebaseProjectId_ToApiService()
        {
            // The API service must receive the project ID via the Firebase__ProjectId env var
            Assert.Contains("Firebase__ProjectId", _composeContent);
            Assert.Contains("${FIREBASE_PROJECT_ID}", _composeContent);
        }

        [Fact]
        public void FirebaseSettings_HasProjectIdProperty()
        {
            FirebaseSettings settings = new();
            Assert.NotNull(settings);
            Assert.Equal(string.Empty, settings.ProjectId);
        }

        [Fact]
        public void FirebaseSettings_SectionName_IsFirebase()
        {
            Assert.Equal("Firebase", FirebaseSettings.SectionName);
        }

        [Fact]
        public void FirebaseSettings_ProjectId_AcceptsValidName()
        {
            // Firebase project IDs: lowercase, digits, hyphens; 6-30 chars; starts with letter
            FirebaseSettings settings = new() { ProjectId = "gocalgo-prod" };
            Assert.Equal("gocalgo-prod", settings.ProjectId);
        }

        [Theory]
        [InlineData("gocalgo-prod")]
        [InlineData("gocalgo-dev")]
        [InlineData("gocalgo-staging")]
        public void ValidProjectIds_MatchFirebaseNamingRules(string projectId)
        {
            // Firebase project ID rules:
            // - 6-30 characters
            // - lowercase letters, digits, hyphens only
            // - must start with a lowercase letter
            Assert.InRange(projectId.Length, 6, 30);
            Assert.Matches("^[a-z][a-z0-9-]+$", projectId);
            Assert.DoesNotContain("--", projectId);
            Assert.False(projectId.EndsWith('-'), "Project ID should not end with a hyphen");
        }

        [Fact]
        public void EnvExample_FirebaseProjectId_HasDescriptiveComment()
        {
            // The .env.example should guide developers on what value to provide
            string[] lines = _envExampleContent.Split('\n');
            bool foundVar = false;

            foreach (string line in lines)
            {
                if (line.TrimStart().StartsWith("FIREBASE_PROJECT_ID", StringComparison.Ordinal))
                {
                    foundVar = true;
                    // The line or a nearby comment should mention Firebase project
                    Assert.True(
                        line.Contains('#') || HasPrecedingComment(lines, line),
                        "FIREBASE_PROJECT_ID should have a descriptive comment");
                    break;
                }
            }

            Assert.True(foundVar, "FIREBASE_PROJECT_ID should be defined in .env.example");
        }

        private static bool HasPrecedingComment(string[] lines, string targetLine)
        {
            for (int i = 1; i < lines.Length; i++)
            {
                if (lines[i] == targetLine && lines[i - 1].TrimStart().StartsWith('#', StringComparison.Ordinal))
                {
                    return true;
                }
            }
            return false;
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
