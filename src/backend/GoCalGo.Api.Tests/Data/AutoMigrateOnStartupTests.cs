namespace GoCalGo.Api.Tests.Data
{
    public class AutoMigrateOnStartupTests
    {
        [Fact]
        public void ProgramCs_CallsDatabaseMigrateInDevelopment()
        {
            string programSource = File.ReadAllText(
                Path.Combine(FindProjectRoot(), "src", "backend", "GoCalGo.Api", "Program.cs"));

            Assert.Contains("IsDevelopment()", programSource);
            Assert.Contains(".Database.Migrate()", programSource);
        }

        private static string FindProjectRoot()
        {
            DirectoryInfo? dir = new(AppContext.BaseDirectory);
            while (dir is not null && !File.Exists(Path.Combine(dir.FullName, "docker-compose.yml")))
            {
                dir = dir.Parent;
            }
            return dir?.FullName ?? throw new InvalidOperationException("Could not find project root");
        }
    }
}
