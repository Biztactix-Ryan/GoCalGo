namespace GoCalGo.Api.Tests.Configuration
{
    /// <summary>
    /// Verifies acceptance criterion for story US-GCG-16:
    /// "google-services.json and GoogleService-Info.plist generated"
    ///
    /// These Firebase config files are generated from the Firebase console when
    /// registering Android and iOS apps. They contain API keys and must NOT be
    /// committed to git. These tests verify:
    ///   - .gitignore excludes both files
    ///   - The Flutter app directory exists as the expected target for these files
    ///   - .env.example documents the Firebase project context these files belong to
    /// </summary>
    public class FirebaseConfigFilesTests
    {
        private readonly string _repoRoot;
        private readonly string _gitignoreContent;
        private readonly string _envExampleContent;

        public FirebaseConfigFilesTests()
        {
            _repoRoot = FindRepoRoot();

            string gitignorePath = Path.Combine(_repoRoot, ".gitignore");
            Assert.True(File.Exists(gitignorePath), ".gitignore should exist at repo root");
            _gitignoreContent = File.ReadAllText(gitignorePath);

            string envPath = Path.Combine(_repoRoot, ".env.example");
            Assert.True(File.Exists(envPath), ".env.example should exist at repo root");
            _envExampleContent = File.ReadAllText(envPath);
        }

        [Fact]
        public void GitIgnore_ExcludesGoogleServicesJson()
        {
            // google-services.json is the Android Firebase config file containing API keys
            Assert.Contains("google-services.json", _gitignoreContent);
        }

        [Fact]
        public void GitIgnore_ExcludesGoogleServiceInfoPlist()
        {
            // GoogleService-Info.plist is the iOS Firebase config file containing API keys
            Assert.Contains("GoogleService-Info.plist", _gitignoreContent);
        }

        [Fact]
        public void FlutterAppDirectory_Exists()
        {
            // The Flutter app must exist — it's the target for Firebase config files:
            //   android/app/google-services.json
            //   ios/Runner/GoogleService-Info.plist
            string appDir = Path.Combine(_repoRoot, "src", "app");
            Assert.True(Directory.Exists(appDir),
                "Flutter app directory (src/app) should exist");
        }

        [Fact]
        public void EnvExample_DefinesFirebaseProjectId()
        {
            // The Firebase project ID links these config files to a specific project
            Assert.Contains("FIREBASE_PROJECT_ID", _envExampleContent);
        }

        [Fact]
        public void FlutterPubspec_Exists()
        {
            // pubspec.yaml must exist — confirms a valid Flutter project
            // that can receive Firebase config files
            string pubspecPath = Path.Combine(_repoRoot, "src", "app", "pubspec.yaml");
            Assert.True(File.Exists(pubspecPath),
                "pubspec.yaml should exist in the Flutter app directory");
        }

        [Fact]
        public void FlutterPubspec_IsNamedCorrectly()
        {
            // The Flutter project name determines the app identity for Firebase registration
            string pubspecPath = Path.Combine(_repoRoot, "src", "app", "pubspec.yaml");
            string content = File.ReadAllText(pubspecPath);
            Assert.Contains("name: gocalgo", content);
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
