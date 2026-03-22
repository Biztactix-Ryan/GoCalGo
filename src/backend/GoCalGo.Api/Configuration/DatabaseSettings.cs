namespace GoCalGo.Api.Configuration
{
    public class DatabaseSettings
    {
        public const string SectionName = "Database";

        public string Host { get; set; } = "localhost";
        public int Port { get; set; } = 5432;
        public string Database { get; set; } = "gocalgo";
        public string Username { get; set; } = "gocalgo";
        public string Password { get; set; } = string.Empty;

        public string ConnectionString =>
            $"Host={Host};Port={Port};Database={Database};Username={Username};Password={Password}";
    }
}
