-- Seed data for local development
-- Usage: psql -h localhost -U gocalgo -d gocalgo_dev -f scripts/seed-data.sql
-- Or via docker: docker compose exec -T postgres psql -U gocalgo -d gocalgo_dev -f /dev/stdin < scripts/seed-data.sql

BEGIN;

-- Clear existing seed data
DELETE FROM "EventBuffs";
DELETE FROM "Events";

-- Community Day
INSERT INTO "Events" ("Id", "Name", "EventType", "Heading", "ImageUrl", "LinkUrl", "Start", "End", "IsUtcTime", "HasSpawns", "HasResearchTasks")
VALUES (
    'seed-community-day-001',
    'Community Day: Beldum',
    'CommunityDay',
    'Catch Beldum and evolve for an exclusive move!',
    'https://example.com/images/community-day-beldum.png',
    'https://example.com/events/community-day-beldum',
    NOW() + INTERVAL '2 days',
    NOW() + INTERVAL '2 days' + INTERVAL '3 hours',
    false,
    true,
    true
);

INSERT INTO "EventBuffs" ("EventId", "Text", "Category", "Multiplier", "Resource", "IconUrl", "Disclaimer")
VALUES
    ('seed-community-day-001', '3x Catch XP', 'Multiplier', 3.0, 'XP', NULL, NULL),
    ('seed-community-day-001', '2x Catch Candy', 'Multiplier', 2.0, 'Candy', NULL, NULL),
    ('seed-community-day-001', '3-hour Lure Modules', 'Duration', NULL, 'Lure Module', NULL, NULL),
    ('seed-community-day-001', '1/4 Egg Hatch Distance', 'Multiplier', 0.25, 'Egg Hatch Distance', NULL, 'Eggs must be placed in Incubators during event hours');

-- Spotlight Hour
INSERT INTO "Events" ("Id", "Name", "EventType", "Heading", "ImageUrl", "LinkUrl", "Start", "End", "IsUtcTime", "HasSpawns", "HasResearchTasks")
VALUES (
    'seed-spotlight-hour-001',
    'Spotlight Hour: Magikarp',
    'SpotlightHour',
    'Magikarp will appear more frequently in the wild!',
    'https://example.com/images/spotlight-magikarp.png',
    'https://example.com/events/spotlight-magikarp',
    NOW() + INTERVAL '1 day' + TIME '18:00:00' - CURRENT_TIME,
    NOW() + INTERVAL '1 day' + TIME '19:00:00' - CURRENT_TIME,
    false,
    true,
    false
);

INSERT INTO "EventBuffs" ("EventId", "Text", "Category", "Multiplier", "Resource", "IconUrl", "Disclaimer")
VALUES
    ('seed-spotlight-hour-001', '2x Transfer Candy', 'Multiplier', 2.0, 'Candy', NULL, NULL);

-- Raid Hour
INSERT INTO "Events" ("Id", "Name", "EventType", "Heading", "ImageUrl", "LinkUrl", "Start", "End", "IsUtcTime", "HasSpawns", "HasResearchTasks")
VALUES (
    'seed-raid-hour-001',
    'Raid Hour: Mega Rayquaza',
    'RaidHour',
    'Mega Rayquaza appears in five-star raids!',
    'https://example.com/images/raid-mega-rayquaza.png',
    'https://example.com/events/raid-mega-rayquaza',
    NOW() + INTERVAL '3 days' + TIME '18:00:00' - CURRENT_TIME,
    NOW() + INTERVAL '3 days' + TIME '19:00:00' - CURRENT_TIME,
    false,
    false,
    false
);

INSERT INTO "EventBuffs" ("EventId", "Text", "Category", "Multiplier", "Resource", "IconUrl", "Disclaimer")
VALUES
    ('seed-raid-hour-001', 'Increased five-star Raid spawns', 'Spawn', NULL, 'Raids', NULL, NULL);

-- Multi-day Event
INSERT INTO "Events" ("Id", "Name", "EventType", "Heading", "ImageUrl", "LinkUrl", "Start", "End", "IsUtcTime", "HasSpawns", "HasResearchTasks")
VALUES (
    'seed-event-001',
    'Adventure Week 2026',
    'Event',
    'Explore, hatch, and discover rare fossil Pokemon!',
    'https://example.com/images/adventure-week.png',
    'https://example.com/events/adventure-week-2026',
    NOW(),
    NOW() + INTERVAL '7 days',
    true,
    true,
    true
);

INSERT INTO "EventBuffs" ("EventId", "Text", "Category", "Multiplier", "Resource", "IconUrl", "Disclaimer")
VALUES
    ('seed-event-001', '2x Buddy Candy', 'Multiplier', 2.0, 'Candy', NULL, NULL),
    ('seed-event-001', '1/2 Egg Hatch Distance', 'Multiplier', 0.5, 'Egg Hatch Distance', NULL, NULL),
    ('seed-event-001', 'Increased Rock-type spawns', 'Spawn', NULL, 'Rock-type Pokemon', NULL, NULL),
    ('seed-event-001', 'Event-exclusive Field Research', 'Other', NULL, 'Field Research', NULL, NULL);

-- GO Battle League Season
INSERT INTO "Events" ("Id", "Name", "EventType", "Heading", "ImageUrl", "LinkUrl", "Start", "End", "IsUtcTime", "HasSpawns", "HasResearchTasks")
VALUES (
    'seed-gbl-001',
    'GO Battle League: Interlude Season',
    'GoBattleLeague',
    'Great League, Ultra League, and Master League rotations',
    'https://example.com/images/gbl-interlude.png',
    'https://example.com/events/gbl-interlude',
    NOW() - INTERVAL '10 days',
    NOW() + INTERVAL '20 days',
    true,
    false,
    false
);

INSERT INTO "EventBuffs" ("EventId", "Text", "Category", "Multiplier", "Resource", "IconUrl", "Disclaimer")
VALUES
    ('seed-gbl-001', '4x Stardust from GBL rewards', 'Multiplier', 4.0, 'Stardust', NULL, NULL);

-- GO Rocket Event
INSERT INTO "Events" ("Id", "Name", "EventType", "Heading", "ImageUrl", "LinkUrl", "Start", "End", "IsUtcTime", "HasSpawns", "HasResearchTasks")
VALUES (
    'seed-rocket-001',
    'Team GO Rocket Takeover',
    'GoRocket',
    'Shadow Pokemon appearing at increased rates from Grunts!',
    'https://example.com/images/rocket-takeover.png',
    'https://example.com/events/rocket-takeover',
    NOW() + INTERVAL '5 days',
    NOW() + INTERVAL '7 days',
    true,
    true,
    true
);

INSERT INTO "EventBuffs" ("EventId", "Text", "Category", "Multiplier", "Resource", "IconUrl", "Disclaimer")
VALUES
    ('seed-rocket-001', 'Increased Team GO Rocket balloon spawns', 'Spawn', NULL, 'Balloons', NULL, NULL),
    ('seed-rocket-001', 'New Shadow Pokemon available', 'Other', NULL, 'Shadow Pokemon', NULL, NULL);

-- Season
INSERT INTO "Events" ("Id", "Name", "EventType", "Heading", "ImageUrl", "LinkUrl", "Start", "End", "IsUtcTime", "HasSpawns", "HasResearchTasks")
VALUES (
    'seed-season-001',
    'Season of Discovery',
    'Season',
    'New seasonal spawns, eggs, and research throughout the season!',
    'https://example.com/images/season-discovery.png',
    'https://example.com/events/season-discovery',
    NOW() - INTERVAL '30 days',
    NOW() + INTERVAL '60 days',
    true,
    true,
    true
);

INSERT INTO "EventBuffs" ("EventId", "Text", "Category", "Multiplier", "Resource", "IconUrl", "Disclaimer")
VALUES
    ('seed-season-001', 'Increased Grass-type spawns in forests', 'Spawn', NULL, 'Grass-type Pokemon', NULL, NULL),
    ('seed-season-001', 'Weather-boosted spawns increased', 'Weather', NULL, 'Weather Boost', NULL, NULL);

COMMIT;
