using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace GoCalGo.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddScheduledNotifications : Migration
    {
        private static readonly string[] EventDeviceColumns = ["EventId", "DeviceTokenId"];
        private static readonly string[] StatusScheduledColumns = ["Status", "ScheduledAtUtc"];

        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "ScheduledNotifications",
                columns: table => new
                {
                    Id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    EventId = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    EventName = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: false),
                    DeviceTokenId = table.Column<int>(type: "integer", nullable: false),
                    ScheduledAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    RemainingTime = table.Column<TimeSpan>(type: "interval", nullable: false),
                    Status = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ScheduledNotifications", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_ScheduledNotifications_EventId_DeviceTokenId",
                table: "ScheduledNotifications",
                columns: EventDeviceColumns);

            migrationBuilder.CreateIndex(
                name: "IX_ScheduledNotifications_Status_ScheduledAtUtc",
                table: "ScheduledNotifications",
                columns: StatusScheduledColumns);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "ScheduledNotifications");
        }
    }
}
