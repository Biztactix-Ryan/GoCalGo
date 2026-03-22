namespace GoCalGo.Api.Tests.Configuration
{
    /// <summary>
    /// Verifies acceptance criterion for story US-GCG-16:
    /// "FCM enabled in the Firebase console"
    ///
    /// While FCM enablement is a Firebase console action, these tests verify
    /// that the project infrastructure is configured to support FCM:
    /// the Firebase project ID is wired through configuration, and
    /// docker-compose passes the necessary Firebase environment variables.
    /// </summary>
    public class FcmEnabledTests
    {
        private readonly string _composeContent;
        private readonly string _appsettingsContent;

        public FcmEnabledTests()
        {
            string repoRoot = FindRepoRoot();

            string composePath = Path.Combine(repoRoot, "docker-compose.yml");
            Assert.True(File.Exists(composePath), "docker-compose.yml should exist at repo root");
            _composeContent = File.ReadAllText(composePath);

            string appsettingsPath = Path.Combine(
                repoRoot, "src", "backend", "GoCalGo.Api", "appsettings.json");
            Assert.True(File.Exists(appsettingsPath), "appsettings.json should exist");
            _appsettingsContent = File.ReadAllText(appsettingsPath);
        }

        [Fact]
        public void Appsettings_HasFirebaseSection()
        {
            // Firebase section must exist — FCM requires a configured Firebase project
            Assert.Contains("\"Firebase\"", _appsettingsContent);
        }

        [Fact]
        public void Appsettings_FirebaseSection_HasProjectId()
        {
            // FCM is scoped to a Firebase project; ProjectId must be present
            Assert.Contains("\"ProjectId\"", _appsettingsContent);
        }

        [Fact]
        public void DockerCompose_PassesFirebaseProjectId()
        {
            // The API container must receive the Firebase project ID for FCM to work
            Assert.Contains("Firebase__ProjectId", _composeContent);
        }

        [Fact]
        public void DockerCompose_PassesFirebaseCredentials()
        {
            // FCM server-side calls require service account credentials
            Assert.Contains("Firebase__CredentialsPath", _composeContent);
        }

        [Fact]
        public void EnvExample_DefinesFirebaseCredentials()
        {
            string repoRoot = FindRepoRoot();
            string envContent = File.ReadAllText(Path.Combine(repoRoot, ".env.example"));

            // Credentials are required for FCM API calls from the backend
            Assert.Contains("FIREBASE_CREDENTIALS_JSON", envContent);
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
