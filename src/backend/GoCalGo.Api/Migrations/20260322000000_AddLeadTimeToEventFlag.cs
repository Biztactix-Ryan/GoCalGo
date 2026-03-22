using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace GoCalGo.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddLeadTimeToEventFlag : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "LeadTimeMinutes",
                table: "EventFlags",
                type: "integer",
                nullable: false,
                defaultValue: 15);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "LeadTimeMinutes",
                table: "EventFlags");
        }
    }
}
