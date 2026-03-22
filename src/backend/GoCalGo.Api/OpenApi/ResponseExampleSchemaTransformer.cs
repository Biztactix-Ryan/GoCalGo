using System.Text.Json.Nodes;
using Microsoft.AspNetCore.OpenApi;
using Microsoft.OpenApi;

namespace GoCalGo.Api.OpenApi
{
    /// <summary>
    /// Adds example values to OpenAPI schema definitions for API response models,
    /// so consumers can see realistic sample data in Swagger UI and generated docs.
    /// </summary>
    public sealed class ResponseExampleSchemaTransformer : IOpenApiSchemaTransformer
    {
        private static readonly Dictionary<string, Func<JsonObject>> SchemaExamples = new()
        {
            ["EventDto"] = CreateEventExample,
            ["ActiveEventDto"] = CreateActiveEventExample,
            ["BuffDto"] = CreateBuffExample,
            ["PokemonDto"] = CreatePokemonExample,
            ["EventsResponse"] = CreateEventsResponseExample,
            ["ActiveEventsResponse"] = CreateActiveEventsResponseExample,
        };

        public Task TransformAsync(
            OpenApiSchema schema,
            OpenApiSchemaTransformerContext context,
            CancellationToken cancellationToken)
        {
            string typeName = context.JsonTypeInfo.Type.Name;
            if (SchemaExamples.TryGetValue(typeName, out Func<JsonObject>? exampleFactory))
            {
                schema.Example = exampleFactory();
            }

            return Task.CompletedTask;
        }

        private static JsonObject CreateBuffExample()
        {
            return new JsonObject
            {
                ["text"] = "2× Catch XP",
                ["iconUrl"] = "https://example.com/icons/xp.png",
                ["category"] = "multiplier",
                ["multiplier"] = 2.0,
                ["resource"] = "XP",
            };
        }

        private static JsonObject CreatePokemonExample()
        {
            return new JsonObject
            {
                ["name"] = "Pikachu",
                ["imageUrl"] = "https://example.com/pokemon/pikachu.png",
                ["canBeShiny"] = true,
                ["role"] = "spotlight",
            };
        }

        private static JsonObject CreateEventExample()
        {
            return new JsonObject
            {
                ["id"] = "community-day-2026-03",
                ["name"] = "March 2026 Community Day",
                ["eventType"] = "community-day",
                ["heading"] = "Featuring Bulbasaur!",
                ["imageUrl"] = "https://example.com/events/cd-march.png",
                ["linkUrl"] = "https://pokemongolive.com/events/community-day",
                ["start"] = "2026-03-15T11:00:00Z",
                ["end"] = "2026-03-15T17:00:00Z",
                ["isUtcTime"] = true,
                ["hasSpawns"] = true,
                ["hasResearchTasks"] = true,
                ["buffs"] = new JsonArray { CreateBuffExample() },
                ["featuredPokemon"] = new JsonArray { CreatePokemonExample() },
                ["promoCodes"] = new JsonArray { JsonValue.Create("CD2026MARCH") },
            };
        }

        private static JsonObject CreateActiveEventExample()
        {
            JsonObject example = CreateEventExample();
            example["timeRemainingSeconds"] = 7200.0;
            return example;
        }

        private static JsonObject CreateEventsResponseExample()
        {
            return new JsonObject
            {
                ["events"] = new JsonArray { CreateEventExample() },
                ["lastUpdated"] = "2026-03-15T10:30:00Z",
                ["cacheHit"] = false,
            };
        }

        private static JsonObject CreateActiveEventsResponseExample()
        {
            return new JsonObject
            {
                ["events"] = new JsonArray { CreateActiveEventExample() },
                ["lastUpdated"] = "2026-03-15T10:30:00Z",
                ["cacheHit"] = true,
            };
        }
    }
}
